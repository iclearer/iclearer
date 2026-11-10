/** Ed25519 license blob sign/verify + ICLR key generation. */

const textEncoder = new TextEncoder();

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64.replace(/\s+/g, ""));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToB64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

function bytesToB64Url(bytes: Uint8Array): string {
  return bytesToB64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64UrlToBytes(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? "" : "=".repeat(4 - (s.length % 4));
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/") + pad;
  return b64ToBytes(b64);
}

export type LicenseClaims = {
  v: 1;
  email: string;
  key: string;
  plan: "free" | "monthly" | "yearly" | "once";
  macs: number;
  device_hash: string;
  verified_at: number; // unix seconds
  grace_days: number;
};

async function importPrivateKey(): Promise<CryptoKey> {
  const b64 = Deno.env.get("LICENSE_SIGNING_PRIVATE_KEY_B64") ?? "";
  if (!b64) throw new Error("LICENSE_SIGNING_PRIVATE_KEY_B64 is not set");
  return await crypto.subtle.importKey(
    "pkcs8",
    b64ToBytes(b64),
    { name: "Ed25519" },
    false,
    ["sign"],
  );
}

export async function importPublicKeyFromEnv(): Promise<CryptoKey> {
  const b64 = Deno.env.get("LICENSE_SIGNING_PUBLIC_KEY_B64") ?? "";
  if (!b64) throw new Error("LICENSE_SIGNING_PUBLIC_KEY_B64 is not set");
  return await crypto.subtle.importKey(
    "spki",
    b64ToBytes(b64),
    { name: "Ed25519" },
    true,
    ["verify"],
  );
}

export async function signLicenseBlob(claims: LicenseClaims): Promise<string> {
  const payload = bytesToB64Url(textEncoder.encode(JSON.stringify(claims)));
  const key = await importPrivateKey();
  const sig = new Uint8Array(
    await crypto.subtle.sign("Ed25519", key, textEncoder.encode(payload)),
  );
  return `${payload}.${bytesToB64Url(sig)}`;
}

export async function verifyLicenseBlob(
  blob: string,
  publicKey?: CryptoKey,
): Promise<LicenseClaims | null> {
  const [payload, sig] = blob.split(".");
  if (!payload || !sig) return null;
  const key = publicKey ?? (await importPublicKeyFromEnv());
  const ok = await crypto.subtle.verify(
    "Ed25519",
    key,
    b64UrlToBytes(sig),
    textEncoder.encode(payload),
  );
  if (!ok) return null;
  try {
    return JSON.parse(new TextDecoder().decode(b64UrlToBytes(payload))) as LicenseClaims;
  } catch {
    return null;
  }
}

/** ICLR-XXXX-XXXX-XXXX (16 hex chars in 4 groups). */
export function generateLicenseKey(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0").toUpperCase()).join("");
  return `ICLR-${hex.slice(0, 4)}-${hex.slice(4, 8)}-${hex.slice(8, 12)}`;
}

export function graceDaysTotal(): number {
  const ok = Number(Deno.env.get("GRACE_DAYS_OK") ?? "24");
  const warn = Number(Deno.env.get("GRACE_DAYS_WARN") ?? "6");
  return Math.max(1, ok + warn);
}

export async function sha256Hex(input: string): Promise<string> {
  const dig = await crypto.subtle.digest("SHA-256", textEncoder.encode(input));
  return Array.from(new Uint8Array(dig), (b) => b.toString(16).padStart(2, "0")).join("");
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}
