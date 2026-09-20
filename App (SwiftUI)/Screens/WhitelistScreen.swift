//
//  WhitelistScreen.swift
//  Shut Up iOS
//
//  See LICENSE.md for license information.
//

import SwiftUI

struct WhitelistScreen: View {
    @State private var model = WhitelistModel.shared
    @State private var appState = AppStateModel.shared
    @State private var newDomain = ""
    @State private var invalidEntry = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField(
                            String(localized: "example.com"),
                            text: $newDomain
                        )
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit(addDomain)

                        Button {
                            addDomain()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .accessibilityLabel(String(localized: "Add"))
                        }
                        .buttonStyle(.borderless)
                        .disabled(newDomain.isEmpty)
                    }
                }

                Section {
                    ForEach(model.entries, id: \.self) { domain in
                        Text(domain)
                    }
                    .onDelete { offsets in
                        model.remove(atOffsets: offsets)
                    }
                } footer: {
                    Text("Comments are hidden except on these websites.")
                }
            }
            .navigationTitle(String(localized: "Allowlist"))
            .onAppear {
                model.reload()
            }
            .alert(
                String(localized: "Invalid domain"),
                isPresented: $invalidEntry
            ) {
                Button(String(localized: "OK", comment: "Default button text – error recovery")) {}
            } message: {
                Text("Enter a valid domain, like “example.com”.")
            }
        }
    }

    private func addDomain() {
        let text = newDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if model.add(text) == .invalid {
            invalidEntry = true
        } else {
            newDomain = ""
        }
    }
}

#Preview {
    WhitelistScreen()
}
