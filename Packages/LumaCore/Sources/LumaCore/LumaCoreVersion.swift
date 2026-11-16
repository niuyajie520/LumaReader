import Foundation

/// 内核版本号。规则一旦改动（阶梯、间隔、判题、合并顺序）就要在这里 +1，
/// 并同步更新 spec/ 下的行为快照，让 iOS / Android 的移植知道该对照哪一版。
public enum LumaCoreVersion {
    public static let specification = "2"
}
