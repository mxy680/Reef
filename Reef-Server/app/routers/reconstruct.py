"""POST /ai/reconstruct — Reconstruct homework PDFs into cleanly typeset LaTeX.

Pipeline:
1. Rasterize PDF at 192 DPI, fire Surya layout detection on Modal GPU
2. Rasterize 288 DPI (overlapped with Surya), annotate pages with numbered boxes
3. Send annotated images to LLM for problem grouping
4. For each crop group (parallelized): extract → compile → visually verify + fix
5. Merge PDFs or return split JSON

Output: merged PDF (default) or split JSON with base64 PDFs + regions.
"""

import asyncio
import base64
import io
import json
import re
import time
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

import fitz  # PyMuPDF
import modal
from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel
from PIL import Image, ImageDraw, ImageFont

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.models import (
    GroupProblemsResponse,
    ProblemGroup,
    Question,
    QuestionBatch,
    VerificationResult,
)
from app.services.latex_compiler import LaTeXCompiler
from app.services.llm_client import LLMClient, LLMResult
from app.services.prompts import (
    EXTRACT_QUESTION_PROMPT,
    GROUP_PROBLEMS_PROMPT,
    LATEX_FIX_PROMPT,
    VISUAL_VERIFY_PROMPT,
)
from app.services.answer_keys import generate_answer_keys
from app.services.cancellation import cancel as cancel_document, cleanup as cancel_cleanup, is_cancelled, register as cancel_register
from app.services.progress import update_document_status, update_progress
from app.services.storage import download_document_pdf, upload_document_pdf
from app.services.question_to_latex import question_to_latex, _sanitize_text
from app.services.region_extractor import extract_question_regions

router = APIRouter()

FIGURE_LABELS = {"Picture", "Figure"}

# LaTeX special characters that must be escaped in literal text (labels, headers)
_LATEX_SPECIAL = str.maketrans({
    "&": r"\&",
    "%": r"\%",
    "#": r"\#",
    "_": r"\_",
})


def _escape_latex_label(text: str) -> str:
    """Escape LaTeX special characters in a problem label/header."""
    return text.translate(_LATEX_SPECIAL)


_INCLUDEGRAPHICS_RE = re.compile(r'\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}')


def _strip_invalid_figures(latex: str, valid_figures: set[str]) -> str:
    """Remove \\includegraphics lines referencing files not in valid_figures."""
    lines = latex.split('\n')
    filtered = []
    for line in lines:
        m = _INCLUDEGRAPHICS_RE.search(line)
        if m and m.group(1) not in valid_figures:
            continue  # drop line with invalid figure reference
        filtered.append(line)
    return '\n'.join(filtered)

# Modal remote reference to the Surya GPU function
SuryaLayout = modal.Cls.from_name("reef-surya", "SuryaLayout")


@dataclass
class LayoutBlock:
    """Local stand-in for a Surya bbox result (deserialized from Modal)."""
    bbox: list[float]
    label: str


@dataclass
class PageLayout:
    """Layout results for one page."""
    bboxes: list[LayoutBlock]


@dataclass
class PipelineCosts:
    """Accumulated cost metrics for a pipeline run."""
    input_tokens: int = 0
    output_tokens: int = 0
    llm_calls: int = 0
    gpu_seconds: float = 0.0
    pipeline_seconds: float = 0.0
    _llm_cost_dollars: float = 0.0  # accumulated LLM cost in dollars

    # GPU pricing (dollars per second)
    _GPU_COST_PER_SECOND: float = 0.000164  # Modal T4

    # Per-model pricing (dollars per token)
    MODEL_RATES: dict = field(default_factory=lambda: {
        "google/gemini-3-flash-preview": (0.50 / 1_000_000, 3.00 / 1_000_000),
        "google/gemini-3.1-pro-preview": (1.25 / 1_000_000, 10.00 / 1_000_000),
    })
    _DEFAULT_RATE: tuple = (0.50 / 1_000_000, 3.00 / 1_000_000)

    def add(self, result: LLMResult, model: str = "") -> None:
        self.input_tokens += result.input_tokens
        self.output_tokens += result.output_tokens
        self.llm_calls += 1
        in_rate, out_rate = self.MODEL_RATES.get(model, self._DEFAULT_RATE)
        self._llm_cost_dollars += (
            result.input_tokens * in_rate + result.output_tokens * out_rate
        )

    @property
    def cost_cents(self) -> int:
        """Total estimated cost in cents (rounded up)."""
        import math
        gpu_cost = self.gpu_seconds * self._GPU_COST_PER_SECOND
        return math.ceil((self._llm_cost_dollars + gpu_cost) * 100)


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def _annotate_page(
    img: Image.Image,
    layout_result: PageLayout,
    start_index: int = 1,
) -> tuple[Image.Image, int]:
    """Annotate a single page image with red numbered bounding boxes.

    Operates at native resolution (no upscaling) to minimize image size
    sent to the LLM, reducing both cost and latency.
    """
    img = img.convert("RGBA")

    overlay = Image.new("RGBA", img.size, (255, 255, 255, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    except Exception:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
        except Exception:
            font = ImageFont.load_default()

    rgb = (220, 53, 69)
    current_index = start_index

    for block in layout_result.bboxes:
        bbox = block.bbox
        x1, y1 = int(bbox[0]), int(bbox[1])
        x2, y2 = int(bbox[2]), int(bbox[3])

        overlay_draw.rectangle([(x1, y1), (x2, y2)], fill=(*rgb, 40))
        draw.rectangle([(x1, y1), (x2, y2)], outline=rgb, width=2)

        label = str(current_index)
        label_y = max(y1 - 22, 3)
        text_bbox = draw.textbbox((x1, label_y), label, font=font)
        padding = 4
        draw.rectangle(
            (text_bbox[0] - padding, text_bbox[1] - padding,
             text_bbox[2] + padding, text_bbox[3] + padding),
            fill=rgb,
        )
        draw.text((x1, label_y), label, fill="white", font=font)
        current_index += 1

    img = Image.alpha_composite(img, overlay)
    return img.convert("RGB"), current_index


def _render_pdf_to_image(pdf_bytes: bytes, dpi: int = 144) -> bytes:
    """Render a compiled PDF to a single JPEG image (stacks pages vertically)."""
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    mat = fitz.Matrix(dpi / 72, dpi / 72)

    page_imgs: list[Image.Image] = []
    for page in doc:
        pix = page.get_pixmap(matrix=mat)
        page_imgs.append(Image.frombytes("RGB", [pix.width, pix.height], pix.samples))
    doc.close()

    if len(page_imgs) == 1:
        composite = page_imgs[0]
    else:
        total_height = sum(img.height for img in page_imgs)
        max_width = max(img.width for img in page_imgs)
        composite = Image.new("RGB", (max_width, total_height), (255, 255, 255))
        y_offset = 0
        for img in page_imgs:
            composite.paste(img, (0, y_offset))
            y_offset += img.height

    buf = io.BytesIO()
    composite.save(buf, format="JPEG", quality=75)
    return buf.getvalue()


def _get_original_crop(
    problem: ProblemGroup,
    bbox_index: dict[int, tuple[int, list[float], str]],
    hires_images: list[Image.Image],
    crop_scale: float,
) -> bytes:
    """Create a composite crop of the original document for a problem's region."""
    page_regions: dict[int, list[list[float]]] = defaultdict(list)
    for idx in problem.annotation_indices:
        if idx not in bbox_index:
            continue
        page_num, bbox, label = bbox_index[idx]
        page_regions[page_num].append(bbox)

    if not page_regions:
        return b""

    crops: list[Image.Image] = []
    for page_num in sorted(page_regions.keys()):
        bboxes = page_regions[page_num]
        hires = hires_images[page_num]

        x1 = max(0, int(min(b[0] for b in bboxes) * crop_scale) - 20)
        y1 = max(0, int(min(b[1] for b in bboxes) * crop_scale) - 20)
        x2 = min(hires.width, int(max(b[2] for b in bboxes) * crop_scale) + 20)
        y2 = min(hires.height, int(max(b[3] for b in bboxes) * crop_scale) + 20)

        if x2 > x1 and y2 > y1:
            crops.append(hires.crop((x1, y1, x2, y2)))

    if not crops:
        return b""

    if len(crops) == 1:
        composite = crops[0]
    else:
        total_height = sum(c.height for c in crops)
        max_width = max(c.width for c in crops)
        composite = Image.new("RGB", (max_width, total_height), (255, 255, 255))
        y_offset = 0
        for crop in crops:
            composite.paste(crop, (0, y_offset))
            y_offset += crop.height

    buf = io.BytesIO()
    composite.save(buf, format="JPEG", quality=75)
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Core pipeline (shared by both endpoints)
# ---------------------------------------------------------------------------


async def _run_pipeline(
    pdf_bytes: bytes,
    document_id: str | None = None,
    debug: bool = False,
    base_name: str = "document",
    costs: PipelineCosts | None = None,
) -> tuple[list[tuple[str, bytes, dict | None]], int, PipelineCosts]:
    """Run the full reconstruction pipeline.

    Returns ``(compiled, page_count, costs)`` where *compiled* is a list of
    ``(label, pdf_bytes, question_dict | None)`` tuples — one per problem.

    Pass a *costs* object to accumulate metrics even if the pipeline raises.
    """
    if costs is None:
        costs = PipelineCosts()
    pipeline_start = time.monotonic()

    async def progress(msg: str | None):
        if document_id:
            await update_progress(document_id, msg)

    data_dir = Path(__file__).parent.parent.parent / "data"

    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    num_pages = len(doc)

    SURYA_DPI = 192
    CROP_DPI = 288
    crop_scale = CROP_DPI / SURYA_DPI
    hires_mat = fitz.Matrix(CROP_DPI / 72, CROP_DPI / 72)

    await progress("Analyzing document layout...")

    # --- Stage 1a: Single-pass rasterization at 288 DPI ---
    hires_images: list[Image.Image] = []
    for page_num in range(num_pages):
        pix = doc[page_num].get_pixmap(matrix=hires_mat)
        hires_images.append(
            Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        )
    doc.close()

    # Downscale to 192 DPI for Surya layout detection
    surya_images: list[Image.Image] = []
    for img in hires_images:
        w, h = int(img.width / crop_scale), int(img.height / crop_scale)
        surya_images.append(img.resize((w, h), Image.LANCZOS))

    # Serialize for Surya
    surya_image_bytes: list[bytes] = []
    for img in surya_images:
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        surya_image_bytes.append(buf.getvalue())

    # --- Stage 1b: Fire Surya (async) ---
    print(f"  [reconstruct] Sending {len(surya_image_bytes)} pages to Modal Surya...")
    surya_cls = SuryaLayout()
    gpu_start = time.monotonic()
    surya_task = asyncio.create_task(
        asyncio.to_thread(surya_cls.detect_layout.remote, surya_image_bytes)
    )

    # --- Stage 1c: Await Surya results ---
    raw_layouts = await surya_task
    costs.gpu_seconds = time.monotonic() - gpu_start

    # Deserialize Modal response into local dataclasses
    layout_results: list[PageLayout] = []
    for page_bboxes in raw_layouts:
        layout_results.append(
            PageLayout(bboxes=[LayoutBlock(**b) for b in page_bboxes])
        )
    print(f"  [reconstruct] Got layout results from Modal")

    # --- Stage 2a: Annotate pages ---
    annotated_pages: list[Image.Image] = []
    current_index = 1
    for img, layout_result in zip(surya_images, layout_results):
        annotated, current_index = _annotate_page(
            img, layout_result, start_index=current_index
        )
        annotated_pages.append(annotated)

    total_annotations = current_index - 1

    page_images: list[bytes] = []
    for page in annotated_pages:
        buf = io.BytesIO()
        page.save(buf, format="JPEG", quality=75)
        page_images.append(buf.getvalue())

    if debug:
        annotations_dir = data_dir / "annotations"
        annotations_dir.mkdir(parents=True, exist_ok=True)
        annotated_pages[0].save(
            annotations_dir / f"{base_name}.pdf",
            "PDF",
            save_all=True,
            append_images=annotated_pages[1:] if len(annotated_pages) > 1 else [],
            resolution=150,
        )

    await progress("Identifying problems...")

    # --- Stage 2b: LLM problem grouping (now non-blocking) ---
    # Single model for all calls — best accuracy, simplest routing
    llm_client = LLMClient(
        api_key=settings.openrouter_api_key,
        model="google/gemini-3-flash-preview",
        base_url="https://openrouter.ai/api/v1",
    )

    prompt = GROUP_PROBLEMS_PROMPT.format(total_annotations=total_annotations)
    group_llm = await asyncio.to_thread(
        llm_client.generate,
        prompt=prompt,
        images=page_images,
        response_schema=GroupProblemsResponse.model_json_schema(),
    )
    costs.add(group_llm, model=llm_client.model)
    group_result = GroupProblemsResponse.model_validate_json(group_llm.content)

    group_result.problems.sort(
        key=lambda p: min(p.annotation_indices) if p.annotation_indices else float("inf")
    )

    if debug:
        labels_dir = data_dir / "labels"
        labels_dir.mkdir(parents=True, exist_ok=True)
        (labels_dir / f"{base_name}.json").write_text(
            group_result.model_dump_json(indent=2)
        )

    # Build bbox index
    bbox_index: dict[int, tuple[int, list[float], str]] = {}
    ann_idx = 1
    for page_num, layout_result in enumerate(layout_results):
        for block in layout_result.bboxes:
            bbox_index[ann_idx] = (page_num, list(block.bbox), block.label)
            ann_idx += 1

    # Rescue orphaned figure annotations
    assigned = set()
    for p in group_result.problems:
        assigned.update(p.annotation_indices)

    for idx, (page_num, bbox, label) in bbox_index.items():
        if idx not in assigned and label in FIGURE_LABELS:
            best_problem = min(
                group_result.problems,
                key=lambda p: min(abs(idx - i) for i in p.annotation_indices),
            )
            best_problem.annotation_indices.append(idx)
            best_problem.annotation_indices.sort()
            assigned.add(idx)
            print(
                f"  [reconstruct] Rescued orphan figure {idx} ({label}) -> {best_problem.label}"
            )

    # Check if page 0 has unassigned annotations (likely general instructions)
    page0_has_instructions = any(
        idx not in assigned and bbox_index[idx][0] == 0
        for idx in bbox_index
    )

    # Prepare original crops for visual verification
    original_crops: dict[str, bytes] = {}
    for problem in group_result.problems:
        original_crops[problem.label] = _get_original_crop(
            problem, bbox_index, hires_images, crop_scale
        )

    # --- Stage 3: Extract + Compile + Verify (pipelined per crop group) ---

    compiler = LaTeXCompiler()

    def _get_extraction_images(problem: ProblemGroup):
        """Get full annotated page images and figure data for a problem."""
        image_data: dict[str, str] = {}
        figure_filenames: list[str] = []
        figure_mappings: list[str] = []
        problem_pages: set[int] = set()

        for idx in problem.annotation_indices:
            if idx not in bbox_index:
                continue
            page_num, bbox, label = bbox_index[idx]
            problem_pages.add(page_num)

            if label in FIGURE_LABELS:
                hires = hires_images[page_num]
                x1 = max(0, int(bbox[0] * crop_scale))
                y1 = max(0, int(bbox[1] * crop_scale))
                x2 = min(hires.width, int(bbox[2] * crop_scale))
                y2 = min(hires.height, int(bbox[3] * crop_scale))
                if x2 > x1 and y2 > y1:
                    buf = io.BytesIO()
                    hires.crop((x1, y1, x2, y2)).save(buf, format="JPEG", quality=90)
                    fname = f"figure_{idx}.jpg"
                    image_data[fname] = base64.b64encode(buf.getvalue()).decode()
                    figure_filenames.append(fname)
                    figure_mappings.append(f"  - Red box #{idx} → {fname}")

        # Include page 0 as context only if it has instructions or problem is nearby
        if problem_pages and 0 not in problem_pages:
            if page0_has_instructions or min(problem_pages) <= 1:
                problem_pages.add(0)

        # Crop tables as images
        for idx, (page_num, bbox, label) in bbox_index.items():
            if page_num in problem_pages and label == "Table":
                hires = hires_images[page_num]
                x1 = max(0, int(bbox[0] * crop_scale))
                y1 = max(0, int(bbox[1] * crop_scale))
                x2 = min(hires.width, int(bbox[2] * crop_scale))
                y2 = min(hires.height, int(bbox[3] * crop_scale))
                if x2 > x1 and y2 > y1:
                    buf = io.BytesIO()
                    hires.crop((x1, y1, x2, y2)).save(buf, format="JPEG", quality=90)
                    fname = f"table_{idx}.jpg"
                    image_data[fname] = base64.b64encode(buf.getvalue()).decode()
                    figure_filenames.append(fname)
                    figure_mappings.append(f"  - Table (Red box #{idx}) → {fname}")

        extraction_images = [page_images[p] for p in sorted(problem_pages)]
        return extraction_images, image_data, figure_filenames, figure_mappings

    MAX_FIX_ATTEMPTS = 3

    def _is_simple_problem(question: Question, latex: str) -> bool:
        """Check if a problem is simple enough to skip visual verification."""
        if question.figures:
            return False
        if len(latex) > 500:
            return False
        for part in question.parts:
            if part.figures or part.parts:  # has figures or nested sub-parts
                return False
        return True

    async def _verify_and_fix(
        label: str,
        latex: str,
        pdf_bytes: bytes,
        original_crop_bytes: bytes,
        image_data: dict[str, str],
    ) -> tuple[str, bytes]:
        """Visually verify compiled PDF against original, retry fixes until they compile."""
        if not original_crop_bytes:
            return latex, pdf_bytes

        reconstruction_image = _render_pdf_to_image(pdf_bytes)

        try:
            verify_prompt = VISUAL_VERIFY_PROMPT.format(latex_body=latex)
            verify_llm = await asyncio.to_thread(
                llm_client.generate,
                prompt=verify_prompt,
                images=[original_crop_bytes, reconstruction_image],
                response_schema=VerificationResult.model_json_schema(),
            )
            costs.add(verify_llm, model=llm_client.model)
            result = VerificationResult.model_validate_json(verify_llm.content)
        except Exception as e:
            print(f"  [verify] {label}: verification call failed — {e}")
            return latex, pdf_bytes

        if not result.needs_fix or not result.fixed_latex.strip():
            print(f"  [verify] {label}: OK")
            return latex, pdf_bytes

        print(f"  [verify] {label}: issues found: {result.issues}")

        # Sanitize fixed_latex: fix JSON escape corruption and strip hallucinated figures
        current_fix = _sanitize_text(result.fixed_latex)
        valid_figs = set(image_data.keys()) if image_data else set()
        current_fix = _strip_invalid_figures(current_fix, valid_figs)
        header = _escape_latex_label(label)

        for attempt in range(1, MAX_FIX_ATTEMPTS + 1):
            try:
                fixed_content = f"\\textbf{{\\large {header}}}\n\n{current_fix}"
                fixed_pdf = await asyncio.to_thread(
                    compiler.compile_latex,
                    fixed_content,
                    image_data=image_data or None,
                )
                suffix = f" (attempt {attempt})" if attempt > 1 else ""
                print(f"  [verify] {label}: fix compiled successfully{suffix}")
                return current_fix, fixed_pdf
            except Exception as e:
                if attempt < MAX_FIX_ATTEMPTS:
                    print(f"  [verify] {label}: fix attempt {attempt} failed — {e}")
                    try:
                        fix_prompt = LATEX_FIX_PROMPT.format(
                            latex_body=current_fix,
                            error_message=str(e)[:2000],
                        )
                        fix_llm = await asyncio.to_thread(
                            llm_client.generate, prompt=fix_prompt
                        )
                        costs.add(fix_llm, model=llm_client.model)
                        current_fix = fix_llm.content
                    except Exception as e2:
                        print(f"  [verify] {label}: LLM fix call failed — {e2}")
                        break
                else:
                    print(
                        f"  [verify] {label}: fix failed after {MAX_FIX_ATTEMPTS} "
                        f"attempts — keeping original"
                    )

        return latex, pdf_bytes

    async def extract_compile_verify(
        problem_num: int,
        problems: list[ProblemGroup],
    ) -> list[tuple[str, bytes, dict | None]]:
        """Extract, compile, and verify all problems in a crop group."""
        extraction_images, image_data, figure_filenames, figure_mappings = (
            _get_extraction_images(problems[0])
        )

        labels_str = ", ".join(p.label for p in problems)
        print(
            f"  [reconstruct] Group [{labels_str}]: {len(extraction_images)} pages "
            f"({len(figure_filenames)} figures)"
        )

        if not extraction_images:
            fallback_pdf = await asyncio.to_thread(
                compiler.compile_latex,
                "\\textit{No regions found for this problem.}",
            )
            return [
                (p.label, fallback_pdf, None)
                for p in problems
            ]

        # --- LLM extraction ---
        extract_prompt = EXTRACT_QUESTION_PROMPT
        if len(problems) == 1:
            extract_prompt += (
                f"\n\n## Target Problem\nExtract ONLY **{problems[0].label}** from the "
                f"annotated page images. The pages show numbered red bounding boxes — "
                f"focus on the content within the relevant boxes. Other content on the "
                f"page is context only."
            )
        else:
            labels = [p.label for p in problems]
            nums = [
                re.findall(r"\d+", l)[0] for l in labels if re.findall(r"\d+", l)
            ]
            extract_prompt += (
                f"\n\n## Multiple Problems — CRITICAL\n"
                f"This image contains {len(labels)} SEPARATE numbered problems. "
                f"Each one MUST be its own top-level Question object in the `questions` array.\n\n"
                f"Problems to extract: {', '.join(labels)}\n"
                f"Expected problem numbers: {', '.join(nums)}\n\n"
                f"Rules:\n"
                f"- Return exactly {len(labels)} Question objects.\n"
                f"- Each Question has its own `number` field matching the problem number.\n"
                f"- Do NOT nest different problem numbers as sub-parts of another question.\n"
                f"- Only use `parts` for actual labeled sub-questions within a single problem."
            )

        if figure_filenames:
            extract_prompt += (
                "\n\nFigure files available for this problem:\n"
                + "\n".join(figure_mappings)
                + "\n\nThese figures were detected adjacent to this problem. Include them "
                "in the `figures` list if the question needs them to be answerable."
            )

        if len(problems) == 1:
            schema = Question.model_json_schema()
        else:
            schema = QuestionBatch.model_json_schema()

        extract_llm = await asyncio.to_thread(
            llm_client.generate,
            prompt=extract_prompt,
            images=extraction_images,
            response_schema=schema,
        )
        costs.add(extract_llm, model=llm_client.model)

        if len(problems) == 1:
            questions = [Question.model_validate_json(extract_llm.content)]
        else:
            batch = QuestionBatch.model_validate_json(extract_llm.content)
            questions = batch.questions

        # Strip hallucinated figure filenames
        valid_figs = set(figure_filenames)
        for q in questions:
            q.figures = [f for f in q.figures if f in valid_figs]
            for part in q.parts:
                part.figures = [f for f in part.figures if f in valid_figs]
                for sub in part.parts:
                    sub.figures = [f for f in sub.figures if f in valid_figs]

        # Match extracted questions to problems by number
        q_by_number: dict[int, list[Question]] = defaultdict(list)
        for q in questions:
            q_by_number[q.number].append(q)

        # --- Compile + verify each problem in this group ---
        out: list[tuple[str, bytes, dict | None]] = []
        for i, problem in enumerate(problems):
            current_num = problem_num + i
            nums = re.findall(r"\d+", problem.label)
            matched = None
            if nums:
                target = int(nums[0])
                candidates = q_by_number.get(target, [])
                if candidates:
                    matched = candidates.pop(0)

            if matched is None:
                for remaining in q_by_number.values():
                    if remaining:
                        matched = remaining.pop(0)
                        break

            if not matched:
                print(f"  [reconstruct] {problem.label}: no matching question in batch")
                fallback_pdf = await asyncio.to_thread(
                    compiler.compile_latex,
                    f"\\textbf{{\\large Problem {current_num}}}\n\n"
                    f"\\textit{{Extraction failed for this problem.}}",
                )
                out.append((problem.label, fallback_pdf, None))
                continue

            latex = question_to_latex(matched)
            question_dict = matched.model_dump()
            header = f"Problem {current_num}"
            print(
                f"  [compile] {problem.label}: {len(latex)} chars, "
                f"images={list(image_data.keys()) or 'none'}"
            )

            # Compile with retry loop
            pdf_result = None
            for attempt in range(1, MAX_FIX_ATTEMPTS + 1):
                try:
                    content = f"\\textbf{{\\large {header}}}\n\n{latex}"
                    pdf_result = await asyncio.to_thread(
                        compiler.compile_latex, content, image_data=image_data or None
                    )
                    if attempt > 1:
                        print(f"  [compile] {problem.label}: FIXED on attempt {attempt}")
                    break
                except Exception as e:
                    if attempt < MAX_FIX_ATTEMPTS:
                        print(f"  [compile] {problem.label}: attempt {attempt} failed — {e}")
                        try:
                            fix_prompt = LATEX_FIX_PROMPT.format(
                                latex_body=latex, error_message=str(e)[:2000]
                            )
                            fix_llm = await asyncio.to_thread(
                                llm_client.generate, prompt=fix_prompt
                            )
                            costs.add(fix_llm, model=llm_client.model)
                            latex = fix_llm.content
                        except Exception as e2:
                            print(f"  [compile] {problem.label}: LLM fix failed — {e2}")
                            break
                    else:
                        print(
                            f"  [compile] {problem.label}: FAILED after "
                            f"{MAX_FIX_ATTEMPTS} attempts — {e}"
                        )

            if pdf_result is None:
                fallback = (
                    f"\\textbf{{\\large {header}}}\n\n"
                    f"\\textit{{LaTeX compilation failed for this problem.}}"
                )
                pdf_result = await asyncio.to_thread(
                    compiler.compile_latex, fallback
                )
                out.append((problem.label, pdf_result, None))
                continue

            # Verify against original (skip for simple problems to save cost)
            if matched and _is_simple_problem(matched, latex):
                print(f"  [verify] {problem.label}: skipped (simple problem)")
            else:
                crop_bytes = original_crops.get(problem.label, b"")
                latex, pdf_result = await _verify_and_fix(
                    problem.label, latex, pdf_result, crop_bytes, image_data
                )

            out.append((problem.label, pdf_result, question_dict))

        return out

    # Group problems by annotation indices
    crop_groups: dict[tuple, list[ProblemGroup]] = defaultdict(list)
    for p in group_result.problems:
        key = tuple(sorted(p.annotation_indices))
        crop_groups[key].append(p)

    await progress(f"Reconstructing {len(group_result.problems)} problems...")

    # Assign problem numbers and launch all groups in parallel
    group_tasks = []
    problem_counter = 1
    for probs in crop_groups.values():
        group_tasks.append(extract_compile_verify(problem_counter, probs))
        problem_counter += len(probs)

    group_results_nested = await asyncio.gather(*group_tasks)

    # Flatten and order by original problem order
    results_by_label: dict[str, tuple] = {}
    for group_list in group_results_nested:
        for r in group_list:
            results_by_label[r[0]] = r
    compiled = [results_by_label[p.label] for p in group_result.problems]

    # Save structured questions
    questions_data = [q for _, _, q in compiled if q is not None]
    if debug and questions_data:
        structured_dir = data_dir / "structured"
        structured_dir.mkdir(parents=True, exist_ok=True)
        (structured_dir / f"{base_name}.json").write_text(
            json.dumps(questions_data, indent=2)
        )

    await progress("Finalizing PDF...")
    await progress(None)  # Clear status message on completion

    costs.pipeline_seconds = time.monotonic() - pipeline_start
    print(
        f"  [reconstruct] Costs: {costs.llm_calls} LLM calls, "
        f"{costs.input_tokens} in / {costs.output_tokens} out tokens, "
        f"{costs.gpu_seconds:.1f}s GPU, {costs.pipeline_seconds:.1f}s total, "
        f"~{costs.cost_cents}¢"
    )

    return compiled, num_pages, costs


# ---------------------------------------------------------------------------
# Background task for iOS document processing
# ---------------------------------------------------------------------------


async def _run_pipeline_for_document(
    user_id: str, document_id: str, costs: PipelineCosts | None = None,
):
    """Download PDF and run the reconstruction pipeline. Returns (compiled, num_pages, costs)."""
    pdf_bytes = await download_document_pdf(user_id, document_id)
    return await _run_pipeline(pdf_bytes, document_id, costs=costs)


PIPELINE_TIMEOUT_SECONDS = 540  # 9 min — leaves 60s buffer before gunicorn's 600s kill

# Strong references for fire-and-forget tasks to prevent GC mid-execution
_background_tasks: set[asyncio.Task] = set()


async def _generate_answer_keys_safe(
    document_id: str, questions: list[tuple[int, dict]],
) -> None:
    """Wrapper that catches all exceptions so fire-and-forget never leaks."""
    try:
        await generate_answer_keys(document_id, questions)
    except Exception as e:
        print(f"  [answer-key] Top-level failure for {document_id}: {e}")


async def _process_document_background(user_id: str, document_id: str):
    """Download PDF, run pipeline, upload output, update document status.

    Supports cancellation via the cancellation registry — a watchdog task
    monitors the cancel event and calls task.cancel() on the pipeline task.
    The entire pipeline is wrapped in a timeout to prevent indefinite hangs.
    """
    cancel_event = cancel_register(document_id)
    # Shared costs object — accumulates even if the pipeline raises partway.
    costs = PipelineCosts()
    try:
        pipeline_task = asyncio.create_task(
            asyncio.wait_for(
                _run_pipeline_for_document(user_id, document_id, costs=costs),
                timeout=PIPELINE_TIMEOUT_SECONDS,
            )
        )

        async def _watchdog():
            await cancel_event.wait()
            pipeline_task.cancel()

        watchdog_task = asyncio.create_task(_watchdog())

        try:
            compiled, num_pages, _costs = await pipeline_task
        finally:
            watchdog_task.cancel()

        # Final check — cancel may have fired between pipeline finishing and here
        if is_cancelled(document_id):
            print(f"  [reconstruct-document] {document_id} cancelled (post-pipeline)")
            return

        # Fire-and-forget answer key generation (runs concurrently with merge/upload)
        answer_questions = [
            (i + 1, q_dict)
            for i, (label, pdf_bytes, q_dict) in enumerate(compiled)
            if q_dict is not None
        ]
        if answer_questions:
            task = asyncio.create_task(
                _generate_answer_keys_safe(document_id, answer_questions)
            )
            _background_tasks.add(task)
            task.add_done_callback(_background_tasks.discard)

        # Merge per-problem PDFs into one, tracking page ranges per question
        merged = fitz.open()
        question_pages: list[list[int]] = []
        running_page = 0
        for label, problem_pdf_bytes, _ in compiled:
            sub_doc = fitz.open(stream=problem_pdf_bytes, filetype="pdf")
            question_pages.append([running_page, running_page + sub_doc.page_count - 1])
            running_page += sub_doc.page_count
            merged.insert_pdf(sub_doc)
            sub_doc.close()
        merged_bytes = merged.tobytes()
        merged.close()

        await upload_document_pdf(user_id, document_id, merged_bytes)
        await update_document_status(
            document_id,
            status="completed",
            page_count=num_pages,
            problem_count=len(compiled),
            question_pages=question_pages,
            status_message=None,
            input_tokens=costs.input_tokens,
            output_tokens=costs.output_tokens,
            llm_calls=costs.llm_calls,
            gpu_seconds=round(costs.gpu_seconds, 2),
            pipeline_seconds=round(costs.pipeline_seconds, 2),
            cost_cents=costs.cost_cents,
        )
    except asyncio.TimeoutError:
        print(f"  [reconstruct-document] {document_id} timed out after {PIPELINE_TIMEOUT_SECONDS}s")
        await update_document_status(
            document_id,
            status="failed",
            error_message=f"Pipeline timed out after {PIPELINE_TIMEOUT_SECONDS}s",
            status_message=None,
            input_tokens=costs.input_tokens,
            output_tokens=costs.output_tokens,
            llm_calls=costs.llm_calls,
            gpu_seconds=round(costs.gpu_seconds, 2),
            cost_cents=costs.cost_cents,
        )
    except asyncio.CancelledError:
        print(f"  [reconstruct-document] {document_id} cancelled")
        return
    except Exception as e:
        if is_cancelled(document_id):
            print(f"  [reconstruct-document] {document_id} cancelled (during error)")
            return
        print(f"  [reconstruct-document] {document_id} failed: {e}")
        await update_document_status(
            document_id,
            status="failed",
            error_message=str(e)[:500],
            status_message=None,
            input_tokens=costs.input_tokens,
            output_tokens=costs.output_tokens,
            llm_calls=costs.llm_calls,
            gpu_seconds=round(costs.gpu_seconds, 2),
            cost_cents=costs.cost_cents,
        )
    finally:
        cancel_cleanup(document_id)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


class ReconstructDocumentRequest(BaseModel):
    document_id: str


@router.post("/ai/reconstruct-document", status_code=202)
async def reconstruct_document(
    req: ReconstructDocumentRequest,
    background_tasks: BackgroundTasks,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Trigger document reconstruction as a background task (used by iOS)."""
    background_tasks.add_task(_process_document_background, user.id, req.document_id)
    return {"status": "accepted", "document_id": req.document_id}


@router.delete("/ai/reconstruct-document/{document_id}")
async def cancel_reconstruction(
    document_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Cancel a running reconstruction task. Idempotent — returns 200 even if no task is running."""
    found = cancel_document(document_id)
    status = "cancelled" if found else "not_found"
    print(f"  [reconstruct-document] cancel {document_id}: {status}")
    return {"status": status, "document_id": document_id}


@router.post("/ai/reconstruct")
async def ai_reconstruct(
    user: AuthenticatedUser = Depends(get_current_user),
    pdf: UploadFile = File(..., description="PDF file to reconstruct"),
    split: bool = Query(default=False, description="Return individual problem PDFs as JSON"),
    debug: bool = Query(default=False, description="Save intermediate files to data/"),
    document_id: str | None = Query(default=None, description="Supabase document ID for progress reporting"),
):
    try:
        pdf_bytes = await pdf.read()
        base_name = Path(pdf.filename).stem if pdf.filename else "document"

        compiled, num_pages, costs = await _run_pipeline(
            pdf_bytes, document_id, debug, base_name
        )

        if split:
            problem_pdfs = []
            for i, (label, pdf_bytes, question_dict) in enumerate(compiled):
                entry = {
                    "number": i + 1,
                    "label": label,
                    "pdf_base64": base64.b64encode(pdf_bytes).decode(),
                }
                if question_dict is not None:
                    region_data = extract_question_regions(pdf_bytes, question_dict)
                    entry["page_heights"] = region_data["page_heights"]
                    entry["regions"] = region_data["regions"]
                else:
                    entry["page_heights"] = []
                    entry["regions"] = []
                problem_pdfs.append(entry)
            return JSONResponse(
                {
                    "problems": problem_pdfs,
                    "total_problems": len(problem_pdfs),
                    "page_count": num_pages,
                }
            )

        # Merge all per-problem PDFs into one, tracking page ranges per question
        merged = fitz.open()
        question_pages: list[list[int]] = []
        running_page = 0
        for label, problem_pdf_bytes, _ in compiled:
            sub_doc = fitz.open(stream=problem_pdf_bytes, filetype="pdf")
            question_pages.append([running_page, running_page + sub_doc.page_count - 1])
            running_page += sub_doc.page_count
            merged.insert_pdf(sub_doc)
            sub_doc.close()

        merged_bytes = merged.tobytes()
        merged.close()

        output_filename = f"{base_name}.pdf"
        if debug:
            data_dir = Path(__file__).parent.parent.parent / "data"
            reconstructions_dir = data_dir / "reconstructions"
            reconstructions_dir.mkdir(parents=True, exist_ok=True)
            (reconstructions_dir / output_filename).write_bytes(merged_bytes)

        return StreamingResponse(
            io.BytesIO(merged_bytes),
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"inline; filename={output_filename}",
                "X-Problem-Count": str(len(compiled)),
                "X-Page-Count": str(num_pages),
                "X-Question-Pages": json.dumps(question_pages),
                "X-Cost-Cents": str(costs.cost_cents),
                "X-Input-Tokens": str(costs.input_tokens),
                "X-Output-Tokens": str(costs.output_tokens),
                "X-LLM-Calls": str(costs.llm_calls),
                "X-GPU-Seconds": str(round(costs.gpu_seconds, 2)),
                "X-Pipeline-Seconds": str(round(costs.pipeline_seconds, 2)),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
