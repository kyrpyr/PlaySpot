import CoreGraphics
import AppKit

final class MediaKeyInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onPlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?

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
        guard AXIsProcessTrusted() else { return false }

        let systemDefinedRawValue: UInt32 = 14  // CGEventType.systemDefined raw value
        let mask = CGEventMask(1 << systemDefinedRawValue)

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

        let systemDefinedType = CGEventType(rawValue: 14)!
        guard type == systemDefinedType,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passRetained(event)
        }

        let data1 = Int(nsEvent.data1)
        guard Self.isKeyDown(data1: data1) else {
            return nil  // consume key-up silently
        }

        let code = Self.keyCode(from: data1)
        switch code {
        case 16:
            DispatchQueue.main.async { self.onPlayPause?() }
            return nil  // consume
        case 17:
            DispatchQueue.main.async { self.onNext?() }
            return nil
        case 18:
            DispatchQueue.main.async { self.onPrevious?() }
            return nil
        default:
            return Unmanaged.passRetained(event)
        }
    }
}
