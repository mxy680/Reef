//
//  RenderedLatexImage.swift
//  Reef
//
//  Displays a server-rendered LaTeX image from POST /render-latex.
//  Falls back to plain Text for non-LaTeX strings.
//

import SwiftUI

struct RenderedLatexImage: View {
    let text: String
    var fontSize: CGFloat = 18
    var maxWidth: Int = 236
    var maxHeight: CGFloat = 300

    private static let cache = NSCache<NSString, UIImage>()

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: CGFloat(maxWidth), maxHeight: maxHeight, alignment: .topLeading)
            } else if loadFailed {
                // Fallback to plain text on error
                Text(text)
                    .font(.system(size: fontSize - 1, weight: .medium))
                    .foregroundColor(ReefColors.gray600)
            } else {
                // Loading or initial state
                ProgressView()
                    .frame(height: 30)
            }
        }
        .onAppear {
            Task { await loadImage() }
        }
    }

    private func loadImage() async {
        guard !text.isEmpty else { return }

        let cacheKey = "\(text)-\(fontSize)-\(maxWidth)" as NSString
        if let cached = Self.cache.object(forKey: cacheKey) {
            image = cached
            return
        }

        isLoading = true
        loadFailed = false
        image = nil

        do {
            let rendered = try await ReefAPI.shared.renderLatex(
                text: text,
                fontSize: fontSize,
                maxWidth: maxWidth
            )
            image = rendered
            Self.cache.setObject(rendered, forKey: cacheKey)
        } catch {
            print("[RenderedLatexImage] Failed: \(error)")
            loadFailed = true
        }
        isLoading = false
    }
}
