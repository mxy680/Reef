//
//  KaTeXView.swift
//  Reef
//
//  Renders LaTeX math using WKWebView + bundled KaTeX.
//  Reports content height via KVO on scrollView.contentSize.
//  Defers HTML loading until SwiftUI assigns a real frame width.
//  Uses loadFileURL for local file access (loadHTMLString can't load local JS/CSS).
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

        // Observe scrollView.contentSize for reliable height updates
        context.coordinator.observeContentSize(of: webView)

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

        if viewWidth > 0 && !context.coordinator.hasLoaded {
            context.coordinator.hasLoaded = true
            context.coordinator.lastText = text
            loadContent(in: webView)
        } else if viewWidth == 0 && !context.coordinator.hasLoaded {
            // Frame not assigned yet — retry after UIKit layout pass.
            DispatchQueue.main.async { [text] in
                guard !context.coordinator.hasLoaded, webView.frame.width > 0 else { return }
                context.coordinator.hasLoaded = true
                context.coordinator.lastText = text
                self.loadContent(in: webView)
            }
        }

        if context.coordinator.hasLoaded && context.coordinator.lastText != text {
            context.coordinator.lastText = text
            loadContent(in: webView)
        }

        webView.scrollView.isScrollEnabled = contentHeight >= maxHeight
    }

    private func loadContent(in webView: WKWebView) {
        guard let bundleURL = Bundle.main.resourceURL else { return }
        let cssURL = bundleURL.appendingPathComponent("katex.min.css").absoluteString
        let jsURL = bundleURL.appendingPathComponent("katex.min.js").absoluteString
        let arURL = bundleURL.appendingPathComponent("auto-render.min.js").absoluteString

        let hexColor = Self.hexString(from: textColor)
        let jsonData = try? JSONEncoder().encode(text)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="\(cssURL)">
        <script src="\(jsURL)"></script>
        <script src="\(arURL)"></script>
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

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let tempHTML = cacheDir.appendingPathComponent("katex_render.html")
        try? html.write(to: tempHTML, atomically: true, encoding: .utf8)

        webView.loadFileURL(tempHTML, allowingReadAccessTo: URL(fileURLWithPath: "/"))
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
        private var contentSizeObservation: NSKeyValueObservation?

        func observeContentSize(of webView: WKWebView) {
            contentSizeObservation = webView.scrollView.observe(
                \.contentSize, options: [.new]
            ) { [weak self] scrollView, _ in
                MainActor.assumeIsolated {
                    let height = scrollView.contentSize.height
                    if height > 0 {
                        self?.onHeight?(height)
                    }
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Height is handled by KVO on scrollView.contentSize
        }

        deinit {
            contentSizeObservation?.invalidate()
        }
    }
}
