"""Extract question part regions from compiled PDFs using PyMuPDF.

After compiling a question's LaTeX to PDF, this module finds the bold
part labels (a), (b), etc. and returns their y-coordinates so the iOS
app can determine which subproblem a user's strokes fall within.
"""

from __future__ import annotations

import re

import fitz  # PyMuPDF

# Bold flag in PyMuPDF span flags (bit 4)
_BOLD_FLAG = 1 << 4

# Part labels rendered by question_to_latex.py always look like "(label)"
_LABEL_RE = re.compile(r"^\(([^)]+)\)")

# Maximum x-position for a part label (left margin area).
# Top-level parts are at ~72pt, nested parts indented to ~90pt.
_MAX_LABEL_X = 120.0


def _collect_expected_labels(parts: list[dict], prefix: str = "") -> list[str]:
    """Walk the parts tree and return dot-notation labels in order.

    Example: parts=[{label:"a", parts:[{label:"i"}, {label:"ii"}]}, {label:"b"}]
    returns ["a", "a.i", "a.ii", "b"]
    """
    labels: list[str] = []
    for part in parts:
        full_label = f"{prefix}.{part['label']}" if prefix else part["label"]
        labels.append(full_label)
        if part.get("parts"):
            labels.extend(_collect_expected_labels(part["parts"], prefix=full_label))
    return labels


def _find_bold_labels(
    page: fitz.Page,
    expected_raw_labels: set[str],
) -> list[tuple[str, float]]:
    """Find bold spans matching expected part labels on a page.

    Returns list of (raw_label, y_position) sorted by y.
    raw_label is the label text as it appears in the PDF (e.g. "a", "ii").
    """
    found: list[tuple[str, float]] = []
    blocks = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]

    for block in blocks:
        if block.get("type") != 0:  # text block
            continue
        for line in block["lines"]:
            for span in line["spans"]:
                if not (span["flags"] & _BOLD_FLAG):
                    continue
                # Check x-position — part labels are near the left margin
                if span["bbox"][0] > _MAX_LABEL_X:
                    continue
                m = _LABEL_RE.match(span["text"].strip())
                if m and m.group(1) in expected_raw_labels:
                    # y_start of the span bbox (top-left origin)
                    found.append((m.group(1), span["bbox"][1]))

    found.sort(key=lambda x: x[1])
    return found


def extract_question_regions(
    pdf_bytes: bytes,
    question_dict: dict,
) -> dict:
    """Extract part regions from a compiled question PDF.

    Args:
        pdf_bytes: Raw PDF bytes of the compiled question.
        question_dict: The structured question dict (Question.model_dump() output).

    Returns:
        {
            "page_heights": [float, ...],
            "regions": [{"label": str|None, "page": int, "y_start": float, "y_end": float}, ...]
        }
    """
    parts = question_dict.get("parts", [])

    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    page_heights = [page.rect.height for page in doc]

    # No parts — single region covering the entire question
    if not parts:
        regions = []
        for page_idx, height in enumerate(page_heights):
            regions.append(
                {
                    "label": None,
                    "page": page_idx,
                    "y_start": 0.0,
                    "y_end": height,
                }
            )
        doc.close()
        return {"page_heights": page_heights, "regions": regions}

    # Build expected labels
    expected_labels = _collect_expected_labels(parts)
    # Map raw label (e.g. "a", "i") to full dot-notation label (e.g. "a", "a.i")
    raw_to_full: dict[str, str] = {}
    for full_label in expected_labels:
        raw = full_label.rsplit(".", 1)[-1]  # "a.i" -> "i", "a" -> "a"
        raw_to_full[raw] = full_label
    expected_raw = set(raw_to_full.keys())

    # Find all labels across all pages
    all_found: list[tuple[str, int, float]] = []  # (full_label, page, y)
    for page_idx in range(len(doc)):
        page = doc[page_idx]
        page_labels = _find_bold_labels(page, expected_raw)
        for raw_label, y in page_labels:
            full_label = raw_to_full.get(raw_label)
            if full_label and full_label in expected_labels:
                all_found.append((full_label, page_idx, y))
                # Remove from expected so duplicate raw labels (e.g. "i" under
                # both "a" and "b") match in document order
                expected_labels.remove(full_label)
                # Re-check what raw labels still map to remaining expected
                raw_to_full_remaining: dict[str, str] = {}
                for fl in expected_labels:
                    r = fl.rsplit(".", 1)[-1]
                    raw_to_full_remaining[r] = fl
                raw_to_full = raw_to_full_remaining
                expected_raw = set(raw_to_full.keys())

    doc.close()

    # Build regions
    regions: list[dict] = []

    if not all_found:
        # Labels not found (e.g. fallback PDF) — return empty regions
        return {"page_heights": page_heights, "regions": []}

    # Stem region: from top of page 0 to first label
    first_label, first_page, first_y = all_found[0]
    if first_page == 0 and first_y > 0:
        regions.append(
            {
                "label": None,
                "page": 0,
                "y_start": 0.0,
                "y_end": first_y,
            }
        )
    elif first_page > 0:
        # Stem spans entire pages before the first label
        for p in range(first_page):
            regions.append(
                {
                    "label": None,
                    "page": p,
                    "y_start": 0.0,
                    "y_end": page_heights[p],
                }
            )
        regions.append(
            {
                "label": None,
                "page": first_page,
                "y_start": 0.0,
                "y_end": first_y,
            }
        )

    # Part regions
    for i, (label, page, y) in enumerate(all_found):
        if i + 1 < len(all_found):
            next_label, next_page, next_y = all_found[i + 1]
            if next_page == page:
                # Same page — region ends at next label
                regions.append(
                    {
                        "label": label,
                        "page": page,
                        "y_start": y,
                        "y_end": next_y,
                    }
                )
            else:
                # Part spans to end of current page
                regions.append(
                    {
                        "label": label,
                        "page": page,
                        "y_start": y,
                        "y_end": page_heights[page],
                    }
                )
                # Full intermediate pages
                for p in range(page + 1, next_page):
                    regions.append(
                        {
                            "label": label,
                            "page": p,
                            "y_start": 0.0,
                            "y_end": page_heights[p],
                        }
                    )
                # Continues on next label's page up to that label
                regions.append(
                    {
                        "label": label,
                        "page": next_page,
                        "y_start": 0.0,
                        "y_end": next_y,
                    }
                )
        else:
            # Last label — extends to end of its page and any remaining pages
            regions.append(
                {
                    "label": label,
                    "page": page,
                    "y_start": y,
                    "y_end": page_heights[page],
                }
            )
            for p in range(page + 1, len(page_heights)):
                regions.append(
                    {
                        "label": label,
                        "page": p,
                        "y_start": 0.0,
                        "y_end": page_heights[p],
                    }
                )

    return {"page_heights": page_heights, "regions": regions}
