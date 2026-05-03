import SwiftUI
import UIKit
import UserNotifications

@main
struct DayflowApp: App {
    @UIApplicationDelegateAdaptor(DayflowAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            DayflowHomeView()
        }
    }
}

final class DayflowAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}
