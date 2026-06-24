import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        window.contentAspectRatio = NSSize(width: 4, height: 3)
        window.contentMinSize = NSSize(width: 760, height: 570)
        window.title = "Silex"
        if window.delegate !== coordinator {
            window.delegate = coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        static var needsActivation = false

        func windowDidChangeOcclusionState(_ notification: Notification) {
            guard
                Self.needsActivation,
                let window = notification.object as? NSWindow,
                window.isVisible
            else { return }
            Self.needsActivation = false
            let saved = window.level
            window.level = .floating
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate()
            window.level = saved
        }
    }
}
