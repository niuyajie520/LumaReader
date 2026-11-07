import AppKit
import ObjectiveC

@MainActor
enum NativeWindowControls {
    private static var stateKey: UInt8 = 0
    private final class VisibilityState: NSObject {
        var visible: Bool?
        var revision = 0
    }
    static func restore(_ window: NSWindow, controlsVisible: Bool = true, animated: Bool = false) {
        if !window.styleMask.contains(.fullScreen) {
            window.collectionBehavior.insert(.fullScreenPrimary)
        }
        window.isMovable = true
        let effectiveVisible = window.styleMask.contains(.fullScreen) ? true : controlsVisible
        let state: VisibilityState
        if let existing = objc_getAssociatedObject(window, &stateKey) as? VisibilityState { state = existing }
        else { state = VisibilityState(); objc_setAssociatedObject(window, &stateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
        guard !animated || state.visible != effectiveVisible else { return }
        state.visible = effectiveVisible; state.revision += 1
        let revision = state.revision
        let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { window.standardWindowButton($0) }
        for button in buttons {
            if effectiveVisible {
                button.isHidden = false
                // macOS may disable a standard titlebar button while it is hidden.
                // Re-enable it when revealed; window/menu actions remain NSWindow-owned.
                if window.attachedSheet == nil { button.isEnabled = true }
            }
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = effectiveVisible ? 0.20 : 0.16
                for button in buttons { button.animator().alphaValue = effectiveVisible ? 1 : 0 }
            } completionHandler: { [weak window] in
                MainActor.assumeIsolated {
                    guard let window,
                          let current = objc_getAssociatedObject(window, &stateKey) as? VisibilityState,
                          current.revision == revision else { return }
                    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                        window.standardWindowButton(type)?.alphaValue = current.visible == true ? 1 : 0
                        window.standardWindowButton(type)?.isHidden = current.visible != true
                    }
                }
            }
        } else {
            for button in buttons { button.alphaValue = effectiveVisible ? 1 : 0; button.isHidden = !effectiveVisible }
        }
    }
}
