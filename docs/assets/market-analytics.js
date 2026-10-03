(() => {
  const endpoint = "https://chatgpt-attention-alert-market.imdisablebutgodisable.workers.dev/event";
  const appId = "chatgpt-attention-alert";
  const consentKey = "gptaa.analytics.consent.v1";
  const variantKey = "gptaa.kr-home-thumbnail-v1";
  const params = new URLSearchParams(location.search);
  const pageByPath = new Map([
    ["/chatgpt-attention-alert/", "home"],
    ["/chatgpt-attention-alert/en/", "home-en"],
    ["/chatgpt-attention-alert/ja/", "home-ja"],
    ["/chatgpt-attention-alert/zh-Hans/", "home-zh-hans"],
    ["/chatgpt-attention-alert/ko/persistent-alerts/", "persistent-alerts"],
    ["/chatgpt-attention-alert/ko/auth-context/", "auth-context"],
    ["/chatgpt-attention-alert/privacy.html/", "privacy"]
  ]);
  const page = pageByPath.get(location.pathname.replace(/\/$/, "") + "/");
  if (!page) return;
  const section = page === "home" ? "home" : page;
  const analyticsSignal = navigator.globalPrivacyControl === true || navigator.doNotTrack === "1" || params.get("gptaa_qa") === "1";
  const pageLanguage = (document.documentElement.lang || navigator.language || "").toLowerCase();
  const locale = pageLanguage.startsWith("ko") ? "ko"
    : pageLanguage.startsWith("en") ? "en"
      : pageLanguage.startsWith("ja") ? "ja"
        : pageLanguage.startsWith("zh") ? "zh-hans" : "other";

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
    : /(^|\.)google\.[a-z]{2,3}(?:\.[a-z]{2})?$/i.test(referrerHost) ? "google"
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
      const copy = {
        ko: { label: "웹사이트 방문 통계 설정", text: "동의하면 국가·광역 지역, 페이지 언어, 기기 종류, 페이지 방문과 버튼 반응을 익명 집계합니다. Cloudflare에는 일별 합계만 저장하며 IP·계정·알림 내용은 저장하지 않습니다. 거부해도 사이트와 다운로드를 이용할 수 있습니다.", details: "자세히", decline: "거부", allow: "동의" },
        en: { label: "Website analytics settings", text: "If you agree, we count coarse country/region, page language, device class, page views and button clicks. Cloudflare stores daily totals only; we do not store IP addresses, accounts or alert text. You can decline and still use the site and downloads.", details: "Details", decline: "Decline", allow: "Allow" },
        ja: { label: "ウェブサイト統計の設定", text: "同意すると、国・広域地域、ページの言語、端末の種類、ページ閲覧とボタン操作を匿名で集計します。Cloudflareには日別の合計のみを保存し、IPアドレス、アカウント、通知内容は保存しません。拒否してもサイトとダウンロードを利用できます。", details: "詳細", decline: "拒否", allow: "同意" },
        "zh-hans": { label: "网站访问统计设置", text: "同意后，我们只匿名汇总国家/大区、页面语言、设备类型、页面访问和按钮点击。Cloudflare 仅保存每日汇总，不保存 IP 地址、账户或提醒内容。拒绝后仍可正常浏览和下载。", details: "详情", decline: "拒绝", allow: "同意" }
      }[locale] || { label: "Website analytics settings", text: "If you agree, we count coarse country/region, page language, device class, page views and button clicks. Cloudflare stores daily totals only; we do not store IP addresses, accounts or alert text. You can decline and still use the site and downloads.", details: "Details", decline: "Decline", allow: "Allow" };
      banner.setAttribute("aria-label", copy.label);
      banner.innerHTML = `<p>${copy.text} <a href="/chatgpt-attention-alert/privacy.html">${copy.details}</a></p><div><button type="button" data-choice="no">${copy.decline}</button><button type="button" data-choice="yes">${copy.allow}</button></div>`;
      document.body.appendChild(banner);
      if (analyticsSignal) {
        const notice = {
          ko: ["브라우저 개인정보 보호 신호 또는 내부 QA 주소로 감지되어 통계를 보내지 않습니다.", "닫기"],
          en: ["Analytics is off because your browser sent a privacy signal or this is a flagged QA visit.", "Close"],
          ja: ["ブラウザーのプライバシー信号、または内部 QA 用アドレスのため、統計は送信されません。", "閉じる"],
          "zh-hans": ["检测到浏览器隐私信号或内部 QA 地址，因此不会发送统计数据。", "关闭"]
        }[locale] || ["Analytics is off because your browser sent a privacy signal or this is a flagged QA visit.", "Close"];
        banner.innerHTML = `<p>${notice[0]}</p><div><button type="button" data-close>${notice[1]}</button></div>`;
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
