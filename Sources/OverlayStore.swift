import AppKit
import Observation

@MainActor
protocol OverlayWindowControlling: AnyObject {
    func showWindow(_ sender: Any?)
    func close()
    func apply(_ overlay: Overlay)
}

@Observable
@MainActor
final class OverlayStore {
    private(set) var overlays: [Overlay] = []
    @ObservationIgnored private var controllers: [Overlay.ID: any OverlayWindowControlling] = [:]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let controllerFactory:
        @MainActor (Overlay, OverlayStore) -> any OverlayWindowControlling

    private let persistenceKey = "Nightprism.overlays.v1"

    init(
        defaults: UserDefaults = .standard,
        controllerFactory:
            @escaping @MainActor (Overlay, OverlayStore) -> any OverlayWindowControlling = {
                OverlayWindowController(overlay: $0, store: $1)
            }
    ) {
        self.defaults = defaults
        self.controllerFactory = controllerFactory
        load()
    }

    func addOverlay() {
        let screenFrame =
            NSScreen.main?.visibleFrame ?? CGRect(x: 200, y: 200, width: 800, height: 600)
        let size = CGSize(
            width: min(600, screenFrame.width * 0.4),
            height: min(400, screenFrame.height * 0.4))
        let origin = CGPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2)
        let overlay = Overlay(
            frame: CGRect(origin: origin, size: size), opacity: 0.5, locked: false)
        overlays.append(overlay)
        present(overlay)
        persist()
    }

    func remove(_ id: Overlay.ID) {
        controllers[id]?.close()
        controllers[id] = nil
        overlays.removeAll { $0.id == id }
        persist()
    }

    func update(_ overlay: Overlay) {
        guard let idx = overlays.firstIndex(where: { $0.id == overlay.id }) else { return }
        overlays[idx] = overlay
        controllers[overlay.id]?.apply(overlay)
        persist()
    }

    func handleFrameChange(id: Overlay.ID, frame: CGRect) {
        guard let idx = overlays.firstIndex(where: { $0.id == id }) else { return }
        overlays[idx].frame = frame
        persist()
    }

    private func present(_ overlay: Overlay) {
        let controller = controllerFactory(overlay, self)
        controllers[overlay.id] = controller
        controller.showWindow(nil)
    }

    // MARK: - Persistence

    private func persist() {
        let payload = overlays.map { OverlayDTO(from: $0) }
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: persistenceKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: persistenceKey),
            let payload = try? JSONDecoder().decode([OverlayDTO].self, from: data)
        else { return }
        overlays = payload.map { $0.toOverlay() }
        for overlay in overlays { present(overlay) }
    }
}

struct Overlay: Identifiable, Hashable {
    let id: UUID
    var frame: CGRect
    var opacity: Double  // 0...1
    var locked: Bool

    init(id: UUID = UUID(), frame: CGRect, opacity: Double, locked: Bool) {
        self.id = id
        self.frame = frame
        self.opacity = opacity
        self.locked = locked
    }
}

private struct OverlayDTO: Codable {
    var id: UUID
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var opacity: Double
    var locked: Bool

    init(from o: Overlay) {
        id = o.id
        x = o.frame.minX
        y = o.frame.minY
        w = o.frame.width
        h = o.frame.height
        opacity = o.opacity
        locked = o.locked
    }
    func toOverlay() -> Overlay {
        Overlay(
            id: id, frame: CGRect(x: x, y: y, width: w, height: h), opacity: opacity, locked: locked
        )
    }
}
