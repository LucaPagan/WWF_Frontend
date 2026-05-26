//
//  EventListView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//  Redesigned — Maggio 2026
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
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {

                    HStack(alignment: .top) {
                        TopWavyShape()
                            .fill(Color(red: 0.184, green: 0.110, blue: 0.102))
                            .frame(width: geo.size.width, height: 165)
                            .shadow(color: .black.opacity(0.30), radius: 6, x: 0, y: 3)

                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Eventi")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(localizer.localizedString(for: "explore"))
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.88))
                    }
                    .padding(.leading, 22)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {

                            EventsHeaderView()
                                .padding(.horizontal, 16)
                                .padding(.top, 10)

                            // Today's Events
                            let todayEvents = events.filter { $0.isToday }
                            if !todayEvents.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.orange)
                                            .font(.body.weight(.bold))
                                        Text(localizer.localizedString(for: "today_oasis"))
                                            .font(WWFDesign.Typography.sectionTitle)
                                            .foregroundColor(WWFDesign.Colors.forestDark)
                                    }
                                    .padding(.horizontal, 16)

                                    ForEach(todayEvents) { event in
                                        EventCardView(event: event, isHighlighted: true)
                                            .padding(.horizontal, 16)
                                            .onTapGesture { selectedEvent = event }
                                    }
                                }
                            }

                            let upcoming = events.filter { $0.isUpcoming && !$0.isToday }
                            VStack(alignment: .leading, spacing: 12) {
                                Text(localizer.localizedString(for: "upcoming_events"))
                                    .font(WWFDesign.Typography.sectionTitle)
                                    .foregroundColor(WWFDesign.Colors.forestDark)
                                    .padding(.horizontal, 16)

                                if upcoming.isEmpty && todayEvents.isEmpty {
                                    ContentUnavailableView(
                                        localizer.localizedString(for: "no_events_scheduled"),
                                        systemImage: "calendar",
                                        description: Text(localizer.localizedString(for: "no_events_scheduled_desc"))
                                    )
                                    .padding(.top, 40)
                                } else if upcoming.isEmpty {
                                    Text(localizer.localizedString(for: "no_other_events"))
                                        .font(WWFDesign.Typography.trailDesc)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                } else {
                                    ForEach(upcoming) { event in
                                        EventCardView(event: event, isHighlighted: false)
                                            .padding(.horizontal, 16)
                                            .onTapGesture { selectedEvent = event }
                                    }
                                }
                            }

                            Spacer(minLength: 40)
                        }
                    }
                    .padding(.top, 100)

                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
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
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: WWFDesign.Radius.hero)
                .fill(Color(red: 0.184, green: 0.110, blue: 0.102))
                .frame(minHeight: 190)

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color(red: 0.353, green: 0.180, blue: 0.149))
                        .frame(width: 200, height: 200)
                        .blur(radius: 50)
                        .offset(x: geo.size.width * 0.6, y: -30)
                        .opacity(0.6)

                    Circle()
                        .fill(Color(red: 0.588, green: 0.314, blue: 0.235))
                        .frame(width: 100, height: 100)
                        .blur(radius: 40)
                        .offset(x: geo.size.width * 0.75, y: 60)
                        .opacity(0.25)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.hero))

            Image(systemName: "sparkles")
                .font(.system(size: 110))
                .foregroundColor(Color(red: 0.949, green: 0.600, blue: 0.290).opacity(0.07))
                .rotationEffect(.degrees(-15))
                .offset(x: UIScreen.main.bounds.width - 180, y: -20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.949, green: 0.600, blue: 0.290))
                        .frame(width: 6, height: 6)
                    Text(localizer.localizedString(for: "events_activities").uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.961, green: 0.769, blue: 0.588))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 0.690, green: 0.329, blue: 0.180).opacity(0.18))
                .overlay(
                    Capsule().stroke(Color(red: 0.690, green: 0.329, blue: 0.180).opacity(0.35), lineWidth: 0.5)
                )
                .clipShape(Capsule())

                Spacer()

                Text("Oasis Events")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(localizer.localizedString(for: "events_oasis_desc"))
                    .font(WWFDesign.Typography.heroSubtitle)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(20)
            .frame(minHeight: 190, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.hero))
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
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(categoryColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: event.category.icon)
                            .font(.caption2.weight(.bold))
                        Text(localizer.localizedString(for: "event_cat_" + event.category.rawValue))
                            .font(WWFDesign.Typography.badge)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.08))
                    .overlay(
                        Capsule().stroke(categoryColor.opacity(0.2), lineWidth: 0.5)
                    )
                    .clipShape(Capsule())

                    Spacer()

                    if event.isToday {
                        Text(localizer.localizedString(for: "today_upper"))
                            .font(.caption2.weight(.black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.localizedName)
                            .font(WWFDesign.Typography.trailName)
                            .foregroundColor(WWFDesign.Colors.forestDark)

                        Text(event.localizedDescription)
                            .font(WWFDesign.Typography.trailDesc)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(WWFDesign.Colors.forestMid.opacity(0.5))
                }

                HStack(spacing: 12) {
                    Label(event.formattedDate, systemImage: "calendar")
                        .font(WWFDesign.Typography.metaLabel)
                        .foregroundColor(.secondary)

                    Label(event.formattedTimeRange, systemImage: "clock")
                        .font(WWFDesign.Typography.metaLabel)
                        .foregroundColor(.secondary)

                    if event.price > 0 {
                        Label(String(format: "€ %.2f", event.price), systemImage: "eurosign.circle")
                            .font(WWFDesign.Typography.metaLabel)
                            .foregroundColor(.secondary)
                    } else {
                        Label(localizer.localizedString(for: "free_price"), systemImage: "eurosign.circle")
                            .font(WWFDesign.Typography.metaLabel)
                            .foregroundColor(WWFDesign.Colors.forestLight)
                            .fontWeight(.semibold)
                    }
                }

                if let trail = event.trail {
                    HStack(spacing: 6) {
                        Image(systemName: "signpost.right.and.left.fill")
                            .font(.caption2)
                            .foregroundColor(WWFDesign.Colors.forestMid)
                        Text("\(localizer.localizedString(for: "associated_trail")): \(trail.localizedName)")
                            .font(WWFDesign.Typography.metaLabel)
                            .foregroundColor(WWFDesign.Colors.forestMid)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WWFDesign.Colors.forestMid.opacity(0.06))
                    .overlay(
                        Capsule().stroke(WWFDesign.Colors.forestMid.opacity(0.15), lineWidth: 0.5)
                    )
                    .clipShape(Capsule())
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: WWFDesign.Radius.card))
        .shadow(color: .black.opacity(isHighlighted ? 0.08 : 0.04), radius: isHighlighted ? 8 : 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: WWFDesign.Radius.card)
                .stroke(isHighlighted ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.localizedName). \(event.localizedDescription). \(event.formattedDate), \(event.formattedTimeRange). \(event.price > 0 ? String(format: "%.2f euro", event.price) : "Ingresso gratuito")")
        .accessibilityHint("Tocca due volte per i dettagli dell'evento")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview {
    EventListView()
}
