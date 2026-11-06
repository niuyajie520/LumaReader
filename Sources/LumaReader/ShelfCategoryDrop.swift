import SwiftUI
import UniformTypeIdentifiers

enum ShelfCategoryDrag {
    static let type = "app.luma.collection-order"
    static func provider(_ id:UUID) -> NSItemProvider {
        let item = NSItemProvider(), data = Data(id.uuidString.utf8)
        item.registerDataRepresentation(forTypeIdentifier:type,visibility:.ownProcess) { completion in
            completion(data,nil); return nil
        }
        return item
    }
}

@MainActor struct ShelfCategoryDrop: @preconcurrency DropDelegate {
    let store: LibraryStore
    let target: UUID
    let allowsReorder: Bool
    @Binding var bookTarget: UUID?
    @Binding var categoryTarget: UUID?
    @Binding var insertAfter: Bool
    func validateDrop(info:DropInfo) -> Bool {
        info.hasItemsConforming(to:[ShelfCategoryDrag.type]) ? allowsReorder:info.hasItemsConforming(to:[UTType.plainText.identifier])
    }
    func dropEntered(info:DropInfo) { updateTarget(info) }
    func dropUpdated(info:DropInfo) -> DropProposal? {
        updateTarget(info)
        return DropProposal(operation:info.hasItemsConforming(to:[ShelfCategoryDrag.type]) ? .move:.copy)
    }
    private func updateTarget(_ info:DropInfo) {
        if info.hasItemsConforming(to:[ShelfCategoryDrag.type]), allowsReorder {
            categoryTarget = target; insertAfter = info.location.y > 22
        } else { bookTarget = target }
    }
    func dropExited(info:DropInfo) {
        if categoryTarget == target { categoryTarget = nil }
        if bookTarget == target { bookTarget = nil }
    }
    func performDrop(info:DropInfo) -> Bool {
        let library = store, destination = target
        let after = info.location.y > 22
        defer { categoryTarget = nil; bookTarget = nil }
        if info.hasItemsConforming(to:[ShelfCategoryDrag.type]) {
            guard allowsReorder, let provider = info.itemProviders(for:[ShelfCategoryDrag.type]).first else { return false }
            provider.loadDataRepresentation(forTypeIdentifier:ShelfCategoryDrag.type) { data,_ in
                guard let data, let text = String(data:data,encoding:.utf8), let source = UUID(uuidString:text) else { return }
                Task { @MainActor in library.moveCollection(source,to:destination,after:after) }
            }
            return true
        }
        let providers = info.itemProviders(for:[UTType.plainText.identifier])
        for provider in providers {
            provider.loadObject(ofClass:NSString.self) { object,_ in
                guard let text = object as? String else { return }
                Task { @MainActor in _ = library.acceptBookDrop([text],groupID:destination) }
            }
        }
        return !providers.isEmpty
    }
}
