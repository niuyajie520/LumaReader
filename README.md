# LumaReader

Native macOS 26+ reader. Verification branch source baseline: 0.9.17.

The repository is Private. This change extracts the reviewed source snapshot into the repository root and consolidates the misplaced YAML files under `.github/workflows/macos26-blockers.yml`.

Gitleaks 8.30.1 was SHA-256 verified against the official GitHub release asset digest and executed against the complete extracted snapshot before upload: exit 0, no findings. The project privacy gate also passed. CI scans Git history again; neither check is a complete privacy guarantee.

CI targets `macos-26` ARM64. It verifies the toolchain, Debug build, Swift tests, Release app, signature, architecture and packaging. Only filtered text evidence is uploaded automatically. Raw logs, crash reports, dSYM and unreviewed app archives are not exported.

A successful CI build does not certify app startup, all buttons, native WebKit graphics, animations, Instruments or M4 Air 16GB performance. Those require separate evidence. Old handoff reports in this snapshot describe earlier attempts and are not current CI results.

The application Sources are byte-identical to the previously delivered 0.9.17 baseline. Tests use fictitious text and credentials; book files, personal conversations and real library data are not included. Existing licenses remain in LICENSE and THIRD_PARTY_NOTICES.md.

Run Verify-LumaReader.command on a Mac to verify locally; run Install-LumaReader.command only after verification. Source import uses the verification branch, without forcing or merging main.
