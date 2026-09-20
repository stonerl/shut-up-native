//
//  ErrorBox.swift
//  Shut Up iOS
//
//  Sink for showError() calls coming from Shared code, surfaced as an
//  alert by the SwiftUI app. See LICENSE.md for license information.
//

import Foundation

@MainActor
final class ErrorBox: ObservableObject {
    static let shared = ErrorBox()

    private init() {}

    @Published var current: Error?
}

func showError(_ error: Error) {
    DispatchQueue.main.async {
        ErrorBox.shared.current = (error is MessagingError) ? error : MessagingError(error)
    }
}
