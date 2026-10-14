{pkgs}:
pkgs.writeShellScriptBin "reshade-preset" ''
  set -euo pipefail

  BASE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/reshade"
  CONFIGS_DIR="$BASE_DIR/configurations"

  show_help() {
    cat << HELP
reshade-preset - Informacoes e localizacao de perfis do ReShade

NOTA:
  Todos os presets (.ini), temas visuais e atalhos de teclado sao gerenciados
  diretamente dentro do jogo pela interface nativa do ReShade (Shift+F6).

USO:
  reshade-preset list                Lista os perfis e presets existentes
  reshade-preset dir [perfil]        Exibe o caminho das configuracoes
  reshade-preset help                Exibe esta ajuda
HELP
  }

  cmd="''${1:-list}"
  case "$cmd" in
    list)
      echo "=== Perfis do ReShade em $CONFIGS_DIR ==="
      if [ -d "$CONFIGS_DIR" ]; then
        for p in "$CONFIGS_DIR"/*; do
          [ -d "$p" ] || continue
          pname=$(basename "$p")
          echo "  Perfil: $pname"
          if [ -f "$p/ReShade.ini" ]; then
            preset=$(grep -E "^PresetPath=" "$p/ReShade.ini" 2>/dev/null | cut -d= -f2- || echo "ReShadePreset.ini")
            echo "    Preset ativo: $preset"
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
