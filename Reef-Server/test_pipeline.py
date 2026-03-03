"""Test the optimized reconstruction pipeline against real documents.

Usage: uv run python test_pipeline.py
"""

import asyncio
import sys
import time
from pathlib import Path

# Ensure the app package is importable
sys.path.insert(0, str(Path(__file__).parent))


async def test_document(pdf_path: str) -> dict:
    """Run the pipeline on a single PDF and return metrics."""
    from app.routers.reconstruct import PipelineCosts, _run_pipeline

    pdf_bytes = Path(pdf_path).read_bytes()
    name = Path(pdf_path).stem

    print(f"\n{'='*60}")
    print(f"  Testing: {Path(pdf_path).name}")
    print(f"{'='*60}")

    costs = PipelineCosts()
    start = time.monotonic()
    try:
        compiled, num_pages, costs = await _run_pipeline(
            pdf_bytes, document_id=None, debug=True, base_name=name, costs=costs
        )
        elapsed = time.monotonic() - start

        # Save reconstructed PDFs (clear old results first)
        import shutil
        out_dir = Path(__file__).parent / "data" / "reconstructed" / name
        if out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        for label, pdf_result, _ in compiled:
            safe_label = label.replace("/", "-").replace(" ", "_")
            (out_dir / f"{safe_label}.pdf").write_bytes(pdf_result)
        print(f"  [test] Saved {len(compiled)} PDFs to {out_dir}")

        result = {
            "name": Path(pdf_path).name,
            "course": Path(pdf_path).parent.name,
            "pages": num_pages,
            "problems": len(compiled),
            "llm_calls": costs.llm_calls,
            "input_tokens": costs.input_tokens,
            "output_tokens": costs.output_tokens,
            "gpu_seconds": round(costs.gpu_seconds, 2),
            "pipeline_seconds": round(elapsed, 2),
            "cost_cents": costs.cost_cents,
            "status": "OK",
        }
    except Exception as e:
        elapsed = time.monotonic() - start
        result = {
            "name": Path(pdf_path).name,
            "course": Path(pdf_path).parent.name,
            "pages": 0,
            "problems": 0,
            "llm_calls": costs.llm_calls,
            "input_tokens": costs.input_tokens,
            "output_tokens": costs.output_tokens,
            "gpu_seconds": round(costs.gpu_seconds, 2),
            "pipeline_seconds": round(elapsed, 2),
            "cost_cents": costs.cost_cents,
            "status": f"FAILED: {e}",
        }

    return result


async def main():
    test_docs = [
        # CSDS-310 — previously had "FDs & Normalization" label causing LaTeX & error
        "/Users/markshteyn/Documents/cwru/CSDS-310/3BQ.pdf",
        # PHYS-121 — has figures, previously triggered hallucinated filenames
        "/Users/markshteyn/Documents/cwru/PHYS-121/p121_spring2024_05.pdf",
        # STAT-312 — short quiz, good baseline
        "/Users/markshteyn/Documents/cwru/STAT-312/STAT312_Quiz_2.pdf",
        # ENGR-145 — math-heavy, previously had \baselineskip corruption
        "/Users/markshteyn/Documents/cwru/ENGR-145/ENGR 145 - HW 5 - Due 10-9-24.pdf",
        # CHEM-111 — multi-page exam with figures
        "/Users/markshteyn/Documents/cwru/CHEM-111/F18111_E2.pdf",
    ]

    results = []
    for path in test_docs:
        if not Path(path).exists():
            print(f"\n  SKIPPING (not found): {path}")
            continue
        result = await test_document(path)
        results.append(result)

    # Print summary table
    print(f"\n\n{'='*130}")
    print("  RESULTS SUMMARY")
    print(f"{'='*130}")
    print(
        f"{'Course':<12} {'Document':<40} {'Pages':>5} {'Probs':>5} {'LLM':>4} "
        f"{'In Tok':>8} {'Out Tok':>8} {'GPU(s)':>6} {'Time(s)':>7} {'Cost':>5} {'Status'}"
    )
    print("-" * 130)

    ok_results = []
    for r in results:
        cost_str = f"{r['cost_cents']}¢"
        status_short = r['status'][:30]
        print(
            f"{r['course']:<12} {r['name']:<40} {r['pages']:>5} {r['problems']:>5} {r['llm_calls']:>4} "
            f"{r['input_tokens']:>8} {r['output_tokens']:>8} {r['gpu_seconds']:>6.1f} "
            f"{r['pipeline_seconds']:>7.1f} {cost_str:>5} {status_short}"
        )
        if r['status'] == 'OK':
            ok_results.append(r)

    total_cost = sum(r["cost_cents"] for r in results)
    total_time = sum(r["pipeline_seconds"] for r in results)
    print("-" * 130)
    print(f"{'TOTAL':<53} {'':>5} {'':>5} {'':>4} {'':>8} {'':>8} {'':>6} {total_time:>7.1f} {total_cost}¢")

    # Per-page and per-question averages (OK results only)
    if ok_results:
        total_pages = sum(r["pages"] for r in ok_results)
        total_problems = sum(r["problems"] for r in ok_results)
        total_ok_cost = sum(r["cost_cents"] for r in ok_results)
        total_ok_time = sum(r["pipeline_seconds"] for r in ok_results)
        n = len(ok_results)

        print(f"\n{'='*60}")
        print("  AVERAGES (successful runs only)")
        print(f"{'='*60}")
        print(f"  Documents:     {n}")
        print(f"  Total pages:   {total_pages}")
        print(f"  Total problems:{total_problems}")
        print(f"  Total cost:    {total_ok_cost}¢")
        print(f"  Total time:    {total_ok_time:.1f}s")
        print()
        print(f"  Cost/page:     {total_ok_cost / total_pages:.2f}¢")
        print(f"  Cost/problem:  {total_ok_cost / total_problems:.2f}¢")
        print(f"  Time/page:     {total_ok_time / total_pages:.1f}s")
        print(f"  Time/problem:  {total_ok_time / total_problems:.1f}s")
        print(f"  Cost/doc:      {total_ok_cost / n:.1f}¢")
        print(f"  Time/doc:      {total_ok_time / n:.1f}s")

        # Failure rate
        total = len(results)
        failed = total - n
        print(f"\n  Success rate:  {n}/{total} ({100*n/total:.0f}%)")
        if failed:
            print(f"  Failures:")
            for r in results:
                if r['status'] != 'OK':
                    print(f"    - {r['name']}: {r['status']}")


if __name__ == "__main__":
    asyncio.run(main())
