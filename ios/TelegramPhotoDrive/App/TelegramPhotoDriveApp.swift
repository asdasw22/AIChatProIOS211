import SwiftUI
import SwiftData

@main
struct TelegramPhotoDriveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: BackupAsset.self)
            let backgroundContainer = container
            BackgroundTaskCoordinator.register {
                await runBackgroundBackup(container: backgroundContainer)
            }
        } catch {
            preconditionFailure("Unable to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .modelContainer(container)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

@MainActor
private func runBackgroundBackup(container: ModelContainer) async {
    let context = ModelContext(container)
    let backgroundSettings = AppSettings()
    let manager = BackupManager(modelContext: context, settings: backgroundSettings)
    manager.isRunning = true
    await manager.runQueue(limit: 3)
}
