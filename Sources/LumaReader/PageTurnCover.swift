import AppKit
import QuartzCore

/// Hardware-accelerated multi-mode page-turn visual surface (`Slide`, `Push`, `Page Curl`, `Page Flip`, `Fade`).
///
/// The live `WKWebView` / `PDFView` remains underneath and owns DOM layout, text selection,
/// CSS Custom Highlights, search, and annotations without DOM cloning or re-pagination.
///
/// ### Open-Source Provenance & Attribution
/// 1. **xissburg/XBPageCurl** (`https://github.com/xissburg/XBPageCurl`, MIT License, Copyright (c) xissburg):
///    Virtual rolling cylinder projection (`cylinderPosition`, `cylinderAngle`, `cylinderRadius`) used in
///    `Page Curl` (`.curl`) mode: strips ahead of the cylinder axis remain flat (`z = 0`), strips along the
///    semi-cylinder arc (`0 < theta <= pi`) wrap around radius `R(p)` in 3D (`x = axis + R*sin(theta)`,
///    `z = R*(1 - cos(theta))`), and strips past the cylinder apex project onto the turned backside plane.
/// 2. **Nodlik/StPageFlip** (`https://github.com/Nodlik/StPageFlip`, v2.0.7, MIT License, Copyright (c) 2020 Nodlik):
///    `FlipCalculation` & `Shadow` 3-layer lighting model (`castShadow` drop shadow on the revealed page,
///    `creaseShadow` along the fold tangent/spine, and paper-tinted `backPage` specular highlight) and
///    `PageDensity.HARD` rigid spine rotation used in `Page Flip` (`.flip`) mode.
/// 3. **johnfactotum/foliate-js** (`https://github.com/johnfactotum/foliate-js`, `paginator.js`, MIT License) &
///    **readest/readest** (`https://github.com/readest/readest`, PR #4940 / Issue #5288):
///    Compositor-synchronized `Slide` (`.slide`) and `Push` (`.push`) dual-surface transitions and
///    zero-flash opaque paper underlay during interactive drag and chapter transitions.
@MainActor
final class PageTurnCover: NSView {
    private let image: NSImage?
    private let paper: NSColor
    private var strips: [CALayer] = []
    private var shades: [CALayer] = []
    private var backs: [CALayer] = []
    private var picture: CALayer?
    private let underlaySheet = CALayer()
    private let backPage = CALayer()
    private let castShadow = CAGradientLayer()
    private let creaseShadow = CAGradientLayer()
    private let spineShadow = CAGradientLayer()
    private(set) var progress: Double = 0
    private(set) var isAnimatingTurn = false
    private var forward = true
    private var style: PageTurnStyle = .slide
    private var prepared = false

    init(frame: NSRect, image: NSImage?, paper: NSColor) {
        self.image = image
        self.paper = paper
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.masksToBounds = true
        // Start with opaque paper backing so chapter switches never flash white before `painted`.
        layer?.backgroundColor = paper.cgColor

        // Opaque paper underlay used during interactive drag preview (before the underlying
        // WebView has turned to the new page) so dragging never exposes a duplicate of the old page.
        underlaySheet.frame = bounds
        underlaySheet.backgroundColor = paper.cgColor
        underlaySheet.isHidden = true
        layer?.addSublayer(underlaySheet)

        // Drop shadow cast onto the revealed underlying page (StPageFlip Shadow model).
        castShadow.colors = [
            NSColor.black.withAlphaComponent(0.0).cgColor,
            NSColor.black.withAlphaComponent(0.32).cgColor,
            NSColor.black.withAlphaComponent(0.10).cgColor,
            NSColor.black.withAlphaComponent(0.0).cgColor
        ]
        castShadow.locations = [0.0, 0.38, 0.72, 1.0]
        castShadow.startPoint = CGPoint(x: 0, y: 0.5)
        castShadow.endPoint = CGPoint(x: 1, y: 0.5)
        castShadow.frame = CGRect(x: 0, y: 0, width: 84, height: bounds.height)
        castShadow.opacity = 0
        layer?.addSublayer(castShadow)

        // Rigid backside leaf for Page Flip (.flip) mode (StPageFlip PageDensity.HARD).
        backPage.frame = bounds
        backPage.backgroundColor = Self.tintedBacksideColor(from: paper).cgColor
        backPage.isDoubleSided = false
        backPage.isHidden = true
        layer?.addSublayer(backPage)

        // Primary front page surface.
        let picture = CALayer()
        picture.frame = bounds
        if let image {
            var source = NSRect(origin: .zero, size: image.size)
            picture.contents = image.cgImage(forProposedRect: &source, context: nil, hints: nil)
        }
        picture.contentsGravity = .resize
        picture.backgroundColor = paper.cgColor
        picture.isDoubleSided = false
        layer?.addSublayer(picture)
        self.picture = picture

        // Inner fold / curl tangent crease shadow (StPageFlip FlipCalculation crease gradient).
        creaseShadow.colors = [
            NSColor.black.withAlphaComponent(0.0).cgColor,
            NSColor.black.withAlphaComponent(0.22).cgColor,
            NSColor.white.withAlphaComponent(0.08).cgColor,
            NSColor.black.withAlphaComponent(0.0).cgColor
        ]
        creaseShadow.locations = [0.0, 0.45, 0.78, 1.0]
        creaseShadow.startPoint = CGPoint(x: 0, y: 0.5)
        creaseShadow.endPoint = CGPoint(x: 1, y: 0.5)
        creaseShadow.frame = CGRect(x: 0, y: 0, width: 52, height: bounds.height)
        creaseShadow.opacity = 0
        layer?.addSublayer(creaseShadow)

        // Book spine shadow for Page Flip (.flip) mode.
        spineShadow.colors = [
            NSColor.black.withAlphaComponent(0.28).cgColor,
            NSColor.black.withAlphaComponent(0.08).cgColor,
            NSColor.black.withAlphaComponent(0.0).cgColor
        ]
        spineShadow.startPoint = CGPoint(x: 0, y: 0.5)
        spineShadow.endPoint = CGPoint(x: 1, y: 0.5)
        spineShadow.frame = CGRect(x: 0, y: 0, width: 36, height: bounds.height)
        spineShadow.opacity = 0
        layer?.addSublayer(spineShadow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private static func tintedBacksideColor(from paper: NSColor) -> NSColor {
        guard let rgb = paper.usingColorSpace(.sRGB) else { return paper }
        let lum = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        let delta: CGFloat = lum > 0.5 ? -0.035 : 0.045
        return NSColor(
            srgbRed: min(1, max(0, rgb.redComponent + delta)),
            green: min(1, max(0, rgb.greenComponent + delta)),
            blue: min(1, max(0, rgb.blueComponent + delta * 0.9)),
            alpha: 1.0
        )
    }

    private func prepare(forward: Bool, style: PageTurnStyle) {
        guard !prepared else { return }
        prepared = true
        self.forward = forward
        self.style = style
        layer?.backgroundColor = NSColor.clear.cgColor
        backPage.isHidden = style != .flip
        castShadow.startPoint = CGPoint(x: forward ? 0 : 1, y: 0.5)
        castShadow.endPoint = CGPoint(x: forward ? 1 : 0, y: 0.5)
        creaseShadow.startPoint = CGPoint(x: forward ? 0 : 1, y: 0.5)
        creaseShadow.endPoint = CGPoint(x: forward ? 1 : 0, y: 0.5)
        spineShadow.startPoint = CGPoint(x: forward ? 0 : 1, y: 0.5)
        spineShadow.endPoint = CGPoint(x: forward ? 1 : 0, y: 0.5)

        guard style == .curl, let image else { return }
        var rect = NSRect(origin: .zero, size: image.size)
        guard let pixels = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
        picture?.removeFromSuperlayer()
        picture = nil

        // XBPageCurl cylindrical strip mesh: 32 vertical strips sharing one CGImage texture.
        let count = 32
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / max(1500, bounds.width * 2.6)
        layer?.sublayerTransform = perspective
        let backsideFill = Self.tintedBacksideColor(from: paper).cgColor

        for index in 0..<count {
            let leaf = CALayer()
            let width = bounds.width / CGFloat(count)
            leaf.bounds = CGRect(x: 0, y: 0, width: width + 0.65, height: bounds.height)
            leaf.anchorPoint = CGPoint(x: forward ? 0 : 1, y: 0.5)
            let source = forward ? index : count - 1 - index

            let front = CALayer()
            front.frame = leaf.bounds
            front.contents = pixels
            front.contentsRect = CGRect(x: CGFloat(source) / CGFloat(count), y: 0, width: 1 / CGFloat(count), height: 1)
            front.contentsGravity = .resize
            front.isDoubleSided = false
            leaf.addSublayer(front)

            let back = CALayer()
            back.frame = leaf.bounds
            back.backgroundColor = backsideFill
            back.contents = pixels
            back.contentsRect = front.contentsRect
            back.contentsGravity = .resize
            back.opacity = 0.96
            back.isDoubleSided = false
            back.transform = CATransform3DMakeRotation(.pi, 0, 1, 0)
            // Paper-tinted translucent veil on the backside so bleed-through looks like real book paper.
            let backVeil = CALayer()
            backVeil.frame = back.bounds
            backVeil.backgroundColor = backsideFill
            backVeil.opacity = 0.88
            back.addSublayer(backVeil)
            leaf.addSublayer(back)

            let shade = CALayer()
            shade.frame = leaf.bounds
            shade.backgroundColor = NSColor.black.cgColor
            shade.opacity = 0
            leaf.addSublayer(shade)

            layer?.addSublayer(leaf)
            strips.append(leaf)
            backs.append(back)
            shades.append(shade)
        }
        // Keep creaseShadow above the curl strips.
        creaseShadow.removeFromSuperlayer()
        layer?.addSublayer(creaseShadow)
    }

    /// XBPageCurl rolling cylinder projection + StPageFlip cylindrical self-shading.
    ///
    /// Projects strip `index` (`s in [0, 1]` from spine to turning edge) onto a virtual cylinder
    /// whose axis sweeps across the page as `value` progresses from `0` to `1`.
    private func mesh(_ value: Double) -> [(position: CGPoint, transform: CATransform3D, shade: Float)] {
        let count = max(1, strips.count)
        let width = bounds.width / CGFloat(count)
        let p = min(1, max(0, value))
        // Virtual cylinder radius in normalized page coordinates (XBPageCurl cylinderRadius).
        let radiusNorm = 0.14 + 0.08 * sin(p * .pi)
        // Cylinder tangent position sweeping from the outer edge (1.0) past the spine (-0.25).
        let cylinderAxis = 1.0 - p * (1.0 + .pi * radiusNorm * 0.85)
        var x: CGFloat = 0
        var depth: CGFloat = 0

        return strips.indices.map { index in
            let s = (Double(index) + 0.5) / Double(count)
            let distPastAxis = s - cylinderAxis
            let localAngle: Double
            if distPastAxis <= 0 {
                // Flat region ahead of the rolling cylinder.
                localAngle = 0
            } else {
                // Smoothly wrap around the cylinder (0 -> pi) with C1-continuous entry.
                let wrapped = min(.pi, distPastAxis / max(0.04, radiusNorm))
                localAngle = wrapped
            }
            // Blend with global lift at high progress so the final unroll completes cleanly at p = 1.
            let globalTurn = pow(p, 1.35) * .pi
            let angle = min(.pi, max(localAngle, globalTurn * (0.65 + 0.35 * sin(s * .pi))))

            let position = CGPoint(x: forward ? x : bounds.width - x, y: bounds.height / 2)
            var transform = CATransform3DMakeTranslation(0, 0, depth)
            transform = CATransform3DRotate(transform, CGFloat(forward ? -angle : angle), 0, 1, 0)

            x += width * CGFloat(cos(angle))
            depth += width * CGFloat(sin(angle)) * 0.36

            // Lambertian + crease self-shading along the cylinder arc (StPageFlip / XBPageCurl shader).
            let cylinderShade = sin(angle) * 0.19 + (angle > .pi * 0.5 ? 0.06 * sin(p * .pi) : 0)
            return (position, transform, Float(min(0.28, max(0, cylinderShade))))
        }
    }

    /// Updates the cover to an interactive or endpoint progress (`0...1`).
    /// When `interactive == true`, `underlaySheet` stays visible so dragging before the
    /// underlying WebView turns does not expose a duplicate of the un-turned page.
    func preview(_ value: Double, forward: Bool, style: PageTurnStyle, interactive: Bool = false) {
        prepare(forward: forward, style: style)
        progress = min(1, max(0, value))
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        underlaySheet.frame = bounds
        underlaySheet.isHidden = !interactive || style == .none

        let edgeX = bounds.width * CGFloat(forward ? 1 - progress : progress)
        castShadow.bounds = CGRect(x: 0, y: 0, width: style == .curl ? 96 : 68, height: bounds.height)
        castShadow.position = CGPoint(x: edgeX, y: bounds.height / 2)
        let shadowPeak: Double = {
            switch style {
            case .fade, .none: return 0
            case .push: return 0.14
            case .slide: return 0.22
            case .curl: return 0.28
            case .flip: return 0.26
            }
        }()
        castShadow.opacity = Float(sin(progress * .pi) * shadowPeak)

        creaseShadow.bounds = CGRect(x: 0, y: 0, width: 54, height: bounds.height)
        creaseShadow.position = CGPoint(x: edgeX, y: bounds.height / 2)
        creaseShadow.opacity = style == .curl ? Float(sin(progress * .pi) * 0.22) : 0

        let spineX: CGFloat = forward ? 18 : bounds.width - 18
        spineShadow.bounds = CGRect(x: 0, y: 0, width: 36, height: bounds.height)
        spineShadow.position = CGPoint(x: spineX, y: bounds.height / 2)
        spineShadow.opacity = style == .flip ? Float(sin(progress * .pi) * 0.24) : 0

        if strips.isEmpty {
            guard let picture else { CATransaction.commit(); return }
            picture.isHidden = false
            picture.bounds = bounds
            picture.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            picture.position = CGPoint(x: bounds.midX, y: bounds.midY)
            picture.opacity = 1
            var transform = CATransform3DIdentity

            switch style {
            case .slide:
                // Readest / foliate-js Cover-Slide: outgoing page slides smoothly across the viewport
                // with a trailing shadow over the incoming page.
                picture.isHidden = false
                backPage.isHidden = true
                let dx = bounds.width * CGFloat(progress) * (forward ? -1 : 1)
                transform = CATransform3DMakeTranslation(dx, 0, 0)
            case .push:
                // foliate-js / Readest Push: edge-to-edge 1:1 horizontal translation with zero scale distortion.
                picture.isHidden = false
                backPage.isHidden = true
                let dx = bounds.width * CGFloat(progress) * (forward ? -1 : 1)
                transform = CATransform3DMakeTranslation(dx, 0, 0)
            case .flip:
                // StPageFlip (PageDensity.HARD) + Flipbook for macOS 3D spine rotation.
                picture.isHidden = false
                backPage.isHidden = false
                let anchorX: CGFloat = forward ? 0 : 1
                let position = CGPoint(x: bounds.width * anchorX, y: bounds.midY)
                picture.anchorPoint = CGPoint(x: anchorX, y: 0.5)
                picture.position = position
                backPage.anchorPoint = picture.anchorPoint
                backPage.position = position
                backPage.bounds = picture.bounds
                var perspective = CATransform3DIdentity
                perspective.m34 = -1 / max(1400, bounds.width * 2.2)
                let angle = CGFloat(progress) * .pi * (forward ? -1 : 1)
                let turn = CATransform3DRotate(perspective, angle, 0, 1, 0)
                picture.transform = turn
                backPage.transform = CATransform3DConcat(turn, CATransform3DMakeRotation(.pi, 0, 1, 0))
                picture.opacity = 1
                backPage.opacity = 1
            case .fade:
                // Pure cross-dissolve over the already-painted incoming page.
                picture.isHidden = false
                backPage.isHidden = true
                picture.opacity = Float(max(0, 1 - progress))
                transform = CATransform3DMakeScale(1 - 0.008 * CGFloat(progress), 1 - 0.008 * CGFloat(progress), 1)
            case .curl, .none:
                picture.isHidden = true
            }
            if style != .flip {
                picture.transform = transform
            }
        } else {
            for (index, state) in mesh(progress).enumerated() {
                strips[index].position = state.position
                strips[index].transform = state.transform
                shades[index].opacity = state.shade
            }
        }
        CATransaction.commit()
    }

    /// Runs the completion animation from the current `progress` to `1.0` while synchronizing
    /// the incoming `targetView`'s layer in the same Core Animation `CATransaction` for `.push` and `.slide`.
    func turn(
        forward: Bool,
        style: PageTurnStyle,
        duration: Double,
        targetView: NSView? = nil,
        completion: @escaping () -> Void
    ) {
        guard duration > 0, style != .none else {
            targetView?.layer?.removeAnimation(forKey: "luma-incoming-page")
            removeFromSuperview()
            completion()
            return
        }
        animate(to: 1, forward: forward, style: style, duration: duration, targetView: targetView, completion: completion)
    }

    func cancel(duration: Double = 0.20, completion: @escaping () -> Void) {
        animate(to: 0, forward: forward, style: style, duration: duration, targetView: nil, completion: completion)
    }

    private func timingFunction(for style: PageTurnStyle) -> CAMediaTimingFunction {
        switch style {
        case .slide:
            // Readest / foliate-js smooth cubic-bezier settle
            return CAMediaTimingFunction(controlPoints: 0.22, 0.61, 0.36, 1.0)
        case .push:
            return CAMediaTimingFunction(controlPoints: 0.20, 0.72, 0.24, 1.0)
        case .curl:
            return CAMediaTimingFunction(controlPoints: 0.22, 0.72, 0.18, 1.0)
        case .flip:
            return CAMediaTimingFunction(controlPoints: 0.30, 0.08, 0.20, 1.0)
        case .fade, .none:
            return CAMediaTimingFunction(controlPoints: 0.25, 0.10, 0.25, 1.0)
        }
    }

    private func animate(
        to target: Double,
        forward: Bool,
        style: PageTurnStyle,
        duration: Double,
        targetView: NSView?,
        completion: @escaping () -> Void
    ) {
        prepare(forward: forward, style: style)
        isAnimatingTurn = true
        let start = progress
        let samples = 36
        let values = (0...samples).map { start + (target - start) * Double($0) / Double(samples) }
        let frames = strips.isEmpty ? [] : values.map { mesh($0) }
        let curve = timingFunction(for: style)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self, weak targetView] in
            MainActor.assumeIsolated {
                targetView?.layer?.removeAnimation(forKey: "luma-incoming-page")
                self?.isAnimatingTurn = false
                self?.removeFromSuperview()
                completion()
            }
        }

        // Synchronize incoming page layer in the exact same Core Animation transaction for Push and Slide.
        // This eliminates async WebKit JS IPC races, white flashes, and the #luma-viewport -50% transform jump.
        if target == 1, let incomingLayer = targetView?.layer, (style == .push || style == .slide) {
            let remainingFraction = CGFloat(max(0, 1.0 - start))
            // Push translates the full remaining page width (100%); Slide adds subtle 16% depth parallax.
            let travelFactor: CGFloat = style == .push ? 1.0 : 0.16
            let startOffset = bounds.width * travelFactor * remainingFraction * (forward ? 1 : -1)
            let incomingAnim = CABasicAnimation(keyPath: "transform.translation.x")
            incomingAnim.fromValue = startOffset
            incomingAnim.toValue = 0
            incomingAnim.duration = duration
            incomingAnim.timingFunction = curve
            incomingLayer.add(incomingAnim, forKey: "luma-incoming-page")
        }

        if strips.isEmpty {
            let oldTransform = picture?.presentation()?.transform ?? picture?.transform ?? CATransform3DIdentity
            let oldOpacity = picture?.presentation()?.opacity ?? picture?.opacity ?? 1
            let oldBackTransform = backPage.presentation()?.transform ?? backPage.transform
            preview(target, forward: forward, style: style, interactive: target == 0)

            if let picture {
                let motion = CABasicAnimation(keyPath: "transform")
                motion.fromValue = NSValue(caTransform3D: oldTransform)
                motion.toValue = NSValue(caTransform3D: picture.transform)
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = oldOpacity
                fade.toValue = picture.opacity
                let group = CAAnimationGroup()
                group.animations = [motion, fade]
                group.duration = duration
                group.timingFunction = curve
                picture.add(group, forKey: "turn")

                if style == .flip {
                    let backMotion = CABasicAnimation(keyPath: "transform")
                    backMotion.fromValue = NSValue(caTransform3D: oldBackTransform)
                    backMotion.toValue = NSValue(caTransform3D: backPage.transform)
                    let backFade = CABasicAnimation(keyPath: "opacity")
                    backFade.fromValue = oldOpacity
                    backFade.toValue = 1
                    let backGroup = CAAnimationGroup()
                    backGroup.animations = [backMotion, backFade]
                    backGroup.duration = duration
                    backGroup.timingFunction = curve
                    backPage.add(backGroup, forKey: "turn")
                }
            }
        } else {
            preview(target, forward: forward, style: style, interactive: target == 0)
            for index in strips.indices {
                let positions = CAKeyframeAnimation(keyPath: "position")
                positions.values = frames.map { NSValue(point: $0[index].position) }
                let transforms = CAKeyframeAnimation(keyPath: "transform")
                transforms.values = frames.map { NSValue(caTransform3D: $0[index].transform) }
                let group = CAAnimationGroup()
                group.animations = [positions, transforms]
                group.duration = duration
                group.timingFunction = curve
                strips[index].add(group, forKey: "curl")

                let shade = CAKeyframeAnimation(keyPath: "opacity")
                shade.values = frames.map { $0[index].shade }
                shade.duration = duration
                shade.timingFunction = curve
                shades[index].add(shade, forKey: "light")
            }
        }

        let shadowPeak: Double = {
            switch style {
            case .fade, .none: return 0
            case .push: return 0.14
            case .slide: return 0.22
            case .curl: return 0.28
            case .flip: return 0.26
            }
        }()
        let shadowPosition = CAKeyframeAnimation(keyPath: "position")
        shadowPosition.values = values.map {
            NSValue(point: CGPoint(x: bounds.width * CGFloat(forward ? 1 - $0 : $0), y: bounds.height / 2))
        }
        let shadowOpacity = CAKeyframeAnimation(keyPath: "opacity")
        shadowOpacity.values = values.map { sin($0 * .pi) * shadowPeak }
        let shadowGroup = CAAnimationGroup()
        shadowGroup.animations = [shadowPosition, shadowOpacity]
        shadowGroup.duration = duration
        shadowGroup.timingFunction = curve
        castShadow.add(shadowGroup, forKey: "cast-shadow")

        if style == .curl {
            let creasePosition = CAKeyframeAnimation(keyPath: "position")
            creasePosition.values = shadowPosition.values
            let creaseOpacity = CAKeyframeAnimation(keyPath: "opacity")
            creaseOpacity.values = values.map { sin($0 * .pi) * 0.22 }
            let creaseGroup = CAAnimationGroup()
            creaseGroup.animations = [creasePosition, creaseOpacity]
            creaseGroup.duration = duration
            creaseGroup.timingFunction = curve
            creaseShadow.add(creaseGroup, forKey: "crease-shadow")
        } else if style == .flip {
            let spineOpacity = CAKeyframeAnimation(keyPath: "opacity")
            spineOpacity.values = values.map { sin($0 * .pi) * 0.24 }
            spineOpacity.duration = duration
            spineOpacity.timingFunction = curve
            spineShadow.add(spineOpacity, forKey: "spine-shadow")
        }

        CATransaction.commit()
    }
}
