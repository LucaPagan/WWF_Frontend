import SwiftUI

struct POIModalView: View {
    let poi: POI
    var onContinue: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var accentColor: Color {
        poi.type.color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(accentColor.opacity(0.15))
                            .frame(height: 120)
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 64, height: 64)
                                Image(systemName: poi.type.icon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(poi.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(poi.type.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal)

                    // Foto
                    if let data = poi.photoData, let uiImg = UIImage(data: data) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                    }

                    // Descrizione
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Descrizione")
                            .font(.headline)
                        Text(poi.poiDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // ── Predisposizione esperienze AR ─────────────────────────

                    ARPlaceholderBanner()
                        .padding(.horizontal)

                    // Badge posizione aggiornata
                    HStack {
                        Image(systemName: "location.fill.viewfinder")
                            .foregroundColor(.green)
                        Text("Posizione aggiornata sulla mappa")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)

                    // CTA continua
                    Button {
                        onContinue?() ?? dismiss()
                    } label: {
                        Label("Continua il percorso", systemImage: "arrow.right.circle.fill")
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
                .padding(.top)
            }
            .navigationTitle("Punto di interesse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") {
                        onContinue?() ?? dismiss()
                    }
                    .foregroundColor(Color("WWFGreen"))
                }
            }
        }
    }
}

// Banner placeholder AR
struct ARPlaceholderBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arkit")
                .font(.title3)
                .foregroundColor(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Esperienza AR disponibile a breve")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                Text("Questo punto avrà contenuti in realtà aumentata.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
