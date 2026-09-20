//
//  Stylesheet.swift
//  shutup
//
//  Created by Ricky Romero on 5/22/20.
//  See LICENSE.md for license information.
//

import Foundation
import OSLog
import SafariServices

private let logger = Logger(subsystem: Info.containingBundleId, category: "Stylesheet")

struct Rule {
    let source: String

    var selectors: [String] {
        let selectorList = source
            .split(separator: "{")[0]
            .components(separatedBy: ", ")

        return selectorList.map { $0.trim() }
    }

    var type: RuleType {
        let declarationString = source.split(separator: "{")[1]

        if declarationString.lowercased().contains("none") {
            return .blocking
        } else {
            return .undoing
        }
    }
}

enum RuleType {
    case blocking
    case undoing
}

class Stylesheet {
    static var main = Stylesheet()
    private init() {}

    private var waitingForResponse = false
    private var currentRefreshMethod: String?
    private var completionHandler: ((Error?) -> Void)?

    private let file = EncryptedFile(
        fsLocation: Info.localCssUrl,
        bundleOrigin: Bundle.main.url(forResource: "shutup", withExtension: "css")!
    )

    private var updateIsDue: Bool {
        let twoDays: Double = 60 * 60 * 24 * 2
        let deadline = Preferences.main.lastStylesheetUpdate.addingTimeInterval(twoDays)

        return deadline.timeIntervalSinceNow < 0.0
    }

    var rules: [Rule] {
        guard let data = file.read() else { return [] }
        guard let cssString = String(data: data, encoding: .utf8) else { return [] }

        var ruleStrings = minify(css: cssString).split(separator: "}")
        ruleStrings = ruleStrings.filter { $0.trim().count > 0 }

        return ruleStrings.map { Rule(source: String($0)) }
    }

    func update(force: Bool = false, completionHandler: ((Error?) -> Void)?) {
        // Callers that pass a completion handler expect exactly one
        // callback per update() call – even when we bail out early. The
        // BG task scheduler, among others, relies on this.
        let bailOut: (Error?) -> Void = { error in
            guard let completionHandler else { return }
            DispatchQueue.main.async { completionHandler(error) }
        }

        guard waitingForResponse == false else {
            bailOut(nil)
            return
        }
        guard updateIsDue || force else {
            bailOut(nil)
            return
        }

        waitingForResponse = true
        currentRefreshMethod = force ? "manual" : "automatic"

        self.completionHandler = completionHandler
        let stylesheetUrl = URL(string: "https://rickyromero.com/shutup/updates/shutup.css")!

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.httpAdditionalHeaders = [
            "User-Agent": "\(Info.productName)/\(Info.version) (\(Info.buildNum))"
        ]
        if !force, Preferences.main.etag != "" {
            sessionConfig.httpAdditionalHeaders?["If-None-Match"] = Preferences.main.etag
        }
        sessionConfig.timeoutIntervalForRequest = 10 // seconds

        let session = URLSession(configuration: sessionConfig)
        let sessionTask = session.dataTask(with: stylesheetUrl, completionHandler: handleServerResponse(data:response:error:))

        sessionTask.resume()
    }

    func handleServerResponse(data: Data?, response: URLResponse?, error: Error?) {
        var outputError: Error?
        defer {
            waitingForResponse = false
            currentRefreshMethod = nil
            DispatchQueue.main.async {
                self.completionHandler?(outputError)
                self.completionHandler = nil
            }
        }

        guard error == nil else {
            logger.error("Encountered an error when updating the stylesheet: \(String(describing: error))")
            outputError = error
            return
        }

        guard let data else {
            logger.error("No data received from request.")
            return
        }

        guard let response = response as? HTTPURLResponse else {
            logger.error("No response received from request.")
            return
        }

        let contentBlockerGroup = DispatchGroup()
        if data.count > 0, response.statusCode == 200 {
            guard validateCss(css: data) else {
                outputError = MiscError.unexpectedNetworkResponse
                return
            }

            do {
                try file.write(data: data)

                contentBlockerGroup.enter()
                SFContentBlockerManager.reloadContentBlocker(withIdentifier: Info.blockerBundleId) { error in
                    if error != nil {
                        outputError = BrowserError.providingBlockRules
                    }
                    contentBlockerGroup.leave()
                }
            } catch {
                if error is CryptoError {
                    outputError = error
                } else {
                    outputError = FileError.writingFile
                }
                return
            }
        } else if data.count == 0, response.statusCode == 304 {
            // Stylesheet is unmodified; continue
        } else {
            outputError = MiscError.unexpectedNetworkResponse
            return
        }

        Preferences.main.lastStylesheetUpdate = Date()
        Preferences.main.lastUpdateMethod = currentRefreshMethod ?? "automatic"
        let headers = response.allHeaderFields
        if let etag = headers["Etag"] as? String {
            Preferences.main.etag = etag
        }

        contentBlockerGroup.wait()
    }

    private func validateCss(css: Data) -> Bool {
        guard css.count < 2 * 1024 * 1024 else { return false }
        guard var cssString = String(data: css, encoding: .utf8) else { return false }

        cssString = minify(css: cssString)

        // Verify a matching number of opening and closing braces
        let openBraceCount = cssString.split(separator: "{").count - 1
        let closeBraceCount = cssString.split(separator: "}").count - 1
        guard openBraceCount == closeBraceCount else { return false }

        var allPairsValid = true
        var displayNoneFound = false
        for selectorRulePair in cssString.split(separator: "}") {
            // Special case for ending bracket
            guard selectorRulePair.trim().count > 0 else { continue }

            let selectorRulePair = selectorRulePair.split(separator: "{")
            let selectorSet = selectorRulePair[0].trim()
            let ruleSet = selectorRulePair[1].trim()

            // Check for a list of (fairly short) selectors
            for selector in selectorSet.components(separatedBy: ", ") {
                allPairsValid = allPairsValid && selector.trim().count < 150
            }

            guard let displayPropRegex = try? NSRegularExpression(
                pattern: "display:\\s*[a-z\\- ]+\\s+!important;?",
                options: .caseInsensitive
            ) else {
                return false
            }
            allPairsValid = allPairsValid && displayPropRegex.test(ruleSet)

            guard let displayNoneRegex = try? NSRegularExpression(
                pattern: "display:\\s*none\\s+!important;?",
                options: .caseInsensitive
            ) else {
                return false
            }
            displayNoneFound = displayNoneFound || displayNoneRegex.test(ruleSet)
        }

        return allPairsValid && displayNoneFound
    }

    private func minify(css: String) -> String {
        let cleanupPatterns = [
            // swiftformat:disable consecutiveSpaces; swiftlint:disable comma
            ["\\s*/\\*.+?\\*/\\s*", " "],   // Comments
            ["^\\s+",               ""],    // Leading whitespace
            [",\\s+",               ", "]   // Selector whitespace
            // swiftformat:enable consecutiveSpaces; swiftlint:enable comma
        ]

        var strippedCSS = css
        for replacementPair in cleanupPatterns {
            let cleanupPattern = replacementPair[0]
            let replacementTemplate = replacementPair[1]
            guard let cleanupRegex = try? NSRegularExpression(pattern: cleanupPattern, options: .dotMatchesLineSeparators) else {
                continue
            }
            strippedCSS = cleanupRegex.stringByReplacingMatches(
                in: strippedCSS,
                options: [],
                range: NSRange(location: 0, length: strippedCSS.count),
                withTemplate: replacementTemplate
            )
        }

        return strippedCSS
    }

    func reset() {
        file.reset()
    }
}

// MARK: - Update-status descriptions + reload helper

extension Stylesheet {
    struct UpdateDescription {
        let summary: String
        let tooltip: String
    }

    /// True within the cooldown window after an update finishes.
    static func updateIsRecent(_ timestamp: Date) -> Bool {
        timestamp.timeIntervalSinceNow > -15
    }

    /// Human-readable "last updated" strings, shared by both UIs.
    static func describe(update timestamp: Date, method: String) -> UpdateDescription {
        let cutoffDate = Date(timeIntervalSinceNow: -(60 * 60 * 24 * 7))
        let relativeFormatter = RelativeDateTimeFormatter()
        let absoluteFormatter = DateFormatter()

        relativeFormatter.unitsStyle = .full
        absoluteFormatter.dateStyle = .medium
        absoluteFormatter.timeStyle = .medium

        let summary: String
        if timestamp == Date(timeIntervalSince1970: 0) {
            summary = String(localized: "--",
                             comment: "String for the 'Last CSS update' label")
        } else if updateIsRecent(timestamp) {
            summary = String(localized: "Updated just now",
                             comment: "String for the 'Last CSS update' label")
        } else if timestamp < cutoffDate {
            summary = String(localized: "Updated over 1 week ago",
                             comment: "String for the 'Last CSS update' label")
        } else {
            let relativeStr = relativeFormatter.localizedString(for: timestamp, relativeTo: Date())
            summary = String(localized: "Updated \(relativeStr)",
                             comment: "String for the 'Last CSS update' label, argument is the relative time")
        }

        let tooltip: String
        if timestamp == Date(timeIntervalSince1970: 0) {
            tooltip = String(localized: "Stylesheet hasn’t been updated.",
                             comment: "Tooltip for the 'Last CSS update' label")
        } else {
            let updatedHow = method == "automatic"
                ? String(localized: "Automatically", comment: "First argument for the 'Last CSS update' label")
                : String(localized: "Manually", comment: "First argument for the 'Last CSS update' label")
            let absoluteStr = absoluteFormatter.string(from: timestamp)
            tooltip = String(localized: "\(updatedHow) updated on \(absoluteStr).",
                             comment: "Tooltip for the 'Last CSS update' label, first argument is 'Automatically' or 'Manually")
        }

        return UpdateDescription(summary: summary, tooltip: tooltip)
    }
}

extension SFContentBlockerManager {
    /// Reloads Shut Up's content blocker on any platform, surfacing
    /// failures through the shared error pipeline.
    static func reloadShutUpBlocker() {
        reloadContentBlocker(withIdentifier: Info.blockerBundleId) { error in
            guard let error else { return }
            logger.error("Content blocker reload error: \(String(describing: error))")
            showError(BrowserError.providingBlockRules)
        }
    }
}

// MARK: String/regex convenience extensions

private extension String {
    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Substring {
    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension NSRegularExpression {
    func test(_ string: String) -> Bool {
        firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.count)) != nil
    }
}
