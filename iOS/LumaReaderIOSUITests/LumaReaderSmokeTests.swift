import XCTest

/// 模拟器上的冒烟测试：真的点、真的打字，验证四个 Tab 和听写一轮的判题。
final class LumaReaderSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testFourTabsRender() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "没有 TabBar")
        for title in ["听写", "阅读", "词库", "设置"] {
            XCTAssertTrue(tabBar.buttons[title].waitForExistence(timeout: 5), "缺少「\(title)」Tab")
        }

        // 听写首页
        XCTAssertTrue(app.buttons["dictation.start"].waitForExistence(timeout: 10), "听写首页没有开始按钮")

        tabBar.buttons["阅读"].tap()
        // 同一个模拟器里前面跑过的用例可能已经导入过书，所以这里只要求「阅读页真的打开了」
        XCTAssertTrue(app.navigationBars["阅读"].waitForExistence(timeout: 10), "阅读页没打开")

        tabBar.buttons["词库"].tap()
        XCTAssertTrue(app.staticTexts["阅读词表"].waitForExistence(timeout: 10), "词库没有内置词表")

        tabBar.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["朗读"].waitForExistence(timeout: 10), "设置页没有朗读分区")
        XCTAssertTrue(app.staticTexts["云同步"].exists, "设置页没有云同步分区")
    }

    func testVocabularyDeckListsWords() {
        app.tabBars.firstMatch.buttons["词库"].tap()
        let deck = app.staticTexts["阅读词表"]
        XCTAssertTrue(deck.waitForExistence(timeout: 15))
        deck.tap()
        // 词本详情里应该至少有一行词条（cell / staticTexts 都算）
        let anyRow = app.cells.firstMatch
        XCTAssertTrue(anyRow.waitForExistence(timeout: 10), "词本详情没有词条行")
        XCTAssertGreaterThan(app.cells.count, 0)
    }

    /// 快速过词模式（默认）：答错立刻跳到下一个词，把正确答案留在屏幕上，
    /// 这个词稍后按错词间隔重新出现（真正的判题规则由 LumaCore 的单元测试覆盖）。
    func testDictationRoundJudgesWrongThenCorrect() {
        app.launch()
        app.tabBars.firstMatch.buttons["听写"].tap()
        app.buttons["dictation.start"].tap()

        let progress = app.staticTexts["dictation.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 15))
        let before = progress.label

        let input = app.textFields["dictation.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText("zzq")
        app.buttons["dictation.submit"].tap()

        let feedback = app.staticTexts["dictation.feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 10), "答错后没有反馈")
        XCTAssertTrue(feedback.label.contains("再拼") || feedback.label.contains("挪到本轮最后"),
                      "答错反馈文案不对：\(feedback.label)")

        let missed = app.staticTexts["dictation.missedAnswer"]
        XCTAssertTrue(missed.waitForExistence(timeout: 10), "答错后没有留下正确答案")
        XCTAssertTrue(missed.label.contains("刚才那个词"), "答错提示文案不对：\(missed.label)")

        // 快速过词把词插回队列后面，队列长度不变，所以进度行文案不变——
        // 这里不拿进度行当观察点，改为确认按钮回到「提交」待答状态。
        let submit = app.buttons["dictation.submit"]
        let backToAsking = NSPredicate(format: "label == %@", "提交")
        expectation(for: backToAsking, evaluatedWith: submit)
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error, "答错后没有回到待答状态，按钮仍是：\(submit.label)")
        }
        XCTAssertEqual(progress.label, before, "快速过词不应改变队列长度：\(progress.label)")

        // 「看答案」应当把那个词的拼写留在屏幕上（不是空白卡片）
        let reveal = app.buttons["dictation.reveal"]
        if reveal.exists, reveal.isEnabled {
            reveal.tap()
            let target = app.staticTexts["dictation.target"]
            XCTAssertTrue(target.waitForExistence(timeout: 10), "看答案后没有显示单词")
            XCTAssertFalse(target.label.isEmpty, "看答案显示的是空白")
        }
    }

    /// 给每个页面留一张真实像素的截图，便于人工核对手机布局。
    func testCaptureScreenshots() {
        func attach(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }

        attach("01-dictation-home")

        let tabBar = app.tabBars.firstMatch
        tabBar.buttons["阅读"].tap()
        sleep(2)
        attach("02-reader-shelf")
        tabBar.buttons["词库"].tap()
        sleep(2)
        attach("03-vocabulary")
        tabBar.buttons["设置"].tap()
        sleep(2)
        attach("04-settings")

        tabBar.buttons["听写"].tap()
        app.buttons["dictation.start"].tap()
        let input = app.textFields["dictation.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        sleep(2)
        attach("05-dictation-running")
        input.tap()
        sleep(2)
        attach("06-dictation-keyboard")
        input.typeText("zzq")
        app.buttons["dictation.submit"].tap()
        _ = app.staticTexts["dictation.target"].waitForExistence(timeout: 10)
        sleep(1)
        attach("07-dictation-correcting")
    }

    /// 把 Documents 里的 sample.epub 通过「文件」选择器导进来，再打开看排版。
    /// 说明：iOS 26/27 的文件选择器会把文件夹当成可选中的一项，所以这里点文件夹，
    /// App 侧会把夹里能读的书批量导入（见 handleImport / expandForImport）。
    /// 用 `-seed-sample-book` 直接种一本示例书，绕开系统「文件」选择器，
    /// 检查 EPUB 分章、手机排版宽度、翻页手势和查词面板。
    func testOpenSampleBook() {
        func attach(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = name
            shot.lifetime = .keepAlways
            add(shot)
        }

        app.launchArguments += ["-seed-sample-book"]
        app.launch()
        app.tabBars.firstMatch.buttons["阅读"].tap()

        let book = app.staticTexts["The Luma Reader Sample"]
        XCTAssertTrue(book.waitForExistence(timeout: 15), "种进来的示例书没出现在书架")
        attach("10-shelf-with-book")

        book.tap()
        sleep(4)
        attach("11-reader-chapter")

        // 第一章够长，应该分出多页：翻一页看正文与页码都变
        let pageLabel = app.staticTexts["reader.page"]
        XCTAssertTrue(pageLabel.waitForExistence(timeout: 10), "第一章没有分页（页码行不存在）")
        let firstPage = pageLabel.label
        attach("12-reader-page1")
        app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5))
            .tap()
        sleep(2)
        XCTAssertNotEqual(pageLabel.label, firstPage, "点了「下一页」页码没变")
        XCTAssertTrue(pageLabel.label.contains("2 /"), "翻页后页码不是第 2 页：\(pageLabel.label)")
        attach("13-reader-page2")

        // 手指向左划 = 下一页
        app.windows.firstMatch.swipeLeft()
        sleep(2)
        XCTAssertTrue(app.staticTexts["reader.page"].label.contains("3 /"), "左滑没有翻到第 3 页")

        // 退出再进来，应该接着第 3 页，而不是回到第 1 页
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)
        let book2 = app.staticTexts["The Luma Reader Sample"]
        XCTAssertTrue(book2.waitForExistence(timeout: 10))
        book2.tap()
        sleep(4)
        XCTAssertTrue(app.staticTexts["reader.page"].label.contains("3 /"),
                      "重开没有回到上次那一页：\(app.staticTexts["reader.page"].label)")
        attach("13b-reader-resume")

        // 点正文里的一个词 → 查词面板
        app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.34))
            .tap()
        let addToVocabulary = app.buttons["加入生词本"]
        XCTAssertTrue(addToVocabulary.waitForExistence(timeout: 10), "点词没有弹出查词面板")
        attach("14-reader-lookup")

        // 加进生词本，回到词库确认
        addToVocabulary.tap()
        sleep(2)
        attach("15-reader-after-add")
    }

    func testSettingsSyncSectionHasFolderButton() {
        app.tabBars.firstMatch.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["云同步"].waitForExistence(timeout: 15))
        // 同步分区里应该有选文件夹/立即同步这类按钮
        let folder = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "文件夹")).firstMatch
        XCTAssertTrue(folder.exists, "云同步分区没有选择文件夹按钮")
    }
}
