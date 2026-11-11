import { json, optionsResponse } from "../_shared/cors.ts";
import { adminClient } from "../_shared/supabaseAdmin.ts";
import {
  generateLicenseKey,
  graceDaysTotal,
  isValidEmail,
  normalizeEmail,
  sha256Hex,
  signLicenseBlob,
  type LicenseClaims,
} from "../_shared/licenseCrypto.ts";
import { licenseKeyEmail, planUpgradedEmail, sendEmail, signInLinkEmail } from "../_shared/resend.ts";

type Body = Record<string, unknown>;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);

  let body: Body = {};
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "Invalid JSON" }, 400);
  }

  const action = String(body.action ?? "").trim();
  try {
    switch (action) {
      case "signup":
        return await signup(body);
      case "activate":
        return await activate(body);
      case "heartbeat":
        return await heartbeat(body);
      case "send_signin_link":
        return await sendSignInLink(body);
      case "resend_key":
        return await resendKey(body);
      case "list_devices":
        return await listDevices(body);
      case "remove_device":
        return await removeDevice(body);
      case "restore":
        return await restore(body);
      case "verify_key":
        return await verifyKey(body);
      case "upgrade":
        return await upgrade(body);
      default:
        return json({ ok: false, error: "Unknown action" }, 400);
    }
  } catch (err) {
    console.error("[license-api]", action, err);
    return json({ ok: false, error: err instanceof Error ? err.message : "Server error" }, 500);
  }
});

async function signup(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  const marketing = Boolean(body.marketing_opt_in ?? body.marketing);
  if (!isValidEmail(email)) return json({ ok: false, error: "Enter a valid email address." }, 400);

  const db = adminClient();
  const { data: existing } = await db
    .from("iclearer_licenses")
    .select("id, email, license_key, plan, macs, status")
    .eq("email", email)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  let license = existing;
  let created = false;

  if (!license) {
    const key = generateLicenseKey();
    const { data, error } = await db
      .from("iclearer_licenses")
      .insert({
        email,
        license_key: key,
        plan: "free",
        macs: 1,
        marketing_opt_in: marketing,
        marketing_opt_in_at: marketing ? new Date().toISOString() : null,
        status: "active",
      })
      .select("id, email, license_key, plan, macs, status")
      .single();
    if (error) throw error;
    license = data;
    created = true;
  } else if (marketing) {
    await db
      .from("iclearer_licenses")
      .update({
        marketing_opt_in: true,
        marketing_opt_in_at: new Date().toISOString(),
      })
      .eq("id", license.id);
  }

  const mail = await sendEmail(
    licenseKeyEmail(email, license!.license_key, String(license!.plan)),
  );
  if (!mail.ok) {
    return json({ ok: false, error: mail.error ?? "Could not send email." }, 502);
  }

  return json({
    ok: true,
    created,
    email,
    plan: license!.plan,
    macs: license!.macs,
    emailed: true,
    email_skipped: Boolean(mail.skipped),
    next: "signin",
    message: mail.skipped
      ? "Account ready. Resend is not configured — check server logs for the key (dev)."
      : "We emailed your license key. Sign in with that key.",
  });
}

async function activate(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  const key = String(body.key ?? "").trim().toUpperCase();
  const deviceHash = String(body.device_hash ?? "").trim();
  const deviceName = String(body.device_name ?? "").trim() || null;
  const appVersion = String(body.app_version ?? "").trim() || null;

  if (!isValidEmail(email)) return json({ ok: false, error: "Enter a valid email address." }, 400);
  if (!key) return json({ ok: false, error: "Enter your license key." }, 400);
  if (!deviceHash || deviceHash.length < 16) {
    return json({ ok: false, error: "Missing device identity." }, 400);
  }

  const db = adminClient();
  const { data: license, error } = await db
    .from("iclearer_licenses")
    .select("*")
    .eq("license_key", key)
    .maybeSingle();
  if (error) throw error;
  if (!license) return json({ ok: false, error: "That key isn’t recognized." }, 404);
  if (normalizeEmail(license.email) !== email) {
    return json({ ok: false, error: "Email doesn’t match this license key." }, 403);
  }
  if (license.status !== "active") {
    return json({ ok: false, error: `License is ${license.status}.` }, 403);
  }

  const { data: devices, error: dErr } = await db
    .from("iclearer_devices")
    .select("id, device_hash, device_name, last_seen_at")
    .eq("license_id", license.id);
  if (dErr) throw dErr;

  const existing = (devices ?? []).find((d) => d.device_hash === deviceHash);
  const seatLimit = Number(license.macs) || 1;

  if (!existing && (devices?.length ?? 0) >= seatLimit) {
    return json({
      ok: false,
      error:
        `This license is for ${seatLimit} Mac${seatLimit === 1 ? "" : "s"} and all seats are in use. ` +
        `Open iClearer on an activated Mac → Account → Your Macs, remove one, then try again. ` +
        `A correct key alone is not enough on a new Mac once seats are full.`,
      macs: seatLimit,
      seats_used: devices?.length ?? 0,
      devices: (devices ?? []).map((d) => ({
        device_hash: d.device_hash,
        device_name: d.device_name,
        last_seen_at: d.last_seen_at,
      })),
    }, 409);
  }

  if (existing) {
    await db
      .from("iclearer_devices")
      .update({
        device_name: deviceName ?? existing.device_name,
        app_version: appVersion,
        last_seen_at: new Date().toISOString(),
      })
      .eq("id", existing.id);
  } else {
    const { error: iErr } = await db.from("iclearer_devices").insert({
      license_id: license.id,
      device_hash: deviceHash,
      device_name: deviceName,
      app_version: appVersion,
      last_seen_at: new Date().toISOString(),
    });
    if (iErr) throw iErr;
  }

  await db
    .from("iclearer_licenses")
    .update({
      last_seen_at: new Date().toISOString(),
      device_hash: deviceHash,
      device_name: deviceName,
      app_version: appVersion,
    })
    .eq("id", license.id);

  const blob = await issueBlob({
    email,
    key: license.license_key,
    plan: license.plan,
    macs: seatLimit,
    device_hash: deviceHash,
  });

  return json({
    ok: true,
    email,
    key: license.license_key,
    plan: license.plan,
    macs: seatLimit,
    status: license.status,
    license_blob: blob,
    message: "Activated on this Mac.",
  });
}

async function heartbeat(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  const key = String(body.key ?? "").trim().toUpperCase();
  const deviceHash = String(body.device_hash ?? "").trim();
  const appVersion = String(body.app_version ?? "").trim() || null;

  if (!isValidEmail(email) || !key || !deviceHash) {
    return json({ ok: false, error: "Missing credentials." }, 400);
  }

  const db = adminClient();
  const { data: license } = await db
    .from("iclearer_licenses")
    .select("*")
    .eq("license_key", key)
    .maybeSingle();
  if (!license || normalizeEmail(license.email) !== email) {
    return json({ ok: false, error: "License not found." }, 404);
  }
  if (license.status !== "active") {
    return json({ ok: false, error: `License is ${license.status}.`, status: license.status }, 403);
  }

  const { data: device } = await db
    .from("iclearer_devices")
    .select("id")
    .eq("license_id", license.id)
    .eq("device_hash", deviceHash)
    .maybeSingle();
  if (!device) {
    return json({ ok: false, error: "This Mac is not activated for this license." }, 403);
  }

  const now = new Date().toISOString();
  await db.from("iclearer_devices").update({ last_seen_at: now, app_version: appVersion }).eq("id", device.id);
  await db.from("iclearer_licenses").update({ last_seen_at: now, app_version: appVersion }).eq("id", license.id);

  const blob = await issueBlob({
    email,
    key: license.license_key,
    plan: license.plan,
    macs: Number(license.macs) || 1,
    device_hash: deviceHash,
  });

  return json({
    ok: true,
    plan: license.plan,
    macs: license.macs,
    status: license.status,
    license_blob: blob,
  });
}

async function sendSignInLink(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  if (!isValidEmail(email)) return json({ ok: false, error: "Enter a valid email address." }, 400);

  const db = adminClient();
  const { data: license } = await db
    .from("iclearer_licenses")
    .select("id, license_key, plan")
    .eq("email", email)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!license) {
    // Don't leak whether email exists — still return ok, but also offer signup path.
    return json({
      ok: true,
      emailed: false,
      message: "If that email has a license, we sent a sign-in link.",
    });
  }

  const raw = crypto.randomUUID() + crypto.randomUUID();
  const tokenHash = await sha256Hex(raw);
  const expires = new Date(Date.now() + 30 * 60 * 1000).toISOString();
  await db.from("iclearer_signin_tokens").insert({
    email,
    license_id: license.id,
    token_hash: tokenHash,
    expires_at: expires,
    purpose: "signin",
  });

  const site = Deno.env.get("SITE_URL") ?? "https://iclearer.com";
  // Deep-link style: website page can show the key; for Mac we also email the key.
  const link = `${site}/signin?token=${encodeURIComponent(raw)}&email=${encodeURIComponent(email)}`;

  // Prefer the license key (Mac sign-in). Optional deep link kept for website restore later.
  await sendEmail(licenseKeyEmail(email, license.license_key, String(license.plan)));

  return json({
    ok: true,
    emailed: true,
    message: "We emailed your license key. Paste it below to sign in.",
    signin_link: link,
  });
}

async function resendKey(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  if (!isValidEmail(email)) return json({ ok: false, error: "Enter a valid email address." }, 400);
  const db = adminClient();
  const { data: license } = await db
    .from("iclearer_licenses")
    .select("license_key, plan")
    .eq("email", email)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!license) {
    return json({ ok: true, emailed: false, message: "If that email has a license, we resent the key." });
  }
  const mail = await sendEmail(licenseKeyEmail(email, license.license_key, String(license.plan)));
  if (!mail.ok) return json({ ok: false, error: mail.error ?? "Email failed" }, 502);
  return json({ ok: true, emailed: true, email_skipped: Boolean(mail.skipped), message: "License key sent." });
}

async function listDevices(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  const key = String(body.key ?? "").trim().toUpperCase();
  if (!isValidEmail(email) || !key) return json({ ok: false, error: "Missing credentials." }, 400);
  const db = adminClient();
  const { data: license } = await db
    .from("iclearer_licenses")
    .select("id, macs, email, license_key")
    .eq("license_key", key)
    .maybeSingle();
  if (!license || normalizeEmail(license.email) !== email) {
    return json({ ok: false, error: "License not found." }, 404);
  }
  const { data: devices } = await db
    .from("iclearer_devices")
    .select("id, device_hash, device_name, app_version, last_seen_at, created_at")
    .eq("license_id", license.id)
    .order("last_seen_at", { ascending: false });
  return json({ ok: true, macs: license.macs, devices: devices ?? [] });
}

async function removeDevice(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  const key = String(body.key ?? "").trim().toUpperCase();
  const deviceHash = String(body.device_hash ?? "").trim();
  if (!isValidEmail(email) || !key || !deviceHash) {
    return json({ ok: false, error: "Missing credentials." }, 400);
  }
  const db = adminClient();
  const { data: license } = await db
    .from("iclearer_licenses")
    .select("id, email")
    .eq("license_key", key)
    .maybeSingle();
  if (!license || normalizeEmail(license.email) !== email) {
    return json({ ok: false, error: "License not found." }, 404);
  }
  const { error } = await db
    .from("iclearer_devices")
    .delete()
    .eq("license_id", license.id)
    .eq("device_hash", deviceHash);
  if (error) throw error;
  return json({ ok: true, message: "Mac removed from this license." });
}

async function restore(body: Body) {
  // Same as activate but without requiring a new seat if already on this device —
  // activate already covers restore. Keep as alias.
  return activate(body);
}

/** Confirm email + existing key match before checkout. */
async function verifyKey(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  const key = String(body.key ?? body.license_key ?? "").trim().toUpperCase();
  if (!isValidEmail(email)) return json({ ok: false, error: "Enter a valid email address." }, 400);
  if (!key) return json({ ok: false, error: "Enter your license key." }, 400);

  const db = adminClient();
  const { data: license } = await db
    .from("iclearer_licenses")
    .select("id, email, license_key, plan, macs, status")
    .eq("license_key", key)
    .maybeSingle();
  if (!license) return json({ ok: false, error: "That license key isn’t recognized." }, 404);
  if (normalizeEmail(license.email) !== email) {
    return json({ ok: false, error: "Email doesn’t match this license key." }, 403);
  }
  if (license.status !== "active") {
    return json({ ok: false, error: `License is ${license.status}.` }, 403);
  }
  return json({
    ok: true,
    email,
    key: license.license_key,
    plan: license.plan,
    macs: license.macs,
    message: "License verified. Continue to payment to upgrade this same key.",
  });
}

/**
 * Upgrade an existing license to a paid plan — keeps the same key.
 * Used after Paddle (webhook) or sandbox checkout.
 */
async function upgrade(body: Body) {
  const email = normalizeEmail(String(body.email ?? ""));
  const key = String(body.key ?? body.license_key ?? "").trim().toUpperCase();
  const plan = String(body.plan ?? "yearly");
  const macs = Number(body.macs ?? 1);
  const safePlan = ["monthly", "yearly", "once"].includes(plan) ? plan : "yearly";
  const safeMacs = [1, 2, 5].includes(macs) ? macs : 1;
  const sendMail = body.send_email !== false;

  if (!isValidEmail(email)) return json({ ok: false, error: "Enter a valid email address." }, 400);
  if (!key) return json({ ok: false, error: "Enter your license key." }, 400);

  const db = adminClient();
  const { data: license } = await db
    .from("iclearer_licenses")
    .select("*")
    .eq("license_key", key)
    .maybeSingle();
  if (!license) return json({ ok: false, error: "That license key isn’t recognized." }, 404);
  if (normalizeEmail(license.email) !== email) {
    return json({ ok: false, error: "Email doesn’t match this license key." }, 403);
  }

  const { error } = await db
    .from("iclearer_licenses")
    .update({
      plan: safePlan,
      macs: safeMacs,
      status: "active",
    })
    .eq("id", license.id);
  if (error) throw error;

  if (sendMail) {
    await sendEmail(planUpgradedEmail(email, license.license_key, safePlan));
  }

  return json({
    ok: true,
    email,
    key: license.license_key,
    plan: safePlan,
    macs: safeMacs,
    upgraded: true,
    message: `Same key upgraded to ${safePlan}. No new key was issued.`,
  });
}

async function issueBlob(args: {
  email: string;
  key: string;
  plan: string;
  macs: number;
  device_hash: string;
}): Promise<string> {
  const claims: LicenseClaims = {
    v: 1,
    email: args.email,
    key: args.key,
    plan: args.plan as LicenseClaims["plan"],
    macs: args.macs,
    device_hash: args.device_hash,
    verified_at: Math.floor(Date.now() / 1000),
    grace_days: graceDaysTotal(),
  };
  return await signLicenseBlob(claims);
}
