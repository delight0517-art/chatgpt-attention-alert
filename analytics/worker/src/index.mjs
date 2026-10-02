const APP_ID = "chatgpt-attention-alert";
const EVENTS = new Set(["page_view", "release_click", "readme_click", "intent_click"]);
const PAGES = new Set(["home", "persistent-alerts", "auth-context", "privacy"]);
const SOURCES = new Set(["google", "bing", "github", "kakao", "x", "reddit", "direct", "other"]);
const MEDIUMS = new Set(["organic", "referral", "social", "direct", "other"]);
const CAMPAIGNS = new Set(["kr_pilot_2026q4", "none", "other"]);
const DEVICES = new Set(["phone", "tablet", "computer", "unknown"]);
const LOCALES = new Set(["ko", "en", "other"]);

function headers(origin, allowedOrigin) {
  const accepted = origin === allowedOrigin;
  return {
    "access-control-allow-origin": accepted ? origin : "null",
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "content-type",
    "access-control-max-age": "86400",
    "cache-control": "no-store",
    vary: "Origin"
  };
}

function json(data, status, responseHeaders) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...responseHeaders }
  });
}

function validRegion(value) {
  return typeof value === "string" && /^[A-Z0-9-]{0,8}$/.test(value) ? value : "";
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("origin") || "";
    const responseHeaders = headers(origin, env.ALLOWED_ORIGIN);
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: origin === env.ALLOWED_ORIGIN ? 204 : 403, headers: responseHeaders });
    }
    if (origin && origin !== env.ALLOWED_ORIGIN) return json({ error: "origin_not_allowed" }, 403, responseHeaders);

    if (request.method === "POST" && url.pathname === "/event") {
      if (origin !== env.ALLOWED_ORIGIN) return json({ error: "origin_required" }, 403, responseHeaders);
      const declaredLength = Number(request.headers.get("content-length") || 0);
      if (declaredLength > 1024) return json({ error: "payload_too_large" }, 413, responseHeaders);
      const raw = await request.text();
      if (new TextEncoder().encode(raw).length > 1024) return json({ error: "payload_too_large" }, 413, responseHeaders);
      let body;
      try { body = JSON.parse(raw); } catch { return json({ error: "invalid_json" }, 400, responseHeaders); }

      const country = request.cf?.country || "";
      const region = validRegion(String(request.cf?.regionCode || "").toUpperCase());
      if (!/^[A-Z]{2}$/.test(country)
          || body?.appId !== APP_ID
          || !PAGES.has(body.page)
          || !EVENTS.has(body.event)
          || !LOCALES.has(body.locale)
          || body.client !== "web"
          || !DEVICES.has(body.deviceClass)
          || !SOURCES.has(body.source)
          || !MEDIUMS.has(body.medium)
          || !CAMPAIGNS.has(body.campaign)) {
        return json({ error: "invalid_event" }, 400, responseHeaders);
      }

      const home = body.page === "home";
      const experiment = home ? "kr-home-thumbnail-v1" : "";
      const variant = home ? body.variant : "default";
      if ((home && !["a", "b"].includes(variant)) || (!home && body.variant !== "default")) {
        return json({ error: "invalid_variant" }, 400, responseHeaders);
      }

      await env.DB.prepare(`
        INSERT INTO marketing_event_daily
          (day, country, region_code, locale, client, device_class, page, experiment, variant, source, medium, campaign, event, count)
        VALUES (date('now'), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
        ON CONFLICT(day, country, region_code, locale, client, device_class, page, experiment, variant, source, medium, campaign, event)
        DO UPDATE SET count = count + 1
      `).bind(country, region, body.locale, body.client, body.deviceClass, body.page, experiment, variant, body.source, body.medium, body.campaign, body.event).run();
      return json({ ok: true }, 202, responseHeaders);
    }

    if (request.method === "GET" && url.pathname === "/summary") {
      const period = url.searchParams.get("period") === "all" ? "all" : "30d";
      const where = period === "all" ? "" : "WHERE day >= date('now', '-29 days')";
      const result = await env.DB.prepare(`
        SELECT country, region_code AS regionCode, locale, client, device_class AS deviceClass,
               page, experiment, variant, source, medium, campaign,
               SUM(CASE WHEN event = 'page_view' THEN count ELSE 0 END) AS pageViews,
               SUM(CASE WHEN event = 'release_click' THEN count ELSE 0 END) AS releaseClicks,
               SUM(CASE WHEN event = 'readme_click' THEN count ELSE 0 END) AS readmeClicks,
               SUM(CASE WHEN event = 'intent_click' THEN count ELSE 0 END) AS intentClicks
        FROM marketing_event_daily ${where}
        GROUP BY country, region_code, locale, client, device_class, page, experiment, variant, source, medium, campaign
        ORDER BY country, region_code, page, experiment, variant, source, medium, campaign
      `).all();
      return json({ appId: APP_ID, period, rows: result.results || [] }, 200, responseHeaders);
    }

    return json({ error: "not_found" }, 404, responseHeaders);
  }
};
