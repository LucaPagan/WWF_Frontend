import SwiftUI

struct POIModalView: View {
    let poi: POI
    @Environment(\.dismiss) private var dismiss

    var accentColor: Color {
        Color(hex: poi.type.color) ?? .green
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header colorato
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

                    // Foto (se presente)
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

                    // Badge "posizione aggiornata"
                    HStack {
                        Image(systemName: "location.fill.viewfinder")
                            .foregroundColor(.green)
                        Text("Posizione aggiornata sulla mappa")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle("Punto di interesse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continua") { dismiss() }
                        .foregroundColor(Color("WWFGreen"))
                }
            }
        }
    }
}