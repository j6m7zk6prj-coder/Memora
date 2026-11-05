import SwiftUI

// MARK: - La séance de révision : une carte à la fois, on la retourne, on dit si on savait

struct StudyView: View {
    let target: StudyTarget
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [SessionItem] = []
    @State private var total = 0
    @State private var done = 0
    @State private var flipped = false
    @State private var started = false
    @State private var results: [Grade: Int] = [:]
    @State private var drag: CGSize = .zero
    @State private var feedback = 0

    var body: some View {
        ZStack {
            AppBackground(tint: tint)
            VStack(spacing: 18) {
                header
                if let item = queue.first {
                    Spacer(minLength: 0)
                    FlipCard(item: item, flipped: flipped, tint: tint)
                        .id(item.id)
                        .offset(x: drag.width, y: drag.height * 0.2)
                        .rotationEffect(.degrees(Double(drag.width) / 22))
                        .overlay(alignment: .top) { swipeHint }
                        .gesture(swipe(item))
                        .onTapGesture { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { flipped.toggle() } }
                        .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity),
                                                removal: .opacity))
                    Spacer(minLength: 0)
                    controls(item)
                } else if started {
                    summary
                }
            }
            .padding(20)
        }
        .sensoryFeedback(trigger: feedback) { _, _ in store.haptics ? .impact(weight: .light) : nil }
        .onAppear {
            guard !started else { return }
            queue = target.practice ? store.practiceSession(for: target.deckIDs) : store.session(for: target.deckIDs)
            total = queue.count
            started = true
        }
    }

    private var tint: Color {
        if target.deckIDs.count == 1, let d = store.deck(target.deckIDs[0]) { return d.color.color }
        return .brand
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 40, height: 40)
                        .glassCircle()
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Arrêter la séance")
                Spacer()
                VStack(spacing: 0) {
                    Text(target.title).font(.headline).lineLimit(1)
                    Text(target.practice ? "Entraînement libre" : "\(queue.count) restante\(queue.count > 1 ? "s" : "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            ProgressView(value: Double(done), total: Double(max(1, total + (results[.again] ?? 0))))
                .tint(tint)
        }
    }

    /// « Je savais » à droite, « À revoir » à gauche, quand on glisse la carte.
    @ViewBuilder private var swipeHint: some View {
        if flipped, abs(drag.width) > 30 {
            let good = drag.width > 0
            Text(good ? "BIEN" : "À REVOIR")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(good ? Color.green : Color.red))
                .padding(.top, 18)
                .opacity(min(1, Double(abs(drag.width) - 30) / 60))
        }
    }

    private func swipe(_ item: SessionItem) -> some Gesture {
        DragGesture()
            .onChanged { g in if flipped { drag = g.translation } }
            .onEnded { g in
                guard flipped else { return }
                if g.translation.width > 110 { answer(item, .good) }
                else if g.translation.width < -110 { answer(item, .again) }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { drag = .zero }
            }
    }

    @ViewBuilder private func controls(_ item: SessionItem) -> some View {
        if flipped {
            HStack(spacing: 8) {
                ForEach(Grade.allCases) { g in
                    Button { answer(item, g) } label: {
                        VStack(spacing: 3) {
                            Text(g.label).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                            if !target.practice {
                                Text(Scheduler.preview(item.card, g)).font(.caption2.weight(.medium)).opacity(0.8)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(g.color.gradient))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { flipped = true }
            } label: {
                Label("Voir la réponse", systemImage: "rotate.3d")
            }
            .buttonStyle(BigButtonStyle(color: tint))
            .transition(.opacity)
        }
    }

    private func answer(_ item: SessionItem, _ grade: Grade) {
        feedback += 1
        results[grade, default: 0] += 1
        if target.practice {
            store.notePractice()
        } else {
            _ = store.record(item, grade)
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            var rest = Array(queue.dropFirst())
            if grade == .again {
                // Oubliée : elle revient un peu plus loin dans la séance.
                var again = item
                again.card = store.deck(item.deckID)?.cards.first { $0.id == item.id } ?? item.card
                rest.insert(again, at: min(rest.count, 4))
            } else {
                done += 1
            }
            queue = rest
            flipped = false
        }
    }

    private var summary: some View {
        VStack(spacing: 22) {
            Spacer()
            Text(total == 0 ? "🎈" : "🎉").font(.system(size: 72))
            Text(total == 0 ? "Rien à réviser" : "Séance terminée !").font(.largeTitle.bold())
            if total > 0 {
                HStack(spacing: 12) {
                    ForEach(Grade.allCases) { g in
                        VStack(spacing: 4) {
                            Text("\(results[g] ?? 0)").font(.title2.bold().monospacedDigit()).foregroundStyle(g.color)
                            Text(g.label).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .glass(22)
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text("\(store.streak) jour\(store.streak > 1 ? "s" : "") d’affilée · \(store.reviewedToday)/\(store.dailyGoal) aujourd’hui")
                }
                .font(.subheadline.weight(.semibold))
            } else {
                Text("Reviens demain : tes cartes reviendront pile au bon moment.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Terminer") { dismiss() }
                .buttonStyle(BigButtonStyle(color: tint))
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

/// La carte qui se retourne en 3D : la question devant, la réponse derrière.
private struct FlipCard: View {
    let item: SessionItem
    let flipped: Bool
    let tint: Color
    @Environment(Store.self) private var store

    var body: some View {
        ZStack {
            face(text: item.card.front, label: "QUESTION", isBack: false)
                .opacity(flipped ? 0 : 1)
            face(text: item.card.back, label: "RÉPONSE", isBack: true)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 340, maxHeight: 460)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(flipped ? "Réponse : \(item.card.back)" : "Question : \(item.card.front)")
        .accessibilityHint(flipped ? "" : "Touche pour voir la réponse")
    }

    private func face(text: String, label: String, isBack: Bool) -> some View {
        VStack(spacing: 14) {
            HStack {
                if let d = store.deck(item.deckID) {
                    Text(d.emoji + " " + d.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(label).font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(isBack ? tint : .secondary)
            }
            Spacer(minLength: 0)
            ScrollView {
                Text(text)
                    .font(text.count < 40 ? .system(size: 30, weight: .bold) : .title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 300)
            Spacer(minLength: 0)
            if !isBack {
                Text("Touche la carte pour la retourner").font(.caption).foregroundStyle(.tertiary)
            } else if item.card.isNew {
                Text("Nouvelle carte").font(.caption.weight(.semibold)).foregroundStyle(.blue)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glass(32)
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(isBack ? tint.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 24, y: 12)
    }
}
