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

    func testTelegramOKResponseIsSuccessEvenWithoutOptionalMetadata() throws {
        let data = Data(#"{"ok":true}"#.utf8)
        let result = try TelegramDirectAPI.parseUploadResponse(data: data, statusCode: 200)

        XCTAssertNil(result.messageId)
        XCTAssertNil(result.fileId)
    }

    func testSuccessfulHTTPResponseWithMissingBackgroundBodyDoesNotFail() throws {
        let result = try TelegramDirectAPI.parseUploadResponse(data: Data(), statusCode: 200)

        XCTAssertNil(result.messageId)
        XCTAssertNil(result.fileId)
    }

    func testTelegramErrorResponseIsFailure() {
        let data = Data(#"{"ok":false,"description":"Bad Request: chat not found"}"#.utf8)

        XCTAssertThrowsError(try TelegramDirectAPI.parseUploadResponse(data: data, statusCode: 400)) { error in
            XCTAssertEqual(error.localizedDescription, "Bad Request: chat not found")
        }
    }

    func testTelegramRetryAfterIsNotARegularUploadFailure() {
        let data = Data(#"{"ok":false,"description":"Too Many Requests","parameters":{"retry_after":12}}"#.utf8)

        XCTAssertThrowsError(try TelegramDirectAPI.parseUploadResponse(data: data, statusCode: 429)) { error in
            guard case TelegramDirectAPIError.rateLimited(let seconds) = error else {
                return XCTFail("Expected rateLimited error")
            }
            XCTAssertEqual(seconds, 12)
        }
    }
}