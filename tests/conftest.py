"""
Pytest configuration and fixtures.
"""

import os

# ── Test mode toggle ──────────────────────────────────────
REEF_TEST_MODE = os.getenv("REEF_TEST_MODE", "contract")

# Set test environment
os.environ["ENVIRONMENT"] = "development"

# In contract mode, set placeholder API keys so clients initialize
if REEF_TEST_MODE == "contract":
    os.environ.setdefault("GROQ_API_KEY", "fake-contract-key")
    os.environ.setdefault("OPENROUTER_API_KEY", "fake-contract-key")
    os.environ.setdefault("DEEPINFRA_API_KEY", "fake-contract-key")
    os.environ.setdefault("MODAL_TTS_URL", "https://fake-modal-tts.example.com/tts")
    os.environ.setdefault("MODAL_EMBED_URL", "https://fake-modal-embed.example.com/embed")
    os.environ.setdefault("MATHPIX_APP_ID", "fake-contract-id")
    os.environ.setdefault("MATHPIX_APP_KEY", "fake-contract-key")
