import Foundation
import Compression

/// 解压后的单个条目。
struct ZipEntry {
    let path: String
    let data: Data
}

enum MiniZipError: LocalizedError {
    case notZip
    case corruptArchive
    case unsupportedCompression

    var errorDescription: String? {
        switch self {
        case .notZip:
            return "这不是一个有效的 ZIP 文件。"
        case .corruptArchive:
            return "压缩包已损坏，或包含暂不支持的 ZIP64 结构。"
        case .unsupportedCompression:
            return "压缩包使用了不支持的压缩方式。"
        }
    }
}

/// 只依赖 Foundation 与 Compression 的最小 ZIP 读取器。
/// 支持 stored（0）与 deflate（8），并兼容带 data descriptor 的条目。
enum MiniZip {

    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let centralDirectorySignature: UInt32 = 0x0201_4B50
    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let maxEntryCount = 100_000
    private static let maxInflatedSize = 512 * 1024 * 1024

    // MARK: - 入口

    static func unzip(fileURL: URL) throws -> [String: Data] {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        return try unzip(data)
    }

    /// 解压整个 zip，返回「条目路径 → 内容」。
    static func unzip(_ archive: Data) throws -> [String: Data] {
        guard archive.count >= 22 else { throw MiniZipError.notZip }

        let endOffset = try locateEndOfCentralDirectory(in: archive)
        let diskNumber = u16(archive, endOffset + 4)
        let directoryDisk = u16(archive, endOffset + 6)
        guard diskNumber == 0, directoryDisk == 0 else { throw MiniZipError.corruptArchive }

        let entryCount = Int(u16(archive, endOffset + 10))
        let directorySize = Int(u32(archive, endOffset + 12))
        let directoryOffset = Int(u32(archive, endOffset + 16))

        guard entryCount != 0xFFFF,
              directoryOffset != 0xFFFF_FFFF,
              entryCount >= 0,
              entryCount <= maxEntryCount,
              directoryOffset >= 0,
              directoryOffset <= archive.count,
              directoryOffset + directorySize <= archive.count else {
            throw MiniZipError.corruptArchive
        }
        guard entryCount > 0 else { return [:] }

        var result: [String: Data] = [:]
        result.reserveCapacity(entryCount)
        var cursor = directoryOffset
        var totalInflated = 0

        for _ in 0..<entryCount {
            guard cursor >= 0, cursor + 46 <= archive.count else { throw MiniZipError.corruptArchive }
            guard u32(archive, cursor) == centralDirectorySignature else { throw MiniZipError.corruptArchive }

            let flags = u16(archive, cursor + 8)
            let method = u16(archive, cursor + 10)
            let compressedSize = Int(u32(archive, cursor + 20))
            let uncompressedSize = Int(u32(archive, cursor + 24))
            let nameLength = Int(u16(archive, cursor + 28))
            let extraLength = Int(u16(archive, cursor + 30))
            let commentLength = Int(u16(archive, cursor + 32))
            let localHeaderOffset = Int(u32(archive, cursor + 42))

            guard compressedSize != 0xFFFF_FFFF,
                  uncompressedSize != 0xFFFF_FFFF,
                  localHeaderOffset != 0xFFFF_FFFF else {
                throw MiniZipError.corruptArchive
            }
            let entryEnd = cursor + 46 + nameLength + extraLength + commentLength
            guard entryEnd <= archive.count else { throw MiniZipError.corruptArchive }

            let nameData = slice(archive, cursor + 46, nameLength)
            let name = String(data: nameData, encoding: .utf8)
                ?? String(data: nameData, encoding: .isoLatin1)
                ?? String(decoding: nameData, as: UTF8.self)
            cursor = entryEnd

            // 目录条目没有内容，直接跳过。
            if name.hasSuffix("/") || name.hasSuffix("\\") { continue }

            // 加密条目暂不支持（bit 0 为传统加密，bit 6 为强加密）。
            // bit 3 是 data descriptor 标记，不能当作加密。
            guard flags & 0x0041 == 0 else { throw MiniZipError.unsupportedCompression }

            let path = normalizedPath(name)
            guard !path.isEmpty else { continue }

            guard localHeaderOffset >= 0, localHeaderOffset + 30 <= archive.count else {
                throw MiniZipError.corruptArchive
            }
            guard u32(archive, localHeaderOffset) == localHeaderSignature else {
                throw MiniZipError.corruptArchive
            }
            let localNameLength = Int(u16(archive, localHeaderOffset + 26))
            let localExtraLength = Int(u16(archive, localHeaderOffset + 28))
            let dataStart = localHeaderOffset + 30 + localNameLength + localExtraLength
            guard dataStart >= 0, dataStart <= archive.count else { throw MiniZipError.corruptArchive }

            // 中央目录里的尺寸始终可信。启用 data descriptor 时本地头尺寸为 0，
            // 这里直接使用中央目录记录，避免依赖 descriptor 的扫描。
            guard compressedSize >= 0, dataStart + compressedSize <= archive.count else {
                throw MiniZipError.corruptArchive
            }
            let payload = slice(archive, dataStart, compressedSize)

            let content: Data
            switch method {
            case 0:
                content = payload
            case 8:
                content = try inflate(payload, expectedSize: uncompressedSize)
            default:
                throw MiniZipError.unsupportedCompression
            }

            totalInflated += content.count
            guard totalInflated <= maxInflatedSize else { throw MiniZipError.corruptArchive }
            result[path] = content
        }

        guard !result.isEmpty else { throw MiniZipError.corruptArchive }
        return result
    }

    // MARK: - 结构定位

    private static func locateEndOfCentralDirectory(in archive: Data) throws -> Int {
        let maximumComment = 65_535
        let minimumOffset = max(0, archive.count - maximumComment - 22)
        var offset = archive.count - 22
        while offset >= minimumOffset {
            if u32(archive, offset) == endOfCentralDirectorySignature {
                let commentLength = Int(u16(archive, offset + 20))
                if offset + 22 + commentLength <= archive.count {
                    return offset
                }
            }
            offset -= 1
        }
        throw MiniZipError.notZip
    }

    // MARK: - Deflate

    private static func inflate(_ payload: Data, expectedSize: Int) throws -> Data {
        guard !payload.isEmpty else {
            if expectedSize == 0 { return Data() }
            throw MiniZipError.corruptArchive
        }

        let initial = max(expectedSize, payload.count * 2, 4_096)
        var capacity = min(max(initial, 1), maxInflatedSize)

        while capacity <= maxInflatedSize {
            var output = [UInt8](repeating: 0, count: capacity)
            let written = output.withUnsafeMutableBytes { destination -> Int in
                payload.withUnsafeBytes { source -> Int in
                    guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress,
                          let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else {
                        return 0
                    }
                    // COMPRESSION_ZLIB 在 Apple 平台上解码的是 raw deflate 数据，
                    // 正好对应 zip 中 method=8 的负载。
                    return compression_decode_buffer(destinationBase, capacity,
                                                     sourceBase, payload.count,
                                                     nil, COMPRESSION_ZLIB)
                }
            }

            if written > 0 {
                return Data(output[0..<written])
            }
            // 空内容也可能只有一个空的 deflate 结束块。
            if expectedSize == 0 {
                return Data()
            }
            if capacity >= maxInflatedSize { break }
            capacity = min(capacity * 2, maxInflatedSize)
        }

        throw MiniZipError.corruptArchive
    }

    // MARK: - 字节读取

    private static func slice(_ data: Data, _ offset: Int, _ length: Int) -> Data {
        guard length > 0 else { return Data() }
        let start = data.startIndex + offset
        return data.subdata(in: start..<(start + length))
    }

    private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { return 0 }
        let base = data.startIndex + offset
        return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
    }

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        let base = data.startIndex + offset
        return UInt32(data[base])
            | (UInt32(data[base + 1]) << 8)
            | (UInt32(data[base + 2]) << 16)
            | (UInt32(data[base + 3]) << 24)
    }

    // MARK: - 路径

    /// 统一分隔符、去掉绝对路径前缀，并解析 `.` 与 `..`，防止越出解压目录。
    private static func normalizedPath(_ raw: String) -> String {
        let replaced = raw.replacingOccurrences(of: "\\", with: "/")
        let components = replaced.split(separator: "/", omittingEmptySubsequences: true)
        var stack: [String] = []
        for component in components {
            switch component {
            case ".":
                continue
            case "..":
                if !stack.isEmpty { stack.removeLast() }
            default:
                stack.append(String(component))
            }
        }
        return stack.joined(separator: "/")
    }
}
