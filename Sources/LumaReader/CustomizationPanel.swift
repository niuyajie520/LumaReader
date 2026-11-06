import SwiftUI

struct CustomizationPanel: View {
    @Environment(\.lumaMuted) private var muted
    @Environment(\.lumaGlass) private var glass
    @Bindable var store: LibraryStore
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appIconStyle") private var appIconStyle = "glass"
    @Namespace private var sectionMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var section = "外观"
    @State private var hex = ""
    @State private var invalidHex = false
    @State private var previewDark = false
    private let sections = ["外观","排版","动画","专注"]
    private func close() { if let onClose { onClose() } else { dismiss() } }
    var body: some View {
        VStack(spacing:0) {
            HStack {
                Text(L10n.text("外观与阅读")).font(.headline)
                Spacer()
                Button(L10n.text("完成")) { close() }.buttonStyle(LumaTactileButtonStyle(prominent:true,accent:store.accent)).keyboardShortcut(.defaultAction)
            }.padding(20)
            Divider()
            HStack(spacing:0) {
                VStack(alignment:.leading,spacing:6) {
                    ForEach(sections,id:\.self) { title in
                        Button { withAnimation(LumaMotion.adjusted(SurfaceMotion.interactive,level:store.effectiveMotionLevel,reduceMotion:reduceMotion)) { section = title } } label: {
                            Text(L10n.text(title)).frame(maxWidth:.infinity,minHeight:24,alignment:.leading).padding(10).contentShape(Rectangle())
                                .background {
                                    if section == title {
                                        RoundedRectangle(cornerRadius:8).fill(store.accent.opacity(0.12))
                                            .matchedGeometryEffect(id:"settings-section",in:sectionMotion)
                                    }
                                }
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                }.padding(12).frame(width:100)
                Divider()
                Form {
                    readingScope
                    if section == "外观" { appearance }
                    if section == "排版" { typography }
                    if section == "动画" { motion }
                    if section == "专注" { focus }
                }
                    .transition(reduceMotion || store.effectiveMotionLevel == .off ? .opacity:.opacity.combined(with:.offset(y:6)))
                    .formStyle(.grouped).scrollContentBackground(.hidden).listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(glass ? 0.68:1)).frame(minWidth:250,maxWidth:.infinity)
                Divider()
                preview.frame(width:210).padding(14)
            }
        }
        .frame(minWidth:660,minHeight:480)
        .foregroundStyle(store.readingPalette(dark:colorScheme == .dark).ink)
        .background(Color.clear)
        .tint(store.accent).accentColor(store.accent).toggleStyle(LumaThemeSwitchStyle(accent:store.accent))
        .onAppear { hex = ReadingPalette.hex(store.monetSeed); previewDark = colorScheme == .dark }
        .onChange(of:store.monetSeed) { _,seed in hex = ReadingPalette.hex(seed) }
    }
    private var readingScope: some View {
        Section(L10n.text("保存范围")) {
            Toggle(L10n.text("每本书记住阅读设置"),isOn:$store.perBookReadingSettings)
            Text(L10n.text(store.selectedBook.map { store.perBookReadingSettings ? "当前修改仅用于《"+$0.title+"》":"当前修改作为所有书籍的默认设置" } ?? "未打开图书，当前修改作为默认设置"))
                .font(.caption).foregroundStyle(muted)
            if store.selectedBook != nil {
                Button(L10n.text("恢复本书的默认设置")) { store.resetCurrentBookReadingPreferences() }.disabled(!store.perBookReadingSettings)
                Button(L10n.text("将当前设置应用到所有书籍")) { store.applyReadingPreferencesToAllBooks() }
            }
        }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
    }
    private var appearance: some View {
        Group {
            Section(L10n.text("界面语言")) {
                Picker(L10n.text("界面语言"),selection:Binding(get:{ AppLanguage.shared.choice },set:{ AppLanguage.shared.choice = $0 })) {
                    Text(L10n.text("跟随系统")).tag("system")
                    Text(L10n.text("简体中文")).tag("zh-Hans")
                    Text("English").tag("en")
                }
            }
            Section(L10n.text("动态取色")) {
                Toggle(L10n.text("Monet 动态取色"),isOn:$store.monetEnabled)
                if store.monetEnabled {
                    Picker(L10n.text("取色来源"),selection:$store.monetSource) {
                        ForEach(MonetSource.allCases) { Text(L10n.text($0.title)).tag($0) }
                    }
                    Picker(L10n.text("配色风格"),selection:$store.monetStyle) {
                        ForEach(MonetStyle.allCases) { Text(L10n.text($0.title)).tag($0) }
                    }
                    if store.monetSource == .image { Button(L10n.text("选择取色图片…")) { store.chooseMonetImage() } }
                    if store.monetSource == .wallpaper { Button(L10n.text("重新读取壁纸")) { store.refreshMonet(force:true) } }
                    ColorPicker("主色",selection:Binding(get:{ Color(hex:ReadingPalette.hex(store.monetSeed)) },set:{ color in
                        _ = store.setMonetHex(ReadingPalette.hex(color))
                    }),supportsOpacity:false)
                    HStack {
                        TextField(L10n.text("HEX，例如 6E9277"),text:$hex).lumaInputSurface().onSubmit { applyHex() }
                        Button(L10n.text("应用")) { applyHex() }
                    }
                    if invalidHex { Text(L10n.text("请输入六位十六进制颜色。可带 #。 ")).font(.caption).foregroundStyle(.red) }
                    Toggle(L10n.text("锁定配色，换书时保持"),isOn:$store.monetLocked)
                    if !store.monetStatus.isEmpty { Text(L10n.text(store.monetStatus)).font(.caption).foregroundStyle(muted) }
                    Text(L10n.text("图片在本机取色。正文、AI 和操作控件共用一份配色。"))
                        .font(.caption).foregroundStyle(muted)
                } else {
                    Picker(L10n.text("经典主题"),selection:$store.theme) {
                        ForEach(ReaderTheme.allCases) { Text(L10n.text($0.title)).tag($0) }
                    }
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            Section(L10n.text("液态玻璃强度")) {
                Slider(value:Binding(get:{ (store.glassOpacity-0.05)/0.80 },set:{ store.glassOpacity = 0.05+$0*0.80 }),in:0...1)
                Text(L10n.text("玻璃强度 \(Int((store.glassOpacity-0.05)/0.80*100))% · 越低越通透")).font(.caption)
                HStack {
                    Button(L10n.text("清透 25%")) { store.glassOpacity = 0.25 }
                    Button(L10n.text("标准 50%")) { store.glassOpacity = 0.45 }
                    Button(L10n.text("磨砂 75%")) { store.glassOpacity = 0.65 }
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.4))
            Section(L10n.text("应用图标")) {
                Picker(L10n.text("图标风格"),selection:$appIconStyle) {
                    Text(L10n.text("玻璃")).tag("glass")
                    Text(L10n.text("黑白 · 浅色")).tag("light")
                    Text(L10n.text("黑白 · 深色")).tag("dark")
                    Text(L10n.text("跟随明暗")).tag("system")
                }
                Text(L10n.text("选择后更新 Dock 图标；Finder 使用安装包中的玻璃图标。玻璃版是静态质感图形。"))
                    .font(.caption).foregroundStyle(muted)
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            Section(L10n.text("明暗模式")) {
                Picker(L10n.text("外观"),selection:$store.appearance) {
                    ForEach(Appearance.allCases,id:\.self) { Text(L10n.text($0.rawValue)).tag($0) }
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            Section {
                Button(L10n.text("恢复默认配色")) {
                    store.monetLocked = false; store.monetStyle = .tonalSpot
                    store.monetSource = .cover; store.monetSeed = 0xFF8C7862
                    store.monetEnabled = true; store.appearance = .system; store.theme = .paper
                    store.refreshMonet(force:true)
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
        }
    }
    private func readingSliderChanged(_ editing: Bool) {
        if editing { store.reader?.beginViewportChange() } else { store.reader?.finishViewportChange() }
    }
    private func applyHex() { invalidHex = !store.setMonetHex(hex) }
    private var typography: some View {
        Group {
            Section(L10n.text("我的字体")) {
                Button { store.importFonts() } label: { Label(L10n.text(store.isImportingFonts ? "正在导入…":"导入字体…"),systemImage:"textformat") }.disabled(store.isImportingFonts)
                Picker(L10n.text("正文自定义字体"),selection:$store.readerCustomFont) {
                    Text(L10n.text("使用内置字体")).tag("")
                    if !store.readerCustomFont.isEmpty && store.selectedReaderFont == nil { Text(L10n.text("等待字体同步")).tag(store.readerCustomFont) }
                    ForEach(store.importedFonts) { font in Text(font.title).tag(font.id) }
                }
                Picker(L10n.text("书库自定义字体"),selection:$store.homeCustomFont) {
                    Text(L10n.text("使用内置字体")).tag("")
                    if !store.homeCustomFont.isEmpty && !store.importedFonts.contains(where:{ $0.id == store.homeCustomFont }) { Text(L10n.text("等待字体同步")).tag(store.homeCustomFont) }
                    ForEach(store.importedFonts) { font in Text(font.title).tag(font.id) }
                }
                Text(L10n.text("支持 TTF / OTF，单个文件不超过 32 MB。字体文件随已连接云盘双向同步，另一台 Mac 同步到本机后可在这里选择。字体选择保存在本机；正文支持每本书独立记忆。PDF 原文版式不替换。"))
                    .font(.caption).foregroundStyle(muted)
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            Section(L10n.text("EPUB 正文")) {
                Picker(L10n.text("字体"),selection:$store.readerFontFamily) {
                    ForEach(LumaFontFamily.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                LabeledContent(L10n.text("字号 \(Int(store.readerSize))")) { Slider(value:$store.readerSize,in:15...30,step:1,onEditingChanged:readingSliderChanged) }
                LabeledContent(L10n.text("版心 \(Int(store.readerWidth))")) { Slider(value:$store.readerWidth,in:480...900,step:20,onEditingChanged:readingSliderChanged) }
                LabeledContent(L10n.text("行距 \(String(format:"%.2f",store.readerLineHeight))")) { Slider(value:$store.readerLineHeight,in:1.2...2.6,step:0.05,onEditingChanged:readingSliderChanged) }
                LabeledContent(L10n.text("段距 \(String(format:"%.2f",store.readerParagraphSpacing))")) { Slider(value:$store.readerParagraphSpacing,in:0...2.5,step:0.05,onEditingChanged:readingSliderChanged) }
                Toggle(L10n.text("首行缩进两字"),isOn:$store.readerIndent)
                Text(L10n.text("宽窗口自动双页；正文保持居中。← / → 翻页，输入文字时移动光标。PDF 保留原始排版。"))
                    .font(.caption).foregroundStyle(muted)
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            Section {
                Button(L10n.text("恢复默认排版")) {
                    store.readerCustomFont = ""; store.readerFontFamily = .serif; store.readerSize = 19; store.readerWidth = 680
                    store.readerLineHeight = 1.75; store.readerParagraphSpacing = 1.35; store.readerIndent = false
                }
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
        }
    }
    private var motion: some View {
        Group {
            Section(L10n.text("视觉效果")) {
                Picker(L10n.text("动画强度"),selection:$store.visualMotionLevel) {
                    ForEach(VisualMotionLevel.allCases) { Text(L10n.text($0.title)).tag($0) }
                }
                Toggle(L10n.text("液态玻璃效果"),isOn:$store.glassEffectsEnabled)
                Toggle(L10n.text("书库与阅读轻柔过渡"),isOn:$store.coverTransitions)
                PageMotionPicker(store:store)
                Toggle(L10n.text("翻页动画"),isOn:$store.pageTurnAnimation)
                Picker(L10n.text("翻页方式"),selection:$store.pageTurnStyle) {
                    ForEach(PageTurnStyle.allCases) { Text(L10n.text($0.title)).tag($0) }
                }.disabled(!store.pageTurnAnimation)
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
            Section(L10n.text("性能")) {
                Toggle(L10n.text("省电模式"),isOn:$store.energySaving)
                Text(L10n.text(store.effectiveEnergySaving ? "当前省电中":"当前使用所选画质"))
                Text(L10n.text("自动遵循系统低电量、减少动态效果和减少透明度设置。"))
                    .font(.caption).foregroundStyle(muted)
            }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
        }
    }
    private var focus: some View {
        Section(L10n.text("专注阅读")) {
            Toggle(L10n.text("专注时自动收起 AI"),isOn:$store.autoHideAIInFocus)
            Button(L10n.text(store.immersive ? "退出专注阅读":"进入专注阅读")) { store.toggleImmersive(); close() }
                .disabled(store.selectedBook == nil)
            Text(L10n.text("顶部“更多”或 ⌥⌘I 进入。工具栏自动隐藏，鼠标移到窗口顶部即可显示；Esc 退出并恢复布局。选中文字时才显示标注工具。"))
                .font(.caption).foregroundStyle(muted)
        }.listRowBackground(store.chrome(dark:colorScheme == .dark).opacity(0.72))
    }
    private var preview: some View {
        let p = store.readingPalette(dark:previewDark)
        return VStack(alignment:.leading,spacing:14) {
            HStack {
                Text(L10n.text("实时预览")).font(.subheadline)
                Spacer()
                Toggle(L10n.text("深色"),isOn:$previewDark).toggleStyle(LumaThemeSwitchStyle(accent:store.accent)).controlSize(.mini)
            }
            VStack(spacing:0) {
                HStack {
                    ForEach(["chevron.left","list.bullet","magnifyingglass","sparkles","bookmark","ellipsis"],id:\.self) { symbol in
                        Image(systemName:symbol).font(.system(size:11)).frame(maxWidth:.infinity)
                    }
                }.foregroundStyle(p.accent).padding(10).background(p.chrome)
                HStack(alignment:.top,spacing:10) {
                    VStack(alignment:.leading,spacing:12) {
                        Text(L10n.text("静下来，读一页")).font(store.readingFont(15,weight:.medium))
                        Text(L10n.text("阅读的意义，有时并不是记住多少内容，而是在别人的句子里，慢慢认出自己的想法。"))
                            .font(store.readingFont(CGFloat(store.readerSize)*0.62))
                            .lineSpacing(CGFloat(max(0,store.readerLineHeight-1))*7)
                        Text(L10n.text("每一种颜色，都是此刻的自己与这本书的一次交谈。"))
                            .font(.system(size:11)).padding(.top,CGFloat(store.readerParagraphSpacing)*3)
                    }.frame(maxWidth:.infinity)
                    VStack(alignment:.leading,spacing:10) {
                        Image(systemName:"chevron.left").foregroundStyle(p.accent)
                        Text("AI").font(.caption)
                        Text(L10n.text("在这里，想法可以继续。 ")).font(.system(size:10)).foregroundStyle(p.muted)
                        RoundedRectangle(cornerRadius:7).fill(p.chrome).frame(height:40)
                    }.frame(width:56).padding(.leading,6)
                }.padding(12).frame(minHeight:280,alignment:.top)
                    .foregroundStyle(p.ink).background(p.paper)
            }.clipShape(RoundedRectangle(cornerRadius:12))
                .overlay(RoundedRectangle(cornerRadius:12).stroke(p.accent.opacity(0.2)))
            HStack(spacing:6) {
                ForEach(Array([p.paperHex,p.chromeHex,p.accentHex,p.inkHex].enumerated()),id:\.offset) { _,value in Circle().fill(Color(hex:value)).frame(width:22,height:22).overlay(Circle().stroke(.gray.opacity(0.3))) }
            }
            Text(L10n.text("正文与 AI 同步；右侧为缩略预览。"))
                .font(.caption).foregroundStyle(muted)
            Spacer()
        }
    }
}
