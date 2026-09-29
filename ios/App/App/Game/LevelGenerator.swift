import Foundation

// MARK: - Deterministic RNG

/// Tiny xorshift RNG so level N is identical on every device and every launch.
/// No level storage needed; generation is cheap enough to run on demand.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }
}

// MARK: - Level generator

enum LevelGenerator {
    static let totalLevels = 50

    /// Difficulty ramp: more colors, fewer empty tubes as levels progress.
    /// Levels 0-4 are tutorial-gentle (3 colors, 2 spare tubes).
    static func config(for index: Int) -> (colors: Int, emptyTubes: Int) {
        switch index {
        case 0..<5: return (3, 2)
        case 5..<12: return (4, 2)
        case 12..<20: return (5, 2)
        case 20..<28: return (6, 2)
        case 28..<36: return (6, 1)
        case 36..<44: return (7, 1)
        default: return (8, 1)
        }
    }

    static func generate(index: Int) -> LevelDef {
        var salt: UInt64 = 0
        while true {
            var rng = SeededRNG(seed: UInt64(index &+ 1) &* 0x9E3779B97F4A7C15 &+ salt &+ 0x1234_5678)
            if let level = shuffled(index: index, rng: &rng) { return level }
            salt &+= 1
        }
    }

    /// Build a level by starting from the solved state and applying random
    /// single-segment reverse moves. Two constraints keep every inverse
    /// provably legal:
    ///  1. The segment may not land on its own color (no merging), so each
    ///     inverse is a single-segment pour and replay restores state exactly.
    ///  2. Removing the top segment must leave the same color or an empty
    ///     tube, so the inverse forward pour always has a legal destination.
    /// Every shipped level is then CERTIFIED: the recorded inverse sequence is
    /// replayed through the real gameplay rules, and the deal is accepted only
    /// if every inverse is legal and the board ends solved.
    private static func shuffled(index: Int, rng: inout SeededRNG) -> LevelDef? {
        let (colors, emptyTubes) = config(for: index)
        let total = colors + emptyTubes
        var tubes: [TubeState] = (0..<colors).map { color in
            TubeState(segments: Array(repeating: color, count: tubeCapacity))
        } + Array(repeating: TubeState(segments: []), count: emptyTubes)

        struct ReverseMove { let from: Int; let to: Int; let color: Int }
        var reverse: [ReverseMove] = []

        let targetMoves = 10 + index * 2
        var attempts = 0
        while reverse.count < targetMoves && attempts < targetMoves * 100 {
            attempts += 1
            let s = Int.random(in: 0..<total, using: &rng)
            let d = Int.random(in: 0..<total, using: &rng)
            if s == d { continue }
            // Never immediately undo the previous reverse move.
            if let last = reverse.last, last.from == d && last.to == s { continue }
            guard !tubes[s].isEmpty, !tubes[d].isFull else { continue }
            let color = tubes[s].segments.last!
            if tubes[d].topColor == color { continue }          // (1) no merging
            let below = tubes[s].segments.dropLast().last
            guard below == nil || below == color else { continue } // (2) clean removal
            tubes[s].segments.removeLast()
            tubes[d].segments.append(color)
            reverse.append(ReverseMove(from: s, to: d, color: color))
        }
        guard !reverse.isEmpty else { return nil }
        // No freebies: the deal must not hand the player a finished tube.
        if tubes.contains(where: { $0.isComplete }) { return nil }
        if isSolved(tubes) { return nil }
        // Genuinely mixed: at least two tubes hold more than one color.
        guard tubes.filter({ Set($0.segments).count > 1 }).count >= 2 else { return nil }

        // CERTIFY solvability through the real rules.
        var sim = tubes
        for rev in reverse.reversed() {
            guard let move = legalPour(tubes: sim, from: rev.to, to: rev.from),
                  move.color == rev.color, move.count == 1 else { return nil }
            applyPour(tubes: &sim, move: move)
        }
        guard isSolved(sim) else { return nil }

        // The inverse sequence IS a solution, so par stays fair and achievable.
        let par = reverse.count + colors
        return LevelDef(index: index, tubes: tubes, par: par)
    }
}
