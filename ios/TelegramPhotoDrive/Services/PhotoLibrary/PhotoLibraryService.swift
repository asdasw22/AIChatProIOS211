import Foundation
import Photos
import UniformTypeIdentifiers

struct ExportedPhoto {
    let fileURL: URL
    let mimeType: String
    let byteCount: Int64
}

enum PhotoLibraryServiceError: LocalizedError {
    case notAuthorized
    case assetNotFound
    case noResource
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "لم تُمنح صلاحية الوصول إلى الصور."
        case .assetNotFound: return "تعذر العثور على الصورة."
        case .noResource: return "لا يوجد ملف أصلي قابل للتصدير لهذه الصورة."
        case .exportFailed: return "فشل تجهيز ملف الصورة للرفع."
        }
    }
}

final class PhotoLibraryService {
    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func currentAuthorization() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func fetchImageAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func exportOriginal(for localIdentifier: String) async throws -> ExportedPhoto {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetch.firstObject else { throw PhotoLibraryServiceError.assetNotFound }
        guard let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) else {
            throw PhotoLibraryServiceError.noResource
        }
        let fileName = resource.originalFilename.isEmpty ? "photo-\(UUID().uuidString).jpg" : resource.originalFilename
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + fileName)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: tempURL, options: options) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: ()) }
            }
        }
        let values = try tempURL.resourceValues(forKeys: [.fileSizeKey])
        let mimeType = UTType(filenameExtension: tempURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return ExportedPhoto(fileURL: tempURL, mimeType: mimeType, byteCount: Int64(values.fileSize ?? 0))
    }

    func deleteAssets(localIdentifiers: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}