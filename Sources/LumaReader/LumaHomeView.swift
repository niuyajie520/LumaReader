import SwiftUI
import LumaReaderStudyKit

/// 主页：打开应用先到这里。一屏一个主操作（「继续上次」），其余是今日数字与功能入口。
/// 同一份数据，按视觉主题换三种外观：卡片（默认）、星轨（深空）、分镜（漫画 / 机械风）。
struct LumaHomeView: View {
    @Bindable var store: LibraryStore
    let summary: LumaStudySession.HomeSummary?
    let onContinueDictation: () -> Void
    let onOpenStudy: (String) -> Void
    let onOpenLibrary: () -> Void
    let onOpenBook: (Book) -> Void
    let onOpenStatistics: () -> Void
    let onOpenPalette: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredPlanet: String?
    /// 星轨暂停时的角度；nil 表示正在转。
    @State private var orbitHoldAngle: Double?
    @State private var orbitPhaseShift: Double = 0

    enum Skin { case cards, orbit, panels }

    private var skin: Skin {
        switch store.visualThemeSystem {
        case .space: return .orbit
        case .manga, .mangaOcean, .mangaCity, .mangaForest: return .panels
        default: return .cards
        }
    }

    private var dark: Bool { store.isDarkAppearance || colorScheme == .dark }
    private var palette: ReadingPalette { store.readingPalette(dark: dark) }

    // MARK: 数据

    private var lastBook: Book? {
        let reading = store.shelfBooks.filter { $0.progress > 0 && !$0.isFinished }
        return (reading.isEmpty ? store.shelfBooks : reading).max { $0.lastOpened < $1.lastOpened }
    }

    private var readingMinutesToday: Int {
        let calendar = Calendar.current
        guard let today = calendar.dateInterval(of: .day, for: Date()) else { return 0 }
        return Int(store.activity.ledger.seconds(in: today, calendar: calendar) / 60)
    }

    private var activeRound: LumaStudySession.HomeSummary? {
        guard let summary, summary.hasActiveRound else { return nil }
        return summary
    }

    /// 主卡片放最近做的那件事：听写本轮 或 正在读的书。
    private enum Hero { case dictation(LumaStudySession.HomeSummary), book(Book), start }

    private var hero: Hero {
        let book = lastBook.flatMap { $0.progress > 0 ? $0 : nil }
        switch (activeRound, book) {
        case let (round?, book?):
            return (round.lastDictationAt ?? .distantPast) >= book.lastOpened ? .dictation(round) : .book(book)
        case let (round?, nil): return .dictation(round)
        case let (nil, book?): return .book(book)
        default: return store.shelfBooks.isEmpty && (summary?.todayDictatedAllDecks ?? 0) == 0 ? .start : (lastBook.map { Hero.book($0) } ?? Hero.start)
        }
    }

    private var isFirstRun: Bool {
        if case .start = hero { return true }
        return false
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 · EEEE"
        return formatter.string(from: Date())
    }

    private struct Feature: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let status: String
        let action: () -> Void
    }

    private var features: [Feature] {
        let reading = store.shelfBooks.filter { $0.progress > 0 && !$0.isFinished }.count
        let units = summary?.unitsInProgress ?? 0
        return [
            Feature(id: "library", title: "书架", symbol: "books.vertical",
                    status: store.shelfBooks.isEmpty ? "还没有书" : (reading > 0 ? "在读 \(reading) 本" : "共 \(store.shelfBooks.count) 本"),
                    action: onOpenLibrary),
            Feature(id: "listening", title: "听力", symbol: "headphones",
                    status: units > 0 ? "\(units) 个单元进行中" : "选一个单元开始",
                    action: { onOpenStudy("学习_听力") }),
            Feature(id: "ielts", title: "雅思阅读", symbol: "doc.text.magnifyingglass",
                    status: "按题型练习", action: { onOpenStudy("学习_雅思阅读") }),
            Feature(id: "vocab", title: "阅读词汇", symbol: "text.book.closed",
                    status: "背词 · 易混词", action: { onOpenStudy("学习_阅读词汇") }),
            Feature(id: "writing", title: "写作", symbol: "pencil",
                    status: (summary?.hasWritingDraft ?? false) ? "有未完成的草稿" : "Task 1 · Task 2",
                    action: { onOpenStudy("学习_写作_Task1题库") }),
            Feature(id: "stats", title: "统计", symbol: "chart.bar",
                    status: "阅读与学习", action: onOpenStatistics),
        ]
    }

    // MARK: 视图

    var body: some View {
        Group {
            switch skin {
            case .orbit: orbitLayout
            case .cards, .panels: cardsLayout
            }
        }
        .foregroundStyle(palette.ink)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主页")
    }

    // MARK: 卡片 / 分镜布局

    private var cardsLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                header
                if isFirstRun {
                    startCard
                } else {
                    heroRow
                    todaySection
                }
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(.horizontal, 48)
            .padding(.top, 44)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateLine)
                    .font(store.homeFont(13))
                    .foregroundStyle(palette.muted)
                Text(isFirstRun ? "欢迎使用 Luma" : greeting)
                    .font(store.themeHeadingFont(28, layout: store.themeLayout))
            }
            Spacer(minLength: 12)
            Button(action: onOpenPalette) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("搜索书和功能")
                    Text("⌘K")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(palette.muted.opacity(0.4), lineWidth: 1))
                }
                .font(store.homeFont(13))
                .foregroundStyle(palette.muted)
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .modifier(HomeSurface(skin: skin, palette: palette, accent: store.accent, radius: 20, prominent: false))
            .accessibilityLabel("搜索书和功能，快捷键 Command K")
        }
    }

    private var heroRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                heroCard.frame(maxWidth: .infinity)
                secondaryCard.frame(width: 320)
            }
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                secondaryCard
            }
        }
    }

    @ViewBuilder private var heroCard: some View {
        switch hero {
        case .dictation(let round):
            heroBody(
                kicker: "听力 · 学新词",
                kickerSymbol: "headphones",
                title: "\(round.roundDeckTitle ?? "听写") · 本轮",
                ratio: Double(round.roundGraduated) / Double(max(1, round.roundTotal)),
                facts: ["已毕业 \(round.roundGraduated) / \(round.roundTotal)", "重现中 \(round.roundRetrying)", "本轮错题 \(round.roundWrong)"],
                buttonTitle: "继续听写",
                action: onContinueDictation
            )
        case .book(let book):
            heroBody(
                kicker: "阅读",
                kickerSymbol: "book",
                title: book.title,
                ratio: min(1, max(0, book.progress)),
                facts: ["读到 \(Int((min(1, max(0, book.progress)) * 100).rounded()))%"],
                buttonTitle: "继续阅读",
                action: { onOpenBook(book) }
            )
        case .start:
            EmptyView()
        }
    }

    private func heroBody(kicker: String, kickerSymbol: String, title: String, ratio: Double,
                          facts: [String], buttonTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(store.themeHeadingFont(26, layout: store.themeLayout))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: ratio)
                    .tint(store.accent)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: ratio)
                HStack(spacing: 16) {
                    Label(kicker, systemImage: kickerSymbol)
                        .foregroundStyle(store.accent)
                    ForEach(facts, id: \.self) { fact in
                        Text(fact).monospacedDigit()
                    }
                }
                .font(store.homeFont(13))
                .foregroundStyle(palette.muted)
            }
            HStack(spacing: 12) {
                Button(action: action) {
                    Label(buttonTitle, systemImage: "play.fill")
                        .font(store.homeFont(15, weight: .semibold))
                        .padding(.horizontal, 22)
                        .frame(minHeight: 44)
                }
                .buttonStyle(HomePrimaryButtonStyle(accent: store.accent, paper: store.paper(dark: dark), reduceMotion: reduceMotion))
                .keyboardShortcut(.defaultAction)
                Text("回车直接继续")
                    .font(store.homeFont(12))
                    .foregroundStyle(palette.muted)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(HomeSurface(skin: skin, palette: palette, accent: store.accent, radius: 18, prominent: true))
    }

    @ViewBuilder private var secondaryCard: some View {
        switch hero {
        case .dictation:
            if let book = lastBook, book.progress > 0 {
                secondaryButton(kicker: "继续阅读", title: book.title,
                                detail: "读到 \(Int((min(1, max(0, book.progress)) * 100).rounded()))%") { onOpenBook(book) }
            } else {
                secondaryButton(kicker: "阅读", title: "打开书架", detail: store.shelfBooks.isEmpty ? "导入一本书开始" : "共 \(store.shelfBooks.count) 本", action: onOpenLibrary)
            }
        case .book:
            if let round = activeRound {
                secondaryButton(kicker: "继续听写", title: "\(round.roundDeckTitle ?? "听写") · 本轮",
                                detail: "已毕业 \(round.roundGraduated) / \(round.roundTotal)", action: onContinueDictation)
            } else {
                secondaryButton(kicker: "听力", title: "选一个单元听写", detail: "学新词与错词复习分开进行") { onOpenStudy("学习_听力") }
            }
        case .start:
            EmptyView()
        }
    }

    private func secondaryButton(kicker: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(store.homeFont(17, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                Text("\(kicker) · \(detail)").font(store.homeFont(13)).foregroundStyle(palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(reduceMotion: reduceMotion))
        .modifier(HomeSurface(skin: skin, palette: palette, accent: store.accent, radius: 18, prominent: false))
    }

    /// 今日数字用一句话交代，不做「大数字 + 小标签」的统计卡片。错词待复习是唯一可点的部分。
    private var todaySection: some View {
        let due = summary?.wrongDueAllDecks ?? 0
        return HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("今日 · 全部词本与书")
                .font(store.homeFont(13, weight: .semibold))
            Text("听写 \(summary?.todayDictatedAllDecks ?? 0) 词 · 阅读 \(readingMinutesToday) 分钟")
                .font(store.homeFont(13))
                .foregroundStyle(palette.muted)
                .monospacedDigit()
            if due > 0 {
                Button { onOpenStudy("学习_听力_错词") } label: {
                    Text("复习 \(due) 个错词")
                        .font(store.homeFont(13, weight: .semibold))
                        .foregroundStyle(store.accent)
                        .underline()
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("打开错词复习")
            } else {
                Text("没有待复习的错词")
                    .font(store.homeFont(13))
                    .foregroundStyle(palette.muted)
            }
        }
        .padding(.horizontal, 4)
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("从这里开始")
                .font(store.themeHeadingFont(26, layout: store.themeLayout))
            Text("导入一本书开始阅读，或导入一份词表开始听写。之后打开应用，这里会显示你上次停在哪里。")
                .font(store.homeFont(15))
                .foregroundStyle(palette.muted)
                .frame(maxWidth: 520, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button { store.pickBooks() } label: {
                    Text("导入一本书")
                        .font(store.homeFont(15, weight: .semibold))
                        .padding(.horizontal, 22)
                        .frame(minHeight: 44)
                }
                .buttonStyle(HomePrimaryButtonStyle(accent: store.accent, paper: store.paper(dark: dark), reduceMotion: reduceMotion))
                Button { onOpenStudy("学习_听力") } label: {
                    Text("导入听写词表")
                        .font(store.homeFont(15, weight: .medium))
                        .padding(.horizontal, 22)
                        .frame(minHeight: 44)
                }
                .buttonStyle(LumaButtonStyle(.secondary, size: .large, ink: palette.ink, horizontalPadding: 0))
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(HomeSurface(skin: skin, palette: palette, accent: store.accent, radius: 18, prominent: true))
    }

    // MARK: 星轨布局（星漫主题）
    // 中心是「继续上次」；每颗行星是一个功能，一边公转（约 4 分钟一圈）一边自转。
    // 鼠标移到任意行星上公转就停住，方便点击；名称用漫画对话气泡显示。
    // 开启「减少动态效果」时全部静止。

    private static let orbitPeriod: Double = 240
    private static let planetColors: [(base: Color, band: Color, ringed: Bool)] = [
        (Color(red: 0.910, green: 0.631, blue: 0.361), Color(red: 0.788, green: 0.478, blue: 0.227), false),
        (Color(red: 0.498, green: 0.831, blue: 1.000), Color(red: 0.310, green: 0.663, blue: 0.867), true),
        (Color(red: 0.435, green: 0.816, blue: 0.784), Color(red: 0.278, green: 0.643, blue: 0.616), false),
        (Color(red: 0.561, green: 0.890, blue: 0.659), Color(red: 0.361, green: 0.749, blue: 0.494), false),
        (Color(red: 1.000, green: 0.561, blue: 0.639), Color(red: 0.878, green: 0.376, blue: 0.478), false),
        (Color(red: 1.000, green: 0.824, blue: 0.369), Color(red: 0.898, green: 0.682, blue: 0.173), false),
    ]

    private func liveOrbitAngle(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate * 2 * .pi / Self.orbitPeriod + orbitPhaseShift
    }

    private func holdOrbit(_ hold: Bool) {
        if hold {
            if orbitHoldAngle == nil { orbitHoldAngle = liveOrbitAngle(at: Date()) }
        } else if let held = orbitHoldAngle {
            orbitPhaseShift += held - liveOrbitAngle(at: Date())
            orbitHoldAngle = nil
        }
    }

    private var orbitLayout: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2 + 24)
            let radius = max(150, min(size.width, size.height) * 0.36)
            let items = features
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let now = timeline.date
                let angle = reduceMotion ? 0 : (orbitHoldAngle ?? liveOrbitAngle(at: now))
                let spin = reduceMotion ? 0.2 : now.timeIntervalSinceReferenceDate / 14
                ZStack {
                    Circle()
                        .strokeBorder(palette.muted.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 6]))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                    orbitSatellite(now: now, center: center, radius: radius + 70)
                    orbitComet(now: now, size: size)

                    VStack(spacing: 6) {
                        Text(dateLine).font(store.homeFont(12, weight: .semibold))
                        Text("今日 · 全部　听写 \(summary?.todayDictatedAllDecks ?? 0) 词 · 错词待复习 \(summary?.wrongDueAllDecks ?? 0) · 阅读 \(readingMinutesToday) 分钟")
                            .font(store.homeFont(12))
                            .monospacedDigit()
                    }
                    .foregroundStyle(StarMangaPalette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Rectangle().fill(StarMangaPalette.ink).offset(x: 4, y: 4))
                    .background(Rectangle().fill(StarMangaPalette.paper))
                    .overlay(Rectangle().strokeBorder(StarMangaPalette.ink, lineWidth: 2.5))
                    .position(x: size.width / 2, y: 44)

                    orbitCore
                        .frame(width: min(340, radius * 1.3))
                        .position(center)

                    ForEach(Array(items.enumerated()), id: \.element.id) { index, feature in
                        let a = -Double.pi / 2 + Double(index) * (2 * Double.pi / Double(items.count)) + angle
                        let point = CGPoint(x: center.x + CGFloat(cos(a)) * radius,
                                            y: center.y + CGFloat(sin(a)) * radius)
                        let colors = Self.planetColors[index % Self.planetColors.count]
                        planet(feature, base: colors.base, band: colors.band, ringed: colors.ringed, spin: spin + Double(index) * 0.17)
                            .position(point)
                    }
                }
            }
        }
    }

    private func orbitSatellite(now: Date, center: CGPoint, radius: CGFloat) -> some View {
        let a = reduceMotion ? -0.7 : -now.timeIntervalSinceReferenceDate * 2 * .pi / 420
        return Canvas { context, _ in
            let ink = StarMangaPalette.ink
            let hull = Path(CGRect(x: 16, y: 9, width: 12, height: 12))
            let left = Path(CGRect(x: 1, y: 11, width: 13, height: 8))
            let right = Path(CGRect(x: 30, y: 11, width: 13, height: 8))
            for (path, color) in [(hull, StarMangaPalette.paper), (left, StarMangaPalette.cyan), (right, StarMangaPalette.cyan)] {
                context.fill(path, with: .color(color))
                context.stroke(path, with: .color(ink), lineWidth: 2)
            }
            context.stroke(Path { p in p.move(to: CGPoint(x: 22, y: 9)); p.addLine(to: CGPoint(x: 22, y: 3)) }, with: .color(ink), lineWidth: 2)
        }
        .frame(width: 44, height: 30)
        .position(x: center.x + CGFloat(cos(a)) * radius, y: center.y + CGFloat(sin(a)) * radius)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 每 26 秒一颗带速度线的彗星从左上划向右下，持续约 5 秒。
    @ViewBuilder private func orbitComet(now: Date, size: CGSize) -> some View {
        let cycle = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 26) / 5
        if !reduceMotion && cycle < 1 {
            let t = CGFloat(cycle)
            Canvas { context, _ in
                let head = CGRect(x: 186, y: 0, width: 14, height: 14)
                context.fill(Path(ellipseIn: head), with: .color(StarMangaPalette.paper))
                context.stroke(Path(ellipseIn: head), with: .color(StarMangaPalette.ink), lineWidth: 2)
                for (i, length) in [180.0, 130.0, 90.0].enumerated() {
                    let y = 3.0 + Double(i) * 4
                    context.stroke(Path { p in p.move(to: CGPoint(x: 186 - length, y: y)); p.addLine(to: CGPoint(x: 186, y: y)) },
                                   with: .linearGradient(Gradient(colors: [.clear, i == 1 ? StarMangaPalette.cyan : StarMangaPalette.paper]),
                                                         startPoint: CGPoint(x: 186 - length, y: y), endPoint: CGPoint(x: 186, y: y)),
                                   lineWidth: 2)
                }
            }
            .frame(width: 200, height: 14)
            .rotationEffect(.degrees(18))
            .position(x: -120 + (size.width + 240) * t, y: 70 + size.height * 0.32 * t)
            .opacity(Double(min(1, min(t * 8, (1 - t) * 3))))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var orbitCore: some View {
        switch hero {
        case .dictation(let round):
            orbitCoreBody(kicker: "听力",
                          title: "\(round.roundDeckTitle ?? "听写") · 本轮",
                          ratio: Double(round.roundGraduated) / Double(max(1, round.roundTotal)),
                          detail: "已毕业 \(round.roundGraduated) / \(round.roundTotal) · 重现中 \(round.roundRetrying) · 本轮错题 \(round.roundWrong)",
                          button: "继续听写", action: onContinueDictation)
        case .book(let book):
            orbitCoreBody(kicker: "阅读", title: book.title,
                          ratio: min(1, max(0, book.progress)),
                          detail: "读到 \(Int((min(1, max(0, book.progress)) * 100).rounded()))%",
                          button: "继续阅读", action: { onOpenBook(book) })
        case .start:
            orbitCoreBody(kicker: "第一次使用", title: "从这里开始", ratio: 0,
                          detail: "导入一本书，或选一个听写单元",
                          button: "导入一本书", action: { store.pickBooks() })
        }
    }

    private func orbitCoreBody(kicker: String, title: String, ratio: Double, detail: String,
                               button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(store.themeHeadingFont(24, layout: store.themeLayout))
                .foregroundStyle(StarMangaPalette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white)
                Rectangle().fill(StarMangaPalette.ink).frame(width: max(0, 300 * ratio))
            }
            .frame(height: 8)
            .overlay(Rectangle().strokeBorder(StarMangaPalette.ink, lineWidth: 2))
            .clipped()
            Text("\(kicker) · \(detail)")
                .font(store.homeFont(12))
                .foregroundStyle(Color(red: 0.29, green: 0.31, blue: 0.39))
                .monospacedDigit()
            Button(action: action) {
                Text(button)
                    .font(store.homeFont(15, weight: .bold))
                    .foregroundStyle(StarMangaPalette.paper)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .background(Rectangle().fill(StarMangaPalette.ink))
                    .background(Rectangle().fill(StarMangaPalette.cyan).offset(x: 3, y: 3))
                    .contentShape(Rectangle())
            }
            .buttonStyle(HomePressStyle(reduceMotion: reduceMotion))
            .keyboardShortcut(.defaultAction)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Rectangle().fill(StarMangaPalette.cyan).offset(x: 7, y: 7))
        .background(Rectangle().fill(StarMangaPalette.paper))
        .overlay(Rectangle().strokeBorder(StarMangaPalette.ink, lineWidth: 3))
    }

    private func planet(_ feature: Feature, base: Color, band: Color, ringed: Bool, spin: Double) -> some View {
        let hovered = hoveredPlanet == feature.id
        let diameter: CGFloat = ringed ? 96 : 72
        return Button(action: feature.action) {
            VStack(spacing: 8) {
                StarPlanetDisc(base: base, band: band, phase: spin, ringed: ringed)
                    .frame(width: diameter, height: diameter)
                    // DESIGN.md：悬停不放大，只靠下方名牌出现给出反馈
                VStack(spacing: 1) {
                    Text(feature.title).font(store.homeFont(13, weight: .bold))
                    Text(feature.status).font(store.homeFont(11))
                }
                .foregroundStyle(StarMangaPalette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(StarMangaPalette.ink).offset(x: 2, y: 2))
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(StarMangaPalette.paper))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(StarMangaPalette.ink, lineWidth: 2))
                .fixedSize()
                .opacity(hovered ? 1 : 0)
                .offset(y: hovered ? 0 : -4)
            }
            .frame(width: 150)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(reduceMotion: reduceMotion))
        .onHover { inside in
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
                hoveredPlanet = inside ? feature.id : (hoveredPlanet == feature.id ? nil : hoveredPlanet)
            }
            holdOrbit(inside || (hoveredPlanet != nil && hoveredPlanet != feature.id))
        }
        .help(feature.title)
        .accessibilityLabel("\(feature.title)，\(feature.status)")
    }
}

// MARK: - 表面与按钮样式

/// 一处定义三种外观的卡片表面：卡片（玻璃感浅底）、星轨（半透明深色）、分镜（墨线粗框 + 错位投影）。
private struct HomeSurface: ViewModifier {
    let skin: LumaHomeView.Skin
    let palette: ReadingPalette
    let accent: Color
    let radius: CGFloat
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch skin {
        case .cards:
            content
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(prominent ? palette.paper.opacity(0.9) : palette.chrome.opacity(0.35)))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(palette.muted.opacity(0.18), lineWidth: 1))
        case .orbit:
            content
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(accent.opacity(prominent ? 0.45 : 0.2), lineWidth: 1))
        case .panels:
            let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
            content
                .background {
                    ZStack {
                        shape.fill(palette.ink).offset(x: prominent ? 4 : 2.5, y: prominent ? 4 : 2.5)
                        shape.fill(palette.paper)
                    }
                }
                .overlay(shape.strokeBorder(palette.ink, lineWidth: prominent ? 2 : 1.5))
        }
    }
}

/// 卡片按下：走统一按钮系统的整行反馈（0.985，不变暗、不放大、不回弹）。
private struct HomePressStyle: ButtonStyle {
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        LumaPressStyle(.row, dims: false).makeBody(configuration: configuration)
    }
}

/// 主按钮：统一按钮系统的「主要」角色，大号 44。
private struct HomePrimaryButtonStyle: ButtonStyle {
    let accent: Color
    let paper: Color
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        LumaButtonStyle(.primary, size: .large, accent: accent, onAccent: paper, horizontalPadding: 0)
            .makeBody(configuration: configuration)
    }
}
