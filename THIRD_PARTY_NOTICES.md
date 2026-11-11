# Third-party notices

## ZIPFoundation 0.9.20

https://github.com/weichsel/ZIPFoundation/tree/0.9.20

ZIPFoundation is resolved by Swift Package Manager, not vendored in this archive.
Its complete MIT license is reproduced in `ZIPFoundation-LICENSE.txt`.

## Design references

https://github.com/emilkowalski/skills

Design guidance was consulted; its instruction files are not redistributed in this project.
No Readest source code is included.

## Animation implementation and references (0.9.0)

The new page-curl mesh, edge gesture controller, reveal layout and glass wrappers are project code.
No Pow, SplitView, Grabfold, StPageFlip, Motion Primitives or private Apple framework is bundled or added as a dependency.
The earlier discussion's library names are references and alternatives, not a list of installed packages.

Reference: https://github.com/Nodlik/StPageFlip (approach to temporary visual pages)
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
