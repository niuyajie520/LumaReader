# Third-party notices

## ZIPFoundation 0.9.20

https://github.com/weichsel/ZIPFoundation/tree/0.9.20

ZIPFoundation is resolved by Swift Package Manager, not vendored in this archive.
Its complete MIT license is reproduced in `ZIPFoundation-LICENSE.txt`.

## Multi-Mode Page Turn Engines & Design References (0.9.18)

1. **Readest (`v0.11.18`–`v0.12.10`, PR #4940 & Issue #5288)**
   - Repository: https://github.com/readest/readest
   - License: AGPL-3.0 (consulted strictly as architectural & interaction reference; no AGPL source files are copied or bundled).
   - Design & architectural patterns referenced:
     - Idle speculative single-page surface pre-warming (`preparedPageSnapshot`) with automatic invalidation on page, geometry, theme, or annotation changes.
     - Continuous distance + release velocity commit rule and velocity-modulated settle duration (`ReaderMotionPolicy.swift`).
     - Exponential moving average (EMA) edge-drag velocity smoothing (`ReaderEdgeTurnView.swift`).

2. **foliate-js (`paginator.js`)**
   - Repository: https://github.com/johnfactotum/foliate-js
   - License: MIT License (`ThirdParty/PageTurn/foliate-js-LICENSE.txt`)
   - Adapted concepts & transition mechanics:
     - Non-destructive CSS multi-column pagination with UTF-16 Range anchor preservation across window resizes.
     - Dual-surface synchronized `Slide` (`平滑滑动`) and `Push` (`柔和推页`) transitions (`PageTurnCover.swift` & `ReaderController.swift`).

3. **StPageFlip (`v2.0.7`)**
   - Repository: https://github.com/Nodlik/StPageFlip
   - Demo & Docs: https://nodlik.github.io/StPageFlip/
   - License: MIT License (`ThirdParty/PageTurn/StPageFlip-LICENSE.txt`)
   - Adapted calculations:
     - `FlipCalculation` and `Shadow` 3-component dynamic shadow model (`castShadow` drop shadow on the revealed page, `creaseShadow` along the fold tangent, and paper-tinted `backPage` specular highlight) and `PageDensity.HARD` rigid spine rotation (`Page Flip` / `整页翻转`) in `PageTurnCover.swift`.

4. **XBPageCurl (`XBCurlView`)**
   - Repository: https://github.com/xissburg/XBPageCurl
   - License: MIT License (`ThirdParty/PageTurn/XBPageCurl-LICENSE.txt`)
   - Adapted calculations:
     - Virtual rolling cylinder mesh projection (`cylinderPosition`, `cylinderAngle`, `cylinderRadius`) and Lambertian cylindrical self-shading for `Page Curl` (`真实纸张弯曲`) in `PageTurnCover.swift` and `Experiments/PageCurlLab.html`.

5. **Flipbook for macOS**
   - Repository: https://github.com/rayhankhilji/flipbook
   - Referenced for native macOS AppKit / SwiftUI Core Animation 3D perspective spine transform (`m34` foreshortening and interruptible `.presentation()` layer handoff).

## Design references

https://github.com/emilkowalski/skills

Design guidance was consulted; its instruction files are not redistributed in this project.

Reference: https://developer.apple.com/documentation/swiftui/glasseffectcontainer
Reference: https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:)

Web AI chrome uses CSS translucency; it is not Apple's native Liquid Glass optical renderer.

## Material Color Utilities (0.9.1)

Source: https://github.com/material-foundation/material-color-utilities
Pinned upstream commit: bd811e4ca2ab94c4ce3cadc89c19b1820b9704b3
Vendored Swift package: `Vendor/MaterialColorUtilities` (upstream `swift/` subtree).
Copyright Google LLC, Apache License 2.0. Complete license and original source
headers are retained in that package. Google Celebi quantization, Score selection,
HCT and DynamicScheme are used directly; no ColorThief/ColorKit dependency is needed.
The app-specific image decoder, cache and semantic-role bridge are Luma Reader code.

## 0.9.3 compatibility adjustment

MaterialColorUtilities Package.swift tools-version directive is moved to its first line; upstream algorithm sources and licenses are unchanged. Luma Reader serializes accesses at its own palette-generation boundary.
