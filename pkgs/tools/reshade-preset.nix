{pkgs}:
pkgs.writeShellScriptBin "reshade-preset" ''
  set -euo pipefail

  BASE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/reshade"
  CONFIGS_DIR="$BASE_DIR/configurations"

  show_help() {
    cat << HELP
reshade-preset - Inspect ReShade configuration paths and presets

NOTE:
  Presets (.ini), themes, and hotkeys can be edited directly inside
  the running game via the ReShade menu (Shift + F6).

USAGE:
  reshade-preset list                List existing profiles and presets
  reshade-preset dir [profile]       Print path to profile configurations
  reshade-preset help                Show this help message
HELP
  }

  cmd="''${1:-list}"
  case "$cmd" in
    list)
      echo "ReShade profiles in $CONFIGS_DIR:"
      if [ -d "$CONFIGS_DIR" ]; then
        for p in "$CONFIGS_DIR"/*; do
          [ -d "$p" ] || continue
          pname=$(basename "$p")
          echo "  Profile: $pname"
          if [ -f "$p/ReShade.ini" ]; then
            preset=$(grep -E "^PresetPath=" "$p/ReShade.ini" 2>/dev/null | cut -d= -f2- || echo "ReShadePreset.ini")
            echo "    Active preset: $preset"
          fi
          for f in "$p"/*.ini; do
            [ -e "$f" ] || continue
            fb=$(basename "$f")
            [ "$fb" = "ReShade.ini" ] || echo "    - $fb"
          done
        done
      fi
      ;;
    dir)
      if [ -n "''${2:-}" ]; then
        echo "$CONFIGS_DIR/$2"
      else
        echo "$CONFIGS_DIR"
      fi
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
