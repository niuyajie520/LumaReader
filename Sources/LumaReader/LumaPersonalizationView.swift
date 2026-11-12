import SwiftUI
import AppKit
import LumaReaderStudyKit

/// 1.9.0：个性化 —— 导入主题主视觉并调节，以及界面按钮 / 输入框透明度。
/// 默认值全部等同于旧版：不导入图片、不改透明度、听写输入框尺寸与位置不变。
enum LumaUIPrefs {
    static let headerOpacity = "luma.ui.headerOpacity"      // 0.3 ... 1
    static let headerScale = "luma.ui.headerButtonScale"    // 0.8 ... 1.25
    static let inputOpacity = "luma.ui.inputOpacity"        // 0.3 ... 1
}

struct LumaHeroImageControls: View {
    let systemKey: String
    @State private var s = HeroImageSettings()
    @State private var status = ""
    @State private var preview: NSImage?
    @State private var dropTargeted = false
    @State private var commitTask: Task<Void, Never>?
    @State private var didLoad = false
    @State private var lastSaved = HeroImageSettings()

    private func scheduleCommit() {
        let snapshot = s
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            lastSaved = snapshot
            HeroImageStore.save(snapshot, system: systemKey)
        }
    }
    private func reloadPreview() {
        preview = s.file.flatMap { HeroImageStore.image(named: $0) }
    }
    @discardableResult
    private func importHero(_ url: URL) -> Bool {
        if let imported = HeroImageStore.importImage(from: url, system: systemKey) {
            lastSaved = imported
            s = imported
            preview = HeroImageStore.image(named: imported.file ?? "")
            status = ""
            return true
        }
        status = L10n.text("无法读取这张图片")
        return false
    }
    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ fmt: String = "%.0f%%", mult: Double = 100) -> some View {
        HStack(spacing: 8) {
            Text(L10n.text(title))
                .font(.caption)
                .lineLimit(2)
                .frame(width: 118, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: fmt, value.wrappedValue * mult))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(L10n.text("自定义主视觉")).font(.headline)
                Text(systemTitle).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Text(L10n.text("导入你自己的漫画 / 插画作为当前主题的主视觉；图片只保存在本机。图片过深或过亮时，用「遮罩」和「不透明度」压低，避免遮住按钮与文字。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                    if let preview {
                        Image(nsImage: preview)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        VStack(spacing: 3) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 18, weight: .light))
                            Text(L10n.text("拖入图片")).font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 116, height: 74)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(dropTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                                      style: StrokeStyle(lineWidth: dropTargeted ? 2 : 1, dash: preview == nil ? [4, 3] : []))
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Button(L10n.text("导入图片…")) {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.image]
                            panel.allowsMultipleSelection = false
                            panel.prompt = L10n.text("导入")
                            guard panel.runModal() == .OK, let url = panel.url else { return }
                            importHero(url)
                        }
                        if s.file != nil {
                            Button(L10n.text("移除"), role: .destructive) {
                                commitTask?.cancel()
                                HeroImageStore.remove(system: systemKey)
                                s = HeroImageSettings(); preview = nil; status = ""
                            }
                            Button(L10n.text("重置调节")) {
                                var d = HeroImageSettings(); d.file = s.file
                                s = d; scheduleCommit()
                            }
                        }
                    }
                    Text(s.file == nil
                         ? L10n.text("支持 PNG / JPEG / HEIC / WebP；导入后会缩放到最长边 2000px。")
                         : L10n.text("已保存到本机 Application Support，不会随云盘同步。"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.red) }
                }
                Spacer(minLength: 0)
            }

            if s.file != nil {
                slider("不透明度", $s.opacity, 0.05...1)
                slider("遮罩", $s.veil, 0...0.8)
                slider("模糊", $s.blur, 0...24, "%.0f", mult: 1)
                Picker(L10n.text("铺放方式"), selection: Binding(get: { s.fill }, set: { s.fill = $0 })) {
                    Text(L10n.text("右下角")).tag(false)
                    Text(L10n.text("铺满背景")).tag(true)
                }.pickerStyle(.segmented)
                if !s.fill {
                    slider("大小", $s.scale, 0.3...1.6)
                    slider("水平位置", $s.offsetX, -0.5...0.5, "%+.0f%%")
                    slider("垂直位置", $s.offsetY, -0.5...0.5, "%+.0f%%")
                }
                Toggle(L10n.text("边缘渐隐（左、上）"), isOn: Binding(get: { s.feather }, set: { s.feather = $0 }))
                Toggle(L10n.text("替换内置矢量图（关闭则叠在其上）"), isOn: Binding(get: { s.replaceBuiltIn }, set: { s.replaceBuiltIn = $0 }))
            }
        }
        .onAppear {
            let loaded = HeroImageStore.loadForEditing(system: systemKey).clamped()
            s = loaded; lastSaved = loaded
            reloadPreview()
            didLoad = true
        }
        .onChange(of: systemKey) { _, new in
            let loaded = HeroImageStore.loadForEditing(system: new).clamped()
            s = loaded; lastSaved = loaded
            reloadPreview()
        }
        .onChange(of: s) { _, new in
            guard didLoad, new != lastSaved else { return }
            scheduleCommit()
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            return importHero(url)
        } isTargeted: { dropTargeted = $0 }
        .onDisappear { commitTask?.cancel() }
    }

    private var systemTitle: String {
        LumaVisualThemeSystem(rawValue: systemKey)?.title
            ?? (systemKey.hasPrefix("manga") ? LumaVisualThemeSystem.manga.title : systemKey)
    }
}

struct LumaUIPersonalizationControls: View {
    @AppStorage(LumaUIPrefs.headerOpacity) private var headerOpacity = 1.0
    @AppStorage(LumaUIPrefs.headerScale) private var headerScale = 1.0
    @AppStorage(LumaUIPrefs.inputOpacity) private var inputOpacity = 1.0

    private func row(_ title: String, _ hint: String? = nil, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(L10n.text(title)).font(.caption).frame(width: 118, alignment: .leading)
                Slider(value: value, in: range)
                Text(String(format: "%.0f%%", value.wrappedValue * 100))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            if let hint {
                Text(L10n.text(hint)).font(.caption2).foregroundStyle(.secondary).padding(.leading, 126)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.text("界面透明度与大小")).font(.headline)
            Text(L10n.text("按钮栏与输入框被背景图抢眼时可以调淡 / 调小。默认 100%，与之前完全一致；听写输入框的尺寸与位置不受影响。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            row("顶栏底色不透明度", "只改变顶栏底色，按钮与红黄绿保持清晰", $headerOpacity, 0.3...1)
            row("按钮栏大小", "阅读顶栏七键等比缩放，窗口过窄时自动限制", $headerScale, 0.8...1.25)
            row("输入框底色不透明度", "只淡化输入框底色，文字保持可读", $inputOpacity, 0.3...1)
            Button(L10n.text("全部恢复默认")) {
                headerOpacity = 1; headerScale = 1; inputOpacity = 1
            }
        }
    }
}
