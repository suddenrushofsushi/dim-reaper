import AppKit
import Testing

@testable import Nightprism

@MainActor
struct OverlayStoreTests {
    private let suiteName = "NightprismTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    @Test
    func createsIndependentOverlaysAndPresentsTheirWindows() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let windows = TestWindows()
        let store = makeStore(windows: windows)

        store.addOverlay()
        store.addOverlay()

        #expect(store.overlays.count == 2)
        #expect(Set(store.overlays.map(\.id)).count == 2)
        #expect(store.overlays.allSatisfy { $0.opacity == 0.5 && !$0.locked })
        #expect(store.overlays.allSatisfy { $0.frame.width > 0 && $0.frame.height > 0 })
        #expect(windows.controllers.count == 2)
        #expect(windows.controllers.values.allSatisfy { $0.showCount == 1 })
    }

    @Test
    func updatesWindowAndRestoresFrameOpacityAndLock() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let windows = TestWindows()
        let store = makeStore(windows: windows)
        store.addOverlay()
        var overlay = try #require(store.overlays.first)
        overlay.opacity = 0.73
        overlay.locked = true
        store.update(overlay)

        #expect(windows.controllers[overlay.id]?.lastApplied == overlay)

        let movedFrame = CGRect(x: -500, y: 150, width: 420, height: 270)
        store.handleFrameChange(id: overlay.id, frame: movedFrame)

        let restoredWindows = TestWindows()
        let restored = makeStore(windows: restoredWindows)
        let saved = try #require(restored.overlays.first)
        #expect(saved.id == overlay.id)
        #expect(saved.frame == movedFrame)
        #expect(saved.opacity == 0.73)
        #expect(saved.locked)
        #expect(restoredWindows.controllers[saved.id]?.showCount == 1)
    }

    @Test
    func removesOnlyRequestedOverlayAndPersistsDeletion() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let windows = TestWindows()
        let store = makeStore(windows: windows)
        store.addOverlay()
        store.addOverlay()
        let removed = try #require(store.overlays.first)
        let remaining = try #require(store.overlays.last)
        let removedWindow = try #require(windows.controllers[removed.id])

        store.remove(removed.id)

        #expect(removedWindow.closeCount == 1)
        #expect(store.overlays == [remaining])
        #expect(makeStore(windows: TestWindows()).overlays == [remaining])
    }

    @Test
    func ignoresUpdatesForUnknownOverlays() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let windows = TestWindows()
        let store = makeStore(windows: windows)
        let unknown = Overlay(frame: .zero, opacity: 0.9, locked: true)

        store.update(unknown)
        store.handleFrameChange(id: unknown.id, frame: CGRect(x: 0, y: 0, width: 10, height: 10))

        #expect(store.overlays.isEmpty)
        #expect(windows.controllers.isEmpty)
        #expect(defaults.data(forKey: "Nightprism.overlays.v1") == nil)
    }

    @Test
    func readsOriginalV1PersistenceFormat() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let id = UUID()
        let legacy = """
            [{"id":"\(id.uuidString)","x":10,"y":20,"w":600,"h":400,"opacity":0.35,"locked":true}]
            """
        defaults.set(Data(legacy.utf8), forKey: "Nightprism.overlays.v1")

        let restored = makeStore(windows: TestWindows())

        #expect(
            restored.overlays == [
                Overlay(
                    id: id, frame: CGRect(x: 10, y: 20, width: 600, height: 400), opacity: 0.35,
                    locked: true)
            ])
    }

    @Test
    func handlesCorruptPersistenceWithoutOpeningWindows() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("invalid JSON".utf8), forKey: "Nightprism.overlays.v1")
        let windows = TestWindows()

        let store = makeStore(windows: windows)

        #expect(store.overlays.isEmpty)
        #expect(windows.controllers.isEmpty)
    }

    private func makeStore(windows: TestWindows) -> OverlayStore {
        OverlayStore(defaults: defaults) { overlay, _ in
            let controller = TestWindow()
            windows.controllers[overlay.id] = controller
            return controller
        }
    }
}

@MainActor
private final class TestWindows {
    var controllers: [Overlay.ID: TestWindow] = [:]
}

@MainActor
private final class TestWindow: OverlayWindowControlling {
    private(set) var showCount = 0
    private(set) var closeCount = 0
    private(set) var lastApplied: Overlay?

    func showWindow(_ sender: Any?) { showCount += 1 }
    func close() { closeCount += 1 }
    func apply(_ overlay: Overlay) { lastApplied = overlay }
}
