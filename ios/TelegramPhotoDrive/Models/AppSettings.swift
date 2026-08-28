import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var telegramChatID: String {
        didSet { UserDefaults.standard.set(telegramChatID, forKey: Keys.telegramChatID) }
    }
    @Published var wifiOnly: Bool {
        didSet { UserDefaults.standard.set(wifiOnly, forKey: Keys.wifiOnly) }
    }
    @Published var hasBotToken: Bool = false

    var isConfigured: Bool {
        hasBotToken && !telegramChatID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum Keys {
        static let telegramChatID = "telegramChatID"
        static let wifiOnly = "wifiOnly"
    }

    init(keychain: KeychainService = KeychainService()) {
        let bundledChatID = Bundle.main.object(forInfoDictionaryKey: "DefaultTelegramChatID") as? String
        let validBundledChatID = bundledChatID?.contains("$(") == false ? bundledChatID : nil
        self.telegramChatID = UserDefaults.standard.string(forKey: Keys.telegramChatID) ?? validBundledChatID ?? ""
        self.wifiOnly = UserDefaults.standard.object(forKey: Keys.wifiOnly) as? Bool ?? true
        if (try? keychain.readToken()) == nil,
           let bundledToken = Bundle.main.object(forInfoDictionaryKey: "DefaultTelegramBotToken") as? String,
           bundledToken.contains(":"),
           !bundledToken.contains("$(") {
            try? keychain.saveToken(bundledToken)
        }
        self.hasBotToken = (try? keychain.readToken()) != nil
    }
}