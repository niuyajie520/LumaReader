import SwiftUI
import AppKit
import Observation

struct CloudFileEntry: Identifiable, Sendable {
    var url: URL
    var directory: Bool
    var symbolicLink: Bool
    var bytes: Int64
    var modified: Date?
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

// Only direct children of a connected root may be changed. Resolve symlinks before
// descending so a linked folder cannot turn this browser into an unrestricted one.
enum CloudFileOperations {
    static func checked(_ url: URL, root: URL) throws -> URL {
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        let target = url.resolvingSymlinksInPath().standardizedFileURL
        guard target == base || target.path.hasPrefix(base.path + "/") else {
            throw ReaderFailure.message("该位置不在已连接的云盘目录内。")
        }
        return target
    }
    static func child(_ name: String, in directory: URL, root: URL) throws -> URL {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name != ".", name != "..", !name.contains("/"), !name.contains(":"), !name.contains("\0") else {
            throw ReaderFailure.message("请输入有效的文件名。")
        }
        let parent = try checked(directory, root: root)
        let target = parent.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: target.path),
              (try? target.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
            throw ReaderFailure.message("已有同名文件，请更换名称。")
        }
        return target
    }
    static func entries(in directory: URL, root: URL) throws -> [CloudFileEntry] {
        let directory = try checked(directory, root: root)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        return try urls.map { url in
            let values = try url.resourceValues(forKeys: keys)
            return CloudFileEntry(url: url, directory: values.isDirectory == true,
                                  symbolicLink: values.isSymbolicLink == true,
                                  bytes: Int64(values.fileSize ?? 0), modified: values.contentModificationDate)
        }.sorted {
            if $0.directory != $1.directory { return $0.directory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

@MainActor @Observable
final class CloudFilesModel {
    @ObservationIgnored weak var store: LibraryStore?
    var root: URL?
    var directory: URL?
    var entries: [CloudFileEntry] = []
    var selected: String?
    var query = ""
    var busy = false
    var error: String?
    private var revision = UUID()
    var selection: CloudFileEntry? { entries.first { $0.id == selected } }
    var visible: [CloudFileEntry] { query.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(query) } }

    func connect(_ root: URL) async {
        self.root = root; directory = root; selected = nil; query = ""
        await refresh()
    }
    func refresh() async {
        guard let root, let directory else { return }
        let token = UUID(); revision = token; busy = true
        let result = await Task.detached(priority: .utility) { () -> Result<[CloudFileEntry], Error> in
            let scoped = root.startAccessingSecurityScopedResource()
            defer { if scoped { root.stopAccessingSecurityScopedResource() } }
            return Result { try CloudFileOperations.entries(in: directory, root: root) }
        }.value
        guard token == revision else { return }
        busy = false
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let rows): entries = rows; selected = nil
        case .failure(let failure): entries = []; error = failure.localizedDescription
        }
    }
    func enter(_ entry: CloudFileEntry) async {
        guard !busy, !entry.symbolicLink else { return }
        if entry.directory { directory = entry.url; await refresh() }
        else { NSWorkspace.shared.open(entry.url) }
    }
    /// 从云盘根目录到当前文件夹的每一级，用于面包屑。
    var trail: [URL] {
        guard let root, let directory else { return [] }
        let base = root.standardizedFileURL
        var path: [URL] = [base]
        let rootCount = base.pathComponents.count
        let parts = directory.standardizedFileURL.pathComponents
        guard parts.count > rootCount else { return path }
        var current = base
        for part in parts[rootCount...] {
            current = current.appendingPathComponent(part, isDirectory: true)
            path.append(current)
        }
        return path
    }
    /// 跳到面包屑里的某一级（只允许根目录及其子目录）。
    func go(to url: URL) async {
        guard !busy, let root else { return }
        let base = root.standardizedFileURL.path
        let target = url.standardizedFileURL
        guard target.path == base || target.path.hasPrefix(base + "/") else { return }
        directory = target; selected = nil; await refresh()
    }
    func up() async {
        guard !busy, let root, let directory, directory.standardizedFileURL != root.standardizedFileURL else { return }
        self.directory = directory.deletingLastPathComponent(); await refresh()
    }
    func change(_ operation: @escaping @Sendable (URL, URL) throws -> Void) async {
        guard !busy, store?.isSyncingCloud != true, let root, let directory else { return }
        busy = true
        store?.cloudFileOperationActive = true
        defer { store?.cloudFileOperationActive = false }
        let failure = await Task.detached(priority: .utility) { () -> String? in
            let scoped = root.startAccessingSecurityScopedResource()
            defer { if scoped { root.stopAccessingSecurityScopedResource() } }
            do { try operation(root, directory); return nil }
            catch { return error.localizedDescription }
        }.value
        busy = false
        if let failure { error = failure }
        await refresh()
    }
}

struct CloudFileManagerView: View {
    @Bindable var store: LibraryStore
    @Binding var provider: CloudProvider
    @Binding var expanded: Bool
    var preferredHeight: CGFloat = 320
    @State private var model = CloudFilesModel()
    @State private var showName = false
    @State private var newFolder = false
    @State private var name = ""
    @State private var target: CloudFileEntry?
    @State private var showTrash = false
    @State private var collapseHovered = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var glassActive: Bool { store.effectiveGlassEffectsEnabled && !reduceTransparency }

    private var connected: [CloudProvider] { CloudProvider.allCases.filter { store.cloudStates[$0]?.isConnected == true } }
    var body: some View {
        let palette = store.readingPalette(dark: scheme == .dark)
        VStack(spacing: 10) {
            // 第一行：折叠 · 标题 · 云盘切换 · 项数（只显示一次）· 搜索 · 唯一的「⋯」
            HStack(spacing: 8) {
                Button {
                    var transaction = Transaction(); transaction.disablesAnimations = reduceMotion
                    withTransaction(transaction) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.muted)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: expanded)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(collapseHovered ? palette.accent.opacity(0.12) : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { collapseHovered = $0 }
                .help(L10n.text(expanded ? "折叠云盘文件" : "展开云盘文件"))
                .accessibilityLabel(L10n.text(expanded ? "折叠云盘文件" : "展开云盘文件"))
                .accessibilityValue(L10n.text(expanded ? "已展开" : "已折叠"))

                Text(L10n.text("云盘文件"))
                    .font(store.homeFont(13, weight: .semibold))
                    .foregroundStyle(palette.ink)
                if connected.count > 1 {
                    Picker(L10n.text("云盘"), selection: $provider) { ForEach(connected) { Text($0.title).tag($0) } }
                        .labelsHidden()
                        .frame(width: 148)
                }
                Text("\(model.visible.count) " + L10n.text("项"))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(palette.muted)
                Spacer(minLength: 8)
                if expanded {
                    TextField(L10n.text("搜索当前文件夹"), text: $model.query)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 110, idealWidth: 156, maxWidth: 200)
                    Menu {
                        Button(L10n.text("新建文件夹"), systemImage: "folder.badge.plus") { newFolder = true; target = nil; name = "新建文件夹"; showName = true }
                        Button(L10n.text("上传文件…"), systemImage: "square.and.arrow.up") { importFiles() }
                        Divider()
                        Button(L10n.text("刷新"), systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                        Button(L10n.text("在 Finder 中打开"), systemImage: "folder") { if let url = model.directory { NSWorkspace.shared.open(url) } }
                    } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 26)
                        .help(L10n.text("新建、上传、刷新或在 Finder 中打开"))
                }
            }
            if expanded {
                // 第二行：可点击的面包屑，代替原来的「上一级」按钮和整串路径。
                HStack(spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            let trail = model.trail
                            ForEach(Array(trail.enumerated()), id: \.offset) { index, url in
                                if index > 0 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(palette.muted)
                                }
                                let isLast = index == trail.count - 1
                                Button {
                                    Task { await model.go(to: url) }
                                } label: {
                                    Text(index == 0 ? provider.title : url.lastPathComponent)
                                        .font(.system(size: 12, weight: isLast ? .semibold : .regular))
                                        .foregroundStyle(isLast ? palette.ink : palette.muted)
                                        .lineLimit(1)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(isLast)
                            }
                        }
                    }
                    ProgressView()
                        .controlSize(.small)
                        .opacity(model.busy ? 1 : 0)
                        .frame(width: 18)
                        .accessibilityHidden(!model.busy)
                }
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text(L10n.text("名称")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(L10n.text("大小")).frame(width: 72, alignment: .trailing)
                        Text(L10n.text("修改时间")).frame(width: 148, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    Divider().opacity(0.14)
                    if model.visible.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: model.query.isEmpty ? "folder" : "magnifyingglass")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(palette.muted)
                            Text(L10n.text(model.query.isEmpty ? "这个文件夹是空的" : "没有找到匹配的文件"))
                                .font(.callout)
                                .foregroundStyle(palette.muted)
                            if model.query.isEmpty {
                                Button(L10n.text("上传文件…")) { importFiles() }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                ForEach(model.visible) { entry in
                                    CloudFileListRow(
                                        entry: entry,
                                        palette: palette,
                                        store: store,
                                        selected: model.selected == entry.id,
                                        onSelect: { model.selected = entry.id },
                                        onOpen: { Task { await model.enter(entry) } },
                                        onRename: { target = entry; newFolder = false; name = entry.name; showName = true },
                                        onReveal: { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) },
                                        onTrash: { target = entry; showTrash = true }
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(height: max(200, preferredHeight))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.chrome.opacity(0.16))
                )
            }
        }
        .padding(14)
        .readerGlass(radius: 14, enabled: glassActive, tint: store.chrome(dark: scheme == .dark))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.chrome.opacity(0.75), lineWidth: 0.8)
        )
        .tint(palette.accent)
        .disabled(store.isSyncingCloud || model.busy)
        .task(id: connected.map { "\($0.rawValue):\(store.cloudStates[$0]?.folderPath ?? "")" }.joined()) {
            model.store = store
            if !connected.contains(provider), let first = connected.first { provider = first }
            await connect()
        }
        .onChange(of: provider) { _, _ in Task { await connect() } }
        .sheet(isPresented: $showName) {
            VStack(alignment: .leading, spacing: 16) {
                Text(newFolder ? "新建文件夹" : "重命名").font(.headline)
                TextField("名称", text: $name).textFieldStyle(.roundedBorder)
                HStack {
                    Button("取消") { showName = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("保存") { applyName() }.keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 360).tint(palette.accent)
        }
        .alert("移到废纸篓？", isPresented: $showTrash) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                guard let entry = target else { return }
                Task { await model.change { root, _ in
                    guard !entry.symbolicLink else { throw ReaderFailure.message("请在 Finder 中管理符号链接。") }
                    let url = try CloudFileOperations.checked(entry.url, root: root)
                    guard url != root.resolvingSymlinksInPath() else { throw ReaderFailure.message("不能删除云盘根目录。") }
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                } }
            }
        } message: { Text("\(target?.name ?? "")\n云盘会同步此删除。删除同步快照或图书可能影响其他设备；本机书库副本不会自动删除。") }
        .alert("文件操作失败", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("好") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private func connect() async {
        guard let resolved = store.resolveCloudDirectory(for: provider) else { return }
        defer { if resolved.scoped { resolved.url.stopAccessingSecurityScopedResource() } }
        await model.connect(resolved.url)
    }
    private func applyName() {
        let value = name, entry = target, create = newFolder
        showName = false
        Task { await model.change { root, directory in
            let destination = try CloudFileOperations.child(value, in: directory, root: root)
            if create { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false) }
            else if let entry {
                guard !entry.symbolicLink else { throw ReaderFailure.message("请在 Finder 中管理符号链接。") }
                let source = try CloudFileOperations.checked(entry.url, root: root)
                try FileManager.default.moveItem(at: source, to: destination)
            }
        } }
    }
    private func importFiles() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let files = panel.urls
        Task { await model.change { root, directory in
            for source in files {
                let scoped = source.startAccessingSecurityScopedResource()
                defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                let destination = try CloudFileOperations.child(source.lastPathComponent, in: directory, root: root)
                try FileManager.default.copyItem(at: source, to: destination)
            }
        } }
    }
}

/// Themeable file row: AppKit Table paints its own dark chrome, which broke the
/// cloud page's theme integration. This list uses the same glass/ink/accent
/// tokens as the rest of LumaReader.
private struct CloudFileListRow: View {
    let entry: CloudFileEntry
    let palette: ReadingPalette
    let store: LibraryStore
    let selected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onRename: () -> Void
    let onReveal: () -> Void
    let onTrash: () -> Void
    @State private var hovered = false

    private var sizeText: String {
        entry.directory ? "—" : ByteCountFormatter.string(fromByteCount: entry.bytes, countStyle: .file)
    }
    private var modifiedText: String {
        entry.modified?.formatted(date: .abbreviated, time: .shortened) ?? "—"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.symbolicLink ? "link" : entry.directory ? "folder.fill" : "doc")
                .font(.system(size: 11.5))
                .foregroundStyle(entry.directory ? palette.accent : palette.muted)
                .frame(width: 16)
            Text(entry.name)
                .font(store.homeFont(12.5))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(sizeText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(palette.muted)
                .frame(width: 72, alignment: .trailing)
            Text(modifiedText)
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)
                .frame(width: 148, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? palette.accent.opacity(0.16) : (hovered ? palette.accent.opacity(0.07) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onSelect() }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen() })
        .contextMenu {
            Button(L10n.text("打开")) { onOpen() }.disabled(entry.symbolicLink)
            Button(L10n.text("重命名…")) { onRename() }
            Button(L10n.text("在 Finder 中显示")) { onReveal() }
            Button(L10n.text("移到废纸篓…"), role: .destructive) { onTrash() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(entry.name))
        .accessibilityValue(Text(sizeText + " · " + modifiedText))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
