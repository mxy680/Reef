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
    os.environ.setdefault("OPENROUTER_API_KEY", "fake-contract-key")
    os.environ.setdefault("MODAL_EMBED_URL", "https://fake-modal-embed.example.com/embed")
