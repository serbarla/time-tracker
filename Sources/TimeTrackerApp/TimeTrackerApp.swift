import AppKit
import Carbon
import Combine
import SwiftUI
import TimeTrackerCore
import UserNotifications

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
    private var boundaryTimer: Timer?
    private var lastIconTint: StateColor?
    private var checksObservation: AnyCancellable?
    private var hotKey: HotKey?
    /// Last observed state per check, in memory only; refreshed on every evaluation.
    private var lastSeenStates: [UUID: Bool] = [:]
    private var requestedNotificationAuthorization = false

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
        boundaryTimer?.invalidate()
        hotKey?.unregister()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "clock",
                                     accessibilityDescription: Localization.shared.t("app.accessibilityName"))
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .aqua)
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(store)
                .environmentObject(Localization.shared)
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
        let checks = store.checks
        let states = checks.map { OverlapEngine.evaluate(check: $0, now: now) }
        announceFlips(checks: checks, states: states, now: now)

        let names = zip(checks, states)
            .filter { $0.1.isOverlapping }
            .map { $0.0.name }
        if let button = statusItem?.button {
            button.title = names.isEmpty ? "" : names.joined(separator: ", ") + " "
            button.imagePosition = names.isEmpty ? .imageOnly : .imageRight
        }

        // Tint by state: first active check's active color (check order); green
        // when none is active (v1 checks have no `states` -> green default).
        let activeColor = zip(checks, states)
            .first { $0.1.isOverlapping }?
            .0.displayStates.active.color ?? .green
        updateIcon(tint: activeColor)

        rescheduleBoundaryTimer(at: states.compactMap(\.nextTransition).min())
    }

    /// Colored (non-template) clock symbol; `contentTintColor` alone renders
    /// black in the menubar, palette configuration renders the exact color.
    private func updateIcon(tint: StateColor) {
        guard tint != lastIconTint else { return }
        lastIconTint = tint
        let config = NSImage.SymbolConfiguration(paletteColors: [tint.nsColor])
        let image = NSImage(systemSymbolName: "clock",
                            accessibilityDescription: Localization.shared.t("app.accessibilityName"))?
            .withSymbolConfiguration(config)
        image?.isTemplate = false
        statusItem?.button?.image = image
    }

    /// One-shot timer at the earliest upcoming state flip; invalidated and
    /// rescheduled on every fire and store change (both go through `updateLabel`).
    private func rescheduleBoundaryTimer(at transition: Date?) {
        boundaryTimer?.invalidate()
        boundaryTimer = nil
        guard let transition, transition > Date() else { return }
        // Small offset so the fire lands after the boundary has passed.
        let timer = Timer(fire: transition.addingTimeInterval(0.25), interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateLabel() }
        }
        RunLoop.main.add(timer, forMode: .common)
        boundaryTimer = timer
    }

    /// Compares this evaluation's states against the last-seen ones (in-memory,
    /// per check) and announces fresh flips. The first observation after launch
    /// only records; a flip whose current stretch began more than 5 minutes ago
    /// resyncs silently, so anything missed while asleep or closed is never
    /// announced late. Checks without `notifyOnFlip` are tracked but never announced.
    private func announceFlips(checks: [Check], states: [OverlapState], now: Date) {
        let ids = Set(checks.map(\.id))
        lastSeenStates = lastSeenStates.filter { ids.contains($0.key) }

        // Lazily ask permission the first time an enabled check exists; once per run.
        if !requestedNotificationAuthorization, checks.contains(where: \.notifyOnFlip) {
            requestNotificationAuthorizationOnce()
        }

        for (check, state) in zip(checks, states) {
            let previous = lastSeenStates[check.id]
            lastSeenStates[check.id] = state.isOverlapping
            guard let previous, previous != state.isOverlapping else { continue }
            guard check.notifyOnFlip,
                  let windowStart = state.windowStart,
                  now.timeIntervalSince(windowStart) <= 5 * 60 else { continue }
            deliverFlipNotification(check: check, state: state)
        }
    }

    private func requestNotificationAuthorizationOnce() {
        requestedNotificationAuthorization = true
        // `swift run` is not a bundle: UNUserNotificationCenter would raise there.
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// `<check name>: <new state label>` + when the next flip comes, in the
    /// status tab's phrasing: `until HH:mm` while active, `from HH:mm` while
    /// out; local clock, like the overlap warning.
    private func deliverFlipNotification(check: Check, state: OverlapState) {
        let style = state.isOverlapping ? check.displayStates.active : check.displayStates.inactive
        let loc = Localization.shared
        let content = UNMutableNotificationContent()
        content.title = "\(check.name): \(style.label)"
        if let next = state.nextTransition {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            content.body = loc.format(state.isOverlapping ? "notify.until" : "notify.from", f.string(from: next))
        } else {
            content.body = loc.t("notify.furtherNotice")
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
