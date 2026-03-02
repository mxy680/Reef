"""LaTeX compilation service using tectonic."""

import base64
import shutil
import subprocess
import tempfile
from pathlib import Path

LATEX_TEMPLATE = r"""
\documentclass[12pt,letterpaper]{{article}}

% Page setup
\usepackage[margin=1in]{{geometry}}

% Math packages
\usepackage{{amsmath}}
\usepackage{{amssymb}}
\usepackage{{amsfonts}}

% Graphics
\usepackage{{graphicx}}
\graphicspath{{{{{image_path}}}}}

% Tables
\usepackage{{booktabs}}
\usepackage{{array}}

% Colors
\usepackage{{xcolor}}

% Prevent page breaks in middle of sub-questions
\usepackage{{needspace}}

% Algorithm/pseudocode support
\usepackage{{algorithm}}
\usepackage{{algorithmic}}

% Code listings
\usepackage{{listings}}
\lstset{{basicstyle=\ttfamily\small, columns=fullflexible, breaklines=true}}

% Captions outside floats
\usepackage{{caption}}

% Indentation for nested sub-parts
\usepackage{{changepage}}

% Font improvements
\usepackage{{lmodern}}
\usepackage[T1]{{fontenc}}

% Prevent paragraph indentation
\setlength{{\parindent}}{{0pt}}
\setlength{{\parskip}}{{1em}}

% Remove page numbers for single-question pages
\pagenumbering{{gobble}}

\begin{{document}}

{content}

\end{{document}}
"""


class LaTeXCompiler:
    """Compiles LaTeX content to PDF using tectonic."""

    def __init__(self, tectonic_path: str | None = None):
        self.tectonic_path = tectonic_path or "tectonic"
        try:
            result = subprocess.run(
                [self.tectonic_path, "--version"],
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode != 0:
                raise RuntimeError(f"tectonic check failed: {result.stderr}")
        except FileNotFoundError:
            raise RuntimeError(
                "tectonic not found. Install with: "
                "curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh"
            )

    def compile_latex(
        self,
        latex_content: str,
        image_data: dict[str, str] | None = None,
    ) -> bytes:
        """Compile LaTeX body content to PDF bytes."""
        temp_dir = Path(tempfile.mkdtemp())
        try:
            images_dir = temp_dir / "images"
            if image_data:
                images_dir.mkdir(exist_ok=True)
                for img_name, img_b64 in image_data.items():
                    (images_dir / img_name).write_bytes(base64.b64decode(img_b64))

            image_path_latex = str(images_dir) + "/" if image_data else "./"
            full_document = LATEX_TEMPLATE.format(
                image_path=image_path_latex,
                content=latex_content,
            )

            tex_file = temp_dir / "question.tex"
            tex_file.write_text(full_document, encoding="utf-8")

            result = subprocess.run(
                [self.tectonic_path, str(tex_file), "--outdir", str(temp_dir), "--keep-logs"],
                capture_output=True, text=True, timeout=60, cwd=str(temp_dir),
            )

            if result.returncode != 0:
                log_file = temp_dir / "question.log"
                log_content = log_file.read_text()[-2000:] if log_file.exists() else ""
                raise RuntimeError(
                    f"LaTeX compilation failed:\n{result.stderr}\n\nLog:\n{log_content}"
                )

            pdf_file = temp_dir / "question.pdf"
            if not pdf_file.exists():
                raise RuntimeError("PDF file was not generated")

            return pdf_file.read_bytes()
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)
