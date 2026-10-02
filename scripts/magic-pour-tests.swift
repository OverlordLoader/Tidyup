import Foundation

func board(_ rows: [[Int]]) -> [TubeState] { rows.map { TubeState(segments: $0) } }
func histogram(_ tubes: [TubeState]) -> [Int: Int] {
    tubes.flatMap(\.segments).reduce(into: [:]) { $0[$1, default: 0] += 1 }
}
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}

// UI/persistence are deliberately isolated; real Models, LevelGenerator and
// GameEngine compile into this executable. This does not test StoreKit or ads.
final class ProgressStore {
    static let shared = ProgressStore()
    func recordWin(level: Int, stars: Int) {}
}
enum TestSound { case click, complete }
final class SoundManager {
    static let shared = SoundManager()
    func play(_ sound: TestSound) {}
}
enum Haptics { static func tap() {}; static func complete() {} }

@main struct MagicPourTests {
    static func main() {
        let fixture = board([[0, 0, 1, 1], [1, 1, 0, 0], []])
        let original = fixture
        check(magicPourSolution(fixture, nodeLimit: 0) == nil, "Zero budget must fail closed")
        check(magicPourSolution(fixture, depthLimit: 0) == nil, "Zero depth must fail closed")
        check(magicPourResult(board([[0, 1], []])) == nil, "Malformed color totals rejected")
        check(magicPourResult(board([[0, 0, 0, 0], []])) == nil, "Solved board is no-op")
        check(magicPourResult(board([[0, 1, 0, 1], [1, 0, 1, 0]])) == nil,
              "Full blocked board is no-op")
        var certified = 0
        var unavailable = 0
        let started = Date()
        for index in 0..<LevelGenerator.totalLevels {
            let tubes = LevelGenerator.generate(index: index).tubes
            guard let solution = magicPourSolution(tubes) else {
                unavailable += 1
                check(index >= 5, "Tutorial booster unexpectedly unavailable")
                continue
            }
            var replay = tubes
            var firstCompletion: [TubeState]?
            for move in solution {
                check(legalPour(tubes: replay, from: move.from, to: move.to) == move,
                      "Solution must use actual legal pours")
                applyPour(tubes: &replay, move: move)
                check(histogram(replay) == histogram(tubes), "Every step conserves each color")
                check(replay.allSatisfy { $0.segments.count <= tubeCapacity }, "No overflow")
                if firstCompletion == nil && replay[move.to].isComplete { firstCompletion = replay }
            }
            check(isSolved(replay), "Witness must end solved")
            check(magicPourResult(tubes) == firstCompletion, "Booster stops at first completion")
            certified += 1
        }
        check(fixture == original, "Planning must not mutate input")
        // The original overwrite bug would fail these assertions on a mixed tube.
        guard let result = magicPourResult(fixture) else { preconditionFailure("Known solvable fixture") }
        check(histogram(result) == histogram(fixture), "Regression: no invented/destroyed colors")
        check(result != fixture, "Success cannot be a no-op")

        let engine = GameEngine(levelIndex: 0)
        let before = engine.tubes
        var inventory = 2
        var charges = 0
        func charge() -> Bool {
            charges += 1
            guard inventory > 0 else { return false }
            inventory -= 1
            return true
        }
        engine.setBusy(true)
        check(!engine.magicPour(authorize: charge), "Busy board rejects booster")
        check(charges == 0 && inventory == 2, "Busy board must not debit")
        engine.setBusy(false)
        check(!engine.magicPour(authorize: { false }), "No inventory must reject")
        check(engine.tubes == before && engine.moves == 0, "Failed debit leaves board/history alone")
        check(engine.magicPour(authorize: charge), "Tutorial booster must succeed")
        check(inventory == 1 && charges == 1 && engine.moves == 1, "Exactly one debit/move")
        check(histogram(engine.tubes) == histogram(before), "Engine conserves liquid")
        engine.setBusy(false)
        engine.undo()
        check(engine.tubes == before && engine.moves == 0, "Undo restores exact board and moves")
        check(inventory == 1, "Undo must not recreate a consumed booster")
        check(engine.magicPour(authorize: charge), "Second use after undo is charged again")
        check(inventory == 0 && charges == 2, "No inventory duplication")
        print("PASS: rules + engine + undo/debit; certified \(certified) generated boards; \(unavailable) bounded no-ops; \(Date().timeIntervalSince(started)) seconds")
    }
}
