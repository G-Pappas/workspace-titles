# Workspace Titles

Every workspace gets a title. Switch workspace and a small card appears under the bar clock with its number and title, a pencil to rename it and a cross to close it. It closes by itself after 10 seconds.

- **Automatic titles**: a workspace without a custom title is named after its focused window ("Ghostty +1", "Google Chrome"), or by your default text when empty. It is never blank. Rename it and the name is yours; save an empty name to go back to automatic.
- **Rename**: click the title or the pencil, type, Enter to save, Esc to cancel. `SUPER + ALT + R` renames the current workspace without switching; right-click the bar button does the same.
- **Bar button** (a tag icon, centerEnd by default): click for all ten workspaces (click a row to switch, pencil to rename) and the settings below.

## Settings

Saved in `~/.config/omarchy/extensions/ws-title.json`:

| Setting | Default | |
|---|---|---|
| Show on workspace switch | on | turn the popup off entirely |
| Show | Number + title | `Number + title`, `Title`, or `Number only` |
| Seconds before it closes | 10 | 1 to 120 |
| Name new workspaces after their window | on | off: use the default text |
| Default text | `Workspace {n}` | `{n}` is the workspace number |
| Keep open while hovered | on | |
| Gap below the bar | 8 px | |

Titles are in `~/.local/state/ws-titles.json`.

## Install

Drop this folder into `~/.config/omarchy/plugins/gpappas.ws-title/`, then `omarchy plugin enable gpappas.ws-title`. The plugin offers once, by notification, to add the `SUPER + ALT + R` line to `~/.config/hypr/bindings.lua` (a backup is saved first); or run `setup.sh apply`.

## IPC

`omarchy-shell gpappas.ws-title show | rename | renameWs <n> | setTitle <n> <text> | hide`
