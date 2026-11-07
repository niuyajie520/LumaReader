import SwiftUI
import LumaReaderStudyKit

struct StudyCenterScreen: View {
    @Binding var mode:String
    var body:some View {
        #if DEBUG
        LumaStudyCenterHostView(mode:$mode,storageDirectory:DebugReaderAcceptance.studyDirectory)
            .onAppear { DebugReaderAcceptance.studyMounted = true }
        #else
        LumaStudyCenterHostView(mode:$mode)
        #endif
    }
}
