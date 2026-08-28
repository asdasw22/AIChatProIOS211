import XCTest
@testable import TelegramPhotoDrive

final class TelegramPhotoDriveTests: XCTestCase {
    func testBackupAssetStoresStatusAndIdempotencyKey() {
        let asset = BackupAsset(localIdentifier: "asset/local/id", filename: "IMG_0001.HEIC", creationDate: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(asset.status, .pending)
        XCTAssertNil(asset.lastAttemptAt)
        XCTAssertFalse(asset.idempotencyKey.isEmpty)
        asset.status = .uploaded
        asset.lastAttemptAt = Date(timeIntervalSince1970: 10)
        XCTAssertEqual(asset.status, .uploaded)
        XCTAssertEqual(asset.lastAttemptAt, Date(timeIntervalSince1970: 10))
    }

    func testDirectUploadResultStoresTelegramIdentifiers() {
        let result = TelegramDirectUploadResult(messageId: 10, fileId: "telegram-file-id")
        XCTAssertEqual(result.messageId, 10)
        XCTAssertEqual(result.fileId, "telegram-file-id")
    }
}