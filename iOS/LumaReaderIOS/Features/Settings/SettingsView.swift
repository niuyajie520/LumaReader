import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(CloudSyncService.self) private var sync
    @Environment(SpeechService.self) private var speech

    @State private var choosingFolder = false
    @State private var importingStore = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                speechSection
                syncSection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    sync.chooseFolder(url)
                    message = sync.statusMessage
                }
            }
            .fileImporter(isPresented: $importingStore, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                handleStoreImport(result)
            }
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.lumaSurface, in: Capsule())
                        .padding(.bottom, 12)
                        .task(id: message) {
                            try? await Task.sleep(nanoseconds: 2_600_000_000)
                            self.message = nil
                        }
                }
            }
        }
    }

    // MARK: 朗读

    private var speechSection: some View {
        Section {
            Picker("口音", selection: accentBinding) {
                ForEach(SpeechService.Accent.allCases) { accent in
                    Text(accent.title).tag(accent)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("语速")
                    Spacer()
                    Text(rateLabel).font(.footnote).foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { store.speechRate }, set: { store.speechRate = $0 }), in: 0.2...0.8)
            }

            Stepper("每词朗读 \(store.speechRepeatCount) 遍",
                    value: Binding(get: { store.speechRepeatCount }, set: { store.speechRepeatCount = $0 }),
                    in: 1...3)
        } header: {
            Text("朗读")
        } footer: {
            Text("使用系统自带的英语语音，离线可用。")
        }
    }

    private var accentBinding: Binding<SpeechService.Accent> {
        Binding(get: { store.speechAccent }, set: { store.speechAccent = $0 })
    }

    private var rateLabel: String {
        let value = store.speechRate
        if value < 0.38 { return "慢" }
        if value > 0.58 { return "快" }
        return "标准"
    }

    // MARK: 云同步

    private var syncSection: some View {
        Section {
            LabeledContent("同步文件夹", value: sync.isConfigured ? sync.folderName : "未选择")
            Button {
                choosingFolder = true
            } label: {
                Label(sync.isConfigured ? "更换文件夹" : "选择 iCloud 文件夹", systemImage: "folder.badge.gearshape")
            }
            Button {
                sync.sync(with: store)
                message = sync.statusMessage
            } label: {
                Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!sync.isConfigured || sync.isSyncing)

            if sync.isConfigured {
                Button(role: .destructive) {
                    sync.disconnect()
                    message = sync.statusMessage
                } label: {
                    Label("断开同步文件夹", systemImage: "xmark.circle")
                }
            }

            if let last = sync.lastSyncedAt {
                LabeledContent("上次同步", value: last.formatted(date: .abbreviated, time: .shortened))
            }
        } header: {
            Text("云同步")
        } footer: {
            Text("在「文件」App 里选一个 iCloud 云盘文件夹，Mac 与 iPhone 各写一份数据文件，同步时合并两端的词库与复习进度。")
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        Section {
            LabeledContent("词条", value: "\(store.words.count) 个")
            LabeledContent("复习记录", value: "\(store.schedule.count) 个")
            LabeledContent("听写日志", value: "\(store.logs.count) 条")
            Button {
                importingStore = true
            } label: {
                Label("导入 Mac 的学习数据", systemImage: "square.and.arrow.down")
            }
            Button {
                store.saveNow()
                message = "已保存到本机。"
            } label: {
                Label("立即保存", systemImage: "checkmark.circle")
            }
        } header: {
            Text("学习数据")
        } footer: {
            Text("在 Mac 上找到 luma_study_store.json（学习中心数据目录），导进来即可把词库和复习进度搬过来。")
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        Section("关于") {
            LabeledContent("版本", value: appVersion)
            Link(destination: URL(string: "https://github.com/")!) {
                Label("项目主页", systemImage: "link")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func handleStoreImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let snapshot = StudyStore.decodeSnapshot(data) else {
            message = "这不是有效的学习数据文件。"
            return
        }
        let replacing = store.isStarterOnly
        store.mergeRemote(words: snapshot.words,
                          schedule: snapshot.schedule,
                          logs: snapshot.logs,
                          stubborn: snapshot.stubborn,
                          replacingWords: replacing)
        store.seedStarterDeckIfNeeded()
        message = replacing
            ? "已导入 \(snapshot.words.count) 个词条与 \(snapshot.schedule.count) 条复习记录"
            : "已合并 \(snapshot.words.count) 个词条与 \(snapshot.schedule.count) 条复习记录"
    }
}
