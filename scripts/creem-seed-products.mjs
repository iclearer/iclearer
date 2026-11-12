#!/usr/bin/env node
/**
 * Create the 9 iClearer Creem products (1/2/5 Mac × monthly/yearly/once)
 * matching app + website Pricing.swift amounts, then print env map values.
 *
 * Usage:
 *   export CREEM_API_KEY=creem_test_...   # or creem_ live key
 *   node scripts/creem-seed-products.mjs
 */
const apiKey = process.env.CREEM_API_KEY || "";
if (!apiKey) {
  console.error("Set CREEM_API_KEY first (creem_test_… or creem_…).");
  process.exit(1);
}

const base = apiKey.startsWith("creem_test_")
  ? "https://test-api.creem.io"
  : "https://api.creem.io";

const catalog = [
  { plan: "yearly", macs: 1, name: "iClearer Yearly · 1 Mac", price: 2999, billing_type: "recurring", billing_period: "every-year" },
  { plan: "yearly", macs: 2, name: "iClearer Yearly · 2 Macs", price: 4499, billing_type: "recurring", billing_period: "every-year" },
  { plan: "yearly", macs: 5, name: "iClearer Yearly · 5 Macs", price: 7499, billing_type: "recurring", billing_period: "every-year" },
  { plan: "monthly", macs: 1, name: "iClearer Monthly · 1 Mac", price: 499, billing_type: "recurring", billing_period: "every-month" },
  { plan: "monthly", macs: 2, name: "iClearer Monthly · 2 Macs", price: 799, billing_type: "recurring", billing_period: "every-month" },
  { plan: "monthly", macs: 5, name: "iClearer Monthly · 5 Macs", price: 1299, billing_type: "recurring", billing_period: "every-month" },
  { plan: "once", macs: 1, name: "iClearer One-time · 1 Mac", price: 7999, billing_type: "onetime" },
  { plan: "once", macs: 2, name: "iClearer One-time · 2 Macs", price: 11999, billing_type: "onetime" },
  { plan: "once", macs: 5, name: "iClearer One-time · 5 Macs", price: 18999, billing_type: "onetime" },
];

const forward = {};
const reverse = {};

for (const item of catalog) {
  const body = {
    name: item.name,
    description: `${item.name}. Moves junk to Trash. Keychain stays.`,
    price: item.price,
    currency: "USD",
    billing_type: item.billing_type,
    tax_category: "saas",
    external_id: `iclearer-${item.plan}-${item.macs}`,
    metadata: { plan: item.plan, macs: String(item.macs) },
  };
  if (item.billing_period) body.billing_period = item.billing_period;

  const res = await fetch(`${base}/v1/products`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "Idempotency-Key": `iclearer-${item.plan}-${item.macs}`,
    },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) {
    console.error("FAIL", item.name, res.status, JSON.stringify(data).slice(0, 400));
    process.exit(1);
  }
  const id = data.id;
  console.log("OK", item.name, id, `$${(item.price / 100).toFixed(2)}`);
  forward[`${item.plan}:${item.macs}`] = id;
  reverse[id] = { plan: item.plan, macs: item.macs };
}

console.log("\n# Forward map (plan:macs → product) — set as CREEM_PRODUCT_MAP_JSON on Supabase");
console.log(JSON.stringify(forward));
console.log("\n# Reverse map (product → plan/macs) — same JSON is fine if keys are prod_ ids;");
console.log("# license-api uses plan:macs keys; webhook uses prod_ keys. Store BOTH shapes:");
const combined = { ...forward };
for (const [id, meta] of Object.entries(reverse)) {
  combined[id] = meta;
}
// Actually webhook needs prod→plan and license-api needs plan:macs→prod.
// Keep them as two secrets OR one object with both.
console.log("\nCREEM_PRODUCT_MAP_JSON (checkout create — plan:macs → prod):");
console.log(JSON.stringify(forward));
console.log("\nCREEM_PRODUCT_REVERSE_JSON (webhook — prod → plan/macs):");
console.log(JSON.stringify(reverse));
