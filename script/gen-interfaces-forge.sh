#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v forge >/dev/null 2>&1 || { echo "Missing: forge"; exit 1; }
command -v cast  >/dev/null 2>&1 || { echo "Missing: cast"; exit 1; }
command -v jq    >/dev/null 2>&1 || { echo "Missing: jq"; exit 1; }

# ---------------- config ----------------
# PERPL_PROJECT_PATH must be set to the target project directory
if [[ -z "${PERPL_PROJECT_PATH:-}" ]]; then
  echo "Error: PERPL_PROJECT_PATH environment variable is not set."
  echo "Usage: PERPL_PROJECT_PATH=../mvp-sc-0.1 $0"
  exit 1
fi

# Convert to absolute path
PROJECT_PATH="$(cd "$ROOT_DIR" && cd "$PERPL_PROJECT_PATH" && pwd)"

CONTRACTS_DIR="$PROJECT_PATH/contracts"
BUILD_OUT_DIR="$PROJECT_PATH/out"
OUT_DIR="$ROOT_DIR/interfaces"
PRAGMA="^0.8.20"

# Compile only contracts/**/*.sol, excluding these folders
EXCL_PATH_1="*/helpers/*"
EXCL_PATH_2="*/fuzzer/*"

# Combined interface names for events and errors
COMBINED_EVENTS_NAME="IExchangeEvents"
COMBINED_ERRORS_NAME="IExchangeErrors"
# ----------------------------------------

# 1) Compile from within the target project directory (uses its foundry.toml)
echo "Compiling contracts in $PROJECT_PATH..."
cd "$PROJECT_PATH"
forge clean >/dev/null

find contracts -type f -name '*.sol' \
  ! -path "$EXCL_PATH_1" \
  ! -path "$EXCL_PATH_2" \
  -print0 \
| xargs -0 forge build --extra-output abi -- >/dev/null

cd "$ROOT_DIR"

# 2) Work in temp space
TMP_DIR="$(mktemp -d)"
TMP_OUT="$TMP_DIR/out"
mkdir -p "$TMP_OUT"

# Collect events/errors as JSONL for deduplication
EVENTS_JSONL="$TMP_DIR/events.jsonl"
ERRORS_JSONL="$TMP_DIR/errors.jsonl"
: > "$EVENTS_JSONL"
: > "$ERRORS_JSONL"

found_any=0
found_events=0
found_errors=0

# 3) Iterate Foundry artifacts
while IFS= read -r -d '' artifact; do
  [[ "$artifact" == *.metadata.json ]] && continue

  contract="$(basename "$artifact" .json)"
  abiFile="$TMP_DIR/${contract}.abi.json"
  jq '.abi // []' "$artifact" > "$abiFile"

  fnCount="$(jq '[.[] | select(.type=="function")] | length' "$abiFile")"
  [[ "$fnCount" -eq 0 ]] && continue
  found_any=1

  # Generate per-contract interface with FUNCTIONS ONLY (no events/errors)
  functionsOnlyAbi="$TMP_DIR/${contract}.functions.abi.json"
  jq '[.[] | select(.type=="function")]' "$abiFile" > "$functionsOnlyAbi"
  cast interface -n "I${contract}" -p "$PRAGMA" -o "$TMP_OUT/I${contract}.sol" "$functionsOnlyAbi"

  # Collect events for combined interface (dedupe by signature)
  evCount="$(jq '[.[] | select(.type=="event")] | length' "$abiFile")"
  if [[ "$evCount" -gt 0 ]]; then
    found_events=1
    jq -c '
      .[]
      | select(.type=="event")
      | {k: (.name + "(" + ((.inputs // []) | map(.type) | join(",")) + ")"), e: .}
    ' "$abiFile" >> "$EVENTS_JSONL"
  fi

  # Collect errors for combined interface (dedupe by signature)
  erCount="$(jq '[.[] | select(.type=="error")] | length' "$abiFile")"
  if [[ "$erCount" -gt 0 ]]; then
    found_errors=1
    jq -c '
      .[]
      | select(.type=="error")
      | {k: (.name + "(" + ((.inputs // []) | map(.type) | join(",")) + ")"), e: .}
    ' "$abiFile" >> "$ERRORS_JSONL"
  fi
done < <(
  find "$BUILD_OUT_DIR" -type f -name '*.json' ! -name '*.metadata.json' -print0 2>/dev/null || true
)

# 4) If nothing had functions, do not create any files
if [[ "$found_any" -eq 0 ]]; then
  echo "ℹ️ No functions found (after exclusions). No files created."
  rm -rf "$TMP_DIR"
  exit 0
fi

# 5) Generate combined events interface
if [[ "$found_events" -eq 1 ]]; then
  MERGED_EVENTS_ABI="$TMP_DIR/merged_events.abi.json"
  jq -s 'unique_by(.k) | map(.e)' "$EVENTS_JSONL" > "$MERGED_EVENTS_ABI"
  cast interface -n "$COMBINED_EVENTS_NAME" -p "$PRAGMA" -o "$TMP_OUT/${COMBINED_EVENTS_NAME}.sol" "$MERGED_EVENTS_ABI"
fi

# 6) Generate combined errors interface
if [[ "$found_errors" -eq 1 ]]; then
  MERGED_ERRORS_ABI="$TMP_DIR/merged_errors.abi.json"
  jq -s 'unique_by(.k) | map(.e)' "$ERRORS_JSONL" > "$MERGED_ERRORS_ABI"
  cast interface -n "$COMBINED_ERRORS_NAME" -p "$PRAGMA" -o "$TMP_OUT/${COMBINED_ERRORS_NAME}.sol" "$MERGED_ERRORS_ABI"
fi

# 7) Write outputs
mkdir -p "$OUT_DIR"
cp -a "$TMP_OUT/." "$OUT_DIR/"

echo "✅ Per-contract interfaces (functions only): $OUT_DIR/I<Contract>.sol"
echo "   IExchange.sol contains all functions from inherited contracts"
if [[ "$found_events" -eq 1 ]]; then
  echo "✅ Combined events interface: $OUT_DIR/${COMBINED_EVENTS_NAME}.sol"
fi
if [[ "$found_errors" -eq 1 ]]; then
  echo "✅ Combined errors interface: $OUT_DIR/${COMBINED_ERRORS_NAME}.sol"
fi

rm -rf "$TMP_DIR"
