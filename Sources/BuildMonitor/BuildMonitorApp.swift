import SwiftUI
import UIKit
import UserNotifications

@main
struct BuildMonitorApp: App {
    @UIApplicationDelegateAdaptor(BuildMonitorAppDelegate.self) private var appDelegate

    init() {
        BuildNotificationManager.registerDefaults()
        BuildNotificationDelegate.install()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView().preferredColorScheme(.light)
        }
    }
}

final class BuildMonitorAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundRefreshScheduler.register()
        BackgroundRefreshScheduler.schedule()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundRefreshScheduler.schedule()
    }
}
