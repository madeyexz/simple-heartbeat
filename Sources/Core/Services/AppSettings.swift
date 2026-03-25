import Foundation

/// Persisted app preferences.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @Published public var showMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon") }
    }
    @Published public var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    @Published public var closePopoverOnOutsideClick: Bool {
        didSet { UserDefaults.standard.set(closePopoverOnOutsideClick, forKey: "closePopoverOnOutsideClick") }
    }

    public init() {
        let defaults = UserDefaults.standard
        // Register defaults
        defaults.register(defaults: [
            "showMenuBarIcon": true,
            "launchAtLogin": false,
            "closePopoverOnOutsideClick": true,
        ])
        self.showMenuBarIcon = defaults.bool(forKey: "showMenuBarIcon")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.closePopoverOnOutsideClick = defaults.bool(forKey: "closePopoverOnOutsideClick")
    }

    public var dataDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("SimpleHeartbeat")
    }
}
