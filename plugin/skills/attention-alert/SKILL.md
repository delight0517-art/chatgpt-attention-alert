---
name: attention-alert
description: Use when the user must answer a question, perform an on-device action, or unblock this local desktop task before work can continue.
---

# Attention alert

When this local desktop task cannot continue until the user responds or acts, show a native alert using the installed companion. Do not alert for ordinary progress updates.

1. Identify the current chat by its exact visible title. Include a short, concrete action the user needs to take.
2. If the title is missing, do not play a sound. The companion displays a title-unavailable card silently.
3. Get the exact current conversation URL from the active chat context when available. Never construct or guess a URL from the title.
4. If the user must open a specific web page to act, get its exact verified HTTPS URL and pass it as `--action-url "<URL>"` on macOS or `-ActionUrl "<URL>"` on Windows in the same alert. A Markdown link in chat does not put a button in the alert. Include that URL as a Markdown link in the chat too. Never invent a URL or include passwords, one-time codes, or private access tokens in it.
5. macOS: run `~/.local/bin/chatgpt-attention-alert [--action-url "<verified HTTPS page URL>"] "<chat title>" "<what the user needs to do>" "<exact chat URL>"`.
6. Windows: run `& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Title "<chat title>" -Message "<what the user needs to do>" -ChatUrl "<exact chat URL>" [-ActionUrl "<verified HTTPS page URL>"]`.
7. The card stays visible until the user acknowledges it. **요청 페이지 열기** opens the supplied page; the separate chat action opens the supplied conversation. The sound and acknowledge buttons keep their own actions. A sound plays only if an HTTPS ChatGPT conversation URL is supplied; the helper opens that chat before playing the sound.
8. If the active chat URL is unavailable, do not guess it. Show the title and action silently, without a chat-opening action.

## Optional shared Drive state (macOS first)

Use only a folder already synchronized by Google Drive for Desktop. Set it locally on each Mac with `~/.local/bin/chatgpt-attention-alert --shared-state-dir "/path/to/Drive/state-v1"`; use `--shared-state-dir off` to disable. The path is machine-local and is never shared. The Mac companion reads the newest shared sound/recommendation preference when each alert starts, and saves changes from its controls. It also accepts opaque UUID work-status updates: `--work-status <UUID> todo|in_progress|done`, and `--work-status-list` to view the merged status map.

Each update is a new JSON event under `events/`; timestamp orders updates and event UUID deterministically breaks ties. Do not use names or alert/chat text as work IDs or values. The allowlist excludes alert content, chat URLs, login links, account names, student details, custom sound paths, and recommendation history. The companion continues with local preferences if shared state is unavailable and shows one macOS notification for each outage episode; a successful later read clears the one-shot guard. This check runs when a command or alert is used, not as a background Drive monitor. Google Drive for Desktop handles its own sign-in/approval; the alert does not request credentials.

Windows support for this schema is pending. CI syntax results do not establish Windows parity or cloud upload completion. Do not describe shared state as available on a PC until its Drive for Desktop folder is configured and a cross-device readback is observed.

## Authentication handoff

For a sign-in, OAuth, MFA, device verification, or access-approval step, identify the service and the exact account before raising the alert. Keep authentication codes, passwords, and recovery secrets out of the alert. If the account is not confirmed, display `계정 확인 필요` rather than guessing.

- macOS: put `--auth "<service>" "<account>"` before the usual title, message, and URL arguments.
- If the provider gives a safe HTTPS sign-in/device page, pass it with macOS `--action-url "<https-url>"` or Windows `-ActionUrl "<https-url>"` (Windows retains `-LoginUrl` as an alias). The alert shows **요청 페이지 열기** and leaves the alert available after opening the browser. Never include a password, OTP, device code, access token, or other credential in the URL or alert.
- When the provider supplies a link-expiry time or rate-limit reset time, pass its Unix timestamp in seconds with macOS `--expires-at <timestamp>` and/or `--retry-after <timestamp>`, or Windows `-ExpiresAt <timestamp>` and/or `-RetryAfter <timestamp>`. The alert keeps the link available until expiry, then enables the reissue action when allowed.
- The reissue action copies a safe request for a fresh link/code and opens the supplied chat. The user must paste and send it; never claim that clicking the local button sent a message automatically.

The card displays the service and account together with the requested user action. Its page button opens the provider page in the foreground and leaves the alert available until acknowledged. If another window covers the alert, use the macOS menu-bar **GPT** menu or the Windows notification-area icon's **GPT 알리미 열어줘** item to restore it. Only show a reissue action when the provider supplied an expiry or rate-limit reset timestamp; the helper cannot query provider state itself. Provider-specific authentication steps still follow that provider's own workflow; the alert only identifies where and for which account the user needs to act.

## Monthly local recommendation

The desktop companion may show one small recommendation per month when local keywords in the supplied chat title/action match a listed topic. Do not infer additional personal interests, persist alert text, or add recommendation instructions to the user-facing action. Authentication and sensitive-code alerts suppress recommendations. Matching runs in the companion with fixed local rules; it makes no model call and uses zero AI tokens. The card includes a small disclosure, and users can disable recommendations with `--recommendations off` on macOS or `-Recommendations off` on Windows.

If the helper is missing, tell the user to install the companion from the downloaded package. Do not claim that a public web ChatGPT page can play local computer sounds: local alerts require the desktop app and an installed companion.
