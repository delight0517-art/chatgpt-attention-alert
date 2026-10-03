import AppKit

final class AppearanceSettings: NSObject, NSWindowDelegate {
    private let path: String
    private let roles = ["background", "accent", "text", "button", "button-text"]
    private let names = ["카드 배경", "강조색", "글자", "버튼 배경", "버튼 글자"]
    private let defaults = ["#0E1724", "#61EBFF", "#FFFFFF", "#24405A", "#FFFFFF"]
    private let defaultOpacity = [82.0, 100, 100, 100, 100]
    private var colors: [NSTextField] = []
    private var sliders: [NSSlider] = []
    private var percentages: [NSTextField] = []
    private let status = NSTextField(labelWithString: "새 알림부터 적용됩니다.")
    private var window: NSWindow!

    init(path: String) {
        self.path = path
        super.init()
    }

    func show() {
        NSApplication.shared.setActivationPolicy(.accessory)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 405), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "GPT 알리미 모양 설정"
        window.center()
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 405))
        window.contentView = content

        let heading = NSTextField(labelWithString: "알림 색상과 투명도를 설정하세요")
        heading.frame = NSRect(x: 24, y: 360, width: 570, height: 24)
        heading.font = .systemFont(ofSize: 17, weight: .semibold)
        content.addSubview(heading)

        let help = NSTextField(labelWithString: "색상은 #RRGGBB · 불투명도 0%는 투명, 100%는 불투명")
        help.frame = NSRect(x: 24, y: 337, width: 570, height: 18)
        help.font = .systemFont(ofSize: 11)
        help.textColor = .secondaryLabelColor
        content.addSubview(help)

        let saved = readSettings()
        for index in roles.indices {
            let y = CGFloat(294 - index * 48)
            let name = NSTextField(labelWithString: names[index])
            name.frame = NSRect(x: 24, y: y + 4, width: 105, height: 20)
            content.addSubview(name)

            let colorField = NSTextField(string: saved.colors[roles[index]] ?? defaults[index])
            colorField.frame = NSRect(x: 132, y: y, width: 98, height: 28)
            colors.append(colorField)
            content.addSubview(colorField)

            let slider = NSSlider(value: saved.opacity[roles[index]] ?? defaultOpacity[index], minValue: 0, maxValue: 100, target: self, action: #selector(opacityChanged(_:)))
            slider.frame = NSRect(x: 244, y: y + 2, width: 270, height: 24)
            slider.tag = index
            sliders.append(slider)
            content.addSubview(slider)

            let percent = NSTextField(labelWithString: "\(Int(slider.doubleValue.rounded()))%")
            percent.frame = NSRect(x: 526, y: y + 4, width: 64, height: 20)
            percent.alignment = .right
            percentages.append(percent)
            content.addSubview(percent)
        }

        status.frame = NSRect(x: 24, y: 29, width: 350, height: 20)
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        content.addSubview(status)

        let reset = NSButton(title: "기본값", target: self, action: #selector(resetValues(_:)))
        reset.frame = NSRect(x: 395, y: 22, width: 88, height: 32)
        content.addSubview(reset)
        let save = NSButton(title: "저장", target: self, action: #selector(saveValues(_:)))
        save.frame = NSRect(x: 495, y: 22, width: 96, height: 32)
        save.keyEquivalent = "\r"
        content.addSubview(save)

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.run()
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        percentages[sender.tag].stringValue = "\(Int(sender.doubleValue.rounded()))%"
    }

    @objc private func saveValues(_ sender: Any?) {
        let values = colors.map { $0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        guard values.allSatisfy({ $0.range(of: #"^#[0-9A-F]{6}$"#, options: .regularExpression) != nil }) else {
            status.stringValue = "색상은 #RRGGBB 형식으로 입력해 주세요."
            status.textColor = .systemRed
            return
        }
        var lines: [String] = []
        for index in roles.indices {
            lines.append("\(roles[index])=\(values[index])")
            lines.append("opacity.\(roles[index])=\(Int(sliders[index].doubleValue.rounded()))")
        }
        do {
            try (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            status.stringValue = "저장했습니다. 새 알림부터 적용됩니다."
            status.textColor = .secondaryLabelColor
        } catch {
            status.stringValue = "저장하지 못했습니다. 다시 시도해 주세요."
            status.textColor = .systemRed
        }
    }

    @objc private func resetValues(_ sender: Any?) {
        for index in roles.indices {
            colors[index].stringValue = defaults[index]
            sliders[index].doubleValue = defaultOpacity[index]
            opacityChanged(sliders[index])
        }
        do {
            if FileManager.default.fileExists(atPath: path) { try FileManager.default.removeItem(atPath: path) }
            status.stringValue = "기본값으로 초기화했습니다. 새 알림부터 적용됩니다."
            status.textColor = .secondaryLabelColor
        } catch {
            status.stringValue = "초기화하지 못했습니다. 다시 시도해 주세요."
            status.textColor = .systemRed
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    private func readSettings() -> (colors: [String: String], opacity: [String: Double]) {
        var colors: [String: String] = [:]
        var opacity: [String: Double] = [:]
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return (colors, opacity) }
        for line in contents.split(whereSeparator: \.isNewline) {
            let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            if pair[0].hasPrefix("opacity."), let value = Double(pair[1]), (0...100).contains(value) {
                opacity[String(pair[0].dropFirst("opacity.".count))] = value
            } else if roles.contains(pair[0]), pair[1].range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil {
                colors[pair[0]] = pair[1].uppercased()
            }
        }
        return (colors, opacity)
    }
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
let settings = AppearanceSettings(path: path)
settings.show()
