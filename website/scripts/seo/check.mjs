/**
 * Checks the built site (dist/) the way a crawler would see it.
 * Runs at the end of `npm run build`; a failure stops the deploy so a broken
 * page, link or structured-data block never ships.
 *
 *   errors    break search or AI visibility: fail the build
 *   warnings  worth a look (lengths): printed only
 */
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { ORIGIN, PRICES, money } from "./site.mjs";
import { GUIDES } from "./guides.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const DIST = join(ROOT, "dist");
const errors = [];
const warnings = [];
const err = (page, msg) => errors.push(`${page}: ${msg}`);
const warn = (page, msg) => warnings.push(`${page}: ${msg}`);

if (!existsSync(DIST)) {
  console.error("seo check: dist/ not found. Run `npm run build` first.");
  process.exit(1);
}

const vercel = JSON.parse(readFileSync(join(ROOT, "vercel.json"), "utf8"));

/** Resolve a site path to a file in dist, following vercel.json rewrites. */
function resolve(path) {
  let p = path.split("#")[0].split("?")[0];
  if (p === "" || p === "/") return join(DIST, "index.html");
  for (const r of vercel.rewrites ?? []) {
    if (r.source === p) return join(DIST, r.destination);
    const m = r.source.match(/^(.*)\/:(\w+)$/);
    if (m && p.startsWith(m[1] + "/") && !p.slice(m[1].length + 1).includes("/")) {
      const candidate = join(DIST, r.destination.replace(`:${m[2]}`, p.slice(m[1].length + 1)));
      if (existsSync(candidate)) return candidate;
    }
  }
  return join(DIST, p);
}
const exists = (path) => existsSync(resolve(path));

const decode = (s) =>
  s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ");
const norm = (s) => s.replace(/\s+/g, " ").trim();
const visible = (html) =>
  norm(
    decode(
      html
        .replace(/<script[\s\S]*?<\/script>/g, " ")
        .replace(/<style[\s\S]*?<\/style>/g, " ")
        .replace(/<!--[\s\S]*?-->/g, " ")
        .replace(/<[^>]+>/g, ""),
    ),
  );

/** Tags can split words differently from the schema text, so compare without spaces. */
const squash = (s) => s.replace(/\s+/g, "");

function checkPage(file, { path, indexable = true }) {
  const html = readFileSync(join(DIST, file), "utf8");
  const page = path;

  const title = html.match(/<title>([\s\S]*?)<\/title>/)?.[1];
  if (!title) err(page, "missing <title>");
  else if (decode(title).length > 60) warn(page, `title is ${decode(title).length} characters (aim for 60 or fewer)`);

  if (!indexable) {
    if (!/<meta name="robots" content="noindex/.test(html)) err(page, "should be noindex");
    return;
  }

  const desc = html.match(/<meta name="description" content="([^"]*)"/)?.[1];
  if (!desc) err(page, "missing meta description");
  else {
    const n = decode(desc).length;
    if (n > 160 || n < 70) warn(page, `description is ${n} characters (aim for 70–160)`);
  }

  const canonical = html.match(/<link rel="canonical" href="([^"]*)"/)?.[1];
  const want = `${ORIGIN}${path === "/" ? "/" : path}`;
  if (canonical !== want) err(page, `canonical is ${canonical ?? "missing"}, expected ${want}`);

  const h1 = html.match(/<h1[\s>]/g) ?? [];
  if (h1.length !== 1) err(page, `has ${h1.length} <h1> elements, expected 1`);

  if (/<meta name="robots" content="[^"]*noindex/.test(html)) err(page, "is marked noindex");

  for (const prop of ["og:title", "og:description", "og:url", "og:image"]) {
    if (!new RegExp(`<meta property="${prop}" content="[^"]+"`).test(html)) err(page, `missing ${prop}`);
  }
  const ogImage = html.match(/<meta property="og:image" content="([^"]+)"/)?.[1];
  if (ogImage?.startsWith(ORIGIN) && !exists(ogImage.slice(ORIGIN.length))) err(page, `og:image file not found: ${ogImage}`);

  // Structured data must parse, and FAQ data must match what visitors can read.
  const text = squash(visible(html));
  for (const m of html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)) {
    let data;
    try {
      data = JSON.parse(m[1]);
    } catch (e) {
      err(page, `JSON-LD does not parse: ${e.message}`);
      continue;
    }
    for (const node of data["@graph"] ?? [data]) {
      if (node["@type"] !== "FAQPage") continue;
      if (!node.mainEntity?.length) err(page, "FAQPage has no questions");
      for (const q of node.mainEntity ?? []) {
        if (!text.includes(squash(q.name))) err(page, `FAQ question in structured data is not visible on the page: “${q.name}”`);
        if (!text.includes(squash(q.acceptedAnswer.text))) err(page, `FAQ answer in structured data is not visible on the page: “${q.name}”`);
      }
    }
  }

  // Internal links and assets.
  for (const m of html.matchAll(/\s(?:href|src)="(\/[^"]*)"/g)) {
    const target = m[1];
    if (target.startsWith("//")) continue;
    if (!exists(target)) err(page, `broken link: ${target}`);
    const hash = target.split("#")[1];
    if (hash && target.split("#")[0] === "/") {
      const home = readFileSync(join(DIST, "index.html"), "utf8");
      if (!new RegExp(`id="${hash}"`).test(home)) err(page, `anchor not found on homepage: #${hash}`);
    }
  }
  // <a> only: <use href="#…"> points at SVG symbols that landing-proto.js adds at runtime.
  for (const m of html.matchAll(/<a\s[^>]*href="#([^"]+)"/g)) {
    if (!new RegExp(`id="${m[1]}"`).test(html)) err(page, `anchor not found on page: #${m[1]}`);
  }
}

/* Pages */
checkPage("index.html", { path: "/" });
checkPage("about.html", { path: "/about" });
checkPage("guides/index.html", { path: "/guides" });
for (const g of GUIDES) checkPage(`guides/${g.slug}.html`, { path: `/guides/${g.slug}` });
for (const p of ["terms", "privacy", "refund"]) checkPage(`${p}.html`, { path: `/${p}` });
checkPage("404.html", { path: "/404", indexable: false });

/* Every guide is reachable: the hub links all of them, the homepage links the hub and the featured ones. */
const home = readFileSync(join(DIST, "index.html"), "utf8");
const hub = readFileSync(join(DIST, "guides/index.html"), "utf8");
if (!home.includes('href="/guides"')) err("/", "homepage does not link to /guides");
if (!home.includes('href="/about"')) err("/", "homepage does not link to /about");
for (const g of GUIDES) {
  if (!hub.includes(`href="/guides/${g.slug}"`)) err("/guides", `hub does not link to /guides/${g.slug}`);
  if (g.featured && !home.includes(`href="/guides/${g.slug}"`)) err("/", `homepage does not link to featured guide /guides/${g.slug}`);
}

/* Prices on the page, in the pricing script and in site.mjs must agree. */
const homeText = visible(home);
for (const p of Object.values(PRICES).flat()) if (!homeText.includes(money(p))) err("/", `price ${money(p)} is in site.mjs but not on the homepage`);
const proto = readFileSync(join(DIST, "landing-proto.js"), "utf8");
for (const [label, key] of [["Yearly", "yearly"], ["Monthly", "monthly"], ['"One-time"', "once"]]) {
  if (!proto.includes(`${label}: [${PRICES[key].join(", ")}]`)) err("/", `landing-proto.js ${label} prices differ from site.mjs`);
}

/* robots.txt, sitemap.xml, llms.txt */
const robots = existsSync(join(DIST, "robots.txt")) ? readFileSync(join(DIST, "robots.txt"), "utf8") : "";
if (!robots.includes(`Sitemap: ${ORIGIN}/sitemap.xml`)) err("/robots.txt", "missing Sitemap line");
if (/^Disallow:\s*\/\s*$/m.test(robots)) err("/robots.txt", "blocks the whole site");

const sitemap = existsSync(join(DIST, "sitemap.xml")) ? readFileSync(join(DIST, "sitemap.xml"), "utf8") : "";
const locs = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
if (!locs.length) err("/sitemap.xml", "missing or empty");
for (const loc of locs) {
  if (!loc.startsWith(ORIGIN)) err("/sitemap.xml", `URL is not on ${ORIGIN}: ${loc}`);
  else if (!exists(loc.slice(ORIGIN.length))) err("/sitemap.xml", `URL does not resolve: ${loc}`);
}
if (!locs.includes(`${ORIGIN}/about`)) err("/sitemap.xml", "missing /about");
for (const g of GUIDES) if (!locs.includes(`${ORIGIN}/guides/${g.slug}`)) err("/sitemap.xml", `missing /guides/${g.slug}`);

for (const f of ["llms.txt", "llms-full.txt"]) {
  if (!existsSync(join(DIST, f))) {
    err(`/${f}`, "missing");
    continue;
  }
  const t = readFileSync(join(DIST, f), "utf8");
  for (const m of t.matchAll(/\]\((https?:\/\/[^)\s]+)\)/g)) {
    if (m[1].startsWith(ORIGIN) && !exists(m[1].slice(ORIGIN.length))) err(`/${f}`, `link does not resolve: ${m[1]}`);
  }
}

/* IndexNow key file: <key>.txt containing the key. */
const keyFile = readdirSync(DIST).find((f) => /^[a-f0-9]{32}\.txt$/.test(f));
if (!keyFile) warn("/", "no IndexNow key file");
else if (readFileSync(join(DIST, keyFile), "utf8").trim() !== keyFile.replace(".txt", "")) err(`/${keyFile}`, "IndexNow key file content does not match its name");

for (const w of warnings) console.warn(`seo check: warning: ${w}`);
if (errors.length) {
  for (const e of errors) console.error(`seo check: ERROR: ${e}`);
  console.error(`seo check: ${errors.length} error(s).`);
  process.exit(1);
}
console.log(`seo check: ok (${7 + GUIDES.length} pages, ${locs.length} sitemap URLs${warnings.length ? `, ${warnings.length} warning(s)` : ""})`);
