type SendArgs = {
  to: string;
  subject: string;
  html: string;
  text: string;
};

export async function sendEmail(args: SendArgs): Promise<{ ok: boolean; id?: string; skipped?: boolean; error?: string }> {
  const apiKey = Deno.env.get("RESEND_API_KEY") ?? "";
  const from = Deno.env.get("RESEND_FROM_EMAIL") ?? "iClearer <licenses@iclearer.com>";

  if (!apiKey) {
    console.log("[resend:dry-run]", { to: args.to, subject: args.subject, text: args.text });
    return { ok: true, skipped: true, id: "dry-run" };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [args.to],
      subject: args.subject,
      html: args.html,
      text: args.text,
    }),
  });

  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error("[resend:error]", res.status, body);
    return { ok: false, error: typeof body?.message === "string" ? body.message : "Email failed" };
  }
  return { ok: true, id: body?.id };
}

/** Absolute HTTPS URL — email clients block relative paths. Override with EMAIL_LOGO_URL. */
function emailLogoUrl(site: string): string {
  return (
    Deno.env.get("EMAIL_LOGO_URL") ??
    `${site.replace(/\/$/, "")}/assets/png/icon-glass-light-120.png`
  );
}

function emailHeader(site: string): string {
  const logo = emailLogoUrl(site);
  return `
    <div style="text-align:center;padding:8px 0 20px">
      <a href="${site}" style="text-decoration:none">
        <img src="${logo}" width="64" height="64" alt="iClearer"
          style="display:inline-block;border:0;border-radius:14px" />
      </a>
    </div>`;
}

export function licenseKeyEmail(email: string, key: string, plan: string): SendArgs {
  const site = Deno.env.get("SITE_URL") ?? "https://www.iclearer.com";
  const subject = "Your iClearer license key";
  const text =
    `Welcome to iClearer.\n\n` +
    `Your license key:\n${key}\n\n` +
    `Plan: ${plan}\n` +
    `Open iClearer → Sign in or activate, enter ${email} and this key.\n\n` +
    `Help: ${site}\n`;
  const html = `
    <div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:520px;margin:0 auto;color:#14202B">
      ${emailHeader(site)}
      <h1 style="font-size:22px;text-align:center;margin:0 0 12px">Welcome to iClearer</h1>
      <p>Use this key to sign in on your Mac:</p>
      <p style="font-size:20px;font-weight:700;letter-spacing:0.04em;background:#F2F5F8;padding:14px 16px;border-radius:12px">${key}</p>
      <p>Email: <strong>${email}</strong><br>Plan: <strong>${plan}</strong></p>
      <p>Open iClearer → <em>Sign in or activate</em>, then paste the key.</p>
      <p style="color:#6B7A88;font-size:13px"><a href="${site}">${site}</a></p>
    </div>`;
  return { to: email, subject, html, text };
}

export function planUpgradedEmail(email: string, key: string, plan: string): SendArgs {
  const site = Deno.env.get("SITE_URL") ?? "https://www.iclearer.com";
  const subject = "Your iClearer plan is upgraded";
  const text =
    `Thanks for upgrading iClearer.\n\n` +
    `Your same license key is now on the ${plan} plan:\n${key}\n\n` +
    `No new key was issued — keep using this one in the Mac app.\n\n` +
    `${site}\n`;
  const html = `
    <div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:520px;margin:0 auto;color:#14202B">
      ${emailHeader(site)}
      <h1 style="font-size:22px;text-align:center;margin:0 0 12px">You’re upgraded</h1>
      <p>Thanks for paying. Your <strong>same</strong> license key is now on the <strong>${plan}</strong> plan — we did not create a new key.</p>
      <p style="font-size:20px;font-weight:700;letter-spacing:0.04em;background:#F2F5F8;padding:14px 16px;border-radius:12px">${key}</p>
      <p>Email: <strong>${email}</strong></p>
      <p>Open iClearer → Sign in or activate if this Mac isn’t activated yet.</p>
      <p style="color:#6B7A88;font-size:13px"><a href="${site}">${site}</a></p>
    </div>`;
  return { to: email, subject, html, text };
}

export function signInLinkEmail(email: string, link: string): SendArgs {
  const site = Deno.env.get("SITE_URL") ?? "https://www.iclearer.com";
  const subject = "Sign in to iClearer";
  const text = `Sign in to iClearer with this one-time link (expires in 30 minutes):\n\n${link}\n\nIf you did not ask for this, ignore this email.`;
  const html = `
    <div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:520px;margin:0 auto;color:#14202B">
      ${emailHeader(site)}
      <h1 style="font-size:22px;text-align:center;margin:0 0 12px">Sign in to iClearer</h1>
      <p>This one-time link expires in 30 minutes.</p>
      <p style="text-align:center"><a href="${link}" style="display:inline-block;background:#7FB8E6;color:#06131F;text-decoration:none;padding:12px 18px;border-radius:999px;font-weight:600">Sign in</a></p>
      <p style="color:#6B7A88;font-size:13px">Or paste this into a browser:<br>${link}</p>
    </div>`;
  return { to: email, subject, html, text };
}
