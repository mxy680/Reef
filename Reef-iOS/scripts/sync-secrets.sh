#!/bin/bash
# Pulls secrets from Doppler and generates Secrets.xcconfig
# Usage: ./scripts/sync-secrets.sh [config]
# Default config: dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG="${1:-dev}"
OUTPUT="$PROJECT_DIR/Secrets.xcconfig"

if ! command -v doppler &>/dev/null; then
    echo "error: Doppler CLI not installed. Run: brew install dopplerhq/cli/doppler"
    exit 1
fi

echo "Pulling secrets from doppler (reef/$CONFIG)..."

# Fetch secrets as JSON, convert to xcconfig format
# xcconfig requires URL slashes to be escaped as /$()/
doppler secrets download \
    --project reef \
    --config "$CONFIG" \
    --format json \
    --no-file 2>/dev/null \
| python3 -c "
import json, sys

secrets = json.load(sys.stdin)
# Keys we need in xcconfig
keys = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'GOOGLE_IOS_CLIENT_ID',
    'GOOGLE_REVERSED_CLIENT_ID',
    'REEF_WEB_URL',
    'REEF_SERVER_URL',
]

for key in keys:
    value = secrets.get(key, '')
    # xcconfig: escape :// as :/\$()/ so Xcode doesn't treat it as a comment
    value = value.replace('://', ':/\$()/')
    print(f'{key} = {value}')
" > "$OUTPUT"

echo "Wrote $OUTPUT ($(wc -l < "$OUTPUT" | tr -d ' ') keys)"
