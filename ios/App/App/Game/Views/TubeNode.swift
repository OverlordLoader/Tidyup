import SpriteKit
import UIKit

// MARK: - Procedural textures

/// All textures are generated in code: no image assets needed.
enum NodeTextures {
    /// Soft radial white circle: glows, droplets, particles, ambient bubbles.
    static let softCircle: SKTexture = {
        let s: CGFloat = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            let colors = [UIColor(white: 1, alpha: 1).cgColor,
                          UIColor(white: 1, alpha: 0).cgColor]
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0, 1]) else { return }
            c.drawRadialGradient(grad,
                                 startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
                                 endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2,
                                 options: [])
        }
        return SKTexture(image: img)
    }()

    static let glow: SKTexture = softCircle

    /// Vertical gradient texture, stretched to fill the background.
    static func verticalGradient(top: UIColor, bottom: UIColor, height: Int = 64) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: height))
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            let colors = [top.cgColor, bottom.cgColor]
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0, 1]) else { return }
            c.drawLinearGradient(grad,
                                 start: CGPoint(x: 0, y: 0),
                                 end: CGPoint(x: 0, y: CGFloat(height)),
                                 options: [])
        }
        return SKTexture(image: img)
    }
}

// MARK: - Tube node

/// One test tube. Origin is at the bottom-center of the tube.
final class TubeNode: SKNode {
    let index: Int
    let tubeW: CGFloat
    let segH: CGFloat

    var tubeH: CGFloat { segH * CGFloat(tubeCapacity) + 30 }

    private var liquidLayer: SKNode!
    private var glowNode: SKSpriteNode!
    private var home: CGPoint = .zero

    init(index: Int, tubeW: CGFloat, segH: CGFloat) {
        self.index = index
        self.tubeW = tubeW
        self.segH = segH
        super.init()
        buildGlass()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    var homePosition: CGPoint {
        get { home }
        set { home = newValue; position = newValue }
    }

    private func buildGlass() {
        let w = tubeW
        let h = tubeH

        // Selection glow, hidden by default.
        glowNode = SKSpriteNode(texture: NodeTextures.glow, color: .white,
                                size: CGSize(width: w * 2.4, height: h * 1.2))
        glowNode.colorBlendFactor = 1
        glowNode.alpha = 0
        glowNode.position = CGPoint(x: 0, y: h / 2)
        glowNode.zPosition = -1
        addChild(glowNode)

        // Glass body.
        let glass = SKShapeNode(rect: CGRect(x: -w / 2, y: 0, width: w, height: h),
                                cornerRadius: w * 0.28)
        glass.fillColor = UIColor(white: 1, alpha: 0.08)
        glass.strokeColor = UIColor(white: 1, alpha: 0.55)
        glass.lineWidth = 6
        glass.zPosition = 10
        addChild(glass)

        // Specular stripe on the glass.
        let stripe = SKShapeNode(rect: CGRect(x: -w / 2 + 10, y: 16, width: 8, height: h - 32),
                                 cornerRadius: 4)
        stripe.fillColor = UIColor(white: 1, alpha: 0.20)
        stripe.strokeColor = .clear
        stripe.zPosition = 11
        addChild(stripe)

        // Liquids, clipped to the tube interior.
        let crop = SKCropNode()
        let mask = SKShapeNode(rect: CGRect(x: -w / 2 + 11, y: 11, width: w - 22, height: h - 22),
                               cornerRadius: w * 0.22)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        crop.zPosition = 5
        liquidLayer = SKNode()
        crop.addChild(liquidLayer)
        addChild(crop)
    }

    /// Rebuild the liquid segments from model state.
    func render(_ tube: TubeState, palette: [GameColor]) {
        liquidLayer.removeAllChildren()
        let w = tubeW
        for (i, colorId) in tube.segments.enumerated() {
            let color = palette[colorId % palette.count]
            let y = 13 + CGFloat(i) * segH
            let seg = SKShapeNode(rect: CGRect(x: -w / 2 + 13, y: y, width: w - 26, height: segH - 4),
                                  cornerRadius: 8)
            seg.fillColor = color.skColor
            seg.strokeColor = .clear
            liquidLayer.addChild(seg)
            if i == tube.segments.count - 1 {
                // Bright liquid surface on the top segment.
                let surface = SKShapeNode(ellipseOf: CGSize(width: w - 32, height: 15))
                surface.position = CGPoint(x: 0, y: y + segH - 5)
                surface.fillColor = color.lightSK
                surface.strokeColor = .clear
                surface.alpha = 0.95
                liquidLayer.addChild(surface)
            }
        }
    }

    func setSelected(_ selected: Bool) {
        removeAction(forKey: "lift")
        let lift = SKAction.moveTo(y: home.y + (selected ? 16 : 0), duration: 0.18)
        lift.timingMode = .easeInEaseOut
        run(lift, withKey: "lift")
        glowNode.removeAction(forKey: "glowfade")
        glowNode.run(.fadeAlpha(to: selected ? 0.45 : 0, duration: 0.2), withKey: "glowfade")
    }

    /// Juicy pop when new liquid lands.
    func popTop() {
        liquidLayer.removeAction(forKey: "pop")
        liquidLayer.setScale(1.0)
        let pop = SKAction.sequence([
            .scale(to: 1.08, duration: 0.10),
            .scale(to: 1.0, duration: 0.16),
        ])
        pop.timingMode = .easeInEaseOut
        liquidLayer.run(pop, withKey: "pop")
    }

    /// Wiggle for an illegal move. Net displacement is zero.
    func shake() {
        removeAction(forKey: "shake")
        let shake = SKAction.sequence([
            .moveBy(x: -10, y: 0, duration: 0.05),
            .moveBy(x: 20, y: 0, duration: 0.08),
            .moveBy(x: -14, y: 0, duration: 0.06),
            .moveBy(x: 4, y: 0, duration: 0.05),
        ])
        run(shake, withKey: "shake")
    }

    /// Tip toward the destination tube while pouring.
    func tilt(angle: CGFloat) {
        removeAction(forKey: "tilt")
        let a = SKAction.rotate(toAngle: angle, duration: 0.18)
        a.timingMode = .easeInEaseOut
        run(a, withKey: "tilt")
    }

    func untilt() { tilt(angle: 0) }
}
