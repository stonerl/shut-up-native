//
//  ShutUpApp.swift
//  Shut Up iOS
//
//  See LICENSE.md for license information.
//

import SwiftUI

@main
struct ShutUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var errorBox = ErrorBox.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    Setup.main.bootstrap {
                        // Match the mac app's launch behavior: check for a
                        // stylesheet update when the app comes to the
                        // foreground (2-day staleness deadline applies).
                        Stylesheet.main.update(completionHandler: nil)
                    }
                    AppStateModel.shared.refresh()
                }
                .environmentObject(errorBox)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // BGTaskScheduler handlers must be registered before the app
        // finishes launching.
        BackgroundRefresh.register()
        BackgroundRefresh.schedule()

        return true
    }
}
