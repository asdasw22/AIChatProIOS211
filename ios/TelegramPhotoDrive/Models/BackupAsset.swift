import Foundation
import SwiftData

enum BackupStatus: String, Codable, CaseIterable {
    case pending
    case preparing
    case uploading
    case uploaded
    case failed
    case skippedTooLarge
}

@Model
final class BackupAsset {
    @Attribute(.unique) var localIdentifier: String
    var filename: String
    var creationDate: Date?
    var statusRawValue: String
    var byteCount: Int64
    var retryCount: Int
    var lastError: String?
    var telegramMessageId: Int?
    var telegramFileId: String?
    var uploadedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(localIdentifier: String, filename: String, creationDate: Date?, status: BackupStatus = .pending, byteCount: Int64 = 0) {
        self.localIdentifier = localIdentifier
        self.filename = filename
        self.creationDate = creationDate
        self.statusRawValue = status.rawValue
        self.byteCount = byteCount
        self.retryCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var status: BackupStatus {
        get { BackupStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue; updatedAt = Date() }
    }

    var idempotencyKey: String {
        localIdentifier.data(using: .utf8)?.base64EncodedString() ?? localIdentifier
    }
}

struct BackupStats {
    var total: Int
    var pending: Int
    var uploading: Int
    var uploaded: Int
    var failed: Int
}