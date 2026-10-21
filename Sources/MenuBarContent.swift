import SwiftUI

struct MenuBarContent: View {
    @Bindable var store: OverlayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nightprism").font(.headline)
                Spacer()
                Button {
                    store.addOverlay()
                } label: {
                    Label("New Overlay", systemImage: "plus.rectangle")
                }
                .buttonStyle(.borderless)
            }

            Divider()

            if store.overlays.isEmpty {
                Text("No overlays. Click **New Overlay** to add one.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.overlays) { overlay in
                            OverlayRow(overlay: overlay, store: store)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            Divider()

            Button("Quit Nightprism") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 320)
    }
}

private struct OverlayRow: View {
    let overlay: Overlay
    let store: OverlayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: overlay.locked ? "lock.fill" : "lock.open")
                Text(overlay.id.uuidString.prefix(8))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    var updated = overlay
                    updated.locked.toggle()
                    store.update(updated)
                } label: {
                    Image(systemName: overlay.locked ? "lock.open" : "lock.fill")
                }
                .buttonStyle(.borderless)
                .help(overlay.locked ? "Unlock position" : "Lock position")

                Button(role: .destructive) {
                    store.remove(overlay.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            HStack {
                Image(systemName: "circle.lefthalf.filled")
                Slider(
                    value: Binding(
                        get: { overlay.opacity },
                        set: { newValue in
                            var updated = overlay
                            updated.opacity = newValue
                            store.update(updated)
                        }
                    ),
                    in: 0...1
                )
                Text("\(Int(overlay.opacity * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
