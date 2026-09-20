//
//  WhitelistModel.swift
//  Shut Up iOS
//
//  Platform-neutral observable wrapper around Whitelist.
//  See LICENSE.md for license information.
//

import Foundation
import Observation
import SafariServices

enum DomainAddOutcome {
    case added
    case duplicate
    case invalid
}

@MainActor
@Observable
final class WhitelistModel {
    static let shared = WhitelistModel()

    private init() {}

    var entries: [String] = []

    func reload() {
        Whitelist.main.load()
        entries = Whitelist.main.entries
    }

    /// Parses a single domain or pasted text and adds any new entries,
    /// reloading the content blocker only when something was added.
    func add(_ rawInput: String) -> DomainAddOutcome {
        let domains = Whitelist.parseDomains(fromPasted: rawInput.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !domains.isEmpty else { return .invalid }

        let fresh = domains.filter { Whitelist.firstIndex(of: $0, in: entries) == nil }
        guard !fresh.isEmpty else { return .duplicate }

        let added = Whitelist.main.add(domains: fresh)
        entries = Whitelist.main.entries

        if !added.isEmpty {
            SFContentBlockerManager.reloadShutUpBlocker()
            return .added
        }

        return .duplicate
    }

    func remove(atOffsets offsets: IndexSet) {
        let domains = offsets.map { entries[$0] }
        _ = Whitelist.main.remove(domains: domains)
        entries = Whitelist.main.entries
        SFContentBlockerManager.reloadShutUpBlocker()
    }
}
