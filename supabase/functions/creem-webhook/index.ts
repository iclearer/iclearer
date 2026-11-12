import { json, optionsResponse } from "../_shared/cors.ts";
import { adminClient } from "../_shared/supabaseAdmin.ts";
import { generateLicenseKey, isValidEmail, normalizeEmail } from "../_shared/licenseCrypto.ts";
import { planUpgradedEmail, sendEmail } from "../_shared/resend.ts";

/**
 * Creem Merchant of Record webhook.
 * Env:
 *   CREEM_WEBHOOK_SECRET — HMAC secret from Creem Developers > Webhooks
 *   CREEM_PRODUCT_REVERSE_JSON — {"prod_xxx":{"plan":"yearly","macs":1},...}
 *   (falls back to object-valued entries in CREEM_PRODUCT_MAP_JSON)
 */

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  const raw = await req.text();
  const secret = Deno.env.get("CREEM_WEBHOOK_SECRET") ?? "";
  if (secret) {
    const sig = req.headers.get("creem-signature") ?? "";
    if (!sig) return json({ ok: false, error: "Missing creem-signature" }, 401);
    const ok = await verifyCreemSignature(raw, sig, secret);
    if (!ok) return json({ ok: false, error: "Invalid signature" }, 401);
  }

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ ok: false, error: "Invalid JSON" }, 400);
  }

  const eventType = String(event.eventType ?? event.event_type ?? "");
  const eventId = String(event.id ?? crypto.randomUUID());
  const object = (event.object ?? {}) as Record<string, unknown>;

  const db = adminClient();
  const { data: prior } = await db
    .from("iclearer_purchases")
    .select("id")
    .eq("provider", "creem")
    .eq("provider_event_id", eventId)
    .maybeSingle();
  if (prior) return json({ ok: true, duplicate: true });

  if (eventType === "checkout.completed" || eventType === "subscription.paid") {
    return await handlePaid(db, eventType, eventId, object);
  }

  if (
    eventType === "subscription.canceled" ||
    eventType === "subscription.expired" ||
    eventType === "subscription.past_due"
  ) {
    const subId = String(object.id ?? "");
    const status = eventType.includes("past_due") ? "past_due" : "cancelled";
    if (subId) {
      await db.from("iclearer_licenses").update({ status }).eq("creem_subscription_id", subId);
    }
    await db.from("iclearer_purchases").insert({
      provider: "creem",
      provider_event_id: eventId,
      status,
      raw: { event_type: eventType, object },
    });
    return json({ ok: true, status });
  }

  return json({ ok: true, ignored: eventType });
});

async function handlePaid(
  db: ReturnType<typeof adminClient>,
  eventType: string,
  eventId: string,
  object: Record<string, unknown>,
) {
  const product = (object.product ?? {}) as Record<string, unknown>;
  const customer = (object.customer ?? {}) as Record<string, unknown>;
  const order = (object.order ?? {}) as Record<string, unknown>;
  const subscription = (object.subscription ?? {}) as Record<string, unknown>;
  const metadata = {
    ...((subscription.metadata ?? {}) as Record<string, unknown>),
    ...((object.metadata ?? {}) as Record<string, unknown>),
  };

  let email = normalizeEmail(
    String(metadata.email ?? customer.email ?? order.email ?? ""),
  );
  const incomingKey = String(metadata.license_key ?? metadata.key ?? "").trim().toUpperCase();

  let productId = "";
  if (typeof object.product === "string") productId = object.product;
  else if (product.id) productId = String(product.id);
  else if (typeof order.product === "string") productId = String(order.product);
  else if (metadata.product_id) productId = String(metadata.product_id);
  const mapped = mapProduct(productId);
  const plan = String(metadata.plan ?? mapped?.plan ?? "yearly") as "monthly" | "yearly" | "once";
  const macs = Number(metadata.macs ?? mapped?.macs ?? 1);
  const safeMacs = [1, 2, 5].includes(macs) ? macs : 1;
  const safePlan = ["monthly", "yearly", "once"].includes(plan) ? plan : "yearly";

  if (!isValidEmail(email)) {
    console.error("[creem] missing email", eventId, object);
    return json({ ok: false, error: "Missing customer email" }, 422);
  }

  const customerId = String(customer.id ?? "") || null;
  const subscriptionId =
    String(subscription.id ?? object.id ?? "").startsWith("sub_")
      ? String(subscription.id ?? object.id)
      : null;

  const { data: existing } = incomingKey
    ? await db.from("iclearer_licenses").select("*").eq("license_key", incomingKey).maybeSingle()
    : await db
        .from("iclearer_licenses")
        .select("*")
        .eq("email", email)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

  let license = existing;
  if (!license) {
    const key = generateLicenseKey();
    const { data, error } = await db
      .from("iclearer_licenses")
      .insert({
        email,
        license_key: key,
        plan: safePlan,
        macs: safeMacs,
        status: "active",
        creem_customer_id: customerId,
        creem_subscription_id: subscriptionId,
      })
      .select("*")
      .single();
    if (error) throw error;
    license = data;
  } else {
    const { data, error } = await db
      .from("iclearer_licenses")
      .update({
        plan: safePlan,
        macs: safeMacs,
        status: "active",
        email: normalizeEmail(license.email) === email ? license.email : email,
        creem_customer_id: customerId ?? license.creem_customer_id,
        creem_subscription_id: subscriptionId ?? license.creem_subscription_id,
      })
      .eq("id", license.id)
      .select("*")
      .single();
    if (error) throw error;
    license = data;
  }

  await db.from("iclearer_purchases").insert({
    provider: "creem",
    provider_event_id: eventId,
    license_id: license.id,
    email,
    plan: safePlan,
    macs: safeMacs,
    status: "paid",
    raw: { event_type: eventType, object },
  });

  const mail = await sendEmail(planUpgradedEmail(email, license.license_key, safePlan));
  return json({
    ok: true,
    upgraded: true,
    email,
    key: license.license_key,
    plan: safePlan,
    macs: safeMacs,
    emailed: mail.ok,
  });
}

function mapProduct(productId: string): { plan: string; macs: number } | null {
  if (!productId) return null;
  const sources = [
    Deno.env.get("CREEM_PRODUCT_REVERSE_JSON") ?? "",
    Deno.env.get("CREEM_PRODUCT_MAP_JSON") ?? "",
  ];
  for (const raw of sources) {
    if (!raw.trim()) continue;
    try {
      const map = JSON.parse(raw) as Record<string, unknown>;
      const entry = map[productId];
      if (entry && typeof entry === "object" && !Array.isArray(entry)) {
        const plan = String((entry as { plan?: string }).plan ?? "");
        const macs = Number((entry as { macs?: number }).macs ?? 0);
        if (plan && macs) return { plan, macs };
      }
    } catch {
      /* try next */
    }
  }
  return null;
}

async function verifyCreemSignature(rawBody: string, header: string, secret: string): Promise<boolean> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody)));
  const hex = Array.from(sig, (b) => b.toString(16).padStart(2, "0")).join("");
  return hex === header.trim().toLowerCase() || hex === header.trim();
}
