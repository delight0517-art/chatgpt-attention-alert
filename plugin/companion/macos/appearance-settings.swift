import AppKit

final class AppearanceSettings: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private let path: String
    private let roles = ["background", "accent", "text", "button", "button-text"]
    private let defaults = ["#0E1724", "#61EBFF", "#FFFFFF", "#24405A", "#FFFFFF"]
    private let defaultOpacity = [82.0, 100, 100, 100, 100]
    private var names: [String] {
        switch language {
        case "ko": return ["카드 배경", "강조색", "카드 글자", "버튼 배경", "버튼 글자"]
        case "ja": return ["カードの背景", "アクセント", "カードの文字", "ボタンの背景", "ボタンの文字"]
        case "zh": return ["卡片背景", "强调色", "卡片文字", "按钮背景", "按钮文字"]
        default: return ["Card background", "Accent", "Card text", "Button background", "Button text"]
        }
    }
    private let language = Locale.preferredLanguages.first?.split(separator: "-").first.map(String.init) ?? "en"
    private func tr(_ ko: String, _ en: String, _ ja: String, _ zh: String) -> String {
        switch language { case "ko": return ko; case "ja": return ja; case "zh": return zh; default: return en }
    }

    private var colors: [NSTextField] = []
    private var colorWells: [NSColorWell] = []
    private var sliders: [NSSlider] = []
    private var percentages: [NSTextField] = []
    private let status = NSTextField(labelWithString: "")
    private var window: NSWindow!
    private var previewCard: NSView!
    private var previewKicker: NSTextField!
    private var previewTitle: NSTextField!
    private var previewBody: NSTextField!
    private var primaryButton: NSView!
    private var primaryButtonLabel: NSTextField!
    private var secondaryButton: NSView!
    private var secondaryButtonLabel: NSTextField!

    init(path: String) {
        self.path = path
        super.init()
    }

    func show() {
        NSApplication.shared.setActivationPolicy(.accessory)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 910, height: 520), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = tr("GPT 알리미 색상 설정", "GPT Alert Colors", "GPTアラートの色設定", "GPT提醒颜色设置")
        window.center()
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 910, height: 520)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 910, height: 520))
        window.contentView = content

        let heading = NSTextField(labelWithString: tr("알림 색상과 투명도를 설정하세요", "Customize alert colors and opacity", "アラートの色と不透明度を設定", "自定义提醒颜色和不透明度"))
        heading.frame = NSRect(x: 26, y: 476, width: 540, height: 24)
        heading.font = .systemFont(ofSize: 18, weight: .semibold)
        content.addSubview(heading)

        let help = NSTextField(labelWithString: tr("색상 버튼을 눌러 고르고, 옆의 HEX 값으로 세밀하게 조정하세요. 오른쪽 미리보기는 바로 바뀝니다.", "Choose a color with the swatch or fine-tune its HEX value. The preview updates as you edit.", "色見本から選ぶか、HEX値で細かく調整できます。右側のプレビューはすぐに更新されます。", "点击色块选择颜色，或用 HEX 值微调；右侧预览会即时更新。"))
        help.frame = NSRect(x: 26, y: 451, width: 850, height: 18)
        help.font = .systemFont(ofSize: 11)
        help.textColor = .secondaryLabelColor
        content.addSubview(help)

        let colorLabel = NSTextField(labelWithString: tr("색상", "Color", "色", "颜色"))
        colorLabel.frame = NSRect(x: 134, y: 420, width: 100, height: 18)
        colorLabel.font = .systemFont(ofSize: 11, weight: .medium)
        colorLabel.textColor = .secondaryLabelColor
        content.addSubview(colorLabel)
        let opacityLabel = NSTextField(labelWithString: tr("불투명도", "Opacity", "不透明度", "不透明度"))
        opacityLabel.frame = NSRect(x: 310, y: 420, width: 170, height: 18)
        opacityLabel.font = .systemFont(ofSize: 11, weight: .medium)
        opacityLabel.textColor = .secondaryLabelColor
        content.addSubview(opacityLabel)

        let saved = readSettings()
        for index in roles.indices {
            let y = CGFloat(380 - index * 52)
            let name = NSTextField(labelWithString: names[index])
            name.frame = NSRect(x: 26, y: y + 4, width: 100, height: 20)
            content.addSubview(name)

            let field = NSTextField(string: saved.colors[roles[index]] ?? defaults[index])
            field.frame = NSRect(x: 178, y: y, width: 98, height: 28)
            field.tag = index
            field.delegate = self
            colors.append(field)
            content.addSubview(field)

            let well = NSColorWell(frame: NSRect(x: 133, y: y - 1, width: 36, height: 30))
            well.color = nsColor(saved.colors[roles[index]] ?? defaults[index])
            well.tag = index
            well.target = self
            well.action = #selector(colorWellChanged(_:))
            colorWells.append(well)
            content.addSubview(well)

            let slider = NSSlider(value: saved.opacity[roles[index]] ?? defaultOpacity[index], minValue: 0, maxValue: 100, target: self, action: #selector(opacityChanged(_:)))
            slider.frame = NSRect(x: 307, y: y + 2, width: 170, height: 24)
            slider.tag = index
            sliders.append(slider)
            content.addSubview(slider)

            let percent = NSTextField(labelWithString: "\(Int(slider.doubleValue.rounded()))%")
            percent.frame = NSRect(x: 484, y: y + 4, width: 45, height: 20)
            percent.alignment = .right
            percentages.append(percent)
            content.addSubview(percent)
        }

        let previewHeading = NSTextField(labelWithString: tr("실시간 미리보기", "Live preview", "リアルタイムプレビュー", "实时预览"))
        previewHeading.frame = NSRect(x: 564, y: 420, width: 280, height: 20)
        previewHeading.font = .systemFont(ofSize: 13, weight: .semibold)
        content.addSubview(previewHeading)
        let previewHint = NSTextField(labelWithString: tr("주요 확인 버튼은 읽기 쉬운 대비를 자동으로 선택합니다.", "Primary action text keeps readable contrast automatically.", "主要ボタンの文字は読みやすいコントラストを自動選択します。", "主要操作按钮会自动选择易读的文字对比色。"))
        previewHint.frame = NSRect(x: 564, y: 400, width: 320, height: 16)
        previewHint.font = .systemFont(ofSize: 10)
        previewHint.textColor = .secondaryLabelColor
        content.addSubview(previewHint)

        buildPreview(in: content)
        buildPresets(in: content)

        status.frame = NSRect(x: 26, y: 32, width: 510, height: 20)
        status.stringValue = tr("변경 사항은 저장 후 새 알림부터 적용됩니다.", "Changes apply to new alerts after saving.", "保存後、新しいアラートから適用されます。", "保存后将应用于新提醒。")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        content.addSubview(status)

        let reset = NSButton(title: tr("기본 팔레트", "Default palette", "既定の配色", "默认配色"), target: self, action: #selector(resetValues(_:)))
        reset.frame = NSRect(x: 650, y: 25, width: 108, height: 32)
        content.addSubview(reset)
        let save = NSButton(title: tr("저장", "Save", "保存", "保存"), target: self, action: #selector(saveValues(_:)))
        save.frame = NSRect(x: 770, y: 25, width: 110, height: 32)
        save.keyEquivalent = "\r"
        content.addSubview(save)

        updatePreview()
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.run()
    }

    private func buildPreview(in content: NSView) {
        let shell = NSView(frame: NSRect(x: 554, y: 105, width: 330, height: 280))
        shell.wantsLayer = true
        shell.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
        shell.layer?.cornerRadius = 16
        content.addSubview(shell)

        previewCard = NSView(frame: NSRect(x: 14, y: 14, width: 302, height: 252))
        previewCard.wantsLayer = true
        previewCard.layer?.cornerRadius = 15
        shell.addSubview(previewCard)

        previewKicker = NSTextField(labelWithString: tr("GPT NEEDS YOU · 확인이 필요해요", "GPT NEEDS YOU · Needs your attention", "GPT NEEDS YOU · 確認が必要です", "GPT NEEDS YOU · 需要您处理"))
        previewKicker.frame = NSRect(x: 18, y: 211, width: 266, height: 20)
        previewKicker.font = .systemFont(ofSize: 12, weight: .bold)
        previewCard.addSubview(previewKicker)

        previewTitle = NSTextField(labelWithString: tr("계정 연결을 완료해 주세요", "Finish connecting your account", "アカウント連携を完了してください", "请完成账号连接"))
        previewTitle.frame = NSRect(x: 18, y: 157, width: 266, height: 42)
        previewTitle.font = .systemFont(ofSize: 17, weight: .bold)
        previewTitle.maximumNumberOfLines = 2
        previewCard.addSubview(previewTitle)

        previewBody = NSTextField(labelWithString: tr("대상 · GitHub · @example\n새 기기 코드를 입력하세요", "For · GitHub · @example\nEnter the new device code", "対象 · GitHub · @example\n新しいデバイスコードを入力してください", "目标 · GitHub · @example\n请输入新的设备代码"))
        previewBody.frame = NSRect(x: 18, y: 104, width: 266, height: 42)
        previewBody.font = .systemFont(ofSize: 11)
        previewBody.maximumNumberOfLines = 2
        previewCard.addSubview(previewBody)

        primaryButton = NSView(frame: NSRect(x: 18, y: 55, width: 266, height: 36))
        primaryButton.wantsLayer = true
        primaryButton.layer?.cornerRadius = 8
        previewCard.addSubview(primaryButton)
        primaryButtonLabel = NSTextField(labelWithString: tr("인증 페이지 열기", "Open verification page", "認証ページを開く", "打开验证页面"))
        primaryButtonLabel.frame = NSRect(x: 8, y: 8, width: 250, height: 20)
        primaryButtonLabel.alignment = .center
        primaryButtonLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        primaryButton.addSubview(primaryButtonLabel)

        secondaryButton = NSView(frame: NSRect(x: 18, y: 12, width: 266, height: 32))
        secondaryButton.wantsLayer = true
        secondaryButton.layer?.cornerRadius = 8
        previewCard.addSubview(secondaryButton)
        secondaryButtonLabel = NSTextField(labelWithString: tr("소리 끄기     확인", "Mute sound     Done", "音を消す     完了", "关闭声音     完成"))
        secondaryButtonLabel.frame = NSRect(x: 8, y: 6, width: 250, height: 20)
        secondaryButtonLabel.alignment = .center
        secondaryButtonLabel.font = .systemFont(ofSize: 11, weight: .medium)
        secondaryButton.addSubview(secondaryButtonLabel)
    }

    private func buildPresets(in content: NSView) {
        let label = NSTextField(labelWithString: tr("빠른 팔레트", "Quick palettes", "クイック配色", "快速配色"))
        label.frame = NSRect(x: 26, y: 111, width: 100, height: 20)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        content.addSubview(label)

        let titles = [
            tr("기본 다크", "Midnight", "ミッドナイト", "午夜"),
            tr("밝은 대비", "Bright", "ブライト", "明亮"),
            tr("보라", "Violet", "バイオレット", "紫色"),
            tr("바다", "Ocean", "オーシャン", "海洋")
        ]
        for (index, title) in titles.enumerated() {
            let button = NSButton(title: title, target: self, action: #selector(selectPreset(_:)))
            button.frame = NSRect(x: 26 + index * 126, y: 76, width: 116, height: 30)
            button.tag = index
            button.bezelStyle = .rounded
            content.addSubview(button)
        }
    }

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        colors[sender.tag].stringValue = hexValue(sender.color)
        updatePreview()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, colors.indices.contains(field.tag) else { return }
        if isValidHex(field.stringValue) { colorWells[field.tag].color = nsColor(field.stringValue) }
        updatePreview()
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        percentages[sender.tag].stringValue = "\(Int(sender.doubleValue.rounded()))%"
        updatePreview()
    }

    @objc private func selectPreset(_ sender: NSButton) {
        let palettes: [[String]] = [
            defaults,
            ["#F3F6FB", "#0057B8", "#152033", "#DFE7F2", "#162238"],
            ["#161326", "#B89CFF", "#FFFFFF", "#33284E", "#FFFFFF"],
            ["#071D2A", "#42D6C5", "#F0FBFF", "#1B3B4A", "#FFFFFF"]
        ]
        guard palettes.indices.contains(sender.tag) else { return }
        for index in roles.indices {
            colors[index].stringValue = palettes[sender.tag][index]
            colorWells[index].color = nsColor(palettes[sender.tag][index])
            sliders[index].doubleValue = defaultOpacity[index]
            percentages[index].stringValue = "\(Int(defaultOpacity[index]))%"
        }
        status.stringValue = tr("미리보기 팔레트를 골랐습니다. 적용하려면 저장을 누르세요.", "Palette preview selected. Save to apply it.", "プレビュー配色を選択しました。適用するには保存してください。", "已选择预览配色。保存后应用。")
        updatePreview()
    }

    @objc private func saveValues(_ sender: Any?) {
        let values = colors.map { $0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        guard values.allSatisfy(isValidHex) else {
            status.stringValue = tr("색상 버튼으로 고르거나 #RRGGBB 형식으로 입력해 주세요.", "Choose a swatch or enter a color as #RRGGBB.", "色見本を選ぶか、#RRGGBB形式で入力してください。", "请选择色块或输入 #RRGGBB 格式。")
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
            status.stringValue = tr("저장했습니다. 다음 알림부터 적용됩니다.", "Saved. The next alert will use this palette.", "保存しました。次のアラートから適用されます。", "已保存。下次提醒将使用此配色。")
            status.textColor = .secondaryLabelColor
        } catch {
            status.stringValue = tr("저장하지 못했습니다. 다시 시도해 주세요.", "Could not save. Please try again.", "保存できませんでした。もう一度お試しください。", "保存失败，请重试。")
            status.textColor = .systemRed
        }
    }

    @objc private func resetValues(_ sender: Any?) {
        for index in roles.indices {
            colors[index].stringValue = defaults[index]
            colorWells[index].color = nsColor(defaults[index])
            sliders[index].doubleValue = defaultOpacity[index]
            percentages[index].stringValue = "\(Int(defaultOpacity[index]))%"
        }
        status.stringValue = tr("기본 팔레트를 미리 보고 있습니다. 적용하려면 저장을 누르세요.", "Previewing the default palette. Save to apply it.", "既定の配色をプレビュー中です。適用するには保存してください。", "正在预览默认配色。保存后应用。")
        status.textColor = .secondaryLabelColor
        updatePreview()
    }

    private func updatePreview() {
        guard previewCard != nil else { return }
        let palette = Dictionary(uniqueKeysWithValues: roles.enumerated().map { ($0.element, isValidHex(colors[$0.offset].stringValue) ? nsColor(colors[$0.offset].stringValue) : nsColor(defaults[$0.offset])) })
        let opacity = Dictionary(uniqueKeysWithValues: roles.enumerated().map { ($0.element, CGFloat(sliders[$0.offset].doubleValue / 100)) })
        previewCard.layer?.backgroundColor = (palette["background"] ?? .black).withAlphaComponent(opacity["background"] ?? 1).cgColor
        previewKicker.textColor = palette["accent"]?.withAlphaComponent(opacity["accent"] ?? 1)
        previewTitle.textColor = palette["text"]?.withAlphaComponent(opacity["text"] ?? 1)
        previewBody.textColor = palette["text"]?.withAlphaComponent(opacity["text"] ?? 1)
        primaryButton.layer?.backgroundColor = (palette["accent"] ?? .systemBlue).withAlphaComponent(opacity["accent"] ?? 1).cgColor
        primaryButtonLabel.textColor = readableText(preferred: palette["button-text"] ?? .white, fill: palette["accent"] ?? .systemBlue, fillOpacity: opacity["accent"] ?? 1, textOpacity: opacity["button-text"] ?? 1)
        secondaryButton.layer?.backgroundColor = (palette["button"] ?? .darkGray).withAlphaComponent(opacity["button"] ?? 1).cgColor
        secondaryButtonLabel.textColor = readableText(preferred: palette["button-text"] ?? .white, fill: palette["button"] ?? .darkGray, fillOpacity: opacity["button"] ?? 1, textOpacity: opacity["button-text"] ?? 1)
    }

    private func readableText(preferred: NSColor, fill: NSColor, fillOpacity: CGFloat, textOpacity: CGFloat) -> NSColor {
        let base = nsColor(colors.first?.stringValue ?? defaults[0])
        let visibleFill = composite(fill, over: base, opacity: fillOpacity)
        let visiblePreferred = composite(preferred, over: visibleFill, opacity: textOpacity)
        if contrast(visiblePreferred, visibleFill) >= 4.5 { return preferred.withAlphaComponent(textOpacity) }
        let dark = nsColor("#102033")
        let light = NSColor.white
        return contrast(dark, visibleFill) >= contrast(light, visibleFill) ? dark : light
    }

    private func composite(_ foreground: NSColor, over background: NSColor, opacity: CGFloat) -> NSColor {
        let fg = (foreground.usingColorSpace(.deviceRGB) ?? .white)
        let bg = (background.usingColorSpace(.deviceRGB) ?? .black)
        let amount = max(0, min(1, opacity))
        return NSColor(calibratedRed: fg.redComponent * amount + bg.redComponent * (1 - amount), green: fg.greenComponent * amount + bg.greenComponent * (1 - amount), blue: fg.blueComponent * amount + bg.blueComponent * (1 - amount), alpha: 1)
    }

    private func contrast(_ first: NSColor, _ second: NSColor) -> CGFloat {
        let values = [luminance(first), luminance(second)].sorted(by: >)
        return (values[0] + 0.05) / (values[1] + 0.05)
    }

    private func luminance(_ color: NSColor) -> CGFloat {
        let rgb = color.usingColorSpace(.deviceRGB) ?? .white
        func linear(_ value: CGFloat) -> CGFloat { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
    }

    private func isValidHex(_ value: String) -> Bool {
        value.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil
    }

    private func nsColor(_ value: String) -> NSColor {
        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else { return .white }
        return NSColor(calibratedRed: CGFloat((rgb >> 16) & 0xff) / 255, green: CGFloat((rgb >> 8) & 0xff) / 255, blue: CGFloat(rgb & 0xff) / 255, alpha: 1)
    }

    private func hexValue(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.deviceRGB) ?? .white
        return String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
    }

    private func readSettings() -> (colors: [String: String], opacity: [String: Double]) {
        var savedColors: [String: String] = [:]
        var savedOpacity: [String: Double] = [:]
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { return (savedColors, savedOpacity) }
        for line in contents.split(whereSeparator: \.isNewline) {
            let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            if pair[0].hasPrefix("opacity."), let value = Double(pair[1]), (0...100).contains(value) {
                savedOpacity[String(pair[0].dropFirst("opacity.".count))] = value
            } else if roles.contains(pair[0]), isValidHex(pair[1]) {
                savedColors[pair[0]] = pair[1].uppercased()
            }
        }
        return (savedColors, savedOpacity)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
let settings = AppearanceSettings(path: path)
settings.show()
