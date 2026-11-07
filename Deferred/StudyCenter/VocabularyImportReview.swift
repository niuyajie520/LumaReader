import SwiftUI

struct VocabularyImportRow:Identifiable,Equatable {
    let id=UUID()
    var word:String
    var meaning:String
    var included=true
    var issue:String? {
        let text=word.trimmingCharacters(in:.whitespacesAndNewlines)
        if text.isEmpty || text.count>200 || !text.unicodeScalars.allSatisfy({$0.value>=32 && $0.value<=126}) || DictationAnswerPolicy.normalized(text).isEmpty{return "英文为空、过长或含非英文字符"}
        if meaning.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{return "请补充中文释义"}
        return nil
    }
}
struct VocabularyImportDraft:Identifiable {
    let id=UUID()
    let filename:String
    var rows:[VocabularyImportRow]
    init(data:Data,filename:String)throws {
        guard data.count<=2*1024*1024 else{throw CocoaError(.fileReadTooLarge)}
        self.filename=filename
        if filename.lowercased().hasSuffix(".json") {
            rows=try JSONDecoder().decode([VocabularyImport.Item].self,from:data).map{VocabularyImportRow(word:$0.word,meaning:$0.meaning)}
        } else {
            guard let text=String(data:data,encoding:.utf8) else{throw CocoaError(.fileReadInapplicableStringEncoding)}
            rows=text.replacingOccurrences(of:"\u{FEFF}",with:"").components(separatedBy:.newlines).compactMap{line in
                guard !line.trimmingCharacters(in:.whitespaces).isEmpty else{return nil}
                let columns=line.components(separatedBy:"\t")
                if columns.first?.lowercased()=="word"{return nil}
                return VocabularyImportRow(word:columns[0],meaning:columns.dropFirst().joined(separator:"\t"))
            }
        }
        guard !rows.isEmpty,rows.count<=20000 else{throw CocoaError(.fileReadCorruptFile)}
    }
    func confirmedWords(existing:[VocabularyWord])throws->[VocabularyWord] {
        let selected=rows.filter(\.included)
        guard !selected.isEmpty,selected.allSatisfy({$0.issue==nil}) else{throw CocoaError(.fileReadCorruptFile)}
        let json=try JSONSerialization.data(withJSONObject:selected.map{["word":$0.word,"meaning":$0.meaning]})
        // Keep the filename-derived deck identity even when edited data was TSV.
        let words=try VocabularyImport.parseJSONEntries(json,filename:filename)
        let ids=Set(existing.map(\.id))
        return words.filter{!ids.contains($0.id)}
    }
}
struct VocabularyImportReview:View {
    @State var draft:VocabularyImportDraft
    let existing:[VocabularyWord]
    let onConfirm:@MainActor ([VocabularyWord])->String?
    @State private var error=""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.studyAppearance) private var appearance
    private var warnings:[UUID:String] {
        var result:[UUID:String]=[:],seen=Set<String>()
        let deckWords=Set(existing.filter{$0.deckTitle==(draft.filename as NSString).deletingPathExtension}.map{$0.word.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()})
        for row in draft.rows where row.included {
            let key=row.word.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
            if let issue=row.issue{result[row.id]=issue}
            else if deckWords.contains(key) || !seen.insert(key).inserted{result[row.id]="重复词 · 保留已有词条，不重复导入"}
        }
        return result
    }
    var body:some View {
        let notices=warnings
        VStack(alignment:.leading,spacing:16) {
            HStack {Text("词库导入预览").font(.title2);Spacer();Button("取消"){dismiss()}}
            Text("\(draft.filename) · \(draft.rows.count) 行。可修改英文、释义或取消勾选；确认前不会写入词库。").font(.callout)
            List($draft.rows){$row in
                VStack(alignment:.leading,spacing:5) {
                    HStack {
                        Toggle("导入",isOn:$row.included).labelsHidden()
                        TextField("英文",text:$row.word).autocorrectionDisabled().frame(minWidth:180)
                        TextField("中文释义",text:$row.meaning).frame(minWidth:240)
                    }
                    if let notice=notices[row.id]{Text(notice).font(.caption).foregroundStyle(row.issue==nil ? appearance.ink.opacity(0.6):.red)}
                }.padding(.vertical,4)
            }
            if !error.isEmpty{Text(error).foregroundStyle(.red)}
            HStack {Spacer();Button("确认导入新词") {
                do {let words=try draft.confirmedWords(existing:existing);if let issue=onConfirm(words){error=issue}else{dismiss()}}
                catch {error="请修正或取消勾选有问题的行。现有词库未更改。"}
            }.buttonStyle(.borderedProminent).disabled(!draft.rows.contains(where:{$0.included}) || draft.rows.contains(where:{$0.included && $0.issue != nil}))}
        }.padding(24).frame(minWidth:720,minHeight:500).background(appearance.paper).foregroundStyle(appearance.ink)
    }
}
