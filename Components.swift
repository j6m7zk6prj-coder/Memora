import SwiftUI

// MARK: - Liquid Glass (iOS 26) avec un verre dépoli sur les iOS plus anciens

extension View {
    func glass(_ radius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(GlassStyle(shape: RoundedRectangle(cornerRadius: radius, style: .continuous), interactive: interactive))
    }

    func glassCapsule(interactive: Bool = false) -> some View {
        modifier(GlassStyle(shape: Capsule(), interactive: interactive))
    }

    func glassCircle() -> some View {
        modifier(GlassStyle(shape: Circle(), interactive: true))
    }
}

struct GlassStyle<S: InsettableShape>: ViewModifier {
    let shape: S
    var interactive = false

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if interactive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            frosted(content)
        }
        #else
        frosted(content)
        #endif
    }

    private func frosted(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.05), .white.opacity(0.15)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
    }
}

/// Le bouton s'enfonce légèrement quand on appuie dessus.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Bouton principal : capsule pleine de couleur.
struct BigButtonStyle: ButtonStyle {
    var color: Color = .brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(color.gradient))
            .shadow(color: color.opacity(0.35), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Fond de l'app : un léger dégradé de couleur qui donne de la profondeur au verre.
struct AppBackground: View {
    var tint: Color = .indigo
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(colors: [tint.opacity(scheme == .dark ? 0.35 : 0.18), .clear],
                           center: .topLeading, startRadius: 20, endRadius: 520)
            RadialGradient(colors: [Color.pink.opacity(scheme == .dark ? 0.18 : 0.1), .clear],
                           center: .bottomTrailing, startRadius: 20, endRadius: 480)
        }
        .ignoresSafeArea()
    }
}

/// Anneau de progression (objectif du jour).
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var color: Color = .brand

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

/// Pastille d'un paquet : son émoji sur sa couleur.
struct DeckBadge: View {
    let deck: Deck
    var size: CGFloat = 48

    var body: some View {
        Text(deck.emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(deck.color.color.gradient))
            .shadow(color: deck.color.color.opacity(0.35), radius: 6, y: 3)
    }
}

/// Barre de niveaux d'un paquet : nouvelles, en cours, connues, maîtrisées.
struct LevelBar: View {
    let deck: Deck

    var body: some View {
        let total = max(1, deck.cards.count)
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Card.Level.allCases, id: \.self) { level in
                    let n = deck.cards.filter { $0.level == level }.count
                    if n > 0 {
                        Capsule()
                            .fill(level.color.gradient)
                            .frame(width: max(4, geo.size.width * CGFloat(n) / CGFloat(total) - 2))
                    }
                }
            }
        }
        .frame(height: 6)
        .background(Capsule().fill(Color.primary.opacity(0.08)))
        .clipShape(Capsule())
    }
}

extension Color {
    /// La couleur de Mémora (violet).
    static let brand = Color(red: 0.42, green: 0.36, blue: 1.0)
}
