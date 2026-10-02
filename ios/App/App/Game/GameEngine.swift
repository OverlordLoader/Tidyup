import Foundation
import Combine

/// Visual events the SpriteKit scene animates. The engine owns the rules and
/// state; the scene owns the juice. Sound and haptics are triggered by the
/// scene so they stay in sync with the animation.
enum GameEvent {
    case selected(Int)
    case deselected(Int)
    case pour(PourMove)
    case tubeCompleted(Int)
    case levelWon(stars: Int)
    case illegal(Int)
    case stateRestored
}

final class GameEngine: ObservableObject {
    @Published private(set) var tubes: [TubeState]
    @Published private(set) var selected: Int? = nil
    @Published private(set) var moves: Int = 0
    @Published private(set) var busy: Bool = false
    @Published private(set) var won: Bool = false
    @Published private(set) var showWinOverlay: Bool = false
    @Published private(set) var lastStars: Int = 0

    let levelIndex: Int
    let par: Int

    /// Wired by the view to the SpriteKit scene.
    var onEvent: ((GameEvent) -> Void)?

    var levelNumber: Int { levelIndex + 1 }
    var canUndo: Bool { !history.isEmpty && !busy && !won }

    private var magicCache: (board: [TubeState], result: [TubeState]?)?

    private func plannedMagicPour() -> [TubeState]? {
        if let cache = magicCache, cache.board == tubes { return cache.result }
        let result = magicPourResult(tubes)
        magicCache = (tubes, result)
        return result
    }

    var canMagicPour: Bool { !busy && !won && plannedMagicPour() != nil }

    private let initial: [TubeState]
    private var history: [(tubes: [TubeState], moves: Int)] = []
    private var completedNotified: Set<Int> = []

    init(levelIndex: Int) {
        let def = LevelGenerator.generate(index: levelIndex)
        self.levelIndex = levelIndex
        self.par = def.par
        self.tubes = def.tubes
        self.initial = def.tubes
    }

    /// Called by the scene to lock/unlock input around animations.
    func setBusy(_ value: Bool) {
        busy = value
    }

    /// Called by the scene after the win celebration finishes.
    func celebrationFinished() {
        showWinOverlay = true
    }

    // MARK: - Input

    func tapTube(_ i: Int) {
        guard !busy, !won, tubes.indices.contains(i) else { return }
        if let s = selected {
            if s == i {
                selected = nil
                onEvent?(.deselected(i))
            } else if let move = legalPour(tubes: tubes, from: s, to: i) {
                history.append((tubes, moves))
                applyPour(tubes: &tubes, move: move)
                moves += 1
                selected = nil
                busy = true
                onEvent?(.pour(move))
                let completedIdx = move.to
                if tubes[completedIdx].isComplete && !completedNotified.contains(completedIdx) {
                    completedNotified.insert(completedIdx)
                    onEvent?(.tubeCompleted(completedIdx))
                }
                if isSolved(tubes) {
                    won = true
                    lastStars = earnedStars()
                    ProgressStore.shared.recordWin(level: levelIndex, stars: lastStars)
                    onEvent?(.levelWon(stars: lastStars))
                }
            } else {
                onEvent?(.illegal(i))
            }
        } else {
            guard !tubes[i].isEmpty, !tubes[i].isComplete else { return }
            selected = i
            onEvent?(.selected(i))
        }
    }

    func undo() {
        undo(count: 1)
    }

    /// Undoes up to `n` moves at once (Second Chance booster).
    func undo(count n: Int) {
        var remaining = max(1, n)
        var restored = false
        while remaining > 0, canUndo {
            guard let last = history.popLast() else { break }
            tubes = last.tubes
            moves = last.moves
            remaining -= 1
            restored = true
        }
        guard restored else { return }
        selected = nil
        completedNotified = Set(tubes.indices.filter { tubes[$0].isComplete })
        SoundManager.shared.play(.click)
        Haptics.tap()
        onEvent?(.stateRestored)
    }

    /// Complete a tube using a certified legal prefix, never by replacing
    /// liquid. Authorization (inventory debit) happens only after a valid plan.
    /// Undo restores the board, but does not refund a spent consumable.
    @discardableResult
    func magicPour(authorize: () -> Bool = { true }) -> Bool {
        guard !busy, !won, let result = plannedMagicPour(), authorize() else { return false }
        let completed = result.indices.filter { result[$0].isComplete && !tubes[$0].isComplete }
        history.append((tubes, moves))
        tubes = result
        moves += 1
        selected = nil
        busy = true
        onEvent?(.stateRestored)
        for idx in completed where !completedNotified.contains(idx) {
            // stateRestored can finish synchronously and unlock input.
            busy = true
            completedNotified.insert(idx)
            onEvent?(.tubeCompleted(idx))
        }
        if isSolved(tubes) {
            won = true
            lastStars = earnedStars()
            ProgressStore.shared.recordWin(level: levelIndex, stars: lastStars)
            onEvent?(.levelWon(stars: lastStars))
        }
        SoundManager.shared.play(.complete)
        Haptics.complete()
        return true
    }

    func restart() {
        guard !busy else { return }
        tubes = initial
        moves = 0
        selected = nil
        won = false
        showWinOverlay = false
        history = []
        completedNotified = []
        SoundManager.shared.play(.click)
        Haptics.tap()
        onEvent?(.stateRestored)
    }

    // MARK: - Scoring

    private func earnedStars() -> Int {
        if moves <= par { return 3 }
        if moves <= Int(Double(par) * 1.6) { return 2 }
        return 1
    }
}
