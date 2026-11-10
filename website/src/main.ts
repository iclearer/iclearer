import "./landing.css";
import { bumpSharedDownloadCount } from "./lib/iclearerDownloads";
import { resendKey, startCheckout, signup } from "./lib/licenseApi";

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
const submitBtn = () => document.getElementById("dl-submit") as HTMLButtonElement | null;

let mode: Mode = "download";
let selectedPrice = "$29.99 / year · 1 Mac";

function readLead(): Lead | null {
  try {
    const raw = localStorage.getItem(LEAD_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Lead;
    if (parsed?.email && parsed?.name) return parsed;
  } catch {
    /* ignore */
  }
  return null;
}

function saveLead(lead: Lead) {
  localStorage.setItem(LEAD_KEY, JSON.stringify(lead));
}

function saveLicenseHint(email: string, plan: string, macs: number) {
  localStorage.setItem(
    LICENSE_KEY,
    JSON.stringify({ email, plan, macs, activatedAt: new Date().toISOString() }),
  );
}

function selectedPlan(): "monthly" | "yearly" | "once" {
  const params = new URLSearchParams(location.search);
  const fromQuery = params.get("plan");
  if (fromQuery === "monthly" || fromQuery === "once" || fromQuery === "yearly") return fromQuery;
  const note = document.getElementById("pn")?.textContent?.toLowerCase() || "";
  if (note.includes("one-time") || note.includes("once")) return "once";
  if (note.includes("month") && !note.includes("year")) return "monthly";
  const pressed = document.querySelector('#sb button[aria-pressed="true"]')?.textContent?.toLowerCase() || "";
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

function openModal(next: Mode) {
  mode = next;
  selectedPrice = pricingLabel();
  const m = modal();
  if (!m) return;
  m.hidden = false;
  if (titleEl()) {
    titleEl()!.textContent = next === "buy" ? "Buy iClearer" : "Download iClearer";
  }
  if (subEl()) {
    subEl()!.textContent =
      next === "buy"
        ? "We’ll email your license key with Resend. Open the Mac app → Sign in or activate."
        : "We use your email for your license, receipts and security notices.";
  }
  if (submitBtn()) {
    submitBtn()!.textContent = next === "buy" ? "Continue to checkout" : "Download .dmg";
    submitBtn()!.onclick = null;
  }
  if (noteEl()) {
    noteEl()!.innerHTML =
      next === "buy"
        ? `Selected: <strong>${selectedPrice}</strong>. After payment (or while payments are in sandbox), your key is emailed.`
        : "Requires macOS 13 or later · Intel and Apple silicon";
  }
  const lead = readLead();
  const f = form();
  if (f && lead) {
    (f.elements.namedItem("name") as HTMLInputElement).value = lead.name;
    (f.elements.namedItem("email") as HTMLInputElement).value = lead.email;
  }
  const params = new URLSearchParams(location.search);
  const emailQ = params.get("email");
  if (f && emailQ) {
    (f.elements.namedItem("email") as HTMLInputElement).value = emailQ;
  }
}

function closeModal() {
  const m = modal();
  if (m) m.hidden = true;
}

async function startDownload(lead: Lead) {
  await bumpSharedDownloadCount({ name: lead.name, email: lead.email });
  // Also ensure a free license exists + key emailed on first download.
  await signup(lead.email, Boolean(lead.marketing));
  const a = document.createElement("a");
  a.href = DMG_URL;
  a.download = "iClearer.dmg";
  document.body.appendChild(a);
  a.click();
  a.remove();
}

function showKeySent(email: string, plan: string, macs: number) {
  saveLicenseHint(email, plan, macs);
  if (!noteEl()) return;
  noteEl()!.innerHTML = `
    <div class="lic-box">
      <strong>Check your email</strong><br>
      We sent your license key to <code>${email}</code>.<br>
      Open iClearer → <em>Sign in or activate</em> and paste the key.<br>
      Plan: ${plan} · ${macs} Mac${macs === 1 ? "" : "s"}
    </div>`;
}

async function onSubmit(event: Event) {
  event.preventDefault();
  const f = form();
  if (!f) return;
  const data = new FormData(f);
  const name = String(data.get("name") || "").trim();
  const email = String(data.get("email") || "").trim();
  const marketing = Boolean(data.get("marketing"));
  if (!name || !email) return;
  const lead: Lead = { name, email, marketing };
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
      const result = await startCheckout({ email, name, marketing, plan, macs });
      if (!result.ok) {
        if (noteEl()) noteEl()!.textContent = result.error || "Checkout failed.";
        return;
      }
      showKeySent(email, plan, macs);
      if (btn) {
        btn.disabled = false;
        btn.textContent = "Resend key";
        btn.onclick = async (e) => {
          e.preventDefault();
          btn.disabled = true;
          const again = await resendKey(email);
          btn.disabled = false;
          if (noteEl()) {
            noteEl()!.textContent = again.message || (again.ok ? "Key resent." : again.error || "Failed");
          }
        };
      }
      return;
    }
    await startDownload(lead);
    closeModal();
  } finally {
    if (btn && mode === "download") {
      btn.disabled = false;
      btn.textContent = "Download .dmg";
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
  modal()?.addEventListener("click", (event) => {
    if (event.target === modal()) closeModal();
  });
  form()?.addEventListener("submit", onSubmit);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeModal();
  });

  // Deep link from the Mac upgrade sheet: ?buy=1&plan=yearly&macs=1&email=
  const params = new URLSearchParams(location.search);
  if (params.get("buy") === "1" || location.hash.includes("pricing")) {
    if (params.get("buy") === "1") {
      setTimeout(() => openModal("buy"), 300);
    }
  }
}

wireActions();
