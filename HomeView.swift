import SwiftUI

/// Ce qu'on révise : un ou plusieurs paquets.
struct StudyTarget: Identifiable {
    let id = UUID()
    let deckIDs: [UUID]
    let title: String
    /// Entraînement libre : toutes les cartes, sans changer leur calendrier.
    var practice = false
}

// MARK: - Accueil : l'objectif du jour et tes paquets

struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var study: StudyTarget?
    @State private var newDeck = false
    @State private var showStarters = false
    @State private var showSettings = false
    @State private var importTarget: ImportTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    TodayCard { study = StudyTarget(deckIDs: store.decks.map(\.id), title: "Tous les paquets") }

                    if store.decks.isEmpty {
                        welcome
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mes paquets").font(.title2.bold())
                            ForEach(store.decks) { deck in
                                NavigationLink(value: deck.id) {
                                    DeckRow(deck: deck)
                                }
                                .buttonStyle(PressStyle())
                                .contextMenu {
                                    Button("Réviser", systemImage: "play.fill") {
                                        study = StudyTarget(deckIDs: [deck.id], title: deck.name)
                                    }
                                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                                        store.deleteDeck(deck.id)
                                    }
                                }
                            }
                        }
                    }

                    Button { showStarters = true } label: {
                        Label("Paquets tout prêts", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .frame(height: 44)
                            .glassCapsule(interactive: true)
                    }
                    .buttonStyle(PressStyle())
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .navigationTitle("Mémora")
            .navigationDestination(for: UUID.self) { DeckView(deckID: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Réglages")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Nouveau paquet", systemImage: "rectangle.stack.badge.plus") { newDeck = true }
                        Button("Depuis une photo du cours", systemImage: "camera.viewfinder") {
                            importTarget = ImportTarget(mode: .photo, deckID: nil)
                        }
                        Button("Coller du texte (Quizlet…)", systemImage: "doc.on.clipboard") {
                            importTarget = ImportTarget(mode: .text, deckID: nil)
                        }
                        Button("Paquets tout prêts", systemImage: "sparkles") { showStarters = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Ajouter")
                }
            }
            .sheet(isPresented: $newDeck) { DeckEditor(deckID: nil) }
            .sheet(isPresented: $showStarters) { StarterDecksView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $importTarget) { ImportView(target: $0) }
            .fullScreenCover(item: $study) { StudyView(target: $0) }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bienvenue 👋").font(.title2.bold())
            Text("Crée un paquet de cartes, prends ton cours en photo, ou commence avec un paquet tout prêt. Mémora te repose chaque question juste avant que tu l’oublies.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button { newDeck = true } label: { Label("Nouveau paquet", systemImage: "plus") }
                    .buttonStyle(BigButtonStyle())
                Button { importTarget = ImportTarget(mode: .photo, deckID: nil) } label: { Label("Photo", systemImage: "camera") }
                    .buttonStyle(BigButtonStyle(color: .pink))
            }
        }
        .padding(18)
        .glass(26)
    }
}

/// Carte du haut : objectif du jour, série de jours, et le bouton pour réviser.
private struct TodayCard: View {
    var onStudy: () -> Void
    @Environment(Store.self) private var store

    var body: some View {
        let todo = store.todayCount(store.decks.map(\.id))
        let progress = Double(store.reviewedToday) / Double(max(1, store.dailyGoal))
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 11)
                    VStack(spacing: 0) {
                        Text("\(store.reviewedToday)").font(.title2.bold()).monospacedDigit()
                        Text("/ \(store.dailyGoal)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: 6) {
                    Text(progress >= 1 ? "Objectif atteint 🎉" : "Objectif du jour")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                        Text(store.streak == 0 ? "Commence ta série aujourd’hui" : "\(store.streak) jour\(store.streak > 1 ? "s" : "") d’affilée")
                    }
                    .font(.subheadline.weight(.medium))
                    Text(todo == 0 ? "Rien à réviser pour l’instant" : "\(todo) carte\(todo > 1 ? "s" : "") à réviser")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            WeekChart()

            Button(action: onStudy) {
                Label(todo == 0 ? "Tout est révisé" : "Réviser maintenant", systemImage: "play.fill")
            }
            .buttonStyle(BigButtonStyle())
            .disabled(todo == 0)
            .opacity(todo == 0 ? 0.5 : 1)
        }
        .padding(18)
        .glass(28)
    }
}

/// Les 7 derniers jours en petites barres.
private struct WeekChart: View {
    @Environment(Store.self) private var store

    var body: some View {
        let week = store.lastWeek
        let top = max(1, week.map { $0.count }.max() ?? 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(week.enumerated()), id: \.offset) { i, day in
                VStack(spacing: 5) {
                    Capsule()
                        .fill(day.count > 0 ? AnyShapeStyle(Color.brand.gradient) : AnyShapeStyle(Color.primary.opacity(0.1)))
                        .frame(height: max(6, 44 * CGFloat(day.count) / CGFloat(top)))
                    Text(day.label)
                        .font(.caption2.weight(i == week.count - 1 ? .bold : .medium))
                        .foregroundStyle(i == week.count - 1 ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 64, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Révisions des 7 derniers jours")
    }
}

/// Une ligne de paquet : pastille, nom, cartes à revoir, niveau.
struct DeckRow: View {
    let deck: Deck
    @Environment(Store.self) private var store

    var body: some View {
        let todo = store.todayCount([deck.id])
        HStack(spacing: 14) {
            DeckBadge(deck: deck)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(deck.name).font(.headline).foregroundStyle(.primary).lineLimit(1)
                    Spacer()
                    if todo > 0 {
                        Text("\(todo)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(Capsule().fill(deck.color.color))
                    }
                }
                Text("\(deck.cards.count) carte\(deck.cards.count > 1 ? "s" : "") · \(Int(deck.mastery * 100)) % connues")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LevelBar(deck: deck)
            }
        }
        .padding(14)
        .glass(22, interactive: true)
    }
}
