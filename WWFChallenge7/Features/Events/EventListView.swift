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
    
    
    private var events: [Event] = []
    
    @State private var selectedEvent: Event? = nil
    @ObservedObject private var localizer = LocalizationManager.shared
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    
                    HStack(alignment: .top) {
                        TopWavyShape()
                            .fill(customHeaderOrange!)
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

// MARK: - Preview

#Preview {
    EventListView()
}
