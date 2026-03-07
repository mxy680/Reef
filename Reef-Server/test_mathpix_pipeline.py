"""Test the Mathpix + DeepSeek pipeline end-to-end on a local PDF.

Self-contained — avoids importing reconstruct.py (which needs auth, modal, etc.)

Usage:
    python test_mathpix_pipeline.py data/sample_worksheet.pdf
    python test_mathpix_pipeline.py data/sample_worksheet.pdf --debug
"""

import asyncio
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from app.config import settings
from app.models.question import Question, QuestionBatch
from app.services.latex_compiler import LaTeXCompiler
from app.services.llm_client import LLMClient
from app.services.mathpix import pdf_to_mmd, download_mmd_images
from app.services.prompts import MATHPIX_EXTRACT_PROMPT, LATEX_FIX_PROMPT
from app.services.question_to_latex import question_to_latex


async def main():
    if len(sys.argv) < 2:
        print("Usage: python test_mathpix_pipeline.py <pdf_path> [--debug]")
        sys.exit(1)

    pdf_path = Path(sys.argv[1])
    debug = "--debug" in sys.argv

    if not pdf_path.exists():
        print(f"Error: {pdf_path} not found")
        sys.exit(1)

    pdf_bytes = pdf_path.read_bytes()
    base_name = pdf_path.stem
    data_dir = Path("data")

    print(f"Running Mathpix pipeline on: {pdf_path}\n")
    start = time.time()

    # --- Stage 1: Mathpix OCR ---
    print("Stage 1: Mathpix OCR...")
    mmd = await pdf_to_mmd(pdf_bytes, f"{base_name}.pdf")
    print(f"  Got MMD: {len(mmd)} chars")

    # Download images referenced in MMD
    mmd, image_data = await download_mmd_images(mmd)
    if image_data:
        print(f"  Downloaded {len(image_data)} images: {list(image_data.keys())}")

    if debug:
        mmd_dir = data_dir / "mmd"
        mmd_dir.mkdir(parents=True, exist_ok=True)
        (mmd_dir / f"{base_name}.mmd").write_text(mmd)
        print(f"  Saved to {mmd_dir / f'{base_name}.mmd'}")

    print(f"\n--- MMD Content (first 2000 chars) ---\n{mmd[:2000]}\n--- End MMD ---\n")

    # --- Stage 2: DeepSeek extraction ---
    print("Stage 2: DeepSeek extraction...")
    llm_client = LLMClient(
        api_key=settings.openrouter_api_key,
        model="deepseek/deepseek-chat-v3-0324",
        base_url="https://openrouter.ai/api/v1",
    )

    prompt = MATHPIX_EXTRACT_PROMPT.format(mmd_content=mmd)
    extract_result = llm_client.generate(
        prompt=prompt,
        response_schema=QuestionBatch.model_json_schema(),
    )
    batch = QuestionBatch.model_validate_json(extract_result.content)
    questions = sorted(batch.questions, key=lambda q: q.number)
    print(f"  Extracted {len(questions)} questions")
    print(f"  Tokens: {extract_result.input_tokens} in / {extract_result.output_tokens} out")

    # Strip hallucinated figure filenames
    valid_figs = set(image_data.keys())
    for q in questions:
        q.figures = [f for f in q.figures if f in valid_figs]
        for part in q.parts:
            part.figures = [f for f in part.figures if f in valid_figs]
            for sub in part.parts:
                sub.figures = [f for f in sub.figures if f in valid_figs]

    if debug:
        structured_dir = data_dir / "structured"
        structured_dir.mkdir(parents=True, exist_ok=True)
        (structured_dir / f"{base_name}.json").write_text(
            json.dumps([q.model_dump() for q in questions], indent=2)
        )

    # Print extracted questions
    for q in questions:
        parts_str = f", {len(q.parts)} parts" if q.parts else ""
        figs_str = f", figs={q.figures}" if q.figures else ""
        print(f"  Q{q.number}: {q.text[:80]}...{parts_str}{figs_str}, space={q.answer_space_cm}cm")

    # Collect figures per question
    def _collect_figures(question):
        figs = set(question.figures)
        for part in question.parts:
            figs.update(part.figures)
            for sub in part.parts:
                figs.update(sub.figures)
        return figs

    # --- Stage 3: LaTeX compile ---
    print("\nStage 3: LaTeX compilation...")
    compiler = LaTeXCompiler()

    import fitz
    merged = fitz.open()

    for i, q in enumerate(questions):
        label = f"Problem {i + 1}"
        latex = question_to_latex(q)

        # Per-question image data
        q_figs = _collect_figures(q)
        q_image_data = {k: v for k, v in image_data.items() if k in q_figs} or None

        try:
            content = f"\\textbf{{\\large {label}}}\n\n{latex}"
            pdf_result = compiler.compile_latex(content, image_data=q_image_data)
            sub_doc = fitz.open(stream=pdf_result, filetype="pdf")
            merged.insert_pdf(sub_doc)
            pages = sub_doc.page_count
            sub_doc.close()
            fig_str = f", {len(q_figs)} figs" if q_figs else ""
            print(f"  Q{q.number} ({label}): OK — {pages} page(s), {len(latex)} chars{fig_str}")
        except Exception as e:
            print(f"  Q{q.number} ({label}): COMPILE FAILED — {str(e)[:200]}")
            # Try LLM fix
            try:
                fix_result = llm_client.generate(
                    prompt=LATEX_FIX_PROMPT.format(
                        latex_body=latex, error_message=str(e)[:2000]
                    )
                )
                content = f"\\textbf{{\\large {label}}}\n\n{fix_result.content}"
                pdf_result = compiler.compile_latex(content, image_data=q_image_data)
                sub_doc = fitz.open(stream=pdf_result, filetype="pdf")
                merged.insert_pdf(sub_doc)
                sub_doc.close()
                print(f"  Q{q.number}: FIXED after LLM retry")
            except Exception as e2:
                print(f"  Q{q.number}: STILL FAILED — {str(e2)[:200]}")

    elapsed = time.time() - start

    # Save merged PDF
    out_dir = data_dir / "reconstructions"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{base_name}_mathpix.pdf"
    merged.save(str(out_path))
    merged.close()

    print(f"\n{'='*60}")
    print(f"Done in {elapsed:.1f}s")
    print(f"Problems: {len(questions)}")
    print(f"Images: {len(image_data)}")
    print(f"Output: {out_path}")
    print(f"{'='*60}")


if __name__ == "__main__":
    asyncio.run(main())
