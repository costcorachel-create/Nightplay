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
    @State private var showIntro = true
    @AppStorage("np.loop") private var loop = "off"       // off, list or one
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
                HLine().stroke(p.petal, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [0.1, 9]))
                    .frame(height: 5).padding(.horizontal, 8).padding(.top, 4).background(p.bg)
                HStack {
                    barButton("chevron.left", p) { store.webView.goBack() }
                    Spacer()
                    barButton("chevron.right", p) { store.webView.goForward() }
                    Spacer()
                    barButton("crown.fill", p) { withAnimation { store.showHome = true } }
                    Spacer()
                    barButton("arrow.clockwise", p) { store.webView.reload() }
                    Spacer()
                    barButton(loop == "one" ? "repeat.1" : "repeat", p) { cycleLoop() }
                        .opacity(loop == "off" ? 0.35 : 1.0)
                    Spacer()
                    barButton(p.isDark ? "sun.max.fill" : "moon.fill", p) { toggleMode() }
                }
                .padding(.horizontal, 20)
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

            if showIntro {
                IntroView(palette: p) {
                    withAnimation(.easeInOut(duration: 0.6)) { showIntro = false }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(forcedScheme)
        .onAppear {
            store.applyTheme(palette)
            store.setLoop(loop)
        }
        .onChange(of: isDark) { _ in store.applyTheme(palette) }
    }

    private func toggleMode() { mode = isDark ? "light" : "dark" }

    private func cycleLoop() {
        loop = loop == "off" ? "list" : (loop == "list" ? "one" : "off")
        store.setLoop(loop)
    }

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

final class WebStore: NSObject, ObservableObject, WKUIDelegate, WKScriptMessageHandler {
    @Published var showHome = true
    private var palette = Palette.light
    private var loopMode = "off"
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

      if (window.top !== window) { return; }
      var firstSeen = {};
      try { firstSeen = JSON.parse(sessionStorage.getItem('npFirst') || '{}'); } catch (e) {}
      var params = function () {
        try { return new URLSearchParams(location.search); } catch (e) { return new URLSearchParams(''); }
      };
      setInterval(function () {
        var p = params(), l = p.get('list'), v = p.get('v');
        if (l && v && !firstSeen[l]) {
          firstSeen[l] = v;
          try { sessionStorage.setItem('npFirst', JSON.stringify(firstSeen)); } catch (e) {}
        }
      }, 1500);
      var adShowing = function () { return !!document.querySelector('.ad-showing'); };
      var restart = function (l) {
        var go = function (v) {
          if (!v) { return; }
          try { window.webkit.messageHandlers.np.postMessage('restart'); } catch (e) {}
          location.href = 'https://m.youtube.com/watch?v=' + v + '&list=' + encodeURIComponent(l) + '&index=1';
        };
        fetch('/playlist?list=' + encodeURIComponent(l), { credentials: 'include' })
          .then(function (r) { return r.text(); })
          .then(function (t) {
            var m = t.match(/(?:"|\\x22)videoId(?:"|\\x22):(?:"|\\x22)([\w-]{11})/);
            go(m ? m[1] : firstSeen[l]);
          })
          .catch(function () { go(firstSeen[l]); });
      };
      document.addEventListener('ended', function (e) {
        var v = e.target;
        if (!v || v.tagName !== 'VIDEO' || adShowing()) { return; }
        var mode = window.__npLoop || 'off';
        if (mode === 'one') { v.currentTime = 0; v.play(); return; }
        if (mode !== 'list') { return; }
        var p = params(), l = p.get('list'), id = p.get('v');
        if (!l) { return; }
        setTimeout(function () {
          if ((window.__npLoop || 'off') !== 'list') { return; }
          var c = params(), now = document.querySelector('video');
          var movedOnInList = c.get('list') === l && c.get('v') !== id;
          var stillPlaying = c.get('v') === id && now && !now.paused && !now.ended;
          if (movedOnInList || stillPlaying) { return; }
          restart(l);
        }, 3500);
      }, true);
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
        webView.configuration.userContentController.add(self, name: "np")
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
        palette = p
        installScripts()
        webView.overrideUserInterfaceStyle = p.isDark ? .dark : .light
        webView.backgroundColor = UIColor(p.bg)
        webView.scrollView.backgroundColor = UIColor(p.bg)
        webView.evaluateJavaScript(WebStore.themeScript(p), completionHandler: nil)
    }

    /// "off", "list" (repeat the whole playlist) or "one" (repeat the current video).
    func setLoop(_ mode: String) {
        loopMode = mode
        installScripts()
        webView.evaluateJavaScript("window.__npLoop = '\(mode)';", completionHandler: nil)
    }

    private func installScripts() {
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(source: "window.__npLoop = '\(loopMode)';", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: WebStore.script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        ucc.addUserScript(WKUserScript(source: WebStore.themeScript(palette), injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }

    // The page says it is reloading to restart a playlist: keep the app awake and press play once it loads.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard (message.body as? String) == "restart" else { return }
        keepAlive(seconds: 20, playAt: [2.0, 4.0, 6.0, 9.0, 13.0],
                  js: "(function(){var v=document.querySelector('video'); if(v&&v.paused){v.play();}})();")
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
        keepAlive(seconds: 3, playAt: [0.3, 1.0, 2.0], js: "window.__npResume && window.__npResume();")
    }

    private func keepAlive(seconds: Double, playAt delays: [Double], js: String) {
        var task: UIBackgroundTaskIdentifier = .invalid
        task = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(task)
            task = .invalid
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
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
