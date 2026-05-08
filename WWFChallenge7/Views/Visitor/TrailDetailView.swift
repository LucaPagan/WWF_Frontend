import SwiftUI

struct TrailDetailView: View {
    let trail: Trail
    @Environment(\.dismiss) private var dismiss
    @State private var startTrail = false

    var difficultyColor: Color {
        switch trail.difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Hero
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(
                                LinearGradient(
                                    colors: [Color("WWFGreen"), Color("WWFDarkGreen")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 200)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(trail.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            HStack {
                                Label(trail.difficulty.rawValue, systemImage: trail.difficulty.icon)
                                    .foregroundColor(difficultyColor)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())

                                Label("\(trail.estimatedMinutes) min", systemImage: "clock")
                                    .foregroundColor(.white.opacity(0.9))
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                    }

                    // Descrizione
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descrizione")
                            .font(.headline)
                        Text(trail.trailDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Tappe del percorso
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tappe del percorso")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(trail.sortedSteps.indices, id: \.self) { index in
                            let step = trail.sortedSteps[index]
                            TrailStepRowView(
                                step: step,
                                index: index,
                                isLast: index == trail.sortedSteps.count - 1
                            )
                            .padding(.horizontal)
                        }
                    }

                    // Avviso modalità offline
                    HStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Modalità offline")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("La navigazione funziona senza internet. Scansiona i QR code lungo il percorso per aggiornare la tua posizione.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // CTA
                    Button {
                        startTrail = true
                    } label: {
                        Label("Inizia percorso", systemImage: "figure.hiking")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("WWFGreen"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, Color.white.opacity(0.3))
                            .font(.title3)
                    }
                }
            }
            .fullScreenCover(isPresented: $startTrail) {
                ActiveTrailView(trail: trail)
            }
        }
    }
}

// MARK: - Step Row

struct TrailStepRowView: View {
    let step: TrailStep
    let index: Int
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color("WWFGreen"))
                        .frame(width: 30, height: 30)
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color("WWFGreen").opacity(0.3))
                        .frame(width: 2, height: 40)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let poi = step.poi {
                    Text(poi.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(step.instructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, isLast ? 0 : 20)
            }
            Spacer()
        }
    }
}