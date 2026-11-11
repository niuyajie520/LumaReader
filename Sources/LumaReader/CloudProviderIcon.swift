import SwiftUI

/// Monochrome service silhouettes inherit Monet tint, including light/dark contrast.
struct CloudProviderIcon: View {
    let provider: CloudProvider
    var body: some View {
        Group {
            switch provider {
            case .iCloud: Image(systemName:"icloud.fill").resizable().scaledToFit()
            case .oneDrive:
                Image(systemName:"cloud.fill").resizable().scaledToFit()
                    .overlay(alignment:.bottomLeading) {
                        Image(systemName:"cloud.fill").resizable().scaledToFit().frame(width:12,height:9)
                            .opacity(0.65).offset(x:-1,y:1)
                    }
            case .googleDrive: DriveSilhouette().fill(style:FillStyle(eoFill:true))
            }
        }.frame(width:18,height:16).accessibilityLabel(provider.title)
    }
}
private struct DriveSilhouette: Shape {
    func path(in rect:CGRect)->Path {
        var p=Path()
        func polygon(_ points:[CGPoint]) {
            p.move(to:CGPoint(x:rect.minX+points[0].x*rect.width,y:rect.minY+points[0].y*rect.height))
            for v in points.dropFirst(){p.addLine(to:CGPoint(x:rect.minX+v.x*rect.width,y:rect.minY+v.y*rect.height))};p.closeSubpath()
        }
        polygon([.init(x:0.34,y:0),.init(x:0.66,y:0),.init(x:1,y:0.68),.init(x:0.83,y:1),.init(x:0.17,y:1),.init(x:0,y:0.68)])
        polygon([.init(x:0.5,y:0.3),.init(x:0.72,y:0.74),.init(x:0.28,y:0.74)])
        return p
    }
}
