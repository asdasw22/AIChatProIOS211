import Foundation

final class BackgroundUploadClient: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    static let shared = BackgroundUploadClient()
    static let identifier = "com.youssef.telegramphotodrive.background-upload"

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private struct PendingUpload {
        let continuation: CheckedContinuation<(Data, URLResponse), Error>
        var data = Data()
    }

    private let lock = NSLock()
    private var pending: [Int: PendingUpload] = [:]

    private override init() {
        super.init()
    }

    func upload(request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, fromFile: fileURL)
            lock.lock()
            pending[task.taskIdentifier] = PendingUpload(continuation: continuation)
            lock.unlock()
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        if var upload = pending[dataTask.taskIdentifier] {
            upload.data.append(data)
            pending[dataTask.taskIdentifier] = upload
        }
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let upload = pending.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        guard let upload else { return }
        if let error {
            upload.continuation.resume(throwing: error)
        } else if let response = task.response {
            upload.continuation.resume(returning: (upload.data, response))
        } else {
            upload.continuation.resume(throwing: URLError(.badServerResponse))
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let identifier = session.configuration.identifier {
            BackgroundSessionEvents.shared.finish(identifier: identifier)
        }
    }
}