import SwiftUI
import Charts

struct StatisticsView: View {
    @Bindable var activity: ReadingActivityStore
    let theme: ReaderTheme
    var store: LibraryStore? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undo
    @State private var goalDraft = ""
    @State private var goalError = false
    @State private var detailDate = Date()
    @State private var period: ReadingPeriod = .day
    @State private var anchor = Date()
    @State private var selectedLabel: String?
    @State private var selectedYear: Int? = Calendar.current.component(.year,from:Date())
    private var years: [Int] {
        Array(Set(activity.ledger.dailySeconds.keys.compactMap { Int($0.prefix(4)) } + [Calendar.current.component(.year,from:Date())])).sorted(by:>)
    }
    private var buckets: [ReadingBucket] {
        period == .month ? activity.ledger.months(year:selectedYear) : activity.ledger.buckets(period:period,through:anchor)
    }
    private var chartCeiling: Double {
        max(1,max(buckets.map { $0.seconds/60 }.max() ?? 0,period == .day ? Double(activity.dailyGoalMinutes):0) * 1.2)
    }
    private var todaySeconds: Double { total(.day) }
    private var targetSeconds: Double { Double(activity.dailyGoalMinutes * 60) }

    private func uiFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil) -> Font {
        if let store { return store.homeFont(size, weight: weight, design: design) }
        return .system(size: size, weight: weight, design: design ?? .serif)
    }

    private func total(_ component: Calendar.Component) -> Double {
        guard let interval = Calendar.current.dateInterval(of:component,for:Date()) else { return 0 }
        return activity.ledger.seconds(in:interval)
    }

    private var palette: ReadingPalette { store?.readingPalette(dark:colorScheme == .dark) ?? .classic(theme,dark:colorScheme == .dark) }

    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:26) {
                HStack(alignment:.center) {
                    Text(L10n.text("阅读统计"))
                        .font(uiFont(30, weight: .medium))
                        .tracking(LumaFontFamily.opticalTracking(for: 30))
                    Spacer()
                    Image(systemName:"chart.bar.xaxis").font(.system(size:26,weight:.light)).foregroundStyle(palette.accent)
                }
                HStack(spacing:24) {
                    summary(L10n.text("今天"),seconds:todaySeconds)
                    summary(L10n.text("本周"),seconds:total(.weekOfYear))
                    summary(L10n.text("本月"),seconds:total(.month))
                }
                VStack(alignment:.leading,spacing:13) {
                    HStack {
                        Label(L10n.text("每日目标"),systemImage:"target").font(uiFont(14, weight: .medium))
                        Spacer()
                        Text(L10n.text(todaySeconds >= targetSeconds ? "已达成" : "\(Int(min(1,todaySeconds/targetSeconds)*100))%"))
                            .font(uiFont(12))
                            .monospacedDigit()
                            .foregroundStyle(palette.muted)
                    }
                    ProgressView(value:min(todaySeconds/targetSeconds,1)).tint(palette.accent)
                    HStack {
                        Text(L10n.text("已读 \(readingDuration(todaySeconds))"))
                            .font(uiFont(11))
                            .monospacedDigit()
                            .foregroundStyle(palette.muted)
                        Spacer()
                        TextField(L10n.text("分钟"),text:$goalDraft)
                            .frame(width:60).textFieldStyle(.roundedBorder)
                            .accessibilityLabel(L10n.text("每日阅读目标分钟数")).onSubmit { saveGoal() }
                        Text(L10n.text("分钟")).font(uiFont(11))
                        Button(L10n.text("应用")) { saveGoal() }
                        Stepper("",value:$activity.dailyGoalMinutes,in:5...600,step:5).labelsHidden()
                            .fixedSize()
                            .font(uiFont(11))
                            .monospacedDigit()
                    }
                }.padding(20).background(palette.chrome,in:RoundedRectangle(cornerRadius:14, style: .continuous))

                if goalError { Text(L10n.text("目标请输入 5–600 之间的整数分钟。")).foregroundStyle(.red) }
                hourlyDetail
                VStack(alignment:.leading,spacing:18) {
                    HStack(spacing: 8) {
                        Picker(L10n.text("周期"),selection:$period) { ForEach(ReadingPeriod.allCases) { Text(L10n.text($0.rawValue)).tag($0) } }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width:210)
                        Spacer()
                        if period == .month {
                            Picker(L10n.text("年份"),selection:$selectedYear) {
                                Text(L10n.text("全部年份")).tag(Int?.none)
                                ForEach(years,id:\.self) { Text(String($0)).tag(Optional($0)) }
                            }.frame(width:155)
                        } else {
                            Button { move(-1) } label: { Image(systemName:"chevron.left") }
                                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.92, cornerRadius: 6, horizontalPadding: 8, verticalPadding: 5))
                                .help(L10n.text("更早"))
                            Button(L10n.text("最近")) {
                                anchor = Date(); selectedLabel = nil
                            }
                            .buttonStyle(LumaTactileButtonStyle(pressScale: 0.95, cornerRadius: 6, horizontalPadding: 9, verticalPadding: 5))
                            .font(uiFont(11))
                            Button { move(1) } label: { Image(systemName:"chevron.right") }
                                .buttonStyle(LumaTactileButtonStyle(pressScale: 0.92, cornerRadius: 6, horizontalPadding: 8, verticalPadding: 5))
                                .disabled(isCurrentRange)
                                .help(L10n.text("更新"))
                        }
                    }
                    Chart {
                        ForEach(buckets) { bucket in
                            BarMark(x:.value("日期",bucket.label),yStart:.value("基线",0),yEnd:.value("背景",chartCeiling),width:.ratio(0.55))
                                .foregroundStyle(palette.muted.opacity(0.07)).cornerRadius(4)
                                .accessibilityHidden(true)
                            BarMark(x:.value("日期",bucket.label),y:.value("分钟",bucket.seconds/60),width:.ratio(0.55))
                                .foregroundStyle(palette.accent.opacity(selectedLabel == nil || selectedLabel == bucket.label ? 1:0.35))
                                .cornerRadius(4)
                                .accessibilityLabel(bucket.label)
                                .accessibilityValue(readingDuration(bucket.seconds))
                        }
                        if period == .day {
                            RuleMark(y:.value("每日目标",Double(activity.dailyGoalMinutes)))
                                .foregroundStyle(palette.muted.opacity(0.45)).lineStyle(StrokeStyle(lineWidth:1,dash:[4,4]))
                        }
                    }
                    .chartXAxisLabel(period == .week ? "周起始" : period == .month ? "月份" : "日期")
                    .chartYAxisLabel(L10n.text("分钟"))
                    .chartYScale(domain:0...chartCeiling)
                    .chartXSelection(value:$selectedLabel)
                    .frame(height:270)
                    HStack {
                        if let selected = buckets.first(where:{$0.label == selectedLabel}) {
                            Text("\(selected.label) · \(readingDuration(selected.seconds))").monospacedDigit()
                        } else {
                            Text(L10n.text("\(period == .month ? selectedYear.map { String($0)+"年" } ?? "全部年份" : "最近 \(period.count) \(period == .day ? "天":"周")") · 共 \(readingDuration(buckets.reduce(0){$0+$1.seconds}))")).monospacedDigit()
                        }
                        Spacer()
                    }.font(uiFont(11)).foregroundStyle(palette.muted)
                }
                if let error = activity.error { Text(L10n.text(error)).font(uiFont(11)).foregroundStyle(.red) }
            }.padding(40).frame(maxWidth:1050)
        }.frame(maxWidth:.infinity).background(palette.paper)
            .onChange(of:period) { _,_ in anchor = Date();selectedLabel = nil }
            .onChange(of:selectedYear) { _,_ in selectedLabel = nil }
            .onAppear { activity.setReadingVisible(false); goalDraft = String(activity.dailyGoalMinutes) }
            .onChange(of:activity.dailyGoalMinutes) { _,value in goalDraft = String(value); goalError = false }
    }


    private func saveGoal() {
        guard let value = Int(goalDraft.trimmingCharacters(in:.whitespacesAndNewlines)),(5...600).contains(value) else { goalError = true; return }
        activity.dailyGoalMinutes = value; goalError = false
    }
    private var canUndoReset:Bool {
        let key = ReadingLedger.key(detailDate,calendar:.current)
        return (activity.ledger.resetDays?[key] ?? .distantPast) > (activity.ledger.restoredDays?[key] ?? .distantPast)
    }
    private var hourlyDetail:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text(L10n.text("阅读时段")).font(uiFont(16,weight:.medium))
                Spacer()
                DatePicker(L10n.text("日期"),selection:$detailDate,in:...Date(),displayedComponents:.date).labelsHidden()
                Button(L10n.text("重置当天")) { activity.resetDay(detailDate,undo:undo) }
                if canUndoReset { Button(L10n.text("撤销重置")) { activity.undoResetDay(detailDate,undo:undo) } }
            }
            Chart(activity.ledger.hours(on:detailDate)) { hour in
                BarMark(x:.value("时间",hour.start),y:.value("分钟",hour.seconds/60))
                    .foregroundStyle(palette.accent).cornerRadius(3)
            }.chartXAxis { AxisMarks(values:.stride(by:.hour,count:3)) { value in
                AxisGridLine(); AxisValueLabel(format:.dateTime.hour().minute())
            }}.chartYAxisLabel(L10n.text("分钟")).frame(height:180)
            let sessions = activity.ledger.sessions(on:detailDate)
            if sessions.isEmpty {
                Text(L10n.text("这天没有可显示的详细时段。旧版只有每日总时长，无法还原具体时间。"))
                    .font(uiFont(11)).foregroundStyle(palette.muted)
            } else {
                ForEach(sessions) { session in
                    HStack {
                        Text(session.start,style:.time); Text("–"); Text(session.end,style:.time)
                        Spacer(); Text(L10n.text(readingDuration(session.end.timeIntervalSince(session.start))))
                    }.font(uiFont(12)).monospacedDigit()
                }
            }
            Text(L10n.text("重置可撤销，原始记录保留；支持 ⌘Z。每日目标不受影响。"))
                .font(uiFont(11)).foregroundStyle(palette.muted)
        }.padding(20).background(palette.chrome,in:RoundedRectangle(cornerRadius:14))
    }

    private func summary(_ title: String,seconds: Double) -> some View {
        VStack(alignment:.leading,spacing:8) {
            Text(L10n.text(title)).font(uiFont(11)).foregroundStyle(palette.muted)
            Text(L10n.text(readingDuration(seconds))).font(uiFont(23, weight: .medium, design: .rounded)).monospacedDigit()
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    private var isCurrentRange: Bool {
        guard let interval = Calendar.current.dateInterval(of:period.component,for:Date()) else { return true }
        return anchor >= interval.start
    }
    private func move(_ direction: Int) {
        if let next = Calendar.current.date(byAdding:period.component,value:direction*period.count,to:anchor) {
            anchor = min(next,Date()); selectedLabel = nil
        }
    }
}
