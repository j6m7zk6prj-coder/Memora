import SwiftUI
import UserNotifications

// MARK: - Réglages : objectif, nouvelles cartes, rappel quotidien

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 18 * 60
    @State private var denied = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    Stepper("Objectif : \(store.dailyGoal) cartes par jour", value: $store.dailyGoal, in: 5...300, step: 5)
                    Stepper("\(store.newPerDay) nouvelles cartes par jour et par paquet", value: $store.newPerDay, in: 0...100, step: 5)
                } header: {
                    Text("Révisions")
                } footer: {
                    Text("Moins de nouvelles cartes = des séances plus courtes. Les cartes déjà vues reviennent toujours au bon moment.")
                }

                Section {
                    Toggle("Rappel chaque jour", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("Heure", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Rappel")
                } footer: {
                    if denied {
                        Text("Les notifications sont désactivées pour Mémora : active-les dans Réglages › Notifications.")
                    } else {
                        Text("Une notification pour ne pas casser ta série 🔥")
                    }
                }

                Section("Confort") {
                    Toggle("Vibrations", isOn: $store.haptics)
                }

                Section("Infos") {
                    LabeledContent("Paquets", value: "\(store.decks.count)")
                    LabeledContent("Cartes", value: "\(store.totalCards)")
                    LabeledContent("Série", value: "\(store.streak) jour\(store.streak > 1 ? "s" : "")")
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() }.fontWeight(.semibold) }
            }
            .onChange(of: reminderOn) { _, _ in Task { await Reminder.update(on: reminderOn, minutes: reminderMinutes) { denied = $0 } } }
            .onChange(of: reminderMinutes) { _, _ in Task { await Reminder.update(on: reminderOn, minutes: reminderMinutes) { denied = $0 } } }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            reminderMinutes = (c.hour ?? 18) * 60 + (c.minute ?? 0)
        }
    }
}

enum Reminder {
    static let id = "memora.daily"

    /// Programme (ou retire) la notification quotidienne.
    @MainActor
    static func update(on: Bool, minutes: Int, denied: (Bool) -> Void) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard on else { denied(false); return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        denied(!granted)
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "C’est l’heure de réviser 🧠"
        content.body = "Quelques minutes suffisent pour garder ta série."
        content.sound = .default
        var when = DateComponents()
        when.hour = minutes / 60
        when.minute = minutes % 60
        let request = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        try? await center.add(request)
    }
}
