import SwiftUI

@main
struct MemoraApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .tint(.brand)
        }
    }
}
