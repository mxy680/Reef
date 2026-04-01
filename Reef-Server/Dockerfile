FROM python:3.12-slim

WORKDIR /app

# System deps for PyMuPDF and tectonic
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfontconfig1 \
    libfreetype6 \
    libharfbuzz0b \
    libfribidi0 \
    libglib2.0-0 \
    curl \
    mupdf-tools \
    && rm -rf /var/lib/apt/lists/*

# Install tectonic LaTeX compiler
RUN curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh \
    && mv tectonic /usr/local/bin/

COPY pyproject.toml .
RUN pip install --no-cache-dir .

COPY app/ app/

RUN useradd --create-home reef
USER reef

# Pre-warm tectonic cache (downloads TeX packages on first run)
RUN printf '\\documentclass{article}\\begin{document}Hello\\end{document}\n' > /tmp/test.tex \
    && tectonic /tmp/test.tex \
    && rm /tmp/test.tex /tmp/test.pdf

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["gunicorn", "app.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--workers", "1", \
     "--bind", "0.0.0.0:8000", \
     "--timeout", "600", \
     "--graceful-timeout", "25", \
     "--keep-alive", "5"]
