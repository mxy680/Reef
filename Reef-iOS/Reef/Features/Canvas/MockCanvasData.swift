import PDFKit
import UIKit

enum MockCanvasData {
    /// 3-page blank US Letter PDF for static preview.
    static func blankPDF(pageCount: Int = 3) -> PDFDocument {
        let pageWidth: CGFloat = 612  // US Letter
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
