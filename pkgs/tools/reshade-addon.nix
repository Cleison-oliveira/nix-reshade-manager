{
  pkgs,
  reshade,
}:
pkgs.writeShellScriptBin "reshade-addon" ''
  set -euo pipefail

  ADDONS_STORE="${reshade}/share/reshade/optional-addons"
  TARGET_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/reshade"

  show_help() {
    cat << HELP
reshade-addon - Manage optional ReShade addons

USAGE:
  reshade-addon list                 List available addons and status
  reshade-addon enable <name>        Enable an addon (e.g. fps_limit)
  reshade-addon disable <name>       Disable an addon
  reshade-addon enable-all           Enable all addons
  reshade-addon disable-all          Disable all addons
HELP
  }

  mkdir -p "$TARGET_DIR"

  cmd="''${1:-list}"
  case "$cmd" in
    list)
      echo "Available ReShade Addons:"
      for addon in "$ADDONS_STORE"/*.addon64; do
        [ -e "$addon" ] || continue
        name=$(basename "$addon" .addon64)
        if [ -e "$TARGET_DIR/$name.addon64" ]; then
          echo "  [ENABLED]  $name"
        else
          echo "  [DISABLED] $name"
        fi
      done
      ;;
    enable)
      [ -n "''${2:-}" ] || { echo "Error: specify addon name." >&2; exit 1; }
      name="$2"
      [ -f "$ADDONS_STORE/$name.addon64" ] || { echo "Error: Addon '$name' not found in $ADDONS_STORE." >&2; exit 1; }
      cp -f "$ADDONS_STORE/$name.addon64" "$TARGET_DIR/$name.addon64"
      echo "Addon '$name' enabled in $TARGET_DIR."
      ;;
    disable)
      [ -n "''${2:-}" ] || { echo "Error: specify addon name." >&2; exit 1; }
      name="$2"
      if [ -f "$TARGET_DIR/$name.addon64" ]; then
        rm -f "$TARGET_DIR/$name.addon64"
        echo "Addon '$name' disabled."
      else
        echo "Addon '$name' was not active."
      fi
      ;;
    enable-all)
      cp -f "$ADDONS_STORE"/*.addon64 "$TARGET_DIR/"
      echo "All addons enabled in $TARGET_DIR."
      ;;
    disable-all)
      rm -f "$TARGET_DIR"/*.addon64
      echo "All addons disabled in $TARGET_DIR."
      ;;
    -h|--help|help)
      show_help
      ;;
    *)
      show_help
      exit 1
      ;;
  esac
''
