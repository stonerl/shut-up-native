//
//  RootView.swift
//  Shut Up iOS
//
//  See LICENSE.md for license information.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var errorBox: ErrorBox
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            WhitelistScreen()
                .tabItem {
                    Label(String(localized: "Allowlist"), systemImage: "list.bullet")
                }

            AboutScreen()
                .tabItem {
                    Label(String(localized: "About"), systemImage: "info.circle")
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Cross-process pref changes aren't observable in-process.
            if phase == .active {
                AppStateModel.shared.refresh()
            }
        }
        .alert(
            Text(errorTitle),
            isPresented: Binding(
                get: { errorBox.current != nil },
                set: {
                    if !$0 {
                        DispatchQueue.main.async { errorBox.current = nil }
                    }
                }
            )
        ) {
            Button(String(localized: "OK", comment: "Default button text – error recovery")) {}
        } message: {
            Text(errorDetail)
        }
    }

    private var errorTitle: String {
        (errorBox.current as NSError?)?.userInfo[NSLocalizedDescriptionKey] as? String
            ?? String(localized: "An unknown error occurred.")
    }

    private var errorDetail: String {
        (errorBox.current as NSError?)?.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String ?? ""
    }
}

#Preview {
    RootView()
}
