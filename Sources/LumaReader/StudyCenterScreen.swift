import SwiftUI
import LumaReaderStudyKit

struct StudyCenterScreen: View {
    @Binding var mode:String
    @Bindable var store:LibraryStore
    let session:LumaStudySession
    @Environment(\.colorScheme) private var colorScheme
    var body:some View {
        let dark = store.isDarkAppearance
        let palette = store.readingPalette(dark:dark)
        Group {
        #if DEBUG
        LumaStudyCenterHostView(mode:$mode,session:session,evaluateWriting:{record,question in try await StudyWritingEvaluation.evaluate(record,question:question,store:store)})
            .onAppear { DebugReaderAcceptance.studyMounted = true }
            .onDisappear { DebugReaderAcceptance.studyMounted = false }
        #else
        LumaStudyCenterHostView(mode:$mode,session:session,evaluateWriting:{record,question in try await StudyWritingEvaluation.evaluate(record,question:question,store:store)})
        #endif
        }.environment(\.studyAppearance,StudyAppearance(paper:palette.paper,ink:palette.ink,accent:palette.accent,surface:palette.chrome,glassEnabled:store.effectiveGlassEffectsEnabled,isDark:dark))
            .foregroundStyle(palette.ink).tint(palette.accent)
    }
}

