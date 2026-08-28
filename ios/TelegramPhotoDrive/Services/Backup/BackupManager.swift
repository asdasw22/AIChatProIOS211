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
    private let failedRetryCooldownSeconds = 10 * 60
    private let pendingRetryCooldownSeconds = 60
    private let maxRetryCount = 3

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
            asset.status = .pending
            asset.lastError = "توقفت العملية قبل اكتمال التأكيد، وسيتم الانتقال للصورة التالية ثم إعادة المحاولة لاحقًا."
            asset.lastAttemptAt = Date()
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

    private func nextAssetForUpload() -> BackupAsset? {
        if let pendingAsset = nextPendingAsset() {
            return pendingAsset
        }
        return nextRetryableFailedAsset()
    }

    private func nextPendingAsset() -> BackupAsset? {
        var descriptor = FetchDescriptor<BackupAsset>(
            predicate: #Predicate { $0.statusRawValue == "pending" },
            sortBy: [SortDescriptor(\.creationDate, order: .forward), SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 50
        let now = Date()
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        return candidates.first { candidate in
            guard let lastAttemptAt = candidate.lastAttemptAt else { return true }
            return lastAttemptAt <= now.addingTimeInterval(-TimeInterval(pendingRetryCooldownSeconds))
        }
    }

    private func nextRetryableFailedAsset() -> BackupAsset? {
        let cooldownDate = Date(timeIntervalSinceNow: -TimeInterval(failedRetryCooldownSeconds))
        var descriptor = FetchDescriptor<BackupAsset>(
            predicate: #Predicate {
                $0.statusRawValue == "failed" &&
                $0.retryCount < maxRetryCount
            },
            sortBy: [SortDescriptor(\.lastAttemptAt, order: .forward), SortDescriptor(\.creationDate, order: .forward), SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 25
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        return candidates.first { candidate in
            guard let lastAttemptAt = candidate.lastAttemptAt else { return true }
            return lastAttemptAt < cooldownDate
        }
    }

    private func upload(_ asset: BackupAsset) async {
        guard asset.status != .uploaded else { return }

        var telegramConfirmedUpload = false
        do {
            asset.status = .preparing
            asset.lastError = nil
            asset.lastAttemptAt = Date()
            try modelContext.save()
            let exported = try await photos.exportOriginal(for: asset.localIdentifier)
            defer { try? FileManager.default.removeItem(at: exported.fileURL) }
            asset.byteCount = exported.byteCount
            asset.status = .uploading
            try modelContext.save()
            let response = try await api.upload(asset: asset, chatID: settings.telegramChatID, fileURL: exported.fileURL, mimeType: exported.mimeType, wifiOnly: settings.wifiOnly)
            telegramConfirmedUpload = true
            markUploaded(asset, response: response)
            do {
                try modelContext.save()
            } catch {
                // Telegram already confirmed the upload. Keep the local object
                // marked as uploaded and never turn a persistence warning into
                // a false network failure or a duplicate upload.
                message = "تم تأكيد رفع \(asset.filename)، لكن تعذر حفظ الحالة محليًا: \(error.localizedDescription)"
            }
        } catch TelegramDirectAPIError.rateLimited(let seconds) {
            markRateLimited(asset, seconds: seconds)
            message = "Telegram أوقف الرفع مؤقتًا. سننتظر \(seconds) ثانية ثم نكمل."
            if isRunning { try? await Task.sleep(nanoseconds: UInt64(max(seconds, uploadDelaySeconds)) * 1_000_000_000) }
        } catch is CancellationError {
            guard !telegramConfirmedUpload else { return }
            asset.status = .pending
            asset.lastAttemptAt = Date()
            asset.lastError = "تم إيقاف الرفع قبل اكتماله."
        } catch {
            // Never downgrade an upload that Telegram already confirmed. This
            // protects against a local SwiftData/UI error immediately after the
            // network request and prevents duplicate uploads on the next run.
            guard !telegramConfirmedUpload, asset.status != .uploaded else {
                message = "تم تأكيد رفع \(asset.filename)، ولن تتم إعادة إرساله."
                try? modelContext.save()
                return
            }
            markFailed(asset, errorMessage: error.localizedDescription)
            if asset.retryCount >= maxRetryCount {
                message = "تم تخطي \(asset.filename) مؤقتًا بعد \(maxRetryCount) محاولات، وسيكمل التطبيق مع الصور التالية."
            } else {
                message = "فشل رفع \(asset.filename): \(error.localizedDescription). سيتم الانتقال للصورة التالية وإعادة المحاولة لاحقًا."
            }
        }
        try? modelContext.save()
        refreshStats()
    }

    private func markRateLimited(_ asset: BackupAsset, seconds: Int) {
        asset.status = .pending
        // nextPendingAsset applies the normal pending cooldown as well. Offset
        // the timestamp so the effective wait is exactly Telegram's retry_after
        // value, not retry_after plus another full cooldown.
        asset.lastAttemptAt = Date().addingTimeInterval(TimeInterval(max(0, seconds - pendingRetryCooldownSeconds)))
        asset.lastError = "Telegram طلب الانتظار \(seconds) ثانية قبل المحاولة التالية."
        asset.updatedAt = Date()
    }

    private func markUploaded(_ asset: BackupAsset, response: TelegramDirectUploadResult) {
        asset.status = .uploaded
        asset.telegramMessageId = response.messageId
        asset.telegramFileId = response.fileId
        asset.uploadedAt = Date()
        asset.lastError = nil
        asset.updatedAt = Date()
        message = "تم رفع \(asset.filename)، وسيتم الانتقال للصورة التالية."
    }

    private func markFailed(_ asset: BackupAsset, errorMessage: String) {
        asset.status = .failed
        asset.retryCount += 1
        asset.lastError = errorMessage
        asset.updatedAt = Date()
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

    func retryFailedAssets() {
        let descriptor = FetchDescriptor<BackupAsset>(predicate: #Predicate { $0.statusRawValue == "failed" })
        let failed = (try? modelContext.fetch(descriptor)) ?? []
        guard !failed.isEmpty else {
            message = "لا توجد صور فاشلة لإعادة المحاولة"
            return
        }

        for asset in failed {
            asset.status = .pending
            asset.retryCount = 0
            asset.lastAttemptAt = nil
            asset.lastError = nil
        }
        try? modelContext.save()
        refreshStats()
        message = "تمت إعادة تهيئة \(failed.count) صورة لإعادة الرفع"
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