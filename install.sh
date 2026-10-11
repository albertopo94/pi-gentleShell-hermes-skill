#!/usr/bin/env bash
# Install all -own Hermes skills in this repo into ~/.hermes/skills/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_BASE="$HOME/.hermes/skills/autonomous-ai-agents"
installed=0

for src in "$REPO_DIR"/skills/*/SKILL.md; do
  skill_name="$(basename "$(dirname "$src")")"
  dest_dir="$DEST_BASE/$skill_name"
  dest="$dest_dir/SKILL.md"

  if [ -f "$dest" ] && ! diff -q "$src" "$dest" >/dev/null 2>&1; then
    cp "$dest" "$dest.bak-$(date +%Y%m%d%H%M%S)"
    echo "[$skill_name] existing SKILL.md backed up"
  fi

  mkdir -p "$dest_dir"
  cp "$src" "$dest"
  echo "[$skill_name] installed: $dest"
  installed=$((installed + 1))
done

if [ "$installed" -eq 0 ]; then
  echo "error: no skills found in $REPO_DIR/skills/" >&2
  exit 1
fi

echo "Done ($installed skills). Verify with: hermes skills list | grep -e pi-own -e gentle-shell-own"