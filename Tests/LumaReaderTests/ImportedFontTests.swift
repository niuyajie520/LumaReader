import Foundation
import Testing
import CoreText
@testable import LumaReader

struct ImportedFontTests {
    private func base() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        return root
    }
    private func fixture() throws -> URL {
        try #require(Bundle.module.url(forResource:"LumaRegressionSans",withExtension:"ttf",subdirectory:"Fixtures"))
    }
    @Test func importedFontRegistersAndTransfersWithoutDuplication() throws {
        let root = try base(); defer { try? FileManager.default.removeItem(at:root) }
        let first = root.appendingPathComponent("first"), second = root.appendingPathComponent("second"), cloud = root.appendingPathComponent("cloud")
        let source = try fixture()
        try ImportedFontLoader.importFiles([source,source],root:first)
        let fonts = try ImportedFontLoader.load(root:first)
        let font = try #require(fonts.first)
        #expect(fonts.count == 1)
        #expect(font.postScriptName == "LumaRegressionSans-Regular")
        try FontFileSync.exchange(localRoot:first,cloudRoot:cloud)
        try FontFileSync.exchange(localRoot:second,cloudRoot:cloud)
        let received = try ImportedFontLoader.load(root:second)
        #expect(received == fonts)
        let bytes = try Data(contentsOf:second.appendingPathComponent("Fonts").appendingPathComponent(font.filename))
        let original = try Data(contentsOf:source)
        #expect(bytes == original)
        try FontFileSync.exchange(localRoot:first,cloudRoot:cloud)
        #expect(try FileManager.default.contentsOfDirectory(atPath:first.appendingPathComponent("Fonts").path).count == 1)
    }
    @Test func incompleteCloudFontIsRejectedWithoutOverwritingLocalData() throws {
        let root = try base(); defer { try? FileManager.default.removeItem(at:root) }
        let first = root.appendingPathComponent("first"), second = root.appendingPathComponent("second"), cloud = root.appendingPathComponent("cloud")
        try ImportedFontLoader.importFiles([try fixture()],root:first)
        try FontFileSync.exchange(localRoot:first,cloudRoot:cloud)
        let directory = cloud.appendingPathComponent("Fonts")
        let remote = try #require(FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil).first)
        try Data("incomplete".utf8).write(to:remote,options:.atomic)
        #expect(throws:(any Error).self) { try FontFileSync.exchange(localRoot:second,cloudRoot:cloud) }
        #expect(try FileManager.default.contentsOfDirectory(atPath:second.appendingPathComponent("Fonts").path).isEmpty)
        #expect(try ImportedFontLoader.load(root:first).count == 1)
    }
}
