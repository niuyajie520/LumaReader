import SwiftUI
import AppKit
import CoreText
import UniformTypeIdentifiers

struct ImportedFont: Identifiable, Equatable, Sendable {
    var filename: String
    var postScriptName: String
    var title: String
    var id: String { filename+":"+postScriptName }
}

enum ImportedFontLoader {
    static func load(root: URL) throws -> [ImportedFont] {
        let folder = root.appendingPathComponent("Fonts",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let files = try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil,options:[.skipsHiddenFiles])
            .filter { ["ttf","otf"].contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var result:[ImportedFont] = []
        for file in files {
            _ = try FontFileSync.validatedData(at:file)
            guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(file as CFURL) as? [CTFontDescriptor], !descriptors.isEmpty else {
                throw ReaderFailure.message("字体无法解析："+file.lastPathComponent)
            }
            CTFontManagerRegisterFontsForURL(file as CFURL,.process,nil)
            for descriptor in descriptors {
                let font = CTFontCreateWithFontDescriptor(descriptor,16,nil)
                result.append(ImportedFont(filename:file.lastPathComponent,postScriptName:CTFontCopyPostScriptName(font) as String,title:CTFontCopyDisplayName(font) as String))
            }
        }
        return result.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    static func importFiles(_ urls:[URL],root:URL) throws {
        let folder = root.appendingPathComponent("Fonts",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys:[.isRegularFileKey,.fileSizeKey])
            guard values.isRegularFile == true, let size = values.fileSize, size <= FontFileSync.maximumBytes else {
                throw ReaderFailure.message("字体超过 32 MB 或不是普通文件。")
            }
            let data = try Data(contentsOf:url)
            let name = try FontFileSync.filename(for:data,extension:url.pathExtension)
            guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor], !descriptors.isEmpty else {
                throw ReaderFailure.message("无法识别字体："+url.lastPathComponent)
            }
            let target = folder.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath:target.path) { try data.write(to:target,options:.atomic) }
        }
    }
}

@MainActor extension LibraryStore {
    var selectedReaderFont: ImportedFont? { importedFonts.first { $0.id == readerCustomFont } }
    func readingFont(_ size:CGFloat,weight:Font.Weight = .regular) -> Font {
        if let font = selectedReaderFont { return .custom(font.postScriptName,size:size).weight(weight) }
        return .system(size:size,weight:weight,design:readerFontFamily.design)
    }
    func importFonts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension:"ttf"),UTType(filenameExtension:"otf")].compactMap { $0 }
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.message = L10n.text("导入 TTF / OTF 字体，保存于 Luma，并随已接入的云盘同步。")
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls, localRoot = root
        isImportingFonts = true
        Task {
            defer { isImportingFonts = false }
            do {
                try await Task.detached(priority:.utility) { try ImportedFontLoader.importFiles(urls,root:localRoot) }.value
            } catch { self.error = "部分字体未能导入："+error.localizedDescription }
            await reloadFonts()
            syncAllConnectedClouds()
        }
    }
    func reloadFonts() async {
        let localRoot = root
        do {
            let loaded = try await Task.detached(priority:.utility) { try ImportedFontLoader.load(root:localRoot) }.value
            if importedFonts != loaded { importedFonts = loaded; reader?.updateSettings() }
        } catch { self.error = "字体未能载入："+error.localizedDescription }
    }
    /// Copy only the selected immutable file into the EPUB's existing read-access sandbox.
    func readerFontCSS(in epubRoot:URL) -> String {
        guard let font = selectedReaderFont else { return "" }
        let folder = epubRoot.appendingPathComponent(".luma-fonts",isDirectory:true)
        let target = folder.appendingPathComponent(font.filename)
        do {
            if !FileManager.default.fileExists(atPath:target.path) {
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                let source = root.appendingPathComponent("Fonts").appendingPathComponent(font.filename)
                do { try FileManager.default.linkItem(at:source,to:target) }
                catch { try FileManager.default.copyItem(at:source,to:target) }
            }
            return "@font-face{font-family:LumaImported;src:url('"+target.absoluteString+"');font-display:swap;}"
        } catch { return "" }
    }
}
