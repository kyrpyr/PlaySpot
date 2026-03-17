import SwiftUI

struct ContentView: View {
    private static let githubURL = URL(string: "https://github.com/kyrpyr/PlaySpot")!

    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 20) {
            Button {
                state.toggleInterception()
            } label: {
                Image("PowerIcon")
                    .resizable()
                    .frame(width: 200, height: 200)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundStyle(state.status == .active ? Color(red: 0.11, green: 0.73, blue: 0.33) : .gray)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Show in Menu Bar", isOn: $state.showInMenuBar)
                    .toggleStyle(.checkbox)
                    .focusable(false)

                Toggle("Launch at Login", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.launchAtLogin = $0 }
                ))
                    .toggleStyle(.checkbox)
                    .focusable(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))

                Spacer()

                Link("Source Code on GitHub ↗", destination: Self.githubURL)
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))
                    .focusable(false)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
            }
        }
        .padding(30)
        .frame(width: 300)
    }


}
