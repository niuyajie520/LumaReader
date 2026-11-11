import Foundation

/// Device-local settings never overwrite progress, notes or synced book content.
struct BookReadingPreferences: Codable, Equatable, Sendable {
    var font: String
    var size: Double
    var width: Double
    var lineHeight: Double
    var paragraphSpacing: Double
    var indent: Bool
    var theme: String
    var appearance: String
    var monetEnabled: Bool
    var monetSource: String
    var monetStyle: String
    var monetSeed: Int
    var monetLocked: Bool
    var pageTurnStyle: String
    var pageTurnAnimation: Bool
    var customFont: String? = nil
    var pageTurnSpeed: String? = nil
}
struct BookReadingPreferencesArchive: Codable, Equatable, Sendable {
    var defaults: BookReadingPreferences
    var books: [String:BookReadingPreferences] = [:]
    func value(for bookID: UUID?, perBook: Bool) -> BookReadingPreferences {
        perBook ? bookID.flatMap { books[$0.uuidString] } ?? defaults:defaults
    }
    mutating func record(_ value: BookReadingPreferences, for bookID: UUID?, perBook: Bool) {
        if perBook, let bookID { books[bookID.uuidString] = value } else { defaults = value }
    }
}

@MainActor extension LibraryStore {
    var currentReadingPreferences: BookReadingPreferences {
        BookReadingPreferences(font:readerFontFamily.rawValue,size:readerSize,width:readerWidth,
                               lineHeight:readerLineHeight,paragraphSpacing:readerParagraphSpacing,indent:readerIndent,
                               theme:theme.rawValue,appearance:appearance.rawValue,monetEnabled:monetEnabled,
                               monetSource:monetSource.rawValue,monetStyle:monetStyle.rawValue,monetSeed:monetSeed,
                               monetLocked:monetLocked,pageTurnStyle:pageTurnStyle.rawValue,pageTurnAnimation:pageTurnAnimation,customFont:readerCustomFont.isEmpty ? nil:readerCustomFont,pageTurnSpeed:pageTurnSpeed.rawValue)
    }
    func loadReadingPreferences() {
        let url = root.appendingPathComponent("reading-preferences.json")
        if FileManager.default.fileExists(atPath:url.path) {
            do { readingPreferencesArchive = try JSONDecoder().decode(BookReadingPreferencesArchive.self,from:Data(contentsOf:url)) }
            catch {
                // Preserve unreadable preferences rather than silently overwriting them.
                readingPreferencesWritable = false
                self.error = "阅读设置未能读取，已保留原文件："+error.localizedDescription
                readingPreferencesArchive = .init(defaults:currentReadingPreferences)
            }
        } else { readingPreferencesArchive = .init(defaults:currentReadingPreferences) }
    }
    func readingPreferencesDidChange() {
        guard !applyingReadingPreferences, var archive = readingPreferencesArchive else { return }
        let value = currentReadingPreferences
        archive.record(value,for:selectedID,perBook:perBookReadingSettings)
        guard archive != readingPreferencesArchive else { return }
        readingPreferencesArchive = archive; readingPreferencesDirty = true
        readingPreferencesSaveTask?.cancel()
        readingPreferencesSaveTask = Task { [weak self] in
            do { try await Task.sleep(for:.milliseconds(450)) } catch { return }
            self?.flushReadingPreferences()
        }
    }
    func flushReadingPreferences() {
        readingPreferencesSaveTask?.cancel(); readingPreferencesSaveTask = nil
        guard readingPreferencesDirty, readingPreferencesWritable, let archive = readingPreferencesArchive else { return }
        do {
            try JSONEncoder().encode(archive).write(to:root.appendingPathComponent("reading-preferences.json"),options:.atomic)
            readingPreferencesDirty = false
        } catch { self.error = "阅读设置保存失败："+error.localizedDescription }
    }
    func restoreReadingPreferences(for bookID: UUID?, preservingTheme: BookReadingPreferences? = nil) {
        guard let archive = readingPreferencesArchive else { return }
        let value = archive.value(for:bookID,perBook:perBookReadingSettings)
        let color = preservingTheme ?? value
        applyingReadingPreferences = true
        readerCustomFont = value.customFont ?? ""
        readerFontFamily = LumaFontFamily(rawValue:value.font) ?? .serif
        readerSize = value.size.isFinite ? min(30,max(15,value.size)):19
        readerWidth = value.width.isFinite ? min(900,max(480,value.width)):680
        readerLineHeight = value.lineHeight.isFinite ? min(2.6,max(1.2,value.lineHeight)):1.75
        readerParagraphSpacing = value.paragraphSpacing.isFinite ? min(2.5,max(0,value.paragraphSpacing)):1.35
        readerIndent = value.indent
        theme = ReaderTheme(rawValue:color.theme) ?? .paper
        appearance = Appearance(rawValue:color.appearance) ?? .system
        monetEnabled = color.monetEnabled
        monetSource = MonetSource(rawValue:color.monetSource) ?? .cover
        monetStyle = MonetStyle(rawValue:color.monetStyle) ?? .tonalSpot
        monetSeed = color.monetSeed
        monetLocked = color.monetLocked
        pageTurnStyle = PageTurnStyle(rawValue:value.pageTurnStyle) ?? .slide
        if let rawSpeed = value.pageTurnSpeed, let speed = PageTurnSpeed(rawValue: rawSpeed) {
            pageTurnSpeed = speed
        }
        pageTurnAnimation = value.pageTurnAnimation
        applyingReadingPreferences = false
        refreshResolvedReadingTheme()
    }
    func applyReadingPreferencesToAllBooks() {
        if monetSource == .image, perBookReadingSettings, let id = selectedID {
            let directory = root.appendingPathComponent("ThemeImages",isDirectory:true)
            let source = directory.appendingPathComponent(id.uuidString)
            if FileManager.default.fileExists(atPath:source.path) {
                do { try Data(contentsOf:source).write(to:directory.appendingPathComponent("default"),options:.atomic) }
                catch { self.error = "默认主题图片未能保存："+error.localizedDescription; return }
            }
        }
        readingPreferencesArchive = .init(defaults:currentReadingPreferences)
        readingPreferencesDirty = true; flushReadingPreferences()
    }
    func resetCurrentBookReadingPreferences() {
        guard let id = selectedID, var archive = readingPreferencesArchive else { return }
        archive.books.removeValue(forKey:id.uuidString); readingPreferencesArchive = archive
        readingPreferencesDirty = true; restoreReadingPreferences(for:id); flushReadingPreferences()
    }
}
