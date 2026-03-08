#!/usr/bin/env python3
"""Test the v2 document reconstruction pipeline end-to-end.

Usage:
    python scripts/test_reconstruct.py "~/Documents/cwru/ENGR-145/ENGR 145 - HW 1 - Due 9-5-24-1.pdf"
    python scripts/test_reconstruct.py "~/Documents/cwru/ENGR-145/ENGR 145 - HW 1 - Due 9-5-24-1.pdf" --api-url http://localhost:8000

Requires env vars from ~/.config/reef/server.env (auto-loaded).
"""

import argparse
import json
import os
import sys
import time
import uuid
from pathlib import Path

import httpx

# ---------------------------------------------------------------------------
# Load env from shared config
# ---------------------------------------------------------------------------

ENV_FILE = Path.home() / ".config" / "reef" / "server.env"


def _load_env():
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, val = line.partition("=")
                os.environ.setdefault(key.strip(), val.strip())


_load_env()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
ANON_KEY = os.environ["SUPABASE_ANON_KEY"]

# Test user — hardcoded for dev/test convenience
TEST_USER_ID = "test-reconstruct-runner"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
}


# ---------------------------------------------------------------------------
# Supabase helpers
# ---------------------------------------------------------------------------


def supabase_upload(path: str, data: bytes, content_type: str = "application/pdf"):
    """Upload a file to Supabase Storage (documents bucket)."""
    url = f"{SUPABASE_URL}/storage/v1/object/documents/{path}"
    resp = httpx.put(
        url,
        content=data,
        headers={**HEADERS, "Content-Type": content_type, "x-upsert": "true"},
        timeout=120,
    )
    resp.raise_for_status()
    return resp


def supabase_download(path: str) -> bytes:
    """Download a file from Supabase Storage (documents bucket)."""
    url = f"{SUPABASE_URL}/storage/v1/object/documents/{path}"
    resp = httpx.get(url, headers=HEADERS, timeout=120)
    resp.raise_for_status()
    return resp.content


def supabase_insert_document(doc_id: str, user_id: str, name: str):
    """Insert a row into the documents table."""
    url = f"{SUPABASE_URL}/rest/v1/documents"
    resp = httpx.post(
        url,
        json={
            "id": doc_id,
            "user_id": user_id,
            "filename": name,
            "status": "uploaded",
        },
        headers={**HEADERS, "Content-Type": "application/json", "Prefer": "return=minimal"},
        timeout=10,
    )
    resp.raise_for_status()


def supabase_get_document(doc_id: str) -> dict | None:
    """Fetch a document row."""
    url = f"{SUPABASE_URL}/rest/v1/documents?id=eq.{doc_id}&select=*"
    resp = httpx.get(
        url,
        headers={**HEADERS, "Accept": "application/json"},
        timeout=10,
    )
    resp.raise_for_status()
    rows = resp.json()
    return rows[0] if rows else None


def supabase_delete_document(doc_id: str):
    """Delete a document row (cleanup)."""
    url = f"{SUPABASE_URL}/rest/v1/documents?id=eq.{doc_id}"
    httpx.delete(url, headers={**HEADERS, "Prefer": "return=minimal"}, timeout=10)


def supabase_delete_storage(path: str):
    """Delete a file from storage."""
    url = f"{SUPABASE_URL}/storage/v1/object/documents/{path}"
    httpx.delete(url, headers=HEADERS, timeout=10)


# ---------------------------------------------------------------------------
# Auth — mint a real JWT via Supabase signInWithPassword or admin API
# ---------------------------------------------------------------------------


def get_test_jwt(user_id: str) -> str:
    """Get a valid JWT for the test user via Supabase admin generateLink + signIn.

    Falls back to service role key (works if server is in dev mode).
    """
    # Try to use admin API to create/get a test user
    email = "test-reconstruct@studyreef.com"
    password = "test-reconstruct-2024"

    # Try sign in first
    resp = httpx.post(
        f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
        json={"email": email, "password": password},
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        timeout=10,
    )
    if resp.status_code == 200:
        data = resp.json()
        return data["access_token"], data["user"]["id"]

    # Create user via admin API, then sign in
    resp = httpx.post(
        f"{SUPABASE_URL}/auth/v1/admin/users",
        json={
            "email": email,
            "password": password,
            "email_confirm": True,
        },
        headers={**HEADERS, "Content-Type": "application/json"},
        timeout=10,
    )
    if resp.status_code in (200, 201):
        created_user_id = resp.json()["id"]
    elif resp.status_code == 422:
        # User already exists — just sign in again (shouldn't reach here)
        pass
    else:
        print(f"  Warning: could not create test user ({resp.status_code}). Using service key.")
        return SERVICE_KEY, user_id

    # Sign in
    resp = httpx.post(
        f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
        json={"email": email, "password": password},
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        timeout=10,
    )
    if resp.status_code == 200:
        data = resp.json()
        return data["access_token"], data["user"]["id"]

    print(f"  Warning: sign-in failed ({resp.status_code}). Using service key.")
    return SERVICE_KEY, user_id


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def run(pdf_path: str, api_url: str, output_dir: str | None = None):
    pdf_path = os.path.expanduser(pdf_path)
    if not os.path.exists(pdf_path):
        print(f"Error: {pdf_path} not found")
        sys.exit(1)

    pdf_name = Path(pdf_path).stem
    doc_id = str(uuid.uuid4())

    # Output directory
    if output_dir:
        out_dir = Path(output_dir)
    else:
        out_dir = Path(f"/tmp/reef-test-{doc_id[:8]}")
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"==> Test reconstruction: {pdf_name}")
    print(f"    Document ID: {doc_id}")
    print(f"    Output dir:  {out_dir}")
    print()

    # Step 1: Get auth token
    print("  [1/6] Authenticating...")
    jwt_token, user_id = get_test_jwt(TEST_USER_ID)
    print(f"    User ID: {user_id}")

    # Step 2: Upload PDF to storage
    print("  [2/6] Uploading PDF to Supabase Storage...")
    pdf_bytes = Path(pdf_path).read_bytes()
    storage_path = f"{user_id}/{doc_id}/original.pdf"
    supabase_upload(storage_path, pdf_bytes)
    print(f"    Uploaded {len(pdf_bytes):,} bytes")

    # Step 3: Create document row
    print("  [3/6] Creating document record...")
    supabase_insert_document(doc_id, user_id, pdf_name)

    # Step 4: Trigger reconstruction
    print("  [4/6] Triggering reconstruction...")
    resp = httpx.post(
        f"{api_url}/ai/v2/reconstruct-document",
        json={"document_id": doc_id},
        headers={
            "Authorization": f"Bearer {jwt_token}",
            "Content-Type": "application/json",
        },
        timeout=30,
    )
    if resp.status_code != 202:
        print(f"    ERROR: {resp.status_code} — {resp.text}")
        sys.exit(1)
    print(f"    Pipeline started (202)")

    # Step 5: Poll for completion
    print("  [5/6] Waiting for completion...")
    start = time.time()
    last_msg = ""
    while True:
        doc = supabase_get_document(doc_id)
        if not doc:
            print("    ERROR: document row disappeared")
            sys.exit(1)

        status = doc.get("status", "unknown")
        msg = doc.get("status_message") or ""
        if msg != last_msg:
            elapsed = time.time() - start
            print(f"    [{elapsed:5.1f}s] {msg or status}")
            last_msg = msg

        if status == "completed":
            break
        elif status == "failed":
            print(f"    FAILED: {doc.get('error_message', 'unknown error')}")
            sys.exit(1)

        time.sleep(2)

    elapsed = time.time() - start
    print(f"    Completed in {elapsed:.1f}s")
    print(f"    Problems: {doc.get('problem_count')}, Pages: {doc.get('page_count')}")
    print(f"    LLM calls: {doc.get('llm_calls')}, Cost: {doc.get('cost_cents')}¢")

    # Step 6: Download output
    print("  [6/6] Downloading output PDF...")
    output_path = f"{user_id}/{doc_id}/output.pdf"
    output_bytes = supabase_download(output_path)

    original_out = out_dir / "original.pdf"
    reconstructed_out = out_dir / "reconstructed.pdf"
    original_out.write_bytes(pdf_bytes)
    reconstructed_out.write_bytes(output_bytes)

    # Save metadata
    meta = {
        "document_id": doc_id,
        "source": pdf_path,
        "status": doc.get("status"),
        "problem_count": doc.get("problem_count"),
        "page_count": doc.get("page_count"),
        "llm_calls": doc.get("llm_calls"),
        "input_tokens": doc.get("input_tokens"),
        "output_tokens": doc.get("output_tokens"),
        "pipeline_seconds": doc.get("pipeline_seconds"),
        "cost_cents": doc.get("cost_cents"),
    }
    (out_dir / "metadata.json").write_text(json.dumps(meta, indent=2))

    print()
    print(f"==> Done!")
    print(f"    Original:      {original_out}")
    print(f"    Reconstructed: {reconstructed_out}")
    print(f"    Metadata:      {out_dir / 'metadata.json'}")
    print()
    print("Open both PDFs to compare:")
    print(f'    open "{original_out}" "{reconstructed_out}"')

    return str(out_dir)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test v2 reconstruction pipeline")
    parser.add_argument("pdf", help="Path to input PDF")
    parser.add_argument(
        "--api-url",
        default="https://api.studyreef.com",
        help="API base URL (default: production)",
    )
    parser.add_argument("--output-dir", help="Output directory (default: /tmp/reef-test-*)")
    args = parser.parse_args()
    run(args.pdf, args.api_url, args.output_dir)
