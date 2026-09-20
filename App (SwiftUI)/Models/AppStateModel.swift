//
//  AppStateModel.swift
//  Shut Up iOS
//
//  Platform-neutral observable state for the SwiftUI app.
//  See LICENSE.md for license information.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppStateModel {
    static let shared = AppStateModel()

    private init() {}

    var stylesheetLastUpdate = Date(timeIntervalSince1970: 0)
    var lastUpdateMethod = "automatic"

    var isUpdatingStylesheet = false

    func refresh() {
        let prefs = Preferences.main
        stylesheetLastUpdate = prefs.lastStylesheetUpdate
        lastUpdateMethod = prefs.lastUpdateMethod
    }

    func updateStylesheetNow() {
        guard !isUpdatingStylesheet else { return }
        isUpdatingStylesheet = true

        Stylesheet.main.update(force: true) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isUpdatingStylesheet = false
                self.stylesheetLastUpdate = Preferences.main.lastStylesheetUpdate
                self.lastUpdateMethod = Preferences.main.lastUpdateMethod

                if let error {
                    showError(error)
                }
            }
        }
    }
}
