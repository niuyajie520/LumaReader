import SwiftUI

@main
struct LumaReaderIOSApp: App {
    @State private var store = StudyStore()
    @State private var speech = SpeechService()
    @State private var sync = CloudSyncService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = StudyStore()
        store.seedStarterDeckIfNeeded()
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(speech)
                .environment(sync)
                .tint(Color.lumaAccent)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                store.saveNow()
            case .active:
                break
            @unknown default:
                break
            }
        }
    }
}

struct RootView: View {
    @Environment(StudyStore.self) private var store
    @Environment(CloudSyncService.self) private var sync
    @State private var selection: Tab = .dictation

    enum Tab: Hashable {
        case dictation, reading, vocabulary, settings
    }

    var body: some View {
        TabView(selection: $selection) {
            DictationHomeView()
                .tabItem { Label("听写", systemImage: "waveform") }
                .tag(Tab.dictation)

            ReadingHomeView()
                .tabItem { Label("阅读", systemImage: "book") }
                .tag(Tab.reading)

            VocabularyHomeView()
                .tabItem { Label("词库", systemImage: "square.stack.3d.up") }
                .tag(Tab.vocabulary)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .onAppear {
            if sync.isConfigured { sync.sync(with: store) }
        }
    }
}

/// 阅读首页：书库 + 生词落库。
struct ReadingHomeView: View {
    @Environment(StudyStore.self) private var store

    var body: some View {
        BookShelfView { term, meaning in
            addReadingWord(term: term, meaning: meaning)
        }
    }

    /// 阅读时点到的生词加进「阅读生词本」，听写就会排到它。
    private func addReadingWord(term: String, meaning: String) {
        let deckID = "ios.reading"
        let deckTitle = "阅读生词本"
        if store.words.contains(where: { $0.deckID == deckID && $0.word.caseInsensitiveCompare(term) == .orderedSame }) {
            return
        }
        var words = store.words
        words.append(VocabularyWord(
            id: "\(deckID).\(term.lowercased().replacingOccurrences(of: " ", with: "_"))",
            word: term,
            definitionZH: meaning,
            deckID: deckID,
            deckTitle: deckTitle
        ))
        store.replaceWords(words)
    }
}
