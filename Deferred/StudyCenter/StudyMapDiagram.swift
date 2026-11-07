import SwiftUI

/// A schematic of the source region labels, never invented coordinates or scale.
struct StudyMapDiagram:View {
    let title:String
    let features:[MapStageFeature]
    private let columns=[GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())]
    private func cell(_ feature:MapStageFeature)->Int {
        let region=feature.region.lowercased()
        let row=region.contains("north") ? 0:region.contains("south") ? 2:1
        let column=region.contains("west") ? 0:region.contains("east") ? 2:1
        return row*3+column
    }
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Text(title).font(.headline)
            Text("N ↑ · 方位示意，非比例").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns:columns,spacing:10) {
                ForEach(0..<9,id:\.self) {index in
                    let items=features.filter{cell($0)==index}
                    VStack(spacing:6) {
                        ForEach(Array(items.enumerated()),id:\.offset) {_,feature in
                            VStack(spacing:3) {
                                Text(feature.label).font(.caption.weight(.medium))
                                Text(feature.status).font(.caption2).foregroundStyle(.secondary)
                            }.multilineTextAlignment(.center).padding(6)
                        }
                        if items.isEmpty {Color.clear.frame(height:30)}
                    }.frame(maxWidth:.infinity,minHeight:50)
                        .background(items.isEmpty ? Color.clear:Color.blue.opacity(0.08),in:RoundedRectangle(cornerRadius:8))
                }
            }.padding(14).background(Color.green.opacity(0.07),in:RoundedRectangle(cornerRadius:32))
                .overlay(RoundedRectangle(cornerRadius:32).stroke(Color.green.opacity(0.25),lineWidth:1))
        }.foregroundStyle(.black)
    }
}
