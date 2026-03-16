import CoreGraphics
import AppKit

enum MediaKey { case playPause, next, previous }

final class MediaKeyInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onKey: ((MediaKey) -> Void)?

    // CGEventType.systemDefined raw value (stable since macOS 10.4; newer SDKs removed the named case)
    private static let systemDefinedEventType = CGEventType(rawValue: 14)!

    // MARK: - Static helpers (testable without system APIs)

    static func isKeyDown(data1: Int) -> Bool {
        // keyFlags upper byte: 0x0A = key-down, 0x0B = key-up
        return (data1 & 0xFF00) >> 8 == 0x0A
    }

    static func keyCode(from data1: Int) -> Int {
        return (data1 & 0xFFFF0000) >> 16
    }

    // MARK: - Enable / Disable

    func enable() -> Bool {
        guard eventTap == nil else { return true }  // already enabled — avoid leaking run loop source
        guard AXIsProcessTrusted() else { return false }

        let mask = CGEventMask(1 << Self.systemDefinedEventType.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return interceptor.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    func disable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Event handling

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap invalidation: macOS auto-disables the tap on timeout.
        // Simply re-enable it. If the tap is permanently broken, AppDelegate's
        // syncInterceptor() will detect failure via enable()'s return value and snap back the UI.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }

        guard type == Self.systemDefinedEventType,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(event)
        }

        let data1 = Int(nsEvent.data1)
        guard Self.isKeyDown(data1: data1) else {
            return nil  // consume key-up silently
        }

        let key: MediaKey
        switch Self.keyCode(from: data1) {
        case 16: key = .playPause
        case 17: key = .next
        case 18: key = .previous
        default: return Unmanaged.passRetained(event)
        }
        DispatchQueue.main.async { self.onKey?(key) }
        return nil
    }
}
