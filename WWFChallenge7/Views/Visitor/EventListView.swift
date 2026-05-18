//
//  EventListView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//

import SwiftUI
import SwiftData

struct EventListView: View {
    @Query(filter: #Predicate<Event> { $0.isActive == true },
           sort: \Event.date, order: .forward)
    private var events: [Event]

    @State private var selectedEvent: Event? = nil
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    EventsHeaderView()

                    // Today's Events
                    let todayEvents = events.filter { $0.isToday }
                    if !todayEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.orange)
                                Text(localizer.localizedString(for: "today_oasis"))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal)

                            ForEach(todayEvents) { event in
                                EventCardView(event: event, isHighlighted: true)
                                    .padding(.horizontal)
                                    .onTapGesture { selectedEvent = event }
                            }
                        }
                    }

                    // Upcoming Events
                    let upcoming = events.filter { $0.isUpcoming && !$0.isToday }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localizer.localizedString(for: "upcoming_events"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if upcoming.isEmpty && todayEvents.isEmpty {
                            ContentUnavailableView(
                                localizer.localizedString(for: "no_events_scheduled"),
                                systemImage: "calendar",
                                description: Text(localizer.localizedString(for: "no_events_scheduled_desc"))
                            )
                            .padding(.top, 40)
                        } else if upcoming.isEmpty {
                            Text(localizer.localizedString(for: "no_other_events"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(upcoming) { event in
                                EventCardView(event: event, isHighlighted: false)
                                    .padding(.horizontal)
                                    .onTapGesture { selectedEvent = event }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle(localizer.localizedString(for: "events"))
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }
}

// MARK: - Events Header

struct EventsHeaderView: View {
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#283593")!.opacity(0.85), Color(hex: "#1565C0")!],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 140)

            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.9))
                Text(localizer.localizedString(for: "events_activities"))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(localizer.localizedString(for: "events_oasis_desc"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}

// MARK: - Event Card

struct EventCardView: View {
    let event: Event
    let isHighlighted: Bool
    @ObservedObject private var localizer = LocalizationManager.shared

    var categoryColor: Color {
        event.category.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top: category + data
            HStack {
                // Category Badge
                HStack(spacing: 4) {
                    Image(systemName: event.category.icon)
                        .font(.caption2)
                    Text(localizer.localizedString(for: "event_cat_" + event.category.rawValue))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(categoryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor.opacity(0.12))
                .clipShape(Capsule())

                Spacer()

                if event.isToday {
                    Text(localizer.localizedString(for: "today_upper"))
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }

            // Title and description
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.localizedName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(event.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }

            // Info chips
            HStack(spacing: 12) {
                Label(event.formattedDate, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(event.formattedTimeRange, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if event.price > 0 {
                    Label(String(format: "€ %.2f", event.price), systemImage: "eurosign.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label(localizer.localizedString(for: "free_price"), systemImage: "eurosign.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }

            // Associated trail
            if let trail = event.trail {
                HStack(spacing: 6) {
                    Image(systemName: "signpost.right.and.left.fill")
                        .font(.caption2)
                        .foregroundColor(WWFStyle.Colors.green)
                    Text("\(localizer.localizedString(for: "associated_trail")): \(trail.localizedName)")
                        .font(.caption)
                        .foregroundColor(WWFStyle.Colors.green)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(WWFStyle.Colors.green.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(isHighlighted ? 0.12 : 0.07), radius: isHighlighted ? 8 : 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHighlighted ? Color.orange.opacity(0.4) : Color.clear, lineWidth: isHighlighted ? 1.5 : 0)
        )
    }
}
