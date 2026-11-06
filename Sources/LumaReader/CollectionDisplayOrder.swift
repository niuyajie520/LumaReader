import Foundation

enum CollectionDisplayOrder {
    static func sorted(_ groups:[LibraryGroup],saved:[String]) -> [LibraryGroup] {
        var ranks:[String:Int] = [:]
        for id in saved where ranks[id] == nil { ranks[id] = ranks.count }
        return groups.filter { $0.deletedAt == nil }.sorted {
            let a = ranks[$0.id.uuidString], b = ranks[$1.id.uuidString]
            if a != b { return (a ?? Int.max) < (b ?? Int.max) }
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id.uuidString < $1.id.uuidString:comparison == .orderedAscending
        }
    }
    static func moving(_ source:UUID,to target:UUID,after:Bool,groups:[LibraryGroup],saved:[String]) -> [String] {
        var ids = sorted(groups,saved:saved).map(\.id)
        guard source != target, let sourceIndex = ids.firstIndex(of:source),ids.contains(target) else { return saved }
        ids.remove(at:sourceIndex)
        guard let targetIndex = ids.firstIndex(of:target) else { return saved }
        ids.insert(source,at:targetIndex+(after ? 1:0))
        return ids.map(\.uuidString)
    }
}
