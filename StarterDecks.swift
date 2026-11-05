import SwiftUI

// MARK: - Paquets tout prêts (pour commencer tout de suite)

struct StarterDeck: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let color: DeckColor
    let subtitle: String
    let pairs: [(String, String)]
}

enum StarterDecks {
    static let all: [StarterDeck] = [capitals, verbs, history, elements, maths]

    static let capitals = StarterDeck(id: "capitales-europe", name: "Capitales d’Europe", emoji: "🌍", color: .teal,
                                      subtitle: "30 pays et leur capitale", pairs: [
        ("Allemagne", "Berlin"), ("Autriche", "Vienne"), ("Belgique", "Bruxelles"), ("Bulgarie", "Sofia"),
        ("Croatie", "Zagreb"), ("Danemark", "Copenhague"), ("Espagne", "Madrid"), ("Estonie", "Tallinn"),
        ("Finlande", "Helsinki"), ("Grèce", "Athènes"), ("Hongrie", "Budapest"), ("Irlande", "Dublin"),
        ("Islande", "Reykjavik"), ("Italie", "Rome"), ("Lettonie", "Riga"), ("Lituanie", "Vilnius"),
        ("Luxembourg", "Luxembourg"), ("Malte", "La Valette"), ("Norvège", "Oslo"), ("Pays-Bas", "Amsterdam"),
        ("Pologne", "Varsovie"), ("Portugal", "Lisbonne"), ("République tchèque", "Prague"), ("Roumanie", "Bucarest"),
        ("Royaume-Uni", "Londres"), ("Slovaquie", "Bratislava"), ("Slovénie", "Ljubljana"), ("Suède", "Stockholm"),
        ("Suisse", "Berne"), ("Ukraine", "Kiev (Kyiv)")
    ])

    static let verbs = StarterDeck(id: "verbes-irreguliers", name: "Verbes irréguliers anglais", emoji: "🇬🇧", color: .red,
                                   subtitle: "Base verbale → prétérit · participe passé", pairs: [
        ("be (être)", "was / were · been"), ("become (devenir)", "became · become"), ("begin (commencer)", "began · begun"),
        ("break (casser)", "broke · broken"), ("bring (apporter)", "brought · brought"), ("build (construire)", "built · built"),
        ("buy (acheter)", "bought · bought"), ("catch (attraper)", "caught · caught"), ("choose (choisir)", "chose · chosen"),
        ("come (venir)", "came · come"), ("do (faire)", "did · done"), ("drink (boire)", "drank · drunk"),
        ("drive (conduire)", "drove · driven"), ("eat (manger)", "ate · eaten"), ("fall (tomber)", "fell · fallen"),
        ("feel (ressentir)", "felt · felt"), ("find (trouver)", "found · found"), ("fly (voler)", "flew · flown"),
        ("forget (oublier)", "forgot · forgotten"), ("get (obtenir)", "got · got (US : gotten)"), ("give (donner)", "gave · given"),
        ("go (aller)", "went · gone"), ("have (avoir)", "had · had"), ("hear (entendre)", "heard · heard"),
        ("keep (garder)", "kept · kept"), ("know (savoir, connaître)", "knew · known"), ("leave (partir, laisser)", "left · left"),
        ("lose (perdre)", "lost · lost"), ("make (fabriquer)", "made · made"), ("meet (rencontrer)", "met · met"),
        ("pay (payer)", "paid · paid"), ("put (mettre)", "put · put"), ("read (lire)", "read · read"),
        ("run (courir)", "ran · run"), ("say (dire)", "said · said"), ("see (voir)", "saw · seen"),
        ("sell (vendre)", "sold · sold"), ("send (envoyer)", "sent · sent"), ("sleep (dormir)", "slept · slept"),
        ("speak (parler)", "spoke · spoken"), ("swim (nager)", "swam · swum"), ("take (prendre)", "took · taken"),
        ("teach (enseigner)", "taught · taught"), ("tell (raconter, dire)", "told · told"), ("think (penser)", "thought · thought"),
        ("understand (comprendre)", "understood · understood"), ("wear (porter un vêtement)", "wore · worn"),
        ("win (gagner)", "won · won"), ("write (écrire)", "wrote · written")
    ])

    static let history = StarterDeck(id: "dates-histoire", name: "Grandes dates de l’histoire", emoji: "🏛️", color: .orange,
                                     subtitle: "Histoire de France et du monde", pairs: [
        ("Couronnement de Charlemagne empereur", "800"), ("Découverte de l’Amérique par Christophe Colomb", "1492"),
        ("Bataille de Marignan", "1515"), ("Édit de Nantes", "1598"), ("Prise de la Bastille", "14 juillet 1789"),
        ("Déclaration des droits de l’homme et du citoyen", "26 août 1789"), ("Sacre de Napoléon Iᵉʳ", "1804"),
        ("Bataille de Waterloo", "1815"), ("Abolition de l’esclavage en France", "1848"),
        ("Proclamation de la IIIᵉ République", "1870"), ("Loi de séparation des Églises et de l’État", "1905"),
        ("Première Guerre mondiale", "1914 – 1918"), ("Armistice de la Première Guerre mondiale", "11 novembre 1918"),
        ("Seconde Guerre mondiale", "1939 – 1945"), ("Débarquement de Normandie", "6 juin 1944"),
        ("Droit de vote des femmes en France", "1944 (premier vote en 1945)"), ("Naissance de la Vᵉ République", "1958"),
        ("Indépendance de l’Algérie", "1962"), ("Mai 68", "1968"), ("Premiers pas de l’Homme sur la Lune", "1969"),
        ("Abolition de la peine de mort en France", "1981"), ("Chute du mur de Berlin", "1989"),
        ("Passage à l’euro (pièces et billets)", "2002")
    ])

    static let elements = StarterDeck(id: "tableau-periodique", name: "Tableau périodique", emoji: "🧪", color: .green,
                                      subtitle: "Les symboles des éléments courants", pairs: [
        ("H", "Hydrogène"), ("He", "Hélium"), ("Li", "Lithium"), ("C", "Carbone"), ("N", "Azote"), ("O", "Oxygène"),
        ("F", "Fluor"), ("Ne", "Néon"), ("Na", "Sodium"), ("Mg", "Magnésium"), ("Al", "Aluminium"), ("Si", "Silicium"),
        ("P", "Phosphore"), ("S", "Soufre"), ("Cl", "Chlore"), ("Ar", "Argon"), ("K", "Potassium"), ("Ca", "Calcium"),
        ("Fe", "Fer"), ("Cu", "Cuivre"), ("Zn", "Zinc"), ("Ag", "Argent"), ("Sn", "Étain"), ("Au", "Or"),
        ("Hg", "Mercure"), ("Pb", "Plomb"), ("U", "Uranium")
    ])

    static let maths = StarterDeck(id: "formules-maths", name: "Formules de maths", emoji: "🧮", color: .blue,
                                   subtitle: "Aires, volumes et identités (collège)", pairs: [
        ("Théorème de Pythagore (triangle rectangle, c l’hypoténuse)", "a² + b² = c²"),
        ("Périmètre d’un cercle de rayon r", "2 × π × r"), ("Aire d’un disque de rayon r", "π × r²"),
        ("Aire d’un triangle", "base × hauteur ÷ 2"), ("Aire d’un rectangle", "longueur × largeur"),
        ("Aire d’un trapèze", "(grande base + petite base) × hauteur ÷ 2"), ("Volume d’un cube d’arête a", "a³"),
        ("Volume d’un pavé droit", "longueur × largeur × hauteur"), ("Volume d’un cylindre", "π × r² × h"),
        ("Volume d’un cône", "π × r² × h ÷ 3"), ("Volume d’une boule de rayon r", "4/3 × π × r³"),
        ("(a + b)²", "a² + 2ab + b²"), ("(a − b)²", "a² − 2ab + b²"), ("(a + b)(a − b)", "a² − b²"),
        ("Vitesse moyenne", "distance ÷ temps"), ("Somme des angles d’un triangle", "180°")
    ])
}

struct StarterDecksView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(StarterDecks.all) { s in
                        let added = store.decks.contains { $0.starterID == s.id }
                        HStack(spacing: 14) {
                            DeckBadge(deck: Deck(name: s.name, emoji: s.emoji, color: s.color), size: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.name).font(.headline)
                                Text(s.subtitle).font(.footnote).foregroundStyle(.secondary)
                                Text("\(s.pairs.count) cartes").font(.caption.weight(.semibold)).foregroundStyle(s.color.color)
                            }
                            Spacer()
                            Button {
                                store.createDeck(name: s.name, emoji: s.emoji, color: s.color,
                                                 cards: s.pairs.map { Card(front: $0.0, back: $0.1) }, starterID: s.id)
                            } label: {
                                Image(systemName: added ? "checkmark" : "plus")
                                    .font(.headline)
                                    .frame(width: 40, height: 40)
                                    .glassCircle()
                            }
                            .buttonStyle(PressStyle())
                            .disabled(added)
                            .accessibilityLabel(added ? "Déjà ajouté" : "Ajouter « \(s.name) »")
                        }
                        .padding(14)
                        .glass(22)
                    }
                }
                .padding(20)
            }
            .background { AppBackground() }
            .navigationTitle("Paquets tout prêts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() }.fontWeight(.semibold) }
            }
        }
    }
}
