#!/usr/bin/env bash
# Install the pi-own Hermes skill into ~/.hermes/skills/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/skill/SKILL.md"
DEST_DIR="$HOME/.hermes/skills/autonomous-ai-agents/pi-own"
DEST="$DEST_DIR/SKILL.md"

[ -f "$SRC" ] || { echo "error: $SRC not found (run from the repo root)"; exit 1; }

if [ -f "$DEST" ] && ! diff -q "$SRC" "$DEST" >/dev/null 2>&1; then
  cp "$DEST" "$DEST.bak-$(date +%Y%m%d%H%M%S)"
  echo "existing SKILL.md backed up"
fi

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST"
echo "Installed: $DEST"
echo "Verify with: hermes skills list | grep pi-own"
echo "Then type /pi-own in a Hermes chat."
