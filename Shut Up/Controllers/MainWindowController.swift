//
//  MainWindowController.swift
//  Shut Up
//
//  Created by Ricky Romero on 10/20/19.
//  See LICENSE.md for license information.
//

import Cocoa

class MainWindowController: NSWindowController {
    @IBOutlet var mainWindow: NSWindow!

    override func windowDidLoad() {
        super.windowDidLoad()

        shouldCascadeWindows = false
        windowFrameAutosaveName = "MainWindow"

        mainWindow.isMovableByWindowBackground = true
        mainWindow.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

// MARK: NSWindowDelegate

extension MainWindowController: NSWindowDelegate {
    /// Callback for when a sheet is being presented on the main window
    func window(_ window: NSWindow, willPositionSheet _: NSWindow, using rect: NSRect) -> NSRect {
        // Offset input rectangle so it sits on the top of the window
        rect.offsetBy(dx: 0.0, dy: window.frame.height - rect.origin.y)
    }
}
