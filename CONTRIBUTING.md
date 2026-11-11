# Contributing

Thanks for taking a look at LumaReader. This is a personal macOS project; small, focused contributions are welcome.

## Before you start

1. Read [`AGENTS.md`](AGENTS.md) — it lists the project's protected behavior (reader chrome, dictation field, writing highlights, theme tokens, cloud entry points).
2. Use macOS 26+ with Xcode 26 / Swift 6.

## Build and test

```bash
swift build -c release
swift test
bash Scripts/build-macos.sh   # assembles and verifies "Luma Reader.app"
```

`swift test` includes UI-adjacent suites that need an active foreground session; a few of them are environment-dependent on headless or background runs. Report the exact failure output rather than skipping them.

## Style

- Surgical changes: keep the diff limited to the requested behavior. Do not refactor, rename, or restyle unrelated code.
- Preserve the protected reader/study behavior described in `AGENTS.md` unless the change explicitly targets it.
- Keep the release identity in [`release.json`](release.json); never hardcode a version or build number elsewhere.
- Prefer the existing motion tokens and theme materials over new ad-hoc animations or colors.
- Conventional Commits for messages, for example `fix(reader): keep chrome mounted while the outline is open`.

## Pull requests

- Explain the user-visible problem and the scope you changed.
- Include build/test evidence; for UI changes, add before/after screenshots in light and dark appearance.
- Do not commit `.build`, `dist`, `Logs`, book files, personal data, keys or logs.
- Update `CHANGELOG.md` when behavior changes.

## Reporting bugs

Use the issue templates. Include the app version (Settings → About), macOS version, exact steps, and the smallest synthetic reproduction you can make. Redact personal paths and book titles.
