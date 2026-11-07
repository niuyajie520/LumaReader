import Foundation
import CryptoKit

public nonisolated enum VocabularyImport {
    struct Item:Decodable {let word:String;let meaning:String}
    public static func parse(_ data:Data,filename:String)throws->[VocabularyWord] {
        guard data.count<=2*1024*1024 else {throw CocoaError(.fileReadTooLarge)}
        let entries:[Item]
        if filename.lowercased().hasSuffix(".json") {
            entries=try JSONDecoder().decode([Item].self,from:data)
        } else {
            guard let text=String(data:data,encoding:.utf8) else {throw CocoaError(.fileReadInapplicableStringEncoding)}
            entries=try text.components(separatedBy:.newlines).enumerated().compactMap {index,line in
                if line.trimmingCharacters(in:.whitespaces).isEmpty {return nil}
                let columns=line.components(separatedBy:"\t")
                if index==0 && columns.first?.lowercased()=="word" {return nil}
                guard columns.count>=2 else {throw CocoaError(.fileReadCorruptFile)}
                return Item(word:columns[0],meaning:columns[1...].joined(separator:"\t"))
            }
        }
        guard !entries.isEmpty,entries.count<=20000 else {throw CocoaError(.fileReadCorruptFile)}
        let deck="import."+hex(Data(filename.utf8))
        var seen=Set<String>()
        return try entries.compactMap {entry in
            let word=entry.word.trimmingCharacters(in:.whitespacesAndNewlines)
            guard !word.isEmpty,word.count<=200,word.unicodeScalars.allSatisfy({$0.value>=32 && $0.value<=126}) else {throw CocoaError(.fileReadCorruptFile)}
            let id=deck+"."+hex(Data(word.lowercased().utf8))
            guard seen.insert(id).inserted else {return nil}
            return VocabularyWord(id:id,word:word,phoneticUK:"",phoneticUS:"",partOfSpeech:"",definitionZH:entry.meaning,exampleSentence:"",deckID:deck,deckTitle:(filename as NSString).deletingPathExtension)
        }
    }
    private static func hex(_ data:Data)->String {SHA256.hash(data:data).prefix(12).map{String(format:"%02x",$0)}.joined()}
}
