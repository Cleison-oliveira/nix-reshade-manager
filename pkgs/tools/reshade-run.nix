{
  pkgs,
  reshade,
}:
pkgs.writeShellScriptBin "reshade-run" ''
  set -euo pipefail

  show_help() {
    cat << "HELP"
reshade-run - Native ReShade launcher for Linux Vulkan

USAGE:
  reshade-run [OPTIONS] <command> [args...]
  reshade-run %command%                  (Launcher launch options syntax)
  reshade-run flatpak run <app-id>       (Flatpak applications)

ENVIRONMENT VARIABLES:
  RESHADE=1 <command>                    Enable ReShade via environment variable
  RESHADE_ENABLE=1 <command>             Alternative syntax
  DISABLE_RESHADE=1 <command>            Explicitly disable ReShade

OPTIONS:
  -p, --profile <NAME>  Set an explicit ReShade profile
                        (Configs in ~/.local/share/reshade/configurations/<NAME>)
  -w, --wayland         Enable PROTON_ENABLE_WAYLAND=1 (Wine Wayland native)
  -n, --no-log          Enable RESHADE_DISABLE_LOGGING=1 (disable log generation)
  -h, --help            Show this help message

HOTKEYS & INTERFACE:
  - Standard hotkeys (configurable declaratively via Nix):
      * Toggle effects: Shift + F5
      * Open/close ReShade menu: Shift + F6
  - All settings (themes, hotkeys, presets, and shaders)
    are saved directly in the in-game ReShade overlay.
HELP
  }

  if [ $# -eq 0 ]; then
    show_help
    exit 1
  fi

  PROFILE=""
  WAYLAND=0
  NO_LOG=0

  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -w|--wayland)
        WAYLAND=1
        shift
        ;;
      -p|--profile)
        [ -n "''${2:-}" ] || { echo "Error: --profile requires a name." >&2; exit 1; }
        PROFILE="$2"
        shift 2
        ;;
      -n|--no-log)
        NO_LOG=1
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  [ $# -gt 0 ] || { echo "Error: No command specified." >&2; exit 1; }

  BASE_RESHADE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/reshade"
  CONFIGS_DIR="$BASE_RESHADE_DIR/configurations"
  SHADERS_DIR="$BASE_RESHADE_DIR/reshade-shaders"
  mkdir -p "$CONFIGS_DIR"

  # Set explicit profile if requested
  if [ -n "$PROFILE" ]; then
    export RESHADE_PROFILE="$PROFILE"
  fi

  export RESHADE=1
  export RESHADE_ENABLE=1
  export VK_LOADER_LAYERS_DISABLE="''${VK_LOADER_LAYERS_DISABLE:+''$VK_LOADER_LAYERS_DISABLE:}VK_LAYER_reshade_x86_64"
  export XDG_DATA_DIRS="${reshade}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
  [ "$WAYLAND" -eq 1 ] && export PROTON_ENABLE_WAYLAND=1
  [ "$NO_LOG" -eq 1 ] && export RESHADE_DISABLE_LOGGING=1

  # Flatpak compatibility
  if [ "$(basename "$1")" = "flatpak" ]; then
    FLATPAK_ARGS=()
    FOUND_RUN=0
    for arg in "$@"; do
      FLATPAK_ARGS+=("$arg")
      if [ "$arg" = "run" ] && [ "$FOUND_RUN" -eq 0 ]; then
        FOUND_RUN=1
        FLATPAK_ARGS+=(
          "--env=VK_ADD_LAYER_PATH=$HOME/.local/share/vulkan/implicit_layer.d"
          "--env=RESHADE=1"
          "--env=RESHADE_ENABLE=1"
          "--filesystem=$BASE_RESHADE_DIR:rw"
          "--filesystem=$HOME/.local/share/vulkan:ro"
        )
        [ -n "$PROFILE" ] && FLATPAK_ARGS+=("--env=RESHADE_PROFILE=$PROFILE")
        [ "$NO_LOG" -eq 1 ] && FLATPAK_ARGS+=("--env=RESHADE_DISABLE_LOGGING=1")
      fi
    done
    exec "''${FLATPAK_ARGS[@]}"
  fi

  exec "$@"
''
