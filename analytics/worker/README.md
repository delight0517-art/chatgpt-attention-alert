# ChatGPT Attention Alert market analytics

This small Cloudflare Worker stores opt-in site research as daily D1 aggregates. It is separate from the desktop companion and from Selah's analytics Worker.

## Data boundary

- Requests are accepted only from `https://delight0517-art.github.io` and only for allowlisted page, event, locale, device, source, medium and campaign labels.
- Country and Cloudflare's first-level region code come from `request.cf`; raw IP addresses, user agents, account identifiers, exact page URLs, search queries, referrers, chat text and authentication data are neither read nor written by this Worker.
- The database has no visitor/session ID. It stores a UTC day, bounded labels and an aggregate integer count.
- `/summary?period=30d` and `/summary?period=all` return only aggregates. The endpoint is public, so never add identifiers or sensitive event names to its schema.
- The site sends no event until consent is chosen. DNT, GPC and `?gptaa_qa=1` suppress event requests.

## Routes

- `POST /event`: append one allowlisted event to a daily aggregate row.
- `GET /summary?period=30d|all`: read the aggregate rows for analysis.

## Operations

```sh
node test.mjs
wrangler d1 migrations apply chatgpt-attention-alert-market --remote
wrangler deploy
```

`wrangler.toml` identifies the dedicated D1 database. No Selah database or Worker is changed by this project.
