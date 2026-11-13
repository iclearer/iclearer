/**
 * Single source of truth for facts the SEO build repeats across pages,
 * structured data, sitemap.xml and llms.txt.
 *
 * Keep these in step with the product:
 *   prices   → mac/Sources/Pricing.swift and public/landing-proto.js
 *   version  → mac/Resources/Info.plist
 */
export const ORIGIN = "https://www.iclearer.com";
export const SITE_NAME = "iClearer";
export const SUPPORT_EMAIL = "iclearerglobal@gmail.com";
export const VERSION = "1.0.1";
export const MIN_MACOS = "macOS 13 Ventura or later";
export const UPDATED = "2026-11-12";
export const OG_IMAGE = `${ORIGIN}/og.png`;
export const LOGO = `${ORIGIN}/assets/png/icon-glass-light-512.png`;
export const DOWNLOAD_URL = `${ORIGIN}/downloads/iClearer.dmg`;

export const SEATS = [1, 2, 5];
export const PRICES = {
  monthly: [4.99, 7.99, 12.99],
  yearly: [29.99, 44.99, 74.99],
  once: [79.99, 119.99, 189.99],
};
export const PLAN_LABEL = { monthly: "Monthly", yearly: "Yearly", once: "One-time" };
export const FREE_CLEANUP = "500 MB";
export const REFUND_DAYS = 14;

export const TAGLINE = "Clear space. Keep control.";
export const ONE_LINER =
  "iClearer is a Mac cleaner that finds the hidden caches, logs, app leftovers, developer files and large files filling your Mac, shows exactly how much space you will free, and moves what you choose to the Trash.";

export const ORG_DESCRIPTION =
  "iClearer is the team behind iClearer, a Mac cleaner app for macOS that finds what is filling a Mac and frees up storage safely.";

/**
 * Official iClearer profiles on other sites (Product Hunt, X, LinkedIn, YouTube…).
 * These go into the Organization "sameAs" so search engines and AI assistants can
 * connect them to this site. Only real, live profile URLs. Leave empty until they exist.
 */
export const SAME_AS = [];

/** Only features that exist in the shipping Mac app. */
export const FEATURES = [
  "Scans for app caches, system caches, logs and temporary files",
  "Labels every item Safe or Ask first before anything moves",
  "Moves items to the Trash instead of deleting them, with undo",
  "History of every cleanup, with restore",
  "Storage Map of the whole disk",
  "Large and old file finder with preview",
  "App uninstaller that removes leftover files",
  "Builders pack for developer and AI tool caches: npm, pnpm, Yarn, pip, Homebrew, Xcode DerivedData, CocoaPods, Gradle, Cursor, VS Code, iOS Simulator, Docker and Ollama models",
  "Never selects Keychain, accounts, editor user data, API tokens, SSH keys, .env files or git repositories",
  "Checks Time Machine before removing anything that cannot be rebuilt",
  "Runs on Intel and Apple silicon Macs",
];

export const money = (n) => `$${n.toFixed(2)}`;
export const seatLabel = (n) => (n === 1 ? "1 Mac" : `${n} Macs`);

export function longDate(iso) {
  const [y, m, d] = iso.split("-").map(Number);
  const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  return `${d} ${months[m - 1]} ${y}`;
}
