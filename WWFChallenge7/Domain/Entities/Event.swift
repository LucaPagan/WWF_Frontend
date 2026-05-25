//
//  Event.swift
//  WWFChallenge7
//
//  SwiftData entity — mirrors Supabase table: public.events
//  Identical schema to GestionaleWWFIpad/Domain/Entities/Event.swift
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Event: @unchecked Sendable {
    var id: UUID
    var name: String
    var eventDescription: String
    var categoryRawValue: String
    var date: Date
    var timeStart: Date
    var timeEnd: Date
    var maxParticipants: Int?
    var isActive: Bool
    var contactInfo: String?
    var requirements: String?
    var targetAudienceRawValue: String
    var price: Double
    var imageURL: String?
    var organizerName: String?
    var photoData: Data?
    var completionQrPayload: String?
    var completionNumericCode: String?
    var gamificationRewardData: Data?

    var trail: Trail?
    var eventPOI: POI?

    var createdAt: Date
    var updatedAt: Date
    var needsSync: Bool

    @Transient var category: EventCategory {
        get { EventCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    @Transient var targetAudience: EventAudience {
        get { EventAudience(rawValue: targetAudienceRawValue) ?? .all }
        set { targetAudienceRawValue = newValue.rawValue }
    }

    @Transient var localizedName: String {
        LocalizationManager.shared.localizedField(table: "events", recordId: id, fieldName: "name", fallback: name)
    }

    @Transient var localizedDescription: String {
        LocalizationManager.shared.localizedField(table: "events", recordId: id, fieldName: "description", fallback: eventDescription)
    }

    @Transient var localizedRequirements: String? {
        guard let req = requirements, !req.isEmpty else { return nil }
        return LocalizationManager.shared.localizedField(table: "events", recordId: id, fieldName: "requirements", fallback: req)
    }

    init(
        name: String,
        description: String,
        category: EventCategory = .other,
        date: Date = Date(),
        startTime: Date = Date(),
        endTime: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
        maxParticipants: Int? = 30,
        organizerName: String? = nil,
        contactInfo: String? = nil,
        requirements: String? = nil,
        targetAudience: EventAudience = .all,
        price: Double = 0,
        imageURL: String? = nil,
        photoData: Data? = nil,
        fixedID: UUID? = nil
    ) {
        self.id = fixedID ?? UUID()
        self.name = name
        self.eventDescription = description
        self.categoryRawValue = category.rawValue
        self.date = date
        self.timeStart = startTime
        self.timeEnd = endTime
        self.maxParticipants = maxParticipants
        self.isActive = false
        self.organizerName = organizerName
        self.contactInfo = contactInfo
        self.requirements = requirements
        self.targetAudienceRawValue = targetAudience.rawValue
        self.price = price
        self.imageURL = imageURL
        self.photoData = photoData
        self.completionQrPayload = nil
        self.completionNumericCode = nil
        self.gamificationRewardData = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }

    var formattedStartTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: timeStart)
    }

    var formattedEndTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: timeEnd)
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "it_IT")
        fmt.dateStyle = .long
        return fmt.string(from: date)
    }

    var formattedTimeRange: String {
        "\(formattedStartTime) – \(formattedEndTime)"
    }

    var isUpcoming: Bool {
        date >= Calendar.current.startOfDay(for: Date())
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var formattedPrice: String {
        price == 0 ? "Gratuito" : String(format: "€%.2f", price)
    }

    func updateFromRemote(_ data: [String: Any]) {
        if let n = data["name"] as? String { name = n }
        if let d = data["description"] as? String { eventDescription = d }
        if let cat = data["category"] as? String { categoryRawValue = cat }
        if let active = data["is_active"] as? Bool { isActive = active }
        maxParticipants = data["max_participants"] as? Int
        contactInfo = data["contact_info"] as? String
        requirements = data["requirements"] as? String
        if let ta = data["target_audience"] as? String { targetAudienceRawValue = ta }
        if let p = data["price"] as? Double { price = p }
        imageURL = data["image_url"] as? String
        organizerName = data["organizer_name"] as? String
        completionQrPayload = data["completion_qr_payload"] as? String
        completionNumericCode = data["completion_numeric_code"] as? String
        if let reward = data["gamification_reward_json"] as? [String: Any] {
            gamificationRewardData = LocalGamificationRule.encodeJSON(reward)
        }
        needsSync = false
    }
}

enum EventCategory: String, Codable, CaseIterable {
    case educational  = "educational"
    case guidedTour   = "guided_tour"
    case workshop     = "workshop"
    case family       = "family"
    case photography  = "photography"
    case scientific   = "scientific"
    case other        = "other"

    var displayName: String {
        switch self {
        case .educational:  return "Educativo"
        case .guidedTour:   return "Visita Guidata"
        case .workshop:     return "Laboratorio"
        case .family:       return "Famiglia"
        case .photography:  return "Fotografia"
        case .scientific:   return "Scientifico"
        case .other:        return "Altro"
        }
    }

    var icon: String {
        switch self {
        case .educational:  return "book.fill"
        case .guidedTour:   return "figure.walk"
        case .workshop:     return "hammer.fill"
        case .family:       return "figure.and.child.holdinghands"
        case .photography:  return "camera.fill"
        case .scientific:   return "flask.fill"
        case .other:        return "calendar.badge.clock"
        }
    }

    var color: Color {
        switch self {
        case .educational:  return Color.blue
        case .guidedTour:   return WWFDesign.Colors.forestLight
        case .workshop:     return Color.orange
        case .family:       return Color.purple
        case .photography:  return Color.gray
        case .scientific:   return Color.teal
        case .other:        return WWFDesign.Colors.leafGreen
        }
    }

    var supabaseValue: String { rawValue }

    nonisolated static func fromSupabase(_ value: String) -> EventCategory? {
        EventCategory(rawValue: value)
    }
}

enum EventAudience: String, Codable, CaseIterable {
    case all         = "all"
    case adults      = "adults"
    case children    = "children"
    case families    = "families"
    case schools     = "schools"
    case researchers = "researchers"

    var displayName: String {
        switch self {
        case .all:         return "Tutti"
        case .adults:      return "Adulti"
        case .children:    return "Bambini"
        case .families:    return "Famiglie"
        case .schools:     return "Scuole"
        case .researchers: return "Ricercatori"
        }
    }

    var supabaseValue: String { rawValue }

    nonisolated static func fromSupabase(_ value: String) -> EventAudience? {
        EventAudience(rawValue: value)
    }
}
