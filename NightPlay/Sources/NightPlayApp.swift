import SwiftUI
import WebKit
import AVFoundation
import UIKit

@main
struct NightPlayApp: App {
    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @StateObject private var store = WebStore()
    @AppStorage("np.mode") private var mode = "system"   // system, light or dark
    @Environment(\.colorScheme) private var systemScheme

    private var isDark: Bool { mode == "dark" || (mode == "system" && systemScheme == .dark) }
    private var palette: Palette { isDark ? Palette.dark : Palette.light }
    private var forcedScheme: ColorScheme? {
        if mode == "system" { return nil }
        return mode == "dark" ? .dark : .light
    }

    var body: some View {
        let p = palette
        ZStack {
            VStack(spacing: 0) {
                WebContainer(webView: store.webView)
                Rectangle().fill(p.gold).frame(height: 1.5)
                HStack {
                    barButton("chevron.left", p) { store.webView.goBack() }
                    Spacer()
                    barButton("chevron.right", p) { store.webView.goForward() }
                    Spacer()
                    barButton("crown.fill", p) { withAnimation { store.showHome = true } }
                    Spacer()
                    barButton("arrow.clockwise", p) { store.webView.reload() }
                    Spacer()
                    barButton(p.isDark ? "sun.max.fill" : "moon.stars.fill", p) { toggleMode() }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 11)
                .background(p.bg)
            }
            .background(p.bg.ignoresSafeArea())

            if store.showHome {
                HomeView(palette: p,
                         onSearch: { store.search($0) },
                         onOpen: { store.open($0) },
                         onToggleMode: toggleMode)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(forcedScheme)
        .onAppear { store.applyTheme(palette) }
        .onChange(of: isDark) { _ in store.applyTheme(palette) }
    }

    private func toggleMode() { mode = isDark ? "light" : "dark" }

    private func barButton(_ symbol: String, _ p: Palette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(p.accent)
        }
    }
}

struct WebContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

final class WebStore: NSObject, ObservableObject, WKUIDelegate {
    @Published var showHome = true
    let webView: WKWebView
    private let home = URL(string: "https://m.youtube.com")!
    private var observers: [NSObjectProtocol] = []

    // Keeps the page believing it is always visible, and gives the app two hooks:
    // __npMark (remember whether a video was playing) and __npResume (start it again).
    private static let script = #"""
    (function () {
      var def = function (o, p, v) {
        try { Object.defineProperty(o, p, { get: function () { return v; }, configurable: true }); } catch (e) {}
      };
      def(document, 'hidden', false);
      def(document, 'webkitHidden', false);
      def(document, 'visibilityState', 'visible');
      def(document, 'webkitVisibilityState', 'visible');
      document.hasFocus = function () { return true; };
      var stop = function (e) { e.stopImmediatePropagation(); };
      ['visibilitychange', 'webkitvisibilitychange'].forEach(function (t) {
        document.addEventListener(t, stop, true);
      });
      ['pagehide', 'blur'].forEach(function (t) {
        window.addEventListener(t, function (e) {
          if (e.target === window || e.target === document) { stop(e); }
        }, true);
      });
      var wasPlaying = false;
      window.__npMark = function () {
        var v = document.querySelector('video');
        wasPlaying = !!(v && !v.paused && !v.ended);
      };
      window.__npResume = function () {
        var v = document.querySelector('video');
        if (wasPlaying && v && v.paused) { v.play(); }
      };
    })();
    """#

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.addUserScript(
            WKUserScript(source: WebStore.script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.uiDelegate = self
        // Present as Safari so Google sign-in and the normal mobile site work.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        goHome()

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.webView.evaluateJavaScript("window.__npMark && window.__npMark();", completionHandler: nil)
        })
        observers.append(nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.resumeInBackground()
        })
    }

    func goHome() { webView.load(URLRequest(url: home)) }

    /// Opens a YouTube section ("" is the YouTube home feed) and hides the themed home screen.
    func open(_ path: String) {
        if !path.isEmpty, let url = URL(string: "https://m.youtube.com/" + path) {
            webView.load(URLRequest(url: url))
        } else if path.isEmpty, webView.url?.path != "/" {
            goHome()
        }
        withAnimation { showHome = false }
    }

    func search(_ query: String) {
        var parts = URLComponents(string: "https://m.youtube.com/results")!
        parts.queryItems = [URLQueryItem(name: "search_query", value: query)]
        if let url = parts.url { webView.load(URLRequest(url: url)) }
        withAnimation { showHome = false }
    }

    /// Recolors the YouTube pages to match the app, now and on every later page load.
    func applyTheme(_ p: Palette) {
        let js = WebStore.themeScript(p)
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(source: WebStore.script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView.overrideUserInterfaceStyle = p.isDark ? .dark : .light
        webView.backgroundColor = UIColor(p.bg)
        webView.scrollView.backgroundColor = UIColor(p.bg)
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private static func themeScript(_ p: Palette) -> String {
        let css = """
        :root, html, html[dark], [dark] {
          --yt-spec-base-background: \(p.bgHex) !important;
          --yt-spec-raised-background: \(p.surfaceHex) !important;
          --yt-spec-menu-background: \(p.surfaceHex) !important;
          --yt-spec-general-background-a: \(p.bgHex) !important;
          --yt-spec-general-background-b: \(p.bgHex) !important;
          --yt-spec-general-background-c: \(p.surfaceHex) !important;
          --yt-spec-brand-background-solid: \(p.bgHex) !important;
          --yt-spec-brand-background-primary: \(p.bgHex) !important;
          --yt-spec-brand-background-secondary: \(p.surfaceHex) !important;
          --yt-spec-text-primary: \(p.textHex) !important;
          --yt-spec-text-secondary: \(p.subtextHex) !important;
          --yt-spec-icon-active-other: \(p.textHex) !important;
          --yt-spec-icon-inactive: \(p.textHex) !important;
          --yt-spec-call-to-action: \(p.accentHex) !important;
          --yt-spec-themed-blue: \(p.accentHex) !important;
          --yt-spec-static-brand-red: \(p.accentHex) !important;
          --yt-spec-badge-chip-background: \(p.surfaceHex) !important;
          --yt-spec-additive-background: \(p.surfaceHex) !important;
          --yt-spec-10-percent-layer: \(p.lineCSS) !important;
          --yt-spec-outline: \(p.lineCSS) !important;
          accent-color: \(p.accentHex);
        }
        html, body, ytm-app, ytm-mobile-topbar-renderer, ytm-pivot-bar-renderer,
        ytm-browse, ytm-search, ytm-watch, ytm-single-column-watch-next-results-renderer,
        .mobile-topbar-header, .pivot-bar-item-tab {
          background-color: \(p.bgHex) !important;
        }
        body, ytm-app {
          color: \(p.textHex) !important;
          font-family: Georgia, 'Times New Roman', serif !important;
        }
        a { color: inherit; }
        """
        return """
        (function () {
          var css = `\(css)`;
          var root = document.documentElement;
          if (!root) { return; }
          if (\(p.isDark ? "true" : "false")) { root.setAttribute('dark', ''); } else { root.removeAttribute('dark'); }
          var s = document.getElementById('np-theme');
          if (!s) { s = document.createElement('style'); s.id = 'np-theme'; (document.head || root).appendChild(s); }
          s.textContent = css;
        })();
        """
    }

    // iOS pauses web video when the app leaves the screen; nudge it back on.
    private func resumeInBackground() {
        var task: UIBackgroundTaskIdentifier = .invalid
        task = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(task)
            task = .invalid
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        for delay in [0.3, 1.0, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.webView.evaluateJavaScript("window.__npResume && window.__npResume();", completionHandler: nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if task != .invalid {
                UIApplication.shared.endBackgroundTask(task)
                task = .invalid
            }
        }
    }

    // Open "new window" links in the same view instead of dropping them.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}
