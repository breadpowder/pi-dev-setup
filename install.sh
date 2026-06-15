#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_EXTENSIONS="$REPO_DIR/extensions"
TARGET_DIR="$HOME/.pi/agent/extensions"
BACKUP_DIR="$HOME/.pi/agent/extensions.bak.$(date +%s)"

# If the target already exists and is not our symlink, back it up.
if [ -e "$TARGET_DIR" ] && ! [ -L "$TARGET_DIR" ]; then
  echo "Backing up existing extensions to $BACKUP_DIR"
  mv "$TARGET_DIR" "$BACKUP_DIR"
fi

# Ensure the symlink points to this repo's extensions directory.
ln -sfn "$SOURCE_EXTENSIONS" "$TARGET_DIR"

echo "Linked $TARGET_DIR -> $SOURCE_EXTENSIONS"

# Install dependencies in the repo's extensions directory so the symlink target is self-contained.
cd "$SOURCE_EXTENSIONS"
npm install

echo ""
echo "Pi extensions linked to $TARGET_DIR"
echo "Updates in $SOURCE_EXTENSIONS are immediately active."
echo ""
echo "Add your API keys to ~/.pi/agent/.env if needed:"
echo "  FIRECRAWL_API_KEY=fc-..."
