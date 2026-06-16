#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_EXTENSIONS="$REPO_DIR/extensions"
SOURCE_MODELS="$REPO_DIR/models.json"
TARGET_EXTENSIONS="$HOME/.pi/agent/extensions"
TARGET_MODELS="$HOME/.pi/agent/models.json"
BACKUP_DIR="$HOME/.pi/agent/backups/$(date +%s)"

backup_if_needed() {
  local target="$1"
  if [ -e "$target" ] && ! [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR"
    echo "Backing up $target to $BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
  fi
}

# Symlink extensions directory.
backup_if_needed "$TARGET_EXTENSIONS"
ln -sfn "$SOURCE_EXTENSIONS" "$TARGET_EXTENSIONS"
echo "Linked $TARGET_EXTENSIONS -> $SOURCE_EXTENSIONS"

# Symlink models.json if it exists in the repo.
if [ -f "$SOURCE_MODELS" ]; then
  backup_if_needed "$TARGET_MODELS"
  ln -sfn "$SOURCE_MODELS" "$TARGET_MODELS"
  echo "Linked $TARGET_MODELS -> $SOURCE_MODELS"
fi

# Install dependencies in the repo's extensions directory so the symlink target is self-contained.
cd "$SOURCE_EXTENSIONS"
npm install

echo ""
echo "Pi extensions linked to $TARGET_EXTENSIONS"
echo "Updates in $SOURCE_EXTENSIONS are immediately active."
echo ""
echo "Models configured in $TARGET_MODELS"
echo ""
echo "Add your API keys to ~/.pi/agent/.env if needed:"
echo "  FIRECRAWL_API_KEY=fc-..."
