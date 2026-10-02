---
name: attention-alert
description: Use when the user must answer a question, perform an on-device action, or unblock this local desktop task before work can continue.
---

# Attention alert

When this local desktop task cannot continue until the user responds or acts, show a native alert using the installed companion. Do not alert for ordinary progress updates.

1. Identify the current chat by its exact visible title. Include a short, concrete action the user needs to take.
2. If the title is missing, do not play a sound. The companion displays a title-unavailable card silently.
3. Get the exact current conversation URL from the active chat context when available. Never construct or guess a URL from the title.
4. macOS: run `~/.local/bin/chatgpt-attention-alert "<chat title>" "<what the user needs to do>" "<exact chat URL>"`.
5. Windows: run `& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Title "<chat title>" -Message "<what the user needs to do>" -ChatUrl "<exact chat URL>"`.
6. The card stays visible until the user acknowledges it. Clicking the card background, title, or message opens the supplied chat; the sound and acknowledge buttons keep their own actions. The card also has an Open Chat button. A sound plays only if an HTTPS ChatGPT conversation URL is supplied; the helper opens that chat before playing the sound.
7. If the active chat URL is unavailable, do not guess it. Show the title and action silently, without a chat-opening action.

## Authentication handoff

For a sign-in, OAuth, MFA, device verification, or access-approval step, identify the service and the exact account before raising the alert. Keep authentication codes, passwords, and recovery secrets out of the alert. If the account is not confirmed, display `계정 확인 필요` rather than guessing.

- macOS: put `--auth "<service>" "<account>"` before the usual title, message, and URL arguments.
- Windows: add `-AuthService "<service>" -AuthAccount "<account>"` to the usual parameters.

The card displays the service and account together with the requested user action. Provider-specific authentication steps still follow that provider's own workflow; the alert only identifies where and for which account the user needs to act.

## Monthly local recommendation

The desktop companion may show one small recommendation per month when local keywords in the supplied chat title/action match a listed topic. Do not infer additional personal interests, persist alert text, or add recommendation instructions to the user-facing action. Authentication and sensitive-code alerts suppress recommendations. Matching runs in the companion with fixed local rules; it makes no model call and uses zero AI tokens. The card includes a small disclosure, and users can disable recommendations with `--recommendations off` on macOS or `-Recommendations off` on Windows.

If the helper is missing, tell the user to install the companion from the downloaded package. Do not claim that a public web ChatGPT page can play local computer sounds: local alerts require the desktop app and an installed companion.
