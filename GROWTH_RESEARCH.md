# ChatGPT Attention Alert growth research archive

## Operating rules

- Append each market, search-promise, page, or creative test with its exact dates, target language, variant, URL, source commit, and evidence. Do not rewrite old observations.
- Separate idea, local source, deployed page, Google-rendered result, site behavior, release download, installation, and sustained use. A click is not a download or active user.
- Begin with the market whose product and support path are actually localized. Treat that as a readiness choice, not a market-size or demand claim. Do not expand campaign targets until the active test has enough evidence or the current market is demonstrably unsuitable.
- Website analytics is opt-in. Preserve only daily aggregate counts by country/first-level region, page, locale, coarse device, experiment and allowlisted campaign label. Do not store IP, browser/user identifiers, exact query/referrer, account names, alert text, or authentication data.
- Use internal links with `?gptaa_qa=1` during QA; flagged loads and browser privacy signals do not emit analytics. Treat consented browser events as approximate, not as people.
- Hold an experiment for at least 28 days. Do not choose a winner below 50 exposures per variant in the target market or without downstream release-click evidence. This floor is a practical observation rule, not proof of statistical significance or causality.
- Google chooses whether and how to show preview images. Set a relevant image and `max-image-preview:large`, then record the actual Google result only when observed. A webpage image A/B is not evidence of which image Google Search or Discover selected.

## KR-MARKET-20261002-01 — Korean pilot and baseline

- **Status (2026-10-02):** registered; aggregate worker is deployed; the updated Pages site is not yet published or live-verified.
- **Target market:** South Korea, Korean locale. Chosen because the helper UI, authentication labels, installation instructions, and main landing copy are Korean. This is a product-readiness choice, not evidence that Korean demand is highest.
- **Other countries:** inbound consenting traffic may be aggregated at country and first-level region, but no non-Korean campaign is selected until the companion and complete setup flow have that market's language. The current English paragraph is not a fully localized product experience.
- **Search-intent hypotheses:** (1) a desktop user wants an attention card to remain while typing and show which ChatGPT/Codex conversation needs action; (2) a user completing a GitHub or other service approval wants the service, account and requested action named together.
- **Search evidence:** the official ChatGPT notifications guide now describes desktop notifications and the Activity view, so do not claim that ChatGPT has no notifications. Search results also show adjacent browser notification tools focused on response completion. Position this companion around a locally invoked, persistent user-action card with chat context, not as a replacement for ChatGPT's built-in completion/activity notifications. Korean user requests are useful hypotheses, not a representative audience survey.
- **Search Console baseline (2026-10-02):** the registered property available to the account is `https://delight0517.github.io/`, a different GitHub Pages hostname. A filter for `/chatgpt-attention-alert/` returned 0 rows for 2026-09-02 through 2026-09-29 (Web, source API, settled through 2026-09-29). The property-wide country report showed Korea and several small non-Korea rows, but these are not attributable to this product and are excluded from its market baseline. The exact product hostname `https://delight0517-art.github.io/` is not yet a connected Search Console property; no exact Google query, product CTR, result thumbnail or indexing state is observed.
- **Search promise baseline:** product site was live at `https://delight0517-art.github.io/chatgpt-attention-alert/`; no `og:image` was set before this study. Google title, snippet and thumbnail were not observed.

## Active test registration

### KR-THUMBNAIL-20261002-01 — Home hero image only

- **Hypothesis:** Korean desktop users will click the release more often when the home-page image clarifies either the disappearing-notification problem or the chat/account context.
- **Control A:** the same Korean headline, body and CTA with a brief system toast beside the persistent ChatGPT Attention Alert card.
- **Variant B:** the exact same page copy and CTA with the alert card grouped around the conversation, service and action context.
- **Only planned changed element:** the home hero image. `og:image` remains fixed to A so the experiment does not claim to randomize Google's result.
- **Assignment:** sticky 50/50 A/B choice in local browser storage, created only after explicit analytics consent. The image assignment and event de-duplication keys are not visitor IDs and are never transmitted.
- **Pages:** `/` is the controlled image experiment; `/ko/persistent-alerts/` and `/ko/auth-context/` are separate search-intent pages. Their visits and release clicks are observational page-level totals, not a randomized comparison of audience segments.
- **Primary metric:** unique-consented-browser-day home page exposures and release-button click count per image variant. Secondary: page-level release clicks, README clicks, and Google Search Console page impressions/clicks when a matching property is available. GitHub release download count is a separate downstream aggregate. No installation or retention telemetry is present.
- **Country/language breakdown:** Cloudflare country and first-level region code, browser language grouped to `ko`, `en`, or `other`, broad device class, and validated source, medium and campaign labels. The active image readout uses only `country=KR` and `locale=ko`; other incoming consented locale/country totals remain descriptive and do not enter that comparison. No city, precise location, raw IP, full referrer, account, exact search query or alert content is retained.
- **Consent / QA:** visitors may decline without losing page or download access; the footer reopens the setting. Do Not Track, Global Privacy Control and `?gptaa_qa=1` disable event sends. Database contains daily aggregate totals only.
- **Stop / winner rule:** keep live at least 28 days. Do not name an image winner below 50 exposures per variant in Korea. If the minimum is reached, compare release-click rates and downstream GitHub download counts, document uncertainty and alternative explanations, and only then update the default page/Google preview candidate.
- **Google result image rule:** 1200×675 PNG candidates, Korean copy, descriptive `og:image` and `max-image-preview:large`. This may enable a large Google preview; Google chooses the actual image. Inspect the live rendered result after crawl. The local A/B result cannot by itself establish Google SERP thumbnail performance.
- **Pre-deployment evidence:** no eligible page experiment rows exist yet. Do not count internal QA, this author's visits, old property-wide Search Console impressions, or the prior GitHub release download as test results.
- **Worker deployment:** `chatgpt-attention-alert-market` deployed to `https://chatgpt-attention-alert-market.imdisablebutgoddisable.workers.dev` on 2026-10-02, version `5ef7bb0c-cea4-4e5c-aaad-cedfdada0d24`. Wrangler confirmed the D1 binding and exact allowed origin. A temporary static preview Worker created by Wrangler's parent-directory auto-detection was deleted immediately. The active shell currently cannot resolve the marketing Worker hostname, so live HTTP preflight and summary reads remain unverified.
- **Next readout:** after Pages is published, verify public routes/assets, sitemap and live worker HTTP behavior, and record workflow status and exact Search Console property/indexing status. Then wait for consented market exposure; avoid launching another country/copy test while this one is accumulating.

### 2026-10-02 deployment readout

- **Source:** commit `0c2ece4` is published on `main`.
- **Pages:** the GitHub Pages deployment workflow `36989041986` completed successfully. The home page, both Korean intent pages, privacy page, sitemap, robots file, analytics script, and both thumbnail assets returned HTTP 200.
- **Validation:** workflow `36989042056` passed macOS source/analytics checks and Windows PowerShell parsing.
- **Aggregate service:** Worker version `5ef7bb0c-cea4-4e5c-aaad-cedfdada0d24` is deployed. Remote D1 reported 0 aggregate rows immediately after deployment; no synthetic visit was inserted. HTTP requests to the Worker hostname could not be verified because this execution environment could not resolve the `workers.dev` hostname. Confirm endpoint resolution and CORS before treating collection as live.
- **Google search:** adding `https://delight0517-art.github.io/` to the connected Search Console workspace returned `not_found`; it must first be added and ownership-verified in Search Console. Sitemap submission, Google query/impression reporting, crawl/index status, and actual Google preview selection are therefore pending.
- **Experiment start:** site publication is not yet an experiment exposure. Start the 28-day observation window only after Worker HTTP/CORS is confirmed and consented Korean traffic has begun; do not infer demand or choose a thumbnail winner from deployments or QA.
