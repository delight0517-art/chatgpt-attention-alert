import AppKit
import QuartzCore
import Darwin

let chatTitle = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Chat title unavailable"
let actionText = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Please check this chat."
let chatURL = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : ""
let preferencePath = CommandLine.arguments.count > 5 ? CommandLine.arguments[5] : ""
let stackPath = CommandLine.arguments.count > 6 ? CommandLine.arguments[6] : ""
var soundEnabled = CommandLine.arguments.count <= 4 || CommandLine.arguments[4] != "off"
let canOpenChat: Bool = {
    guard let components = URLComponents(string: chatURL),
          components.scheme == "https",
          ["chatgpt.com", "chat.openai.com"].contains(components.host ?? "") else { return false }
    return true
}()

final class AlertActions: NSObject, NSGestureRecognizerDelegate {
    @objc func acknowledge(_ sender: Any?) {
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
        guard canOpenChat, let url = URL(string: chatURL) else { return }
        NSWorkspace.shared.open(url)
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
let size = NSSize(width: 520, height: 220)
let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
window.title = "ChatGPT Attention Alert"
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
card.layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.09, blue: 0.14, alpha: 1).cgColor
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

let heading = NSTextField(labelWithString: "GPT NEEDS YOU  ·  확인이 필요해요")
heading.frame = NSRect(x: 22, y: 184, width: 470, height: 20)
heading.font = .systemFont(ofSize: 13, weight: .bold)
heading.textColor = NSColor(calibratedRed: 0.38, green: 0.92, blue: 1, alpha: 1)
card.addSubview(heading)

let title = NSTextField(wrappingLabelWithString: chatTitle)
title.frame = NSRect(x: 22, y: 142, width: 470, height: 38)
title.font = .systemFont(ofSize: 21, weight: .semibold)
title.textColor = .white
title.maximumNumberOfLines = 2
card.addSubview(title)

let action = NSTextField(wrappingLabelWithString: actionText)
action.frame = NSRect(x: 22, y: 58, width: 468, height: 70)
action.font = .systemFont(ofSize: 15)
action.textColor = NSColor(calibratedWhite: 0.88, alpha: 1)
action.maximumNumberOfLines = 3
card.addSubview(action)

let actions = AlertActions()
let cardClick = NSClickGestureRecognizer(target: actions, action: #selector(AlertActions.openChatFromCard(_:)))
cardClick.delegate = actions
card.addGestureRecognizer(cardClick)
let sound = NSButton(title: soundEnabled ? "소리 끄기" : "소리 켜기", target: actions, action: #selector(AlertActions.toggleSound(_:)))
sound.frame = NSRect(x: 20, y: 16, width: 104, height: 28)
sound.bezelStyle = .rounded
card.addSubview(sound)

if canOpenChat {
    let open = NSButton(title: "채팅 열기", target: actions, action: #selector(AlertActions.openChat(_:)))
    open.frame = NSRect(x: 300, y: 16, width: 96, height: 28)
    open.bezelStyle = .rounded
    card.addSubview(open)
}

let done = NSButton(title: "확인", target: actions, action: #selector(AlertActions.acknowledge(_:)))
done.frame = NSRect(x: 420, y: 16, width: 76, height: 28)
done.bezelStyle = .rounded
done.keyEquivalent = "\r"
card.addSubview(done)

window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
