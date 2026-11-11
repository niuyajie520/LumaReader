import Foundation
import Testing
@testable import LumaReader

struct CloudFileOperationsTests {
    @Test func refusesTraversalAndOverwrite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["..", "../outside", "nested/file", ""] {
            #expect(throws: (any Error).self) { try CloudFileOperations.child(name, in: root, root: root) }
        }
        try Data("original".utf8).write(to: root.appendingPathComponent("keep.txt"))
        #expect(throws: (any Error).self) { try CloudFileOperations.child("keep.txt", in: root, root: root) }
        #expect(try String(contentsOf: root.appendingPathComponent("keep.txt"), encoding: .utf8) == "original")
    }
    @Test func refusesExternalSymlinkAndListsAllFileTypes() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = parent.appendingPathComponent("cloud")
        let outside = parent.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: outside)
        #expect(throws: (any Error).self) { try CloudFileOperations.checked(root.appendingPathComponent("link"), root: root) }
        try Data().write(to: root.appendingPathComponent("photo.png"))
        try Data().write(to: root.appendingPathComponent("notes.docx"))
        let rows = try CloudFileOperations.entries(in: root, root: root)
        #expect(Set(rows.map(\.name)) == ["link", "photo.png", "notes.docx"])
    }
}
