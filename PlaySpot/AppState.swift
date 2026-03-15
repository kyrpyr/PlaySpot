import Foundation
import Combine

enum InterceptionStatus {
    case active
    case inactive
    case noPermission
}

final class AppState: ObservableObject {
    @Published var showInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar") }
    }

    @Published var hasAccessibilityPermission: Bool = true

    @Published private(set) var status: InterceptionStatus = .inactive

    var interceptionEnabled: Bool {
        get { _interceptionEnabled }
        set {
            objectWillChange.send()  // required: plain var doesn't trigger @Published
            guard newValue else {
                _interceptionEnabled = false
                status = .inactive
                UserDefaults.standard.set(false, forKey: "interceptionEnabled")
                return
            }
            guard hasAccessibilityPermission else {
                status = .noPermission
                return
            }
            _interceptionEnabled = true
            status = .active
            UserDefaults.standard.set(true, forKey: "interceptionEnabled")
        }
    }

    private var _interceptionEnabled: Bool = false

    init() {
        showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")
        // Note: `interceptionEnabled` is intentionally NOT restored here.
        // AppDelegate restores it after checking AXIsProcessTrusted() at launch.
    }
}
