import Foundation

/// Number of liquid segments a tube holds.
let tubeCapacity = 4

// MARK: - Model

/// One tube. `segments` runs bottom -> top and holds color ids.
struct TubeState: Equatable, Codable {
    var segments: [Int]

    var isEmpty: Bool { segments.isEmpty }
    var isFull: Bool { segments.count >= tubeCapacity }
    var isComplete: Bool { segments.count == tubeCapacity && Set(segments).count == 1 }
    var topColor: Int? { segments.last }

    /// Length of the contiguous run of the top color.
    var topRunLength: Int {
        guard let top = segments.last else { return 0 }
        var n = 0
        for s in segments.reversed() {
            if s == top { n += 1 } else { break }
        }
        return n
    }
}

/// A single legal pour of the top color run from one tube to another.
struct PourMove: Equatable {
    let from: Int
    let to: Int
    let color: Int
    let count: Int
}

struct LevelDef {
    let index: Int          // 0-based
    let tubes: [TubeState]
    let par: Int            // moves for 3 stars
}

// MARK: - Rules (single source of truth)

/// Gameplay pour rules: source must be non-empty and not already complete,
/// destination must have room and match (or be empty).
func legalPour(tubes: [TubeState], from: Int, to: Int) -> PourMove? {
    guard from != to,
          tubes.indices.contains(from), tubes.indices.contains(to) else { return nil }
    let src = tubes[from]
    let dst = tubes[to]
    guard !src.isEmpty, !src.isComplete, !dst.isFull, !dst.isComplete else { return nil }
    guard let color = src.topColor else { return nil }
    if let top = dst.topColor, top != color { return nil }
    let count = min(src.topRunLength, tubeCapacity - dst.segments.count)
    guard count > 0 else { return nil }
    return PourMove(from: from, to: to, color: color, count: count)
}

func applyPour(tubes: inout [TubeState], move: PourMove) {
    let moving = Array(tubes[move.from].segments.suffix(move.count))
    tubes[move.from].segments.removeLast(move.count)
    tubes[move.to].segments.append(contentsOf: moving)
}

func isSolved(_ tubes: [TubeState]) -> Bool {
    tubes.allSatisfy { $0.isEmpty || $0.isComplete }
}

/// Find a complete legal solution before spending a booster. A partial search
/// is never used: preserving color counts alone does not prove solvability.
/// Hard node/depth limits bound work, including on a dead-ended player board.
func magicPourSolution(_ tubes: [TubeState], nodeLimit: Int = 2_000,
                       depthLimit: Int = 128) -> [PourMove]? {
    guard nodeLimit > 0, depthLimit > 0, !isSolved(tubes),
          tubes.allSatisfy({ $0.segments.count <= tubeCapacity }) else { return nil }
    let counts = Dictionary(grouping: tubes.flatMap(\.segments), by: { $0 })
    guard counts.values.allSatisfy({ $0.count % tubeCapacity == 0 }) else { return nil }
    var visited = Set<[[Int]]>()
    var expanded = 0

    func search(_ board: [TubeState], depth: Int) -> [PourMove]? {
        if isSolved(board) { return [] }
        guard depth < depthLimit, expanded < nodeLimit else { return nil }
        // Tube positions do not affect rules; canonicalization avoids exploring
        // permutations of empty tubes or simply moving a uniform stack.
        let key = board.map(\.segments).sorted { $0.lexicographicallyPrecedes($1) }
        guard visited.insert(key).inserted else { return nil }
        expanded += 1
        var candidates: [PourMove] = []
        for from in board.indices {
            for to in board.indices {
                if let move = legalPour(tubes: board, from: from, to: to) {
                    candidates.append(move)
                }
            }
        }
        func score(_ move: PourMove) -> Int {
            let destination = board[move.to]
            return (destination.segments.count + move.count == tubeCapacity ? 100 : 0)
                + (destination.isEmpty ? 0 : 10) + move.count
        }
        candidates.sort {
            if score($0) != score($1) { return score($0) > score($1) }
            if $0.from != $1.from { return $0.from < $1.from }
            return $0.to < $1.to
        }
        for move in candidates {
            guard expanded < nodeLimit else { break }
            var next = board
            applyPour(tubes: &next, move: move)
            if let tail = search(next, depth: depth + 1) { return [move] + tail }
        }
        return nil
    }
    return search(tubes, depth: 0)
}

/// Execute only the prefix ending at the first newly completed tube. The
/// unused suffix remains a proof that the resulting board can still be solved.
func magicPourResult(_ tubes: [TubeState]) -> [TubeState]? {
    guard let solution = magicPourSolution(tubes) else { return nil }
    var result = tubes
    for move in solution {
        applyPour(tubes: &result, move: move)
        if result[move.to].isComplete { return result }
    }
    return nil
}
