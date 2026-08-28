import Foundation
import Photos
import SwiftData
import BackgroundTasks

@MainActor
final class BackupManager: ObservableObject {
    @Published var isRunning = false
    @Published var message = "جاهز"
    @Published var stats = BackupStats(total: 0, pending: 0, uploading: 0, uploaded: 0, failed: 0)
    @Published var uploadDelaySeconds: Int {
        didSet { UserDefaults.standard.set(uploadDelaySeconds, forKey: Keys.uploadDelaySeconds) }
    }

    private let modelContext: ModelContext
    private let photos: PhotoLibraryService
    private let api: TelegramDirectAPI
    private let settings: AppSettings
    private let maximumRetryDelaySeconds = 90

    private enum Keys {
        static let uploadDelaySeconds = "backupUploadDelaySeconds"
    }

    init(modelContext: ModelContext, settings: AppSettings, photos: PhotoLibraryService = PhotoLibraryService(), api: TelegramDirectAPI = TelegramDirectAPI()) {
        self.modelContext = modelContext
        self.settings = settings
        self.photos = photos
        self.api = api
        self.uploadDelaySeconds = UserDefaults.standard.object(forKey: Keys.uploadDelaySeconds) as? Int ?? 4
        recoverInterruptedWork()
        refreshStats()
    }

    private func recoverInterruptedWork() {
        let descriptor = FetchDescriptor<BackupAsset>(predicate: #Predicate { $0.statusRawValue == "preparing" || $0.statusRawValue == "uploading" })
        let interrupted = (try? modelContext.fetch(descriptor)) ?? []
        for asset in interrupted {
            asset.status = .failed
            asset.lastError = "توقفت العملية قبل اكتمال التأكيد، وسيعاد المحاولة بأمان."
        }
        if !interrupted.isEmpty { try? modelContext.save() }
    }

    func requestPhotosAccess() async {
        let status = await photos.requestAuthorization()
        message = status == .authorized || status == .limited ? "تم منح صلاحية الصور" : "لم تُمنح صلاحية الصور"
    }

    func indexLibrary() {
        let assets = photos.fetchImageAssets()
        for asset in assets {
            let id = asset.localIdentifier
            let descriptor = FetchDescriptor<BackupAsset>(predicate: #Predicate { $0.localIdentifier == id })
            let exists = (try? modelContext.fetchCount(descriptor)) ?? 0
            if exists == 0 {
                let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "photo-\(asset.localIdentifier.hashValue).jpg"
                modelContext.insert(BackupAsset(localIdentifier: id, filename: filename, creationDate: asset.creationDate))
            }
        }
        try? modelContext.save()
        refreshStats()
        message = "تمت فهرسة \(assets.count) صورة"
    }

    func startBackup(limit: Int = Int.max) {
        guard !isRunning else { return }
        isRunning = true
        Task { await runQueue(limit: limit) }
    }

    func stopBackup() {
        isRunning = false
        message = "تم إيقاف النسخ مؤقتًا"
    }

    func runQueue(limit: Int = Int.max) async {
        defer { isRunning = false; refreshStats(); scheduleBackgroundProcessing() }
        guard settings.isConfigured else {
            message = "أدخل توكن البوت وTelegram Chat ID أولًا"
            return
        }
        var processed = 0
        while isRunning && processed < limit {
            guard let asset = nextAssetForUpload() else {
                message = "لا توجد صور معلقة"
                return
            }
            processed += 1
            await upload(asset)
            await pauseBetweenUploads()
        }
    }

    private func pauseBetweenUploads() async {
        guard isRunning, uploadDelaySeconds > 0 else { return }
        message = "انتظار \(uploadDelaySeconds) ثوانٍ قبل الصورة التالية لتجنب سبام Telegram..."
        try? await Task.sleep(nanoseconds: UInt64(uploadDelaySeconds) * 1_000_000_000)
    }

    private func retryDelay(for retryCount: Int) -> Int {
        min(maximumRetryDelaySeconds, max(uploadDelaySeconds, retryCount * uploadDelaySeconds))
    }

    private func nextAssetForUpload() -> BackupAsset? {
        var descriptor = FetchDescriptor<BackupAsset>(
            predicate: #Predicate { $0.statusRawValue == "pending" || $0.statusRawValue == "failed" },
            sortBy: [SortDescriptor(\.creationDate, order: .forward), SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func upload(_ asset: BackupAsset) async {
        do {
            asset.status = .preparing
            asset.lastError = nil
            try modelContext.save()
            let exported = try await photos.exportOriginal(for: asset.localIdentifier)
            defer { try? FileManager.default.removeItem(at: exported.fileURL) }
            asset.byteCount = exported.byteCount
            asset.status = .uploading
            try modelContext.save()
            let response = try await api.upload(asset: asset, chatID: settings.telegramChatID, fileURL: exported.fileURL, mimeType: exported.mimeType, wifiOnly: settings.wifiOnly)
            asset.status = .uploaded
            asset.telegramMessageId = response.messageId
            asset.telegramFileId = response.fileId
            asset.uploadedAt = Date()
            message = "تم رفع \(asset.filename)"
        } catch TelegramDirectAPIError.rateLimited(let seconds) {
            asset.status = .failed
            asset.retryCount += 1
            asset.lastError = TelegramDirectAPIError.rateLimited(seconds).localizedDescription
            message = "Telegram أوقف الرفع مؤقتًا. سننتظر \(seconds) ثانية ثم نكمل."
            if isRunning { try? await Task.sleep(nanoseconds: UInt64(max(seconds, uploadDelaySeconds)) * 1_000_000_000) }
        } catch {
            asset.status = .failed
            asset.retryCount += 1
            asset.lastError = error.localizedDescription
            let delay = retryDelay(for: asset.retryCount)
            message = "فشل رفع \(asset.filename): \(error.localizedDescription). انتظار \(delay) ثانية قبل المتابعة."
            if isRunning { try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000) }
        }
        asset.updatedAt = Date()
        try? modelContext.save()
        refreshStats()
    }

    func refreshStats() {
        let all = (try? modelContext.fetch(FetchDescriptor<BackupAsset>())) ?? []
        stats = BackupStats(
            total: all.count,
            pending: all.filter { $0.status == .pending }.count,
            uploading: all.filter { $0.status == .uploading || $0.status == .preparing }.count,
            uploaded: all.filter { $0.status == .uploaded }.count,
            failed: all.filter { $0.status == .failed }.count
        )
    }

    func uploadedAssets() -> [BackupAsset] {
        let descriptor = FetchDescriptor<BackupAsset>(predicate: #Predicate { $0.statusRawValue == "uploaded" }, sortBy: [SortDescriptor(\.uploadedAt, order: .forward)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func deleteUploadedAssets(_ assets: [BackupAsset]) async {
        do {
            try await photos.deleteAssets(localIdentifiers: assets.map(\.localIdentifier))
            message = "تم إرسال طلب حذف الصور المحددة إلى النظام"
        } catch {
            message = "فشل حذف الصور: \(error.localizedDescription)"
        }
    }

    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskCoordinator.identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}