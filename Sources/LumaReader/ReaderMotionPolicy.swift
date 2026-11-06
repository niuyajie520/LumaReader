import Foundation

enum ReaderMotionPolicy {
    static func commitsDrag(progress: Double, velocity: Double) -> Bool {
        if velocity < -220 { return false }
        return progress >= 0.32 || velocity > 420
    }
    static func pageTurnDuration(enabled:Bool,reduceMotion:Bool,systemLowPower:Bool,energySaving:Bool) -> Double {
        guard enabled, !reduceMotion, !systemLowPower, !energySaving else { return 0 }
        return 0.30
    }
}
