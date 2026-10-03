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
var authStatusLabel: NSTextField?
var authLinkButton: NSButton?
var reissueButton: NSButton?
let actionURLValue = CommandLine.arguments.count > 13 ? CommandLine.arguments[13] : ""
let linkExpiresAt = CommandLine.arguments.count > 14 ? TimeInterval(CommandLine.arguments[14]) ?? 0 : 0
let retryAfter = CommandLine.arguments.count > 15 ? TimeInterval(CommandLine.arguments[15]) ?? 0 : 0
let sharedStateHelperPath = CommandLine.arguments.count > 17 ? CommandLine.arguments[17] : ""
let sharedStateDirectory = CommandLine.arguments.count > 18 ? CommandLine.arguments[18] : ""
let wrapperPath = CommandLine.arguments.count > 19 ? CommandLine.arguments[19] : ""
let hasAuthContext = !authService.isEmpty || !authAccount.isEmpty || !actionURLValue.isEmpty || linkExpiresAt > 0 || retryAfter > 0
var authStatusIsActionResult = false

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
    let sharedStateHelperPath: String
    let sharedStateDirectory: String
    let wrapperPath: String
    init(pauseUntilPath: String, recommendationURL: URL?, actionURL: URL?, linkExpiresAt: TimeInterval, reissueAvailableAt: TimeInterval, alertWindow: NSWindow, sharedStateHelperPath: String, sharedStateDirectory: String, wrapperPath: String) {
        self.pauseUntilPath = pauseUntilPath
        self.recommendationURL = recommendationURL
        self.actionURL = actionURL
        self.linkExpiresAt = linkExpiresAt
        self.reissueAvailableAt = reissueAvailableAt
        self.alertWindow = alertWindow
        self.sharedStateHelperPath = sharedStateHelperPath
        self.sharedStateDirectory = sharedStateDirectory
        self.wrapperPath = wrapperPath
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

    @objc func openActionLink(_ sender: Any?) {
        guard let actionURL else { return }
        guard linkExpiresAt == 0 || Date().timeIntervalSince1970 < linkExpiresAt else {
            refreshAuthControls()
            return
        }
        NSApp.windows.forEach { $0.level = .normal }
        guard NSWorkspace.shared.open(actionURL) else {
            authStatusLabel?.stringValue = "요청 페이지를 열지 못했습니다. 다시 눌러 주세요."
            NSSound.beep()
            return
        }
        authStatusLabel?.stringValue = "요청 페이지를 열었습니다. 이 알림은 계속 남아 있습니다."
        authStatusIsActionResult = true
    }

    @objc func requestNewLoginLink(_ sender: Any?) {
        guard reissueAvailableAt > 0, Date().timeIntervalSince1970 >= reissueAvailableAt else { return }
        let service = authService.isEmpty ? "인증 서비스" : authService
        let account = authAccount.isEmpty ? "계정 확인 필요" : authAccount
        let message = "\(service) 계정 \(account)의 이전 인증 링크/코드가 만료되었거나 재요청 제한이 끝났습니다. 이전 값은 재사용하지 말고 새 인증 링크 또는 코드를 발급해 주세요."
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
        if canOpenChat, let url = URL(string: chatURL) { NSWorkspace.shared.open(url) }
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
        if !preferencePath.isEmpty {
            try? (soundEnabled ? "on\n" : "off\n").write(toFile: preferencePath, atomically: true, encoding: .utf8)
        }
        guard !sharedStateDirectory.isEmpty, !sharedStateHelperPath.isEmpty else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", sharedStateHelperPath, "set", "sound", soundEnabled ? "on" : "off"]
        var environment = ProcessInfo.processInfo.environment
        environment["CHATGPT_ALERT_SHARED_STATE_DIR"] = sharedStateDirectory
        process.environment = environment
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 { recordSharedStateUnavailable() }
            else { recordSharedStateAvailable() }
        } catch {
            recordSharedStateUnavailable()
        }
    }

    private func recordSharedStateUnavailable() {
        runWrapperHealthCommand("--record-shared-state-unavailable")
    }

    private func recordSharedStateAvailable() {
        runWrapperHealthCommand("--record-shared-state-available")
    }

    private func runWrapperHealthCommand(_ argument: String) {
        guard !wrapperPath.isEmpty else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [wrapperPath, argument]
        try? process.run()
    }

    @objc func openChat(_ sender: Any?) {
        guard canOpenChat, let url = URL(string: chatURL) else {
            actionLabel?.stringValue = "이 알림에는 유효한 채팅 링크가 없습니다."
            NSSound.beep()
            return
        }
        NSApp.windows.forEach { $0.level = .normal }
        guard NSWorkspace.shared.open(url) else {
            actionLabel?.stringValue = "채팅을 열지 못했습니다. 다시 눌러 주세요."
            NSSound.beep()
            return
        }
        actionLabel?.stringValue = "대화창을 열었습니다. 이 알림은 확인을 누를 때까지 유지됩니다."
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
let size = NSSize(width: 520, height: expandedAuthCard ? 322 : (hasAuthContext || recommendation != nil) ? 252 : 220)
let window = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
window.title = "ChatGPT Attention Alert"
window.hidesOnDeactivate = false
window.isFloatingPanel = true
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
card.layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.09, blue: 0.14, alpha: 0.82).cgColor
card.layer?.cornerRadius = 20
card.layer?.borderWidth = 2
card.layer?.borderColor = NSColor(calibratedRed: 0.24, green: 0.88, blue: 1, alpha: 0.95).cgColor
card.layer?.shadowColor = NSColor(calibratedRed: 0.1, green: 0.78, blue: 1, alpha: 1).cgColor
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

let actions = AlertActions(pauseUntilPath: pauseUntilPath, recommendationURL: recommendation?.url, actionURL: actionURL, linkExpiresAt: linkExpiresAt, reissueAvailableAt: reissueAvailableAt, alertWindow: window, sharedStateHelperPath: sharedStateHelperPath, sharedStateDirectory: sharedStateDirectory, wrapperPath: wrapperPath)
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = "GPT"
let statusMenu = NSMenu()
let showAlertItem = NSMenuItem(title: "GPT 알리미 열어줘", action: #selector(AlertActions.bringAlertForward(_:)), keyEquivalent: "")
showAlertItem.target = actions
statusMenu.addItem(showAlertItem)
statusMenu.addItem(.separator())
let dismissAlertItem = NSMenuItem(title: "확인하고 닫기", action: #selector(AlertActions.acknowledge(_:)), keyEquivalent: "")
dismissAlertItem.target = actions
statusMenu.addItem(dismissAlertItem)
statusItem.menu = statusMenu
let heading = NSTextField(labelWithString: "GPT NEEDS YOU  ·  확인이 필요해요")
heading.frame = NSRect(x: 54, y: size.height - 36, width: 410, height: 20)
heading.font = .systemFont(ofSize: 13, weight: .bold)
heading.textColor = NSColor(calibratedRed: 0.38, green: 0.92, blue: 1, alpha: 1)
card.addSubview(heading)
let closeButton = NSButton(title: "×", target: actions, action: #selector(AlertActions.acknowledge(_:)))
closeButton.frame = NSRect(x: 16, y: size.height - 40, width: 28, height: 28)
closeButton.bezelStyle = .rounded
card.addSubview(closeButton)

let title = NSTextField(wrappingLabelWithString: chatTitle)
title.frame = NSRect(x: 22, y: expandedAuthCard ? 244 : (hasAuthContext || recommendation != nil) ? 174 : 142, width: 470, height: 38)
title.font = .systemFont(ofSize: 21, weight: .semibold)
title.textColor = .white
title.maximumNumberOfLines = 2
card.addSubview(title)

if hasAuthContext {
    let service = authService.isEmpty ? "인증 서비스 확인 필요" : authService
    let account = authAccount.isEmpty ? "계정 확인 필요" : authAccount
    let identity = NSTextField(labelWithString: "인증 대상  ·  \(service)  ·  \(account)")
    identity.frame = NSRect(x: 22, y: expandedAuthCard ? 214 : 144, width: 470, height: 18)
    identity.font = .systemFont(ofSize: 13)
    identity.textColor = NSColor(calibratedRed: 0.65, green: 0.83, blue: 0.9, alpha: 1)
    card.addSubview(identity)
}

let action = NSTextField(wrappingLabelWithString: actionText)
action.frame = NSRect(x: 22, y: expandedAuthCard ? 130 : recommendation == nil ? 58 : 78, width: 468, height: expandedAuthCard ? 66 : recommendation == nil ? 70 : 50)
action.font = .systemFont(ofSize: 15)
action.textColor = NSColor(calibratedWhite: 0.88, alpha: 1)
action.maximumNumberOfLines = 3
card.addSubview(action)
actionLabel = action

if let recommendation {
    let link = NSButton(title: "이번 달 개발자 추천: \(recommendation.title) ↗", target: actions, action: #selector(AlertActions.openRecommendation(_:)))
    link.frame = NSRect(x: 20, y: 48, width: 250, height: 18)
    link.isBordered = false
    link.alignment = .left
    link.font = .systemFont(ofSize: 10, weight: .medium)
    link.contentTintColor = NSColor(calibratedRed: 0.55, green: 0.89, blue: 0.76, alpha: 1)
    card.addSubview(link)

    let note = NSTextField(labelWithString: "관심 주제는 기기에만 저장 · 추천 AI 토큰 0 · 대화 본문 미저장")
    note.frame = NSRect(x: 270, y: 48, width: 230, height: 18)
    note.font = .systemFont(ofSize: 8)
    note.textColor = NSColor(calibratedWhite: 0.68, alpha: 1)
    card.addSubview(note)
}

if expandedAuthCard {
    let status = NSTextField(labelWithString: "")
    status.frame = NSRect(x: 22, y: 96, width: 476, height: 18)
    status.font = .systemFont(ofSize: 11, weight: .medium)
    status.textColor = NSColor(calibratedRed: 0.55, green: 0.9, blue: 0.76, alpha: 1)
    card.addSubview(status)
    authStatusLabel = status
    if actionURL != nil {
        let openLink = NSButton(title: "요청 페이지 열기", target: actions, action: #selector(AlertActions.openActionLink(_:)))
        openLink.frame = NSRect(x: 22, y: 54, width: 220, height: 30)
        openLink.bezelStyle = .rounded
        card.addSubview(openLink)
        authLinkButton = openLink
    }
    if reissueAvailableAt > 0 {
        let reissue = NSButton(title: "새 인증 링크 요청", target: actions, action: #selector(AlertActions.requestNewLoginLink(_:)))
        reissue.frame = NSRect(x: 258, y: 54, width: 240, height: 30)
        reissue.bezelStyle = .rounded
        card.addSubview(reissue)
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
sound.frame = NSRect(x: 20, y: 16, width: 104, height: 28)
sound.bezelStyle = .rounded
card.addSubview(sound)
let pause = NSButton(title: "24시간 중지", target: actions, action: #selector(AlertActions.pauseForDay(_:)))
pause.frame = NSRect(x: 136, y: 16, width: 140, height: 28)
pause.bezelStyle = .rounded
card.addSubview(pause)

if canOpenChat {
    let open = NSButton(title: "채팅 열기", target: actions, action: #selector(AlertActions.openChat(_:)))
    open.frame = NSRect(x: 300, y: 16, width: 96, height: 28)
    open.bezelStyle = .rounded
    card.addSubview(open)
}

let done = NSButton(title: "확인", target: actions, action: #selector(AlertActions.acknowledge(_:)))
done.frame = NSRect(x: 420, y: 16, width: 76, height: 28)
done.bezelStyle = .rounded
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
