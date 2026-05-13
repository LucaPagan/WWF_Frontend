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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    EventsHeaderView()

                    // Eventi di oggi
                    let todayEvents = events.filter { $0.isToday }
                    if !todayEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.orange)
                                Text("Oggi all'Oasi")
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

                    // Prossimi eventi
                    let upcoming = events.filter { $0.isUpcoming && !$0.isToday }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prossimi eventi")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        if upcoming.isEmpty && todayEvents.isEmpty {
                            ContentUnavailableView(
                                "Nessun evento in programma",
                                systemImage: "calendar",
                                description: Text("Torna a trovarci presto per scoprire le attività dell'Oasi!")
                            )
                            .padding(.top, 40)
                        } else if upcoming.isEmpty {
                            Text("Nessun altro evento in programma al momento.")
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
            .navigationTitle("Eventi")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }
}

// MARK: - Events Header

struct EventsHeaderView: View {
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
                Text("Eventi e Attività")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Scopri le esperienze organizzate nell'Oasi degli Astroni")
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

    var categoryColor: Color {
        event.category.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top: categoria + data
            HStack {
                // Badge categoria
                HStack(spacing: 4) {
                    Image(systemName: event.category.icon)
                        .font(.caption2)
                    Text(event.category.rawValue)
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
                    Text("OGGI")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }

            // Titolo e descrizione
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(event.eventDescription)
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
                    Label(String(format: "%.2f €", event.price), systemImage: "eurosign.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("Gratuito", systemImage: "eurosign.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }

            // Percorso associato
            if let trail = event.trail {
                HStack(spacing: 6) {
                    Image(systemName: "signpost.right.and.left.fill")
                        .font(.caption2)
                        .foregroundColor(Color("WWFGreen"))
                    Text("Percorso: \(trail.name)")
                        .font(.caption)
                        .foregroundColor(Color("WWFGreen"))
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color("WWFGreen").opacity(0.08))
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
