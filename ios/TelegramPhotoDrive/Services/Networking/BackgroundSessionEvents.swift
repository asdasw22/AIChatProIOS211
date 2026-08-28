import Foundation

final class BackgroundSessionEvents {
    static let shared = BackgroundSessionEvents()
    private var completionHandlers: [String: () -> Void] = [:]
    private let lock = NSLock()

    private init() {}

    func store(identifier: String, completionHandler: @escaping () -> Void) {
        lock.lock()
        completionHandlers[identifier] = completionHandler
        lock.unlock()
    }

    func finish(identifier: String) {
        lock.lock()
        let handler = completionHandlers.removeValue(forKey: identifier)
        lock.unlock()
        DispatchQueue.main.async { handler?() }
    }
}