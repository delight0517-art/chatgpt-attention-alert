(() => {
  const endpoint = "https://chatgpt-attention-alert-market.imdisablebutgodisable.workers.dev/event";
  const appId = "chatgpt-attention-alert";
  const consentKey = "gptaa.analytics.consent.v1";
  const variantKey = "gptaa.kr-home-thumbnail-v1";
  const params = new URLSearchParams(location.search);
  const pageByPath = new Map([
    ["/chatgpt-attention-alert/", "home"],
    ["/chatgpt-attention-alert/ko/persistent-alerts/", "persistent-alerts"],
    ["/chatgpt-attention-alert/ko/auth-context/", "auth-context"],
    ["/chatgpt-attention-alert/privacy.html/", "privacy"]
  ]);
  const page = pageByPath.get(location.pathname.replace(/\/$/, "") + "/");
  if (!page) return;
  const section = page === "home" ? "home" : page;
  const analyticsSignal = navigator.globalPrivacyControl === true || navigator.doNotTrack === "1" || params.get("gptaa_qa") === "1";
  const browserLanguage = (navigator.language || "").toLowerCase();
  const locale = browserLanguage.startsWith("ko") ? "ko" : browserLanguage.startsWith("en") ? "en" : "other";

  function localGet(key) {
    try { return localStorage.getItem(key); } catch { return null; }
  }
  function localSet(key, value) {
    try { localStorage.setItem(key, value); return true; } catch { return false; }
  }
  function pruneOldEventFlags() {
    try {
      const cutoff = new Date(Date.now() - 35 * 86400000).toISOString().slice(0, 10);
      for (let index = localStorage.length - 1; index >= 0; index--) {
        const key = localStorage.key(index);
        const match = key && key.match(/^gptaa\.event\.(\d{4}-\d{2}-\d{2})\./);
        if (match && match[1] < cutoff) localStorage.removeItem(key);
      }
    } catch {}
  }
  function normalized(value, allow, fallback) {
    return allow.has((value || "").toLowerCase()) ? value.toLowerCase() : fallback;
  }
  const allowedSources = new Set(["google", "bing", "github", "kakao", "x", "reddit", "direct", "other"]);
  const allowedMediums = new Set(["organic", "referral", "social", "direct", "other"]);
  const utmSource = normalized(params.get("utm_source"), allowedSources, "");
  const utmMedium = normalized(params.get("utm_medium"), allowedMediums, "");
  const utmCampaign = params.get("utm_campaign") === "kr_pilot_2026q4" ? "kr_pilot_2026q4" : "";
  const referrerHost = (() => { try { return new URL(document.referrer).hostname.toLowerCase(); } catch { return ""; } })();
  const inferredSource = referrerHost === "google.com" || referrerHost.endsWith(".google.com") ? "google"
    : referrerHost === "bing.com" || referrerHost.endsWith(".bing.com") ? "bing"
      : referrerHost === "github.com" || referrerHost.endsWith(".github.com") ? "github"
        : referrerHost ? "other" : "direct";
  const source = utmSource || inferredSource;
  const medium = utmMedium || (source === "google" || source === "bing" ? "organic" : source === "direct" ? "direct" : source === "github" ? "referral" : source === "other" ? "other" : "social");
  const campaign = utmCampaign || "none";
  const deviceClass = matchMedia("(pointer: coarse)").matches
    ? (Math.min(screen.width, screen.height) < 600 ? "phone" : "tablet")
    : "computer";
  const day = new Date().toISOString().slice(0, 10);

  function activeVariant() {
    if (section !== "home") return "default";
    let current = localGet(variantKey);
    if (current !== "a" && current !== "b") {
      current = Math.random() < 0.5 ? "a" : "b";
      if (!localSet(variantKey, current)) return "a";
    }
    return current;
  }

  function applyThumbnail(variant) {
    if (section !== "home") return;
    const image = document.getElementById("hero-thumbnail");
    if (!image) return;
    image.src = variant === "b" ? "assets/preview-kr-b.png" : "assets/preview-kr-a.png";
    image.alt = variant === "b"
      ? "대화 제목, 요청, 인증 계정을 함께 표시하는 ChatGPT Attention Alert 카드"
      : "잠깐 보이는 시스템 알림 옆에 계속 남아 있는 GPT 알림 카드";
  }

  function coarseCampaignContext() {
    return { source, medium, campaign };
  }

  function emit(event) {
    if (analyticsSignal || localGet(consentKey) !== "yes") return;
    const variant = activeVariant();
    const eventKey = `gptaa.event.${day}.${page}.${variant}.${event}`;
    if (localGet(eventKey) === "1") return;
    const payload = {
      appId,
      page,
      variant,
      event,
      locale,
      client: "web",
      deviceClass,
      ...coarseCampaignContext()
    };
    fetch(endpoint, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(payload), keepalive: true })
      .then(response => { if (response.ok) localSet(eventKey, "1"); })
      .catch(() => {});
  }

  function showConsent() {
    let banner = document.getElementById("analytics-consent");
    if (!banner) {
      banner = document.createElement("aside");
      banner.id = "analytics-consent";
      banner.setAttribute("role", "dialog");
      banner.setAttribute("aria-label", "웹사이트 방문 통계 설정");
      const english = !navigator.language.toLowerCase().startsWith("ko");
      banner.innerHTML = english
        ? `<p>If you agree, we count coarse country/region, language, device class, page views and button clicks to improve this site. Cloudflare stores daily totals only; we do not store IP addresses, accounts or alert text. You can refuse. <a href="/chatgpt-attention-alert/privacy.html">Details</a></p><div><button type="button" data-choice="no">Decline</button><button type="button" data-choice="yes">Allow</button></div>`
        : `<p>페이지·다운로드 반응을 개선하는 데 동의하면 국가·광역 지역, 언어, 기기 종류, 선택한 페이지와 버튼 반응만 익명 집계합니다. Cloudflare를 거쳐 일별 합계로 저장하며 IP·계정·알림 내용은 저장하지 않습니다. 원하지 않으면 거부를 선택할 수 있습니다. <a href="/chatgpt-attention-alert/privacy.html">자세히</a></p><div><button type="button" data-choice="no">거부</button><button type="button" data-choice="yes">동의</button></div>`;
      document.body.appendChild(banner);
      if (analyticsSignal) {
        const english = !navigator.language.toLowerCase().startsWith("ko");
        banner.innerHTML = english
          ? `<p>Website analytics is off because your browser sent a privacy signal or this is a flagged QA visit.</p><div><button type="button" data-close>Close</button></div>`
          : `<p>브라우저 개인정보 보호 신호 또는 내부 QA 주소로 감지되어 웹사이트 통계를 보내지 않습니다.</p><div><button type="button" data-close>닫기</button></div>`;
        banner.querySelector("[data-close]").addEventListener("click", () => banner.remove());
        return;
      }
      banner.querySelectorAll("[data-choice]").forEach(button => button.addEventListener("click", () => {
        const choice = button.dataset.choice;
        localSet(consentKey, choice);
        if (choice !== "yes") {
          try { localStorage.removeItem(variantKey); } catch {}
        }
        banner.remove();
        if (choice === "yes" && !analyticsSignal) {
          const variant = activeVariant();
          applyThumbnail(variant);
          emit("page_view");
        }
      }));
    }
    banner.hidden = false;
  }

  document.addEventListener("DOMContentLoaded", () => {
    pruneOldEventFlags();
    const variant = localGet(consentKey) === "yes" && !analyticsSignal ? activeVariant() : "a";
    applyThumbnail(variant);
    if (localGet(consentKey) === "yes" && !analyticsSignal) emit("page_view");
    else if (localGet(consentKey) !== "no" && !analyticsSignal) showConsent();

    document.querySelectorAll("[data-market-event]").forEach(link => {
      link.addEventListener("click", () => emit(link.dataset.marketEvent));
    });
    document.querySelectorAll("[data-analytics-settings]").forEach(button => button.addEventListener("click", showConsent));
  });
})();
