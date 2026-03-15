import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showPermissionAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Text(statusText)
                .font(.headline)
                .foregroundColor(statusColor)

            Button(toggleLabel) {
                handleToggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(state.status == .active ? .green : .gray)

            Toggle("Show in Menu Bar", isOn: $state.showInMenuBar)
                .toggleStyle(.checkbox)
        }
        .padding(30)
        .frame(width: 280)
        .alert("Accessibility Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("PlaySpot needs Accessibility permission to intercept media keys.")
        }
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

    private var toggleLabel: String {
        state.status == .active ? "Disable interception" : "Enable interception"
    }

    private func handleToggle() {
        if state.status == .active {
            state.interceptionEnabled = false
        } else {
            guard state.hasAccessibilityPermission else {
                showPermissionAlert = true
                return
            }
            state.interceptionEnabled = true
        }
    }
}
