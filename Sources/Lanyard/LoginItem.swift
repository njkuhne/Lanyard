import Foundation
import ServiceManagement

/// Launch at login via SMAppService (works for the bundled .app, not `swift run`).
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Lanyard: couldn't change launch at login: \(error)")
        }
    }
}
