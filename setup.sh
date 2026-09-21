#!/usr/bin/env bash
# multi-claude: run two Claude accounts side-by-side in Claude Code.
#
#   claude       -> personal account (default, uses ~/.claude)
#   claude-team  -> Team account     (uses ~/.claude-team)
#
# Both profiles share settings, CLAUDE.md, skills/agents/commands and the
# session store, so `claude-team -c` can pick up a conversation started with
# `claude` (and vice versa). Credentials and login state stay separate.
#
# Safe to re-run. Works on macOS and Linux (bash or zsh).

set -euo pipefail

PERSONAL_DIR="${CLAUDE_PERSONAL_DIR:-$HOME/.claude}"
TEAM_DIR="${CLAUDE_TEAM_DIR:-$HOME/.claude-team}"
ALIAS_NAME="${CLAUDE_TEAM_ALIAS:-claude-team}"

# Files/dirs shared between the two profiles (symlinked team -> personal).
SHARED_FILES=(settings.json CLAUDE.md)
SHARED_DIRS=(projects skills agents commands)

# ---------------------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  echo "error: 'claude' not found on PATH. Install Claude Code first:" >&2
  echo "       https://code.claude.com/docs/en/setup" >&2
  exit 1
fi

if [ ! -d "$PERSONAL_DIR" ]; then
  echo "error: $PERSONAL_DIR does not exist. Run 'claude' once and log in with" >&2
  echo "       your personal account before running this script." >&2
  exit 1
fi

mkdir -p "$TEAM_DIR"
echo "Team config dir: $TEAM_DIR"

link() {  # link <target-in-personal> <link-in-team>
  local target="$1" link="$2"
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$target" ]; then
      echo "  ok       $link -> $target"; return
    fi
    echo "  relink   $link -> $target"
    ln -sfn "$target" "$link"; return
  fi
  if [ -e "$link" ]; then
    local bak="$link.bak.$(date +%Y%m%d%H%M%S)"
    echo "  backup   $link -> $bak (existing non-symlink moved aside)"
    mv "$link" "$bak"
  fi
  echo "  link     $link -> $target"
  ln -sfn "$target" "$link"
}

echo "Sharing files:"
for f in "${SHARED_FILES[@]}"; do
  if [ -e "$PERSONAL_DIR/$f" ]; then
    link "$PERSONAL_DIR/$f" "$TEAM_DIR/$f"
  else
    echo "  skip     $PERSONAL_DIR/$f (not present)"
  fi
done

echo "Sharing directories:"
for d in "${SHARED_DIRS[@]}"; do
  mkdir -p "$PERSONAL_DIR/$d"
  link "$PERSONAL_DIR/$d" "$TEAM_DIR/$d"
done

# ---------------------------------------------------------------------------
# Shell alias
case "$(basename "${SHELL:-bash}")" in
  zsh)  RC="$HOME/.zshrc" ;;
  bash) if [ "$(uname)" = "Darwin" ]; then RC="$HOME/.bash_profile"; else RC="$HOME/.bashrc"; fi ;;
  *)    RC="$HOME/.profile" ;;
esac

ALIAS_LINE="alias $ALIAS_NAME='CLAUDE_CONFIG_DIR=$TEAM_DIR claude'"
if grep -qF "alias $ALIAS_NAME=" "$RC" 2>/dev/null; then
  echo "Alias '$ALIAS_NAME' already present in $RC"
else
  {
    echo ""
    echo "# multi-claude: personal account is plain 'claude'; Team account via '$ALIAS_NAME'"
    echo "$ALIAS_LINE"
  } >> "$RC"
  echo "Added alias to $RC"
fi

cat <<MSG

Done. Next steps:
  1. Reload your shell:          source $RC
  2. Log the Team profile in:    $ALIAS_NAME
     (first launch opens a browser - sign in with the TEAM account)
  3. Check inside the session:   /status   -> should show the Team org
  4. Plain 'claude' is unchanged and stays on your personal account.

To continue a conversation across accounts, run from the same project folder:
  claude            # ... hit the usage limit ...
  $ALIAS_NAME -c    # continues the most recent session in this folder
MSG
