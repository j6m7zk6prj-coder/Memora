import SwiftUI

// MARK: - Un paquet : ses cartes, réviser, ajouter

struct DeckView: View {
    let deckID: UUID
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var editingCard: Card?
    @State private var addingCard = false
    @State private var editingDeck = false
    @State private var study: StudyTarget?
    @State private var importTarget: ImportTarget?
    @State private var confirmReset = false
    @State private var confirmDelete = false

    var body: some View {
        if let deck = store.deck(deckID) {
            content(deck)
        } else {
            ContentUnavailableView("Paquet introuvable", systemImage: "rectangle.stack")
        }
    }

    private func content(_ deck: Deck) -> some View {
        let cards = deck.cards.filter {
            query.isEmpty || $0.front.localizedCaseInsensitiveContains(query) || $0.back.localizedCaseInsensitiveContains(query)
        }
        let todo = store.todayCount([deck.id])
        return List {
            Section {
                VStack(spacing: 14) {
                    DeckBadge(deck: deck, size: 72)
                    Text(deck.name).font(.title2.bold()).multilineTextAlignment(.center)
                    HStack(spacing: 18) {
                        ForEach(Card.Level.allCases, id: \.self) { level in
                            VStack(spacing: 2) {
                                Text("\(deck.cards.filter { $0.level == level }.count)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(level.color)
                                Text(level.label).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    LevelBar(deck: deck)
                    Button { study = StudyTarget(deckIDs: [deck.id], title: deck.name) } label: {
                        Label(todo == 0 ? "Rien à réviser aujourd’hui" : "Réviser \(todo) carte\(todo > 1 ? "s" : "")", systemImage: "play.fill")
                    }
                    .buttonStyle(BigButtonStyle(color: deck.color.color))
                    .disabled(todo == 0)
                    .opacity(todo == 0 ? 0.5 : 1)
                    if !deck.cards.isEmpty {
                        Button { study = StudyTarget(deckIDs: [deck.id], title: deck.name, practice: true) } label: {
                            Label("S’entraîner sur tout le paquet", systemImage: "shuffle")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .frame(height: 40)
                                .glassCapsule(interactive: true)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                Button { addingCard = true } label: {
                    Label("Ajouter une carte", systemImage: "plus.circle.fill")
                }
                ForEach(cards) { card in
                    Button { editingCard = card } label: { CardRow(card: card) }
                        .buttonStyle(.plain)
                }
                .onDelete { idx in store.deleteCards(Set(idx.map { cards[$0].id }), from: deck.id) }
            } header: {
                Text("\(deck.cards.count) carte\(deck.cards.count > 1 ? "s" : "")")
            }
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground(tint: deck.color.color) }
        .searchable(text: $query, prompt: "Chercher une carte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Ajouter une carte", systemImage: "plus") { addingCard = true }
                    Button("Depuis une photo du cours", systemImage: "camera.viewfinder") {
                        importTarget = ImportTarget(mode: .photo, deckID: deck.id)
                    }
                    Button("Coller du texte (Quizlet…)", systemImage: "doc.on.clipboard") {
                        importTarget = ImportTarget(mode: .text, deckID: deck.id)
                    }
                    Divider()
                    Button("Modifier le paquet", systemImage: "pencil") { editingDeck = true }
                    ShareLink(item: Self.export(deck)) { Label("Exporter les cartes", systemImage: "square.and.arrow.up") }
                    Button("Remettre à zéro", systemImage: "arrow.counterclockwise") { confirmReset = true }
                    Button("Supprimer le paquet", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editingCard) { CardEditor(deckID: deck.id, card: $0) }
        .sheet(isPresented: $addingCard) { CardEditor(deckID: deck.id, card: nil) }
        .sheet(isPresented: $editingDeck) { DeckEditor(deckID: deck.id) }
        .sheet(item: $importTarget) { ImportView(target: $0) }
        .fullScreenCover(item: $study) { StudyView(target: $0) }
        .confirmationDialog("Remettre ce paquet à zéro ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Remettre à zéro", role: .destructive) { store.resetProgress(deck.id) }
        } message: {
            Text("Toutes les cartes redeviennent nouvelles. Les cartes elles-mêmes sont gardées.")
        }
        .confirmationDialog("Supprimer « \(deck.name) » ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer le paquet", role: .destructive) {
                dismiss()
                store.deleteDeck(deck.id)
            }
        }
    }

    /// Texte « question⇥réponse », une carte par ligne (le format de Quizlet et d'Anki).
    static func export(_ deck: Deck) -> String {
        deck.cards.map { "\($0.front)\t\($0.back)" }.joined(separator: "\n")
    }
}

private struct CardRow: View {
    let card: Card

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(card.level.color).frame(width: 9, height: 9).padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(card.front).font(.body.weight(.semibold)).lineLimit(2)
                Text(card.back).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            if !card.isNew {
                Text(card.due <= .now ? "à revoir" : card.due.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Créer ou modifier une carte

struct CardEditor: View {
    let deckID: UUID
    let card: Card?
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var front = ""
    @State private var back = ""
    @State private var added = 0
    @FocusState private var focus: Field?

    private enum Field { case front, back }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recto (question)") {
                    TextField("Ex. : Capitale de l’Espagne", text: $front, axis: .vertical)
                        .lineLimit(1...6)
                        .focused($focus, equals: .front)
                }
                Section("Verso (réponse)") {
                    TextField("Ex. : Madrid", text: $back, axis: .vertical)
                        .lineLimit(1...8)
                        .focused($focus, equals: .back)
                }
                if card == nil {
                    Section {
                        Button {
                            save()
                            front = ""
                            back = ""
                            added += 1
                            focus = .front
                        } label: {
                            Label("Ajouter et continuer", systemImage: "plus.circle")
                        }
                        .disabled(!valid)
                    } footer: {
                        if added > 0 { Text("\(added) carte\(added > 1 ? "s" : "") ajoutée\(added > 1 ? "s" : "")") }
                    }
                }
            }
            .navigationTitle(card == nil ? "Nouvelle carte" : "Modifier la carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(added > 0 ? "Fermer" : "Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        if valid { save() }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                front = card?.front ?? ""
                back = card?.back ?? ""
                focus = .front
            }
        }
    }

    private var valid: Bool {
        !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let f = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = back.trimmingCharacters(in: .whitespacesAndNewlines)
        if var c = card {
            c.front = f
            c.back = b
            store.updateCard(c, in: deckID)
        } else {
            store.addCards([Card(front: f, back: b)], to: deckID)
        }
    }
}

// MARK: - Créer ou modifier un paquet

struct DeckEditor: View {
    let deckID: UUID?
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "📘"
    @State private var color: DeckColor = .indigo

    private let emojis = ["📘", "📗", "📕", "📙", "🧠", "🌍", "🏛️", "🧪", "🧮", "🇬🇧", "🇪🇸", "🇩🇪", "🎨", "🎵", "⚖️", "🩺", "💻", "🚗", "📜", "⭐️"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        DeckBadge(deck: Deck(name: name, emoji: emoji, color: color), size: 84)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Nom") {
                    TextField("Ex. : Histoire – le XXᵉ siècle", text: $name)
                }
                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(emojis, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e)
                                    .font(.title2)
                                    .frame(width: 46, height: 46)
                                    .background(Circle().fill(emoji == e ? color.color.opacity(0.3) : Color.clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(DeckColor.allCases) { c in
                            Button { color = c } label: {
                                Circle()
                                    .fill(c.color.gradient)
                                    .frame(width: 38, height: 38)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: color == c ? 3 : 0))
                                    .shadow(color: c.color.opacity(0.4), radius: color == c ? 6 : 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(deckID == nil ? "Nouveau paquet" : "Modifier le paquet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(deckID == nil ? "Créer" : "OK") {
                        if let deckID {
                            store.updateDeck(deckID, name: name, emoji: emoji, color: color)
                        } else {
                            store.createDeck(name: name, emoji: emoji, color: color)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let deckID, let d = store.deck(deckID) {
                    name = d.name
                    emoji = d.emoji
                    color = d.color
                }
            }
        }
    }
}
