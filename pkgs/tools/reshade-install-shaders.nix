{
  pkgs,
  reshade,
}:
pkgs.writeShellScriptBin "reshade-install-shaders" ''
  set -euo pipefail

  TARGET_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/reshade/reshade-shaders"
  SRC_DIR="${reshade}/share/reshade/reshade-shaders"

  show_help() {
    cat << HELP
reshade-install-shaders - Sync and manage ReShade shader library

USAGE:
  reshade-install-shaders [OPTIONS]

OPTIONS:
  -s, --sync (default)  Synchronize shaders without overwriting local modifications
  -f, --force           Restore a fresh copy of all shaders and textures
  -h, --help            Show this help message
HELP
  }

  FORCE=0
  for arg in "$@"; do
    case "$arg" in
      -f|--force) FORCE=1 ;;
      -s|--sync) ;;
      -h|--help|help) show_help; exit 0 ;;
      *) show_help; exit 1 ;;
    esac
  done

  mkdir -p "$TARGET_DIR/Shaders" "$TARGET_DIR/Textures"

  if [ "$FORCE" -eq 1 ]; then
    echo "Restoring shaders and textures (overwriting)..."
    cp -rf "$SRC_DIR"/* "$TARGET_DIR/"
  else
    echo "Synchronizing shaders and textures to $TARGET_DIR..."
    cp -rn "$SRC_DIR"/* "$TARGET_DIR/" 2>/dev/null || true
  fi

  chmod -R u+w "$TARGET_DIR" 2>/dev/null || true

  shader_count=$(find "$TARGET_DIR/Shaders" -name "*.fx" 2>/dev/null | wc -l)
  texture_count=$(find "$TARGET_DIR/Textures" -type f 2>/dev/null | wc -l)

  echo "Synchronization complete."
  echo "  Location: $TARGET_DIR"
  echo "  Available shaders (.fx): $shader_count"
  echo "  Available textures/LUTs: $texture_count"
''
