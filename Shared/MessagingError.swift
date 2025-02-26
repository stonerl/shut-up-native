//
//  MessagingError.swift
//  shutup
//
//  Created by Ricky Romero on 5/21/20.
//  See LICENSE.md for license information.
//

import Foundation

enum UnknownError: Error {
    case unknown
}

enum LockError: Error {
    case timedOut
}

enum CryptoError: Error {
    case accessingKeychain
    case removingInvalidKeys
    case generatingKeys
    case fetchingKeys
    case transformingData
}

enum FileError: Error {
    case checkingFreeSpace
    case readingFile
    case writingFile
}

enum BrowserError: Error {
    case providingBlockRules
    case showingSafariPreferences
    case requestingExtensionStatus
}

enum MiscError: Error {
    case unexpectedNetworkResponse
}

enum RecoveryOption: String, CaseIterable, CustomStringConvertible {
    case ok
    case quit
    case reset
    case tryAgain

    var description: String {
        var buttonText: String!
        switch self {
            case .ok: buttonText = "OK"
            case .quit: buttonText = "Quit"
            case .reset: buttonText = "Reset Shut Up"
            case .tryAgain: buttonText = "Try Again…"
        }

        return NSLocalizedString(buttonText, comment: rawValue)
    }
}

struct MessageContents {
    let title: String?
    let info: String?
    let options: [RecoveryOption]?
}

class MessagingError: NSError, @unchecked Sendable {
    let cause: Error

    init(_ cause: Error) {
        self.cause = cause
        super.init(domain: Info.bundleId, code: -1, userInfo: [:])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func genAlertContents(_ contents: MessageContents) -> [String: Any] {
        var userInfo: [String: Any] = [:]

        if let title = contents.title, let info = contents.info {
            userInfo[NSLocalizedDescriptionKey] =
                NSLocalizedString(title, comment: "localizedErrorDescription")
            userInfo[NSLocalizedRecoverySuggestionErrorKey] =
                NSLocalizedString(info, comment: "localizedErrorRecoverSuggestion")
        }

        if let options = contents.options {
            userInfo[NSLocalizedRecoveryOptionsErrorKey] = options
        }

        return userInfo
    }

    override var userInfo: [String: Any] {
        var title: String?
        var info: String?
        var options: [RecoveryOption]?

        if cause is CryptoError {
            switch cause as! CryptoError {
                case .accessingKeychain:
                    title = "Keychain locked or unavailable"
                    info = "Shut Up requires keychain privileges to secure its data. Unlock your keychain to proceed."
                    options = [.quit, .tryAgain]
                case .removingInvalidKeys:
                    title = "Failed to remove invalid keys"
                    info = "If the issue persists, try restarting your Mac."
                case .generatingKeys:
                    title = "Failed to generate a required key"
                    info = "If the issue persists, try restarting your Mac."
                case .fetchingKeys:
                    title = "Encryption keys missing or damaged"
                    info = "Shut Up failed to decrypt some required data. You can fix this by resetting Shut Up, but your allowlist may be lost."
                    options = [.quit, .reset]
                case .transformingData:
                    title = "Stylesheet or allowlist damaged"
                    info = "Shut Up failed to decrypt some required data. You can fix this by resetting Shut Up, but your allowlist may be lost."
                    options = [.quit, .reset]
            }
        } else if cause is LockError {
            switch cause as! LockError {
                case .timedOut:
                    title = "Internal error occurred"
                    info = "Shut Up encountered a problem and cannot recover. Please quit and restart Shut Up."
                    options = [.quit]
            }
        } else if cause is FileError {
            switch cause as! FileError {
                case .checkingFreeSpace:
                    title = "Startup disk is too full to continue"
                    info = "Quit Shut Up and delete any files you don’t need."
                    options = [.quit]
                case .readingFile:
                    title = "Failed to read an internal file"
                    info = "Shut Up failed to read from an internal file. If this issue persists, please quit and restart Shut Up."
                case .writingFile:
                    title = "Failed to write an internal file"
                    info = "Shut Up failed to write to an internal file. If this issue persists, please quit and restart Shut Up."
            }
        } else if cause is BrowserError {
            switch cause as! BrowserError {
                case .providingBlockRules:
                    title = "Safari failed to read Shut Up’s content-blocking rules"
                    info = "Shut Up sent Safari new content-blocking rules, but it failed. Try restarting Safari. If the issue persists, try restarting your Mac."
                case .showingSafariPreferences:
                    title = "Safari failed to open its settings"
                    info = "Shut Up asked Safari to open its settings window, but it failed. Try opening Safari’s settings manually, then go to the “Extensions” section."
                case .requestingExtensionStatus:
                    title = "Safari failed to provide extension info"
                    info = "Shut Up asked Safari if its extensions are enabled, but it failed. Try quitting Shut Up and moving it to your Applications folder.\n\nIf the issue persists, try uninstalling Shut Up, restarting your Mac, and reinstalling Shut Up."
            }
        } else if cause is MiscError {
            switch cause as! MiscError {
                case .unexpectedNetworkResponse:
                    title = "Unexpected response from rickyromero.com"
                    info = "Shut Up tried to update the stylesheet, but the response the server sent was invalid. Try again later."
            }
        } else if cause is URLError {
            title = "Cannot connect to rickyromero.com"
            info = cause.localizedDescription
        }

        return genAlertContents(MessageContents(title: title, info: info, options: options?.reversed()))
    }
}
