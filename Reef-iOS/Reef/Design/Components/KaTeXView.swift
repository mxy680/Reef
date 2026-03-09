//
//  KaTeXView.swift
//  Reef
//
//  Renders LaTeX math using WKWebView + bundled KaTeX.
//  Reports content height after page loads via callAsyncJavaScript.
//  Defers HTML loading until SwiftUI assigns a real frame width.
//

import SwiftUI
import WebKit

struct KaTeXView: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 13
    var textColor: Color = ReefColors.gray600
    var maxHeight: CGFloat = 300
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.underPageBackgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        context.coordinator.maxHeight = maxHeight
        context.coordinator.onHeight = { [weak webView] height in
            MainActor.assumeIsolated {
                self.contentHeight = min(height, self.maxHeight)
                webView?.scrollView.isScrollEnabled = height >= self.maxHeight
            }
        }
        // Do NOT load content here — frame is .zero, HTML would lay out at 0px width.
        // Content is loaded in updateUIView once SwiftUI assigns a real frame.
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.maxHeight = maxHeight
        context.coordinator.onHeight = { [weak webView] height in
            MainActor.assumeIsolated {
                self.contentHeight = min(height, self.maxHeight)
                webView?.scrollView.isScrollEnabled = height >= self.maxHeight
            }
        }

        let viewWidth = webView.frame.width

        // Load content once we have a real width
        if viewWidth > 0 && !context.coordinator.hasLoaded {
            context.coordinator.hasLoaded = true
            context.coordinator.lastText = text
            loadContent(in: webView)
        }

        // Reload if text changed (after initial load)
        if context.coordinator.hasLoaded && context.coordinator.lastText != text {
            context.coordinator.lastText = text
            loadContent(in: webView)
        }

        webView.scrollView.isScrollEnabled = contentHeight >= maxHeight
    }

    private func loadContent(in webView: WKWebView) {
        // KaTeX files are flattened into the bundle root by Xcode's copy phase
        let baseURL: URL? = Bundle.main.resourceURL

        let hexColor = Self.hexString(from: textColor)
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
          html, body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: \(fontSize)px;
            color: \(hexColor);
            background: transparent;
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
        </script>
        </html>
        """

        webView.loadHTMLString(html, baseURL: baseURL)
    }

    private static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastText: String = ""
        var hasLoaded = false
        var onHeight: (@MainActor (CGFloat) -> Void)?
        var maxHeight: CGFloat = 300

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                await self.measureHeight(webView: webView)
            }
        }

        private func measureHeight(webView: WKWebView) async {
            do {
                let js = "await document.fonts.ready; return document.body.scrollHeight;"
                let result = try await webView.callAsyncJavaScript(
                    js, arguments: [:], contentWorld: .page
                )
                if let num = result as? Double, num > 0 {
                    onHeight?(CGFloat(num))
                }
            } catch {
                if let result = try? await webView.evaluateJavaScript("document.body.scrollHeight"),
                   let num = result as? Double, num > 0 {
                    onHeight?(CGFloat(num))
                }
            }
        }
    }
}
