import AppKit
import SwiftUI
import SilexCore

struct WindowInputAdapter: NSViewRepresentable {
    let isBlocked: () -> Bool
    let move: (PageDirection) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isBlocked: isBlocked, move: move)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isBlocked = isBlocked
        context.coordinator.move = move
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        var isBlocked: () -> Bool
        var move: (PageDirection) -> Void

        private weak var view: NSView?
        private var monitor: Any?
        private var horizontalDistance: CGFloat = 0
        private var verticalDistance: CGFloat = 0
        private var didNavigate = false
        private var navigatedThisGesture = false
        private var resetWorkItem: DispatchWorkItem?

        init(
            isBlocked: @escaping () -> Bool,
            move: @escaping (PageDirection) -> Void
        ) {
            self.isBlocked = isBlocked
            self.move = move
        }

        func attach(to view: NSView) {
            self.view = view
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(
                matching: [.scrollWheel, .keyDown]
            ) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func detach() {
            resetWorkItem?.cancel()
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard
                let window = view?.window,
                event.window === window
            else {
                return event
            }

            switch event.type {
            case .keyDown:
                return handleKey(event, window: window)
            case .scrollWheel:
                return handleScroll(event)
            default:
                return event
            }
        }

        private func handleKey(_ event: NSEvent, window: NSWindow) -> NSEvent? {
            guard
                !isBlocked(),
                !(window.firstResponder is NSTextView),
                event.modifierFlags
                    .intersection([.command, .option, .control])
                    .isEmpty
            else {
                return event
            }

            switch event.keyCode {
            case 123:
                move(.previous)
                return nil
            case 124:
                move(.next)
                return nil
            default:
                return event
            }
        }

        private func handleScroll(_ event: NSEvent) -> NSEvent? {
            if event.phase == .began {
                resetGesture()
            }

            if event.momentumPhase == .ended
                || event.momentumPhase == .cancelled
            {
                resetGesture()
                return event
            }

            if event.phase == .ended
                || event.phase == .cancelled
            {
                horizontalDistance = 0
                verticalDistance = 0
                didNavigate = false
                return event
            }

            guard !isBlocked() else {
                resetGesture()
                return event
            }

            horizontalDistance += event.scrollingDeltaX
            verticalDistance += event.scrollingDeltaY

            guard
                !navigatedThisGesture,
                abs(horizontalDistance) >= 60,
                abs(horizontalDistance) > abs(verticalDistance) * 1.25
            else {
                scheduleLegacyResetIfNeeded(for: event)
                return event
            }

            navigatedThisGesture = true
            didNavigate = true
            move(horizontalDistance > 0 ? .previous : .next)
            scheduleLegacyResetIfNeeded(for: event)
            return nil
        }

        private func scheduleLegacyResetIfNeeded(for event: NSEvent) {
            guard event.phase == [] && event.momentumPhase == [] else {
                return
            }
            resetWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.resetGesture()
            }
            resetWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: item)
        }

        private func resetGesture() {
            horizontalDistance = 0
            verticalDistance = 0
            didNavigate = false
            navigatedThisGesture = false
        }
    }
}
