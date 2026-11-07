import SwiftUI
import UniformTypeIdentifiers

struct DictationReportRow:Identifiable,Equatable {
    let id:String
    let word:String
    let errors:Int
    let attempts:Int
    let status:String
}
struct DictationSessionReport {
    let rows:[DictationReportRow]
    let totalAttempts:Int
    let firstTryCorrect:Int
    init(session:DictationSessionStateMachine) {
        let groups=Dictionary(grouping:session.attemptLogs,by:\.wordID)
        rows=groups.map{id,logs in
            DictationReportRow(id:id,word:logs.first!.word,errors:logs.filter{!$0.isCorrect}.count,attempts:logs.count,status:session.stubbornWordsMap[id] != nil ? "顽固单词":session.completedWordIDs.contains(id) ? "已通过":"待复习")
        }.sorted{if $0.errors != $1.errors{return $0.errors>$1.errors};return $0.word.localizedStandardCompare($1.word) == .orderedAscending}
        totalAttempts=session.attemptLogs.count
        firstTryCorrect=groups.values.filter{$0.first?.isCorrect==true}.count
    }
    var csv:String {
        func cell(_ text:String)->String {
            let safe=["=","+","-","@"].contains(String(text.prefix(1))) ? "'"+text:text
            return "\""+safe.replacingOccurrences(of:"\"",with:"\"\"")+"\""
        }
        let lines=[["单词","错误次数","提交次数","状态"]]+rows.map{[$0.word,String($0.errors),String($0.attempts),$0.status]}
        return "\u{FEFF}"+lines.map{$0.map(cell).joined(separator:",")}.joined(separator:"\r\n")+"\r\n"
    }
}
struct StudyCSVDocument:FileDocument {
    static var readableContentTypes:[UTType]{[.commaSeparatedText]}
    let text:String
    init(text:String){self.text=text}
    init(configuration:ReadConfiguration)throws{text=String(decoding:configuration.file.regularFileContents ?? Data(),as:UTF8.self)}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper{FileWrapper(regularFileWithContents:Data(text.utf8))}
}
struct DictationReportView:View {
    let session:DictationSessionStateMachine
    @State private var exporting=false
    @State private var error=""
    @Environment(\.studyAppearance) private var appearance
    var body:some View {
        let report=DictationSessionReport(session:session)
        VStack(alignment:.leading,spacing:12) {
            HStack {Text("本轮听写小结").font(.title2);Spacer();Button("导出 CSV",systemImage:"square.and.arrow.up"){exporting=true}}
            Text("\(report.rows.count) 个词 · 首次答对 \(report.firstTryCorrect) 个 · 提交 \(report.totalAttempts) 次").font(.callout)
            Text("按本轮错误次数从高到低排列，订正不算独立复习通过。").font(.caption).foregroundStyle(.secondary)
            ForEach(report.rows){row in
                HStack {Text(row.word).textSelection(.enabled);Spacer();Text("错 \(row.errors) 次");Text(row.status).foregroundStyle(.secondary)}
                Divider()
            }
            if !error.isEmpty{Text(error).foregroundStyle(.red)}
        }.padding(20).background(appearance.surface,in:RoundedRectangle(cornerRadius:14)).padding(.horizontal,32)
        .fileExporter(isPresented:$exporting,document:StudyCSVDocument(text:report.csv),contentType:.commaSeparatedText,defaultFilename:"听写小结-\(session.dateString)") {result in
            if case .failure(let issue)=result{error="导出失败：\(issue.localizedDescription)"}
        }
    }
}
