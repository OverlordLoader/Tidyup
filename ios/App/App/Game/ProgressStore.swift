import Foundation
import Combine

/// Persists level progress locally. No accounts, no network, no tracking.
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    /// How many levels are unlocked (1-based count; level indexes are 0-based).
    @Published private(set) var unlocked: Int
    @Published private(set) var stars: [Int: Int]
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.sound) }
    }

    private enum Keys {
        static let unlocked = "tidyup.unlocked"
        static let stars = "tidyup.stars"
        static let sound = "tidyup.sound"
    }

    private init() {
        let defaults = UserDefaults.standard
        let saved = defaults.integer(forKey: Keys.unlocked)
        self.unlocked = saved <= 0 ? 1 : min(saved, LevelGenerator.totalLevels)
        if let data = defaults.data(forKey: Keys.stars),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            self.stars = decoded
        } else {
            self.stars = [:]
        }
        self.soundEnabled = defaults.object(forKey: Keys.sound) as? Bool ?? true
    }

    func stars(for level: Int) -> Int { stars[level] ?? 0 }

    var totalStars: Int { stars.values.reduce(0, +) }

    func recordWin(level: Int, stars earned: Int) {
        if earned > (stars[level] ?? 0) {
            stars[level] = earned
        }
        if level + 1 < LevelGenerator.totalLevels {
            unlocked = max(unlocked, min(level + 2, LevelGenerator.totalLevels))
        }
        save()
        objectWillChange.send()
    }

    func resetAll() {
        unlocked = 1
        stars = [:]
        save()
        objectWillChange.send()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(unlocked, forKey: Keys.unlocked)
        if let data = try? JSONEncoder().encode(stars) {
            defaults.set(data, forKey: Keys.stars)
        }
    }
}
