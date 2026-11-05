import SwiftUI
import Observation

// MARK: - Cartes et paquets

/// Une carte : une question au recto, la réponse au verso, et son calendrier de révision.
struct Card: Identifiable, Codable, Hashable {
    var id = UUID()
    var front: String
    var back: String
    var createdAt = Date()
    /// Prochaine date où la carte doit revenir.
    var due = Date()
    /// Écart actuel entre deux révisions, en jours.
    var interval: Double = 0
    /// Facilité de la carte (plus c'est haut, plus les écarts grandissent vite).
    var ease: Double = 2.5
    /// Nombre de bonnes réponses d'affilée.
    var reps = 0
    /// Nombre de fois où la carte a été oubliée.
    var lapses = 0
    var lastReview: Date?
    /// Jour de la toute première révision (pour limiter les nouvelles cartes par jour).
    var firstReview: Date?

    var isNew: Bool { lastReview == nil }
    func isDue(_ now: Date = .now) -> Bool { !isNew && due <= now }

    /// Où en est la carte : nouvelle, en apprentissage, ou bien connue.
    var level: Level {
        if isNew { return .new }
        if interval < 7 { return .learning }
        if interval < 30 { return .young }
        return .mastered
    }

    enum Level: String, CaseIterable {
        case new, learning, young, mastered
        var label: String {
            switch self {
            case .new: return "Nouvelles"
            case .learning: return "En cours"
            case .young: return "Connues"
            case .mastered: return "Maîtrisées"
            }
        }
        var color: Color {
            switch self {
            case .new: return .blue
            case .learning: return .orange
            case .young: return .mint
            case .mastered: return .green
            }
        }
    }
}

struct Deck: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String = "📘"
    var color: DeckColor = .indigo
    var cards: [Card] = []
    var createdAt = Date()
    /// Le paquet tout prêt dont il vient (pour ne pas l'ajouter deux fois).
    var starterID: String?

    func dueCount(_ now: Date = .now) -> Int { cards.filter { $0.isDue(now) }.count }
    var newCount: Int { cards.filter(\.isNew).count }
    /// Part des cartes déjà bien connues (de 0 à 1).
    var mastery: Double {
        guard !cards.isEmpty else { return 0 }
        return Double(cards.filter { $0.level == .young || $0.level == .mastered }.count) / Double(cards.count)
    }
}

enum DeckColor: String, Codable, CaseIterable, Identifiable {
    case indigo, blue, teal, green, yellow, orange, red, pink, purple, graphite
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .indigo: return Color(red: 0.36, green: 0.34, blue: 0.95)
        case .blue: return Color(red: 0.16, green: 0.5, blue: 1.0)
        case .teal: return Color(red: 0.1, green: 0.72, blue: 0.8)
        case .green: return Color(red: 0.2, green: 0.75, blue: 0.4)
        case .yellow: return Color(red: 1.0, green: 0.78, blue: 0.15)
        case .orange: return Color(red: 1.0, green: 0.55, blue: 0.15)
        case .red: return Color(red: 0.98, green: 0.28, blue: 0.3)
        case .pink: return Color(red: 1.0, green: 0.35, blue: 0.62)
        case .purple: return Color(red: 0.68, green: 0.36, blue: 0.95)
        case .graphite: return Color(red: 0.42, green: 0.44, blue: 0.5)
        }
    }
}

// MARK: - Répétition espacée

/// Ta réponse après avoir vu le verso.
enum Grade: Int, CaseIterable, Identifiable {
    case again, hard, good, easy
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .again: return "À revoir"
        case .hard: return "Difficile"
        case .good: return "Bien"
        case .easy: return "Facile"
        }
    }
    var color: Color {
        switch self {
        case .again: return .red
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }
}

enum Scheduler {
    /// Calcule le prochain passage de la carte selon ta réponse (méthode proche de celle d'Anki).
    static func review(_ card: Card, _ grade: Grade, now: Date = .now) -> Card {
        var c = card
        let wasNew = c.isNew
        if wasNew { c.firstReview = now }
        c.lastReview = now
        switch grade {
        case .again:
            if !wasNew { c.lapses += 1 }
            c.reps = 0
            c.ease = max(1.3, c.ease - 0.2)
            c.interval = 0
            c.due = now.addingTimeInterval(60) // revient dans la séance
            return c
        case .hard:
            c.ease = max(1.3, c.ease - 0.15)
            c.interval = c.reps == 0 ? 1 : max(1, c.interval * 1.2)
        case .good:
            c.interval = c.reps == 0 ? 1 : (c.reps == 1 ? 3 : max(c.interval + 1, c.interval * c.ease))
        case .easy:
            c.ease += 0.15
            c.interval = c.reps == 0 ? 4 : max(c.interval + 2, c.interval * c.ease * 1.3)
        }
        c.interval = min(c.interval, 3650)
        c.reps += 1
        // La carte revient au début de la journée prévue (pour qu'elle soit prête dès le matin).
        let day = Calendar.current.date(byAdding: .day, value: Int(c.interval.rounded()), to: now) ?? now
        c.due = Calendar.current.startOfDay(for: day)
        return c
    }

    /// Le temps avant le prochain passage, affiché sous chaque bouton (« 1 min », « 3 j », « 2 mois »…).
    static func preview(_ card: Card, _ grade: Grade) -> String {
        if grade == .again { return "1 min" }
        let next = review(card, grade)
        let days = Int(next.interval.rounded())
        if days < 1 { return "1 j" }
        if days < 30 { return "\(days) j" }
        if days < 365 { return "\(Int((Double(days) / 30).rounded())) mois" }
        let years = Double(days) / 365
        return years < 1.95 ? "1 an" : "\(Int(years.rounded())) ans"
    }
}

// MARK: - Le stockage (sur l'iPhone)

@MainActor
@Observable
final class Store {
    private(set) var decks: [Deck] = []
    /// Nombre de cartes révisées par jour (« 2026-11-05 » → 34).
    private(set) var history: [String: Int] = [:]
    var dailyGoal: Int = UserDefaults.standard.object(forKey: "dailyGoal") as? Int ?? 20 {
        didSet { UserDefaults.standard.set(dailyGoal, forKey: "dailyGoal") }
    }
    /// Nouvelles cartes présentées par jour et par paquet.
    var newPerDay: Int = UserDefaults.standard.object(forKey: "newPerDay") as? Int ?? 15 {
        didSet { UserDefaults.standard.set(newPerDay, forKey: "newPerDay") }
    }
    var haptics: Bool = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true {
        didSet { UserDefaults.standard.set(haptics, forKey: "haptics") }
    }
    var message: String?

    private static let folder: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Memora", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private static let decksURL = folder.appendingPathComponent("decks.json")
    private static let historyURL = folder.appendingPathComponent("history.json")

    init() {
        if let data = try? Data(contentsOf: Self.decksURL), let list = try? JSONDecoder().decode([Deck].self, from: data) {
            decks = list
        }
        if let data = try? Data(contentsOf: Self.historyURL), let map = try? JSONDecoder().decode([String: Int].self, from: data) {
            history = map
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(decks) { try? data.write(to: Self.decksURL, options: .atomic) }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) { try? data.write(to: Self.historyURL, options: .atomic) }
    }

    func deck(_ id: UUID) -> Deck? { decks.first { $0.id == id } }

    // MARK: Paquets

    @discardableResult
    func createDeck(name: String, emoji: String = "📘", color: DeckColor = .indigo, cards: [Card] = [], starterID: String? = nil) -> Deck {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = Deck(name: clean.isEmpty ? "Nouveau paquet" : clean, emoji: emoji, color: color, cards: cards, starterID: starterID)
        decks.insert(d, at: 0)
        save()
        return d
    }

    func updateDeck(_ id: UUID, name: String, emoji: String, color: DeckColor) {
        guard let i = decks.firstIndex(where: { $0.id == id }) else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { decks[i].name = clean }
        decks[i].emoji = emoji.isEmpty ? decks[i].emoji : String(emoji.prefix(2))
        decks[i].color = color
        save()
    }

    func deleteDeck(_ id: UUID) {
        decks.removeAll { $0.id == id }
        save()
    }

    func moveDecks(from: IndexSet, to: Int) {
        decks.move(fromOffsets: from, toOffset: to)
        save()
    }

    // MARK: Cartes

    func addCards(_ cards: [Card], to deckID: UUID) {
        guard let i = decks.firstIndex(where: { $0.id == deckID }) else { return }
        decks[i].cards.append(contentsOf: cards)
        save()
    }

    func updateCard(_ card: Card, in deckID: UUID) {
        guard let i = decks.firstIndex(where: { $0.id == deckID }),
              let j = decks[i].cards.firstIndex(where: { $0.id == card.id }) else { return }
        decks[i].cards[j] = card
        save()
    }

    func deleteCards(_ ids: Set<UUID>, from deckID: UUID) {
        guard let i = decks.firstIndex(where: { $0.id == deckID }) else { return }
        decks[i].cards.removeAll { ids.contains($0.id) }
        save()
    }

    /// Remet un paquet à zéro (toutes les cartes redeviennent nouvelles).
    func resetProgress(_ deckID: UUID) {
        guard let i = decks.firstIndex(where: { $0.id == deckID }) else { return }
        decks[i].cards = decks[i].cards.map { Card(id: $0.id, front: $0.front, back: $0.back, createdAt: $0.createdAt) }
        save()
    }

    // MARK: Révision

    /// Les cartes d'une séance : celles à revoir aujourd'hui, puis quelques nouvelles.
    func session(for deckIDs: [UUID], now: Date = .now) -> [SessionItem] {
        var due: [SessionItem] = []
        var fresh: [SessionItem] = []
        for id in deckIDs {
            guard let d = deck(id) else { continue }
            due += d.cards.filter { $0.isDue(now) }.sorted { $0.due < $1.due }.map { SessionItem(deckID: id, card: $0) }
            let newToday = newStudiedToday(in: d)
            let room = max(0, newPerDay - newToday)
            fresh += d.cards.filter(\.isNew).prefix(room).map { SessionItem(deckID: id, card: $0) }
        }
        return due.shuffled() + fresh
    }

    /// Nombre de cartes à réviser maintenant (à revoir + nouvelles du jour).
    func todayCount(_ deckIDs: [UUID]) -> Int { session(for: deckIDs).count }

    private func newStudiedToday(in deck: Deck) -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        return deck.cards.filter { ($0.firstReview ?? .distantPast) >= start }.count
    }

    func record(_ item: SessionItem, _ grade: Grade) -> Card {
        let updated = Scheduler.review(item.card, grade)
        updateCard(updated, in: item.deckID)
        history[Self.dayKey(.now), default: 0] += 1
        saveHistory()
        return updated
    }

    // MARK: Statistiques

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    var reviewedToday: Int { history[Self.dayKey(.now)] ?? 0 }

    /// Jours d'affilée avec au moins une révision (aujourd'hui compte s'il est déjà fait).
    var streak: Int {
        var count = 0
        var day = Date.now
        if (history[Self.dayKey(day)] ?? 0) == 0 {
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while (history[Self.dayKey(day)] ?? 0) > 0 {
            count += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    /// Les 7 derniers jours (du plus ancien à aujourd'hui).
    var lastWeek: [(label: String, count: Int)] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEEE"
        return (0..<7).reversed().map { back in
            let d = Calendar.current.date(byAdding: .day, value: -back, to: .now) ?? .now
            return (f.string(from: d).uppercased(), history[Self.dayKey(d)] ?? 0)
        }
    }

    var totalCards: Int { decks.reduce(0) { $0 + $1.cards.count } }
}

struct SessionItem: Identifiable, Hashable {
    var id: UUID { card.id }
    let deckID: UUID
    var card: Card
}

extension Store {
    /// Entraînement libre : toutes les cartes du paquet, mélangées.
    func practiceSession(for deckIDs: [UUID]) -> [SessionItem] {
        deckIDs.flatMap { id in (deck(id)?.cards ?? []).map { SessionItem(deckID: id, card: $0) } }.shuffled()
    }

    /// Une carte vue en entraînement libre : elle compte pour l'objectif du jour, sans changer son calendrier.
    func notePractice() {
        history[Self.dayKey(.now), default: 0] += 1
        saveHistory()
    }
}
