import Foundation

struct GroupMembership: Codable, Equatable, Sendable {
    var included: Bool
    var updatedAt: Date
}

struct LibraryGroup: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var updatedAt = Date()
    var deletedAt: Date? = nil
    var members: [String:GroupMembership] = [:]
}

struct LibraryGroups: Codable, Equatable, Sendable {
    var groups: [LibraryGroup] = []
    var active: [LibraryGroup] {
        groups.filter { $0.deletedAt == nil }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func contains(book:UUID,in group:UUID) -> Bool {
        groups.first { $0.id == group && $0.deletedAt == nil }?.members[book.uuidString]?.included == true
    }
    private func validName(_ raw:String,excluding:UUID? = nil) throws -> String {
        let name = raw.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { throw ReaderFailure.message("分类名称请输入 1–80 个字。") }
        guard !active.contains(where:{ $0.id != excluding && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw ReaderFailure.message("已有同名分类，请换个名称。")
        }
        return name
    }
    @discardableResult mutating func create(_ raw:String) throws -> UUID {
        let group = LibraryGroup(name:try validName(raw)); groups.append(group); return group.id
    }
    mutating func rename(_ id:UUID,to raw:String) throws {
        let name = try validName(raw,excluding:id)
        guard let index = groups.firstIndex(where:{ $0.id == id && $0.deletedAt == nil }) else { return }
        groups[index].name = name; groups[index].updatedAt = Date()
    }
    mutating func remove(_ id:UUID) {
        guard let index = groups.firstIndex(where:{ $0.id == id }) else { return }
        groups[index].deletedAt = Date()
    }
    mutating func set(book:UUID,in group:UUID,included:Bool) {
        guard let index = groups.firstIndex(where:{ $0.id == group && $0.deletedAt == nil }) else { return }
        groups[index].members[book.uuidString] = GroupMembership(included:included,updatedAt:Date())
    }
    static func merge(local:Self,remote:Self) -> Self {
        var merged: [UUID:LibraryGroup] = [:]
        for group in local.groups + remote.groups {
            guard var previous = merged[group.id] else { merged[group.id] = group; continue }
            if group.updatedAt > previous.updatedAt || (group.updatedAt == previous.updatedAt && group.name > previous.name) {
                previous.name = group.name; previous.updatedAt = group.updatedAt
            }
            if let deleted = group.deletedAt { previous.deletedAt = max(previous.deletedAt ?? .distantPast,deleted) }
            for (book,membership) in group.members {
                if let old = previous.members[book], old.updatedAt > membership.updatedAt || (old.updatedAt == membership.updatedAt && !old.included) { continue }
                previous.members[book] = membership
            }
            merged[group.id] = previous
        }
        return Self(groups:merged.values.sorted { $0.id.uuidString < $1.id.uuidString })
    }
}
