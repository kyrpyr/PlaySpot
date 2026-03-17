import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 20) {
            Button {
                handleToggle()
            } label: {
                Image("PowerIcon")
                    .resizable()
                    .frame(width: 200, height: 200)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundStyle(state.status == .active ? Color(red: 0.11, green: 0.73, blue: 0.33) : .gray)

            Toggle("Show in Menu Bar", isOn: $state.showInMenuBar)
                .toggleStyle(.checkbox)
                .focusable(false)

            Toggle("Launch at Login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.launchAtLogin = $0 }
            ))
            .toggleStyle(.checkbox)
            .focusable(false)

            Link("Source Code on GitHub ↗", destination: URL(string: "https://github.com/kyrpyr/PlaySpot")!)
                .foregroundStyle(.tertiary)
                .font(.system(size: 11))
                .focusable(false)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
        }
        .padding(30)
        .frame(width: 300)
    }

    private func handleToggle() {
        if state.status == .active {
            state.interceptionEnabled = false
        } else {
            // AXIsProcessTrustedWithOptions opens System Settings focused on the exact running
            // binary when not trusted — no manual navigation or wrong-entry risk.
            let trusted = AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            )
            state.hasAccessibilityPermission = trusted
            if trusted {
                state.interceptionEnabled = true
            }
            // If not trusted: System Settings just opened — user adds the app, then clicks Enable again.
        }
    }
}
