import SpriteKit
import UIKit

/// SpriteKit playfield: renders tubes, pour animations, and celebrations.
/// The GameEngine owns rules and state; this scene owns the juice.
final class BoardScene: SKScene {
    private weak var engine: GameEngine?
    private var tubeNodes: [TubeNode] = []
    private var visualTubes: [TubeState] = []
    private var eventQueue: [GameEvent] = []
    private var animating = false
    private let palette = Palette.all

    private var tubeW: CGFloat = 68
    private var segH: CGFloat = 46

    init(size: CGSize, engine: GameEngine) {
        self.engine = engine
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMove(to view: SKView) {
        buildBackground()
        buildBoard()
        if let engine {
            visualTubes = engine.tubes
            renderAll()
        }
        startAmbientBubbles()
    }

    // MARK: - Background

    private func buildBackground() {
        let tex = NodeTextures.verticalGradient(top: UIColor(hex: 0x2B1B4D),
                                                bottom: UIColor(hex: 0x17102E))
        let bg = SKSpriteNode(texture: tex, size: CGSize(width: size.width, height: size.height + 2))
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -10
        addChild(bg)

        let glows: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (0.20, 0.78, 150, 0xFF5FD2),
            (0.85, 0.38, 170, 0x3AB6FF),
            (0.68, 0.88, 120, 0xA259FF),
        ]
        for (fx, fy, r, hex) in glows {
            let g = SKSpriteNode(texture: NodeTextures.glow, color: UIColor(hex: hex),
                                 size: CGSize(width: r * 2, height: r * 2))
            g.colorBlendFactor = 1
            g.alpha = 0.14
            g.position = CGPoint(x: size.width * fx, y: size.height * fy)
            g.zPosition = -9
            addChild(g)
        }
    }

    private func startAmbientBubbles() {
        for _ in 0..<10 {
            let b = SKSpriteNode(texture: NodeTextures.softCircle, color: .white,
                                 size: CGSize(width: 26, height: 26))
            b.colorBlendFactor = 1
            b.alpha = 0.10
            b.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                 y: CGFloat.random(in: 0...size.height))
            b.zPosition = -8
            addChild(b)
            let drift = SKAction.sequence([
                .moveBy(x: CGFloat.random(in: -40...40),
                        y: CGFloat.random(in: 60...140),
                        duration: Double.random(in: 6...10)),
                .fadeAlpha(to: 0, duration: 1.0),
                .run { [weak b, weak self] in
                    b?.position = CGPoint(x: CGFloat.random(in: 0...(self?.size.width ?? 300)), y: -30)
                    b?.alpha = 0.10
                },
            ])
            b.run(.repeatForever(drift))
        }
    }

    // MARK: - Board layout

    private func buildBoard() {
        guard let engine else { return }
        let n = engine.tubes.count
        let cols = n <= 4 ? n : (n <= 6 ? 3 : (n <= 8 ? 4 : 5))
        let rows = (n + cols - 1) / cols

        var w: CGFloat = 68
        var s: CGFloat = 46
        let sx: CGFloat = 20
        let sy: CGFloat = 30
        var gridW = CGFloat(cols) * w + CGFloat(cols - 1) * sx
        let maxW = size.width - 32
        if gridW > maxW {
            let k = maxW / gridW
            w *= k
            s *= k
            gridW = CGFloat(cols) * w + CGFloat(cols - 1) * sx
        }
        tubeW = w
        segH = s
        let tubeH = s * CGFloat(tubeCapacity) + 30
        let gridH = CGFloat(rows) * tubeH + CGFloat(rows - 1) * sy

        let cx = size.width / 2
        let cy = size.height / 2 + 24
        let topY = cy + gridH / 2
        for i in 0..<n {
            let r = i / cols
            let c = i % cols
            let inRow = min(cols, n - r * cols)
            let rowW = CGFloat(inRow) * w + CGFloat(inRow - 1) * sx
            let x = cx - rowW / 2 + CGFloat(c) * (w + sx) + w / 2
            let y = topY - CGFloat(r) * (tubeH + sy) - tubeH
            let node = TubeNode(index: i, tubeW: w, segH: s)
            node.homePosition = CGPoint(x: x, y: y)
            node.zPosition = 0
            addChild(node)
            tubeNodes.append(node)
        }
    }

    private func renderAll() {
        for (i, node) in tubeNodes.enumerated() where i < visualTubes.count {
            node.render(visualTubes[i], palette: palette)
            node.setSelected(false)
            node.setScale(1.0)
            node.zRotation = 0
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine, let touch = touches.first else { return }
        let p = touch.location(in: self)
        var node: SKNode? = atPoint(p)
        while let n = node, !(n is TubeNode) { node = n.parent }
        if let tube = node as? TubeNode {
            engine.tapTube(tube.index)
        }
    }

    // MARK: - Event queue

    /// Serializes animations so pour -> complete -> win always play in order.
    func handle(_ event: GameEvent) {
        eventQueue.append(event)
        pump()
    }

    private func pump() {
        guard !animating, let event = eventQueue.first else { return }
        eventQueue.removeFirst()
        animating = true
        switch event {
        case .selected(let i):
            animateSelect(i, selected: true) { self.done() }
        case .deselected(let i):
            animateSelect(i, selected: false) { self.done() }
        case .pour(let move):
            animatePour(move) { self.done() }
        case .tubeCompleted(let i):
            animateComplete(i) { self.done() }
        case .levelWon(let stars):
            animateWin(stars: stars) { self.done() }
        case .illegal(let i):
            animateIllegal(i) { self.done() }
        case .stateRestored:
            if let engine { visualTubes = engine.tubes }
            renderAll()
            done()
        }
    }

    private func done() {
        animating = false
        if eventQueue.isEmpty {
            engine?.setBusy(false)
        } else {
            pump()
        }
    }

    // MARK: - Animations

    private func animateSelect(_ index: Int, selected: Bool, completion: @escaping () -> Void) {
        guard index < tubeNodes.count else { completion(); return }
        if selected {
            SoundManager.shared.play(.click)
            Haptics.select()
        } else {
            SoundManager.shared.play(.click)
            Haptics.tap()
        }
        tubeNodes[index].setSelected(selected)
        run(.wait(forDuration: 0.20), completion: completion)
    }

    private func animatePour(_ move: PourMove, completion: @escaping () -> Void) {
        guard move.from < tubeNodes.count, move.to < tubeNodes.count,
              let engine else { completion(); return }
        let fromNode = tubeNodes[move.from]
        let toNode = tubeNodes[move.to]
        let color = palette[move.color % palette.count].skColor

        // The pour consumes the selection: drop the source tube back down.
        fromNode.setSelected(false)

        // Liquid leaves the source immediately; the stream sells the travel.
        visualTubes[move.from].segments.removeLast(move.count)
        fromNode.render(visualTubes[move.from], palette: palette)
        let dx = toNode.position.x - fromNode.position.x
        fromNode.tilt(angle: dx > 0 ? -0.4 : 0.4)
        SoundManager.shared.play(.pour)

        let start = fromNode.convert(CGPoint(x: 0, y: fromNode.tubeH + 6), to: self)
        let end = toNode.convert(CGPoint(x: 0, y: toNode.tubeH + 6), to: self)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end,
                          control: CGPoint(x: (start.x + end.x) / 2,
                                           y: max(start.y, end.y) + 70))
        for k in 0..<3 {
            let blob = SKSpriteNode(texture: NodeTextures.softCircle, color: color,
                                    size: CGSize(width: 20, height: 20))
            blob.colorBlendFactor = 1
            blob.position = start
            blob.zPosition = 20
            addChild(blob)
            let follow = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.36)
            follow.timingMode = .easeIn
            blob.run(.sequence([
                .wait(forDuration: 0.16 + Double(k) * 0.07),
                follow,
                .removeFromParent(),
            ]))
        }

        let arrive = SKAction.sequence([
            .wait(forDuration: 0.16 + 0.36 + 0.14),
            .run { [weak self] in
                guard let self else { return }
                self.visualTubes = engine.tubes
                toNode.render(self.visualTubes[move.to], palette: self.palette)
                toNode.popTop()
                self.burst(at: end, colors: [color, .white], count: 14,
                           speed: 160, lifetime: 0.45, scale: 0.35)
                SoundManager.shared.play(.pop)
                Haptics.pour()
            },
            .wait(forDuration: 0.22),
            .run { fromNode.untilt() },
            .wait(forDuration: 0.18),
        ])
        run(arrive, completion: completion)
    }

    private func animateComplete(_ index: Int, completion: @escaping () -> Void) {
        guard index < tubeNodes.count else { completion(); return }
        let node = tubeNodes[index]
        let pos = node.convert(CGPoint(x: 0, y: node.tubeH / 2), to: self)
        burst(at: pos,
              colors: [.white, UIColor(hex: 0xFFD60A), UIColor(hex: 0xFF9F1C)],
              count: 30, speed: 260, lifetime: 0.7, scale: 0.4)
        SoundManager.shared.play(.complete)
        Haptics.complete()
        let pop = SKAction.sequence([
            .scale(to: 1.10, duration: 0.12),
            .scale(to: 1.0, duration: 0.20),
        ])
        pop.timingMode = .easeInEaseOut
        node.run(pop, completion: completion)
    }

    private func animateIllegal(_ index: Int, completion: @escaping () -> Void) {
        guard index < tubeNodes.count else { completion(); return }
        SoundManager.shared.play(.error)
        Haptics.error()
        tubeNodes[index].shake()
        run(.wait(forDuration: 0.32), completion: completion)
    }

    private func animateWin(stars: Int, completion: @escaping () -> Void) {
        SoundManager.shared.play(.win)
        Haptics.win()
        let e = SKEmitterNode()
        e.particleTexture = NodeTextures.softCircle
        e.numParticlesToEmit = 160
        e.particleBirthRate = 90
        e.particleLifetime = 2.6
        e.particleLifetimeRange = 0.8
        e.particlePositionRange = CGVector(dx: size.width, dy: 10)
        e.position = CGPoint(x: size.width / 2, y: size.height + 20)
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.35
        e.particleSpeed = 240
        e.particleSpeedRange = 120
        e.yAcceleration = -260
        e.particleScale = 0.45
        e.particleScaleRange = 0.25
        e.particleAlpha = 1
        e.particleAlphaSpeed = -0.25
        e.particleRotationSpeed = 3
        e.particleRotationRange = 6
        let colors = palette.map { $0.skColor }
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: colors,
            times: colors.indices.map { NSNumber(value: Double($0) / Double(max(colors.count - 1, 1))) })
        e.zPosition = 60
        addChild(e)
        run(.sequence([
            .wait(forDuration: 2.4),
            .run { e.removeFromParent() },
        ]), completion: { [weak self] in
            self?.engine?.celebrationFinished()
            completion()
        })
    }

    // MARK: - Particles

    private func burst(at pos: CGPoint, colors: [SKColor], count: Int,
                       speed: CGFloat, lifetime: CGFloat, scale: CGFloat) {
        let e = SKEmitterNode()
        e.particleTexture = NodeTextures.softCircle
        e.numParticlesToEmit = count
        e.particleBirthRate = CGFloat(count) / 0.15
        e.particleLifetime = lifetime
        e.particleLifetimeRange = lifetime * 0.4
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.6
        e.emissionAngleRange = .pi * 2
        e.particleScale = scale
        e.particleScaleRange = scale * 0.5
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1.2
        if colors.count == 1 {
            e.particleColor = colors[0]
        } else {
            e.particleColorSequence = SKKeyframeSequence(
                keyframeValues: colors,
                times: colors.indices.map { NSNumber(value: Double($0) / Double(max(colors.count - 1, 1))) })
        }
        e.particleBlendMode = .add
        e.position = pos
        e.zPosition = 50
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.4), .removeFromParent()]))
    }
}
