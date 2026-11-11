# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.7.x | ✅ |
| < 1.7 | ❌ |

## Reporting a vulnerability

Please use GitHub's **private vulnerability reporting**: open the **Security** tab → **Report a vulnerability**. Do not open a public issue for a security problem.

Never attach or paste:

- book files, EPUB/PDF contents, or library archives
- AI API keys, tokens, or Keychain exports
- personal conversations, study records, or full logs

If a report needs a sample, reproduce it with a synthetic file and fictitious text.

## What is in scope

- The app bundle, Swift sources and installer scripts in this repository.
- Data handling in `~/Library/Application Support/LumaReader`.
- AI requests: they are sent only to the endpoint you configure. Keys are stored in the macOS Keychain.
- Cloud sync: writes only to the folder you explicitly connect.

## Good practice for users

- Use a dedicated API key with a spending limit for the AI panel.
- Keep the app in `/Applications` or `~/Applications` and verify releases with the published SHA-256.
- Do not put the source folder inside a cloud-synced directory while building.
