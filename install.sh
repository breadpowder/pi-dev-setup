#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.pi/agent/extensions"

mkdir -p "$TARGET_DIR"

# Copy each tracked extension, overwriting existing files/directories.
for source in "$REPO_DIR/extensions"/*; do
  name=$(basename "$source")
  target="$TARGET_DIR/$name"

  if [ -d "$source" ]; then
    rm -rf "$target"
    cp -R "$source" "$target"
  else
    cp -f "$source" "$target"
  fi

done

# Install dependencies declared in extensions/package.json.
cd "$TARGET_DIR"
npm install

echo "Pi extensions installed to $TARGET_DIR"
echo ""
echo "Add your API keys to ~/.pi/agent/.env if needed:"
echo "  FIRECRAWL_API_KEY=fc-..."
