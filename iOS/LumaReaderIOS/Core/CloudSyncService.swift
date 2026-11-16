import Foundation
import Observation
import UIKit

/// 云同步：用 iCloud Drive（或任何「文件」App 里的目录）当共享盘。
/// 每台设备各写一个 `device-<id>.json`，同步时把所有设备文件合并进来再写回，
/// 这样两端同时学习也不会互相覆盖。
@Observable
final class CloudSyncService {

    private let bookmarkKey = "luma.ios.syncFolderBookmark"
    private let deviceKey = "luma.ios.deviceID"
    private let lastSyncKey = "luma.ios.lastSyncAt"

    private(set) var folderURL: URL?
    private(set) var lastSyncedAt: Date?
    private(set) var statusMessage: String = ""
    private(set) var isSyncing = false
    private var scopedAccess = false

    var folderName: String { folderURL?.lastPathComponent ?? "" }
    var isConfigured: Bool { folderURL != nil }

    var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: deviceKey) { return existing }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let short = String(id.replacingOccurrences(of: "-", with: "").prefix(10)).lowercased()
        UserDefaults.standard.set(short, forKey: deviceKey)
        return short
    }

    init() {
        lastSyncedAt = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        restoreFolder()
    }

    deinit {
        if scopedAccess { folderURL?.stopAccessingSecurityScopedResource() }
    }

    // MARK: 目录授权

    func chooseFolder(_ url: URL) {
        if scopedAccess { folderURL?.stopAccessingSecurityScopedResource() }
        let granted = url.startAccessingSecurityScopedResource()
        scopedAccess = granted
        folderURL = url
        if let data = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
        statusMessage = "已连接「\(url.lastPathComponent)」"
    }

    func restoreFolder() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else { return }
        if stale { chooseFolder(url); return }
        scopedAccess = url.startAccessingSecurityScopedResource()
        folderURL = url
    }

    func disconnect() {
        if scopedAccess { folderURL?.stopAccessingSecurityScopedResource() }
        scopedAccess = false
        folderURL = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        statusMessage = "已断开同步文件夹"
    }

    // MARK: 同步

    @MainActor
    func sync(with store: StudyStore) {
        guard let folder = folderURL else {
            statusMessage = "还没有选择同步文件夹。"
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        let fileManager = FileManager.default
        let merged = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let remotes = merged.filter { $0.lastPathComponent.hasPrefix("device-") && $0.pathExtension == "json" }

        var incoming = 0
        for url in remotes {
            // 自己的文件跳过，避免自我合并后无限追加日志。
            if url.lastPathComponent == "device-\(deviceID).json" { continue }
            guard let data = try? Data(contentsOf: url),
                  let snapshot = StudyStore.decodeSnapshot(data) else { continue }
            store.mergeRemote(words: snapshot.words, schedule: snapshot.schedule, logs: snapshot.logs, stubborn: snapshot.stubborn)
            incoming += 1
        }

        if let data = store.rawSnapshotData {
            let target = folder.appendingPathComponent("device-\(deviceID).json")
            do {
                try data.write(to: target, options: .atomic)
            } catch {
                statusMessage = "写入共享文件失败：\(error.localizedDescription)"
                return
            }
        }

        lastSyncedAt = Date()
        UserDefaults.standard.set(lastSyncedAt, forKey: lastSyncKey)
        statusMessage = incoming > 0 ? "已与 \(incoming) 台设备合并" : "已上传本机进度"
    }
}
