import SwiftUI
import SpriteKit

// MARK: - Color helpers

extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    func darkened(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - amount, 0), green: max(g - amount, 0),
                       blue: max(b - amount, 0), alpha: a)
    }

    func lightened(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(r + amount, 1), green: min(g + amount, 1),
                       blue: min(b + amount, 1), alpha: a)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0)
    }
}

// MARK: - Game palette

/// One liquid color. Candy-bright so every pour reads instantly.
struct GameColor: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let hex: UInt32

    var swiftUIColor: Color { Color(hex: hex) }
    var skColor: SKColor { SKColor(hex: hex) }
    var darkSK: SKColor { SKColor(hex: hex).darkened(0.30) }
    var lightSK: SKColor { SKColor(hex: hex).lightened(0.38) }
}

enum Palette {
    static let all: [GameColor] = [
        GameColor(id: 0, name: "Cherry", hex: 0xFF3B5C),
        GameColor(id: 1, name: "Tangerine", hex: 0xFF8A00),
        GameColor(id: 2, name: "Lemon", hex: 0xFFD60A),
        GameColor(id: 3, name: "Lime", hex: 0x7ED957),
        GameColor(id: 4, name: "Mint", hex: 0x00C2A8),
        GameColor(id: 5, name: "Sky", hex: 0x3AB6FF),
        GameColor(id: 6, name: "Blueberry", hex: 0x5B5FE9),
        GameColor(id: 7, name: "Grape", hex: 0xA259FF),
        GameColor(id: 8, name: "Bubblegum", hex: 0xFF5FD2),
        GameColor(id: 9, name: "Lagoon", hex: 0x00B4D8),
    ]

    static func color(id: Int) -> GameColor {
        all[id % all.count]
    }
}
