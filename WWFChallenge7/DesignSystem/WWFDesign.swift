//
//  WWFDesign.swift
//  WWFChallenge7
//
//  Centralized Design System per l'Oasi degli Astroni
//

import SwiftUI

enum WWFDesign {
    // Palette principale — bosco vulcanico
    enum Colors {
        // Verde foresta (hero, accenti primari)
        static let forestDark     = Color(red: 0.102, green: 0.200, blue: 0.126) // #1a3320
        static let forestMid      = Color(red: 0.176, green: 0.353, blue: 0.227) // #2d5a3a
        static let forestLight    = Color(red: 0.388, green: 0.600, blue: 0.133) // #639922

        // Accenti naturali
        static let leafGreen      = Color(red: 0.478, green: 0.714, blue: 0.282) // #7ab648
        static let leafLight      = Color(red: 0.659, green: 0.847, blue: 0.478) // #a8d87a

        // Badge difficoltà
        static let easyFill       = Color(red: 0.918, green: 0.953, blue: 0.871) // #eaf3de
        static let easyText       = Color(red: 0.231, green: 0.427, blue: 0.067) // #3b6d11
        static let mediumFill     = Color(red: 0.980, green: 0.933, blue: 0.851) // #faeeda
        static let mediumText     = Color(red: 0.522, green: 0.310, blue: 0.043) // #854f0b
        static let hardFill       = Color(red: 0.988, green: 0.922, blue: 0.922) // #fcebeb
        static let hardText       = Color(red: 0.639, green: 0.176, blue: 0.176) // #a32d2d
        
        // Colori aggiuntivi estratti per le card
        static let accentAmbra    = Color(red: 0.729, green: 0.459, blue: 0.043) // #ba750b (medium)
        static let accentRosso    = Color(red: 0.886, green: 0.294, blue: 0.290) // #e24b4a (hard)
        
        // Backgrounds
        static let backgroundOffWhite = Color(red: 0.941, green: 0.929, blue: 0.902)
        static let backgroundCream    = Color(red: 0.969, green: 0.951, blue: 0.906)
        static let cardCream          = Color(red: 0.988, green: 0.976, blue: 0.945)
        static let organicOutline     = Color(red: 0.122, green: 0.235, blue: 0.149)
        static let organicInset       = Color(red: 1.000, green: 0.992, blue: 0.965)

        // Warning / Metadati info
        static let warningFill    = Color(red: 0.980, green: 0.933, blue: 0.851)
        static let warningBorder  = Color(red: 0.980, green: 0.780, blue: 0.459)
        static let warningText    = Color(red: 0.388, green: 0.220, blue: 0.024) // #633806
        static let warningBody    = Color(red: 0.522, green: 0.310, blue: 0.043)
        
        // Mappe
        static let mapCurrentPin  = Color(red: 0.48, green: 0.36, blue: 0)
    }

    enum Typography {
        // Titolazione
        static let heroTitle      = Font.system(size: 28, weight: .bold, design: .rounded)
        static let heroSubtitle   = Font.system(.footnote).weight(.light)
        static let sectionTitle   = Font.system(size: 21, weight: .bold, design: .rounded)
        static let sectionLargeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        
        // Arrotondati (Dashboard/Cards)
        static let titleHeroRounded = Font.system(size: 28, weight: .bold, design: .rounded)
        static let largeTitleRounded = Font.system(size: 30, weight: .bold, design: .rounded)
        static let titleRounded   = Font.system(size: 20, weight: .bold, design: .rounded)
        static let trailNameLarge = Font.system(size: 22, weight: .bold, design: .rounded)
        static let bodyLargeRounded = Font.system(size: 16, weight: .regular, design: .rounded)
        
        // UI Testi Generici
        static let headline       = Font.headline
        static let body           = Font.body
        static let caption        = Font.caption
        static let subheadline    = Font.subheadline
        
        // Testi specifici percorso
        static let trailName      = Font.system(.subheadline).weight(.medium)
        static let trailDesc      = Font.system(.caption).weight(.light)
        static let trailDescBody  = Font.system(size: 15, weight: .regular)
        
        // Etichette e Badge
        static let chipLabel      = Font.system(.caption).weight(.medium)
        static let metaLabel      = Font.system(.caption2)
        static let badge          = Font.system(.caption2).weight(.medium)
    }

    enum Radius {
        static let card: CGFloat   = 16
        static let hero: CGFloat   = 20
        static let chip: CGFloat   = 20
        static let badge: CGFloat  = 10
        static let warning: CGFloat = 12
        static let largeCard: CGFloat = 24
    }
}
