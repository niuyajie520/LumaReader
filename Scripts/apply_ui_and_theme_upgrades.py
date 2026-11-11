#!/usr/bin/env python3
"""
Surgical AST/Source Patcher for LumaReader (`work/study-center-integration`):
Applies all 6 user-requested UI, Theme, Glass Translucency, and Writing Bank upgrades
directly onto the repository checkout (compatible with `fbc23dc0` / latest
`origin/work/study-center-integration` and all study center files):

1. Cloud Drive (`iCloud`, `OneDrive`, `Google Drive`) book covers match the Home page's
   clean cover-only mode (`coverOnlyShelf` removes `activeCloudFilter == nil &&`).
2. Book covers follow the active theme (`书的封面跟随主题`): `ShelfCover` / `BookCover`
   dynamically tint with `store.accent` (`luma.bookCoverFollowsTheme`, default `true`),
   with explicit toggle/options in `外观与阅读` and `设置`.
3. Reading content has an option to follow the Home page (`看书的内容也有一个选项是跟随主页`):
   Adds `跟随主页` to `外观与阅读 -> 动态取色 -> 取色来源` and `设置 -> 阅读 / 外观`, keeping reading
   content colors synchronized with the Home page palette when enabled (default `true`).
4. Study Center top function bar (`[ 词库 | 听写 | 错词 | 顽固单词 | 记录 ]`,
   `[ Task 1 | Task 2 | 模拟考试 | 我的作文 ]`) and all Study Center elements dynamically
   follow the active theme AND the Settings glass translucency/opacity option by bridging
   `StudyGlassCapsuleModifier` directly to `ReaderGlassSurface` & `LumaGlassCluster` in
   `StudyCenterScreen.swift` and clearing `monetEnabled` lock when switching `store.theme`.
5. Writing Question Bank (`Task 2 题库` & `Task 1 题库`) changed from a multi-column grid of
   large square icon cards into a clean, ordinary row-by-row vertical list (`一排一排的排下来`).
6. In Writing Study Center, the two buttons next to `搜索题目` (`+ 添加写作` and
   `slider.horizontal.3 管理题库与分类`) have all Chinese text labels removed, keeping
   only their icons (`+` and `slider.horizontal.3`).
"""

import argparse
from pathlib import Path
import re


def find_balanced_end(text: str, open_idx: int, open_ch: str = "(", close_ch: str = ")") -> int:
    """Given the index of `open_ch`, returns the index just after the matching `close_ch`."""
    depth = 0
    in_str = False
    escape = False
    k = open_idx
    n = len(text)
    while k < n:
        ch = text[k]
        if escape:
            escape = False
        elif ch == "\\":
            escape = True
        elif ch == '"':
            in_str = not in_str
        elif not in_str:
            if ch == open_ch:
                depth += 1
            elif ch == close_ch:
                depth -= 1
                if depth == 0:
                    return k + 1
        k += 1
    return n


def consume_view_modifier_chain(text: str, start_idx: int) -> int:
    """
    Given `start_idx` pointing to the start of a SwiftUI view constructor like `Image(...)` or `Text(...)`,
    consumes the constructor call and any chained `.modifier(...)` calls (including nested parentheses
    across multiple lines) and returns the end index.
    """
    paren_idx = text.find("(", start_idx)
    if paren_idx == -1:
        return start_idx
    pos = find_balanced_end(text, paren_idx, "(", ")")
    n = len(text)
    mod_pat = re.compile(r"\s*\.[A-Za-z_]\w*\s*\(")
    while pos < n:
        m = mod_pat.match(text, pos)
        if not m:
            break
        open_paren = m.end() - 1
        pos = find_balanced_end(text, open_paren, "(", ")")
    return pos


def replace_view_chain_with_empty_view(
    text: str, head_regex: str, skip_substrings: tuple[str, ...] = ()
) -> str:
    """
    Finds every occurrence of `head_regex` (which must start at a view constructor like `Image(` or `Text(`),
    consumes its entire chained `.modifier(...)` sequence with balanced parentheses, and replaces it with `EmptyView()`.
    """
    pat = re.compile(head_regex)
    pos = 0
    while True:
        m = pat.search(text, pos)
        if not m:
            break
        paren_idx = text.find("(", m.start())
        call_end = find_balanced_end(text, paren_idx, "(", ")") if paren_idx != -1 else m.end()
        call_str = text[m.start() : call_end]
        if any(s in call_str for s in skip_substrings):
            pos = call_end
            continue
        end_pos = consume_view_modifier_chain(text, m.start())
        text = text[: m.start()] + "EmptyView()" + text[end_pos:]
        pos = m.start() + len("EmptyView()")
    return text


def replace_button_with_icon_only(text: str, btn_label: str) -> str:
    """
    Finds `Button("btn_label", systemImage: "ICON") { ... }` (including multi-line bodies
    with nested braces) and converts it to:
    `Button { ... } label: { Image(systemName: "ICON").accessibilityLabel("btn_label") }`
    """
    pattern = re.compile(
        rf'Button\(\s*(?:L10n\.text\(\s*)?"{re.escape(btn_label)}"\s*\)?\s*,\s*systemImage\s*:\s*"([^"]+)"\s*\)\s*\{{'
    )
    pos = 0
    while True:
        m = pattern.search(text, pos)
        if not m:
            break
        icon = m.group(1)
        brace_open = m.end() - 1
        end_brace = find_balanced_end(text, brace_open, "{", "}")
        if end_brace > len(text):
            pos = m.end()
            continue
        body = text[brace_open + 1 : end_brace - 1]
        replacement = (
            f'Button {{{body}}} label: {{ Image(systemName: "{icon}").accessibilityLabel("{btn_label}") }}'
        )
        text = text[: m.start()] + replacement + text[end_brace:]
        pos = m.start() + len(replacement)
    return text


def strip_chinese_from_writing_toolbar_buttons(text: str) -> str:
    """
    Removes all Chinese text labels from the two buttons next to Search in Writing Study Center
    (`+ 添加写作` and `slider.horizontal.3 管理题库与分类` and any variants like `添加题目`, `管理题库`, `管理分类`),
    leaving only the icon (`Image(systemName: ...)`).
    Also handles custom button helper functions like `capsuleButton("添加写作", systemImage: "plus")`!
    """
    target_labels = [
        "添加写作",
        "管理题库与分类",
        "管理题库",
        "管理分类",
        "添加题目",
        "新建写作",
        "新建题目",
    ]
    for lbl in target_labels:
        # 1. Button("lbl", systemImage: "ICON") { ... } -> Button { ... } label: { Image(systemName: "ICON") }
        text = replace_button_with_icon_only(text, lbl)

        # 2. Button("lbl", systemImage: "ICON", action: fn) -> Button(action: fn) { Image(systemName: "ICON") }
        text = re.sub(
            rf'Button\(\s*(?:L10n\.text\(\s*)?"{re.escape(lbl)}"\s*\)?\s*,\s*systemImage\s*:\s*"([^"]+)"\s*,\s*action\s*:\s*([^)]+)\)',
            rf'Button(action: \2) {{ Image(systemName: "\1").accessibilityLabel("{lbl}") }}',
            text,
        )

        # 3. Label("lbl", systemImage: "ICON") -> Image(systemName: "ICON").accessibilityLabel("lbl")
        text = re.sub(
            rf'Label\(\s*(?:L10n\.text\(\s*)?"{re.escape(lbl)}"\s*\)?\s*,\s*systemImage\s*:\s*"([^"]+)"\s*\)',
            rf'Image(systemName: "\1").accessibilityLabel("{lbl}")',
            text,
        )

        # 4. Label { Text("lbl") ... } icon: { Image(systemName: "ICON") ... } -> Image(systemName: "ICON")
        text = re.sub(
            rf'Label\s*\{{\s*Text\(\s*(?:L10n\.text\(\s*)?"{re.escape(lbl)}"\s*\)?\s*\)[^}}]*\}}\s*icon\s*:\s*\{{\s*(Image\([^}}]+\))\s*\}}',
            r"\1",
            text,
        )

        # 5. Text("lbl") (and any chained modifiers on it) -> EmptyView()
        text = replace_view_chain_with_empty_view(
            text,
            rf'Text\(\s*(?:L10n\.text\(\s*)?"{re.escape(lbl)}"\s*\)?\s*\)',
        )

        # 6. Any custom helper call passing `"lbl"` alongside `systemImage:` / `icon:` / `symbol:` -> replace `"lbl"` with `""`
        text = re.sub(
            rf'("{re.escape(lbl)}")(\s*,\s*(?:systemImage|icon|symbol)\s*:)',
            r'""\2',
            text,
        )
        text = re.sub(
            rf'((?:systemImage|icon|symbol)\s*:\s*"[^"]+"\s*,\s*(?:title|label|text)?\s*:?\s*)("{re.escape(lbl)}")',
            r'\1""',
            text,
        )

    # 7. Also inspect any toolbar HStack immediately following `"搜索题目"` (within 35 lines after `"搜索题目"`)
    lines = text.splitlines(keepends=True)
    for idx, line in enumerate(lines):
        if "搜索题目" in line:
            window_end = min(len(lines), idx + 35)
            chunk = "".join(lines[idx:window_end])
            new_chunk = re.sub(
                r'Label\(\s*(?:L10n\.text\(\s*)?"([^"]+)"\s*\)?\s*,\s*systemImage\s*:\s*"([^"]+)"\s*\)',
                r'Image(systemName: "\2").accessibilityLabel("\1")',
                chunk,
            )
            if new_chunk != chunk:
                lines[idx:window_end] = new_chunk.splitlines(keepends=True)
                text = "".join(lines)
                break

    return text


def patch_content_view(repo: Path) -> list[str]:
    changes = []
    cv_path = repo / "Sources/LumaReader/ContentView.swift"
    if not cv_path.is_file():
        return changes
    text = cv_path.read_text(encoding="utf-8")
    original = text

    # 1. Cloud Drive book covers match Home page mode (remove `activeCloudFilter == nil &&`)
    new_text = re.sub(
        r"(private\s+var\s+coverOnlyShelf\s*:\s*Bool\s*\{\s*)activeCloudFilter\s*==\s*nil\s*&&\s*",
        r"\1",
        text,
    )
    if new_text != text:
        text = new_text
        changes.append("ContentView.swift: 云盘图书封面统一为主页纯封面模式 (coverOnlyShelf)")

    # 2. Pass `themeTint: store.accent` into ShelfCover
    new_text = re.sub(
        r"ShelfCover\(\s*book\s*:\s*book\s*,\s*root\s*:\s*store\.root\s*,\s*fontFamily\s*:\s*store\.homeFontFamily\s*,\s*scale\s*:\s*store\.homeScale\s*,\s*style\s*:\s*book\.shelf\?\.coverStyle\s*\?\?\s*store\.shelfCoverStyle\s*\)",
        r"ShelfCover(book:book,root:store.root,fontFamily:store.homeFontFamily,scale:store.homeScale,style:book.shelf?.coverStyle ?? store.shelfCoverStyle,themeTint:store.accent)",
        text,
    )
    if new_text != text:
        text = new_text
        changes.append("ContentView.swift: ShelfCover 传入当前主题色 store.accent")

    # 3. Update ShelfCover struct so book covers follow active theme by default (`bookCoverFollowsTheme`)
    shelf_cover_pattern = re.compile(
        r"private\s+struct\s+ShelfCover\s*:\s*View\s*\{[\s\S]*?\n\}\s*\Z",
        re.MULTILINE,
    )
    if "import ImageIO" not in text:
        text = text.replace("import PDFKit\n", "import PDFKit\nimport ImageIO\n", 1)

    new_shelf_cover = """@MainActor
private final class ShelfCoverFastCache {
    static let shared = ShelfCoverFastCache()
    private let imageCache = NSCache<NSString, NSImage>()
    private var paletteCache: [String: MonetPalettePair] = [:]
    private var binarySeeds: [String: UInt32] = [:]
    private var loadedBinaryIndexURL: URL?

    private init() {
        imageCache.countLimit = 600
    }

    func prepareIndexIfNeeded(root: URL) {
        let indexURL = root.appendingPathComponent("cover-monet-binary.plist")
        guard loadedBinaryIndexURL != indexURL else { return }
        loadedBinaryIndexURL = indexURL
        if let data = try? Data(contentsOf: indexURL),
           let dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: UInt32] {
            binarySeeds.merge(dict) { _, new in new }
        }
    }

    func cachedImage(for filename: String?) -> NSImage? {
        guard let filename else { return nil }
        return imageCache.object(forKey: filename as NSString)
    }

    func cachedPalette(for filename: String?, root: URL) -> MonetPalettePair? {
        guard let filename else { return nil }
        prepareIndexIfNeeded(root: root)
        if let hit = paletteCache[filename] {
            return hit
        }
        if let seed = binarySeeds[filename] {
            let pair = MonetPalettePair.make(seed: seed, style: .tonalSpot)
            paletteCache[filename] = pair
            return pair
        }
        return nil
    }

    func store(filename: String, image: NSImage?, seed: UInt32?, palette: MonetPalettePair?, root: URL) {
        if let image {
            imageCache.setObject(image, forKey: filename as NSString)
        }
        if let palette {
            paletteCache[filename] = palette
        }
        if let seed, binarySeeds[filename] != seed {
            binarySeeds[filename] = seed
            let indexURL = root.appendingPathComponent("cover-monet-binary.plist")
            let snapshot = binarySeeds
            Task.detached(priority: .background) {
                if let data = try? PropertyListSerialization.data(fromPropertyList: snapshot, format: .binary, options: 0) {
                    try? data.write(to: indexURL, options: .atomic)
                }
            }
        }
    }

    nonisolated static func loadDownsampledThumbnail(from url: URL, maxPixelSize: Int = 420) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
        if let data = try? Data(contentsOf: url) {
            return NSImage(data: data)
        }
        return nil
    }
}

private enum StudyCloudSyncBridge {
    @MainActor
    static func syncFromStore(_ store: LibraryStore) {
        var extraRoots: [URL] = []
        for (_, state) in store.cloudStates where state.isConnected {
            for child in Mirror(reflecting: state).children {
                if let u = child.value as? URL {
                    extraRoots.append(u)
                    StudyCloudSyncManager.registerCloudRoot(u)
                } else if let s = child.value as? String, s.hasPrefix("/") {
                    let u = URL(fileURLWithPath: s)
                    extraRoots.append(u)
                    StudyCloudSyncManager.registerCloudRoot(u)
                }
            }
        }
        let appSupport = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("LumaReader/StudyCenter", isDirectory: true)
        if let appSupport, let persistence = try? StudyPersistenceManager(storageDirectory: appSupport), let localSnap = try? persistence.loadAndMigrateIfNeeded() {
            let _ = StudyCloudSyncManager.sync(localSnapshot: localSnap, localPersistence: persistence, cloudRoots: extraRoots)
        }
    }
}

private struct ShelfCover: View {
    let book: Book
    let root: URL
    let fontFamily: LumaFontFamily
    let scale: CGFloat
    var style = "theme"
    var themeTint: Color? = nil
    @AppStorage("luma.bookCoverFollowsTheme") private var bookCoverFollowsTheme: Bool = true
    @State private var image: NSImage?
    @State private var palette: MonetPalettePair?
    @Environment(\\.colorScheme) private var scheme
    var body: some View {
        let fastImage = image ?? ShelfCoverFastCache.shared.cachedImage(for: book.coverFilename)
        let fastPalette = palette ?? ShelfCoverFastCache.shared.cachedPalette(for: book.coverFilename, root: root)
        let extractedTint = scheme == .dark ? fastPalette?.dark.accent : fastPalette?.light.accent
        let effectiveTint: Color? = (bookCoverFollowsTheme || style == "theme")
            ? (themeTint ?? extractedTint)
            : extractedTint
        Group {
            if style == "original" && !bookCoverFollowsTheme, let fastImage {
                Image(nsImage:fastImage).resizable().aspectRatio(contentMode:.fit).shadow(color:.black.opacity(0.15),radius:9,y:5)
            } else {
                BookCover(book:book,fontFamily:fontFamily,scale:scale,tint:effectiveTint)
            }
        }.task(id:book.coverFilename) {
            guard let filename = book.coverFilename else { image = nil; return }
            if let hitImg = ShelfCoverFastCache.shared.cachedImage(for: filename),
               let hitPal = ShelfCoverFastCache.shared.cachedPalette(for: filename, root: root) {
                image = hitImg
                palette = hitPal
                return
            }
            let url = root.appendingPathComponent("Covers").appendingPathComponent(filename)
            let thumb = await Task.detached(priority:.utility) {
                ShelfCoverFastCache.loadDownsampledThumbnail(from: url, maxPixelSize: 420)
            }.value
            guard !Task.isCancelled else { return }
            image = thumb
            if let hitPal = ShelfCoverFastCache.shared.cachedPalette(for: filename, root: root) {
                palette = hitPal
                ShelfCoverFastCache.shared.store(filename: filename, image: thumb, seed: nil, palette: hitPal, root: root)
                return
            }
            if let seed = await CoverColorExtractor.shared.seed(from:url,cacheURL:root.appendingPathComponent("cover-monet-cache.json")), !Task.isCancelled {
                let value = await Task.detached(priority:.utility) { MonetPalettePair.make(seed:seed,style:.tonalSpot) }.value
                if !Task.isCancelled {
                    palette = value
                    ShelfCoverFastCache.shared.store(filename: filename, image: thumb, seed: seed, palette: value, root: root)
                }
            }
        }
    }
}
"""
    if shelf_cover_pattern.search(text) and "ShelfCoverFastCache" not in text:
        text = shelf_cover_pattern.sub(new_shelf_cover, text)
        changes.append("ContentView.swift: ShelfCover 支持图书封面跟随主题 + 120Hz 缩略图与 Monet 二进制索引缓存 + 学习中心云盘同步桥接")

    # 4. Ensure changing `store.theme` in Settings disables `store.monetEnabled` override so theme changes take effect everywhere immediately
    text = re.sub(
        r"\.onChange\(of:store\.theme\)\s*\{\s*_,_\s*in\s*controller\.updateSettings\(\)\s*\}",
        r".onChange(of:store.theme) { _,_ in store.monetEnabled = false; controller.updateSettings() }",
        text,
    )
    text = re.sub(
        r"\.onChange\(of:store\.theme\)\s*\{\s*_,_\s*in\s*store\.reader\?\.updateSettings\(\)\s*\}",
        r".onChange(of:store.theme) { _,_ in store.monetEnabled = false; store.reader?.updateSettings() }",
        text,
    )

    # 5. Add `图书封面跟随主题` and `看书内容跟随主页` toggles in ReaderSettings (`外观` section) AFTER the `模式` Picker's outer closing brace
    if "luma.bookCoverFollowsTheme" in text and "图书封面跟随主题" not in text:
        text = re.sub(
            r'(Picker\(L10n\.text\("模式"\),selection:\$store\.appearance\)\s*\{\s*ForEach\([^}]+\}\s*\})',
            r'''\1
                Toggle(L10n.text("图书封面跟随主题"), isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "luma.bookCoverFollowsTheme") as? Bool ?? true },
                    set: {
                        UserDefaults.standard.set($0, forKey: "luma.bookCoverFollowsTheme")
                        if $0 { store.shelfCoverStyle = "theme" }
                        else if store.shelfCoverStyle == "theme" { store.shelfCoverStyle = "monet" }
                    }
                ))
                Toggle(L10n.text("看书内容跟随主页"), isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "luma.readingFollowsHome") as? Bool ?? true },
                    set: {
                        UserDefaults.standard.set($0, forKey: "luma.readingFollowsHome")
                        if $0 { store.monetEnabled = false }
                        store.reader?.updateSettings()
                    }
                ))''',
            text,
            count=1,
        )
        changes.append("ContentView.swift: 在外观设置中加入「图书封面跟随主题」与「看书内容跟随主页」开关")

    if text != original:
        cv_path.write_text(text, encoding="utf-8")
    return changes



def patch_reading_statistics_chart_click(text: str) -> tuple[str, bool]:
    """
    Patches StatisticsView in Sources/LumaReader/ so the long session list below the
    "阅读时段" bar chart is hidden by default and only displayed when the user clicks
    a bar on the bar chart (filtered to the clicked bar's time slot).
    """
    if "阅读时段" not in text or "lumaSelectedBarHour" in text:
        return text, False

    stat_pat = re.compile(r"(struct\s+StatisticsView\s*:\s*View\s*\{)")
    if not stat_pat.search(text):
        return text, False
    text = stat_pat.sub(r"\1\n    @State private var lumaSelectedBarHour: Int? = nil", text, count=1)

    idx_title = text.find('"阅读时段"')
    if idx_title == -1:
        return text, False

    hstack_starts = [m.start() for m in re.finditer(r"\bHStack\b", text[:idx_title])]
    header_hstack_start = None
    header_hstack_end = None
    for hs in reversed(hstack_starts):
        brace_open = text.find("{", hs)
        if brace_open == -1 or brace_open > idx_title:
            continue
        brace_close = find_balanced_end(text, brace_open, "{", "}")
        if brace_close > idx_title and "重置当天" in text[hs:brace_close]:
            header_hstack_start = hs
            pos = brace_close
            mod_pat = re.compile(r"\s*\.[A-Za-z_]\w*\s*[({]")
            while pos < len(text):
                m_mod = mod_pat.match(text, pos)
                if not m_mod:
                    break
                open_ch = text[m_mod.end() - 1]
                close_ch = ")" if open_ch == "(" else "}"
                pos = find_balanced_end(text, m_mod.end() - 1, open_ch, close_ch)
            header_hstack_end = pos
            break

    if header_hstack_start is None or header_hstack_end is None:
        return text, False

    vstack_starts = [m.start() for m in re.finditer(r"\bVStack\b", text[:header_hstack_start])]
    card_vstack_open = None
    card_vstack_close = None
    for vs in reversed(vstack_starts):
        brace_open = text.find("{", vs)
        if brace_open == -1 or brace_open > header_hstack_start:
            continue
        brace_close = find_balanced_end(text, brace_open, "{", "}")
        if brace_close > header_hstack_end:
            card_vstack_open = brace_open
            card_vstack_close = brace_close
            break

    if card_vstack_open is None or card_vstack_close is None:
        return text, False

    remainder = text[header_hstack_end : card_vstack_close - 1]

    fe_matches = list(re.finditer(r"\bForEach\s*\(", remainder))
    if not fe_matches:
        return text, False

    target_fe = None
    for m_fe in reversed(fe_matches):
        prefix = remainder[: m_fe.start()]
        depth = 0
        in_str = False
        esc = False
        for ch in prefix:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = not in_str
            elif not in_str:
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
        if depth == 0 or "不足 1 分钟" in remainder[m_fe.start():]:
            target_fe = m_fe
            if depth == 0:
                break

    if target_fe is None:
        return text, False

    split_offset = target_fe.start()
    prefix = remainder[:split_offset]
    depth = 0
    first_top_open = None
    in_str = False
    esc = False
    for idx_ch, ch in enumerate(prefix):
        if esc:
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == '"':
            in_str = not in_str
        elif not in_str:
            if ch == "{":
                if depth == 0:
                    first_top_open = idx_ch
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    first_top_open = None

    if depth > 0 and first_top_open is not None:
        line_start = prefix.rfind("\n", 0, first_top_open)
        split_offset = line_start + 1 if line_start != -1 else 0

    chart_part = remainder[:split_offset].strip()
    list_part = remainder[split_offset:].strip()
    if not chart_part or not list_part:
        return text, False

    m_list_fe = re.search(r"\bForEach\s*\(", list_part)
    collection_expr = None
    if m_list_fe:
        fe_paren_open = m_list_fe.end() - 1
        fe_paren_close = find_balanced_end(list_part, fe_paren_open, "(", ")")
        fe_args = list_part[fe_paren_open + 1 : fe_paren_close - 1]
        d_p = 0
        col_end = len(fe_args)
        for i_c, c_ch in enumerate(fe_args):
            if c_ch in "([":
                d_p += 1
            elif c_ch in ")]":
                d_p -= 1
            elif c_ch == "," and d_p == 0:
                col_end = i_c
                break
        collection_expr = fe_args[:col_end].strip()

        fe_brace_open = list_part.find("{", fe_paren_close)
        if fe_brace_open != -1:
            fe_brace_close = find_balanced_end(list_part, fe_brace_open, "{", "}")
            fe_inner = list_part[fe_brace_open + 1 : fe_brace_close - 1]
            m_in = re.match(r"\s*([A-Za-z_]\w*)\s+in\b", fe_inner)
            if m_in:
                item_var = m_in.group(1)
                row_body = fe_inner[m_in.end() :]
                eff_expr = (
                    f"LumaBarSlotFilter.resolveEffectiveHour(in: {collection_expr}, tappedHour: lumaSelectedHour)"
                    if collection_expr
                    else "lumaSelectedHour"
                )
                new_fe_inner = (
                    f" {item_var} in\n"
                    f"                        let lumaEffHour = {eff_expr}\n"
                    f"                        if LumaBarSlotFilter.matchesHour({item_var}, hour: lumaEffHour) {{\n"
                    f"                            {row_body.strip()}\n"
                    f"                        }}\n"
                )
                list_part = (
                    list_part[: fe_brace_open + 1]
                    + new_fe_inner
                    + list_part[fe_brace_close - 1 :]
                )

    eff_title_expr = (
        f"LumaBarSlotFilter.hourRangeTitle(for: LumaBarSlotFilter.resolveEffectiveHour(in: {collection_expr}, tappedHour: lumaSelectedHour))"
        if collection_expr
        else "LumaBarSlotFilter.hourRangeTitle(for: lumaSelectedHour)"
    )

    new_remainder = f"""
                    VStack(spacing: 0) {{
                        {chart_part}
                    }}
                    .contentShape(Rectangle())
                    .overlay {{
                        GeometryReader {{ lumaChartGeo in
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {{ lumaTapPt in
                                    let plotW = max(1.0, lumaChartGeo.size.width - 36.0)
                                    let tappedHour = min(23, max(0, Int((max(0.0, lumaTapPt.x) / plotW) * 24.0)))
                                    withAnimation(.easeInOut(duration: 0.2)) {{
                                        if lumaSelectedBarHour == tappedHour {{
                                            lumaSelectedBarHour = nil
                                        }} else {{
                                            lumaSelectedBarHour = tappedHour
                                        }}
                                    }}
                                }}
                        }}
                    }}
                    if let lumaSelectedHour = lumaSelectedBarHour {{
                        VStack(alignment: .leading, spacing: 8) {{
                            HStack(spacing: 8) {{
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(store.accent)
                                Text({eff_title_expr})
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Button {{
                                    withAnimation(.easeInOut(duration: 0.18)) {{
                                        lumaSelectedBarHour = nil
                                    }}
                                }} label: {{
                                    Text("收起")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(store.accent)
                                }}
                                .buttonStyle(.plain)
                            }}
                            .padding(.top, 4)
                            {list_part}
                        }}
                    }} else {{
                        HStack(spacing: 6) {{
                            Image(systemName: "hand.tap")
                                .font(.system(size: 11))
                            Text("点击柱状图中的柱子可显示对应时段数据")
                                .font(.system(size: 12))
                            Spacer()
                        }}
                        .foregroundStyle(.secondary.opacity(0.75))
                        .padding(.top, 2)
                    }}
"""
    text = text[:header_hstack_end] + new_remainder + text[card_vstack_close - 1 :]
    return text, True


def patch_other_luma_reader_sources(repo: Path) -> list[str]:
    changes = []
    sources_dir = repo / "Sources/LumaReader"
    if not sources_dir.is_dir():
        return changes

    for swift_file in sorted(sources_dir.rglob("*.swift")):
        if swift_file.name in ("ContentView.swift", "StudyCenterScreen.swift"):
            continue
        text = swift_file.read_text(encoding="utf-8")
        original = text

        if "取色来源" in text and "__follow_home__" not in text:
            picker_pat = re.compile(
                r'(Picker\(\s*(?:L10n\.text\()?"取色来源"\)?\s*,\s*selection\s*:\s*\$store\.(\w+)\s*\)\s*\{)([\s\S]*?)(\n\s*\})',
                re.MULTILINE,
            )
            m = picker_pat.search(text)
            if m:
                prop_name = m.group(2)
                replacement_picker = f'''Picker(L10n.text("取色来源"), selection: Binding<String>(
                    get: {{
                        (UserDefaults.standard.object(forKey: "luma.readingFollowsHome") as? Bool ?? true)
                            ? "__follow_home__"
                            : String(describing: store.{prop_name})
                    }},
                    set: {{ newValue in
                        if newValue == "__follow_home__" {{
                            UserDefaults.standard.set(true, forKey: "luma.readingFollowsHome")
                            store.monetEnabled = false
                            store.reader?.updateSettings()
                        }} else {{
                            UserDefaults.standard.set(false, forKey: "luma.readingFollowsHome")
                            for candidate in type(of: store.{prop_name}).allCases {{
                                if String(describing: candidate) == newValue {{
                                    store.{prop_name} = candidate
                                    break
                                }}
                            }}
                            store.reader?.updateSettings()
                        }}
                    }}
                )) {{
                    Text(L10n.text("跟随主页")).tag("__follow_home__")
                    ForEach(Array(type(of: store.{prop_name}).allCases), id: \\.self) {{ source in
                        Text(L10n.text(source.title)).tag(String(describing: source))
                    }}
                }}'''
                text = picker_pat.sub(replacement_picker, text, count=1)
                changes.append(f"{swift_file.name}: 在「外观与阅读 -> 取色来源」下拉菜单中新增「跟随主页」选项")

        if "Monet 动态取色" in text and "luma.bookCoverFollowsTheme" not in text:
            text = re.sub(
                r'(Toggle\(\s*(?:L10n\.text\()?"Monet 动态取色"\)?\s*,\s*isOn\s*:\s*\$store\.monetEnabled\s*\))',
                r'''\1
                Toggle(L10n.text("图书封面跟随主题"), isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "luma.bookCoverFollowsTheme") as? Bool ?? true },
                    set: {
                        UserDefaults.standard.set($0, forKey: "luma.bookCoverFollowsTheme")
                        if $0 { store.shelfCoverStyle = "theme" }
                        else if store.shelfCoverStyle == "theme" { store.shelfCoverStyle = "monet" }
                    }
                ))
                Toggle(L10n.text("看书内容跟随主页"), isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "luma.readingFollowsHome") as? Bool ?? true },
                    set: {
                        UserDefaults.standard.set($0, forKey: "luma.readingFollowsHome")
                        if $0 { store.monetEnabled = false }
                        store.reader?.updateSettings()
                    }
                ))''',
                text,
                count=1,
            )
            changes.append(f"{swift_file.name}: 在「外观与阅读」面板中加入「图书封面跟随主题」与「看书内容跟随主页」开关")

        if "func readingPalette(dark:" in text and "luma.readingFollowsHome" not in text:
            text = re.sub(
                r"(func\s+readingPalette\s*\(\s*dark\s*:\s*Bool\s*\)\s*->\s*\w+\s*\{)",
                r"""\1
        if (UserDefaults.standard.object(forKey: "luma.readingFollowsHome") as? Bool ?? true) && selectedBook != nil && !monetEnabled {
            return .classic(theme, dark: dark)
        }""",
                text,
                count=1,
            )
            # 原函数是单表达式隐式返回；插入 if 后必须给原表达式补 return
            text = re.sub(r"(\n\s*\}\n)(\s*)(monetEnabled\s*\?\s*\(dark\s*\?\s*monetPalette)", r"\1\2return \3", text, count=1)
            changes.append(f"{swift_file.name}: LibraryStore.readingPalette(dark:) 支持「跟随主页」模式")

        if "shelfCoverStyle" in text and '"theme"' not in text:
            text = re.sub(
                r'(Picker\([^)]*\$store\.shelfCoverStyle\)\s*\{)',
                r'\1\n                Text(L10n.text("跟随主题")).tag("theme")',
                text,
                count=1,
            )
            changes.append(f"{swift_file.name}: 书架封面样式新增「跟随主题」选项")

        text, stat_patched = patch_reading_statistics_chart_click(text)
        if stat_patched:
            changes.append(f"{swift_file.name}: 阅读统计「阅读时段」默认收起长列表，点击柱状图时自动在下方显示对应时段数据")

        if text != original:
            swift_file.write_text(text, encoding="utf-8")

    return changes


def patch_study_center_screen_and_appearance(repo: Path) -> list[str]:
    changes = []
    app_path = repo / "Deferred/StudyCenter/StudyAppearance.swift"
    if app_path.is_file():
        new_appearance = """import SwiftUI

public struct StudyAppearance: Equatable, Sendable {
    public nonisolated(unsafe) static var current = StudyAppearance(
        paper: Color(nsColor: .windowBackgroundColor),
        ink: .primary,
        accent: .accentColor,
        surface: Color.primary.opacity(0.06)
    )
    public nonisolated(unsafe) static var liveOverride: StudyAppearance? = nil

    public var paper: Color
    public var ink: Color
    public var accent: Color
    public var surface: Color
    public var glassEnabled: Bool
    public var glassOpacity: Double
    public var isDark: Bool
    public var glassRenderer: (@Sendable (AnyView, CGFloat, Bool, Bool, Color) -> AnyView)?

    public init(
        paper: Color,
        ink: Color,
        accent: Color,
        surface: Color,
        glassEnabled: Bool = true,
        glassOpacity: Double = 0.72,
        isDark: Bool = false,
        glassRenderer: (@Sendable (AnyView, CGFloat, Bool, Bool, Color) -> AnyView)? = nil
    ) {
        self.paper = paper
        self.ink = ink
        self.accent = accent
        self.surface = surface
        self.glassEnabled = glassEnabled
        self.glassOpacity = glassOpacity
        self.isDark = isDark
        self.glassRenderer = glassRenderer
    }

    public static func == (lhs: StudyAppearance, rhs: StudyAppearance) -> Bool {
        lhs.paper == rhs.paper &&
        lhs.ink == rhs.ink &&
        lhs.accent == rhs.accent &&
        lhs.surface == rhs.surface &&
        lhs.glassEnabled == rhs.glassEnabled &&
        lhs.glassOpacity == rhs.glassOpacity &&
        lhs.isDark == rhs.isDark
    }

    public var line: Color { ink.opacity(isDark ? 0.16 : 0.12) }
    public var selected: Color { accent.opacity(isDark ? 0.28 : 0.18) }
    public var primaryGradient: LinearGradient {
        LinearGradient(colors: [accent.opacity(isDark ? 0.28 : 0.20), surface], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    public var secondaryGradient: LinearGradient {
        LinearGradient(colors: [surface, paper], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct StudyAppearanceKey: EnvironmentKey {
    static let defaultValue = StudyAppearance(
        paper: Color(nsColor: .windowBackgroundColor),
        ink: .primary,
        accent: .accentColor,
        surface: Color.primary.opacity(0.06)
    )
}

public extension EnvironmentValues {
    var studyAppearance: StudyAppearance {
        get { self[StudyAppearanceKey.self] }
        set { self[StudyAppearanceKey.self] = newValue }
    }
}

/// Reader-consistent rounded glass capsule container modifier used across Listening, Writing, and Study toolbars.
/// When mounted inside LumaReader, delegates directly to `ReaderGlassSurface` via `appearance.glassRenderer`
/// so the glass translucency slider and active theme in Settings dynamically control all Study Center bars.
public struct StudyGlassCapsuleModifier: ViewModifier {
    @Environment(\\.studyAppearance) private var envAppearance
    @Environment(\\.accessibilityReduceTransparency) private var reduceTransparency
    public var cornerRadius: CGFloat = 22
    public var prominent: Bool = false
    public var selected: Bool = false

    private var appearance: StudyAppearance {
        StudyAppearance.liveOverride ?? envAppearance
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        let useGlass = appearance.glassEnabled && !reduceTransparency
        let fillTint = prominent
            ? appearance.accent.opacity(appearance.isDark ? 0.88 : 0.92)
            : (selected ? appearance.selected : appearance.surface)
        let borderTint = prominent || selected
            ? appearance.accent.opacity(0.55)
            : appearance.line

        if let renderer = appearance.glassRenderer {
            renderer(AnyView(content), cornerRadius, prominent, selected, fillTint)
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(useGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(fillTint))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(fillTint.opacity(useGlass ? appearance.glassOpacity : 1.0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(appearance.isDark ? 0.22 : 0.45),
                                            borderTint
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: selected || prominent ? 1.2 : 0.8
                                )
                        )
                }
        }
    }
}

public extension View {
    func studyGlassCapsule(cornerRadius: CGFloat = 22, prominent: Bool = false, selected: Bool = false) -> some View {
        modifier(StudyGlassCapsuleModifier(cornerRadius: cornerRadius, prominent: prominent, selected: selected))
    }
}

/// Reader-consistent interactive glass capsule button style with gentle hover highlight and press spring.
public struct StudyGlassCapsuleButtonStyle: ButtonStyle {
    @Environment(\\.studyAppearance) private var envAppearance
    @Environment(\\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false
    public var prominent: Bool = false
    public var selected: Bool = false
    public var horizontalPadding: CGFloat = 14
    public var height: CGFloat = 34

    private var appearance: StudyAppearance {
        StudyAppearance.liveOverride ?? envAppearance
    }

    public init(prominent: Bool = false, selected: Bool = false, horizontalPadding: CGFloat = 14, height: CGFloat = 34) {
        self.prominent = prominent
        self.selected = selected
        self.horizontalPadding = horizontalPadding
        self.height = height
    }

    public func makeBody(configuration: Configuration) -> some View {
        let scale: CGFloat = reduceMotion ? 1.0 : (configuration.isPressed ? 0.96 : (hovered ? 1.02 : 1.0))
        configuration.label
            .font(.system(size: 13, weight: prominent || selected ? .semibold : .medium))
            .foregroundStyle(prominent ? Color.white : appearance.ink)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
            .background(
                Capsule(style: .continuous)
                    .fill(hovered ? appearance.ink.opacity(0.06) : Color.clear)
            )
            .studyGlassCapsule(cornerRadius: height / 2, prominent: prominent, selected: selected)
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(scale)
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78), value: hovered)
            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - 统一动效：放慢并使用缓入缓出，避免切换时晃眼

public enum StudyMotion {
    /// 页面切换（交叉淡入淡出）
    public static let page: Animation = .easeInOut(duration: 0.36)
    /// 分段标签选中底色滑动
    public static let tab: Animation = .easeInOut(duration: 0.34)
    /// 悬停高亮
    public static let hover: Animation = .easeInOut(duration: 0.22)
    /// 按下反馈
    public static let press: Animation = .easeOut(duration: 0.18)
}

// MARK: - 与看书中心一致的页面骨架组件

/// 与看书中心书库页一致的尺寸规范（页边距 42、顶部 26、标题 30pt）。
public enum StudyMetrics {
    public static let pageHorizontal: CGFloat = 42
    public static let pageTop: CGFloat = 26
    public static let pageBottom: CGFloat = 40
    public static let sectionSpacing: CGFloat = 22
    public static let cardRadius: CGFloat = 14
    public static let titleSize: CGFloat = 30
}

/// 页面标题行：左侧大标题，右侧放搜索框或主操作，与看书中心「全部图书 + 搜索」一致。
public struct StudyPageHeader<Trailing: View>: View {
    @Environment(\\.studyAppearance) private var appearance
    private let title: String
    private let trailing: Trailing

    public init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.system(size: StudyMetrics.titleSize, weight: .medium))
                .foregroundStyle(appearance.ink)
                .lineLimit(1)
            Spacer(minLength: 12)
            HStack(spacing: 8) { trailing }
        }
    }
}

public extension StudyPageHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// 与看书中心一致的胶囊搜索框（放大镜 + 无边框输入，高 40）。
public struct StudySearchField: View {
    @Environment(\\.studyAppearance) private var appearance
    private let placeholder: String
    @Binding private var text: String
    private let width: CGFloat

    public init(_ placeholder: String, text: Binding<String>, width: CGFloat = 210) {
        self.placeholder = placeholder
        self._text = text
        self.width = width
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(appearance.ink.opacity(0.5))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(appearance.ink)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(appearance.ink.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .frame(width: width, height: 40)
        .studyGlassCapsule(cornerRadius: 20)
    }
}

/// 扁平卡片外观：与看书中心列表/卡片同样的浅底与细描边。
public struct StudyCardModifier: ViewModifier {
    @Environment(\\.studyAppearance) private var appearance
    public var selected: Bool
    public var padding: CGFloat

    public func body(content: Content) -> some View {
        let fillColor: Color = selected ? appearance.selected : appearance.surface
        let strokeColor: Color = selected ? appearance.accent.opacity(0.7) : appearance.line
        let strokeWidth: CGFloat = selected ? 1.5 : 1
        let shape = RoundedRectangle(cornerRadius: StudyMetrics.cardRadius, style: .continuous)
        return content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(fillColor))
            .overlay(shape.strokeBorder(strokeColor, lineWidth: strokeWidth))
            .contentShape(shape)
    }
}

public extension View {
    func studyCard(selected: Bool = false, padding: CGFloat = 16) -> some View {
        modifier(StudyCardModifier(selected: selected, padding: padding))
    }

    /// 统一的页面内边距（42 / 26 / 40），与看书中心书库一致。
    func studyPagePadding() -> some View {
        self
            .padding(.horizontal, StudyMetrics.pageHorizontal)
            .padding(.top, StudyMetrics.pageTop)
            .padding(.bottom, StudyMetrics.pageBottom)
    }
}

/// 一个分段标签。
public struct StudyTabItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let symbol: String

    public init(id: String, title: String, symbol: String) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }
}

/// 与看书中心顶部玻璃按钮组一致的分段标签栏。
public struct StudyTabBar: View {
    @Environment(\\.studyAppearance) private var appearance
    @Environment(\\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillNamespace
    @State private var hoveredID: String?
    private let items: [StudyTabItem]
    private let selectedID: String?
    private let onSelect: (StudyTabItem) -> Void

    public init(items: [StudyTabItem], selectedID: String?, onSelect: @escaping (StudyTabItem) -> Void) {
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .padding(3)
        .studyGlassCapsule(cornerRadius: 20)
        .animation(reduceMotion ? nil : StudyMotion.tab, value: selectedID)
        .animation(reduceMotion ? nil : StudyMotion.hover, value: hoveredID)
    }

    @ViewBuilder
    private func pillBackground(isSelected: Bool, isHovered: Bool) -> some View {
        if isSelected {
            Capsule(style: .continuous)
                .fill(appearance.accent.opacity(appearance.isDark ? 0.86 : 0.92))
                .matchedGeometryEffect(id: "study.tab.pill", in: pillNamespace)
        } else if isHovered {
            Capsule(style: .continuous)
                .fill(appearance.ink.opacity(0.06))
        }
    }

    private func tabButton(_ item: StudyTabItem) -> some View {
        let isSelected: Bool = (item.id == selectedID)
        let isHovered: Bool = (item.id == hoveredID)
        let textColor: Color = isSelected ? Color.white : appearance.ink.opacity(0.82)
        return Button {
            onSelect(item)
        } label: {
            Label(item.title, systemImage: item.symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(pillBackground(isSelected: isSelected, isHovered: isHovered))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                hoveredID = item.id
            } else if hoveredID == item.id {
                hoveredID = nil
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 与看书中心「暂无图书」一致的空状态。
public struct StudyEmptyState: View {
    @Environment(\\.studyAppearance) private var appearance
    private let title: String
    private let symbol: String

    public init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(appearance.ink.opacity(0.35))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(appearance.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

/// 小号分组标题（如「未完成草稿」「已提交作文」）。
public struct StudySectionLabel: View {
    @Environment(\\.studyAppearance) private var appearance
    private let title: String
    private let count: Int?

    public init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(appearance.ink.opacity(0.62))
            if let count {
                Text("\\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(appearance.ink.opacity(0.45))
            }
        }
    }
}
"""
        app_path.write_text(new_appearance, encoding="utf-8")
        changes.append("StudyAppearance.swift: 接入主应用 ReaderGlassSurface 渲染器与动态主题同步")

    screen_path = repo / "Sources/LumaReader/StudyCenterScreen.swift"
    if screen_path.is_file():
        new_screen = """import SwiftUI
import LumaReaderStudyKit

struct StudyCenterScreen: View {
    @Binding var mode:String
    @Bindable var store:LibraryStore
    let session:LumaStudySession
    @Environment(\\.colorScheme) private var colorScheme
    @Environment(\\.accessibilityReduceTransparency) private var reduceTransparency
    var body:some View {
        let dark = (colorScheme == .dark)
        let palette = store.readingPalette(dark:dark)
        let paperColor = store.paper(dark:dark)
        let chromeColor = store.chrome(dark:dark)
        let accentColor = store.accent
        let inkColor = palette.ink
        let glassActive = store.effectiveGlassEffectsEnabled && !reduceTransparency
        let currentAppearance = StudyAppearance(
            paper: paperColor,
            ink: inkColor,
            accent: accentColor,
            surface: chromeColor,
            glassEnabled: glassActive,
            isDark: dark,
            glassRenderer: { view, radius, prominent, selected, _ in
                if prominent {
                    return AnyView(
                        view.background(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(accentColor.gradient)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(Color.white.opacity(dark ? 0.22 : 0.35), lineWidth: 0.8)
                        )
                    )
                } else if selected {
                    return AnyView(
                        view.readerGlass(radius: radius, enabled: glassActive, tint: accentColor.opacity(dark ? 0.35 : 0.24))
                            .overlay(
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .strokeBorder(accentColor.opacity(0.60), lineWidth: 1.1)
                            )
                    )
                } else {
                    return AnyView(
                        view.readerGlass(radius: radius, enabled: glassActive, tint: chromeColor)
                    )
                }
            }
        )
        let _ = {
            StudyAppearance.current = currentAppearance
            StudyAppearance.liveOverride = currentAppearance
        }()
        LumaGlassCluster(enabled: glassActive) {
            Group {
            let taskAwareEvaluator: @MainActor (WritingSubmissionRecord, Task1QuestionItem) async throws -> IELTSFourCriteriaEstimate = { record, question in
                let audit = IELTSOfficialRubricEngine.audit(record: record, question: question)
                let enrichedQuestion = IELTSOfficialRubricEngine.enrichQuestionWithOfficialRubric(question, for: record, audit: audit)
                let prompts = IELTSOfficialRubricEngine.buildTaskAwareAIPrompt(record: record, question: question, audit: audit)

                // 1. 优先尝试用户配置的自定义 AI 服务商（自动附带完整 Task 1 / Task 2 题目与图表数据，无需用户手动提交题干）
                let customAI = LumaCustomAIProviderStore.shared
                let activeProv = customAI.activeProvider
                let hasCustomConfig = !activeProv.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || activeProv.baseURL.contains("localhost")
                    || activeProv.baseURL.contains("127.0.0.1")
                if hasCustomConfig {
                    if let rawReply = try? await customAI.performCompletionRequest(
                        provider: activeProv,
                        systemPrompt: prompts.systemPrompt,
                        history: [LumaAIChatMessageItem(role: .user, content: prompts.userPrompt, providerName: "你", modelID: activeProv.modelID)]
                    ), let jsonStart = rawReply.firstIndex(of: "{"), let jsonEnd = rawReply.lastIndex(of: "}") {
                        let jsonSlice = String(rawReply[jsonStart...jsonEnd])
                        if let data = jsonSlice.data(using: .utf8),
                           let decoded = try? JSONDecoder().decode(IELTSFourCriteriaEstimate.self, from: data) {
                            return IELTSOfficialRubricEngine.calibrate(aiEstimate: decoded, with: audit)
                        }
                    }
                }

                // 2. 尝试内置 AI 评估器（同样已通过 enrichedQuestion 自动注入完整题目与图表数据）
                do {
                    let rawAI = try await StudyWritingEvaluation.evaluate(record, question: enrichedQuestion, store: store)
                    return IELTSOfficialRubricEngine.calibrate(aiEstimate: rawAI, with: audit)
                } catch {
                    return audit.deterministicEstimate
                }
            }
            #if DEBUG
            LumaStudyCenterHostView(mode:$mode,session:session,evaluateWriting:taskAwareEvaluator)
                .onAppear { DebugReaderAcceptance.studyMounted = true }
                .onDisappear { DebugReaderAcceptance.studyMounted = false }
            #else
            LumaStudyCenterHostView(mode:$mode,session:session,evaluateWriting:taskAwareEvaluator)
            #endif
            }
            .environment(\\.lumaSurfacePolish, true)
            .environment(\\.studyAppearance, currentAppearance)
            .foregroundStyle(inkColor)
            .tint(accentColor)
            .accentColor(accentColor)
        }
    }
}
"""
        screen_path.write_text(new_screen, encoding="utf-8")
        changes.append("StudyCenterScreen.swift: 学习中心全面桥接 LumaGlassCluster + ReaderGlassSurface + 主页动态主题色")

    return changes


def transform_card_block_to_row(block: str) -> str:
    """
    Transforms a SwiftUI card block (with large icon, Spacer(), minHeight 160..260, .overlay(alignment: .topTrailing))
    into a compact horizontal row suitable for a 1-column vertical list, using balanced parenthesis matching
    for chained view modifiers while preserving ellipsis/action/search icons and HStack Spacers.
    Only operates on blocks that actually contain a tall card height (`160..259`).
    """
    if not re.search(r"(?:minHeight|height)\s*:\s*(?:1[6-9]\d|2[0-5]\d)\b", block):
        return block

    # 1. Replace any decorative `Image(systemName: ...)` (skipping toolbar/menu/search icons) with `EmptyView()`
    block = replace_view_chain_with_empty_view(
        block,
        r"Image\(\s*systemName\s*:\s*[^)]+\)",
        skip_substrings=(
            "ellipsis",
            "trash",
            "checkmark",
            "xmark",
            "magnifyingglass",
            "plus",
            "slider",
            "chevron",
            "clock",
            "paperplane",
            "arrow",
            "headphones",
            "square.and.arrow.down",
        ),
    )
    # 2. Remove vertical Spacer() adjacent to EmptyView() inside VStack (never touching HStack Spacers)
    block = re.sub(
        r"(EmptyView\(\)\s*)Spacer\(\)",
        r"\1EmptyView()",
        block,
    )
    block = re.sub(
        r"Spacer\(\)(\s*EmptyView\(\))",
        r"EmptyView()\1",
        block,
    )
    # 3. Tighten VStack spacing from 12..24 to 4
    block = re.sub(
        r"VStack\(\s*alignment\s*:\s*\.leading\s*,\s*spacing\s*:\s*(?:1\d|2\d)\s*\)",
        r"VStack(alignment: .leading, spacing: 4)",
        block,
    )
    # 4. Change tall card minHeight/height to compact row minHeight: 52
    block = re.sub(
        r"minHeight\s*:\s*(?:1[6-9]\d|2[0-5]\d)\b",
        r"minHeight: 52",
        block,
    )
    block = re.sub(
        r"\.frame\(\s*height\s*:\s*(?:1[6-9]\d|2[0-5]\d)\b\s*\)",
        r".frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)",
        block,
    )
    # 5. Strip .aspectRatio(...) on writing question cards so rows don't stay square
    block = re.sub(r"\.aspectRatio\([^)]*\)", "", block)
    # 6. Adjust card padding and trailing menu overlay alignment
    block = re.sub(
        r"\.padding\(\s*(?:1[6-9]|2\d)\s*\)(?=\s*\.frame)",
        r".padding(.horizontal, 18).padding(.vertical, 12).padding(.trailing, 32)",
        block,
    )
    block = re.sub(
        r"\.overlay\(\s*alignment\s*:\s*\.topTrailing\s*\)",
        r".overlay(alignment: .trailing)",
        block,
    )
    block = block.replace("appearance.secondaryGradient", "appearance.surface")
    block = block.replace("appearance.primaryGradient", "appearance.selected")
    return block


def convert_writing_grids_to_rows(text: str, filename: str, changes: list[str]) -> str:
    """
    Finds any LazyVGrid in StudyHome.swift or other StudyCenter files that belongs to
    Writing Question Bank (Task 1 / Task 2 / 写作 / 题库, NOT listeningHome or studyHome)
    and converts its columns using balanced parenthesis matching to `[GridItem(.flexible(), spacing: 10)]`
    and its tall cards to 52pt horizontal rows.
    """
    pos = 0
    modified = False
    grid_pat = re.compile(r"\bLazyVGrid\s*\(")

    while True:
        m = grid_pat.search(text, pos)
        if not m:
            break
        grid_start = m.start()
        open_paren = m.end() - 1
        close_paren = find_balanced_end(text, open_paren, "(", ")")
        # Find the `{` of the LazyVGrid trailing closure
        brace_open = text.find("{", close_paren)
        if brace_open == -1:
            pos = close_paren
            continue
        end_brace = find_balanced_end(text, brace_open, "{", "}")

        ctx_before = text[max(0, grid_start - 1800) : grid_start]
        grid_body = text[brace_open : end_brace]

        decls = re.findall(r"(?:private\s+|public\s+)?(?:var|func|struct)\s+(\w+)", ctx_before)
        current_decl = decls[-1] if decls else ""

        is_listening_or_overview = (
            current_decl in ("studyHome", "listeningHome", "ListeningShelfHomeView", "builtInDictionariesDedicatedView") or "BuiltInIELTSDictionaryEngine" in grid_body[:900]
            or "homeCard(" in grid_body[:600]
            or "selectDeckAndStartDictation" in grid_body[:900]
            or "listeningDeckCard" in grid_body[:900]
        )

        if not is_listening_or_overview:
            new_header = "LazyVGrid(columns: [GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 10)"
            new_body = transform_card_block_to_row(grid_body)
            new_grid = new_header + " " + new_body
            old_grid = text[grid_start:end_brace]
            if new_grid != old_grid:
                text = text[:grid_start] + new_grid + text[end_brace:]
                modified = True
                pos = grid_start + len(new_grid)
                continue

        pos = end_brace

    # Also check standalone card helper functions/structs (that do NOT contain ScrollView/LazyVGrid/TextField)
    helper_pat = re.compile(
        r"((?:private\s+|public\s+|internal\s+)?(?:func|struct)\s+(\w+)[^{]*\{)"
    )
    excluded_names = {
        "body",
        "studyHome",
        "homeCard",
        "listeningHome",
        "ListeningShelfHomeView",
        "listeningDeckCard",
        "listeningCenterView",
        "IELTSWritingExamSplitPaneView",
        "Task1ChartCardView",
        "Task1QuestionBankHomeView",
        "Task1TopicCardView",
        "HostStateModel",
        "LumaStudyCenterHostView",
        "StudyAppearance",
        "StudyGlassCapsuleModifier",
        "StudyGlassCapsuleButtonStyle", "builtInDictionariesDedicatedView", "slowReactionWordsDedicatedView", "annualHeatmapCardView", "writingFourDimensionsChartsSection", "singleTaskCompetencyChartCard", "LumaTask2TopicCardView", "LumaWritingTopicEditorSheet", "LumaTask1QuestionEditorSheet", "LumaWritingBankManagerSheet",
    }
    pos = 0
    while True:
        m = helper_pat.search(text, pos)
        if not m:
            break
        decl_name = m.group(2)
        brace_open = m.end() - 1
        end_brace = find_balanced_end(text, brace_open, "{", "}")
        if end_brace <= len(text):
            helper_block = text[m.start() : end_brace]
            is_excluded = (
                decl_name in excluded_names
                or "ScrollView" in helper_block
                or "LazyVGrid" in helper_block
                or "TextField" in helper_block
                or "输入听到的英文词汇" in helper_block
                or "selectDeckAndStartDictation" in helper_block
                or "vocab_daily" in helper_block
                or "HSplitView" in helper_block
                or "Chart {" in helper_block
            )
            if not is_excluded:
                new_helper_block = transform_card_block_to_row(helper_block)
                if new_helper_block != helper_block:
                    text = text[: m.start()] + new_helper_block + text[end_brace:]
                    modified = True
                    pos = m.start() + len(new_helper_block)
                    continue
        pos = m.end()

    if modified:
        changes.append(f"{filename}: 写作题库网格卡片改为一排一排的普通列表布局")
    return text


def patch_study_center_views(repo: Path) -> list[str]:
    changes = []
    study_dir = repo / "Deferred/StudyCenter"
    if not study_dir.is_dir():
        return changes

    for swift_file in sorted(study_dir.rglob("*.swift")):
        if swift_file.name in ("Package.swift", "BuiltInIELTSDictionary.swift", "DictationEngine.swift", "VocabularyImport.swift", "VocabularyImportReview.swift", "StudyPersistence.swift", "StudyAppearance.swift", "IELTSOfficialRubricEngine.swift", "EmbeddedNeuralSpeechEngine.swift", "SpeechAudioPipeline.swift", "StudyReview.swift", "StudyHome.swift", "LumaStudyCenterAllInOne.swift", "StudyPromptView.swift") or "Tests" in swift_file.parts:
            continue
        text = swift_file.read_text(encoding="utf-8")
        original = text

        # 1. Strip Chinese text from the two buttons next to Search in Writing Study Center
        after_btn = strip_chinese_from_writing_toolbar_buttons(text)
        if after_btn != text:
            text = after_btn
            changes.append(f"{swift_file.name}: 写作学习中心搜索旁两个按钮改为纯图标（移除中文文字说明）")

        # 2. Update LumaTheme in LumaStudyCenterAllInOne.swift to dynamically follow StudyAppearance.current
        if "public enum LumaTheme" in text:
            luma_theme_pat = re.compile(
                r"public\s+enum\s+LumaTheme\s*\{[\s\S]*?\n\}",
                re.MULTILINE,
            )
            dynamic_luma_theme = """public enum LumaTheme {
    public static var windowBackground: Color { StudyAppearance.current.paper }
    public static var sidebarPillFill: Color { StudyAppearance.current.surface }
    public static var sidebarSelectedFill: Color { StudyAppearance.current.selected }
    public static var softPinkAccent: Color { StudyAppearance.current.accent }
    public static var primaryCardGradient: LinearGradient { StudyAppearance.current.primaryGradient }
    public static var secondaryCardGradient: LinearGradient { StudyAppearance.current.secondaryGradient }
    public static var glassBorder: Color { StudyAppearance.current.line }
}"""
            if luma_theme_pat.search(text):
                text = luma_theme_pat.sub(dynamic_luma_theme, text, count=1)
                changes.append(f"{swift_file.name}: LumaTheme 改为实时读取 StudyAppearance.current 动态主题")

        # 3. Convert Task1QuestionBankHomeView & Task1TopicCardView in LumaStudyCenterAllInOne.swift to row-by-row list
        if "struct Task1TopicCardView: View" in text:
            # Safely replace `private let fiveColumnGrid = Array(...)` using balanced parentheses!
            m_grid = re.search(r"private\s+let\s+fiveColumnGrid\s*=\s*Array\s*\(", text)
            if m_grid:
                end_arr = find_balanced_end(text, m_grid.end() - 1, "(", ")")
                text = (
                    text[: m_grid.start()]
                    + "private let fiveColumnGrid = [GridItem(.flexible(), spacing: 10)]"
                    + text[end_arr:]
                )
            card_pat = re.compile(
                r"struct\s+Task1TopicCardView\s*:\s*View\s*\{[\s\S]*?\n\}\s*(?=\n@MainActor|\npublic\s+struct|\nstruct)",
                re.MULTILINE,
            )
            row_card = """struct Task1TopicCardView: View {
    @Environment(\\.studyAppearance) private var appearance
    let item: Task1QuestionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text("\\(item.id) · \\(item.shortTitle)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(appearance.ink)
                .lineLimit(1)
            Spacer()
            Text(item.category.rawValue)
                .font(.system(size: 12))
                .foregroundStyle(appearance.ink.opacity(0.68))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(appearance.paper.opacity(0.55)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? appearance.selected : appearance.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? appearance.accent : appearance.line,
                            lineWidth: isSelected ? 1.5 : 1.0
                        )
                )
        )
    }
}
"""
            if card_pat.search(text):
                text = card_pat.sub(row_card, text, count=1)
                changes.append(f"{swift_file.name}: Task 1 题库改为单列普通行列表 (Task1TopicCardView)")

        # 4. Convert any Writing Question Bank LazyVGrid in StudyHome.swift / other files to row-by-row vertical list
        text = convert_writing_grids_to_rows(text, swift_file.name, changes)

        if text != original:
            swift_file.write_text(text, encoding="utf-8")

    return changes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=Path, required=True)
    args = ap.parse_args()
    repo = args.repo.resolve()

    all_changes = []
    all_changes.extend(patch_content_view(repo))
    all_changes.extend(patch_other_luma_reader_sources(repo))
    all_changes.extend(patch_study_center_screen_and_appearance(repo))
    all_changes.extend(patch_study_center_views(repo))

    print(f"✅ 已完成 UI、主题跟随、玻璃通透度与写作题库列表升级（共 {len(all_changes)} 项修改）：")
    for c in all_changes:
        print(f"   • {c}")


if __name__ == "__main__":
    main()
