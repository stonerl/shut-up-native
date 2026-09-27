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
                        // Launch-time check, mac parity; callback is
                        // guaranteed even on early bails.
                        Stylesheet.main.update { _ in
                            AppStateModel.shared.refresh()
                        }
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
