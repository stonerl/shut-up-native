//
//  LockFile.swift
//  shutup
//
//  Created by Ricky Romero on 5/16/20.
//  See LICENSE.md for license information.
//

import Foundation

final class LockFile {
    private var url: URL
    private var claimedDate: Date?
    let expiry = 120 // seconds

    init(url: URL) {
        self.url = url
    }

    func attempt() -> Bool {
        let claimed = FileManager.default.createFile(
            atPath: url.path,
            contents: Data(),
            attributes: [.immutable: 1]
        )
        if claimed {
            claimedDate = lockDate
        }
        return claimed
    }

    func unlock() {
        guard claimedByUs else { return }
        smash()
    }

    func smash() { // Forcefully remove the lock
        claimedDate = nil
        try? FileManager.default.setAttributes([.immutable: 0], ofItemAtPath: url.path)
        try? FileManager.default.removeItem(at: url)
    }

    var lockDate: Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.creationDate] as? Date
    }

    private var claimedByUs: Bool {
        lockDate == claimedDate && lockDate != nil
    }

    private var timerActive = false
    private var lockExpired: Bool {
        let negativeExpiry = Double(expiry) * -1
        let age = lockDate?.timeIntervalSinceNow
        guard age != nil else { return false }
        return age! < negativeExpiry
    }

    func claim() {
        guard !timerActive else { return }
        timerActive = true

        // Polls on the calling thread; blocks until the lock is claimed or expires.
        while true {
            let lockClaimed = attempt()
            if lockClaimed {
                break
            } else {
                if lockExpired {
                    smash()
                }

                usleep(1000 * 1000 / 2)
            }
        }

        // The guard above only prevents nested/reentrant claims. Clear the
        // flag so independent claims later in the process life can proceed.
        timerActive = false
    }
}
