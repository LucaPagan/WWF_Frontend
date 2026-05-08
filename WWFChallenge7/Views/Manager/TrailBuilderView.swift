import SwiftUI
import SwiftData

struct TrailBuilderView: View {
    let trail: Trail?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPOIs: [POI]

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var difficulty: TrailDifficulty = .easy
    @State private var estimatedMinutes: Int = 60
    @State private var isActive: Bool = false
    @State private var steps: [DraftStep] = []
    @State private var showAddStep = false

    // Step draft (non ancora persistiti)
    struct DraftStep: Identifiable {
        let id = UUID()
        var poi: POI?
        var instructions: String
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !steps.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Info base
                Section("Informazioni percorso") {
                    TextField("Nome percorso", text: $name)
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Descrizione...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 60)
                    }
                }

                // MARK: Parametri
                Section("Parametri") {
                    Picker("Difficoltà", selection: $difficulty) {
                        ForEach(TrailDifficulty.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    Stepper("Durata: \(estimatedMinutes) min", value: $estimatedMinutes, in: 10...480, step: 10)
                    Toggle("Visibile ai visitatori", isOn: $isActive)
                        .tint(Color("WWFGreen"))
                }

                // MARK: Tappe
                Section {
                    ForEach($steps) { $step in
                        StepEditorRow(step: $step, allPOIs: allPOIs)
                    }
                    .onMove { from, to in steps.move(fromOffsets: from, toOffset: to) }
                    .onDelete { steps.remove(atOffsets: $0) }

                    Button {
                        steps.append(DraftStep(poi: nil, instructions: ""))
                    } label: {
                        Label("Aggiungi tappa", systemImage: "plus.circle.fill")
                            .foregroundColor(Color("WWFGreen"))
                    }
                } header: {
                    Text("Tappe (\(steps.count))")
                } footer: {
                    Text("Tieni premuto e trascina per riordinare le tappe.")
                        .font(.caption2)
                }
            }
            .navigationTitle(trail == nil ? "Nuovo percorso" : "Modifica percorso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveTrail() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !steps.isEmpty { EditButton() }
                }
            }
            .onAppear { loadExistingData() }
            .environment(\.editMode, .constant(.active))
        }
    }

    // MARK: - Helpers

    private func loadExistingData() {
        guard let t = trail else { return }
        name = t.name
        description = t.trailDescription
        difficulty = t.difficulty
        estimatedMinutes = t.estimatedMinutes
        isActive = t.isActive
        steps = t.sortedSteps.map { DraftStep(poi: $0.poi, instructions: $0.instructions) }
    }

    private func saveTrail() {
        let target = trail ?? Trail(name: "", description: "")
        target.name = name
        target.trailDescription = description
        target.difficulty = difficulty
        target.estimatedMinutes = estimatedMinutes
        target.isActive = isActive

        // Ricostruisce gli step
        target.steps.forEach { context.delete($0) }
        target.steps = steps.enumerated().map { i, draft in
            let s = TrailStep(orderIndex: i, instructions: draft.instructions, poi: draft.poi)
            context.insert(s)
            return s
        }

        if trail == nil { context.insert(target) }
        try? context.save()
        dismiss()
    }
}

// MARK: - Step row editor

struct StepEditorRow: View {
    @Binding var step: TrailBuilderView.DraftStep
    let allPOIs: [POI]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selezione POI
            Picker("Punto di interesse", selection: $step.poi) {
                Text("Nessun POI").tag(Optional<POI>(nil))
                ForEach(allPOIs) { poi in
                    Label(poi.name, systemImage: poi.type.icon).tag(Optional(poi))
                }
            }
            .pickerStyle(.menu)
            .tint(Color("WWFGreen"))

            // Indicazioni testuali
            TextField("Indicazioni (es. 'Vai dritto 200m...')", text: $step.instructions, axis: .vertical)
                .font(.caption)
                .lineLimit(2...4)
        }
        .padding(.vertical, 4)
    }
}