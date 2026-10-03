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
5. For a Codex chat, use the Codex thread tools to identify this chat by its exact title and workspace, then pass its returned UUID as `--resume-thread "<exact UUID>"` on macOS. Never infer the UUID. This adds a **Resume** button; clicking it queues a continuation message in that exact Codex thread and opens the chat. The message includes the alert's requested action, tells Codex to verify it, and never treats an unverified action as complete. If no exact UUID is available, omit the option. Windows support is pending its matching companion implementation.
6. macOS: run `~/.local/bin/chatgpt-attention-alert [--resume-thread "<exact Codex thread UUID>"] [--action-url "<verified HTTPS page URL>"] "<chat title>" "<what the user needs to do>" "<exact chat URL>"`.
7. Windows: run `& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Title "<chat title>" -Message "<what the user needs to do>" -ChatUrl "<exact chat URL>" [-ActionUrl "<verified HTTPS page URL>"]`.
8. Opening the supplied page or conversation leaves the floating alert visible. On macOS, the user can drag its background to move it. Keep the card until the user presses **확인** or `×`. The sound and acknowledge buttons keep their own actions. A sound plays only if an HTTPS ChatGPT conversation URL is supplied; the helper opens that chat before playing the sound.
9. If the active chat URL is unavailable, do not guess it. Show the title and action silently, without a chat-opening action.

## Alert colors

When the user asks to customize this companion's colors, update its saved palette with the installed macOS command. Agents may run this local settings command only in response to the user's color request; do not infer a preference from unrelated messages.

Users can open the visual settings from the menu bar **GPT → 색상·투명도 설정…** while an alert is open, or at any time with `~/.local/bin/chatgpt-attention-alert --settings`.
The appearance window follows the macOS display language in Korean, English, Japanese, or Chinese; other locales use English. The palette file's role names and command options stay language-neutral.

```sh
~/.local/bin/chatgpt-attention-alert --color accent '#7C5CFF'
~/.local/bin/chatgpt-attention-alert --color background '#172033'
~/.local/bin/chatgpt-attention-alert --color text '#FFFFFF'
~/.local/bin/chatgpt-attention-alert --color button '#293B58'
~/.local/bin/chatgpt-attention-alert --color button-text '#FFFFFF'
~/.local/bin/chatgpt-attention-alert --opacity background 55
~/.local/bin/chatgpt-attention-alert --opacity accent 85
~/.local/bin/chatgpt-attention-alert --opacity button 90
~/.local/bin/chatgpt-attention-alert --opacity text 100
~/.local/bin/chatgpt-attention-alert --opacity button-text 100
~/.local/bin/chatgpt-attention-alert --opacity reset
~/.local/bin/chatgpt-attention-alert --color reset
```

Supported roles are `background`, `accent`, `text`, `button`, and `button-text`. Colors use `#RRGGBB`; opacity uses a whole-number percentage from `0` (transparent) to `100` (opaque). Opacity changes only the selected role and is stored locally with the palette. `--opacity reset` restores default opacity while keeping custom colors; `--color reset` restores all built-in colors and opacity. Changes apply to new alerts. The alert renders button backgrounds and labels with explicit colors so system dark mode cannot make the text disappear.

## Authentication handoff

For a sign-in, OAuth, MFA, device verification, or access-approval step, identify the service and exact account before raising the alert. Keep passwords, recovery secrets, and tokens out of all alerts. If the account is not confirmed, display `계정 확인 필요` rather than guessing.

- macOS: put `--auth "<service>" "<account>"` before the usual title, message, and URL arguments.
- If the provider gives a safe HTTPS sign-in/device page, pass it with macOS `--action-url "<https-url>"` or Windows `-ActionUrl "<https-url>"` (Windows retains `-LoginUrl` as an alias). The alert shows **요청 페이지 열기** and leaves the alert available after opening the browser. Never put a code or credential in the URL.
- For GitHub CLI device-code login on macOS, do not put the code in a generic alert. Run a fresh `GH_BROWSER=/usr/bin/true gh auth login --hostname github.com --git-protocol https --web --scopes repo` in a task-specific `GH_CONFIG_DIR`. Capture the code and issuance time from that exact session; if GitHub CLI omits the duration, use its device-flow default of 900 seconds. Call `${CODEX_HOME:-$HOME/.codex}/bin/needs-user-input --auth GitHub "<confirmed-account>" --link "https://github.com/login/device?skip_account_picker=true" --reason "<observable reason>" --github-device-auth "<exact chat title>" "조치 필요: GitHub 기기 인증 페이지에서 인증을 완료해 주세요." "<exact thread id>"` and pass `{"code":"<fresh code>","expiresAtEpochSeconds":<unix-seconds>,"expectedAccount":"<confirmed-account>","ghPath":"<gh executable path>","ghConfigDir":"<same task config directory>"}` on stdin. This dedicated card shows the code, copy button, confirmed account, expiry countdown, and GitHub page together. Never put the code in command-line arguments, a URL, or the chat response; the user enters it on GitHub. This personal Codex helper is not bundled in the public download. If it is unavailable, say the combined code card is unavailable and use the generic alert only for the verified page and required action.
- Do not reuse a prior or expired code, or issue overlapping device codes. If the helper reports alerts are paused or suppressed, preserve that preference and report that the card was not shown; do not claim it is visible.
- When the provider supplies a link-expiry time or rate-limit reset time, pass its Unix timestamp in seconds with macOS `--expires-at <timestamp>` and/or `--retry-after <timestamp>`, or Windows `-ExpiresAt <timestamp>` and/or `-RetryAfter <timestamp>`. The alert keeps the link available until expiry, then enables the reissue action when allowed.
- The reissue action copies a safe request for a fresh link/code and opens the supplied chat. The user must paste and send it; never claim that clicking the local button sent a message automatically.

The card displays the service and account together with the requested user action. Its page button opens the provider page in the foreground and leaves the alert available until acknowledged. If another window covers the alert, use the macOS menu-bar **GPT** menu or the Windows notification-area icon's **GPT 알리미 열어줘** item to restore it. Only show a reissue action when the provider supplied an expiry or rate-limit reset timestamp; the helper cannot query provider state itself. Provider-specific authentication steps still follow that provider's own workflow; the alert only identifies where and for which account the user needs to act.

## Monthly local recommendation

The desktop companion may show one small recommendation per month when local keywords in the supplied chat title/action match a listed topic. Do not infer additional personal interests, persist alert text, or add recommendation instructions to the user-facing action. Authentication and sensitive-code alerts suppress recommendations. Matching runs in the companion with fixed local rules; it makes no model call and uses zero AI tokens. The card includes a small disclosure, and users can disable recommendations with `--recommendations off` on macOS or `-Recommendations off` on Windows.

If the helper is missing, tell the user to install the companion from the downloaded package. Do not claim that a public web ChatGPT page can play local computer sounds: local alerts require the desktop app and an installed companion.
