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

If the helper is missing, tell the user to install the companion from the downloaded package. Do not claim that a public web ChatGPT page can play local computer sounds: local alerts require the desktop app and an installed companion.
