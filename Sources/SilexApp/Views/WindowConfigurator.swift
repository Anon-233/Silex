import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        HidingView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            context.coordinator.configure(window)
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        func configure(_ window: NSWindow) {
            window.contentAspectRatio = NSSize(width: 4, height: 3)
            window.contentMinSize = NSSize(width: 760, height: 570)
            window.title = "Silex"
            if window.delegate !== self {
                window.delegate = self
            }
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
        }
    }
}

private final class HidingView: NSView {
    private let coordinator: WindowConfigurator.Coordinator

    init(coordinator: WindowConfigurator.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = self.window else { return }
        coordinator.configure(window)
    }
}
