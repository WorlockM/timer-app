import AppKit
import SwiftUI
import UserNotifications
import IOKit
import IOKit.pwr_mgt
import CoreAudio
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    let timerManager = TimerManager()
    private var ticker: Timer?
    private var isUserActive = false
    private var inactiveStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        setupStatusItem()
        setupPopover()
        startTicker()
        setupSystemNotifications()
        setupLimitAlerts()
    }

    // MARK: - Limit alerts

    private func setupLimitAlerts() {
        timerManager.$showSessionLimitAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if show { self?.openPopover() }
            }
            .store(in: &cancellables)

        timerManager.$showDailyLimitAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if show { self?.openPopover() }
            }
            .store(in: &cancellables)
    }

    private func openPopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
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
        popover.behavior = .transient
        let hostingController = NSHostingController(
            rootView: MenuBarView().environmentObject(timerManager)
        )
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
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
            let active = idle < 60 || self.isAudioActive() || self.isVideoPlaying()

            if active != self.isUserActive {
                self.isUserActive = active
                if active {
                    if let start = self.inactiveStartTime {
                        let inactiveDuration = Date().timeIntervalSince(start)
                        if inactiveDuration >= TimeInterval(self.timerManager.sessionResetMinutes * 60) {
                            self.timerManager.resetSession()
                        }
                    }
                    self.inactiveStartTime = nil
                } else {
                    self.inactiveStartTime = Date()
                }
            }

            if active {
                self.timerManager.tickActivity()
                self.statusItem?.button?.title = "⏱"
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
        if isUserActive {
            isUserActive = false
            inactiveStartTime = Date()
        }
        statusItem?.button?.title = "⏸"
    }

    @objc private func systemWake() {
        // Ticker pikt de activiteit op bij de volgende tick
    }

    private func isAudioActive() -> Bool {
        return isMicrophoneActive()
    }

    private func isVideoPlaying() -> Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let dict = status?.takeRetainedValue() as? [String: Int] else { return false }
        let count = dict[kIOPMAssertPreventUserIdleDisplaySleep as String] ?? 0
        return count > 0
    }

    private func isMicrophoneActive() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioDeviceUnknown else { return false }

        var isRunning: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &isRunning) == noErr else { return false }
        return isRunning != 0
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
