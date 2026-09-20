//
//  EncryptedFile.swift
//  shutup
//
//  Created by Ricky Romero on 5/13/20.
//  See LICENSE.md for license information.
//

import Foundation

final class EncryptedFile {
    let fsLocation: URL
    let bundleOrigin: URL

    private var mostRecentlySeenModification: Date?
    var lastModified: Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fsLocation.path)
        return attributes?[.modificationDate] as? Date
    }

    private var cache: Data?
    var externalUpdateOccurred: ((Data) -> Void)?

    var lock: LockFile!

    init(fsLocation: URL, bundleOrigin: URL) {
        self.fsLocation = fsLocation
        self.bundleOrigin = bundleOrigin

        lock = LockFile(url: fsLocation.appendingPathExtension("lock"))
        _ = read()
    }

    func keysVerifiedPresent() -> Bool {
        Crypto.main.requiredKeysPresent
    }

    func read(force: Bool = false) -> Data? {
        if force {
            cache = nil
        }

        if lastModified != mostRecentlySeenModification || cache == nil {
            defer { self.lock.unlock() }
            var modificationOccurred = false

            do {
                let keysPresent = keysVerifiedPresent()
                if keysPresent {
                    lock.claim()

                    var fileData: Data!

                    do {
                        let encryptedData = try Data(contentsOf: fsLocation)
                        fileData = try Crypto.main.transform(with: .decryption, data: encryptedData)
                    } catch {
                        if error is CryptoError {
                            throw error
                        }

                        // Reading failed for some reason. Try to restore from the bundle.
                        // If this fails, that failure will be thrown to the caller.
                        fileData = try Data(contentsOf: bundleOrigin)
                        try write(data: fileData)
                    }

                    modificationOccurred = cache != nil && cache != fileData
                    cache = fileData

                    mostRecentlySeenModification = lastModified
                }
            } catch {
                DispatchQueue.main.async { showError(error) }
            }

            DispatchQueue.main.async {
                if modificationOccurred {
                    self.externalUpdateOccurred?(self.cache!)
                }
            }
        }

        return cache
    }

    func write(data contents: Data) throws {
        guard lastModified == mostRecentlySeenModification else {
            throw FileError.writingFile
        }
        defer { self.lock.unlock() }

        do {
            let keysPresent = keysVerifiedPresent()

            if keysPresent {
                lock.claim()

                let encryptedData = try Crypto.main.transform(with: .encryption, data: contents)
                try encryptedData.write(to: fsLocation, options: .atomic)
                mostRecentlySeenModification = lastModified

                cache = contents
            }
        } catch {
            DispatchQueue.main.async { showError(error) }
        }
    }

    func reset() {
        try? FileManager.default.removeItem(at: fsLocation)
    }
}
