import AppKit
import SwiftUI
import UserNotifications
import IOKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    let timerManager = TimerManager()
    private var ticker: Timer?
    private var isUserActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        setupStatusItem()
        setupPopover()
        startTicker()
        setupSystemNotifications()
    }

    // MARK: - Menubar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "⏱"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(timerManager)
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Activiteitsdetectie

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let idle = self.systemIdleTime()
            let active = idle < 60

            if active != self.isUserActive {
                self.isUserActive = active
                if active {
                    self.timerManager.resetSession()
                }
            }

            if active {
                self.timerManager.tickActivity()
                self.statusItem?.button?.title = self.timerManager.activeDisplayTitle()
            } else {
                self.statusItem?.button?.title = "⏸"
            }
        }
    }

    private func setupSystemNotifications() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(systemSleep),
                       name: NSWorkspace.willSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(systemSleep),
                       name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(systemWake),
                       name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(systemWake),
                       name: NSWorkspace.screensDidWakeNotification, object: nil)

        let dc = DistributedNotificationCenter.default()
        dc.addObserver(self, selector: #selector(systemSleep),
                       name: NSNotification.Name("com.apple.screensaver.didstart"), object: nil)
        dc.addObserver(self, selector: #selector(systemWake),
                       name: NSNotification.Name("com.apple.screensaver.didstop"), object: nil)
    }

    @objc private func systemSleep() {
        isUserActive = false
        statusItem?.button?.title = "⏸"
    }

    @objc private func systemWake() {
        // Ticker pikt de activiteit op bij de volgende tick
    }

    private func systemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                          IOServiceMatching("IOHIDSystem"),
                                          &iterator) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any],
              let idleNs = dict["HIDIdleTime"] as? UInt64 else { return 0 }

        return TimeInterval(idleNs) / 1_000_000_000
    }
}
