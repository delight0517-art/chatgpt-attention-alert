import assert from "node:assert/strict";
import worker from "./src/index.mjs";

const writes = [];
const db = {
  prepare(sql) {
    return {
      bind(...values) {
        return {
          async run() { writes.push({ sql, values }); return { success: true }; },
          async all() { return { results: [{ page: "home", variant: "a", pageViews: 1 }] }; }
        };
      },
      async all() { return { results: [{ page: "home", variant: "a", pageViews: 1 }] }; }
    };
  }
};
const env = { ALLOWED_ORIGIN: "https://delight0517-art.github.io", DB: db };

function request(path, method = "GET", body = undefined, origin = env.ALLOWED_ORIGIN) {
  const headers = origin ? { origin } : {};
  if (body !== undefined) headers["content-type"] = "application/json";
  const req = new Request(`https://analytics.test${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body)
  });
  req.cf = { country: "KR", regionCode: "KR-11" };
  return req;
}

const valid = {
  appId: "chatgpt-attention-alert",
  page: "home",
  variant: "b",
  event: "page_view",
  locale: "ko",
  client: "web",
  deviceClass: "computer",
  source: "google",
  medium: "organic",
  campaign: "kr_pilot_2026q4"
};

const accepted = await worker.fetch(request("/event", "POST", valid), env);
assert.equal(accepted.status, 202);
assert.equal(writes.length, 1);
assert.match(writes[0].sql, /INSERT INTO marketing_event_daily/);
assert.doesNotMatch(writes[0].sql, /visitorId|ip_address|user_agent/i);
assert.equal(writes[0].values.includes("b"), true);

const refusedOrigin = await worker.fetch(request("/event", "POST", valid, "https://example.invalid"), env);
assert.equal(refusedOrigin.status, 403);
const missingOrigin = await worker.fetch(request("/event", "POST", valid, ""), env);
assert.equal(missingOrigin.status, 403);
const refusedPayload = await worker.fetch(request("/event", "POST", { ...valid, event: "prompt_text" }), env);
assert.equal(refusedPayload.status, 400);
const acceptedLocale = await worker.fetch(request("/event", "POST", { ...valid, locale: "en" }), env);
assert.equal(acceptedLocale.status, 202);
const refusedVariant = await worker.fetch(request("/event", "POST", { ...valid, variant: "delight0517" }), env);
assert.equal(refusedVariant.status, 400);
const summary = await worker.fetch(request("/summary?period=all", "GET", undefined, ""), env);
assert.equal(summary.status, 200);
assert.equal((await summary.json()).period, "all");

console.log("marketing worker checks passed");
