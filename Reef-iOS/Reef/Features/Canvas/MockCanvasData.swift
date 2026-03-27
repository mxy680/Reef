import PDFKit
import UIKit

enum MockCanvasData {
    /// Blank US Letter PDF.
    static func blankPDF(pageCount: Int = 3) -> PDFDocument {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let data = renderer.pdfData { ctx in
            for _ in 0..<pageCount {
                ctx.beginPage()
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            }
        }

        return PDFDocument(data: data) ?? PDFDocument()
    }

    /// Single-page PDF with a question rendered at the top.
    static func demoPDF(question: String) -> PDFDocument {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

            // "Q1." label
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            let label = "Q1."
            label.draw(at: CGPoint(x: margin, y: margin), withAttributes: labelAttrs)

            // Question text
            let questionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.black,
            ]
            let textRect = CGRect(x: margin + 30, y: margin, width: pageWidth - 2 * margin - 30, height: 200)
            question.draw(in: textRect, withAttributes: questionAttrs)
        }

        return PDFDocument(data: data) ?? PDFDocument()
    }

    /// Mock question label for the info strip.
    static let questionLabel = "Q1a"

    /// Mock tutor steps for tutor mode preview.
    static let tutorSteps: [MockTutorStep] = [
        MockTutorStep(
            instruction: "Start by identifying the given values in the problem.",
            hint: "Look for numbers and units mentioned in the question.",
            answer: "Given: m = 5 kg, v = 10 m/s"
        ),
        MockTutorStep(
            instruction: "Apply the kinetic energy formula.",
            hint: "KE = (1/2)mv^2",
            answer: "KE = (1/2)(5)(10)^2 = 250 J"
        ),
        MockTutorStep(
            instruction: "State your final answer with proper units.",
            hint: "Include the SI unit for energy.",
            answer: "The kinetic energy is 250 Joules."
        ),
    ]
}

struct MockTutorStep {
    let instruction: String
    let hint: String
    let answer: String
}
