import Foundation
#if canImport(SwiftUI)
import SwiftUI
import AppKit
#endif

// All annotations use stable book IDs. EPUB locations are chapter-local UTF-16 offsets.
enum Ink: String, Codable, CaseIterable, Identifiable, Sendable {
    case yellow, green, blue, purple, pink, orange
    var id: String { rawValue }
    var title: String {
        switch self {
        case .yellow: return "暖黄"
        case .green: return "薄荷绿"
        case .blue: return "天空蓝"
        case .purple: return "薰衣草紫"
        case .pink: return "玫瑰粉"
        case .orange: return "杏橙"
        }
    }
    var hex: String {
        switch self {
        case .yellow: return "E9BE42"
        case .green: return "6AAF89"
        case .blue: return "699BD3"
        case .purple: return "A58ACB"
        case .pink: return "D78EA6"
        case .orange: return "D99763"
        }
    }
    #if canImport(SwiftUI)
    var nsColor: NSColor {
        let value = UInt32(hex, radix: 16) ?? 0
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }
    var color: Color { Color(nsColor: nsColor) }
    #endif
}

enum LumaFontFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case serif = "serif"
    case sans = "sans"
    case rounded = "rounded"
    case monospaced = "mono"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serif: return "人文衬线"
        case .sans: return "现代无衬线"
        case .rounded: return "温润圆体"
        case .monospaced: return "等宽手稿"
        }
    }

    var shortTitle: String {
        switch self {
        case .serif: return "衬线"
        case .sans: return "无衬线"
        case .rounded: return "圆体"
        case .monospaced: return "等宽"
        }
    }

    #if canImport(SwiftUI)
    var design: Font.Design {
        switch self {
        case .serif: return .serif
        case .sans: return .default
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        }
    }

    #endif
    var cssStack: String {
        switch self {
        case .serif:
            return "'New York','Iowan Old Style','Songti SC',serif"
        case .sans:
            return "-apple-system,'SF Pro Text','PingFang SC','Hiragino Sans GB',sans-serif"
        case .rounded:
            return "ui-rounded,'SF Pro Rounded','PingFang SC',sans-serif"
        case .monospaced:
            return "ui-monospace,'SF Mono','Menlo','PingFang SC',monospace"
        }
    }

    #if canImport(SwiftUI)
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: design)
    }

    #endif
    // Size-specific optical tracking per apple-design §15 & motion-web page-design §4.
    static func opticalTracking(for size: CGFloat) -> CGFloat {
        if size >= 26 { return -size * 0.022 }
        if size >= 18 { return -size * 0.01 }
        if size <= 11 { return 0.15 }
        return 0
    }
}

enum CloudProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case iCloud = "icloud"
    case oneDrive = "onedrive"
    case googleDrive = "googledrive"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iCloud: return "iCloud Drive"
        case .oneDrive: return "OneDrive"
        case .googleDrive: return "Google Drive"
        }
    }

    var shortTitle: String {
        switch self {
        case .iCloud: return "iCloud"
        case .oneDrive: return "OneDrive"
        case .googleDrive: return "Google Drive"
        }
    }

    var symbol: String {
        switch self {
        case .iCloud: return "icloud"
        case .oneDrive: return "cloud"
        case .googleDrive: return "externaldrive.badge.icloud"
        }
    }

    func candidateDirectories(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let fm = FileManager.default
        let cloudStorage = home.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        let storageEntries = (try? fm.contentsOfDirectory(at: cloudStorage, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        switch self {
        case .iCloud:
            return [
                home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/LumaReader", isDirectory: true),
                home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
            ]
        case .oneDrive:
            let matches = storageEntries.filter { $0.lastPathComponent.lowercased().hasPrefix("onedrive") }
            return matches + [home.appendingPathComponent("OneDrive", isDirectory: true)]
        case .googleDrive:
            var urls: [URL] = []
            for entry in storageEntries where entry.lastPathComponent.lowercased().hasPrefix("googledrive") {
                urls.append(entry.appendingPathComponent("My Drive", isDirectory: true))
                urls.append(entry.appendingPathComponent("我的云端硬盘", isDirectory: true))
                urls.append(entry)
            }
            urls.append(home.appendingPathComponent("Google Drive", isDirectory: true))
            return urls
        }
    }

    func discoverDefaultDirectory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        let fm = FileManager.default
        for candidate in candidateDirectories(home: home) {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                return candidate
            }
        }
        return nil
    }
}

struct CloudDriveState: Codable, Equatable, Identifiable, Sendable {
    var provider: CloudProvider
    var isConnected: Bool = false
    var folderPath: String = ""
    var lastSynced: Date? = nil
    var syncedBookCount: Int = 0
    var id: String { provider.rawValue }
}

struct PageRect: Codable, Equatable, Sendable {
    var page: Int
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct ReadingNote: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var quote: String
    var note = ""
    var ink: Ink
    // Optional for backward-compatible decoding of existing and cloud notes.
    var colorHex: String? = nil
    var highlightHex: String {
        guard let colorHex, colorHex.count == 6, UInt32(colorHex, radix:16) != nil else { return ink.hex }
        return colorHex
    }
    var modifiedAt: Date? = nil
    var created = Date()
    var chapter = 0
    var start: Int? = nil
    var end: Int? = nil
    var rects: [PageRect] = []
}

struct Book: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var author = ""
    var filename: String
    var kind: String
    var position = 0
    var progress = 0.0
    var lastOpened = Date()
    var notes: [ReadingNote] = []
    var shelf: ShelfBookPreferences? = nil
    var coverFilename: String? = nil
    var cloudProvider: CloudProvider? = nil
    var progressUpdatedAt: Date? = nil
    var readerOffset: Double? = nil
    var readerAnchor: ReaderTextAnchor? = nil
    var bookmarks: [ReadingBookmark]? = nil
    var deletedNotes: [String: Date]? = nil
    var deletedBookmarks: [String: Date]? = nil
}

struct Chapter: Identifiable, Sendable {
    var id: Int
    var title: String
    var url: URL
}

struct ReadingBookmark: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var position: Int
    var offset: Double? = nil
    var anchor: ReaderTextAnchor? = nil
    var created = Date()
}

enum Appearance: String, CaseIterable, Sendable {
    case system = "跟随系统", light = "浅色", dark = "深色"
    #if canImport(SwiftUI)
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
    #endif
}

enum ReaderFailure: LocalizedError, Sendable {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
