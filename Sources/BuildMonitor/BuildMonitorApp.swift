import SwiftUI

@main
struct BuildMonitorApp: App {
    init() {
        // BackgroundTasks identifiers must be registered before any submit() call.
        BuildNotificationManager.registerDefaults()
        BackgroundRefreshScheduler.register()
        BuildNotificationDelegate.install()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView().preferredColorScheme(.light)
        }
    }
}
