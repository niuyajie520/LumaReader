import AppKit
import QuartzCore

/// Temporary visual leaf. The live PDF/WebKit surface remains underneath and owns text selection.
/// All strips share one CGImage; Core Animation interpolates the mesh only while a turn runs.
@MainActor
final class PageTurnCover: NSView {
    private let image: NSImage?
    private let paper: NSColor
    private var strips: [CALayer] = []
    private var shades: [CALayer] = []
    private var picture: CALayer?
    private let castShadow = CAGradientLayer()
    private(set) var progress: Double = 0
    private var forward = true
    private var style: PageTurnStyle = .natural
    private var prepared = false

    init(frame: NSRect, image: NSImage?, paper: NSColor) {
        self.image = image; self.paper = paper
        super.init(frame: frame)
        autoresizingMask = [.width, .height]; wantsLayer = true
        layer?.backgroundColor = paper.cgColor
        let picture = CALayer(); picture.frame = bounds
        if let image {
            var source = NSRect(origin:.zero,size:image.size)
            picture.contents = image.cgImage(forProposedRect:&source,context:nil,hints:nil)
        }
        picture.contentsGravity = .resize
        picture.backgroundColor = paper.cgColor
        castShadow.colors = [NSColor.clear.cgColor,NSColor.black.cgColor,NSColor.clear.cgColor]
        castShadow.startPoint = CGPoint(x:0,y:0.5); castShadow.endPoint = CGPoint(x:1,y:0.5)
        castShadow.frame = CGRect(x:0,y:0,width:64,height:bounds.height); castShadow.opacity = 0
        layer?.addSublayer(castShadow)
        layer?.addSublayer(picture); self.picture = picture
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func prepare(forward: Bool, style: PageTurnStyle) {
        guard !prepared else { return }
        prepared = true; self.forward = forward; self.style = style
        layer?.backgroundColor = NSColor.clear.cgColor
        guard style == .natural, let image else { return }
        var rect = NSRect(origin:.zero,size:image.size)
        guard let pixels = image.cgImage(forProposedRect:&rect,context:nil,hints:nil) else { return }
        picture?.removeFromSuperlayer(); picture = nil
        let count = 28
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / max(1600,bounds.width * 3)
        layer?.sublayerTransform = perspective
        for index in 0..<count {
            let leaf = CALayer()
            let width = bounds.width / CGFloat(count)
            leaf.bounds = CGRect(x:0,y:0,width:width + 0.5,height:bounds.height)
            leaf.anchorPoint = CGPoint(x:forward ? 0:1,y:0.5)
            let source = forward ? index:count - 1 - index
            let front = CALayer(); front.frame = leaf.bounds
            front.contents = pixels
            front.contentsRect = CGRect(x:CGFloat(source)/CGFloat(count),y:0,width:1/CGFloat(count),height:1)
            front.contentsGravity = .resize; front.isDoubleSided = false
            leaf.addSublayer(front)
            let back = CALayer(); back.frame = leaf.bounds
            back.backgroundColor = paper.cgColor; back.isDoubleSided = false
            back.transform = CATransform3DMakeRotation(.pi,0,1,0)
            leaf.addSublayer(back)
            let shade = CALayer(); shade.frame = leaf.bounds
            shade.backgroundColor = NSColor.black.cgColor; shade.opacity = 0
            leaf.addSublayer(shade)
            layer?.addSublayer(leaf); strips.append(leaf); shades.append(shade)
        }
    }

    private func mesh(_ value: Double) -> [(CGPoint, CATransform3D, Float)] {
        let width = bounds.width / CGFloat(max(1,strips.count))
        var x: CGFloat = 0, depth: CGFloat = 0
        return strips.indices.map { index in
            let s = (Double(index) + 0.5) / Double(strips.count)
            let angle = Double.pi * value + sin(s * .pi) * 0.85 * sin(value * .pi)
            let position = CGPoint(x:forward ? x:bounds.width - x,y:bounds.height/2)
            var transform = CATransform3DMakeTranslation(0,0,depth)
            transform = CATransform3DRotate(transform,CGFloat(forward ? -angle:angle),0,1,0)
            x += width * CGFloat(cos(angle)); depth += width * CGFloat(sin(angle)) * 0.32
            return (position,transform,Float(abs(sin(angle)) * 0.20))
        }
    }

    func preview(_ value: Double, forward: Bool, style: PageTurnStyle) {
        prepare(forward:forward,style:style)
        progress = min(1,max(0,value))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        castShadow.position = CGPoint(x:bounds.width * CGFloat(forward ? 1-progress:progress),y:bounds.height/2)
        castShadow.opacity = Float(sin(progress * .pi)*0.18)
        if strips.isEmpty {
            if style == .slide {
                picture?.transform = CATransform3DMakeTranslation(bounds.width * progress * (forward ? -1:1),0,0)
            } else {
                picture?.anchorPoint = CGPoint(x:forward ? 0:1,y:0.5)
                picture?.position = CGPoint(x:forward ? 0:bounds.width,y:bounds.height/2)
                var t = CATransform3DIdentity; t.m34 = -1 / max(1400,bounds.width * 2)
                picture?.transform = CATransform3DRotate(t,CGFloat(progress * .pi * 0.5 * (forward ? -1:1)),0,1,0)
                picture?.opacity = Float(1 - pow(progress,4))
            }
        } else {
            for (index,state) in mesh(progress).enumerated() {
                strips[index].position = state.0; strips[index].transform = state.1
                shades[index].opacity = state.2
            }
        }
        CATransaction.commit()
    }

    func turn(forward: Bool, style: PageTurnStyle, duration: Double, completion: @escaping () -> Void) {
        guard duration > 0, style != .none else { removeFromSuperview(); completion(); return }
        animate(to:1,forward:forward,style:style,duration:duration,completion:completion)
    }

    func cancel(completion: @escaping () -> Void) {
        animate(to:0,forward:forward,style:style,duration:0.22,completion:completion)
    }

    private func animate(to target: Double, forward: Bool, style: PageTurnStyle, duration: Double, completion: @escaping () -> Void) {
        prepare(forward:forward,style:style)
        let start = progress
        let samples = 32
        let values = (0...samples).map { start + (target-start)*Double($0)/Double(samples) }
        let frames = values.map { mesh($0) }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated { self?.removeFromSuperview(); completion() }
        }
        if strips.isEmpty {
            let oldTransform = picture?.presentation()?.transform ?? picture?.transform ?? CATransform3DIdentity
            let oldOpacity = picture?.opacity ?? 1
            preview(target,forward:forward,style:style)
            if let picture {
                let motion = CASpringAnimation(keyPath:"transform")
                motion.mass = 1; motion.stiffness = 260; motion.damping = 30; motion.initialVelocity = 0
                motion.duration = duration
                motion.fromValue = NSValue(caTransform3D:oldTransform)
                motion.toValue = NSValue(caTransform3D:picture.transform)
                let fade = CABasicAnimation(keyPath:"opacity"); fade.fromValue = oldOpacity; fade.toValue = picture.opacity
                let group = CAAnimationGroup(); group.animations = [motion,fade]; group.duration = duration
                group.timingFunction = CAMediaTimingFunction(name:.linear)
                picture.add(group,forKey:"turn")
            }
        } else {
            preview(target,forward:forward,style:style)
            for index in strips.indices {
                let positions = CAKeyframeAnimation(keyPath:"position")
                positions.values = frames.map { NSValue(point:$0[index].0) }
                let transforms = CAKeyframeAnimation(keyPath:"transform")
                transforms.values = frames.map { NSValue(caTransform3D:$0[index].1) }
                let group = CAAnimationGroup(); group.animations = [positions,transforms]; group.duration = duration
                group.timingFunction = CAMediaTimingFunction(controlPoints:0.22,0.72,0.18,1)
                strips[index].add(group,forKey:"curl")
                let shade = CAKeyframeAnimation(keyPath:"opacity"); shade.values = frames.map { $0[index].2 }
                shade.duration = duration; shade.timingFunction = group.timingFunction
                shades[index].add(shade,forKey:"light")
            }
        }
        let shadowPosition = CAKeyframeAnimation(keyPath:"position")
        shadowPosition.values = values.map { NSValue(point:CGPoint(x:bounds.width * CGFloat(forward ? 1-$0:$0),y:bounds.height/2)) }
        let shadowOpacity = CAKeyframeAnimation(keyPath:"opacity")
        shadowOpacity.values = values.map { sin($0 * .pi)*0.18 }
        let shadowGroup = CAAnimationGroup(); shadowGroup.animations = [shadowPosition,shadowOpacity]
        shadowGroup.duration = duration; shadowGroup.timingFunction = CAMediaTimingFunction(controlPoints:0.22,0.72,0.18,1)
        castShadow.add(shadowGroup,forKey:"cast-shadow")
        CATransaction.commit()
    }
}
