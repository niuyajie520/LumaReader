import AppKit
import Foundation
import Testing
@testable import LumaReader

struct CollectionDisplayOrderTests {
    @MainActor @Test func nativeControlsHideAndRecoverWithoutChangingWindowGeometry() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect:NSRect(x:100,y:100,width:940,height:720),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let frame = window.frame
        NativeWindowControls.restore(window,controlsVisible:false)
        for type in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton] {
            #expect(window.standardWindowButton(type)?.isHidden == true)
            #expect(window.standardWindowButton(type)?.isEnabled == true)
        }
        let hidden = NativeWindowControls.snapshot(window)
        for name in ["closeHitTarget","minimizeHitTarget","zoomHitTarget"] { #expect(hidden[name] == false) }
        NativeWindowControls.restore(window,controlsVisible:true)
        for type in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton] {
            #expect(window.standardWindowButton(type)?.isHidden == false)
            #expect(window.standardWindowButton(type)?.isEnabled == true)
        }
        #expect(window.frame == frame)
        #expect(window.styleMask.contains(.resizable))
    }

    @MainActor @Test func categoryDragUsesItsOwnNativePayload() async throws {
        let id = UUID(), provider = ShelfCategoryDrag.provider(UUID())
        #expect(provider.hasItemConformingToTypeIdentifier(ShelfCategoryDrag.type))
        #expect(!provider.hasItemConformingToTypeIdentifier("public.plain-text"))
        let item = ShelfCategoryDrag.provider(id)
        let data = try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Data,Error>) in
            item.loadDataRepresentation(forTypeIdentifier:ShelfCategoryDrag.type) { data,error in
                if let data { continuation.resume(returning:data) }
                else { continuation.resume(throwing:error ?? CocoaError(.fileReadUnknown)) }
            }
        }
        #expect(String(decoding:data,as:UTF8.self) == id.uuidString)
    }
    @MainActor @Test func toolbarSensorNeverParticipatesInHitTesting() {
        let sensor = ReaderChromeMonitor.MonitorView()
        #expect(sensor.hitTest(.zero) == nil)
        #expect(sensor.hitTest(NSPoint(x:40,y:40)) == nil)
    }
    @Test func reorderingChangesOnlyDisplayOrderAndPersists() throws {
        var groups = LibraryGroups()
        let a = try groups.create("Fixture A"), b = try groups.create("Fixture B"), c = try groups.create("Fixture C")
        let book = UUID(); groups.set(book:book,in:a,included:true)
        let original = groups
        let order = CollectionDisplayOrder.moving(a,to:c,after:true,groups:groups.groups,saved:[])
        #expect(CollectionDisplayOrder.sorted(groups.groups,saved:order).map(\.id) == [b,c,a])
        #expect(groups == original)
        let suite = "LumaCategoryFixture."+UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName:suite)); defer { defaults.removePersistentDomain(forName:suite) }
        defaults.set(order,forKey:"collectionDisplayOrder")
        let reopened = try #require(UserDefaults(suiteName:suite))
        #expect(CollectionDisplayOrder.sorted(groups.groups,saved:reopened.stringArray(forKey:"collectionDisplayOrder") ?? []).map(\.id) == [b,c,a])
    }
    @Test func unknownAndDuplicateIDsDoNotLoseNewCategories() throws {
        var groups = LibraryGroups(); let a = try groups.create("Fixture A"), b = try groups.create("Fixture B")
        let saved = [UUID().uuidString,b.uuidString,b.uuidString]
        #expect(CollectionDisplayOrder.sorted(groups.groups,saved:saved).map(\.id) == [b,a])
        #expect(CollectionDisplayOrder.moving(UUID(),to:a,after:false,groups:groups.groups,saved:saved) == saved)
        groups.remove(b)
        #expect(CollectionDisplayOrder.sorted(groups.groups,saved:saved).map(\.id) == [a])
    }
}
