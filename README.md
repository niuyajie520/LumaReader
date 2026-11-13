<div align="center">
  <img src="Assets/AppIcon/LumaReader-Glass.png" width="120" alt="LumaReader app icon">
  <h1>LumaReader</h1>
  <p><strong>A native macOS reading and study workspace.</strong><br>
  EPUB · PDF · 14 art-directed themes · annotations · dictation · writing · AI · cloud sync</p>

  <p>
    <a href="https://github.com/niuyajie520/LumaReader/releases/latest"><img alt="Latest release" src="https://img.shields.io/badge/release-v1.22.1%20(118)-2ea44f"></a>
    <img alt="macOS 26 or later" src="https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white">
    <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
    <img alt="SwiftUI, AppKit and WebKit" src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit%20%2B%20WebKit-1B6AC9">
    <img alt="MIT license" src="https://img.shields.io/badge/license-MIT-blue">
  </p>
</div>

LumaReader is a native macOS app for **deep reading and deliberate practice**. It pairs a serious EPUB/PDF reading engine with a study workspace: highlights and notes, vocabulary dictation, IELTS-style writing practice, an AI assistant, and folder-based cloud sync.

中文：LumaReader 是一个原生 macOS 阅读与学习工作台——EPUB/PDF 阅读、14 套艺术主题、批注与笔记、雅思听写与写作练习、AI 助手，以及 iCloud / OneDrive / Google Drive 文件夹同步。所有数据默认保存在本机。

> **Status:** personal project, actively developed. Builds are compiled and ad-hoc signed locally; there is no App Store distribution.

## Highlights

| Area | What it does |
| --- | --- |
| **Reading** | EPUB 2/3 and PDF, paginated WebKit renderer, four page-turn engines (slide, push, page flip, page curl), immersive mode, in-book search, bookmarks and text anchors. |
| **Directory** | Flattened table of contents with instant expand/collapse, saved folds per book, and a “current position” reveal. |
| **Annotations** | Select text to highlight or annotate; notes inspector, hover delete, export. |
| **Themes** | 14 independent visual systems with their own palettes, materials, borders, shadows and scene illustration — see [Themes](#themes). |
| **Dictation** | Vocabulary decks, wrong-word review, adaptive answer field, progress rail, neural (Kitten Nano/Micro) and Apple speech voices. |
| **Writing** | IELTS Task 1/2 workspace, drafts and history in SQLite, rubric-based evaluation. |
| **AI** | Side panel with OpenAI-compatible providers (DeepSeek, SiliconFlow, custom endpoints). API keys live in the macOS Keychain. |
| **Cloud** | Connect an existing cloud folder (iCloud Drive, OneDrive, Google Drive); syncs JSON snapshots and book files, never your SQLite database. |
| **Privacy** | Local-first. No account, no telemetry service. Reading data stays in `~/Library/Application Support/LumaReader` and the sync folder you choose. |

## Themes

Fourteen independent visual systems, each with its own material language rather than a palette swap.

| Classic | Manga worlds | Game & anime worlds |
| --- | --- | --- |
| Monet · Liquid Glass | Manga · Manuscript | NieR:Automata · YoRHa UI |
| Space · Observatory | Ocean Manga · 海风漫绘 | Zelda · Sheikah UI |
| Manga · Screentone | City Pop Manga · 都市漫绘 | Shinkai Sky · 晴空夏影 |
| | Forest Manga · 森之漫绘 | Spirited Away · 千与千寻 |
| | | Kanagawa · 镰仓海风 |
| | | Rosé Pine Dawn · 晨曦白桃 |
| | | Akari Dawn · 京都提灯 |
| | | Matcha Latte · 抹茶白玉 |

The five classic palettes and the Monet seed-extraction pipeline are preserved as-is; every other system adds its own scene, glass parameters and motion identity. Windows, panels and cards stay translucent so the scene remains visible, with WCAG-AA text contrast.

## Requirements

- macOS 26 or later (Apple silicon)
- Xcode 26 / Swift 6 toolchain to build from source
- Network access for SwiftPM dependencies on a clean machine

## Install

1. Download `LumaReader-<version>-Source.zip` from [Releases](https://github.com/niuyajie520/LumaReader/releases).
2. Unzip it anywhere outside your synced folders if possible.
3. Double-click `Install.command` (or run `bash Install.command`). It builds with your local toolchain, verifies the bundle, and installs to `~/Applications` and `/Applications`.
4. Existing books, vocabulary and learning records are preserved.

Command line:

```bash
curl -L -o LumaReader-Source.zip \
  https://github.com/niuyajie520/LumaReader/releases/download/v1.22.1/LumaReader-1.22.1-B118-20261113-Source.zip
unzip LumaReader-Source.zip
cd LumaReader-1.22.1-B118-20261113-Source
bash Install.command
```

## Build from source

```bash
swift build -c release          # compile
swift test                      # run the test suites
bash Scripts/build-macos.sh     # assemble, sign and verify "Luma Reader.app"
```

The release identity lives only in [`release.json`](release.json) (`version`, `build`, `source_id`). `Install.command`, `Info.plist`, the source ZIP name and the bundle check all read that file — never hardcode a version elsewhere.

## Project layout

```text
Sources/LumaReader/        App shell, reader, themes, cloud, AI, diagnostics
Deferred/StudyCenter/      Study kit: dictation, writing, speech, SQLite, persistence
Tests/                     Swift testing suites
Scripts/                   Build, signing, packaging, voice setup, privacy gate
Assets/                    App icons and marketing assets
Vendor/                    Vendored Swift packages
ThirdParty/                Third-party license texts
CHANGELOG.md               Release highlights + dated change log
AGENTS.md                  Project constraints and protected behavior
```

## Privacy

- No account system and no analytics service. The app does not phone home.
- Books, annotations and study records live under `~/Library/Application Support/LumaReader`.
- AI requests go only to the provider you configure; keys are stored in the Keychain.
- Cloud sync writes to the folder you explicitly connect. It never uploads your SQLite database.
- Crash and diagnostic data stay local unless you export them.

Security reports: see [SECURITY.md](SECURITY.md).

## Versioning

Semantic versioning with a monotonic build number. Every release ships a new source ZIP whose identity (`LumaReader-<version>-B<build>-<source-id>-Source`) is checked by `release_guard` before delivery. See [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE). Third-party notices: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
