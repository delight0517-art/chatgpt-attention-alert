import AppKit
import QuartzCore
import Darwin

let chatTitle = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Chat title unavailable"
let actionText = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Please check this chat."
let chatURL = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : ""
let soundEnabledArg = CommandLine.arguments.count > 4 ? CommandLine.arguments[4] : "on"
let preferencePath = CommandLine.arguments.count > 5 ? CommandLine.arguments[5] : ""
let stackPath = CommandLine.arguments.count > 6 ? CommandLine.arguments[6] : ""
let customSoundPath = CommandLine.arguments.count > 7 ? CommandLine.arguments[7] : ""
let pauseUntilPath = CommandLine.arguments.count > 8 ? CommandLine.arguments[8] : ""
let authService = CommandLine.arguments.count > 9 ? CommandLine.arguments[9] : ""
let authAccount = CommandLine.arguments.count > 10 ? CommandLine.arguments[10] : ""
let recommendationsEnabled = CommandLine.arguments.count <= 11 || CommandLine.arguments[11] != "off"
let recommendationStatePath = CommandLine.arguments.count > 12 ? CommandLine.arguments[12] : ""
var soundEnabled = soundEnabledArg != "off"
var actionLabel: NSTextField?
var actionStatusLabel: NSTextField?
var authStatusLabel: NSTextField?
var authLinkButton: NSButton?
var reissueButton: NSButton?
let actionURLValue = CommandLine.arguments.count > 13 ? CommandLine.arguments[13] : ""
let linkExpiresAt = CommandLine.arguments.count > 14 ? TimeInterval(CommandLine.arguments[14]) ?? 0 : 0
let retryAfter = CommandLine.arguments.count > 15 ? TimeInterval(CommandLine.arguments[15]) ?? 0 : 0
let colorsPath = CommandLine.arguments.count > 16 ? CommandLine.arguments[16] : ""
let appearanceSettingsPath = CommandLine.arguments.count > 17 ? CommandLine.arguments[17] : ""
let resumeThreadID = CommandLine.arguments.count > 18 ? CommandLine.arguments[18] : ""
let canResume = UUID(uuidString: resumeThreadID) != nil
let language = Locale.preferredLanguages.first?.split(separator: "-").first.map(String.init) ?? "en"
func tr(_ ko: String, _ en: String, _ ja: String, _ zh: String) -> String {
    switch language { case "ko": return ko; case "ja": return ja; case "zh": return zh; default: return en }
}
func resumePrompt() -> String {
    let request = "\n\n\(actionText)"
    switch language {
    case "ko": return "중단된 작업을 이 대화에서 재개해 주세요. 사용자는 '작업 재개'를 눌러 요청된 조치를 수행했다고 알렸습니다. 기존 상태를 확인해 조치가 완료된 것이 확인되면 원래 작업을 계속하세요. 확인할 수 없다면 성공했다고 가정하지 말고 남은 조치를 알려 주세요.\n\n알림에 적힌 요청:\(request)"
    case "ja": return "この会話で中断した作業を再開してください。ユーザーは「再開」を選び、依頼された操作を行ったと伝えています。既存の状態を確認し、完了が確認できたら元の作業を続けてください。確認できない場合は成功と決めつけず、必要な操作を伝えてください。\n\n通知に記載された依頼:\(request)"
    case "zh": return "请在此对话中继续中断的任务。用户选择了“继续”，表示已执行所请求的操作。请检查当前状态；确认完成后继续原任务。如果无法确认，请勿假定成功，并说明还需要什么操作。\n\n提醒中的请求：\(request)"
    default: return "Resume the interrupted work in this conversation. By selecting Resume, the user says they performed the requested action. Verify the current state; continue the original task if completion is confirmed. If you cannot verify it, do not assume success; state what is still needed.\n\nRequest shown in the alert:\(request)"
    }
}
var savedColors: [String: String] = [:]
var savedOpacities: [String: String] = [:]
if let contents = try? String(contentsOfFile: colorsPath, encoding: .utf8) {
    for line in contents.split(whereSeparator: \.isNewline) {
        let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
        if pair.count == 2 {
            if pair[0].hasPrefix("opacity.") { savedOpacities[String(pair[0].dropFirst("opacity.".count))] = pair[1] }
            else { savedColors[pair[0]] = pair[1] }
        }
    }
}
func color(_ role: String, fallback: String) -> NSColor {
    let value = savedColors[role] ?? fallback
    let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
    guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else { return colorFromHex(fallback) }
    return NSColor(calibratedRed: CGFloat((rgb >> 16) & 0xff) / 255, green: CGFloat((rgb >> 8) & 0xff) / 255, blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
}
func colorFromHex(_ value: String) -> NSColor {
    let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
    guard let rgb = UInt32(hex, radix: 16) else { return .white }
    return NSColor(calibratedRed: CGFloat((rgb >> 16) & 0xff) / 255, green: CGFloat((rgb >> 8) & 0xff) / 255, blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
}
func alpha(_ role: String, fallback: CGFloat = 1) -> CGFloat {
    guard let value = savedOpacities[role], let percent = Double(value), (0...100).contains(percent) else { return fallback }
    return CGFloat(percent / 100)
}
let backgroundColor = color("background", fallback: "#0E1724")
let accentColor = color("accent", fallback: "#61EBFF")
let textColor = color("text", fallback: "#FFFFFF")
let buttonColor = color("button", fallback: "#24405A")
let buttonTextColor = color("button-text", fallback: "#FFFFFF")

func composite(_ foreground: NSColor, over background: NSColor, opacity: CGFloat) -> NSColor {
    let fg = foreground.usingColorSpace(.deviceRGB) ?? .white
    let bg = background.usingColorSpace(.deviceRGB) ?? .black
    let amount = max(0, min(1, opacity))
    return NSColor(calibratedRed: fg.redComponent * amount + bg.redComponent * (1 - amount), green: fg.greenComponent * amount + bg.greenComponent * (1 - amount), blue: fg.blueComponent * amount + bg.blueComponent * (1 - amount), alpha: 1)
}

func luminance(_ color: NSColor) -> CGFloat {
    let rgb = color.usingColorSpace(.deviceRGB) ?? .white
    func linear(_ value: CGFloat) -> CGFloat { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
}

func contrast(_ first: NSColor, _ second: NSColor) -> CGFloat {
    let values = [luminance(first), luminance(second)].sorted(by: >)
    return (values[0] + 0.05) / (values[1] + 0.05)
}

func readableButtonText(for fill: NSColor, fillOpacity: CGFloat) -> NSColor {
    let visibleFill = composite(fill, over: backgroundColor, opacity: fillOpacity)
    let preferredText = composite(buttonTextColor, over: visibleFill, opacity: alpha("button-text"))
    if contrast(preferredText, visibleFill) >= 4.5 { return buttonTextColor.withAlphaComponent(alpha("button-text")) }
    let dark = colorFromHex("#102033")
    let light = NSColor.white
    return contrast(dark, visibleFill) >= contrast(light, visibleFill) ? dark : light
}

let hasAuthContext = !authService.isEmpty || !authAccount.isEmpty || !actionURLValue.isEmpty || linkExpiresAt > 0 || retryAfter > 0
var authStatusIsActionResult = false

func showActionStatus(_ message: String) {
    actionLabel?.stringValue = actionText
    if let authStatusLabel {
        authStatusLabel.stringValue = message
        authStatusIsActionResult = true
    } else {
        actionStatusLabel?.stringValue = message
    }
}

func styleButton(_ button: NSButton, prominent: Bool = false) {
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.cornerRadius = 8
    let fill = prominent ? accentColor.withAlphaComponent(alpha("accent")) : buttonColor.withAlphaComponent(alpha("button"))
    button.layer?.backgroundColor = fill.cgColor
    let foreground = readableButtonText(for: prominent ? accentColor : buttonColor, fillOpacity: alpha(prominent ? "accent" : "button"))
    button.attributedTitle = NSAttributedString(string: button.title, attributes: [.foregroundColor: foreground, .font: button.font ?? .systemFont(ofSize: 13, weight: .medium)])
    button.contentTintColor = foreground
}

struct LocalRecommendation {
    let title: String
    let url: URL

    static func showIfDue(title: String, action: String, enabled: Bool, hasAuthContext: Bool, statePath: String) -> Self? {
        guard enabled, !hasAuthContext, !statePath.isEmpty else { return nil }
        let text = "\(title) \(action)".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let sensitive = ["password", "passkey", "otp", "one-time code", "verification code", "api key", "access token", "secret", "oauth", "mfa", "sign-in", "login", "authentication", "비밀번호", "인증", "로그인", "인증 코드", "인증번호", "일회용 코드", "패스키", "액세스 토큰"]
        guard !sensitive.contains(where: text.contains) else { return nil }

        let picks: [(topic: String, keywords: [String], title: String, url: String)] = [
            ("focus", ["pomodoro", "focus", "timer", "study", "concentration", "집중", "포모도로", "타이머", "공부"], "PomoFlow · 집중 타이머", "https://delight0517.github.io/pomoflow/"),
            ("scripture", ["bible", "scripture", "prayer", "성경", "말씀", "기도", "묵상"], "Selah · 성경 묵상 웹 앱", "https://delight0517.github.io/selah-bible-meditation/"),
            ("ai", ["chatgpt", "artificial intelligence", " ai ", "llm", "prompt", "agent", "인공지능", "생성형 ai"], "Jev Evidence Kit · AI 답변 비교", "https://jev-evidence-kit.rogan2534.chatgpt.site/"),
            ("app-building", ["build an app", "app development", "website", "web app", "앱 개발", "앱 만들", "앱 제작", "웹사이트", "웹 앱"], "Launchmate · 앱 제작 서비스", "https://launchmate-app-builders.rogan2534.chatgpt.site/")
        ]
        guard let currentTopic = picks.first(where: { item in item.keywords.contains(where: text.contains) })?.topic else { return nil }

        let date = Calendar.current.dateComponents([.year, .month], from: Date())
        let month = String(format: "%04d-%02d", date.year ?? 0, date.month ?? 0)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let cutoff = formatter.string(from: Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date())
        let stateURL = URL(fileURLWithPath: (statePath as NSString).standardizingPath)
        let lockPath = stateURL.path + ".lock"
        let fd = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return nil }
        flock(fd, LOCK_EX)
        defer { flock(fd, LOCK_UN); close(fd) }
        var state: [String: String] = [:]
        if let contents = try? String(contentsOf: stateURL, encoding: .utf8) {
            for line in contents.split(whereSeparator: \.isNewline) {
                let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
                if pair.count == 2 { state[pair[0]] = pair[1] }
            }
        }
        var topics = [String: [String]]()
        for pick in picks {
            let key = "topic.\(pick.topic)"
            var dates = (state[key] ?? "").split(separator: ",").map(String.init).filter { $0 >= cutoff }
            if pick.topic == currentTopic, !dates.contains(today) { dates.append(today) }
            topics[pick.topic] = dates
        }
        let maxCount = topics.values.map(\.count).max() ?? 0
        let preferredTopic = topics[currentTopic]?.count == maxCount ? currentTopic : picks.first(where: { topics[$0.topic]?.count == maxCount })?.topic
        guard let pick = picks.first(where: { $0.topic == preferredTopic }),
              let destination = URL(string: pick.url), destination.scheme == "https" else { return nil }
        var lines = ["month=\(month)"]
        for pick in picks { lines.append("topic.\(pick.topic)=\((topics[pick.topic] ?? []).joined(separator: ","))") }
        do { try (lines.joined(separator: "\n") + "\n").write(to: stateURL, atomically: true, encoding: .utf8) }
        catch { return nil }
        guard state["month"] != month else { return nil }
        return Self(title: pick.title, url: destination)
    }
}

let recommendation = LocalRecommendation.showIfDue(
    title: chatTitle,
    action: actionText,
    enabled: recommendationsEnabled,
    hasAuthContext: hasAuthContext,
    statePath: recommendationStatePath
)
let canOpenChat: Bool = {
    guard let components = URLComponents(string: chatURL),
          components.scheme == "https",
          ["chatgpt.com", "chat.openai.com"].contains(components.host ?? "") else { return false }
    return true
}()
let actionURL: URL? = {
    guard let components = URLComponents(string: actionURLValue),
          components.scheme == "https", components.host != nil,
          components.user == nil, components.password == nil else { return nil }
    return components.url
}()
// Prefer the signed Easy Paster App Store app when its URL scheme is registered.
// The open-source companion remains usable on its own when the app is absent.
if let probeURL = URL(string: "easypaster://needs-you"),
   let handlerURL = NSWorkspace.shared.urlForApplication(toOpen: probeURL),
   Bundle(url: handlerURL)?.bundleIdentifier == "app.flowguardian.mac" {
    var handoff = URLComponents()
    handoff.scheme = "easypaster"
    handoff.host = "needs-you"
    handoff.queryItems = [
        URLQueryItem(name: "title", value: chatTitle),
        URLQueryItem(name: "message", value: actionText),
        URLQueryItem(name: "chatURL", value: chatURL),
        URLQueryItem(name: "actionURL", value: actionURL?.absoluteString ?? ""),
        URLQueryItem(name: "service", value: authService),
        URLQueryItem(name: "account", value: authAccount),
        URLQueryItem(name: "threadID", value: resumeThreadID)
    ]
    if let url = handoff.url, NSWorkspace.shared.open(url) { exit(0) }
}
let reissueAvailableAt = retryAfter > 0 ? retryAfter : linkExpiresAt
let hasAuthControls = !actionURLValue.isEmpty || reissueAvailableAt > 0

func refreshAuthControls() {
    guard let authStatusLabel else { return }
    guard !authStatusIsActionResult else { return }
    let now = Date().timeIntervalSince1970
    authLinkButton?.isEnabled = actionURL != nil && (linkExpiresAt == 0 || now < linkExpiresAt)
    reissueButton?.isEnabled = reissueAvailableAt > 0 && now >= reissueAvailableAt
    if !actionURLValue.isEmpty && actionURL == nil {
        authStatusLabel.stringValue = "보안을 위해 HTTPS 요청 주소만 열 수 있습니다."
    } else if retryAfter > now {
        let seconds = Int(retryAfter - now)
        authStatusLabel.stringValue = "요청 제한 중 · 새 링크 요청까지 \(seconds / 60)분 \(seconds % 60)초"
    } else if retryAfter > 0 && now >= retryAfter {
        authStatusLabel.stringValue = "요청 제한 해제 · 새 인증 링크를 요청할 수 있어요."
    } else if linkExpiresAt > 0 && now >= linkExpiresAt {
        authStatusLabel.stringValue = "인증 링크 만료 · 새 링크 요청 가능"
    } else if linkExpiresAt > now {
        let seconds = Int(linkExpiresAt - now)
        authStatusLabel.stringValue = "인증 링크 유효 · 만료까지 \(seconds / 60)분 \(seconds % 60)초"
    } else if linkExpiresAt > 0 {
        authStatusLabel.stringValue = "인증 링크가 만료되었습니다. 새 링크를 요청하세요."
    } else {
        authStatusLabel.stringValue = "요청 페이지를 열고, 이 알림은 확인 전까지 남겨 두세요."
    }
}

final class AlertActions: NSObject, NSGestureRecognizerDelegate {
    let pauseUntilPath: String
    let recommendationURL: URL?
    let actionURL: URL?
    let linkExpiresAt: TimeInterval
    let reissueAvailableAt: TimeInterval
    let alertWindow: NSWindow
    let appearanceSettingsPath: String
    let resumeThreadID: String
    let resumeMessage: String
    var appearanceSettingsProcess: Process?
    init(pauseUntilPath: String, recommendationURL: URL?, actionURL: URL?, linkExpiresAt: TimeInterval, reissueAvailableAt: TimeInterval, alertWindow: NSWindow, appearanceSettingsPath: String, resumeThreadID: String, resumeMessage: String) {
        self.pauseUntilPath = pauseUntilPath
        self.recommendationURL = recommendationURL
        self.actionURL = actionURL
        self.linkExpiresAt = linkExpiresAt
        self.reissueAvailableAt = reissueAvailableAt
        self.alertWindow = alertWindow
        self.appearanceSettingsPath = appearanceSettingsPath
        self.resumeThreadID = resumeThreadID
        self.resumeMessage = resumeMessage
    }

    @objc func acknowledge(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc func bringAlertForward(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        alertWindow.level = .floating
        alertWindow.makeKeyAndOrderFront(nil)
        alertWindow.orderFrontRegardless()
    }

    private func moveAlertBehindDestination() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard self.alertWindow.isVisible else { return }
            self.alertWindow.level = .normal
            self.alertWindow.orderBack(nil)
        }
    }

    @objc func openAppearanceSettings(_ sender: Any?) {
        guard !appearanceSettingsPath.isEmpty else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [appearanceSettingsPath, colorsPath]
        do { try process.run(); appearanceSettingsProcess = process }
        catch { NSSound.beep() }
    }

    @objc func openActionLink(_ sender: Any?) {
        guard let actionURL else { return }
        guard linkExpiresAt == 0 || Date().timeIntervalSince1970 < linkExpiresAt else {
            refreshAuthControls()
            return
        }
        guard NSWorkspace.shared.open(actionURL) else {
            authStatusLabel?.stringValue = "요청 페이지를 열지 못했습니다. 다시 눌러 주세요."
            NSSound.beep()
            return
        }
        authStatusLabel?.stringValue = "요청 페이지를 열었습니다. 이 알림은 계속 남아 있습니다."
        authStatusIsActionResult = true
        moveAlertBehindDestination()
    }

    @objc func requestNewLoginLink(_ sender: Any?) {
        guard reissueAvailableAt > 0, Date().timeIntervalSince1970 >= reissueAvailableAt else { return }
        let service = authService.isEmpty ? "인증 서비스" : authService
        let account = authAccount.isEmpty ? "계정 확인 필요" : authAccount
        let message = "\(service) 계정 \(account)의 이전 인증 링크/코드가 만료되었거나 재요청 제한이 끝났습니다. 이전 값은 재사용하지 말고 새 인증 링크 또는 코드를 발급해 주세요."
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
        if canOpenChat, let url = URL(string: chatURL), NSWorkspace.shared.open(url) { moveAlertBehindDestination() }
        authStatusLabel?.stringValue = "새 인증 요청 문구를 복사했습니다. 대화창에서 붙여넣어 전송하세요."
        authStatusIsActionResult = true
    }

    @objc func pauseForDay(_ sender: Any?) {
        let expiry = Int(Date().timeIntervalSince1970 + 24 * 60 * 60)
        try? "\(expiry)\n".write(toFile: pauseUntilPath, atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }

    @objc func toggleSound(_ sender: NSButton) {
        soundEnabled.toggle()
        sender.title = soundEnabled ? "소리 끄기" : "소리 켜기"
        sender.attributedTitle = NSAttributedString(string: sender.title, attributes: [.foregroundColor: buttonTextColor.withAlphaComponent(alpha("button-text")), .font: sender.font ?? .systemFont(ofSize: 13, weight: .medium)])
        if !preferencePath.isEmpty {
            try? (soundEnabled ? "on\n" : "off\n").write(toFile: preferencePath, atomically: true, encoding: .utf8)
        }
    }

    @objc func openChat(_ sender: Any?) {
        guard canOpenChat, let url = URL(string: chatURL) else {
            showActionStatus("이 알림에는 유효한 채팅 링크가 없습니다.")
            NSSound.beep()
            return
        }
        guard NSWorkspace.shared.open(url) else {
            showActionStatus("채팅을 열지 못했습니다. 다시 눌러 주세요.")
            NSSound.beep()
            return
        }
        showActionStatus("채팅을 열었습니다. 알림은 메뉴 막대 GPT에서 다시 열 수 있습니다.")
        moveAlertBehindDestination()
    }

    @objc func resume(_ sender: NSButton) {
        guard UUID(uuidString: resumeThreadID) != nil else { return }
        let paths = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex"] + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { URL(fileURLWithPath: String($0)).appendingPathComponent("codex").path }
        guard let executable = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            showActionStatus(tr("Codex CLI를 찾지 못했습니다. 설치 후 다시 시도해 주세요.", "Codex CLI was not found. Install it and try again.", "Codex CLI が見つかりません。インストールして再試行してください。", "找不到 Codex CLI。请安装后重试。"))
            NSSound.beep()
            return
        }
        sender.isEnabled = false
        showActionStatus(tr("요청을 대화에 보내는 중…", "Sending the resume request…", "再開リクエストを送信中…", "正在发送继续请求…"))
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["queue", "--thread", self.resumeThreadID, "--message", self.resumeMessage]
            var environment = ProcessInfo.processInfo.environment
            let inheritedPath = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
            var searchPaths: [String] = []
            for path in ["/opt/homebrew/bin", "/usr/local/bin"] + inheritedPath where !searchPaths.contains(path) {
                searchPaths.append(path)
            }
            environment["PATH"] = searchPaths.joined(separator: ":")
            process.environment = environment
            process.standardOutput = FileHandle.nullDevice
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardInput = FileHandle.nullDevice
            do {
                try process.run()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                try? errorPipe.fileHandleForReading.close()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .split(whereSeparator: \.isNewline)
                    .first
                    .map(String.init) ?? ""
                DispatchQueue.main.async {
                    sender.isEnabled = true
                    if process.terminationStatus == 0 {
                        let openedThread = URL(string: "codex://threads/\(self.resumeThreadID)").map { NSWorkspace.shared.open($0) } ?? false
                        let sent = tr("재개 요청을 보냈습니다. Codex가 기존 작업을 확인합니다.", "Resume request sent. Codex will check the existing task.", "再開リクエストを送信しました。Codex が既存の作業を確認します。", "已发送继续请求。Codex 将检查现有任务。")
                        showActionStatus(openedThread ? sent : sent + " Codex 대화를 열지 못했습니다.")
                        if openedThread { self.moveAlertBehindDestination() }
                    } else {
                        let detail = String(errorText.prefix(160))
                        let fallback = tr("보내지 못했습니다. Codex 채팅을 열어 다시 시도해 주세요.", "Could not send. Open the Codex chat and try again.", "送信できませんでした。Codex チャットを開いて再試行してください。", "发送失败。请打开 Codex 对话并重试。")
                        showActionStatus(detail.isEmpty ? fallback : "\(fallback) (\(detail))")
                        NSSound.beep()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    sender.isEnabled = true
                    showActionStatus(tr("보내지 못했습니다. Codex 채팅을 열어 다시 시도해 주세요.", "Could not send. Open the Codex chat and try again.", "送信できませんでした。Codex チャットを開いて再試行してください。", "发送失败。请打开 Codex 对话并重试。"))
                    NSSound.beep()
                }
            }
        }
    }

    @objc func openRecommendation(_ sender: Any?) {
        guard let recommendationURL else { return }
        NSWorkspace.shared.open(recommendationURL)
    }

    @objc func openChatFromCard(_ sender: Any?) {
        openChat(sender)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        guard canOpenChat, let view = gestureRecognizer.view else { return false }
        return !(view.hitTest(gestureRecognizer.location(in: view)) is NSButton)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let expandedAuthCard = hasAuthControls
let size = NSSize(width: 520, height: expandedAuthCard ? 322 : ((hasAuthContext || recommendation != nil) ? 276 : 242))
let window = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
window.title = "ChatGPT Attention Alert"
window.hidesOnDeactivate = false
window.isFloatingPanel = true
window.isMovableByWindowBackground = true
window.isOpaque = false
window.backgroundColor = .clear
window.level = .floating
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
var stackIndex = 0
if !stackPath.isEmpty {
    let fd = open(stackPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    if fd >= 0 {
        flock(fd, LOCK_EX)
        var buffer = [CChar](repeating: 0, count: 32)
        let count = read(fd, &buffer, buffer.count - 1)
        if count > 0 { stackIndex = Int(String(cString: buffer)) ?? 0 }
        lseek(fd, 0, SEEK_SET)
        ftruncate(fd, 0)
        let next = Array("\(stackIndex + 1)".utf8)
        _ = next.withUnsafeBytes { write(fd, $0.baseAddress, next.count) }
        flock(fd, LOCK_UN)
        close(fd)
    }
}
let stackSlots = max(1, Int(min(screen.width - size.width, screen.height - size.height) / 28) + 1)
let offset = CGFloat(stackIndex % stackSlots) * 28
window.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 28 - offset, y: screen.maxY - size.height - 28 - offset))

let card = NSView(frame: NSRect(origin: .zero, size: size))
card.wantsLayer = true
card.layer?.backgroundColor = backgroundColor.withAlphaComponent(alpha("background", fallback: 0.82)).cgColor
card.layer?.cornerRadius = 20
card.layer?.borderWidth = 2
card.layer?.borderColor = accentColor.withAlphaComponent(0.95 * alpha("accent")).cgColor
card.layer?.shadowColor = accentColor.withAlphaComponent(alpha("accent")).cgColor
card.layer?.shadowOffset = .zero
card.layer?.shadowOpacity = 0.9
card.layer?.shadowRadius = 18
let pulse = CABasicAnimation(keyPath: "shadowRadius")
pulse.fromValue = 12
pulse.toValue = 30
pulse.duration = 0.85
pulse.autoreverses = true
pulse.repeatCount = .infinity
card.layer?.add(pulse, forKey: "glow")
window.contentView = card

let actions = AlertActions(pauseUntilPath: pauseUntilPath, recommendationURL: recommendation?.url, actionURL: actionURL, linkExpiresAt: linkExpiresAt, reissueAvailableAt: reissueAvailableAt, alertWindow: window, appearanceSettingsPath: appearanceSettingsPath, resumeThreadID: canResume ? resumeThreadID : "", resumeMessage: resumePrompt())
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = "GPT"
let statusMenu = NSMenu()
let showAlertItem = NSMenuItem(title: "GPT 알리미 열어줘", action: #selector(AlertActions.bringAlertForward(_:)), keyEquivalent: "")
showAlertItem.target = actions
statusMenu.addItem(showAlertItem)
statusMenu.addItem(.separator())
let appearanceItem = NSMenuItem(title: tr("색상·투명도 설정…", "Color & Opacity Settings…", "色と不透明度の設定…", "颜色和不透明度设置…"), action: #selector(AlertActions.openAppearanceSettings(_:)), keyEquivalent: "")
appearanceItem.target = actions
statusMenu.addItem(appearanceItem)
statusMenu.addItem(.separator())
let dismissAlertItem = NSMenuItem(title: "확인하고 닫기", action: #selector(AlertActions.acknowledge(_:)), keyEquivalent: "")
dismissAlertItem.target = actions
statusMenu.addItem(dismissAlertItem)
statusItem.menu = statusMenu
let heading = NSTextField(labelWithString: "GPT NEEDS YOU  ·  확인이 필요해요")
heading.frame = NSRect(x: 54, y: size.height - 36, width: 410, height: 20)
heading.font = .systemFont(ofSize: 13, weight: .bold)
heading.textColor = accentColor.withAlphaComponent(alpha("accent"))
card.addSubview(heading)
let closeButton = NSButton(title: "×", target: actions, action: #selector(AlertActions.acknowledge(_:)))
closeButton.frame = NSRect(x: 16, y: size.height - 40, width: 28, height: 28)
closeButton.bezelStyle = .rounded
styleButton(closeButton, prominent: true)
card.addSubview(closeButton)

let title = NSTextField(wrappingLabelWithString: chatTitle)
title.frame = NSRect(x: 22, y: expandedAuthCard ? 244 : (hasAuthContext || recommendation != nil) ? 196 : 164, width: 470, height: 38)
title.font = .systemFont(ofSize: 21, weight: .semibold)
title.textColor = textColor.withAlphaComponent(alpha("text"))
title.maximumNumberOfLines = 2
card.addSubview(title)

if hasAuthContext {
    let service = authService.isEmpty ? "인증 서비스 확인 필요" : authService
    let account = authAccount.isEmpty ? "계정 확인 필요" : authAccount
    let identity = NSTextField(labelWithString: "인증 대상  ·  \(service)  ·  \(account)")
    identity.frame = NSRect(x: 22, y: expandedAuthCard ? 214 : 166, width: 470, height: 18)
    identity.font = .systemFont(ofSize: 13)
    identity.textColor = textColor.withAlphaComponent(0.78 * alpha("text"))
    card.addSubview(identity)
}

let action = NSTextField(wrappingLabelWithString: actionText)
action.frame = NSRect(x: 22, y: expandedAuthCard ? 130 : recommendation == nil ? 80 : 100, width: 468, height: expandedAuthCard ? 66 : recommendation == nil ? 70 : 50)
action.font = .systemFont(ofSize: 15)
action.textColor = textColor.withAlphaComponent(0.9 * alpha("text"))
action.maximumNumberOfLines = 3
card.addSubview(action)
actionLabel = action

if let recommendation {
    let link = NSButton(title: "이번 달 개발자 추천: \(recommendation.title) ↗", target: actions, action: #selector(AlertActions.openRecommendation(_:)))
    link.frame = NSRect(x: 20, y: 48, width: 250, height: 18)
    link.isBordered = false
    link.alignment = .left
    link.font = .systemFont(ofSize: 10, weight: .medium)
    link.contentTintColor = NSColor(calibratedRed: 0.55, green: 0.89, blue: 0.76, alpha: alpha("accent"))
    card.addSubview(link)

    let note = NSTextField(labelWithString: "관심 주제는 기기에만 저장 · 추천 AI 토큰 0 · 대화 본문 미저장")
    note.frame = NSRect(x: 270, y: 48, width: 230, height: 18)
    note.font = .systemFont(ofSize: 8)
    note.textColor = NSColor(calibratedWhite: 0.68, alpha: alpha("text"))
    card.addSubview(note)
}

if !expandedAuthCard {
    let status = NSTextField(labelWithString: "")
    status.frame = NSRect(x: 22, y: recommendation == nil ? 48 : 72, width: 476, height: 15)
    status.font = .systemFont(ofSize: 10, weight: .medium)
    status.textColor = NSColor(calibratedWhite: 0.72, alpha: alpha("text"))
    card.addSubview(status)
    actionStatusLabel = status
}

if expandedAuthCard {
    let status = NSTextField(labelWithString: "")
    status.frame = NSRect(x: 22, y: 96, width: 476, height: 18)
    status.font = .systemFont(ofSize: 11, weight: .medium)
    status.textColor = NSColor(calibratedRed: 0.55, green: 0.9, blue: 0.76, alpha: alpha("text"))
    card.addSubview(status)
    authStatusLabel = status
    if actionURL != nil {
        let openLink = NSButton(title: "요청 페이지 열기", target: actions, action: #selector(AlertActions.openActionLink(_:)))
        openLink.frame = NSRect(x: 22, y: 54, width: 220, height: 30)
        openLink.bezelStyle = .rounded
        card.addSubview(openLink)
        styleButton(openLink, prominent: true)
        authLinkButton = openLink
    }
    if reissueAvailableAt > 0 {
        let reissue = NSButton(title: "새 인증 링크 요청", target: actions, action: #selector(AlertActions.requestNewLoginLink(_:)))
        reissue.frame = NSRect(x: 258, y: 54, width: 240, height: 30)
        reissue.bezelStyle = .rounded
        card.addSubview(reissue)
        styleButton(reissue)
        reissueButton = reissue
    }
    refreshAuthControls()
    if reissueAvailableAt > 0 {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in refreshAuthControls() }
    }
}

let cardClick = NSClickGestureRecognizer(target: actions, action: #selector(AlertActions.openChatFromCard(_:)))
cardClick.delegate = actions
card.addGestureRecognizer(cardClick)
let sound = NSButton(title: soundEnabled ? "소리 끄기" : "소리 켜기", target: actions, action: #selector(AlertActions.toggleSound(_:)))
sound.frame = NSRect(x: 16, y: 16, width: canResume ? 86 : 104, height: 28)
sound.bezelStyle = .rounded
styleButton(sound)
card.addSubview(sound)
let pause = NSButton(title: "24시간 중지", target: actions, action: #selector(AlertActions.pauseForDay(_:)))
pause.frame = NSRect(x: canResume ? 108 : 136, y: 16, width: canResume ? 112 : 140, height: 28)
pause.bezelStyle = .rounded
styleButton(pause)
card.addSubview(pause)

if canOpenChat {
    let open = NSButton(title: tr("채팅 열기", "Open chat", "チャットを開く", "打开对话"), target: actions, action: #selector(AlertActions.openChat(_:)))
    open.frame = NSRect(x: canResume ? 228 : 300, y: 16, width: canResume ? 90 : 96, height: 28)
    open.bezelStyle = .rounded
    styleButton(open)
    card.addSubview(open)
}

if canResume {
    let resume = NSButton(title: tr("작업 재개", "Resume", "再開", "继续"), target: actions, action: #selector(AlertActions.resume(_:)))
    resume.frame = NSRect(x: 326, y: 16, width: 96, height: 28)
    resume.bezelStyle = .rounded
    styleButton(resume, prominent: true)
    card.addSubview(resume)
}

let done = NSButton(title: "확인", target: actions, action: #selector(AlertActions.acknowledge(_:)))
done.frame = NSRect(x: canResume ? 430 : 420, y: 16, width: canResume ? 72 : 76, height: 28)
done.bezelStyle = .rounded
styleButton(done, prominent: true)
card.addSubview(done)

DispatchQueue.main.async {
    app.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
}
if soundEnabled {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        let chosenSound = !customSoundPath.isEmpty && FileManager.default.fileExists(atPath: customSoundPath)
            ? customSoundPath
            : "/System/Library/Sounds/Sosumi.aiff"
        let player = Process()
        player.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        player.arguments = [chosenSound]
        try? player.run()
    }
}
app.run()
