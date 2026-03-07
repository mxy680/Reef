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
from app.services.mathpix import pdf_to_mmd
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

    if debug:
        mmd_dir = data_dir / "mmd"
        mmd_dir.mkdir(parents=True, exist_ok=True)
        (mmd_dir / f"{base_name}.mmd").write_text(mmd)
        print(f"  Saved to {mmd_dir / f'{base_name}.mmd'}")

    print(f"\n--- MMD Content ---\n{mmd}\n--- End MMD ---\n")

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

    if debug:
        structured_dir = data_dir / "structured"
        structured_dir.mkdir(parents=True, exist_ok=True)
        (structured_dir / f"{base_name}.json").write_text(
            json.dumps([q.model_dump() for q in questions], indent=2)
        )

    # Print extracted questions
    for q in questions:
        parts_str = f", {len(q.parts)} parts" if q.parts else ""
        print(f"  Q{q.number}: {q.text[:80]}...{parts_str}, space={q.answer_space_cm}cm")

    # --- Stage 3: LaTeX compile ---
    print("\nStage 3: LaTeX compilation...")
    compiler = LaTeXCompiler()

    import fitz
    merged = fitz.open()

    for i, q in enumerate(questions):
        label = f"Problem {i + 1}"
        latex = question_to_latex(q)

        try:
            content = f"\\textbf{{\\large {label}}}\n\n{latex}"
            pdf_result = compiler.compile_latex(content)
            sub_doc = fitz.open(stream=pdf_result, filetype="pdf")
            merged.insert_pdf(sub_doc)
            pages = sub_doc.page_count
            sub_doc.close()
            print(f"  Q{q.number} ({label}): OK — {pages} page(s), {len(latex)} chars")
        except Exception as e:
            print(f"  Q{q.number} ({label}): COMPILE FAILED — {e}")
            # Try LLM fix
            try:
                fix_result = llm_client.generate(
                    prompt=LATEX_FIX_PROMPT.format(
                        latex_body=latex, error_message=str(e)[:2000]
                    )
                )
                content = f"\\textbf{{\\large {label}}}\n\n{fix_result.content}"
                pdf_result = compiler.compile_latex(content)
                sub_doc = fitz.open(stream=pdf_result, filetype="pdf")
                merged.insert_pdf(sub_doc)
                sub_doc.close()
                print(f"  Q{q.number}: FIXED after LLM retry")
            except Exception as e2:
                print(f"  Q{q.number}: STILL FAILED — {e2}")

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
    print(f"Output: {out_path}")
    print(f"{'='*60}")


if __name__ == "__main__":
    asyncio.run(main())
