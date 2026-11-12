/**
 * SEO build. Run with `npm run seo` (also runs before `vite build`).
 *
 * Generates, from site.mjs + guides.mjs + the visible homepage HTML:
 *   public/guides/<slug>.html   one page per guide
 *   public/guides/index.html    guides hub
 *   public/sitemap.xml
 *   public/llms.txt             short index for AI assistants
 *   public/llms-full.txt        everything in plain text
 * and refreshes the generated blocks in index.html (between
 * <!-- seo:NAME --> and <!-- /seo:NAME --> markers):
 *   jsonld    structured data; the FAQ part is read from the visible FAQ
 *   reviews   seed feedback, so it exists without JavaScript
 *   price / price-note / price-list   default plan, same reason
 *   guides    homepage links to every guide
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  DOWNLOAD_URL,
  FEATURES,
  FREE_CLEANUP,
  LOGO,
  MIN_MACOS,
  OG_IMAGE,
  ONE_LINER,
  ORIGIN,
  PLAN_LABEL,
  PRICES,
  REFUND_DAYS,
  SEATS,
  SITE_NAME,
  SUPPORT_EMAIL,
  TAGLINE,
  UPDATED,
  VERSION,
  longDate,
  money,
  seatLabel,
} from "./site.mjs";
import { CTA_NOTE, GUIDES } from "./guides.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const PUBLIC = join(ROOT, "public");
const read = (p) => readFileSync(join(ROOT, p), "utf8");
const write = (p, s) => {
  mkdirSync(dirname(join(ROOT, p)), { recursive: true });
  writeFileSync(join(ROOT, p), s);
};

const ORG_ID = `${ORIGIN}/#organization`;
const SITE_ID = `${ORIGIN}/#website`;
const APP_ID = `${ORIGIN}/#app`;
const ROBOTS = "index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1";

/* ---------- small helpers ---------- */

const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

const ENTITIES = { "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&#39;": "'", "&nbsp;": " " };
const decode = (s) => s.replace(/&(amp|lt|gt|quot|#39|nbsp);/g, (m) => ENTITIES[m]);

/** Visible text of an HTML fragment. */
const text = (html) => decode(html.replace(/<[^>]+>/g, "")).replace(/\s+/g, " ").trim();

/** JSON-LD script tag. `<` is escaped so content can never close the tag. */
const jsonld = (graph) =>
  `<script type="application/ld+json">${JSON.stringify({ "@context": "https://schema.org", "@graph": graph }).replace(/</g, "\\u003c")}</script>`;

const guideUrl = (slug) => `${ORIGIN}/guides/${slug}`;
const bySlug = (slug) => {
  const g = GUIDES.find((x) => x.slug === slug);
  if (!g) throw new Error(`Unknown guide slug: ${slug}`);
  return g;
};

/** Minimal HTML → Markdown for llms-full.txt. Handles only what guides use. */
function toMarkdown(html) {
  let s = html;
  s = s.replace(/<pre><code>([\s\S]*?)<\/code><\/pre>/g, (_, c) => `\n\`\`\`\n${c.trim()}\n\`\`\`\n`);
  s = s.replace(/<table>([\s\S]*?)<\/table>/g, (_, t) => {
    const rows = [...t.matchAll(/<tr>([\s\S]*?)<\/tr>/g)].map((r) =>
      [...r[1].matchAll(/<t[hd]>([\s\S]*?)<\/t[hd]>/g)].map((c) => inline(c[1])),
    );
    if (!rows.length) return "";
    const head = `| ${rows[0].join(" | ")} |\n| ${rows[0].map(() => "---").join(" | ")} |`;
    return `\n${head}\n${rows.slice(1).map((r) => `| ${r.join(" | ")} |`).join("\n")}\n`;
  });
  const items = (l) => [...l.matchAll(/<li>([\s\S]*?)<\/li>/g)].map((m) => inline(m[1]));
  s = s.replace(/<ol>([\s\S]*?)<\/ol>/g, (_, l) => `\n${items(l).map((c, i) => `${i + 1}. ${c}`).join("\n")}\n`);
  s = s.replace(/<ul>([\s\S]*?)<\/ul>/g, (_, l) => `\n${items(l).map((c) => `- ${c}`).join("\n")}\n`);
  s = s.replace(/<h2[^>]*>([\s\S]*?)<\/h2>/g, (_, c) => `\n## ${inline(c)}\n`);
  s = s.replace(/<h3[^>]*>([\s\S]*?)<\/h3>/g, (_, c) => `\n### ${inline(c)}\n`);
  s = s.replace(/<p[^>]*>([\s\S]*?)<\/p>/g, (_, c) => `\n${inline(c)}\n`);
  s = s.replace(/<\/?div[^>]*>/g, "");
  return decode(s).replace(/\n{3,}/g, "\n\n").trim();

  function inline(h) {
    return h
      .replace(/<a href="([^"]+)">([\s\S]*?)<\/a>/g, (_, href, t) => `[${t}](${href.startsWith("/") ? ORIGIN + href : href})`)
      .replace(/<code>([\s\S]*?)<\/code>/g, "`$1`")
      .replace(/<\/kbd>\s*<kbd>/g, "-") // <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>G</kbd> → Shift-Command-G
      .replace(/<[^>]+>/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }
}

/* ---------- shared page chrome ---------- */

function head({ title, description, url, type = "website", graph, modified }) {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
    <title>${esc(title)}</title>
    <meta name="description" content="${esc(description)}" />
    <link rel="canonical" href="${url}" />
    <meta name="robots" content="${ROBOTS}" />
    <meta name="theme-color" content="#3B7CB0" />
    <meta property="og:type" content="${type}" />
    <meta property="og:site_name" content="${SITE_NAME}" />
    <meta property="og:title" content="${esc(title)}" />
    <meta property="og:description" content="${esc(description)}" />
    <meta property="og:url" content="${url}" />
    <meta property="og:image" content="${OG_IMAGE}" />
    <meta property="og:image:width" content="1200" />
    <meta property="og:image:height" content="630" />
    <meta property="og:image:alt" content="iClearer, the Mac cleaner. ${TAGLINE}" />
    <meta property="og:locale" content="en_US" />${modified ? `\n    <meta property="article:modified_time" content="${modified}" />` : ""}
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="${esc(title)}" />
    <meta name="twitter:description" content="${esc(description)}" />
    <meta name="twitter:image" content="${OG_IMAGE}" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <link rel="icon" type="image/png" sizes="48x48" href="/assets/png/favicon-48.png" />
    <link rel="apple-touch-icon" href="/assets/png/apple-touch-icon-180.png" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" />
    <link rel="stylesheet" href="/guide.css" />
    ${jsonld(graph)}
  </head>
  <body>
    <header class="g-hd">
      <a class="g-logo" href="/"><img src="/assets/png/icon-glass-light-120.png" width="36" height="36" alt="" />iClearer</a>
      <nav class="g-nav" aria-label="Main">
        <a href="/guides" class="g-keep">Guides</a>
        <a href="/#features">Features</a>
        <a href="/#pricing">Pricing</a>
        <a class="g-btn" href="/downloads/iClearer.dmg" download="iClearer.dmg">Download Free</a>
      </nav>
    </header>
`;
}

const FOOT = `
    <footer class="g-ft">
      <div class="g-ft-in">
        <a href="/">iClearer home</a>
        <a href="/guides">Guides</a>
        <a href="/#pricing">Pricing</a>
        <a href="/privacy">Privacy Policy</a>
        <a href="/terms">Terms of Service</a>
        <a href="/refund">Refund Policy</a>
        <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>
        <p>Copyright © 2026 iClearer. iClearer is not affiliated with Apple Inc. Mac, macOS, MacBook, iMac, Xcode and iPhone are trademarks of Apple Inc.</p>
      </div>
    </footer>
  </body>
</html>
`;

/* ---------- guide pages ---------- */

function guidePage(g) {
  const url = guideUrl(g.slug);
  const title = `${g.title} | ${SITE_NAME}`;
  const graph = [
    {
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "iClearer", item: `${ORIGIN}/` },
        { "@type": "ListItem", position: 2, name: "Guides", item: `${ORIGIN}/guides` },
        { "@type": "ListItem", position: 3, name: g.h1, item: url },
      ],
    },
    {
      "@type": "Article",
      "@id": `${url}#article`,
      headline: g.h1,
      description: g.description,
      image: OG_IMAGE,
      datePublished: UPDATED,
      dateModified: UPDATED,
      inLanguage: "en",
      mainEntityOfPage: url,
      author: { "@type": "Organization", "@id": ORG_ID, name: SITE_NAME, url: `${ORIGIN}/` },
      publisher: { "@type": "Organization", "@id": ORG_ID, name: SITE_NAME, logo: { "@type": "ImageObject", url: LOGO } },
      about: { "@id": APP_ID },
    },
    {
      "@type": "FAQPage",
      "@id": `${url}#faq`,
      mainEntity: g.faq.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })),
    },
  ];

  return `${head({ title, description: g.description, url, type: "article", graph, modified: UPDATED })}
    <main>
      <nav class="g-bc" aria-label="Breadcrumb"><a href="/">iClearer</a> › <a href="/guides">Guides</a> › ${esc(g.card)}</nav>
      <article>
        <h1>${esc(g.h1)}</h1>
        <p class="g-meta">Updated <time datetime="${UPDATED}">${longDate(UPDATED)}</time> · By the iClearer team</p>

        <div class="g-answer">
          <h2>Short answer</h2>
          ${g.answer}
        </div>

        <nav class="g-toc" aria-label="On this page">
          <b>On this page</b>
          <ol>
${g.toc.map(([id, label]) => `            <li><a href="#${id}">${esc(label)}</a></li>`).join("\n")}
            <li><a href="#faq">Frequently asked questions</a></li>
          </ol>
        </nav>
${g.body}
        <section class="g-cta" aria-labelledby="cta">
          <h2 id="cta">${esc(g.cta.heading)}</h2>
          ${g.cta.text}
          <div class="g-cta-row">
            <a class="g-btn lg green" href="/downloads/iClearer.dmg" download="iClearer.dmg">Download Free</a>
            <a class="g-btn lg ol" href="/#pricing">See pricing</a>
          </div>
          <small>${esc(CTA_NOTE)} Needs ${MIN_MACOS}, Intel or Apple silicon.</small>
        </section>

        <section class="g-faq">
          <h2 id="faq">Frequently asked questions</h2>
${g.faq.map((f) => `          <h3>${esc(f.q)}</h3>\n          <p>${esc(f.a)}</p>`).join("\n")}
        </section>

        <section class="g-rel">
          <h2>Related guides</h2>
          <ul>
${g.related
  .map((s) => bySlug(s))
  .map((r) => `            <li><a href="/guides/${r.slug}">${esc(r.h1)}<span>${esc(r.description)}</span></a></li>`)
  .join("\n")}
          </ul>
        </section>
      </article>
    </main>
${FOOT}`;
}

function guidesIndex() {
  const url = `${ORIGIN}/guides`;
  const title = `Mac Storage Guides: Free Up Space Safely | ${SITE_NAME}`;
  const description =
    "Step-by-step guides to free up space on a Mac: storage full, System Data, caches, large files, uninstalling apps, and cleanup for developers.";
  const graph = [
    {
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "iClearer", item: `${ORIGIN}/` },
        { "@type": "ListItem", position: 2, name: "Guides", item: url },
      ],
    },
    {
      "@type": "CollectionPage",
      "@id": `${url}#page`,
      url,
      name: "Mac storage guides",
      description,
      isPartOf: { "@id": SITE_ID },
      publisher: { "@id": ORG_ID },
      dateModified: UPDATED,
      mainEntity: {
        "@type": "ItemList",
        itemListElement: GUIDES.map((g, i) => ({ "@type": "ListItem", position: i + 1, name: g.h1, url: guideUrl(g.slug) })),
      },
    },
  ];
  return `${head({ title, description, url, graph })}
    <main class="g-index">
      <nav class="g-bc" aria-label="Breadcrumb"><a href="/">iClearer</a> › Guides</nav>
      <h1>Mac storage guides</h1>
      <p>Plain, step-by-step answers for a Mac that is running out of space. Every guide shows the manual way first, what is safe to delete and what is not.</p>
      <ul class="g-cards">
${GUIDES.map((g) => `        <li><a href="/guides/${g.slug}"><h2>${esc(g.h1)}</h2><p>${esc(g.description)}</p></a></li>`).join("\n")}
      </ul>
      <section class="g-cta" aria-labelledby="cta">
        <h2 id="cta">Or let iClearer do it in one scan</h2>
        <p>${esc(ONE_LINER)}</p>
        <div class="g-cta-row">
          <a class="g-btn lg green" href="/downloads/iClearer.dmg" download="iClearer.dmg">Download Free</a>
          <a class="g-btn lg ol" href="/#pricing">See pricing</a>
        </div>
        <small>${esc(CTA_NOTE)} Needs ${MIN_MACOS}, Intel or Apple silicon.</small>
      </section>
    </main>
${FOOT}`;
}

/* ---------- homepage blocks ---------- */

/** Replace what sits between <!-- seo:NAME --> and <!-- /seo:NAME -->. */
function inject(html, name, content) {
  const re = new RegExp(`(<!-- seo:${name} -->)[\\s\\S]*?(<!-- /seo:${name} -->)`);
  if (!re.test(html)) throw new Error(`index.html is missing the <!-- seo:${name} --> marker`);
  return html.replace(re, (_, a, b) => `${a}${content}${b}`);
}

/**
 * The visible homepage FAQ, as [{q, a}]. Structured data is built from this,
 * so it always matches what visitors see. Add data-noschema to a <details>
 * to keep it on the page but out of the structured data.
 */
function homeFaq(html) {
  const sec = html.match(/<section class="sec faq"[\s\S]*?<\/section>/);
  if (!sec) throw new Error("index.html: FAQ section not found");
  return [...sec[0].matchAll(/<details([^>]*)><summary>([\s\S]*?)<\/summary>([\s\S]*?)<\/details>/g)]
    .filter((m) => !m[1].includes("data-noschema"))
    .map((m) => ({ q: text(m[2]), a: text(m[3]) }));
}

function offers() {
  const out = [
    {
      "@type": "Offer",
      name: "iClearer Free",
      description: `Unlimited scans and ${FREE_CLEANUP} of cleanup in total.`,
      price: "0",
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
      url: `${ORIGIN}/`,
    },
  ];
  for (const plan of ["yearly", "monthly", "once"]) {
    SEATS.forEach((n, i) => {
      out.push({
        "@type": "Offer",
        name: `iClearer ${PLAN_LABEL[plan]}, ${seatLabel(n)}`,
        description:
          plan === "once"
            ? `One-time purchase of version 1 for ${seatLabel(n)}. Unlimited cleanup.`
            : `Unlimited cleanup for ${seatLabel(n)}, billed ${plan}. Cancel anytime.`,
        price: PRICES[plan][i].toFixed(2),
        priceCurrency: "USD",
        availability: "https://schema.org/InStock",
        url: `${ORIGIN}/#pricing`,
      });
    });
  }
  return out;
}

function homeGraph(html) {
  const title = text(html.match(/<title>([\s\S]*?)<\/title>/)[1]);
  const description = decode(html.match(/<meta name="description" content="([^"]*)"/)[1]);
  return [
    {
      "@type": "Organization",
      "@id": ORG_ID,
      name: SITE_NAME,
      url: `${ORIGIN}/`,
      logo: { "@type": "ImageObject", url: LOGO, width: 512, height: 512 },
      email: SUPPORT_EMAIL,
      contactPoint: { "@type": "ContactPoint", contactType: "customer support", email: SUPPORT_EMAIL, availableLanguage: "English" },
    },
    {
      "@type": "WebSite",
      "@id": SITE_ID,
      url: `${ORIGIN}/`,
      name: SITE_NAME,
      description: ONE_LINER,
      inLanguage: "en",
      publisher: { "@id": ORG_ID },
    },
    {
      "@type": "WebPage",
      "@id": `${ORIGIN}/#webpage`,
      url: `${ORIGIN}/`,
      name: title,
      description,
      inLanguage: "en",
      isPartOf: { "@id": SITE_ID },
      about: { "@id": APP_ID },
      primaryImageOfPage: OG_IMAGE,
      dateModified: UPDATED,
    },
    {
      "@type": "SoftwareApplication",
      "@id": APP_ID,
      name: SITE_NAME,
      alternateName: "iClearer for Mac",
      description: ONE_LINER,
      url: `${ORIGIN}/`,
      image: OG_IMAGE,
      applicationCategory: "UtilitiesApplication",
      applicationSubCategory: "Mac cleaner",
      operatingSystem: "macOS 13 or later",
      processorRequirements: "Intel or Apple silicon",
      softwareVersion: VERSION,
      downloadUrl: DOWNLOAD_URL,
      installUrl: `${ORIGIN}/#install`,
      featureList: FEATURES,
      publisher: { "@id": ORG_ID },
      offers: offers(),
    },
    {
      "@type": "FAQPage",
      "@id": `${ORIGIN}/#faq`,
      mainEntity: homeFaq(html).map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })),
    },
  ];
}

/* Reviews: the same markup main.ts renders, so nothing shifts when it takes over. */
const TONES = [
  ["#7fb8e6", "#2d6da4"],
  ["#8fe0bd", "#1f9a67"],
  ["#f6c36b", "#dc8a16"],
  ["#9a8ae0", "#5d4fc2"],
  ["#5fd0c8", "#2a8f8f"],
  ["#f19a8e", "#d1544a"],
];
function initials(name) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
function headline(t) {
  const trimmed = t.trim();
  const match = trimmed.match(/(\d+(?:\.\d+)?\s*(?:GB|GBs|MB))/i);
  if (match) return match[1].replace(/\s+/g, " ") + " recovered.";
  const first = trimmed.split(/[.!?]/)[0]?.trim() || trimmed;
  return first.length > 42 ? first.slice(0, 40).trimEnd() + "…" : first + ".";
}
function reviewsHtml() {
  const seed = JSON.parse(read("src/seedFeedback.json"));
  return seed
    .map((item, i) => {
      const [a, b] = TONES[i % TONES.length];
      return `<li><div class="rvw-av" style="--a:${a};--b:${b}">${esc(initials(item.name))}</div><div class="rvw-bd"><b>${esc(headline(item.text))}</b><p>“${esc(item.text)}”</p></div><div class="rvw-au">${esc(item.name)}</div></li>`;
    })
    .join("");
}

function homepage() {
  let html = read("index.html");
  const yearly = PRICES.yearly[0];
  html = inject(html, "reviews", reviewsHtml());
  html = inject(html, "price", `$${(yearly / 12).toFixed(2)}<small> / month</small>`);
  html = inject(html, "price-note", `Billed ${money(yearly)} per year. Cancel anytime.`);
  html = inject(
    html,
    "price-list",
    [
      "Unlimited cleanup",
      "Item names, details and exact locations",
      "Full Storage Map, large files and Quick Look",
      "App uninstaller with leftovers",
      "Builders pack for developers and AI tools",
      "History with restore and a never-touch list",
      "Bug and safety fixes",
      "Use on 1 Mac (each Mac is linked to your key)",
    ]
      .map((x) => `<li>${x}</li>`)
      .join(""),
  );
  html = inject(
    html,
    "guides",
    `\n${GUIDES.map((g) => `    <li><a href="/guides/${g.slug}"><h3>${esc(g.card)}</h3><p>${esc(g.description)}</p></a></li>`).join("\n")}\n    `,
  );
  // Last, so the FAQ and title it reads are final.
  html = inject(html, "jsonld", `\n    ${jsonld(homeGraph(html))}\n    `);
  write("index.html", html);
  return html;
}

/* ---------- sitemap + llms ---------- */

function sitemap() {
  const urls = [
    [`${ORIGIN}/`, "1.0"],
    [`${ORIGIN}/guides`, "0.8"],
    ...GUIDES.map((g) => [guideUrl(g.slug), "0.9"]),
    [`${ORIGIN}/privacy`, "0.2"],
    [`${ORIGIN}/terms`, "0.2"],
    [`${ORIGIN}/refund`, "0.2"],
  ];
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map(([loc, pr]) => `  <url><loc>${loc}</loc><lastmod>${UPDATED}</lastmod><priority>${pr}</priority></url>`).join("\n")}
</urlset>
`;
}

function pricingTable() {
  const rows = ["yearly", "monthly", "once"].map(
    (p) => `| ${PLAN_LABEL[p]}${p === "yearly" ? " (per year)" : p === "monthly" ? " (per month)" : " (pay once, version 1)"} | ${PRICES[p].map(money).join(" | ")} |`,
  );
  return `| Plan | ${SEATS.map(seatLabel).join(" | ")} |\n| --- | --- | --- | --- |\n${rows.join("\n")}`;
}

function llms() {
  return `# iClearer

> ${ONE_LINER} It runs on ${MIN_MACOS}, on Intel and Apple silicon. Scanning is free; the free plan includes ${FREE_CLEANUP} of cleanup.

Key facts:

- Product: iClearer, a Mac cleaner app (disk cleanup utility for macOS). Website: ${ORIGIN}/
- Not to be confused with "iCleaner" or other similarly named apps. The name is iClearer, with "clear".
- Price: free to scan, ${FREE_CLEANUP} of free cleanup. Unlimited cleanup from ${money(PRICES.yearly[0])} per year, ${money(PRICES.monthly[0])} per month or ${money(PRICES.once[0])} once, for 1 Mac. Plans for 2 and 5 Macs are available.
- Refunds: ${REFUND_DAYS}-day money-back guarantee.
- Safety: every item is labelled Safe or Ask first, everything goes to the Trash with undo, and Keychain, accounts, tokens, SSH keys, .env files and git repositories can never be selected.
- For developers: cleans npm, pnpm, Yarn, pip, Homebrew, Xcode DerivedData, CocoaPods, Gradle, Cursor and VS Code caches, plus iOS Simulator data, Docker data and Ollama models.
- Current version: ${VERSION}. Download: ${DOWNLOAD_URL}
- Support: ${SUPPORT_EMAIL}

## Product

- [iClearer home](${ORIGIN}/): what it does, screenshots, pricing, install steps and FAQ
- [Pricing](${ORIGIN}/#pricing): free plan and paid plans for 1, 2 or 5 Macs
- [Install guide](${ORIGIN}/#install): how to install the DMG on macOS

## Guides

${GUIDES.map((g) => `- [${g.h1}](${guideUrl(g.slug)}): ${g.description}`).join("\n")}

## Policies

- [Privacy Policy](${ORIGIN}/privacy)
- [Terms of Service](${ORIGIN}/terms)
- [Refund Policy](${ORIGIN}/refund)

## Optional

- [Full text of this site for AI assistants](${ORIGIN}/llms-full.txt)
`;
}

function llmsFull(homeHtml) {
  const faq = homeFaq(homeHtml);
  return `# iClearer: full reference

Source: ${ORIGIN}/ · Updated ${longDate(UPDATED)}

## What iClearer is

${ONE_LINER}

- Category: Mac cleaner / disk cleanup utility for macOS
- Requirements: ${MIN_MACOS}; Intel and Apple silicon
- Current version: ${VERSION}
- Download: ${DOWNLOAD_URL}
- Support: ${SUPPORT_EMAIL}
- The name is iClearer (with "clear"). It is not "iCleaner" and is not related to similarly named apps.
- iClearer is not affiliated with Apple Inc.

## What it does

${FEATURES.map((f) => `- ${f}`).join("\n")}

## How it works

1. Scan. iClearer looks for caches, logs, leftovers, large files and apps. Nothing moves yet.
2. Review. Every item says what it is, how big it is, and whether it is Safe (your Mac rebuilds it) or Ask first (larger or system-related; starts unticked).
3. Clean up. The items you chose go to the Trash. Undo works right away, and History keeps every cleanup so it can be restored.

## Pricing (USD)

Scanning is free on every Mac. The free plan includes ${FREE_CLEANUP} of cleanup in total. Paid plans give unlimited cleanup:

${pricingTable()}

Every purchase has a ${REFUND_DAYS}-day money-back guarantee. Subscriptions can be cancelled anytime. A one-time purchase covers version 1.

## Frequently asked questions

${faq.map((f) => `### ${f.q}\n\n${f.a}`).join("\n\n")}

${GUIDES.map(
  (g) => `---

# ${g.h1}

URL: ${guideUrl(g.slug)}

**Short answer.** ${toMarkdown(g.answer)}

${toMarkdown(g.body)}

## ${g.cta.heading}

${toMarkdown(g.cta.text)}

## Frequently asked questions

${g.faq.map((f) => `### ${f.q}\n\n${f.a}`).join("\n\n")}`,
).join("\n\n")}
`;
}

/* ---------- run ---------- */

for (const g of GUIDES) {
  for (const r of g.related) bySlug(r);
  write(`public/guides/${g.slug}.html`, guidePage(g));
}
write("public/guides/index.html", guidesIndex());
const homeHtml = homepage();
write("public/sitemap.xml", sitemap());
write("public/llms.txt", llms());
write("public/llms-full.txt", llmsFull(homeHtml));

console.log(`seo: ${GUIDES.length} guides, sitemap.xml, llms.txt, llms-full.txt, homepage blocks refreshed (${PUBLIC})`);
