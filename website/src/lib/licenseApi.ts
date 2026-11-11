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

export function resendKey(email: string) {
  return post({ action: "resend_key", email });
}

export function verifyKey(email: string, key: string) {
  return post({ action: "verify_key", email, key });
}

export function upgradeLicense(opts: {
  email: string;
  key: string;
  plan: "monthly" | "yearly" | "once";
  macs: 1 | 2 | 5;
}) {
  return post({
    action: "upgrade",
    email: opts.email,
    key: opts.key,
    plan: opts.plan,
    macs: opts.macs,
  });
}

/**
 * Buy flow: verify existing key, then Paddle checkout (same key in custom_data).
 * Sandbox / no Paddle.js: upgrade that same key in place (no new key emailed as “new”).
 */
export async function startCheckout(opts: {
  email: string;
  key: string;
  marketing?: boolean;
  plan: "monthly" | "yearly" | "once";
  macs: 1 | 2 | 5;
}): Promise<LicenseApiResult> {
  const verified = await verifyKey(opts.email, opts.key);
  if (!verified.ok) return verified;

  const priceId = paddlePriceId(opts.plan, opts.macs);
  const token = import.meta.env.VITE_PADDLE_CLIENT_TOKEN as string | undefined;
  const paddleReady =
    Boolean(token && priceId && typeof window !== "undefined") &&
    Boolean((window as unknown as { Paddle?: PaddleLike }).Paddle);

  if (paddleReady) {
    const Paddle = (window as unknown as { Paddle: PaddleLike }).Paddle;
    return await new Promise((resolve) => {
      let settled = false;
      const finish = (result: LicenseApiResult) => {
        if (settled) return;
        settled = true;
        resolve(result);
      };
      try {
        Paddle.Checkout.open({
          settings: { displayMode: "overlay", theme: "dark" },
          items: [{ priceId: priceId!, quantity: 1 }],
          customer: { email: opts.email },
          customData: {
            email: opts.email,
            license_key: opts.key.toUpperCase(),
            plan: opts.plan,
            macs: String(opts.macs),
          },
          onComplete: async () => {
            // Webhook upgrades the key; also upgrade optimistically for snappy UI.
            const up = await upgradeLicense(opts);
            finish({
              ok: true,
              upgraded: true,
              email: opts.email,
              key: opts.key.toUpperCase(),
              plan: opts.plan,
              macs: opts.macs,
              message:
                up.message ||
                "Payment complete. Your same license key is now paid — no new key was issued.",
            });
          },
        });
      } catch (err) {
        finish({
          ok: false,
          error: err instanceof Error ? err.message : "Could not open checkout.",
        });
      }
    });
  }

  // Payments UI not wired / sandbox without Paddle.js — upgrade same key.
  const up = await upgradeLicense(opts);
  if (up.ok) {
    up.message =
      up.message ||
      `Same key upgraded to ${opts.plan}. Use it in the Mac app — we did not create a new key.`;
  }
  return up;
}

function paddlePriceId(plan: string, macs: number): string | undefined {
  const map = (import.meta.env.VITE_PADDLE_PRICE_MAP_JSON as string | undefined) || "{}";
  try {
    const parsed = JSON.parse(map) as Record<string, string>;
    return parsed[`${plan}:${macs}`] || parsed[`${plan}_${macs}`];
  } catch {
    return undefined;
  }
}

type PaddleLike = {
  Checkout: {
    open: (opts: Record<string, unknown>) => void;
  };
};
