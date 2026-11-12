const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL ||
  import.meta.env.NEXT_PUBLIC_SUPABASE_URL ||
  "";
const SUPABASE_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
  import.meta.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
  "";

export type LicenseApiResult = {
  ok: boolean;
  error?: string;
  message?: string;
  email?: string;
  key?: string;
  plan?: string;
  macs?: number;
  emailed?: boolean;
  email_skipped?: boolean;
  next?: string;
  upgraded?: boolean;
  checkout_url?: string;
};

async function post(body: Record<string, unknown>): Promise<LicenseApiResult> {
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return { ok: false, error: "Supabase is not configured." };
  }
  const res = await fetch(`${SUPABASE_URL}/functions/v1/license-api`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${SUPABASE_KEY}`,
    },
    body: JSON.stringify(body),
  });
  try {
    return (await res.json()) as LicenseApiResult;
  } catch {
    return { ok: false, error: `Server error (${res.status})` };
  }
}

export function signup(email: string, marketing: boolean) {
  return post({ action: "signup", email, marketing_opt_in: marketing });
}

export function setMarketing(email: string, key: string, marketing: boolean) {
  return post({
    action: "set_marketing",
    email,
    key,
    marketing_opt_in: marketing,
  });
}

export function resendKey(email: string) {
  return post({ action: "resend_key", email });
}

export function verifyKey(email: string, key: string) {
  return post({ action: "verify_key", email, key });
}

/**
 * Buy flow: verify existing key, then open Creem hosted checkout (same key in metadata).
 * Payment confirmation upgrades the license via the Creem webhook.
 */
export async function startCheckout(opts: {
  email: string;
  key: string;
  marketing?: boolean;
  plan: "monthly" | "yearly" | "once";
  macs: 1 | 2 | 5;
}): Promise<LicenseApiResult> {
  const result = await post({
    action: "create_checkout",
    email: opts.email,
    key: opts.key,
    plan: opts.plan,
    macs: opts.macs,
    marketing_opt_in: Boolean(opts.marketing),
  });

  if (result.ok && result.checkout_url && typeof window !== "undefined") {
    window.location.href = result.checkout_url;
    return {
      ...result,
      message: result.message || "Redirecting to secure checkout…",
    };
  }

  return result;
}
