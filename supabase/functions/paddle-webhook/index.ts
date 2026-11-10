import { json, optionsResponse } from "../_shared/cors.ts";
import { adminClient } from "../_shared/supabaseAdmin.ts";
import { generateLicenseKey, isValidEmail, normalizeEmail } from "../_shared/licenseCrypto.ts";
import { planUpgradedEmail, sendEmail } from "../_shared/resend.ts";

/**
 * Paddle Billing webhook.
 * Maps custom_data.plan + custom_data.macs (or price id map) → license row + Resend key email.
 *
 * Env:
 *   PADDLE_WEBHOOK_SECRET — for signature verification (optional in sandbox bootstrap)
 *   PADDLE_PRICE_MAP_JSON — optional {"pri_xxx":{"plan":"yearly","macs":1},...}
 */

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  const raw = await req.text();
  const secret = Deno.env.get("PADDLE_WEBHOOK_SECRET") ?? "";
  if (secret) {
    const ts = req.headers.get("paddle-signature") ?? "";
    // Soft-verify: Paddle uses ts=...;h1=... HMAC. Full verify when secret set.
    if (!ts) return json({ ok: false, error: "Missing paddle-signature" }, 401);
    const ok = await verifyPaddleSignature(raw, ts, secret);
    if (!ok) return json({ ok: false, error: "Invalid signature" }, 401);
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ ok: false, error: "Invalid JSON" }, 400);
  }

  const eventType = String(event.event_type ?? event.eventType ?? "");
  const eventId = String(event.event_id ?? event.eventId ?? crypto.randomUUID());
  const data = (event.data ?? {}) as Record<string, unknown>;

  // Idempotency
  const db = adminClient();
  const { data: prior } = await db
    .from("iclearer_purchases")
    .select("id")
    .eq("provider", "paddle")
    .eq("provider_event_id", eventId)
    .maybeSingle();
  if (prior) return json({ ok: true, duplicate: true });

  if (
    eventType === "transaction.completed" ||
    eventType === "subscription.activated" ||
    eventType === "subscription.updated"
  ) {
    return await handlePaid(db, eventType, eventId, data);
  }

  if (eventType === "subscription.canceled" || eventType === "subscription.past_due") {
    const subId = String(data.id ?? data.subscription_id ?? "");
    const status = eventType.endsWith("canceled") ? "cancelled" : "past_due";
    if (subId) {
      await db.from("iclearer_licenses").update({ status }).eq("paddle_subscription_id", subId);
    }
    return json({ ok: true, status });
  }

  return json({ ok: true, ignored: eventType });
});

async function handlePaid(
  db: ReturnType<typeof adminClient>,
  eventType: string,
  eventId: string,
  data: Record<string, unknown>,
) {
  const custom = (data.custom_data ?? data.customData ?? {}) as Record<string, unknown>;
  let email = normalizeEmail(
    String(
      custom.email ??
        (data.customer as Record<string, unknown> | undefined)?.email ??
        data.email ??
        "",
    ),
  );
  const incomingKey = String(custom.license_key ?? custom.key ?? "").trim().toUpperCase();

  // Paddle often nests customer id only — email may be in details
  if (!isValidEmail(email)) {
    email = normalizeEmail(String((data.details as Record<string, unknown> | undefined)?.email ?? ""));
  }

  const priceId = extractPriceId(data);
  const mapped = mapPrice(priceId);
  const plan = String(custom.plan ?? mapped?.plan ?? "yearly") as "monthly" | "yearly" | "once";
  const macs = Number(custom.macs ?? mapped?.macs ?? 1);
  const safeMacs = [1, 2, 5].includes(macs) ? macs : 1;
  const safePlan = ["monthly", "yearly", "once"].includes(plan) ? plan : "yearly";

  if (!isValidEmail(email)) {
    console.error("[paddle] missing email", eventId, data);
    return json({ ok: false, error: "Missing customer email" }, 422);
  }

  const customerId = String(
    (data.customer_id as string | undefined) ??
      (data.customer as Record<string, unknown> | undefined)?.id ??
      "",
  ) || null;
  const subscriptionId = String(
    (data.subscription_id as string | undefined) ??
      (safePlan === "once" ? "" : data.id ?? ""),
  ) || null;
  const txnId = String(data.id ?? data.transaction_id ?? "") || null;

  // Prefer upgrading the key they entered at checkout — never mint a new one when key is present.
  let existing = null as Record<string, unknown> | null;
  if (incomingKey) {
    const { data: byKey } = await db
      .from("iclearer_licenses")
      .select("*")
      .eq("license_key", incomingKey)
      .maybeSingle();
    existing = byKey;
    if (existing && normalizeEmail(String(existing.email)) !== email) {
      return json({ ok: false, error: "Email doesn’t match this license key." }, 403);
    }
  }
  if (!existing) {
    const { data: byEmail } = await db
      .from("iclearer_licenses")
      .select("*")
      .eq("email", email)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    existing = byEmail;
  }

  let licenseId = existing?.id as string | undefined;
  let licenseKey = existing?.license_key as string | undefined;
  let created = false;

  if (existing) {
    await db
      .from("iclearer_licenses")
      .update({
        plan: safePlan,
        macs: safeMacs,
        status: "active",
        paddle_customer_id: customerId ?? existing.paddle_customer_id,
        paddle_subscription_id: subscriptionId ?? existing.paddle_subscription_id,
      })
      .eq("id", existing.id);
  } else if (incomingKey) {
    // Key claimed but missing in DB — refuse rather than invent another key.
    return json({ ok: false, error: "License key not found; payment recorded for support." }, 404);
  } else {
    // Legacy checkout without a key: create once (should be rare).
    licenseKey = generateLicenseKey();
    const { data: createdRow, error } = await db
      .from("iclearer_licenses")
      .insert({
        email,
        license_key: licenseKey,
        plan: safePlan,
        macs: safeMacs,
        status: "active",
        paddle_customer_id: customerId,
        paddle_subscription_id: subscriptionId,
        marketing_opt_in: false,
      })
      .select("id, license_key")
      .single();
    if (error) throw error;
    licenseId = createdRow.id;
    licenseKey = createdRow.license_key;
    created = true;
  }

  await db.from("iclearer_purchases").insert({
    license_id: licenseId,
    email,
    provider: "paddle",
    provider_event_id: eventId,
    provider_transaction_id: txnId,
    plan: safePlan,
    macs: safeMacs,
    raw: { event_type: eventType, data },
  });

  if (licenseKey) {
    await sendEmail(planUpgradedEmail(email, licenseKey, safePlan));
  }

  return json({
    ok: true,
    created,
    upgraded: !created,
    email,
    key: licenseKey,
    plan: safePlan,
    macs: safeMacs,
  });
}

function extractPriceId(data: Record<string, unknown>): string {
  const items = (data.items as unknown[]) ?? (data.details as Record<string, unknown> | undefined)?.line_items as unknown[] ?? [];
  if (Array.isArray(items) && items.length) {
    const first = items[0] as Record<string, unknown>;
    const price = (first.price as Record<string, unknown> | undefined) ?? first;
    return String(price.id ?? price.price_id ?? "");
  }
  return String(data.price_id ?? "");
}

function mapPrice(priceId: string): { plan: string; macs: number } | null {
  if (!priceId) return null;
  try {
    const raw = Deno.env.get("PADDLE_PRICE_MAP_JSON") ?? "{}";
    const map = JSON.parse(raw) as Record<string, { plan: string; macs: number }>;
    return map[priceId] ?? null;
  } catch {
    return null;
  }
}

async function verifyPaddleSignature(rawBody: string, header: string, secret: string): Promise<boolean> {
  // paddle-signature: ts=1700000000;h1=hex
  const parts = Object.fromEntries(
    header.split(";").map((p) => {
      const [k, v] = p.trim().split("=");
      return [k, v];
    }),
  );
  const ts = parts["ts"];
  const h1 = parts["h1"];
  if (!ts || !h1) return false;
  const payload = `${ts}:${rawBody}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)));
  const hex = Array.from(sig, (b) => b.toString(16).padStart(2, "0")).join("");
  return hex === h1;
}
