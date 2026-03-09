//
//  KaTeXView.swift
//  Reef
//
//  Renders LaTeX math using WKWebView + bundled KaTeX.
//  Self-sizes via intrinsicContentSize driven by scrollView.contentSize KVO.
//

import SwiftUI
import WebKit

// MARK: - Self-sizing WKWebView

/// WKWebView subclass that reports its content size as intrinsicContentSize,
/// allowing Auto Layout (and SwiftUI) to size it to fit content.
final class SelfSizingWebView: WKWebView {
    private var observation: NSKeyValueObservation?
    var onContentSizeChange: ((CGSize) -> Void)?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        observation = scrollView.observe(\.contentSize, options: .new) { [weak self] _, change in
            guard let newSize = change.newValue, newSize.height > 0 else { return }
            DispatchQueue.main.async {
                self?.invalidateIntrinsicContentSize()
                self?.onContentSizeChange?(newSize)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize {
        scrollView.contentSize
    }
}

// MARK: - SwiftUI wrapper

struct KaTeXView: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 13
    var textColor: Color = ReefColors.gray600
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SelfSizingWebView {
        let config = WKWebViewConfiguration()
        config.userContentController = WKUserContentController()

        let webView = SelfSizingWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.underPageBackgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        webView.onContentSizeChange = { size in
            if size.height > 0 {
                self.contentHeight = size.height
            }
        }

        context.coordinator.lastText = text
        loadContent(in: webView)
        return webView
    }

    func updateUIView(_ webView: SelfSizingWebView, context: Context) {
        webView.onContentSizeChange = { size in
            if size.height > 0 {
                self.contentHeight = size.height
            }
        }

        if context.coordinator.lastText != text {
            context.coordinator.lastText = text
            loadContent(in: webView)
        }
    }

    private func loadContent(in webView: WKWebView) {
        guard let katexDir = Bundle.main.url(forResource: "KaTeX", withExtension: nil)
            ?? Bundle.main.resourceURL?.appendingPathComponent("KaTeX")
        else { return }

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

        webView.loadHTMLString(html, baseURL: katexDir)
    }

    private static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // MARK: - Coordinator

    final class Coordinator {
        var lastText: String = ""
    }
}
