import SwiftUI

@main
struct NightprismApp: App {
    @State private var store = OverlayStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(store: store)
        } label: {
            Image(systemName: "moon.stars.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
