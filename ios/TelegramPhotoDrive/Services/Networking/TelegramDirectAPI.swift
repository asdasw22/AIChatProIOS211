import Foundation

struct TelegramDirectUploadResult {
    let messageId: Int?
    let fileId: String?
}

private struct TelegramSendDocumentResponse: Decodable {
    let ok: Bool
    let description: String?
    let result: TelegramMessage?
    let parameters: TelegramResponseParameters?
}

private struct TelegramResponseParameters: Decodable {
    let retryAfter: Int?

    enum CodingKeys: String, CodingKey {
        case retryAfter = "retry_after"
    }
}

private struct TelegramMessage: Decodable {
    let messageId: Int?
    let document: TelegramDocument?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case document
    }
}

private struct TelegramDocument: Decodable {
    let fileId: String?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
    }
}

enum TelegramDirectAPIError: LocalizedError {
    case missingBotToken
    case invalidBotToken
    case invalidChatID
    case rateLimited(Int)
    case telegram(String)
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingBotToken: return "أدخل توكن البوت أولًا."
        case .invalidBotToken: return "توكن البوت غير صحيح."
        case .invalidChatID: return "Telegram Chat ID غير صحيح."
        case .rateLimited(let seconds): return "Telegram طلب الانتظار \(seconds) ثانية قبل المحاولة التالية."
        case .telegram(let message): return message
        case .badStatus(let status): return "فشل طلب Telegram برمز HTTP \(status)."
        }
    }
}

final class TelegramDirectAPI {
    private let keychain: KeychainService
    private let decoder = JSONDecoder()
    private let backgroundUploader: BackgroundUploadClient

    init(keychain: KeychainService = KeychainService(), backgroundUploader: BackgroundUploadClient = .shared) {
        self.keychain = keychain
        self.backgroundUploader = backgroundUploader
    }

    func upload(asset: BackupAsset, chatID: String, fileURL: URL, mimeType: String, wifiOnly: Bool) async throws -> TelegramDirectUploadResult {
        guard let token = try keychain.readToken()?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw TelegramDirectAPIError.missingBotToken
        }
        guard token.contains(":"), let endpoint = URL(string: "https://api.telegram.org/bot\(token)/sendDocument") else {
            throw TelegramDirectAPIError.invalidBotToken
        }
        let cleanChatID = chatID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChatID.isEmpty else { throw TelegramDirectAPIError.invalidChatID }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "content-type")
        request.allowsCellularAccess = !wifiOnly
        request.allowsConstrainedNetworkAccess = !wifiOnly

        let bodyFileURL = try multipartBodyFile(boundary: boundary, asset: asset, chatID: cleanChatID, fileURL: fileURL, mimeType: mimeType)
        defer { try? FileManager.default.removeItem(at: bodyFileURL) }

        let (data, response) = try await backgroundUploader.upload(request: request, fromFile: bodyFileURL)
        guard let http = response as? HTTPURLResponse else { throw TelegramDirectAPIError.badStatus(-1) }
        let telegram = try? decoder.decode(TelegramSendDocumentResponse.self, from: data)

        if let retryAfter = telegram?.parameters?.retryAfter {
            throw TelegramDirectAPIError.rateLimited(retryAfter)
        }

        guard 200..<300 ~= http.statusCode else {
            if let description = telegram?.description, !description.isEmpty {
                throw TelegramDirectAPIError.telegram(description)
            }
            throw TelegramDirectAPIError.badStatus(http.statusCode)
        }

        guard let telegramResponse = telegram, telegramResponse.ok else {
            throw TelegramDirectAPIError.telegram(telegram?.description ?? "Telegram رفض رفع الملف.")
        }
        return TelegramDirectUploadResult(messageId: telegramResponse.result?.messageId, fileId: telegramResponse.result?.document?.fileId)
    }

    private func multipartBodyFile(boundary: String, asset: BackupAsset, chatID: String, fileURL: URL, mimeType: String) throws -> URL {
        var data = Data()
        func appendField(_ name: String, _ value: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("chat_id", chatID)
        appendField("caption", caption(for: asset))
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"document\"; filename=\"\(escapedFilename(asset.filename))\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(try Data(contentsOf: fileURL))
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("telegram-upload-\(UUID().uuidString).multipart")
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }

    private func caption(for asset: BackupAsset) -> String {
        var lines = ["Telegram Photo Drive backup", "asset: \(asset.localIdentifier)"]
        if let creationDate = asset.creationDate { lines.append("created: \(ISO8601DateFormatter().string(from: creationDate))") }
        return lines.joined(separator: "\n")
    }

    private func escapedFilename(_ filename: String) -> String {
        filename.replacingOccurrences(of: "\"", with: "'")
    }
}