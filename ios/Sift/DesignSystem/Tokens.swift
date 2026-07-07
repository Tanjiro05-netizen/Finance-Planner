import SwiftUI

struct RGBAComponents: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: Double
}

enum ColorToken: String, Codable, CaseIterable {
    case ink
    case inkSoft
    case inkFaint
    case bone
    case card
    case sand
    case line
    case gold
    case goldDeep
    case clay
    case green

    fileprivate var hex: String {
        switch self {
        case .ink: "#1A1612"
        case .inkSoft: "#6E6357"
        case .inkFaint: "#9C9285"
        case .bone: "#F6F2EA"
        case .card: "#FFFDF8"
        case .sand: "#ECE4D6"
        case .line: "#E2D9C8"
        case .gold: "#B68A4E"
        case .goldDeep: "#9A7238"
        case .clay: "#A8472F"
        case .green: "#3F6B3A"
        }
    }

    var color: Color {
        Color(hex: hex)
    }

    var components: RGBAComponents {
        parseHex(hex)
    }
}

enum Palette {
    static var ink: Color {
        ColorToken.ink.color
    }

    static var inkSoft: Color {
        ColorToken.inkSoft.color
    }

    static var inkFaint: Color {
        ColorToken.inkFaint.color
    }

    static var bone: Color {
        ColorToken.bone.color
    }

    static var card: Color {
        ColorToken.card.color
    }

    static var sand: Color {
        ColorToken.sand.color
    }

    static var line: Color {
        ColorToken.line.color
    }

    static var gold: Color {
        ColorToken.gold.color
    }

    static var goldDeep: Color {
        ColorToken.goldDeep.color
    }

    static var clay: Color {
        ColorToken.clay.color
    }

    static var green: Color {
        ColorToken.green.color
    }

    static func rgba(_ token: ColorToken) -> RGBAComponents {
        token.components
    }
}

enum Radius {
    static let card: CGFloat = 26
    static let row: CGFloat = 17
    static let control: CGFloat = 16
    static let tile: CGFloat = 11
    static let pill: CGFloat = 20
    static let tabBar: CGFloat = 24
    static let actionBar: CGFloat = 24
    static let segmented: CGFloat = 15
    static let sheet: CGFloat = 38
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let screenHorizontal: CGFloat = 18
}

enum Elevation {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static var card: Shadow {
        Shadow(color: Palette.ink.opacity(0.12), radius: 30, x: 0, y: 14)
    }

    static var row: Shadow {
        Shadow(color: Palette.ink.opacity(0.10), radius: 20, x: 0, y: 8)
    }

    static var control: Shadow {
        Shadow(color: Palette.ink.opacity(0.18), radius: 40, x: 0, y: 18)
    }
}

private extension Color {
    init(hex: String) {
        let rgba = parseHex(hex)
        self.init(
            .sRGB,
            red: Double(rgba.red) / 255.0,
            green: Double(rgba.green) / 255.0,
            blue: Double(rgba.blue) / 255.0,
            opacity: rgba.alpha
        )
    }
}

private func parseHex(_ hex: String) -> RGBAComponents {
    let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)

    switch cleaned.count {
    case 6:
        return RGBAComponents(
            red: UInt8((value & 0xFF0000) >> 16),
            green: UInt8((value & 0x00FF00) >> 8),
            blue: UInt8(value & 0x0000FF),
            alpha: 1
        )
    case 8:
        return RGBAComponents(
            red: UInt8((value & 0xFF00_0000) >> 24),
            green: UInt8((value & 0x00FF_0000) >> 16),
            blue: UInt8((value & 0x0000_FF00) >> 8),
            alpha: Double(value & 0x0000_00FF) / 255.0
        )
    default:
        assertionFailure("Invalid color token")
        return RGBAComponents(red: 0, green: 0, blue: 0, alpha: 1)
    }
}
