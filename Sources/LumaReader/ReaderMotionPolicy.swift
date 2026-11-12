import Foundation

/// Page-turn motion and gesture arbitration policy.
///
/// Open-source provenance & references:
/// - **Readest** (`https://github.com/readest/readest`, PR #4940 & Issue #5288):
///   Continuous distance + release velocity commit rule and velocity-modulated settle duration.
/// - **StPageFlip** (`https://github.com/Nodlik/StPageFlip`, v2.0.7, MIT License):
///   Swipe distance / velocity threshold and corner fold settle timing.
enum ReaderMotionPolicy {
    /// Determines whether an interactive edge drag or swipe should commit to a page turn
    /// or spring back to the current page.
    ///
    /// Preserves reverse-flick cancellation (`velocity < -220`), full-drag commit (`progress >= 0.32`),
    /// fast-flick commit (`velocity > 420`), and Readest #5288's continuous distance + velocity
    /// combination (`progress >= 0.08 && progress + velocity / 1600.0 >= 0.34`).
    static func commitsDrag(progress: Double, velocity: Double) -> Bool {
        guard progress.isFinite, velocity.isFinite else { return false }
        if velocity < -220 { return false }
        if progress >= 0.32 || velocity > 420 { return true }
        if progress >= 0.08 && (progress + max(0, velocity) / 1600.0) >= 0.34 {
            return true
        }
        return false
    }

    /// Base page-turn duration (in seconds) before speed scaling (`PageTurnSpeed.scale`).
    static func pageTurnDuration(enabled: Bool, reduceMotion: Bool, systemLowPower: Bool, energySaving: Bool) -> Double {
        guard enabled, !reduceMotion else { return 0 }
        // Power saving keeps the page-turn animation but shortens it.
        return (systemLowPower || energySaving) ? 0.18 : 0.30
    }

    /// Mode-specific duration multiplier so 3D curl and spine flip have natural physical weight
    /// while slide, push, and fade remain crisp.
    static func styleDuration(base: Double, style: PageTurnStyle, speedScale: Double, motionLevel: VisualMotionLevel, isChainedRapidTurn: Bool = false) -> Double {
        guard base > 0, style != .none, motionLevel != .off else { return 0 }
        let modeFactor: Double
        switch style {
        case .slide:
            modeFactor = 1.0
        case .push:
            modeFactor = 0.96
        case .curl, .paperFlip:
            modeFactor = motionLevel == .enhanced ? 1.48 : 1.15
        case .flip:
            modeFactor = motionLevel == .enhanced ? 1.28 : 1.08
        case .fade:
            modeFactor = 0.85
        case .none:
            return 0
        }
        let scaled = base * modeFactor * speedScale
        if isChainedRapidTurn {
            return min(scaled * 0.58, 0.18)
        }
        return scaled
    }

    /// Velocity-modulated settle duration for completing or cancelling an interactive drag
    /// (adapted from Readest Issue #5288 release velocity settle rule).
    static func interactiveSettleDuration(baseDuration: Double, currentProgress: Double, velocity: Double, commit: Bool) -> Double {
        guard baseDuration > 0 else { return 0 }
        let clampedProgress = min(1, max(0, currentProgress))
        let remaining = commit ? (1.0 - clampedProgress) : clampedProgress
        let distanceFactor = max(0.35, min(1.0, sqrt(max(0.05, remaining))))
        let speedBoost = min(1.8, max(1.0, abs(velocity) / 900.0))
        let raw = (commit ? baseDuration : min(baseDuration, 0.24)) * distanceFactor / speedBoost
        return min(max(0.10, raw), baseDuration)
    }
}
