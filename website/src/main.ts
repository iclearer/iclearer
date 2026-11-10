import "./landing.css";
import { bumpSharedDownloadCount } from "./lib/iclearerDownloads";
import { startCheckout, signup } from "./lib/licenseApi";

const DMG_URL = "/downloads/iClearer.dmg";
const LEAD_KEY = "iclearer-download-lead";
const LICENSE_KEY = "iclearer-license";

type Mode = "download" | "buy";

type Lead = { name: string; email: string; marketing?: boolean };

const modal = () => document.getElementById("dl-modal");
const form = () => document.getElementById("dl-form") as HTMLFormElement | null;
const titleEl = () => document.getElementById("dl-title");
const subEl = () => document.getElementById("dl-sub");
const noteEl = () => document.getElementById("dl-note");
const successEl = () => document.getElementById("dl-success");
const submitBtn = () => document.getElementById("dl-submit") as HTMLButtonElement | null;
const nameWrap = () => document.getElementById("dl-name-wrap");
const keyWrap = () => document.getElementById("dl-key-wrap");
const mktWrap = () => document.getElementById("dl-mkt-wrap");
const noKeyEl = () => document.getElementById("dl-no-key");

let mode: Mode = "download";
let selectedPrice = "$29.99 / year · 1 Mac";
/** After pay success, require explicit Close (X / backdrop / button still work). */
let paySuccessLock = false;

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
    document.querySelector('#sb button[aria-pressed="true"]')?.textContent?.toLowerCase() || "";
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
  paySuccessLock = false;
  const s = successEl();
  if (s) {
    s.hidden = true;
    s.innerHTML = "";
  }
  const f = form();
  if (f) f.hidden = false;
}

function openModal(next: Mode) {
  mode = next;
  selectedPrice = pricingLabel();
  const m = modal();
  if (!m) return;
  m.hidden = false;
  resetSuccessUI();

  const isBuy = next === "buy";
  if (nameWrap()) nameWrap()!.hidden = isBuy;
  if (keyWrap()) keyWrap()!.hidden = !isBuy;
  if (mktWrap()) mktWrap()!.hidden = isBuy;
  if (noKeyEl()) noKeyEl()!.hidden = !isBuy;

  const nameInput = form()?.elements.namedItem("name") as HTMLInputElement | null;
  const keyInput = form()?.elements.namedItem("license_key") as HTMLInputElement | null;
  if (nameInput) nameInput.required = !isBuy;
  if (keyInput) keyInput.required = isBuy;

  if (titleEl()) {
    titleEl()!.textContent = isBuy ? "Upgrade your license" : "Download iClearer";
  }
  if (subEl()) {
    subEl()!.textContent = isBuy
      ? "Enter the email and license key from your free account. After you pay, that same key becomes paid — we won’t issue a new one."
      : "We use your email for your license, receipts and security notices.";
  }
  if (submitBtn()) {
    submitBtn()!.hidden = false;
    submitBtn()!.textContent = isBuy ? "Continue to checkout" : "Download .dmg";
    submitBtn()!.onclick = null;
    submitBtn()!.disabled = false;
  }
  if (noteEl()) {
    noteEl()!.innerHTML = isBuy
      ? `Selected: <strong>${selectedPrice}</strong>. You’ll keep your current key.`
      : "Requires macOS 13 or later · Intel and Apple silicon";
  }

  const lead = readLead();
  const f = form();
  if (f && lead?.email) {
    (f.elements.namedItem("email") as HTMLInputElement).value = lead.email;
    if (lead.name && nameInput) nameInput.value = lead.name;
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

async function startDownload(lead: Lead) {
  await bumpSharedDownloadCount({ name: lead.name, email: lead.email });
  await signup(lead.email, Boolean(lead.marketing));
  const a = document.createElement("a");
  a.href = DMG_URL;
  a.download = "iClearer.dmg";
  document.body.appendChild(a);
  a.click();
  a.remove();
}

/** Switch buy modal into “create free account” (download signup) while keeping email. */
function goCreateAccount() {
  const email = String(
    (form()?.elements.namedItem("email") as HTMLInputElement | null)?.value || "",
  ).trim();
  openModal("download");
  if (titleEl()) titleEl()!.textContent = "Create your free account";
  if (subEl()) {
    subEl()!.textContent =
      "We’ll email you a free license key. Then come back to Buy iClearer, enter that key, and pay to upgrade it.";
  }
  if (submitBtn()) submitBtn()!.textContent = "Create account & get key";
  if (email) {
    const emailInput = form()?.elements.namedItem("email") as HTMLInputElement | null;
    if (emailInput) emailInput.value = email;
  }
  if (noteEl()) {
    noteEl()!.innerHTML =
      "Free account first → get your <code>ICLR-…</code> key by email → then upgrade that same key.";
  }
}

function showPaidSuccess(email: string, key: string, plan: string, macs: number) {
  saveLicenseHint(email, key, plan, macs);
  paySuccessLock = true;

  const f = form();
  if (f) f.hidden = true;
  if (noKeyEl()) noKeyEl()!.hidden = true;
  if (noteEl()) noteEl()!.innerHTML = "";

  if (titleEl()) titleEl()!.textContent = "Payment successful";
  if (subEl()) {
    subEl()!.textContent =
      "You’re all set. Sign in to iClearer with the same license key — we did not create a new one.";
  }

  const s = successEl();
  if (s) {
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
      <p class="fine">Already have the app? Just sign in with the key above.</p>
      <button type="button" class="btn" id="dl-success-close" style="margin-top:8px;background:transparent;border:1px solid rgba(255,255,255,0.2)">Close</button>
    `;
    document.getElementById("dl-success-close")?.addEventListener("click", () => closeModal());
  }

  if (submitBtn()) submitBtn()!.hidden = true;
}

async function onSubmit(event: Event) {
  event.preventDefault();
  const f = form();
  if (!f) return;
  const data = new FormData(f);
  const name = String(data.get("name") || "").trim();
  const email = String(data.get("email") || "").trim();
  const key = String(data.get("license_key") || "").trim();
  const marketing = Boolean(data.get("marketing"));

  if (mode === "buy") {
    if (!email || !key) return;
  } else {
    if (!name || !email) return;
  }

  const lead: Lead = { name: name || email.split("@")[0] || "User", email, marketing };
  saveLead(lead);
  const btn = submitBtn();
  if (btn) {
    btn.disabled = true;
    btn.textContent = mode === "buy" ? "Working…" : "Starting download…";
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
    await startDownload(lead);
    if (noteEl()) {
      noteEl()!.innerHTML = `
        <div class="lic-box">
          <strong>Check your email</strong><br>
          We sent your free license key to <code>${email}</code>.<br>
          Then open <em>Buy iClearer</em>, enter that key, and pay to upgrade it.
        </div>`;
    }
    if (btn) {
      btn.disabled = false;
      btn.textContent = "Buy iClearer next";
      btn.onclick = (e) => {
        e.preventDefault();
        openModal("buy");
        const emailInput = form()?.elements.namedItem("email") as HTMLInputElement | null;
        if (emailInput) emailInput.value = email;
      };
    }
  } finally {
    if (btn && mode === "download" && btn.textContent !== "Buy iClearer next") {
      btn.disabled = false;
      btn.textContent = "Download .dmg";
    } else if (btn && mode === "buy" && !paySuccessLock) {
      btn.disabled = false;
      btn.textContent = "Continue to checkout";
    }
  }
}

function wireActions() {
  document.querySelectorAll<HTMLElement>("[data-action]").forEach((el) => {
    el.addEventListener("click", (event) => {
      event.preventDefault();
      const action = el.getAttribute("data-action") as Mode | null;
      if (action === "download" || action === "buy") openModal(action);
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
}

wireActions();
