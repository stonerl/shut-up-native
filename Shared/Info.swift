//
//  Info.swift
//  shutup
//
//  Created by Ricky Romero on 10/6/19.
//  See LICENSE.md for license information.
//

import Foundation

enum Info {
    /// Bundle ID of the containing app. Injected per-target via the
    /// CONTAINING_APP_BUNDLE_ID build setting – the extensions and Debug
    /// Tools can't derive it at runtime.
    static let containingBundleId = readBundleKey("ShutUpContainingBundleId")
    static let helperBundleId = "\(containingBundleId).helper"
    static let blockerBundleId = "\(containingBundleId).blocker"

    static let productName = readBundleKey(kCFBundleNameKey)
    static let version = readBundleKey("CFBundleShortVersionString")
    static let buildNum = Int(readBundleKey(kCFBundleVersionKey))!

    static let bundleId = Bundle.main.bundleIdentifier!
    static let teamId = readBundleKey("TeamIdentifierPrefix")

    /// App group / preferences suite identifier. macOS uses the
    /// TeamIdentifierPrefix convention; iOS requires the "group." prefix.
    static let groupId: String = {
        #if os(macOS)
            return "\(teamId)\(containingBundleId)"
        #else
            return "group.\(containingBundleId)"
        #endif
    }()

    /// Keychain access group. Must match the keychain-access-groups
    /// entitlement (team-prefixed) on every platform.
    static let keychainGroupId = "\(teamId)\(containingBundleId)"

    static let isApp = bundleId == containingBundleId

    static let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Info.groupId)!
    static let whitelistUrl = containerUrl.appendingPathComponent("domain-whitelist.json.enc")
    static let localCssUrl = containerUrl.appendingPathComponent("shutup.css.enc")

    private static func readBundleKey(_ key: CFString) -> String {
        guard let value = Bundle.main.infoDictionary?[key as String] as? String else {
            preconditionFailure("Expected key \(key) in Info.plist is missing or not a string")
        }
        return value
    }

    private static func readBundleKey(_ key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            preconditionFailure("Expected key \(key) in Info.plist is missing or not a string")
        }
        return value
    }
}
