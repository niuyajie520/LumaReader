import XCTest
@testable import LumaReaderStudyKit

/// 回归：文件夹拖拽移动后的路径解析。
/// 旧实现只应用第一条匹配规则就 break，连续移动或移动子文件夹后会出现
/// “旧位置仍显示、新位置又出现一份”的错乱；这里锁定修复后的语义。
final class FinderPathResolutionTests: XCTestCase {

    private func resolve(_ path: [String], _ redirects: [String: String]) -> [String] {
        LumaFinderPath.resolve(path, rules: LumaFinderPath.rules(from: redirects))
    }

    func testNoMovesKeepsPath() {
        XCTAssertEqual(resolve(["Part 1", "租房场景", "01_租房场景词汇"], [:]),
                       ["Part 1", "租房场景", "01_租房场景词汇"])
    }

    func testMoveFolderIntoAnotherFolder() {
        let redirects = ["Part 1/租房场景": "Part 1/新文件夹/租房场景"]
        XCTAssertEqual(resolve(["Part 1", "租房场景"], redirects),
                       ["Part 1", "新文件夹", "租房场景"])
        XCTAssertEqual(resolve(["Part 1", "租房场景", "01_租房场景词汇"], redirects),
                       ["Part 1", "新文件夹", "租房场景", "01_租房场景词汇"])
    }

    func testChainedMoveFollowsNewLocation() {
        let redirects = [
            "Part 1/租房场景": "Part 1/新文件夹/租房场景",
            "Part 1/新文件夹/租房场景": "Part 2/归档/租房场景"
        ]
        XCTAssertEqual(resolve(["Part 1", "租房场景", "01_租房场景词汇"], redirects),
                       ["Part 2", "归档", "租房场景", "01_租房场景词汇"])
    }

    func testMovingChildAfterParentMoves() {
        let redirects = [
            "Part 1/租房场景": "Part 1/新文件夹/租房场景",
            "Part 1/新文件夹/租房场景/01_租房场景词汇": "Part 3/01_租房场景词汇"
        ]
        XCTAssertEqual(resolve(["Part 1", "租房场景", "01_租房场景词汇"], redirects),
                       ["Part 3", "01_租房场景词汇"])
    }

    func testMovingFolderBackRestoresOriginalPath() {
        let redirects = [
            "Part 1/租房场景": "Part 1/新文件夹/租房场景",
            "Part 1/新文件夹/租房场景": "Part 1/租房场景"
        ]
        XCTAssertEqual(resolve(["Part 1", "租房场景"], redirects), ["Part 1", "租房场景"])
        XCTAssertEqual(resolve(["Part 1", "租房场景", "01_租房场景词汇"], redirects),
                       ["Part 1", "租房场景", "01_租房场景词汇"])
    }

    func testLongestPrefixWins() {
        let redirects = [
            "Part 1": "Part 2/Part 1",
            "Part 1/租房场景": "Part 3/租房场景"
        ]
        XCTAssertEqual(resolve(["Part 1", "租房场景", "01_租房场景词汇"], redirects),
                       ["Part 3", "租房场景", "01_租房场景词汇"])
        XCTAssertEqual(resolve(["Part 1", "工作场景"], redirects),
                       ["Part 2", "Part 1", "工作场景"])
    }

    func testMovedCategoryNoLongerResolvesToOldShell() {
        let redirects = ["雅思王语料库": "Part 4/雅思王语料库"]
        XCTAssertEqual(resolve(["雅思王语料库"], redirects), ["Part 4", "雅思王语料库"])
        XCTAssertNotEqual(resolve(["雅思王语料库"], redirects), ["雅思王语料库"])
    }
}
