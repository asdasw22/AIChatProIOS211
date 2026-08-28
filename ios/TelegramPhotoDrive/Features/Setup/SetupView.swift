import SwiftUI
import Photos

struct SetupView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var botToken = ""
    @State private var statusMessage = ""
    private let keychain = KeychainService()

    var body: some View {
        NavigationStack {
            AdaptiveScreen {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    telegramCard
                    optionsCard
                    notesCard
                    if !statusMessage.isEmpty { statusCard }
                }
            }
            .navigationTitle("الإعداد")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { botToken = (try? keychain.readToken()) ?? "" }
        }
    }

    private var heroCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(AppTheme.lightGold)
                VStack(alignment: .leading, spacing: 6) {
                    Text("إعداد Telegram")
                        .font(.title2.bold())
                    Text("أدخل توكن البوت وChat ID مرة واحدة، وسيتم حفظ التوكن في Keychain على الجهاز.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var telegramCard: some View {
        GlassCard {
            Text("بيانات البوت")
                .font(.headline)

            SecureField("توكن البوت من BotFather", text: $botToken)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            TextField("Telegram Chat ID / أيدي المستخدم", text: $settings.telegramChatID)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button("حفظ التوكن والإعدادات") { saveSettings() }
                .buttonStyle(PrimaryActionButtonStyle(tint: AppTheme.gold, darkLabel: true))
                .disabled(botToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.telegramChatID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(botToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.telegramChatID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

            if settings.isConfigured {
                Label("الإعدادات جاهزة", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(AppTheme.success)
                    .font(.subheadline.bold())
            }
        }
    }

    private var optionsCard: some View {
        GlassCard {
            Text("الخيارات")
                .font(.headline)
            Toggle("الرفع عبر Wi‑Fi فقط", isOn: $settings.wifiOnly)
            Text("إذا كان اتصالك الخلوي سريعًا وتريد رفع الصور خارجه، عطّل هذا الخيار.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var notesCard: some View {
        GlassCard {
            Label("تنبيهات مهمة", systemImage: "exclamationmark.shield")
                .font(.headline)
            Text("التطبيق سيرسل الصور مباشرةً إلى Telegram Bot API باستخدام التوكن والأيدي اللذين تحفظهما هنا.")
            Text("توكن البوت يُحفظ في Keychain على الجهاز، ولا يوضع داخل ملفات المشروع.")
            Text("iOS لا يضمن العمل المستمر في الخلفية، وسيكمل التطبيق عند إعادة فتحه من آخر عناصر غير مرفوعة.")
            Text("لا تحذف الصور إلا بعد التأكد من النسخة الاحتياطية. الحذف قد يؤثر على iCloud Photos.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var statusCard: some View {
        GlassCard {
            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func saveSettings() {
        do {
            try keychain.saveToken(botToken.trimmingCharacters(in: .whitespacesAndNewlines))
            settings.hasBotToken = true
            statusMessage = "تم حفظ توكن البوت وChat ID"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}