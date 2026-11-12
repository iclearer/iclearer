/**
 * Tells IndexNow (Bing, Yandex, Seznam, Naver and others) that the pages in
 * the live sitemap changed. Run after a deploy that adds or edits pages:
 *
 *   node scripts/seo/indexnow.mjs
 *
 * Google does not use IndexNow; submit the sitemap in Google Search Console.
 */
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { ORIGIN } from "./site.mjs";

const PUBLIC = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "public");
const keyFile = readdirSync(PUBLIC).find((f) => /^[a-f0-9]{32}\.txt$/.test(f));
if (!keyFile) throw new Error("No IndexNow key file in public/");
const key = readFileSync(join(PUBLIC, keyFile), "utf8").trim();
const host = new URL(ORIGIN).host;

// Use the live sitemap, so only URLs that are really deployed are submitted.
const live = await fetch(`${ORIGIN}/sitemap.xml`);
if (!live.ok) throw new Error(`${ORIGIN}/sitemap.xml returned ${live.status}. Deploy first.`);
const urlList = [...(await live.text()).matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);

const liveKey = await fetch(`${ORIGIN}/${keyFile}`);
if (!liveKey.ok || (await liveKey.text()).trim() !== key) throw new Error(`Key file is not live at ${ORIGIN}/${keyFile}. Deploy first.`);

const res = await fetch("https://api.indexnow.org/indexnow", {
  method: "POST",
  headers: { "Content-Type": "application/json; charset=utf-8" },
  body: JSON.stringify({ host, key, keyLocation: `${ORIGIN}/${keyFile}`, urlList }),
});
console.log(`IndexNow: ${res.status} ${res.statusText} for ${urlList.length} URLs`);
if (!res.ok) {
  console.error(await res.text());
  process.exit(1);
}
