import SwiftUI

struct WritingReviewSession:Identifiable {
    let id=UUID()
    let original:WritingSubmissionRecord
    let revision:WritingRevision
}
struct WritingReviewPanel:View {
    let original:WritingSubmissionRecord
    let onSave:@MainActor (WritingRevision)->String?
    @State private var revision:WritingRevision
    @State private var part=1
    @State private var status="尚未修改"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.studyAppearance) private var appearance
    init(session:WritingReviewSession,onSave:@escaping @MainActor (WritingRevision)->String?) {
        original=session.original;self.onSave=onSave;_revision=State(initialValue:session.revision)
    }
    private var answer:Binding<String> {
        Binding(get:{part==1 ? revision.part1:revision.part2},set:{text in
            if part==1{revision.part1=text}else{revision.part2=text}
            revision.updatedAt=Date();status=onSave(revision) ?? "已自动保存 · 原稿未改动"
        })
    }
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text("作文对照与重写").font(.title2);Spacer();Button("完成"){dismiss()}}
            Text("原稿和重写稿独立保存；AI 建议仅供复盘参考。").font(.caption).foregroundStyle(.secondary)
            Picker("任务",selection:$part){Text("Task 1").tag(1);Text("Task 2").tag(2)}.pickerStyle(.segmented).frame(maxWidth:260)
            HSplitView {
                ScrollView {
                    VStack(alignment:.leading,spacing:14) {
                        Text("原稿").font(.headline)
                        Text(part==1 ? original.part1EssayText:original.part2EssayText).textSelection(.enabled)
                        if let evaluation=original.aiEvaluation {
                            ForEach(Array(evaluation.sentenceCorrections.enumerated()),id:\.offset){_,item in
                                if (part==1 ? original.part1EssayText:original.part2EssayText).contains(item.originalSentence) {
                                    VStack(alignment:.leading,spacing:6) {
                                        Text(item.kind=="error" ? "需要修正的错误":item.kind=="upgrade" ? "可选表达优化":"建议 · 未分类").font(.caption).foregroundStyle(appearance.accent)
                                        Text(item.originalSentence).foregroundStyle(.secondary)
                                        Text(item.correctedSentence)
                                        Text(item.explanationZH).font(.callout)
                                        if !item.upgradedExpression.isEmpty{Text(item.upgradedExpression).font(.callout)}
                                    }.padding(12).background(appearance.surface,in:RoundedRectangle(cornerRadius:10))
                                }
                            }
                        } else {Text("尚无 AI 反馈，可先独立重写；不会生成示例纠错。").font(.caption).foregroundStyle(.secondary)}
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(16)
                }.frame(minWidth:260)
                VStack(alignment:.leading) {
                    Text("重写稿").font(.headline)
                    ExamEnglishTextEditor(text:answer,scope:.ieltsWritingFullMockExam,isEditable:true,fontSize:15.5,onInputRejected:{status=$0})
                    Text("字数 \(ExamEnglishInputPolicy().countIELTSWords(in:answer.wrappedValue))").font(.caption)
                }.padding(16).frame(minWidth:280)
            }
            Text(status).font(.caption).textSelection(.enabled)
        }.padding(24).frame(minWidth:760,idealWidth:1000,minHeight:580).background(appearance.paper).foregroundStyle(appearance.ink)
    }
}
