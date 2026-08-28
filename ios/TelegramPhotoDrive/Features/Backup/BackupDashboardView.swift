import SwiftUI

struct BackupDashboardView: View {
    @ObservedObject var manager: BackupManager

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            AdaptiveScreen {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statsCard
                    throttlingCard
                    actionsCard
                    statusCard
                }
            }
            .navigationTitle("النسخ الاحتياطي")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.cyan)
                    .frame(width: 58, height: 58)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Telegram Photo Drive")
                        .font(.title2.bold())
                    Text("نسخ صورك إلى Telegram بوت بشكل مباشر وآمن مع انتظار بين كل صورة لتجنب السبام.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statsCard: some View {
        GlassCard {
            Text("الإحصائيات")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(title: "المجموع", value: manager.stats.total, color: .blue, systemImage: "photo.stack")
                StatTile(title: "معلقة", value: manager.stats.pending, color: .orange, systemImage: "clock")
                StatTile(title: "قيد الرفع", value: manager.stats.uploading, color: .cyan, systemImage: "arrow.up.circle")
                StatTile(title: "مرفوعة", value: manager.stats.uploaded, color: .green, systemImage: "checkmark.seal")
                StatTile(title: "فاشلة", value: manager.stats.failed, color: .red, systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var throttlingCard: some View {
        GlassCard {
            HStack {
                Label("حماية من السبام", systemImage: "timer")
                    .font(.headline)
                Spacer()
                Text("\(manager.uploadDelaySeconds) ثوانٍ")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.cyan)
            }

            Stepper("مدة الانتظار بين كل صورة وصورة", value: $manager.uploadDelaySeconds, in: 2...30, step: 1)
                .font(.subheadline)

            Text("زيادة المدة تقلل ضغط الطلبات على Telegram وتخفف احتمالية ظهور rate limit أو فشل مؤقت.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var actionsCard: some View {
        GlassCard {
            Text("الأوامر")
                .font(.headline)

            Button {
                Task { await manager.requestPhotosAccess() }
            } label: {
                Label("طلب صلاحية الصور", systemImage: "photo.badge.checkmark")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: .indigo))

            Button {
                manager.indexLibrary()
            } label: {
                Label("فهرسة الصور", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: .blue))

            Button {
                manager.isRunning ? manager.stopBackup() : manager.startBackup()
            } label: {
                Label(manager.isRunning ? "إيقاف مؤقت" : "بدء/استكمال النسخ", systemImage: manager.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: manager.isRunning ? .orange : .green))

            Button {
                manager.refreshStats()
            } label: {
                Label("تحديث الإحصائيات", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: .teal))
        }
    }

    private var statusCard: some View {
        GlassCard {
            Label("الحالة الحالية", systemImage: manager.isRunning ? "bolt.horizontal.fill" : "info.circle")
                .font(.headline)
            Text(manager.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}