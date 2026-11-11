import Foundation
import CryptoKit

/// Immutable, content-addressed files require no destructive conflict resolution.
enum FontFileSync {
    static let maximumBytes = 32 * 1024 * 1024
    static func filename(for data: Data, extension ext: String) throws -> String {
        guard ["ttf","otf"].contains(ext.lowercased()), !data.isEmpty, data.count <= maximumBytes else {
            throw ReaderFailure.message("请选择不超过 32 MB 的 TTF 或 OTF 字体。")
        }
        return SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()+"."+ext.lowercased()
    }
    static func validatedData(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= maximumBytes else {
            throw ReaderFailure.message("字体文件无效或尚未下载完成。")
        }
        let data = try Data(contentsOf:url)
        guard try filename(for:data,extension:url.pathExtension) == url.lastPathComponent else {
            throw ReaderFailure.message("字体完整性检查失败："+url.lastPathComponent)
        }
        return data
    }
    static func exchange(localRoot: URL, cloudRoot: URL) throws {
        let fm = FileManager.default
        let local = localRoot.appendingPathComponent("Fonts",isDirectory:true)
        let cloud = cloudRoot.appendingPathComponent("Fonts",isDirectory:true)
        for folder in [local,cloud] {
            try fm.createDirectory(at:folder,withIntermediateDirectories:true)
            guard (try folder.resourceValues(forKeys:[.isSymbolicLinkKey])).isSymbolicLink != true else {
                throw ReaderFailure.message("字体目录不能是符号链接。")
            }
        }
        for (source,destination) in [(local,cloud),(cloud,local)] {
            let files = try fm.contentsOfDirectory(at:source,includingPropertiesForKeys:nil,options:[.skipsHiddenFiles])
                .filter { ["ttf","otf"].contains($0.pathExtension.lowercased()) }
            for file in files {
                // Validate every downloaded resource before exposing it to font APIs.
                let target = destination.appendingPathComponent(file.lastPathComponent)
                if fm.fileExists(atPath:target.path) { continue }
                let data = try validatedData(at:file)
                try data.write(to:target,options:.atomic)
            }
        }
    }
}
