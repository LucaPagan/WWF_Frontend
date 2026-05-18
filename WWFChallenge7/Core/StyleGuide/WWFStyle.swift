//
//  WWFStyle.swift
//  WWFChallenge7
//
//  Design system tokens — mirrors GestionaleWWFIpad/Core/StyleGuide/WWFStyle.swift
//  Any color referenced in Views or Models MUST come from this file.
//

import SwiftUI

public enum WWFStyle {

    // MARK: - Color Palette

    public enum Colors {
        // Primary brand
        public static let green       = Color(hexString: "#2E7D32")
        public static let darkGreen   = Color(hexString: "#1B5E20")

        // Semantic
        public static let info        = Color(hexString: "#1565C0")
        public static let warning     = Color(hexString: "#F57F17")
        public static let danger      = Color(hexString: "#C62828")
        public static let purple      = Color(hexString: "#6A1B9A")

        // Event categories
        public static let educational = Color(hexString: "#1565C0")
        public static let workshop    = Color(hexString: "#F57F17")
        public static let family      = Color(hexString: "#AB47BC")
        public static let photography = Color(hexString: "#455A64")
        public static let scientific  = Color(hexString: "#00897B")
        public static let other       = Color(hexString: "#5C8A5C")
    }

    // MARK: - Typography Helpers

    public enum Fonts {
        public static let largeTitle  = Font.system(.largeTitle, design: .rounded, weight: .bold)
        public static let headline    = Font.system(.headline, design: .rounded, weight: .semibold)
        public static let body        = Font.system(.body, design: .rounded)
        public static let caption     = Font.system(.caption, design: .rounded)
    }

    // MARK: - Layout Constants

    public enum Layout {
        public static let cornerRadius: CGFloat  = 14
        public static let cardPadding: CGFloat   = 16
        public static let sectionSpacing: CGFloat = 24
    }
}

// MARK: - Color(hexString:) Initialiser (Manager-compatible)

extension Color {
    init(hexString hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
