import Foundation
import Testing
@testable import LumaReader

struct LibraryGroupsTests {
    @Test func customNamesTrimAndValidate() throws {
        var groups = LibraryGroups()
        let id = try groups.create("  雅思阅读  ")
        #expect(groups.active.first?.name == "雅思阅读")
        try groups.rename(id,to:"小说")
        #expect(groups.active.first?.name == "小说")
        #expect(throws:(any Error).self) { try groups.create("小说") }
        #expect(throws:(any Error).self) { try groups.create(" \n ") }
    }
    @Test func aBookCanBelongToSeveralGroupsAndBeRemovedFromOne() throws {
        var groups = LibraryGroups()
        let a = try groups.create("学习"), b = try groups.create("收藏")
        let book = UUID()
        groups.set(book:book,in:a,included:true); groups.set(book:book,in:b,included:true)
        #expect(groups.contains(book:book,in:a))
        #expect(groups.contains(book:book,in:b))
        groups.set(book:book,in:a,included:false)
        #expect(!groups.contains(book:book,in:a))
        #expect(groups.contains(book:book,in:b))
        groups.remove(a)
        #expect(groups.active.count == 1)
        #expect(groups.contains(book:book,in:b))
    }
    @Test func offlineRenameAndMembershipMergeWithoutLosingChanges() throws {
        var base = LibraryGroups()
        let id = try base.create("Original")
        let aBook = UUID(),bBook = UUID()
        var a = base,b = base
        a.groups[0].name = "Renamed"; a.groups[0].updatedAt = Date(timeIntervalSince1970:100)
        b.groups[0].updatedAt = Date(timeIntervalSince1970:50)
        a.groups[0].members[aBook.uuidString] = GroupMembership(included:true,updatedAt:Date(timeIntervalSince1970:30))
        b.groups[0].members[bBook.uuidString] = GroupMembership(included:true,updatedAt:Date(timeIntervalSince1970:30))
        let merged = LibraryGroups.merge(local:a,remote:b)
        #expect(merged.active.first?.name == "Renamed")
        #expect(merged.contains(book:aBook,in:id))
        #expect(merged.contains(book:bBook,in:id))
        #expect(merged == LibraryGroups.merge(local:b,remote:a))
        #expect(merged == LibraryGroups.merge(local:merged,remote:a))
    }
    @Test func staleDevicesCannotRestoreRemovedMembershipOrDeletedGroup() throws {
        var old = LibraryGroups()
        let id = try old.create("Books"), book = UUID()
        old.set(book:book,in:id,included:true)
        old.groups[0].members[book.uuidString]?.updatedAt = Date(timeIntervalSince1970:10)
        var newer = old
        newer.groups[0].members[book.uuidString] = GroupMembership(included:false,updatedAt:Date(timeIntervalSince1970:20))
        let merged = LibraryGroups.merge(local:newer,remote:old)
        #expect(!merged.contains(book:book,in:id))
        newer.remove(id)
        #expect(LibraryGroups.merge(local:newer,remote:old).active.isEmpty)
        #expect(try JSONDecoder().decode(LibraryGroups.self,from:JSONEncoder().encode(newer)) == newer)
    }
    @Test func groupsSyncBetweenIndependentDeviceDirectories() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at:base) }
        var groups = LibraryGroups()
        let id = try groups.create("我的分类")
        let book = Book(title:"Book",filename:"book.pdf",kind:"pdf")
        groups.set(book:book.id,in:id,included:true)
        let first = base.appendingPathComponent("first"),second = base.appendingPathComponent("second"),cloud = base.appendingPathComponent("cloud")
        try fm.createDirectory(at:first.appendingPathComponent("Books"),withIntermediateDirectories:true)
        try Data("fixture-book".utf8).write(to:first.appendingPathComponent("Books/book.pdf"))
        _ = try CloudSyncEngine.exchange(directory:cloud,localRoot:first,books:[book],ledger:ReadingLedger(),provider:.iCloud,deviceID:UUID().uuidString,collections:groups)
        let result = try CloudSyncEngine.exchange(directory:cloud,localRoot:second,books:[],ledger:ReadingLedger(),provider:.iCloud,deviceID:UUID().uuidString)
        #expect(result.collections.active.first?.name == "我的分类")
        #expect(result.collections.contains(book:book.id,in:id))
        #expect(result.books.first?.id == book.id)
    }
}
