#!/usr/bin/env sh
# Makes claude-pull/claude-push/claude-sync-report/claude-profile available as plain
# commands: symlinks them into ~/.local/bin and, if that directory isn't on
# $PATH yet, adds it to ~/.bashrc. Safe to re-run (idempotent).
# Usage:  ./setup.sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BASHRC="$HOME/.bashrc"
PATH_MARKER="# added by claude-multi-profile-sync-drive/setup.sh"

mkdir -p "$BIN_DIR"

echo "== Linking scripts into $BIN_DIR =="
for name in claude-pull claude-push claude-sync-report claude-profile; do
  target="$BIN_DIR/$name"
  src="$SCRIPT_DIR/$name"
  if [ -L "$target" ] && [ "$(readlink -f -- "$target")" = "$src" ]; then
    echo "  $name: already linked, skipping"
  elif [ -e "$target" ]; then
    echo "  $name: $target already exists and is NOT our symlink - leaving it alone" >&2
  else
    ln -s "$src" "$target"
    echo "  $name: linked"
  fi
done

echo "== Checking \$PATH =="
case ":$PATH:" in
  *":$BIN_DIR:"*)
    echo "  $BIN_DIR is already on \$PATH."
    ;;
  *)
    if [ -f "$BASHRC" ] && grep -qF "$BIN_DIR" "$BASHRC"; then
      echo "  $BIN_DIR is already referenced in $BASHRC, but not active in this shell."
      echo "  Open a new terminal or run: . $BASHRC"
    else
      printf '\n%s\nexport PATH="%s:$PATH"\n' "$PATH_MARKER" "$BIN_DIR" >> "$BASHRC"
      echo "  Added $BIN_DIR to \$PATH in $BASHRC."
      echo "  Open a new terminal or run: . $BASHRC"
    fi
    ;;
esac

echo "== Checking profiles/ =="
if find "$SCRIPT_DIR/profiles" -maxdepth 1 -name '*.conf' -print -quit 2>/dev/null | grep -q .; then
  echo "  Found existing profile(s):"
  find "$SCRIPT_DIR/profiles" -maxdepth 1 -name '*.conf' -exec basename {} .conf \; | sort | sed 's/^/    /'
else
  echo "  No profiles/*.conf found yet. Copy one of the templates and edit it, e.g.:"
  echo "    cp $SCRIPT_DIR/profiles/private.conf.example $SCRIPT_DIR/profiles/private.conf"
fi

echo "== Done =="
