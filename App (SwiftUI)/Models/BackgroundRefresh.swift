//
//  BackgroundRefresh.swift
//  Shut Up iOS
//
//  Stylesheet auto-update via BGTaskScheduler, ported from the legacy
//  iOS app's StylesheetUpdate.swift. See LICENSE.md for license information.
//

import BackgroundTasks
import Foundation
import OSLog

private let logger = Logger(subsystem: Info.containingBundleId, category: "BackgroundRefresh")

enum BackgroundRefresh {
    static let taskIdentifier = "\(Info.containingBundleId).backgroundRefresh"

    /// Must be called before the app finishes launching (application
    /// (_:didFinishLaunchingWithOptions:)).
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }

            handle(task)
        }
    }

    /// Submits the next refresh request; call after registering and after
    /// each task fires so the system keeps a request queued.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 24) // Check once a day

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // 1 = no launch-mode permission, 2 = too many tasks of the same
            // identifier pending. Resubmission happens on next schedule(),
            // so neither error is fatal.
            logger.info("Background refresh scheduling: \(String(describing: error))")
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule() // Queue the next refresh window first (legacy app pattern).

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        // setTaskCompleted must be called exactly once, no matter which
        // path (success, early-bail, or expiration) runs first.
        var completed = false
        let completionLock = NSLock()
        let complete: (Bool) -> Void = { success in
            completionLock.lock()
            let alreadyRan = completed
            completed = true
            completionLock.unlock()

            guard !alreadyRan else { return }
            DispatchQueue.main.async {
                task.setTaskCompleted(success: success)
            }
        }

        let operation = BlockOperation {
            Stylesheet.main.update { error in
                complete(error == nil)
                // AppStateModel is @MainActor-isolated.
                Task { @MainActor in
                    AppStateModel.shared.refresh()
                }
            }
        }

        task.expirationHandler = {
            queue.cancelAllOperations()

            // If the operation never started executing, no completion
            // callback is coming; finish the task here.
            if !operation.isExecuting {
                complete(false)
            }
        }

        queue.addOperation(operation)
    }
}
