#!/usr/bin/env bash
# Hooks bindings.lua into ~/.config/hypr/bindings.lua, but only with the user's
# consent.
#   setup.sh        asks through a desktop notification (once), then applies
#   setup.sh apply  applies right away (the explicit, manual way)
# Applying backs the file up first and is safe to repeat.
set -u

bindings="$HOME/.config/hypr/bindings.lua"
marker="-- >>> gpappas.ws-title"
state="${XDG_STATE_HOME:-$HOME/.local/state}/gpappas.ws-title"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apply() {
  [ -f "$bindings" ] || { echo "no $bindings, nothing to hook into"; return 0; }
  grep -qF -- "$marker" "$bindings" && { echo "already hooked up"; return 0; }

  # Build the new file beside the old one and swap it in only when the backup
  # and every write succeeded, so a failure leaves bindings.lua untouched.
  local backup="$bindings.bak.$(date +%s)"
  local staged
  staged="$(mktemp "$bindings.ws-title.XXXXXX")" || { echo "cannot stage the change, bindings.lua left alone" >&2; return 1; }

  if ! cp -p "$bindings" "$backup"; then
    rm -f "$staged"
    echo "backup failed, bindings.lua left alone" >&2
    return 1
  fi
  if ! { cat "$bindings" && cat <<'LUA'

-- >>> gpappas.ws-title: added by the Workspace Titles plugin (SUPER + ALT + R). Skipped once the plugin is removed.
do local p = os.getenv("HOME") .. "/.config/omarchy/plugins/gpappas.ws-title/bindings.lua" local f = io.open(p) if f then f:close() dofile(p) end end
-- <<< gpappas.ws-title
LUA
  } > "$staged"; then
    rm -f "$staged"
    echo "could not write the change, bindings.lua left alone (backup: $backup)" >&2
    return 1
  fi
  if ! chmod --reference="$bindings" "$staged" || ! mv -f "$staged" "$bindings"; then
    rm -f "$staged"
    echo "could not replace bindings.lua, left alone (backup: $backup)" >&2
    return 1
  fi

  hyprctl reload >/dev/null 2>&1
  echo "hooked into bindings.lua (SUPER + ALT + R), backup: $backup"
}

if [ "${1:-}" = "apply" ]; then apply; exit $?; fi

[ -f "$bindings" ] || exit 0
grep -qF -- "$marker" "$bindings" && exit 0   # already set up
[ -e "$state/asked" ] && exit 0            # asked before, never nag
mkdir -p "$state" && : > "$state/asked"

answer=$(notify-send --wait --app-name="Workspace Titles" --action=setup="Add SUPER + ALT + R" \
  "Workspace Titles needs one change" \
  "Add one line to ~/.config/hypr/bindings.lua to enable SUPER + ALT + R? A backup is saved first. To do it later, run: $here/setup.sh apply" 2>/dev/null)
[ "$answer" = "setup" ] && apply
exit 0
