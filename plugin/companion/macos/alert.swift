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
let hasAuthContext = !authService.isEmpty || !authAccount.isEmpty
var actionLabel: NSTextField?

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

final class AlertActions: NSObject, NSGestureRecognizerDelegate {
    let pauseUntilPath: String
    let recommendationURL: URL?
    init(pauseUntilPath: String, recommendationURL: URL?) {
        self.pauseUntilPath = pauseUntilPath
        self.recommendationURL = recommendationURL
    }

    @objc func acknowledge(_ sender: Any?) {
        NSApp.terminate(nil)
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
    }

    @objc func openChat(_ sender: Any?) {
        guard canOpenChat, let url = URL(string: chatURL) else {
            actionLabel?.stringValue = "이 알림에는 유효한 채팅 링크가 없습니다."
            NSSound.beep()
            return
        }
        guard NSWorkspace.shared.open(url) else {
            actionLabel?.stringValue = "채팅을 열지 못했습니다. 다시 눌러 주세요."
            NSSound.beep()
            return
        }
        NSApp.terminate(nil)
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
let size = NSSize(width: 520, height: (hasAuthContext || recommendation != nil) ? 252 : 220)
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

let actions = AlertActions(pauseUntilPath: pauseUntilPath, recommendationURL: recommendation?.url)
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
title.frame = NSRect(x: 22, y: (hasAuthContext || recommendation != nil) ? 174 : 142, width: 470, height: 38)
title.font = .systemFont(ofSize: 21, weight: .semibold)
title.textColor = .white
title.maximumNumberOfLines = 2
card.addSubview(title)

if hasAuthContext {
    let service = authService.isEmpty ? "인증 서비스 확인 필요" : authService
    let account = authAccount.isEmpty ? "계정 확인 필요" : authAccount
    let identity = NSTextField(labelWithString: "인증 대상  ·  \(service)  ·  \(account)")
    identity.frame = NSRect(x: 22, y: 144, width: 470, height: 18)
    identity.font = .systemFont(ofSize: 13)
    identity.textColor = NSColor(calibratedRed: 0.65, green: 0.83, blue: 0.9, alpha: 1)
    card.addSubview(identity)
}

let action = NSTextField(wrappingLabelWithString: actionText)
action.frame = NSRect(x: 22, y: recommendation == nil ? 58 : 78, width: 468, height: recommendation == nil ? 70 : 50)
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
