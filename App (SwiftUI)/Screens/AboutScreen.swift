//
//  AboutScreen.swift
//  Shut Up iOS
//
//  See LICENSE.md for license information.
//

import SafariServices
import SwiftUI

struct AboutScreen: View {
    private let homepageUrl = URL(string: "https://rickyromero.com/shutup/")!
    @State private var appState = AppStateModel.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Shut Up")
                                .font(.headline)
                            Text("Version \(Info.version) (\(Info.buildNum))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Blocks comment sections on webpages using shutup.css by Steven Frank and contributors, used with permission.")
                }

                Section {
                    if #available(iOS 26.2, *) {
                        Button {
                            SFSafariSettings.openExtensionsSettings(forIdentifiers: [Info.blockerBundleId]) { error in
                                if error != nil {
                                    showError(BrowserError.showingSafariPreferences)
                                }
                            }
                        } label: {
                            Label(String(localized: "Open Safari’s Extension Settings"), systemImage: "gear")
                        }
                    } else {
                        Text("Enable “Shut Up” in Settings → Apps → Safari → Extensions.")
                    }
                } header: {
                    Text("Set up in Safari")
                }

                Section {
                    stylesheetRow
                } header: {
                    Text("Stylesheet")
                }

                Section {
                    Link(destination: homepageUrl) {
                        Label(String(localized: "Shut Up Homepage"), systemImage: "safari")
                    }
                    Link(destination: URL(string: "mailto:feedback@rickyromero.com")!) {
                        Label(String(localized: "Contact Support"), systemImage: "envelope")
                    }
                }
            }
            .navigationTitle(String(localized: "About"))
            .onAppear {
                appState.refresh()
            }
        }
    }

    private var stylesheetRow: some View {
        HStack {
            let description = Stylesheet.describe(
                update: appState.stylesheetLastUpdate,
                method: appState.lastUpdateMethod
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(description.summary)
                Text(description.tooltip)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if appState.isUpdatingStylesheet {
                ProgressView()
            } else {
                Button(String(localized: "Update")) {
                    appState.updateStylesheetNow()
                }
                .disabled(isRecentUpdate)
            }
        }
    }

    private var isRecentUpdate: Bool {
        Stylesheet.updateIsRecent(appState.stylesheetLastUpdate)
    }
}

#Preview {
    AboutScreen()
}
