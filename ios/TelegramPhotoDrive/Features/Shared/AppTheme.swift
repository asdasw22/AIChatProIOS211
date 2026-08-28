import SwiftUI

enum AppTheme {
    static let black = Color(red: 0.015, green: 0.018, blue: 0.035)
    static let navy = Color(red: 0.035, green: 0.075, blue: 0.18)
    static let deepNavy = Color(red: 0.015, green: 0.035, blue: 0.10)
    static let gold = Color(red: 0.96, green: 0.70, blue: 0.18)
    static let lightGold = Color(red: 1.0, green: 0.86, blue: 0.45)
    static let goldShadow = Color(red: 0.86, green: 0.52, blue: 0.08)
    static let success = Color(red: 0.26, green: 0.86, blue: 0.58)
    static let danger = Color(red: 1.0, green: 0.34, blue: 0.38)
}

struct AppGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.black,
                    AppTheme.deepNavy,
                    AppTheme.navy,
                    AppTheme.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.gold.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 45)
                .offset(x: -140, y: -260)

            Circle()
                .fill(Color.indigo.opacity(0.26))
                .frame(width: 320, height: 320)
                .blur(radius: 55)
                .offset(x: 170, y: 260)
        }
    }
}

struct AdaptiveScreen<Content: View>: View {
    let maxWidth: CGFloat
    let content: Content

    init(maxWidth: CGFloat = 760, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppGradientBackground()
            ScrollView {
                content
                    .frame(maxWidth: maxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.105), Color.white.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.gold.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 12)
    }
}

struct StatTile: View {
    let title: String
    let value: Int
    let color: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    let tint: Color
    let darkLabel: Bool

    init(tint: Color = AppTheme.gold, darkLabel: Bool = false) {
        self.tint = tint
        self.darkLabel = darkLabel
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(darkLabel ? AppTheme.black : .white)
            .background(
                LinearGradient(
                    colors: darkLabel ? [AppTheme.lightGold, AppTheme.gold] : [tint.opacity(0.95), tint.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(darkLabel ? AppTheme.lightGold.opacity(0.75) : .white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.28), radius: 10, x: 0, y: 7)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}