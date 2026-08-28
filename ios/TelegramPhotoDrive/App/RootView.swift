import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @StateObject private var holder = BackupManagerHolder()

    var body: some View {
        TabView {
            SetupView()
                .tabItem { Label("الإعداد", systemImage: "gearshape") }
            BackupDashboardView(manager: manager)
                .tabItem { Label("النسخ", systemImage: "icloud.and.arrow.up") }
            CleanupView(manager: manager)
                .tabItem { Label("التنظيف", systemImage: "trash") }
        }
        .onAppear { holder.configureIfNeeded(modelContext: modelContext, settings: settings) }
    }

    private var manager: BackupManager {
        holder.manager ?? BackupManager(modelContext: modelContext, settings: settings)
    }
}

@MainActor
final class BackupManagerHolder: ObservableObject {
    @Published var manager: BackupManager?

    func configureIfNeeded(modelContext: ModelContext, settings: AppSettings) {
        guard manager == nil else { return }
        manager = BackupManager(modelContext: modelContext, settings: settings)
    }
}