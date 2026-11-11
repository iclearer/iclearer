import "./landing.css";
import { bumpSharedDownloadCount } from "./lib/iclearerDownloads";
import { startCheckout, signup } from "./lib/licenseApi";

const DMG_URL = "/downloads/iClearer.dmg";
const LEAD_KEY = "iclearer-download-lead";
const LICENSE_KEY = "iclearer-license";

type Mode = "buy" | "create";

type Lead = { email: string; marketing?: boolean };

const modal = () => document.getElementById("dl-modal");
const form = () => document.getElementById("dl-form") as HTMLFormElement | null;
const titleEl = () => document.getElementById("dl-title");
const subEl = () => document.getElementById("dl-sub");
const noteEl = () => document.getElementById("dl-note");
const successEl = () => document.getElementById("dl-success");
const submitBtn = () => document.getElementById("dl-submit") as HTMLButtonElement | null;
const keyWrap = () => document.getElementById("dl-key-wrap");
const mktWrap = () => document.getElementById("dl-mkt-wrap");
const noKeyEl = () => document.getElementById("dl-no-key");

let mode: Mode = "buy";
let selectedPrice = "$29.99 / year · 1 Mac";

function readLead(): Lead | null {
  try {
    const raw = localStorage.getItem(LEAD_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Lead;
    if (parsed?.email) return parsed;
  } catch {
    /* ignore */
  }
  return null;
}

function saveLead(lead: Lead) {
  localStorage.setItem(LEAD_KEY, JSON.stringify(lead));
}

function saveLicenseHint(email: string, key: string, plan: string, macs: number) {
  localStorage.setItem(
    LICENSE_KEY,
    JSON.stringify({ email, key, plan, macs, activatedAt: new Date().toISOString() }),
  );
}

function selectedPlan(): "monthly" | "yearly" | "once" {
  const params = new URLSearchParams(location.search);
  const fromQuery = params.get("plan");
  if (fromQuery === "monthly" || fromQuery === "once" || fromQuery === "yearly") return fromQuery;
  const note = document.getElementById("pn")?.textContent?.toLowerCase() || "";
  if (note.includes("one-time") || note.includes("once")) return "once";
  if (note.includes("month") && !note.includes("year")) return "monthly";
  const pressed =
    document.querySelector('#sp button[aria-pressed="true"]')?.textContent?.toLowerCase() || "";
  if (pressed.includes("month")) return "monthly";
  if (pressed.includes("one")) return "once";
  return "yearly";
}

function selectedMacs(): 1 | 2 | 5 {
  const params = new URLSearchParams(location.search);
  const q = Number(params.get("macs") || 0);
  if (q === 1 || q === 2 || q === 5) return q;
  const label = document.querySelector('#sm button[aria-pressed="true"]')?.textContent || "1";
  if (label.includes("5")) return 5;
  if (label.includes("2")) return 2;
  return 1;
}

function pricingLabel(): string {
  const price = document.getElementById("pp")?.textContent?.replace(/\s+/g, " ").trim() || "$29.99";
  const note = document.getElementById("pn")?.textContent?.trim() || "";
  const macs =
    document.querySelector('#sm button[aria-pressed="true"]')?.textContent?.trim() || "1 Mac";
  return `${price} · ${macs}${note ? ` · ${note}` : ""}`;
}

function resetSuccessUI() {
  const s = successEl();
  if (s) {
    s.hidden = true;
    s.innerHTML = "";
  }
  const f = form();
  if (f) f.hidden = false;
}

function setFieldVisibility(next: Mode) {
  const isBuy = next === "buy";
  if (keyWrap()) keyWrap()!.hidden = !isBuy;
  if (mktWrap()) mktWrap()!.hidden = isBuy;
  if (noKeyEl()) noKeyEl()!.hidden = !isBuy;

  const keyInput = form()?.elements.namedItem("license_key") as HTMLInputElement | null;
  if (keyInput) keyInput.required = isBuy;
}

function openModal(next: Mode) {
  mode = next;
  selectedPrice = pricingLabel();
  const m = modal();
  if (!m) return;
  m.hidden = false;
  resetSuccessUI();
  setFieldVisibility(next);

  if (titleEl()) {
    titleEl()!.textContent = next === "buy" ? "Buy iClearer" : "Create your free account";
  }
  if (subEl()) {
    subEl()!.textContent =
      next === "buy"
        ? "Enter the email and license key from your free account. After you pay, that same key becomes paid for the Mac seats you selected — we won’t issue a new one."
        : "We’ll email you a free license key. Then come back here, enter that key, and pay to upgrade it.";
  }
  if (submitBtn()) {
    submitBtn()!.hidden = false;
    submitBtn()!.disabled = false;
    submitBtn()!.onclick = null;
    submitBtn()!.textContent =
      next === "buy" ? "Continue to checkout" : "Create account & get key";
  }
  if (noteEl()) {
    noteEl()!.innerHTML =
      next === "buy"
        ? `Selected: <strong>${selectedPrice}</strong>. You’ll keep your current key.`
        : "Free account first → get your <code>ICLR-…</code> key by email → then upgrade that same key.";
  }

  const lead = readLead();
  const f = form();
  const keyInput = f?.elements.namedItem("license_key") as HTMLInputElement | null;
  if (f && lead?.email) {
    (f.elements.namedItem("email") as HTMLInputElement).value = lead.email;
  }
  const params = new URLSearchParams(location.search);
  const emailQ = params.get("email");
  const keyQ = params.get("key");
  if (f && emailQ) {
    (f.elements.namedItem("email") as HTMLInputElement).value = emailQ;
  }
  if (f && keyQ && keyInput) {
    keyInput.value = keyQ;
  }
}

function closeModal() {
  const m = modal();
  if (m) m.hidden = true;
  resetSuccessUI();
}

/** Instant DMG download — no email/name gate. Sign-up lives in Buy → Create account. */
function triggerDownload() {
  void bumpSharedDownloadCount({});
  const a = document.createElement("a");
  a.href = DMG_URL;
  a.download = "iClearer.dmg";
  document.body.appendChild(a);
  a.click();
  a.remove();
}

function goCreateAccount() {
  const email = String(
    (form()?.elements.namedItem("email") as HTMLInputElement | null)?.value || "",
  ).trim();
  openModal("create");
  if (email) {
    const emailInput = form()?.elements.namedItem("email") as HTMLInputElement | null;
    if (emailInput) emailInput.value = email;
  }
}

function showPaidSuccess(email: string, key: string, plan: string, macs: number) {
  saveLicenseHint(email, key, plan, macs);

  const f = form();
  if (f) f.hidden = true;
  if (noKeyEl()) noKeyEl()!.hidden = true;
  if (noteEl()) noteEl()!.innerHTML = "";
  if (submitBtn()) submitBtn()!.hidden = true;

  if (titleEl()) titleEl()!.textContent = "Payment successful";
  if (subEl()) {
    subEl()!.textContent =
      "You’re all set. Sign in to iClearer with the same license key — we did not create a new one.";
  }

  const s = successEl();
  if (!s) return;
  s.hidden = false;
  s.innerHTML = `
    <div class="lic-box">
      <strong>Paid successfully</strong><br>
      Email: ${email}<br>
      License key: <code>${key}</code><br>
      Plan: ${plan} · ${macs} Mac${macs === 1 ? "" : "s"}<br><br>
      Open the Mac app → <em>Sign in or activate</em> and paste this key.
    </div>
    <p style="margin:16px 0 10px">
      <a class="btn" href="${DMG_URL}" download="iClearer.dmg" id="dl-success-download">Download iClearer for Mac</a>
    </p>
    <p class="fine"><a href="#install">How to install</a> · Already have the app? Sign in with the key above.</p>
    <button type="button" class="btn" id="dl-success-close" style="margin-top:8px;background:transparent;border:1.5px solid var(--ln);box-shadow:none;color:var(--fg)!important">Close</button>
  `;
  document.getElementById("dl-success-close")?.addEventListener("click", () => closeModal());
}

function showCreatedAccount(email: string) {
  const f = form();
  if (f) f.hidden = true;
  if (noKeyEl()) noKeyEl()!.hidden = true;
  if (submitBtn()) submitBtn()!.hidden = true;
  if (noteEl()) noteEl()!.innerHTML = "";

  if (titleEl()) titleEl()!.textContent = "Check your email";
  if (subEl()) {
    subEl()!.textContent = `We sent your free license key to ${email}. Use that same key when you buy.`;
  }

  const s = successEl();
  if (!s) return;
  s.hidden = false;
  s.innerHTML = `
    <div class="lic-box">
      <strong>Account created</strong><br>
      Check <code>${email}</code> for your <code>ICLR-…</code> license key.<br><br>
      Then click Buy iClearer, enter that key, and pay. We upgrade the same key — no new key after payment.
    </div>
    <p style="margin:16px 0 10px">
      <a class="btn" href="${DMG_URL}" download="iClearer.dmg">Download iClearer for Mac</a>
    </p>
    <button type="button" class="btn" id="dl-created-buy" style="margin-top:8px">Buy iClearer next</button>
    <button type="button" class="btn" id="dl-created-close" style="margin-top:8px;background:transparent;border:1.5px solid var(--ln);box-shadow:none;color:var(--fg)!important">Close</button>
  `;
  document.getElementById("dl-created-buy")?.addEventListener("click", () => {
    openModal("buy");
    const emailInput = form()?.elements.namedItem("email") as HTMLInputElement | null;
    if (emailInput) emailInput.value = email;
  });
  document.getElementById("dl-created-close")?.addEventListener("click", () => closeModal());
}

async function onSubmit(event: Event) {
  event.preventDefault();
  const f = form();
  if (!f) return;
  const data = new FormData(f);
  const email = String(data.get("email") || "").trim();
  const key = String(data.get("license_key") || "").trim();
  const marketing = Boolean(data.get("marketing"));

  if (mode === "buy") {
    if (!email || !key) {
      if (noteEl()) {
        noteEl()!.textContent = "Enter your email and license key, or create an account below.";
      }
      return;
    }
  } else if (!email) {
    return;
  }

  saveLead({ email, marketing });
  const btn = submitBtn();
  if (btn) {
    btn.disabled = true;
    btn.textContent = mode === "buy" ? "Working…" : "Creating account…";
  }

  try {
    if (mode === "buy") {
      const plan = selectedPlan();
      const macs = selectedMacs();
      const result = await startCheckout({ email, key, marketing, plan, macs });
      if (!result.ok) {
        if (noteEl()) noteEl()!.textContent = result.error || "Checkout failed.";
        return;
      }
      showPaidSuccess(
        email,
        (result.key || key).toUpperCase(),
        result.plan || plan,
        result.macs || macs,
      );
      return;
    }

    const result = await signup(email, marketing);
    if (!result.ok) {
      if (noteEl()) noteEl()!.textContent = result.error || "Could not create account.";
      return;
    }
    showCreatedAccount(email);
  } finally {
    if (btn && !btn.hidden) {
      btn.disabled = false;
      btn.textContent = mode === "buy" ? "Continue to checkout" : "Create account & get key";
    }
  }
}

function ensurePaddle() {
  const token = import.meta.env.VITE_PADDLE_CLIENT_TOKEN as string | undefined;
  if (!token || typeof document === "undefined") return;
  if ((window as unknown as { Paddle?: unknown }).Paddle) return;
  if (document.getElementById("paddle-js")) return;
  const s = document.createElement("script");
  s.id = "paddle-js";
  s.src = "https://cdn.paddle.com/paddle/v2/paddle.js";
  s.async = true;
  s.onload = () => {
    const Paddle = (
      window as unknown as {
        Paddle?: {
          Environment: { set: (e: string) => void };
          Initialize: (o: { token: string }) => void;
        };
      }
    ).Paddle;
    if (!Paddle) return;
    if (token.startsWith("test_")) Paddle.Environment.set("sandbox");
    Paddle.Initialize({ token });
  };
  document.head.appendChild(s);
}

function wireActions() {
  ensurePaddle();

  document.querySelectorAll<HTMLElement>("[data-action]").forEach((el) => {
    el.addEventListener("click", (event) => {
      event.preventDefault();
      const action = el.getAttribute("data-action");
      if (action === "download") triggerDownload();
      if (action === "buy") openModal("buy");
    });
  });
  document.getElementById("dl-close")?.addEventListener("click", closeModal);
  document.getElementById("dl-create-account")?.addEventListener("click", (e) => {
    e.preventDefault();
    goCreateAccount();
  });
  modal()?.addEventListener("click", (event) => {
    if (event.target === modal()) closeModal();
  });
  form()?.addEventListener("submit", onSubmit);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeModal();
  });

  const params = new URLSearchParams(location.search);
  if (params.get("buy") === "1") {
    setTimeout(() => openModal("buy"), 300);
  }
  if (params.get("signup") === "1" || params.get("create") === "1") {
    setTimeout(() => openModal("create"), 300);
  }

  const cmds: Record<string, string> = {
    dmg: (document.getElementById("cmd-dmg")?.textContent || "").trim(),
    apps: "xattr -dr com.apple.quarantine /Applications/iClearer.app && open /Applications/iClearer.app",
    one: (document.getElementById("cmd-one")?.textContent || "").trim(),
  };
  document.querySelectorAll<HTMLButtonElement>(".install-copy").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const key = btn.getAttribute("data-copy") || "";
      try {
        await navigator.clipboard.writeText(cmds[key] || "");
        btn.textContent = "Copied";
        btn.classList.add("ok");
        setTimeout(() => {
          btn.textContent = "Copy";
          btn.classList.remove("ok");
        }, 1600);
      } catch {
        btn.textContent = "Select & copy";
      }
    });
  });
}

wireActions();
