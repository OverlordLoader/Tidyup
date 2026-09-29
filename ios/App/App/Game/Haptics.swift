import UIKit

/// Lightweight haptic accents. Every generator is created on demand and fired
/// on the main thread; call sites are already main-thread (UI / SpriteKit).
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func select() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func pour() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func complete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func win() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
