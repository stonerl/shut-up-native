//
//  StylesheetExtension.swift
//  Shut Up
//
//  Created by Ricky Romero on 6/14/20.
//  See LICENSE.md for license information.
//

import Cocoa

extension MainViewController {
    func makeIconStr(for updateMethod: String) -> NSAttributedString {
        let isAutomatic = updateMethod == "automatic"
        let symbol = NSImage(
            systemSymbolName: isAutomatic ? "a.circle.fill" : "m.circle.fill",
            accessibilityDescription: isAutomatic
                ? String(localized: "Automatically",
                         comment: "First argument for the 'Last CSS update' label")
                : String(localized: "Manually",
                         comment: "First argument for the 'Last CSS update' label")
        )

        let attachment = NSTextAttachment()
        attachment.image = symbol

        return NSAttributedString(attachment: attachment)
    }

    func resetCssLabelUpdateTimer() {
        cssLabelUpdateTimer?.invalidate()
        cssLabelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateLastCssUpdateLabel()
            }
        }
    }

    func updateLastCssUpdateLabel() {
        let timestamp = Preferences.main.lastStylesheetUpdate
        updateLastCssUpdateLabel(with: timestamp)
    }

    func updateLastCssUpdateLabel(with timestamp: Date) {
        let method = Preferences.main.lastUpdateMethod
        let description = Stylesheet.describe(update: timestamp, method: method)
        let iconStr = makeIconStr(for: method)
        let isRecentUpdate = Stylesheet.updateIsRecent(timestamp)

        let textStr = NSAttributedString(string: description.summary)

        // Combine SF Symbol icon string with summary
        let labelString = NSMutableAttributedString()
        labelString.append(iconStr)
        labelString.append(NSAttributedString(string: " "))
        labelString.append(textStr)

        lastCssUpdateLabel.attributedStringValue = labelString
        lastCssUpdateLabel.toolTip = description.tooltip

        // Disable the button and menu item during the update and for 15 seconds afterward to prevent rapid consecutive updates.
        let isEnabled = updatingIndicator.isHidden ? !isRecentUpdate : false
        updateStylesheetButton.isEnabled = isEnabled

        if let menuItem = NSApp.mainMenu?.items.first(where: { $0.identifier?.rawValue == "menu_update_stylesheet" }) {
            menuItem.isEnabled = isEnabled
        }
    }

    @IBAction func forceStylesheetUpdate(_ sender: NSButton) {
        sender.isEnabled = false
        lastCssUpdateLabel.isHidden = true
        updatingSpinner.startAnimation(nil)
        updatingIndicator.isHidden = false
        Stylesheet.main.update(force: true) { error in
            sender.isEnabled = true
            self.lastCssUpdateLabel.isHidden = false
            self.updatingIndicator.isHidden = true
            self.updatingSpinner.stopAnimation(nil)

            guard error == nil else {
                showError(error!)
                return
            }

            self.updateLastCssUpdateLabel(with: Preferences.main.lastStylesheetUpdate)
            self.resetCssLabelUpdateTimer()
        }
    }
}
