"""POST /ai/reconstruct — Reconstruct homework PDFs into cleanly typeset LaTeX.

Pipeline:
1. Render PDF pages at 192 DPI (Surya) + 288 DPI (cropping) via PyMuPDF
2. Run Surya layout detection on Modal GPU, annotate pages with red numbered boxes
3. Send annotated images to Gemini (via OpenRouter LLMClient) for problem grouping
4. For each problem: crop regions, send to Gemini for structured Question extraction
5. question_to_latex() → LaTeXCompiler (with LLM error recovery on failure)

Output: merged PDF (default) or split JSON with base64 PDFs + regions.
"""

import asyncio
import base64
import io
import json
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

import fitz  # PyMuPDF
import modal
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse
from PIL import Image, ImageDraw, ImageFont

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.models import GroupProblemsResponse, ProblemGroup, Question, QuestionBatch
from app.services.latex_compiler import LaTeXCompiler
from app.services.llm_client import LLMClient
from app.services.prompts import (
    EXTRACT_QUESTION_PROMPT,
    GROUP_PROBLEMS_PROMPT,
    LATEX_FIX_PROMPT,
)
from app.services.question_to_latex import question_to_latex
from app.services.region_extractor import extract_question_regions

router = APIRouter()

FIGURE_LABELS = {"Picture", "Figure"}

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


def _annotate_page(
    img: Image.Image,
    layout_result: PageLayout,
    scale: int = 2,
    start_index: int = 1,
) -> tuple[Image.Image, int]:
    """Annotate a single page image with red numbered bounding boxes."""
    img = img.resize((img.width * scale, img.height * scale), Image.LANCZOS)
    img = img.convert("RGBA")

    overlay = Image.new("RGBA", img.size, (255, 255, 255, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 24)
    except Exception:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
        except Exception:
            font = ImageFont.load_default()

    rgb = (220, 53, 69)
    current_index = start_index

    for block in layout_result.bboxes:
        bbox = block.bbox
        x1, y1 = int(bbox[0] * scale), int(bbox[1] * scale)
        x2, y2 = int(bbox[2] * scale), int(bbox[3] * scale)

        overlay_draw.rectangle([(x1, y1), (x2, y2)], fill=(*rgb, 40))
        for i in range(3):
            draw.rectangle([(x1 - i, y1 - i), (x2 + i, y2 + i)], outline=rgb, width=2)

        label = str(current_index)
        label_y = max(y1 - 32, 5)
        text_bbox = draw.textbbox((x1, label_y), label, font=font)
        padding = 6
        draw.rectangle(
            (text_bbox[0] - padding, text_bbox[1] - padding,
             text_bbox[2] + padding, text_bbox[3] + padding),
            fill=rgb,
        )
        draw.text((x1, label_y), label, fill="white", font=font)
        current_index += 1

    img = Image.alpha_composite(img, overlay)
    return img.convert("RGB"), current_index


@router.post("/ai/reconstruct")
async def ai_reconstruct(
    user: AuthenticatedUser = Depends(get_current_user),
    pdf: UploadFile = File(..., description="PDF file to reconstruct"),
    split: bool = Query(default=False, description="Return individual problem PDFs as JSON"),
    debug: bool = Query(default=False, description="Save intermediate files to data/"),
):
    try:
        pdf_bytes = await pdf.read()
        base_name = Path(pdf.filename).stem if pdf.filename else "document"
        data_dir = Path(__file__).parent.parent.parent / "data"

        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        num_pages = len(doc)

        SURYA_DPI = 192
        CROP_DPI = 288
        crop_scale = CROP_DPI / SURYA_DPI

        surya_images = []
        hires_images = []
        surya_mat = fitz.Matrix(SURYA_DPI / 72, SURYA_DPI / 72)
        hires_mat = fitz.Matrix(CROP_DPI / 72, CROP_DPI / 72)

        for page_num in range(num_pages):
            pdf_page = doc[page_num]
            pix = pdf_page.get_pixmap(matrix=surya_mat)
            surya_images.append(
                Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
            )
            pix = pdf_page.get_pixmap(matrix=hires_mat)
            hires_images.append(
                Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
            )
        doc.close()

        # --- Stage 1: Surya layout detection (Modal GPU) ---
        surya_image_bytes: list[bytes] = []
        for img in surya_images:
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=95)
            surya_image_bytes.append(buf.getvalue())

        print(f"  [reconstruct] Sending {len(surya_image_bytes)} pages to Modal Surya...")
        surya_cls = SuryaLayout()
        raw_layouts = await asyncio.to_thread(
            surya_cls.detect_layout.remote, surya_image_bytes
        )

        # Deserialize Modal response into local dataclasses
        layout_results: list[PageLayout] = []
        for page_bboxes in raw_layouts:
            layout_results.append(
                PageLayout(
                    bboxes=[LayoutBlock(**b) for b in page_bboxes]
                )
            )
        print(f"  [reconstruct] Got layout results from Modal")

        annotated_pages = []
        current_index = 1
        for img, layout_result in zip(surya_images, layout_results):
            annotated, current_index = _annotate_page(
                img, layout_result, scale=2, start_index=current_index
            )
            annotated_pages.append(annotated)

        total_annotations = current_index - 1

        page_images: list[bytes] = []
        for page in annotated_pages:
            buf = io.BytesIO()
            page.save(buf, format="JPEG", quality=85)
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

        # --- Stage 2: Gemini problem grouping ---
        llm_client = LLMClient(
            api_key=settings.openrouter_api_key,
            model="google/gemini-3-flash-preview",
            base_url="https://openrouter.ai/api/v1",
        )

        prompt = GROUP_PROBLEMS_PROMPT.format(total_annotations=total_annotations)
        raw_response = llm_client.generate(
            prompt=prompt,
            images=page_images,
            response_schema=GroupProblemsResponse.model_json_schema(),
        )
        group_result = GroupProblemsResponse.model_validate_json(raw_response)

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
                print(
                    f"  [reconstruct] Rescued orphan figure {idx} ({label}) -> {best_problem.label}"
                )

        # --- Stage 3+4: Extraction per crop group ---

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

            # Include page 0 as context if problem isn't on it
            if problem_pages and 0 not in problem_pages:
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

        async def reconstruct_group(
            problems: list[ProblemGroup],
        ) -> list[tuple[str, str, dict, dict | None]]:
            """Extract all questions sharing the same page regions in one LLM call."""
            extraction_images, image_data, figure_filenames, figure_mappings = (
                _get_extraction_images(problems[0])
            )

            labels_str = ", ".join(p.label for p in problems)
            print(
                f"  [reconstruct] Group [{labels_str}]: {len(extraction_images)} pages "
                f"({len(figure_filenames)} figures)"
            )

            if not extraction_images:
                return [(p.label, "% No regions found", {}, None) for p in problems]

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

            raw = await asyncio.to_thread(
                llm_client.generate,
                prompt=extract_prompt,
                images=extraction_images,
                response_schema=schema,
            )

            if len(problems) == 1:
                questions = [Question.model_validate_json(raw)]
            else:
                batch = QuestionBatch.model_validate_json(raw)
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

            out: list[tuple[str, str, dict, dict | None]] = []
            for problem in problems:
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

                if matched:
                    latex = question_to_latex(matched)
                    print(
                        f"  [reconstruct] {problem.label}: got {len(latex)} chars of LaTeX"
                    )
                    out.append((problem.label, latex, image_data, matched.model_dump()))
                else:
                    print(
                        f"  [reconstruct] {problem.label}: no matching question in batch"
                    )
                    out.append((problem.label, "% Extraction failed", {}, None))

            return out

        # Group problems by annotation indices
        crop_groups: dict[tuple, list[ProblemGroup]] = defaultdict(list)
        for p in group_result.problems:
            key = tuple(sorted(p.annotation_indices))
            crop_groups[key].append(p)

        group_tasks = [reconstruct_group(probs) for probs in crop_groups.values()]
        group_results_nested = await asyncio.gather(*group_tasks)

        results_by_label: dict[str, tuple] = {}
        for group_list in group_results_nested:
            for r in group_list:
                results_by_label[r[0]] = r
        results = [results_by_label[p.label] for p in group_result.problems]

        # Save structured questions
        questions_data = [q for _, _, _, q in results if q is not None]
        if debug and questions_data:
            structured_dir = data_dir / "structured"
            structured_dir.mkdir(parents=True, exist_ok=True)
            (structured_dir / f"{base_name}.json").write_text(
                json.dumps(questions_data, indent=2)
            )

        # --- Stage 5: Compile LaTeX to PDF ---
        compiler = LaTeXCompiler()

        async def compile_problem(
            problem_num: int,
            label: str,
            latex: str,
            image_data: dict[str, str],
            question_dict: dict | None,
        ) -> tuple[str, bytes | None, dict | None]:
            header = f"Problem {problem_num}"
            content = f"\\textbf{{\\large {header}}}\n\n{latex}"
            print(
                f"  [compile] {label}: {len(latex)} chars, "
                f"images={list(image_data.keys()) or 'none'}"
            )
            try:
                pdf_bytes = await asyncio.to_thread(
                    compiler.compile_latex, content, image_data=image_data or None
                )
                return (label, pdf_bytes, question_dict)
            except Exception as e:
                print(f"  [compile] {label}: FAILED — {e}")
                # Try LLM fix
                try:
                    fix_prompt = LATEX_FIX_PROMPT.format(
                        latex_body=latex, error_message=str(e)[:2000]
                    )
                    fixed_latex = await asyncio.to_thread(
                        llm_client.generate, prompt=fix_prompt
                    )
                    fixed_content = f"\\textbf{{\\large {header}}}\n\n{fixed_latex}"
                    pdf_bytes = await asyncio.to_thread(
                        compiler.compile_latex,
                        fixed_content,
                        image_data=image_data or None,
                    )
                    print(f"  [compile] {label}: FIXED by LLM")
                    return (label, pdf_bytes, question_dict)
                except Exception as e2:
                    print(f"  [compile] {label}: FIX FAILED — {e2}")
                    fallback = (
                        f"\\textbf{{\\large {header}}}\n\n"
                        f"\\textit{{LaTeX compilation failed for this problem.}}"
                    )
                    pdf_bytes = await asyncio.to_thread(
                        compiler.compile_latex, fallback
                    )
                    return (label, pdf_bytes, None)

        compile_tasks = [
            compile_problem(i + 1, label, latex, img_data, q_dict)
            for i, (p, (label, latex, img_data, q_dict)) in enumerate(
                zip(group_result.problems, results)
            )
        ]
        compiled = await asyncio.gather(*compile_tasks)

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

        # Merge all per-problem PDFs into one
        merged = fitz.open()
        for label, problem_pdf_bytes, _ in compiled:
            sub_doc = fitz.open(stream=problem_pdf_bytes, filetype="pdf")
            merged.insert_pdf(sub_doc)
            sub_doc.close()

        merged_bytes = merged.tobytes()
        merged.close()

        output_filename = f"{base_name}.pdf"
        if debug:
            reconstructions_dir = data_dir / "reconstructions"
            reconstructions_dir.mkdir(parents=True, exist_ok=True)
            (reconstructions_dir / output_filename).write_bytes(merged_bytes)

        return StreamingResponse(
            io.BytesIO(merged_bytes),
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"inline; filename={output_filename}",
                "X-Problem-Count": str(len(group_result.problems)),
                "X-Page-Count": str(num_pages),
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
