import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 20) {
            Text(statusText)
                .font(.headline)
                .foregroundStyle(statusColor)

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
        }
        .padding(30)
        .frame(width: 300)
    }

    private var statusText: String {
        switch state.status {
        case .active:      return "Interception active"
        case .inactive:    return "Interception inactive"
        case .noPermission: return "Accessibility permission required"
        }
    }

    private var statusColor: Color {
        state.status == .active ? .green : .secondary
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
