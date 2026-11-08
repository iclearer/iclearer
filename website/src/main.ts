import "./landing.css";
import { bumpSharedDownloadCount } from "./lib/iclearerDownloads";

const DMG_URL = "/downloads/iClearer.dmg";
const LEAD_KEY = "iclearer-download-lead";
const LICENSE_KEY = "iclearer-license";

/** Free Pro test user for local/dev testing (no payment required). */
const TEST_LICENSE = {
  email: "test@iclearer.com",
  key: "ICLR-TEST-0001-FREE",
  plan: "yearly" as const,
  macs: 1,
};

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

function saveLicense(email: string) {
  const license = {
    ...TEST_LICENSE,
    email: email || TEST_LICENSE.email,
    activatedAt: new Date().toISOString(),
  };
  localStorage.setItem(LICENSE_KEY, JSON.stringify(license));
  return license;
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
    titleEl()!.textContent = next === "buy" ? "Activate iClearer" : "Download iClearer";
  }
  if (subEl()) {
    subEl()!.textContent =
      next === "buy"
        ? "Payments are not live yet. Enter your details to activate the free test Pro license."
        : "We use your email for your license, receipts and security notices.";
  }
  if (submitBtn()) {
    submitBtn()!.textContent = next === "buy" ? "Activate free test license" : "Download .dmg";
  }
  if (noteEl()) {
    noteEl()!.innerHTML =
      next === "buy"
        ? `Test key <code>${TEST_LICENSE.key}</code> unlocks Pro in the Mac app. Price selected: ${selectedPrice}`
        : "Requires macOS 13 or later · Intel and Apple silicon";
  }
  const lead = readLead();
  const f = form();
  if (f && lead) {
    (f.elements.namedItem("name") as HTMLInputElement).value = lead.name;
    (f.elements.namedItem("email") as HTMLInputElement).value = lead.email;
  }
}

function closeModal() {
  const m = modal();
  if (m) m.hidden = true;
}

async function startDownload(lead: Lead) {
  await bumpSharedDownloadCount({ name: lead.name, email: lead.email });
  const a = document.createElement("a");
  a.href = DMG_URL;
  a.download = "iClearer.dmg";
  document.body.appendChild(a);
  a.click();
  a.remove();
}

function showLicenseCard(email: string) {
  const license = saveLicense(email);
  if (!noteEl()) return;
  noteEl()!.innerHTML = `
    <div class="lic-box">
      <strong>Pro activated for testing</strong><br>
      Email: ${license.email}<br>
      License key: <code>${license.key}</code><br>
      Plan: Yearly · 1 Mac<br>
      Open iClearer → Account → paste this key to unlock paid features.
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
    btn.textContent = mode === "buy" ? "Activating…" : "Starting download…";
  }
  try {
    if (mode === "buy") {
      showLicenseCard(email);
      if (btn) {
        btn.disabled = false;
        btn.textContent = "Download app too";
        btn.onclick = async (e) => {
          e.preventDefault();
          await startDownload(lead);
          closeModal();
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
}

wireActions();
