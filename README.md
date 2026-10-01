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
- Keeps the card open until the user acknowledges it.
- Lets the user toggle sound from the card or command line.
- Offers an **Open chat** button only when a chat URL is provided.
- Runs locally and sends no alert content to a server.

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
```

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
```

The process-scoped execution policy does not change the machine's persistent PowerShell policy.

## Open a specific chat

Pass the full HTTPS conversation URL as the third macOS argument or `-ChatUrl` on Windows. For safety, automatic opening accepts only `chatgpt.com` and `chat.openai.com`. When sound is enabled, the companion opens that chat before playing the alert. Clicking the card background, title, or message also opens the conversation; the sound and acknowledge buttons keep their own actions. The card also shows an **Open chat** button. The companion does not guess a chat URL from its title.

## Project layout

- `plugin/`: portable plugin manifest, local marketplace entry, and skill.
- `plugin/companion/macos/`: Swift overlay and command wrapper.
- `plugin/companion/windows/`: PowerShell overlay and installer source.
- `install-macos.sh`, `Install-Windows.ps1`: local companion installers.

## License

MIT. See [LICENSE](LICENSE).
