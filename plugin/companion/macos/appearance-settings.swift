import AppKit

final class AppearanceSettings: NSObject, NSWindowDelegate {
    private let path: String
    private let roles = ["background", "accent", "text", "button", "button-text"]
    private var names: [String] {
        switch language {
        case "ko": return ["카드 배경", "강조색", "글자", "버튼 배경", "버튼 글자"]
        case "ja": return ["カードの背景", "アクセント", "文字", "ボタンの背景", "ボタンの文字"]
        case "zh": return ["卡片背景", "强调色", "文字", "按钮背景", "按钮文字"]
        default: return ["Card background", "Accent", "Text", "Button background", "Button text"]
        }
    }
    private let language = Locale.preferredLanguages.first?.split(separator: "-").first.map(String.init) ?? "en"
    private func tr(_ ko: String, _ en: String, _ ja: String, _ zh: String) -> String {
        switch language { case "ko": return ko; case "ja": return ja; case "zh": return zh; default: return en }
    }
    private let defaults = ["#0E1724", "#61EBFF", "#FFFFFF", "#24405A", "#FFFFFF"]
    private let defaultOpacity = [82.0, 100, 100, 100, 100]
    private var colors: [NSTextField] = []
    private var sliders: [NSSlider] = []
    private var percentages: [NSTextField] = []
    private let status = NSTextField(labelWithString: "")
    private var window: NSWindow!

    init(path: String) {
        self.path = path
        super.init()
    }

    func show() {
        NSApplication.shared.setActivationPolicy(.accessory)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 405), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = tr("GPT 알리미 모양 설정", "GPT Alert Appearance", "GPTアラートの外観", "GPT提醒外观")
        window.center()
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 405))
        window.contentView = content

        let heading = NSTextField(labelWithString: tr("알림 색상과 투명도를 설정하세요", "Customize alert colors and opacity", "アラートの色と不透明度を設定", "自定义提醒颜色和不透明度"))
        heading.frame = NSRect(x: 24, y: 360, width: 570, height: 24)
        heading.font = .systemFont(ofSize: 17, weight: .semibold)
        content.addSubview(heading)

        let help = NSTextField(labelWithString: tr("색상은 #RRGGBB · 불투명도 0%는 투명, 100%는 불투명", "Colors use #RRGGBB · 0% opacity is transparent; 100% is opaque", "色は #RRGGBB · 不透明度 0% は透明、100% は不透明", "颜色使用 #RRGGBB · 不透明度 0% 为透明，100% 为不透明"))
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
        status.stringValue = tr("새 알림부터 적용됩니다.", "Changes apply to new alerts.", "変更は新しいアラートから適用されます。", "更改将应用于新提醒。")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        content.addSubview(status)

        let reset = NSButton(title: tr("기본값", "Reset", "リセット", "重置"), target: self, action: #selector(resetValues(_:)))
        reset.frame = NSRect(x: 395, y: 22, width: 88, height: 32)
        content.addSubview(reset)
        let save = NSButton(title: tr("저장", "Save", "保存", "保存"), target: self, action: #selector(saveValues(_:)))
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
            status.stringValue = tr("색상은 #RRGGBB 형식으로 입력해 주세요.", "Enter colors in #RRGGBB format.", "色は #RRGGBB 形式で入力してください。", "请按 #RRGGBB 格式输入颜色。")
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
            status.stringValue = tr("저장했습니다. 새 알림부터 적용됩니다.", "Saved. Changes apply to new alerts.", "保存しました。変更は新しいアラートから適用されます。", "已保存。更改将应用于新提醒。")
            status.textColor = .secondaryLabelColor
        } catch {
            status.stringValue = tr("저장하지 못했습니다. 다시 시도해 주세요.", "Could not save. Please try again.", "保存できませんでした。もう一度お試しください。", "保存失败，请重试。")
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
            status.stringValue = tr("기본값으로 초기화했습니다. 새 알림부터 적용됩니다.", "Reset to defaults. Changes apply to new alerts.", "既定値に戻しました。変更は新しいアラートから適用されます。", "已恢复默认值。更改将应用于新提醒。")
            status.textColor = .secondaryLabelColor
        } catch {
            status.stringValue = tr("초기화하지 못했습니다. 다시 시도해 주세요.", "Could not reset. Please try again.", "リセットできませんでした。もう一度お試しください。", "重置失败，请重试。")
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
