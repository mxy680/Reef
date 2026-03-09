//
//  KaTeXView.swift
//  Reef
//
//  Renders LaTeX math using WKWebView + bundled KaTeX.
//  Reports intrinsic content height; scrolling is disabled (parent owns scroll).
//

import SwiftUI
import WebKit

struct KaTeXView: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 13
    var textColor: Color = ReefColors.gray600
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userController = WKUserContentController()
        userController.add(context.coordinator, name: "sizeNotifier")
        config.userContentController = userController

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 260, height: 400), configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.alpha = 0

        context.coordinator.lastText = text
        context.coordinator.onHeight = { [weak webView] height in
            self.contentHeight = height
            UIView.animate(withDuration: 0.15) {
                webView?.alpha = 1
            }
        }
        loadContent(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onHeight = { [weak webView] height in
            self.contentHeight = height
            UIView.animate(withDuration: 0.15) {
                webView?.alpha = 1
            }
        }

        if context.coordinator.lastText != text {
            context.coordinator.lastText = text
            webView.alpha = 0
            loadContent(in: webView)
        }
    }

    private func loadContent(in webView: WKWebView) {
        guard let katexDir = Bundle.main.url(forResource: "KaTeX", withExtension: nil)
            ?? Bundle.main.resourceURL?.appendingPathComponent("KaTeX")
        else { return }

        let hexColor = Self.hexString(from: textColor)

        // JSON-encode the text so it's safely embedded as a JS string literal
        let jsonData = try? JSONEncoder().encode(text)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="katex.min.css">
        <script src="katex.min.js"></script>
        <script src="auto-render.min.js"></script>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: \(fontSize)px;
            color: \(hexColor);
            background: transparent;
            padding: 0;
            line-height: 1.5;
            -webkit-text-size-adjust: none;
            overflow-wrap: break-word;
            word-wrap: break-word;
            white-space: pre-wrap;
          }
          .katex { font-size: 1.1em; }
          .katex-display { margin: 0.5em 0; overflow-x: auto; }
        </style>
        </head>
        <body id="content"></body>
        <script>
          document.getElementById('content').textContent = \(jsonString);
          renderMathInElement(document.body, {
            delimiters: [
              {left: "$$", right: "$$", display: true},
              {left: "$", right: "$", display: false},
              {left: "\\\\[", right: "\\\\]", display: true},
              {left: "\\\\(", right: "\\\\)", display: false}
            ],
            throwOnError: false
          });
          function reportHeight() {
            var h = document.body.scrollHeight;
            if (h > 0) {
              window.webkit.messageHandlers.sizeNotifier.postMessage(h);
            }
          }
          // Report after render and again after fonts load
          setTimeout(reportHeight, 100);
          document.fonts.ready.then(function() { setTimeout(reportHeight, 50); });
        </script>
        </html>
        """

        webView.loadHTMLString(html, baseURL: katexDir)
    }

    private static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastText: String = ""
        var onHeight: ((CGFloat) -> Void)?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let height = message.body as? CGFloat, height > 0 else { return }
            DispatchQueue.main.async { [weak self] in
                self?.onHeight?(height)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Re-measure after navigation completes (fonts may have loaded)
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self?.onHeight?(height)
                    }
                }
            }
        }
    }
}
