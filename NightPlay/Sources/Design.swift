import SwiftUI
import AVFoundation
import UIKit

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
    let bgHex: String        // paper
    let surfaceHex: String   // cards
    let textHex: String      // ink
    let subtextHex: String
    let accentHex: String    // rose ink: buttons, links, script lettering
    let goldHex: String
    let lineCSS: String
    let petalHex: String
    let petal2Hex: String
    let sageHex: String
    let curtainHex: String
    let curtain2Hex: String
    let lineHex: String
    let dotHex: String

    var bg: Color { Color(hex: bgHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var text: Color { Color(hex: textHex) }
    var subtext: Color { Color(hex: subtextHex) }
    var accent: Color { Color(hex: accentHex) }
    var gold: Color { Color(hex: goldHex) }
    var petal: Color { Color(hex: petalHex) }
    var petal2: Color { Color(hex: petal2Hex) }
    var sage: Color { Color(hex: sageHex) }
    var curtain: Color { Color(hex: curtainHex) }
    var curtain2: Color { Color(hex: curtain2Hex) }
    var line: Color { Color(hex: lineHex) }
    var dot: Color { Color(hex: dotHex) }
    var key: Color { Color(hex: "#8E3B5A") }
    var mirror: Color { Color(hex: "#F9E4E9") }
    var shade: Color { isDark ? Color.black.opacity(0.45) : Color(hex: "#6E2846").opacity(0.28) }

    static let light = Palette(
        isDark: false,
        bgHex: "#FBF6EE", surfaceHex: "#FFFDF8",
        textHex: "#4A2F33", subtextHex: "#7A5560",
        accentHex: "#8E3B5A", goldHex: "#A8823F",
        lineCSS: "rgba(142,59,90,0.18)",
        petalHex: "#E9A9B9", petal2Hex: "#C97A90", sageHex: "#8FA382",
        curtainHex: "#F3CDD6", curtain2Hex: "#EDBBC7",
        lineHex: "#E3B4C0", dotHex: "#F3E4E2")

    static let dark = Palette(
        isDark: true,
        bgHex: "#2B1A24", surfaceHex: "#38232F",
        textHex: "#F8E6EA", subtextHex: "#DDBFC8",
        accentHex: "#F2B6C6", goldHex: "#D9B978",
        lineCSS: "rgba(248,230,234,0.18)",
        petalHex: "#C97A90", petal2Hex: "#E9A9B9", sageHex: "#9DB38F",
        curtainHex: "#5A2F45", curtain2Hex: "#6B3A53",
        lineHex: "#7A4A5C", dotHex: "#352230")
}

func scriptFont(_ size: CGFloat) -> Font { Font.custom("PinyonScript-Regular", size: size) }
func serifFont(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
    Font.system(size: size, weight: weight, design: .serif)
}

// MARK: - Small decorations

struct DotPaper: View {
    let palette: Palette
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 9
            while y < size.height {
                var x: CGFloat = 9
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(palette.dot))
                    x += 18
                }
                y += 18
            }
        }
        .background(palette.bg)
    }
}

/// A row of half circles. `down` hangs them from the top edge; otherwise they rise from the bottom edge.
struct ScallopRow: View {
    let fill: Color
    let edge: Color
    let diameter: CGFloat
    let down: Bool
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 0
            let cy: CGFloat = down ? 0 : size.height
            while x < size.width + diameter {
                let r = CGRect(x: x, y: cy - diameter / 2, width: diameter, height: diameter)
                ctx.fill(Path(ellipseIn: r), with: .color(fill))
                ctx.stroke(Path(ellipseIn: r), with: .color(edge), lineWidth: 1.2)
                x += diameter
            }
        }
        .frame(height: diameter / 2)
        .clipped()
    }
}

struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
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

struct Flourish: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w, y: h * 0.5))
        p.addCurve(to: CGPoint(x: w * 0.30, y: h * 0.38),
                   control1: CGPoint(x: w * 0.75, y: h * 0.5), control2: CGPoint(x: w * 0.62, y: h * 0.05))
        p.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.50),
                   control1: CGPoint(x: w * 0.16, y: h * 0.55), control2: CGPoint(x: w * 0.34, y: h * 0.72))
        p.move(to: CGPoint(x: w, y: h * 0.5))
        p.addCurve(to: CGPoint(x: w * 0.06, y: h * 0.55),
                   control1: CGPoint(x: w * 0.70, y: h * 0.5), control2: CGPoint(x: w * 0.45, y: h * 1.05))
        return p
    }
}

struct MirrorView: View {
    let palette: Palette
    var width: CGFloat = 104
    var body: some View {
        let h = width * 1.27
        ZStack {
            Ellipse().fill(palette.petal)
            Ellipse()
                .strokeBorder(palette.isDark ? palette.curtain2 : Color.white,
                              style: StrokeStyle(lineWidth: width * 0.07, lineCap: .round, dash: [0.1, width * 0.105]))
            ZStack {
                Ellipse().fill(palette.mirror)
                Ellipse().fill(LinearGradient(colors: [palette.key.opacity(0.28), .clear],
                                              startPoint: .top, endPoint: .center))
                Ellipse().fill(Color.white.opacity(0.7))
                    .frame(width: width * 0.17, height: width * 0.36)
                    .rotationEffect(.degrees(24))
                    .offset(x: -width * 0.17, y: -h * 0.17)
                Keyhole().fill(palette.key).frame(width: width * 0.31, height: width * 0.5)
                Ellipse().strokeBorder(palette.gold, lineWidth: 2)
            }
            .padding(width * 0.125)
        }
        .frame(width: width, height: h)
        .shadow(color: palette.shade, radius: 8, y: 8)
    }
}

struct RoseView: View {
    let palette: Palette
    let size: CGFloat
    var body: some View {
        let lw = max(size * 0.045, 1.2)
        ZStack {
            Circle().fill(palette.petal)
            Circle().trim(from: 0, to: 0.72)
                .stroke(palette.petal2, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(size * 0.12)
            Circle().trim(from: 0, to: 0.72)
                .stroke(palette.petal2, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(size * 0.27)
            Circle().fill(palette.key).frame(width: size * 0.14, height: size * 0.14)
            Circle().trim(from: 0.56, to: 0.70)
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: lw * 1.2, lineCap: .round))
                .padding(size * 0.07)
        }
        .frame(width: size, height: size)
    }
}

struct RoseCluster: View {
    let palette: Palette
    var body: some View {
        ZStack {
            Ellipse().fill(palette.sage).frame(width: 36, height: 17).rotationEffect(.degrees(-25)).offset(x: -34, y: 16)
            Ellipse().fill(palette.sage).frame(width: 36, height: 17).rotationEffect(.degrees(30)).offset(x: 36, y: 20)
            Ellipse().fill(palette.sage).frame(width: 30, height: 15).rotationEffect(.degrees(90)).offset(x: 2, y: 30)
            RoseView(palette: palette, size: 40).offset(x: -24, y: -4)
            RoseView(palette: palette, size: 50).offset(x: 8, y: -10)
            RoseView(palette: palette, size: 34).offset(x: 34, y: 4)
        }
        .frame(width: 104, height: 74)
        .shadow(color: palette.shade, radius: 4, y: 5)
    }
}

struct BowLoops: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 30, y: 16))
        p.addCurve(to: CGPoint(x: 5, y: 14), control1: CGPoint(x: 20, y: 2), control2: CGPoint(x: 4, y: 2))
        p.addCurve(to: CGPoint(x: 30, y: 16), control1: CGPoint(x: 6, y: 24), control2: CGPoint(x: 19, y: 23))
        p.addCurve(to: CGPoint(x: 55, y: 14), control1: CGPoint(x: 40, y: 2), control2: CGPoint(x: 56, y: 2))
        p.addCurve(to: CGPoint(x: 30, y: 16), control1: CGPoint(x: 54, y: 24), control2: CGPoint(x: 41, y: 23))
        return p.applying(CGAffineTransform(scaleX: rect.width / 60, y: rect.height / 42))
    }
}

struct BowTails: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 27, y: 18))
        p.addQuadCurve(to: CGPoint(x: 14, y: 38), control: CGPoint(x: 24, y: 28))
        p.move(to: CGPoint(x: 33, y: 18))
        p.addQuadCurve(to: CGPoint(x: 46, y: 38), control: CGPoint(x: 36, y: 28))
        return p.applying(CGAffineTransform(scaleX: rect.width / 60, y: rect.height / 42))
    }
}

struct BowView: View {
    let palette: Palette
    var width: CGFloat = 52
    var body: some View {
        let h = width * 0.7
        ZStack {
            BowTails().stroke(palette.petal, style: StrokeStyle(lineWidth: width * 0.07, lineCap: .round))
            BowLoops().fill(palette.petal)
            BowLoops().stroke(palette.key, lineWidth: 1.2)
            Circle().fill(palette.key).frame(width: width * 0.16, height: width * 0.16)
                .offset(y: -h * 0.12)
        }
        .frame(width: width, height: h)
        .shadow(color: palette.shade, radius: 3, y: 4)
    }
}

// MARK: - Home screen

struct CurtainHeader: View {
    let palette: Palette
    var onToggleMode: () -> Void
    var body: some View {
        let p = palette
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    var i = 0
                    while x < size.width {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: 26, height: size.height)),
                                 with: .color(i % 2 == 0 ? p.curtain : p.curtain2))
                        x += 26
                        i += 1
                    }
                }
                LinearGradient(colors: [Color.white.opacity(p.isDark ? 0.12 : 0.4), .clear, p.key.opacity(0.14)],
                               startPoint: .top, endPoint: .bottom)
                HLine().stroke(Color.white.opacity(p.isDark ? 0.35 : 0.85),
                               style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(height: 2).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
                Button(action: onToggleMode) {
                    Image(systemName: p.isDark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(p.gold)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(p.surface))
                        .overlay(Circle().stroke(p.petal2, lineWidth: 1))
                        .shadow(color: p.shade, radius: 3, y: 3)
                }
                .padding(.trailing, 12)
            }
            .frame(height: 58)
            ScallopRow(fill: p.curtain, edge: p.petal2, diameter: 26, down: true)
                .shadow(color: p.shade, radius: 3, y: 4)
        }
        .background(p.curtain.ignoresSafeArea(edges: .top))
    }
}

struct ContentsRow: View {
    let palette: Palette
    let numeral: String
    let title: String
    let note: String
    var action: () -> Void
    var body: some View {
        let p = palette
        Button(action: action) {
            HStack(spacing: 10) {
                Text(numeral)
                    .font(serifFont(14, .semibold))
                    .foregroundColor(p.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(p.petal.opacity(0.3)))
                    .overlay(Circle().stroke(p.petal2, lineWidth: 1))
                Text(title).font(serifFont(20, .semibold)).foregroundColor(p.text).lineLimit(1)
                HLine().stroke(p.line, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 6]))
                    .frame(height: 2).offset(y: 6)
                Text(note).font(serifFont(14).italic()).foregroundColor(p.subtext).lineLimit(1)
            }
            .frame(height: 52)
        }
    }
}

struct ContentsCard: View {
    let palette: Palette
    var onOpen: (String) -> Void
    var body: some View {
        let p = palette
        VStack(spacing: 0) {
            ScallopRow(fill: p.surface, edge: p.line, diameter: 16, down: false)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Rectangle().fill(p.gold).frame(height: 1)
                    Text("CONTENTS").font(serifFont(13, .semibold)).tracking(4)
                        .foregroundColor(p.isDark ? p.gold : p.accent)
                    Rectangle().fill(p.gold).frame(height: 1)
                }
                .padding(.bottom, 2)
                ContentsRow(palette: p, numeral: "I", title: "Home", note: "the front page") { onOpen("") }
                Rectangle().fill(p.line.opacity(0.5)).frame(height: 1)
                ContentsRow(palette: p, numeral: "II", title: "Subscriptions", note: "new chapters") { onOpen("feed/subscriptions") }
                Rectangle().fill(p.line.opacity(0.5)).frame(height: 1)
                ContentsRow(palette: p, numeral: "III", title: "Library", note: "your shelf") { onOpen("feed/library") }
                Rectangle().fill(p.line.opacity(0.5)).frame(height: 1)
                ContentsRow(palette: p, numeral: "IV", title: "History", note: "pages you've read") { onOpen("feed/history") }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(p.surface)
            .overlay(Rectangle().stroke(p.line, lineWidth: 1))
        }
        .shadow(color: p.shade, radius: 10, y: 12)
    }
}

struct HomeView: View {
    let palette: Palette
    var onSearch: (String) -> Void
    var onOpen: (String) -> Void
    var onToggleMode: () -> Void

    @State private var query = ""
    @State private var twinkle = false

    var body: some View {
        let p = palette
        ZStack {
            DotPaper(palette: p).ignoresSafeArea()
            VStack(spacing: 0) {
                CurtainHeader(palette: p, onToggleMode: onToggleMode)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        emblemRow
                        Text("Once upon a time\u{2026}")
                            .font(scriptFont(44))
                            .foregroundColor(p.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .shadow(color: p.shade.opacity(0.6), radius: 4, y: 3)
                            .padding(.top, 4)
                        Text("WHAT STORY SHALL WE PLAY?")
                            .font(serifFont(12))
                            .tracking(3)
                            .foregroundColor(p.subtext)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        searchField.padding(.top, 18)
                        ContentsCard(palette: p, onOpen: onOpen)
                            .padding(.top, 26)
                            .overlay(RoseCluster(palette: p).offset(x: 26, y: 46), alignment: .bottomTrailing)
                        BowView(palette: p).padding(.top, 54)
                        Text("NightPlay")
                            .font(scriptFont(30))
                            .foregroundColor(p.accent)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { twinkle = true }
        }
    }

    private var emblemRow: some View {
        let p = palette
        return HStack(spacing: 4) {
            Flourish().stroke(p.gold, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 84, height: 56)
                .overlay(sparkle(16, early: true).offset(x: -26, y: -24))
            MirrorView(palette: p)
            Flourish().stroke(p.gold, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 84, height: 56)
                .scaleEffect(x: -1, y: 1)
                .overlay(sparkle(18, early: false).offset(x: 26, y: -26))
        }
        .padding(.top, 6)
    }

    private var searchField: some View {
        let p = palette
        return HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(p.gold)
            TextField("Search for a video or playlist", text: $query)
                .font(serifFont(17).italic())
                .foregroundColor(p.text)
                .tint(p.accent)
                .submitLabel(.search)
                .autocorrectionDisabled(true)
                .onSubmit {
                    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !q.isEmpty { onSearch(q) }
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Capsule().fill(p.surface))
        .overlay(Capsule().stroke(p.petal2, lineWidth: 1.5))
        .shadow(color: p.shade.opacity(0.8), radius: 6, y: 6)
    }

    private func sparkle(_ size: CGFloat, early: Bool) -> some View {
        let bright = early ? twinkle : !twinkle
        return Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundColor(palette.gold)
            .opacity(bright ? 1.0 : 0.3)
            .scaleEffect(bright ? 1.1 : 0.8)
    }
}

// MARK: - Intro

/// Plays a video named intro.mp4 if one is bundled with the app; otherwise plays the drawn animation.
struct IntroView: View {
    let palette: Palette
    var onDone: () -> Void

    @State private var falling = false
    @State private var wipe: CGFloat = 0
    @State private var wipeOpacity: Double = 1
    @State private var sceneTwo = false
    @State private var emblem: CGFloat = 0.001
    @State private var field: CGFloat = 280
    @State private var finale = false
    @State private var word = false
    @State private var finished = false

    private var videoURL: URL? { Bundle.main.url(forResource: "intro", withExtension: "mp4") }

    var body: some View {
        ZStack {
            if let url = videoURL {
                Color.black.ignoresSafeArea()
                IntroVideo(url: url) { showFinale(after: 0) }.ignoresSafeArea()
            } else {
                drawnScene
            }
            if finale {
                ZStack {
                    Color(hex: "#FBF6EE").ignoresSafeArea()
                    VStack(spacing: 6) {
                        Text("NightPlay").font(scriptFont(64)).foregroundColor(Color(hex: "#8E3B5A"))
                        Text("ONCE UPON A TIME").font(serifFont(13)).tracking(4).foregroundColor(Color(hex: "#7A5560"))
                    }
                    .opacity(word ? 1 : 0)
                    .offset(y: word ? 0 : 14)
                }
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear { if videoURL == nil { runDrawn() } }
    }

    private var drawnScene: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Color(hex: "#DCE6F7"), Color(hex: "#F6DCE2"), Color(hex: "#FBF6EE")],
                               startPoint: .top, endPoint: .bottom)
                Ellipse().fill(Color.white.opacity(0.75)).frame(width: 260, height: 80).blur(radius: 14)
                    .position(x: w * 0.25, y: h * 0.16)
                Ellipse().fill(Color.white.opacity(0.65)).frame(width: 240, height: 70).blur(radius: 16)
                    .position(x: w * 0.8, y: h * 0.3)
                if !sceneTwo {
                    ForEach(0..<12, id: \.self) { i in petal(i, w: w, h: h) }
                    ForEach(0..<8, id: \.self) { i in pearl(i, w: w, h: h) }
                } else {
                    ForEach(0..<16, id: \.self) { i in
                        RoseView(palette: Palette.light, size: CGFloat(44 + (i * 17) % 40))
                            .position(x: w * CGFloat(i) / 15, y: h - CGFloat(30 + (i * 29) % 90))
                            .offset(y: field)
                    }
                    MirrorView(palette: Palette.light, width: 160)
                        .scaleEffect(emblem)
                        .position(x: w / 2, y: h * 0.42)
                }
                Ellipse()
                    .fill(LinearGradient(colors: [Color(hex: "#FBE3EA"), Color(hex: "#E9A9B9"), Color(hex: "#C97A90")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: h * 1.8, height: h * 1.4)
                    .rotationEffect(.degrees(-14))
                    .scaleEffect(wipe)
                    .opacity(wipeOpacity)
                    .position(x: w / 2, y: h / 2)
            }
        }
        .ignoresSafeArea()
    }

    private func petal(_ i: Int, w: CGFloat, h: CGFloat) -> some View {
        let size = CGFloat(14 + (i * 7) % 14)
        let x = w * CGFloat((i * 37) % 100) / 100
        let speed = 2.6 + Double(i % 4) * 0.5
        return Ellipse()
            .fill(LinearGradient(colors: [Color(hex: "#F7CBD6"), Color(hex: "#C97A90")],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size * 0.62)
            .rotationEffect(.degrees(falling ? 420 : Double(i * 30)))
            .position(x: x + (falling ? 60 : 0), y: falling ? h + 40 : -40 - CGFloat(i * 46))
            .animation(.linear(duration: speed).repeatForever(autoreverses: false), value: falling)
    }

    private func pearl(_ i: Int, w: CGFloat, h: CGFloat) -> some View {
        let size = CGFloat(20 + (i * 13) % 50)
        let x = w * CGFloat((i * 53 + 11) % 100) / 100
        let speed = 3.4 + Double(i % 3) * 0.7
        return Circle()
            .fill(RadialGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.35), Color(hex: "#C97A90").opacity(0.35)],
                                 center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: size * 0.7))
            .frame(width: size, height: size)
            .position(x: x, y: falling ? -80 : h + 60 + CGFloat(i * 40))
            .animation(.easeIn(duration: speed).repeatForever(autoreverses: false), value: falling)
    }

    private func runDrawn() {
        falling = true
        after(1.5) { withAnimation(.easeInOut(duration: 0.55)) { wipe = 1 } }
        after(2.1) {
            sceneTwo = true
            withAnimation(.easeOut(duration: 0.45)) { wipeOpacity = 0 }
            withAnimation(.easeOut(duration: 0.7)) { field = 0 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.15)) { emblem = 1 }
        }
        showFinale(after: 3.5)
    }

    private func showFinale(after delay: Double) {
        after(delay) {
            withAnimation(.easeInOut(duration: 0.5)) { finale = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) { word = true }
        }
        after(delay + 1.7) { finish() }
    }

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func finish() {
        if finished { return }
        finished = true
        onDone()
    }
}

struct IntroVideo: UIViewRepresentable {
    let url: URL
    var onEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onEnd: onEnd) }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        let player = AVPlayer(url: url)
        player.isMuted = true
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.observe(player)
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    final class Coordinator {
        let onEnd: () -> Void
        private var token: NSObjectProtocol?
        init(onEnd: @escaping () -> Void) { self.onEnd = onEnd }
        func observe(_ player: AVPlayer) {
            token = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                           object: player.currentItem, queue: .main) { [weak self] _ in
                self?.onEnd()
            }
        }
        deinit { if let token = token { NotificationCenter.default.removeObserver(token) } }
    }
}
