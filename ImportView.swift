import SwiftUI
import PhotosUI
import Vision
import VisionKit

// MARK: - Ajouter des cartes depuis une photo du cours ou du texte collé (Quizlet, Anki, notes…)

struct ImportTarget: Identifiable {
    enum Mode { case photo, text }
    let id = UUID()
    let mode: Mode
    /// Paquet où ajouter les cartes (vide : on en crée un nouveau).
    let deckID: UUID?
}

/// Une carte proposée, que tu peux corriger ou décocher avant de l'ajouter.
struct Draft: Identifiable, Hashable {
    let id = UUID()
    var front: String
    var back: String
    var keep = true
}

enum CardParser {
    enum Layout: String, CaseIterable, Identifiable {
        case separator, alternate
        var id: String { rawValue }
        var label: String { self == .separator ? "Question : réponse" : "Une ligne sur deux" }
    }

    /// Séparateurs reconnus entre la question et la réponse, du plus sûr au moins sûr.
    static let separators = ["\t", " : ", " = ", " → ", " -> ", " – ", " — ", " - ", ";", ":"]

    static func parse(_ text: String, layout: Layout) -> [Draft] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        switch layout {
        case .alternate:
            return stride(from: 0, to: lines.count - 1, by: 2).map { Draft(front: lines[$0], back: lines[$0 + 1]) }
        case .separator:
            var out: [Draft] = []
            for line in lines {
                guard let sep = separators.first(where: { line.contains($0) }),
                      let range = line.range(of: sep) else {
                    // Ligne sans séparateur : elle complète la réponse de la carte précédente.
                    if let last = out.indices.last { out[last].back += " " + line }
                    continue
                }
                let q = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let a = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !q.isEmpty && !a.isEmpty { out.append(Draft(front: q, back: a)) }
            }
            return out
        }
    }

    /// Choisit tout seul la mise en page qui donne le plus de cartes.
    static func guessLayout(_ text: String) -> Layout {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let withSep = lines.filter { l in separators.contains { l.contains($0) } }.count
        return Double(withSep) >= Double(max(1, lines.count)) * 0.4 ? .separator : .alternate
    }
}

enum TextReader {
    /// Lit le texte d'une image (français et anglais), ligne par ligne, de haut en bas.
    static func read(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await Task.detached(priority: .userInitiated) { () -> String in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["fr-FR", "en-US", "es-ES", "de-DE"]
            let handler = VNImageRequestHandler(cgImage: cg, orientation: Self.orientation(image.imageOrientation))
            try? handler.perform([request])
            let lines = (request.results ?? [])
                .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                .compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }

    nonisolated static func orientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

struct ImportView: View {
    let target: ImportTarget
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var layout: CardParser.Layout = .separator
    @State private var drafts: [Draft] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var scanning = false
    @State private var reading = false
    @State private var deckID: UUID?
    @State private var newDeckName = ""
    @State private var step = 0 // 0 : source, 1 : vérifier les cartes

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 { source } else { review }
            }
            .navigationTitle(target.mode == .photo ? "Depuis une photo" : "Coller du texte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                if step == 1 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ajouter \(drafts.filter(\.keep).count)") { add() }
                            .fontWeight(.semibold)
                            .disabled(drafts.filter(\.keep).isEmpty)
                    }
                }
            }
            .onAppear { deckID = target.deckID ?? store.decks.first?.id }
            .fullScreenCover(isPresented: $scanning) {
                DocumentScanner { images in
                    scanning = false
                    Task { await read(images) }
                } onCancel: {
                    scanning = false
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { images.append(img) }
                    }
                    photoItems = []
                    await read(images)
                }
            }
        }
    }

    // MARK: Étape 1 : la source

    private var source: some View {
        Form {
            if target.mode == .photo {
                Section {
                    if VNDocumentCameraViewController.isSupported {
                        Button { scanning = true } label: {
                            Label("Scanner le cours avec l’appareil photo", systemImage: "doc.viewfinder")
                        }
                    }
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                        Label("Choisir des photos", systemImage: "photo.on.rectangle")
                    }
                    if reading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Lecture du texte…").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Astuce : écris « question : réponse » sur chaque ligne (ou une ligne pour la question, la suivante pour la réponse). Mémora lit le texte et prépare les cartes ; tu pourras tout corriger.")
                }
            }
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .font(.callout)
            } header: {
                Text(target.mode == .photo ? "Texte lu (modifiable)" : "Ton texte")
            } footer: {
                Text("Exemples :\nParis : capitale de la France\n1789 = Révolution française\nDepuis Quizlet : « Exporter » puis colle le texte ici.")
            }
            Section("Mise en page") {
                Picker("Mise en page", selection: $layout) {
                    ForEach(CardParser.Layout.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Button {
                    drafts = CardParser.parse(text, layout: layout)
                    withAnimation { step = 1 }
                } label: {
                    Label("Préparer les cartes", systemImage: "wand.and.stars")
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: Étape 2 : vérifier et choisir le paquet

    private var review: some View {
        Form {
            Section("Ajouter dans") {
                Picker("Paquet", selection: $deckID) {
                    Text("Nouveau paquet").tag(UUID?.none)
                    ForEach(store.decks) { d in Text(d.emoji + " " + d.name).tag(Optional(d.id)) }
                }
                if deckID == nil {
                    TextField("Nom du nouveau paquet", text: $newDeckName)
                }
            }
            Section {
                if drafts.isEmpty {
                    Text("Aucune carte trouvée. Reviens en arrière et essaie l’autre mise en page.")
                        .foregroundStyle(.secondary)
                }
                ForEach($drafts) { $d in
                    HStack(alignment: .top, spacing: 12) {
                        Button { d.keep.toggle() } label: {
                            Image(systemName: d.keep ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(d.keep ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Question", text: $d.front, axis: .vertical).font(.body.weight(.semibold))
                            TextField("Réponse", text: $d.back, axis: .vertical).foregroundStyle(.secondary)
                        }
                    }
                    .opacity(d.keep ? 1 : 0.45)
                }
                .onDelete { drafts.remove(atOffsets: $0) }
            } header: {
                Text("\(drafts.count) carte\(drafts.count > 1 ? "s" : "") trouvée\(drafts.count > 1 ? "s" : "")")
            }
            Section {
                Button("Revenir au texte") { withAnimation { step = 0 } }
            }
        }
    }

    private func read(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        reading = true
        var parts: [String] = []
        for img in images { parts.append(await TextReader.read(img)) }
        reading = false
        let found = parts.filter { !$0.isEmpty }.joined(separator: "\n")
        text = text.isEmpty ? found : text + "\n" + found
        layout = CardParser.guessLayout(text)
    }

    private func add() {
        let cards = drafts.filter(\.keep).compactMap { d -> Card? in
            let f = d.front.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = d.back.trimmingCharacters(in: .whitespacesAndNewlines)
            return f.isEmpty || b.isEmpty ? nil : Card(front: f, back: b)
        }
        if let deckID {
            store.addCards(cards, to: deckID)
        } else {
            store.createDeck(name: newDeckName.isEmpty ? "Mon cours" : newDeckName, cards: cards)
        }
        dismiss()
    }
}

/// Le scanner de documents d'Apple (recadrage automatique, plusieurs pages).
struct DocumentScanner: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parent.onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
