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
  plan?: string;
  macs?: number;
  emailed?: boolean;
  email_skipped?: boolean;
  next?: string;
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

/** Paddle.js overlay when configured; otherwise signup+email key (dev). */
export async function startCheckout(opts: {
  email: string;
  name?: string;
  marketing?: boolean;
  plan: "monthly" | "yearly" | "once";
  macs: 1 | 2 | 5;
}): Promise<LicenseApiResult> {
  const priceId = paddlePriceId(opts.plan, opts.macs);
  const token = import.meta.env.VITE_PADDLE_CLIENT_TOKEN as string | undefined;

  if (token && priceId && typeof window !== "undefined" && (window as unknown as { Paddle?: PaddleLike }).Paddle) {
    const Paddle = (window as unknown as { Paddle: PaddleLike }).Paddle;
    return await new Promise((resolve) => {
      Paddle.Checkout.open({
        settings: { displayMode: "overlay", theme: "dark" },
        items: [{ priceId, quantity: 1 }],
        customer: { email: opts.email },
        customData: {
          email: opts.email,
          plan: opts.plan,
          macs: String(opts.macs),
        },
        onComplete: () =>
          resolve({
            ok: true,
            message: "Payment complete. Check your email for your license key.",
            emailed: true,
          }),
      });
    });
  }

  // Payments not live: create/ensure account and email the (free/dev) key.
  const result = await signup(opts.email, Boolean(opts.marketing));
  if (result.ok) {
    result.message =
      result.message ||
      "Payments are not live yet. We emailed your license key so you can sign in on the Mac app.";
  }
  return result;
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
