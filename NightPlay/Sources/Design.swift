import SwiftUI

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

/// One set of colors per mode. The hex strings are also used to recolor the YouTube pages.
struct Palette {
    let isDark: Bool
    let bgHex: String        // page background
    let surfaceHex: String   // cards, chips, menus
    let textHex: String
    let subtextHex: String
    let accentHex: String    // buttons and links
    let goldHex: String      // ornaments
    let lineCSS: String      // hairlines on the web pages
    let skyHex: [String]     // home screen gradient, top to bottom

    var bg: Color { Color(hex: bgHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var text: Color { Color(hex: textHex) }
    var subtext: Color { Color(hex: subtextHex) }
    var accent: Color { Color(hex: accentHex) }
    var gold: Color { Color(hex: goldHex) }
    var sky: [Color] { skyHex.map { Color(hex: $0) } }

    static let light = Palette(
        isDark: false,
        bgHex: "#FFF6E9", surfaceHex: "#FBE3EA",
        textHex: "#3B144A", subtextHex: "#7A4A78",
        accentHex: "#B8326F", goldHex: "#C99A3A",
        lineCSS: "rgba(59,20,74,0.14)",
        skyHex: ["#FFF6E9", "#FBD9E4", "#F2A9C4"])

    static let dark = Palette(
        isDark: true,
        bgHex: "#2A0F36", surfaceHex: "#3F1A4E",
        textHex: "#FFF6E9", subtextHex: "#E3C4D6",
        accentHex: "#E8BE64", goldHex: "#E8BE64",
        lineCSS: "rgba(255,246,233,0.16)",
        skyHex: ["#2A0F36", "#7A2460", "#B4507F"])
}

struct Keyhole: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: w, height: w))
        p.move(to: CGPoint(x: rect.minX + w * 0.36, y: rect.minY + w * 0.7))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.64, y: rect.minY + w * 0.7))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.88, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.12, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct MirrorView: View {
    let palette: Palette
    var glow: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: "#FFF6E9"), Color(hex: "#EC96B4")],
                                     startPoint: .top, endPoint: .bottom))
            Keyhole()
                .fill(Color(hex: "#3B144A"))
                .frame(width: 44, height: 74)
            Ellipse().stroke(palette.gold, lineWidth: 6)
            Ellipse().inset(by: 9).stroke(palette.gold.opacity(0.7), lineWidth: 1)
        }
        .frame(width: 130, height: 168)
        .shadow(color: palette.gold.opacity(glow ? 0.9 : 0.35), radius: glow ? 26 : 10)
    }
}

struct HomeView: View {
    let palette: Palette
    var onSearch: (String) -> Void
    var onOpen: (String) -> Void
    var onToggleMode: () -> Void

    @State private var query = ""
    @State private var glow = false
    @State private var twinkle = false

    var body: some View {
        let p = palette
        ZStack {
            LinearGradient(colors: p.sky, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            sparkle(x: -135, y: -300, size: 20, early: true)
            sparkle(x: 130, y: -250, size: 13, early: false)
            sparkle(x: 140, y: 60, size: 18, early: true)
            sparkle(x: -140, y: 120, size: 12, early: false)
            sparkle(x: -115, y: 290, size: 17, early: false)
            sparkle(x: 125, y: 270, size: 22, early: true)

            RoundedRectangle(cornerRadius: 30).stroke(p.gold, lineWidth: 2).padding(14)
            RoundedRectangle(cornerRadius: 24).stroke(p.gold.opacity(0.6), lineWidth: 0.8).padding(22)

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button(action: onToggleMode) {
                        Image(systemName: p.isDark ? "sun.max.fill" : "moon.stars.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(p.gold)
                            .padding(10)
                            .background(Circle().fill(p.surface.opacity(0.9)))
                            .overlay(Circle().stroke(p.gold, lineWidth: 1))
                    }
                }
                .padding(.top, 34)

                Image(systemName: "crown.fill")
                    .font(.system(size: 34))
                    .foregroundColor(p.gold)
                Text("Once upon a time\u{2026}")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundColor(p.text)
                Text("WHAT STORY SHALL WE PLAY?")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .tracking(3)
                    .foregroundColor(p.subtext)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(p.gold)
                    TextField("Search", text: $query)
                        .font(.system(size: 17, design: .serif))
                        .foregroundColor(p.text)
                        .tint(p.accent)
                        .submitLabel(.search)
                        .autocorrectionDisabled(true)
                        .onSubmit(submit)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(Capsule().fill(p.surface))
                .overlay(Capsule().stroke(p.gold, lineWidth: 1.5))
                .padding(.top, 6)

                HStack(spacing: 10) {
                    chip("Home", "")
                    chip("Subscriptions", "feed/subscriptions")
                }
                HStack(spacing: 10) {
                    chip("Library", "feed/library")
                    chip("History", "feed/history")
                }

                Spacer()
                MirrorView(palette: p, glow: glow)
                Spacer()
                Text("NightPlay")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(p.subtext)
                    .padding(.bottom, 36)
            }
            .padding(.horizontal, 40)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { twinkle = true }
        }
    }

    private func submit() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { onSearch(q) }
    }

    private func chip(_ title: String, _ path: String) -> some View {
        let p = palette
        return Button(action: { onOpen(path) }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(p.isDark ? p.bg : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(p.accent))
        }
    }

    private func sparkle(x: CGFloat, y: CGFloat, size: CGFloat, early: Bool) -> some View {
        let bright = early ? twinkle : !twinkle
        return Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundColor(palette.gold)
            .opacity(bright ? 1.0 : 0.25)
            .scaleEffect(bright ? 1.15 : 0.8)
            .offset(x: x, y: y)
    }
}
