import SwiftUI

struct BackupDashboardView: View {
    @ObservedObject var manager: BackupManager

    private let columns = [GridItem(.adaptive(minimum: 142), spacing: 12)]

    var body: some View {
        NavigationStack {
            AdaptiveScreen {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    progressCard
                    statsCard
                    controlsCard
                    throttlingCard
                    statusCard
                }
            }
            .navigationTitle("النسخ الاحتياطي")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var heroCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppTheme.gold.opacity(0.18))
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.lightGold)
                }
                .frame(width: 66, height: 66)
                .overlay { Circle().stroke(AppTheme.gold.opacity(0.65), lineWidth: 1) }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Telegram Photo Drive")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.lightGold)
                    Text("نسخة احتياطية ذكية وآمنة لصورك، صورة واحدة في كل مرة مع حماية من التكرار والـ rate limit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var progressCard: some View {
        GlassCard {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("تقدم النسخ").font(.headline)
                    Text(manager.stats.total == 0 ? "ابدأ بفهرسة مكتبة الصور" : "تم تأكيد الصور المرفوعة إلى Telegram")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(manager.stats.progress * 100))%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.lightGold)
            }

            ProgressView(value: manager.stats.progress)
                .tint(AppTheme.gold)
                .scaleEffect(y: 1.8)
                .padding(.vertical, 8)

            HStack {
                Label("\(manager.stats.uploaded) مكتملة", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(AppTheme.success)
                Spacer()
                Text("\(manager.stats.remaining) متبقية").foregroundStyle(.secondary)
            }
            .font(.footnote.weight(.semibold))
        }
    }

    private var statsCard: some View {
        GlassCard {
            Text("مركز العمليات")
                .font(.headline)
                .foregroundStyle(AppTheme.lightGold)

            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(title: "كل الصور", value: manager.stats.total, color: AppTheme.lightGold, systemImage: "photo.stack.fill")
                StatTile(title: "في الانتظار", value: manager.stats.pending, color: AppTheme.gold, systemImage: "clock.badge.checkmark")
                StatTile(title: "قيد الرفع", value: manager.stats.uploading, color: .indigo, systemImage: "arrow.up.circle.fill")
                StatTile(title: "مؤكدة", value: manager.stats.uploaded, color: AppTheme.success, systemImage: "checkmark.seal.fill")
                StatTile(title: "تحتاج مراجعة", value: manager.stats.failed, color: AppTheme.danger, systemImage: "exclamationmark.triangle.fill")
            }
        }
    }

    private var controlsCard: some View {
        GlassCard {
            Text("التحكم الذكي")
                .font(.headline)
                .foregroundStyle(AppTheme.lightGold)

            Button { Task { await manager.requestPhotosAccess() } } label: {
                Label("طلب صلاحية الصور", systemImage: "photo.badge.checkmark")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: .indigo))

            Button { manager.indexLibrary() } label: {
                Label("فهرسة الصور الجديدة", systemImage: "square.stack.3d.up.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: AppTheme.gold, darkLabel: true))

            Button { manager.isRunning ? manager.stopBackup() : manager.startBackup() } label: {
                Label(manager.isRunning ? "إيقاف مؤقت آمن" : "بدء / استكمال النسخ", systemImage: manager.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: manager.isRunning ? AppTheme.goldShadow : AppTheme.gold, darkLabel: !manager.isRunning))

            Button { manager.retryFailedAssets() } label: {
                Label("إعادة تهيئة الصور الفاشلة", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: .indigo))
            .disabled(manager.stats.failed == 0 || manager.isRunning)
            .opacity(manager.stats.failed == 0 || manager.isRunning ? 0.5 : 1)

            Button { manager.refreshStats() } label: {
                Label("تحديث الحالة الآن", systemImage: "arrow.clockwise.circle.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle(tint: .indigo))
        }
    }

    private var throttlingCard: some View {
        GlassCard {
            HStack {
                Label("حماية Telegram", systemImage: "shield.lefthalf.filled").font(.headline)
                Spacer()
                Text("\(manager.uploadDelaySeconds) ثوانٍ")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(AppTheme.lightGold)
            }

            Stepper("الفاصل بين كل صورة والتي تليها", value: $manager.uploadDelaySeconds, in: 2...30, step: 1)
                .font(.subheadline)
            Text("الفاصل يقلل الضغط على Telegram. عند ظهور rate limit سينتظر التطبيق تلقائيًا بدل تسجيل الصورة كفاشلة.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        GlassCard {
            Label(manager.isRunning ? "النظام يعمل الآن" : "آخر حالة للنظام", systemImage: manager.isRunning ? "bolt.horizontal.fill" : "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(manager.isRunning ? AppTheme.success : AppTheme.lightGold)
            Text(manager.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if manager.stats.failed > 0 {
                Label("الصور الفاشلة لا تعيد إرسال الصور المؤكدة، ويمكن إعادة تهيئتها من زر التحكم.", systemImage: "info.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.gold)
            }
        }
    }
}