"""Generate a sample homework worksheet PDF for testing Mathpix OCR."""

from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas


def create_worksheet(path: str = "data/sample_worksheet.pdf"):
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)

    c = canvas.Canvas(path, pagesize=letter)
    w, h = letter

    # Title
    c.setFont("Helvetica-Bold", 18)
    c.drawCentredString(w / 2, h - 1 * inch, "Algebra II — Homework #7")

    c.setFont("Helvetica", 11)
    c.drawString(1 * inch, h - 1.5 * inch, "Name: _______________________          Date: _______________          Period: ____")

    # Section 1
    y = h - 2.2 * inch
    c.setFont("Helvetica-Bold", 13)
    c.drawString(1 * inch, y, "Part A: Simplify each expression.")
    y -= 0.15 * inch
    c.setFont("Helvetica", 10)
    c.drawString(1 * inch, y, "Show all work. Circle your final answer.")

    problems_a = [
        "1)   3x² + 5x − 2 + (4x² − 3x + 7)",
        "2)   (2x + 3)(x − 5)",
        "3)   (x² − 9) / (x + 3)",
        "4)   √(48) + 3√(12) − 2√(27)",
    ]

    y -= 0.45 * inch
    c.setFont("Courier", 12)
    for p in problems_a:
        c.drawString(1.2 * inch, y, p)
        y -= 0.7 * inch

    # Section 2
    y -= 0.3 * inch
    c.setFont("Helvetica-Bold", 13)
    c.drawString(1 * inch, y, "Part B: Solve for x.")

    problems_b = [
        "5)   2x² − 8 = 0",
        "6)   3(x − 4) + 2 = 5x − 10",
        "7)   x² + 6x + 9 = 0",
        "8)   |2x − 5| = 11",
    ]

    y -= 0.5 * inch
    c.setFont("Courier", 12)
    for p in problems_b:
        c.drawString(1.2 * inch, y, p)
        y -= 0.7 * inch

    # Section 3
    y -= 0.3 * inch
    c.setFont("Helvetica-Bold", 13)
    c.drawString(1 * inch, y, "Part C: Word Problems")

    y -= 0.35 * inch
    c.setFont("Helvetica", 11)
    lines = [
        "9)  A ball is thrown upward from the ground with an initial velocity of 64 ft/s.",
        "     Its height after t seconds is given by  h(t) = −16t² + 64t.",
        "     a) What is the maximum height reached by the ball?",
        "     b) When does the ball return to the ground?",
    ]
    for line in lines:
        c.drawString(1.2 * inch, y, line)
        y -= 0.28 * inch

    y -= 0.3 * inch
    lines2 = [
        "10) The sum of two numbers is 20. The sum of their squares is 232.",
        "     Find the two numbers. (Set up and solve a system of equations.)",
    ]
    for line in lines2:
        c.drawString(1.2 * inch, y, line)
        y -= 0.28 * inch

    c.save()
    print(f"Created: {path}")


if __name__ == "__main__":
    create_worksheet()
