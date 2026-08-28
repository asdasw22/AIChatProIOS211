import SwiftUI

struct CleanupView: View {
    @ObservedObject var manager: BackupManager
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            AdaptiveScreen {
                VStack(alignment: .leading, spacing: 18) {
                    GlassCard {
                        HStack(spacing: 14) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 46))
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("تنظيف آمن")
                                    .font(.title2.bold())
                                Text("احذف فقط الصور التي تم رفعها وتأكيدها داخل Telegram.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    GlassCard {
                        Label("قبل الحذف", systemImage: "hand.raised.fill")
                            .font(.headline)
                        Text("سيطلب iOS موافقتك قبل حذف الصور. إذا كانت iCloud Photos مفعلة فقد تُحذف الصور من iCloud أيضًا.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Button {
                            showingConfirmation = true
                        } label: {
                            Label("حذف الصور المرفوعة والمؤكدة", systemImage: "trash.fill")
                        }
                        .buttonStyle(PrimaryActionButtonStyle(tint: .red))

                        Text(manager.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("التنظيف")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("هل تريد حذف الصور المرفوعة والمؤكدة من مكتبة الصور؟", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("حذف", role: .destructive) {
                    let assets = manager.uploadedAssets()
                    Task { await manager.deleteUploadedAssets(assets) }
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("لا تستخدم هذا الخيار إلا بعد التأكد من أن الصور موجودة في Telegram.")
            }
        }
    }
}