FROM python:3.11-slim

WORKDIR /app

# Install system dependencies including tectonic for LaTeX compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libgraphite2-3 \
    libharfbuzz0b \
    libfontconfig1 \
    libfreetype6 \
    libssl3 \
    && curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh \
    && mv tectonic /usr/local/bin/ \
    && rm -rf /var/lib/apt/lists/*

# Pre-warm tectonic bundle cache so parallel compiles don't race
RUN echo '\documentclass{article}\begin{document}Hello\end{document}' > /tmp/warmup.tex \
    && tectonic /tmp/warmup.tex --outdir /tmp \
    && rm /tmp/warmup.tex /tmp/warmup.pdf

# Install CPU-only PyTorch first (much smaller)
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run the application (Railway sets PORT env var)
# --timeout-keep-alive: Increase timeout for long-running question extraction
CMD uvicorn api.index:app --host 0.0.0.0 --port ${PORT:-8000} --timeout-keep-alive 180
