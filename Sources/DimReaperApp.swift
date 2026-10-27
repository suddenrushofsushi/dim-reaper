import SwiftUI

@main
struct DimReaperApp: App {
    @State private var store = OverlayStore(legacyDomainName: "com.cwaterman.Nightprism")

    var body: some Scene {
        Window("Dim Reaper Controls", id: "controls") {
            MenuBarContent(store: store, showsOpenControls: false)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContent(store: store)
        } label: {
            Image(systemName: "moon.stars.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
