import AppKit
import Carbon
import Combine
import SwiftUI
import TimeTrackerCore

@main
struct TimeTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = CheckStore()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var labelTimer: Timer?
    private var checksObservation: AnyCancellable?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        setupHotKey()
        observeChecks()
        updateLabel()

        labelTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateLabel() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        labelTimer?.invalidate()
        hotKey?.unregister()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Time Tracker")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(store)
        )
        popover.contentSize = NSSize(width: 380, height: 588)
        self.popover = popover
    }

    private func setupHotKey() {
        let hotKey = HotKey { [weak self] in
            self?.togglePopover()
        }
        // Default: Control+Option+T. Change keyCode/modifiers to remap.
        hotKey.register(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | optionKey))
        self.hotKey = hotKey
    }

    private func observeChecks() {
        checksObservation = store.$checks
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.updateLabel() }
            }
    }

    private func updateLabel() {
        let now = Date()
        let names = store.checks
            .filter { OverlapEngine.evaluate(check: $0, now: now).isOverlapping }
            .map(\.name)
        statusItem?.button?.title = names.isEmpty ? "" : " " + names.joined(separator: ", ")
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
