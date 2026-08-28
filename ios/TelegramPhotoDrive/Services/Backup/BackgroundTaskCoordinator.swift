import BackgroundTasks
import Foundation

enum BackgroundTaskCoordinator {
    static let identifier = "com.youssef.telegramphotodrive.backup-processing"

    static func register(handler: @escaping () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let operation = Task {
                await handler()
                processingTask.setTaskCompleted(success: true)
            }
            processingTask.expirationHandler = {
                operation.cancel()
                processingTask.setTaskCompleted(success: false)
            }
        }
    }
}