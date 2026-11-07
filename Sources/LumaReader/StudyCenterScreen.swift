import SwiftUI
import LumaReaderStudyKit

struct StudyCenterScreen: View {
    @Binding var mode:String
    @Bindable var store:LibraryStore
    @Environment(\.colorScheme) private var colorScheme
    var body:some View {
        let palette = store.readingPalette(dark:colorScheme == .dark)
        Group {
        #if DEBUG
        LumaStudyCenterHostView(mode:$mode,storageDirectory:DebugReaderAcceptance.studyDirectory,evaluateWriting:{record,question in try await StudyWritingEvaluation.evaluate(record,question:question,store:store)})
            .onAppear { DebugReaderAcceptance.studyMounted = true }
        #else
        LumaStudyCenterHostView(mode:$mode,evaluateWriting:{record,question in try await StudyWritingEvaluation.evaluate(record,question:question,store:store)})
        #endif
        }.environment(\.studyAppearance,StudyAppearance(paper:palette.paper,ink:palette.ink,accent:palette.accent,surface:palette.chrome))
            .foregroundStyle(palette.ink).tint(palette.accent)
    }
}
