//
//  AppDelegate.swift
//  shutup
//
//  Created by Ricky Romero on 9/2/19.
//  See LICENSE.md for license information.
//

import Cocoa
import CoreGraphics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var mwc: MainWindowController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let optionKeyState = CGEventSource.keyState(.combinedSessionState, key: 0x3A)
        let mainSb = NSStoryboard(name: "Main", bundle: nil)
        self.mwc = mainSb.instantiateController(withIdentifier: "MainWC") as? MainWindowController

        // Show the main window immediately
        self.mwc.window?.makeKeyAndOrderFront(self)

        // Then bootstrap the application
        Setup.main.bootstrap(optionKeyState) {
            Stylesheet.main.update(completionHandler: nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @IBAction func didChooseLinkItem(_ sender: NSMenuItem) {
        Links.collection.open(by: sender)
    }

    @IBAction func didChooseContactMenuItem(_ sender: NSMenuItem) {
        Links.composeEmail()
    }

    @IBAction func didChooseUpdateStylesheet(_ sender: NSMenuItem) {
        guard let mainVC = mwc.window?.contentViewController as? MainViewController else {
            print("MainViewController not found")
            return
        }

        mainVC.updateStylesheetButton.performClick(nil)
    }
}

// MARK: ErrorRecoveryDelegate

extension AppDelegate: ErrorRecoveryDelegate {
    func attemptRecovery(from error: Error, with option: RecoveryOption) -> Bool {
        switch option {
            case .ok:
                break
            case .quit:
                _ = NSApp.mainWindow?.sheets.map { $0.close() }
                NSApp.terminate(nil)
            case .tryAgain:
                Setup.main.restart()
            case .reset:
                Setup.main.confirmReset()
        }

        return true
    }

    func application(_ application: NSApplication, willPresentError error: Error) -> Error {
        return DelegatingRecoverableError(recoveringFrom: error, with: self)
    }
}

func showError(_ error: Error) {
    DispatchQueue.main.async {
        let errorToPresent = (error is MessagingError) ? error : MessagingError(error)

        guard let mainWindow = NSApp.mainWindow else {
            // Retry after a short delay if mainWindow is not yet available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showError(errorToPresent)
            }
            return
        }

        NSApp.presentError(errorToPresent,
                           modalFor: mainWindow,
                           delegate: nil,
                           didPresent: nil,
                           contextInfo: nil)
    }
}

// MARK: NSMenuItemValidation

/// Validates the "Update Stylesheet" menu item (identifier "menu_update_stylesheet").
/// It is enabled only when MainViewController's updateStylesheetButton is enabled,
/// preventing rapid consecutive updates. All other menu items are enabled.
extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.identifier?.rawValue == "menu_update_stylesheet",
           let mainVC = mwc?.window?.contentViewController as? MainViewController
        {
            return mainVC.updateStylesheetButton.isEnabled
        }
        return true
    }
}
