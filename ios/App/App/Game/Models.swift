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
