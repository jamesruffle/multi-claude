#!/usr/bin/env bash
# multi-claude: run any number of Claude accounts side-by-side in Claude Code.
#
#   claude         -> personal account (default, uses ~/.claude)
#   claude-<name>  -> extra account    (uses ~/.claude-<name>)
#
# Usage:
#   ./setup.sh                    # one extra profile: claude-team (original behaviour)
#   ./setup.sh team work lab      # claude-team, claude-work, claude-lab
#   ./setup.sh --list             # show profiles this script has installed
#   ./setup.sh --remove work      # remove claude-work (alias + ~/.claude-work)
#
# Every profile shares settings, CLAUDE.md, skills/agents/commands and the
# session store with ~/.claude, so `claude-<name> -c` can pick up a
# conversation started with any other profile. Credentials and login state
# stay separate.
#
# Safe to re-run. Works on macOS and Linux (bash or zsh).

set -euo pipefail

PERSONAL_DIR="${CLAUDE_PERSONAL_DIR:-$HOME/.claude}"

# Files/dirs shared between profiles (symlinked profile -> personal).
SHARED_FILES=(settings.json CLAUDE.md)
SHARED_DIRS=(projects skills agents commands)

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# Shell rc file that holds the aliases
case "$(basename "${SHELL:-bash}")" in
  zsh)  RC="$HOME/.zshrc" ;;
  bash) if [ "$(uname)" = "Darwin" ]; then RC="$HOME/.bash_profile"; else RC="$HOME/.bashrc"; fi ;;
  *)    RC="$HOME/.profile" ;;
esac

# Normalise a profile name: accept "work" or "claude-work"; reject anything
# that isn't safe in an alias / directory name.
normalise() {
  local name="${1#claude-}"
  if [ -z "$name" ] || ! [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "error: invalid profile name '$1' (use letters, digits, '-' or '_')" >&2
    exit 1
  fi
  if [ "$name" = "claude" ]; then
    echo "error: 'claude' is the personal profile and cannot be added/removed" >&2
    exit 1
  fi
  printf '%s' "$name"
}

link() {  # link <target-in-personal> <link-in-profile>
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

# ---------------------------------------------------------------------------
list_profiles() {
  echo "Personal:  claude -> $PERSONAL_DIR"
  local found=0 line alias_name dir state
  if [ -f "$RC" ]; then
    while IFS= read -r line; do
      alias_name="${line#alias }"; alias_name="${alias_name%%=*}"
      dir="${line#*CLAUDE_CONFIG_DIR=}"; dir="${dir%% claude*}"
      if [ -d "$dir" ]; then state="ok"; else state="MISSING DIR"; fi
      printf '  %-20s -> %s  [%s]\n' "$alias_name" "$dir" "$state"
      found=1
    done < <(grep -E "^alias [A-Za-z0-9_-]+='CLAUDE_CONFIG_DIR=" "$RC" || true)
  fi
  [ "$found" = 1 ] || echo "  (no extra profiles found in $RC)"
}

add_profile() {  # add_profile <alias-name> <config-dir>
  local alias_name="$1" dir="$2"
  echo "== $alias_name ($dir)"
  mkdir -p "$dir"

  echo "Sharing files:"
  local f d
  for f in "${SHARED_FILES[@]}"; do
    if [ -e "$PERSONAL_DIR/$f" ]; then
      link "$PERSONAL_DIR/$f" "$dir/$f"
    else
      echo "  skip     $PERSONAL_DIR/$f (not present)"
    fi
  done

  echo "Sharing directories:"
  for d in "${SHARED_DIRS[@]}"; do
    mkdir -p "$PERSONAL_DIR/$d"
    link "$PERSONAL_DIR/$d" "$dir/$d"
  done

  local alias_line="alias $alias_name='CLAUDE_CONFIG_DIR=$dir claude'"
  if grep -qxF "$alias_line" "$RC" 2>/dev/null; then
    echo "Alias '$alias_name' already present in $RC"
  elif grep -qE "^alias $alias_name=" "$RC" 2>/dev/null; then
    echo "warning: '$alias_name' is already defined in $RC with a different value:" >&2
    grep -E "^alias $alias_name=" "$RC" | sed 's/^/           /' >&2
    echo "         Left unchanged. Remove it (./setup.sh --remove ${alias_name#claude-}) and re-run to replace." >&2
  else
    {
      echo ""
      echo "# multi-claude: '$alias_name' -> $dir"
      echo "$alias_line"
    } >> "$RC"
    echo "Added alias '$alias_name' to $RC"
  fi
  echo ""
}

remove_profile() {  # remove_profile <name>
  local name alias_name dir
  name="$(normalise "$1")"
  alias_name="claude-$name"
  dir="$HOME/.claude-$name"

  if [ -f "$RC" ] && grep -qE "^alias $alias_name=" "$RC"; then
    # Drop the alias line and its multi-claude comment (covers the old
    # "... Team account via 'claude-team'" comment too).
    local tmp
    tmp="$(mktemp)"
    grep -vE "^alias $alias_name=|^# multi-claude:.*'$alias_name'" "$RC" > "$tmp" || true
    cat "$tmp" > "$RC"; rm -f "$tmp"
    echo "Removed alias '$alias_name' from $RC"
  else
    echo "No alias '$alias_name' in $RC"
  fi

  if [ -d "$dir" ]; then
    # Shared items are symlinks, so rm -rf only removes the links, never the
    # files in $PERSONAL_DIR. What is actually deleted is this profile's login
    # and per-profile state (.credentials.json, .claude.json, history).
    local reply=""
    if [ -t 0 ]; then
      read -r -p "Delete $dir (this profile's login and local state)? [y/N] " reply
    fi
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      rm -rf "$dir"
      echo "Deleted $dir"
    else
      echo "Kept $dir (delete it yourself with: rm -rf $dir)"
    fi
  fi
}

# ---------------------------------------------------------------------------
MODE=add
NAMES=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)   usage; exit 0 ;;
    -l|--list)   MODE=list ;;
    -r|--remove) MODE=remove ;;
    -*)          echo "error: unknown option '$1'" >&2; usage >&2; exit 1 ;;
    *)           NAMES+=("$1") ;;
  esac
  shift
done

case "$MODE" in
  list)
    list_profiles; exit 0 ;;
  remove)
    if [ ${#NAMES[@]} -eq 0 ]; then
      echo "error: --remove needs at least one profile name" >&2; exit 1
    fi
    for n in "${NAMES[@]}"; do remove_profile "$n"; done
    echo ""
    echo "Reload your shell (source $RC) or open a new terminal; also run"
    echo "'unalias claude-<name>' in any terminal that is already open."
    exit 0 ;;
esac

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

ALIASES=()
if [ ${#NAMES[@]} -eq 0 ]; then
  # No names given: original single-profile behaviour, still honouring the
  # legacy CLAUDE_TEAM_DIR / CLAUDE_TEAM_ALIAS overrides.
  alias_name="${CLAUDE_TEAM_ALIAS:-claude-team}"
  add_profile "$alias_name" "${CLAUDE_TEAM_DIR:-$HOME/.claude-team}"
  ALIASES+=("$alias_name")
else
  for n in "${NAMES[@]}"; do
    name="$(normalise "$n")"
    add_profile "claude-$name" "$HOME/.claude-$name"
    ALIASES+=("claude-$name")
  done
fi

cat <<MSG
Done. Next steps:
  1. Reload your shell:          source $RC
  2. Log each new profile in (first launch opens a browser - sign in with
     the account you want that profile to use):
MSG
for a in "${ALIASES[@]}"; do echo "       $a"; done
cat <<MSG
  3. Check inside each session:  /status   -> should show that account
  4. Plain 'claude' is unchanged and stays on your personal account.

To continue a conversation across accounts, run from the same project folder:
  claude            # ... hit the usage limit ...
  ${ALIASES[0]} -c    # continues the most recent session in this folder

See all installed profiles:     ./setup.sh --list
MSG
