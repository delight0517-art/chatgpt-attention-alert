# ChatGPT Attention Alert

Open-source local desktop companion and plugin package for persistent, chat-labeled user-attention alerts. Includes macOS and Windows helpers.

## 한국어 빠른 시작

1. 내려받은 ZIP 패키지의 압축을 푼다.
2. GitHub에서 바로 추가하거나, 내려받아 압축을 푼 뒤 저장소 폴더를 추가한다:

   ```sh
   codex plugin marketplace add delight0517-art/chatgpt-attention-alert
   # 또는 다운로드/압축 해제 후 해당 폴더에서:
   codex plugin marketplace add .
   ```
3. 앱을 다시 열고 Plugins에서 **ChatGPT Attention Alert**를 설치한다.
4. macOS는 `./install-macos.sh`, Windows PowerShell은 `Set-ExecutionPolicy -Scope Process Bypass` 후 `./Install-Windows.ps1`을 실행해 OS 알림 도우미를 설치한다.

브라우저의 ChatGPT 웹만으로는 사용자의 컴퓨터에서 소리나 네이티브 창을 띄울 수 없다. 데스크톱 앱과 해당 OS의 도우미가 필요하다. 공개 플러그인 디렉터리에 올리려면 별도의 원격 HTTPS MCP 서버와 OpenAI 심사가 필요하다.

## What it does

- Opens the supplied chat URL before playing sound; without a valid HTTP(S) chat URL it stays silent.
- Shows the chat title and requested action in a floating card.
- Uses an opaque card and offsets simultaneous alerts so their arrival order remains visible.
- Keeps the card open until the user acknowledges it.
- Leaves keyboard focus with the app you are using; typing, including Enter, does not dismiss the alert.
- Plays the alert sound after the card appears; `×` closes that alert, and clicking the card opens its conversation.
- Adds a **24시간 중지** button that suppresses new alerts for 24 hours.
- Lets the user toggle sound from the card or command line.
- Lets the user choose a custom `.wav` alert sound on macOS and Windows, or restore the system sound.
- Can show at most one small developer-service recommendation per calendar month when an alert title/action matches a listed topic. Authentication and sensitive-code alerts are excluded.
- Recommendation matching uses local keyword rules on the alert title and action. It makes no AI/model request, spends zero AI tokens on recommendations, and does not save or send the alert text. The card discloses this in small text; use `--recommendations off` on macOS or `-Recommendations off` on Windows to disable it.
- Offers an **Open chat** button only when a chat URL is provided.
- Lets the agent include a verified HTTPS action page in the alert with **요청 페이지 열기**, separate from the chat-opening action.
- Adds a macOS menu-bar and Windows notification-area **GPT 알리미 열어줘** action to restore an alert after another window or browser covers it.
- Runs locally and sends no alert content to a server.

The public website has separate Korean landing pages for persistent alerts and authentication context. Its optional, consent-based research tracks only daily aggregate page and button counts by coarse Cloudflare country/first-level region, locale, broad device class, experiment variant, and allowlisted campaign label. It stores no IP address, account, exact query/referrer, browser ID, alert text, or installation result. Read [the privacy notice](https://delight0517-art.github.io/chatgpt-attention-alert/privacy.html) before opting in. The companion itself does not send alert content to this website analytics service.

## Requirements and limits

- ChatGPT desktop or Codex desktop for the local plugin workflow.
- macOS: Swift toolchain included with Xcode Command Line Tools.
- Windows: Windows PowerShell 5.1 or PowerShell 7 with Windows Forms available.

The plugin provides reusable agent instructions; the native companion must also be installed. A plugin running only in ChatGPT on the web cannot play sound or display a native window on the user's computer. Public Plugin Directory publication also requires a reachable HTTPS MCP service and OpenAI review; this repository is a local desktop package, not a published directory listing.

## Install the plugin in ChatGPT desktop / Codex

1. Download and unzip this repository, or clone it.
2. Add the GitHub marketplace, or from the repository root add the downloaded local marketplace:

   ```sh
   codex plugin marketplace add delight0517-art/chatgpt-attention-alert
   # Or, from the downloaded repository folder:
   codex plugin marketplace add .
   ```

3. Restart ChatGPT desktop, open Plugins, choose **ChatGPT Attention Alert**, and install the plugin.

The repository includes `.agents/plugins/marketplace.json` and `plugin/plugin.json` for this local installation path.

## Install the companion

### macOS

From this repository root, run:

```sh
./install-macos.sh
```

This copies the helper to `~/.local/share/chatgpt-attention-alert` and installs `~/.local/bin/chatgpt-attention-alert`. Add `~/.local/bin` to `PATH` if it is not already there.

Try it:

```sh
~/.local/bin/chatgpt-attention-alert "My chat title" "Please unlock the Mac and approve the prompt."
~/.local/bin/chatgpt-attention-alert --sound off
~/.local/bin/chatgpt-attention-alert --sound on
~/.local/bin/chatgpt-attention-alert --sound toggle
~/.local/bin/chatgpt-attention-alert --sound-file /path/to/alert.wav
~/.local/bin/chatgpt-attention-alert --sound-file default
~/.local/bin/chatgpt-attention-alert --recommendations off
~/.local/bin/chatgpt-attention-alert --auth "GitHub" "delight0517" "Current chat" "Complete sign-in" "https://chatgpt.com/c/..."
```

For another provider, replace `GitHub` and the account with the exact service and account. Add `--action-url "https://github.com/login/device"` to show the provider page button (**--login-url** remains an alias). If the provider reports an expiry or rate-limit reset time, add `--expires-at <unix-seconds>` and/or `--retry-after <unix-seconds>`. The card keeps the link available until its reported expiry. Once a retry limit ends, **새 인증 링크 요청** copies a fresh-request message and opens the conversation; paste and send that message to get a new link. The alert stays open until acknowledged. Use the macOS menu-bar **GPT** menu to bring it forward again.

Windows accepts `-AuthService "<service>" -AuthAccount "<account>" -ActionUrl "<https-url>" -ExpiresAt <unix-seconds> -RetryAfter <unix-seconds>` with its normal alert parameters. `-LoginUrl` remains an alias. Keep passwords, one-time codes, and tokens out of the URL and alert.

### Windows

From PowerShell in this repository root, run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-Windows.ps1
```

Try it:

```powershell
& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Title "My chat title" -Message "Please unlock the computer and approve the prompt."
& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Sound off
& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Sound on
& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Sound toggle
& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -SetSoundFile "C:\Sounds\alert.wav"
& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -SetSoundFile default
& "$env:LOCALAPPDATA\ChatGPTAttentionAlert\alert.ps1" -Recommendations off
```

On macOS, an AI agent can change the installed alert palette when you ask it to:

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

Use `#RRGGBB` values for colors and whole-number percentages from `0` (transparent) to `100` (opaque) for opacity. Both use the roles `background`, `accent`, `text`, `button`, or `button-text`. Changes are saved locally and apply to new alerts. `--opacity reset` resets opacity while keeping colors; `--color reset` restores the complete default palette. Button text and fills are drawn explicitly for readable contrast in dark mode. Windows color settings are pending the matching Windows implementation.

Use an existing `.wav` file. The process-scoped execution policy does not change the machine's persistent PowerShell policy.
When another window covers the alert, open the Windows notification-area icon's menu and choose **GPT 알리미 열어줘**, or double-click the icon.

## Open a specific chat

Pass the full HTTPS conversation URL as the third macOS argument or `-ChatUrl` on Windows. For safety, automatic opening accepts only `chatgpt.com` and `chat.openai.com`. Clicking the card background, title, or message opens that conversation without dismissing the alert. When the user must open a web page to act, the agent can pass its verified HTTPS URL with `--action-url` on macOS or `-ActionUrl` on Windows; the alert displays **요청 페이지 열기** as a separate button. The agent should also include the link in its chat response. Use the macOS menu-bar or Windows notification-area **GPT 알리미 열어줘** action to restore a covered alert. A reissue button is enabled only when an expiry or provider-supplied retry time is passed in; the companion cannot independently detect a provider's rate-limit state. The companion does not guess links from a title.

## Project layout

- `plugin/`: portable plugin manifest, local marketplace entry, and skill.
- `plugin/companion/macos/`: Swift overlay and command wrapper.
- `plugin/companion/windows/`: PowerShell overlay and installer source.
- `install-macos.sh`, `Install-Windows.ps1`: local companion installers.

## License

MIT. See [LICENSE](LICENSE).
