import Foundation
import Testing
@testable import LumaReaderStudyKit

struct VocabularyImportTests {
    @Test func repeatedImportHasStableIDsAndPreservesDefinitions()throws {
        let tsv=Data("word\tmeaning\naccommodation\t住宿\nfluctuate\t波动\naccommodation\t重复\n".utf8)
        let first=try VocabularyImport.parse(tsv,filename:"Day 1.tsv")
        let second=try VocabularyImport.parse(tsv,filename:"Day 1.tsv")
        #expect(first==second);#expect(first.count==2);#expect(first[0].definitionZH=="住宿")
        let another=try VocabularyImport.parse(tsv,filename:"Day 2.tsv")
        #expect(another[0].id != first[0].id)
    }
    @Test func jsonAndPhraseSupportDoNotModifyMisspellings()throws {
        let words=try VocabularyImport.parse(Data(#"[{"word":"teh enviroment","meaning":"保留拼写"}]"#.utf8),filename:"phrases.json")
        #expect(words.first?.word=="teh enviroment")
    }
    @Test func malformedOrNonEnglishWordsFailRatherThanPartiallyImport() {
        for data in [Data("word only".utf8),Data("hello\t你好\n中文\tinvalid".utf8)] {
            #expect(throws:(any Error).self){try VocabularyImport.parse(data,filename:"fixture.tsv")}
        }
    }
}
