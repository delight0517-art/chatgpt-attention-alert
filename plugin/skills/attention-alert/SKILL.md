---
name: attention-alert
description: Use when the user must answer a question, perform an on-device action, or unblock this local desktop task before work can continue.
---

# Attention alert

When this local desktop task cannot continue until the user responds or acts, show a native alert using the installed companion. Do not alert for ordinary progress updates.

1. Identify the current chat by its exact visible title. Include a short, concrete action the user needs to take.
2. If the title is missing, do not play a sound. The companion displays a title-unavailable card silently.
3. macOS: run `~/.local/bin/chatgpt-attention-alert "<chat title>" "<what the user needs to do>" [chat URL]`.
4. Windows: run `& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Title "<chat title>" -Message "<what the user needs to do>" [-ChatUrl "<chat URL>"]`.
5. The card stays visible until the user acknowledges it. It always shows the chat title and provides a sound toggle. A sound plays only if an HTTPS ChatGPT conversation URL is supplied; the helper opens that chat before playing the sound. The card offers an Open Chat button when a valid URL is supplied.

If the helper is missing, tell the user to install the companion from the downloaded package. Do not claim that a public web ChatGPT page can play local computer sounds: local alerts require the desktop app and an installed companion.
