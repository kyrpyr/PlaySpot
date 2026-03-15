import SwiftUI

@main
struct PlaySpotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(delegate.appState)
        }
        .windowResizability(.contentSize)
    }
}
