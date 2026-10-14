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
reshade-addon - Gerenciador de addons opcionais do ReShade

USO:
  reshade-addon list                 Lista addons disponiveis e o status atual
  reshade-addon enable <nome>        Habilita um addon (ex: fps_limit)
  reshade-addon disable <nome>       Desabilita um addon
  reshade-addon enable-all           Habilita todos os addons
  reshade-addon disable-all          Desabilita todos os addons
HELP
  }

  mkdir -p "$TARGET_DIR"

  cmd="''${1:-list}"
  case "$cmd" in
    list)
      echo "=== Addons ReShade Disponiveis ==="
      for addon in "$ADDONS_STORE"/*.addon64; do
        [ -e "$addon" ] || continue
        name=$(basename "$addon" .addon64)
        if [ -e "$TARGET_DIR/$name.addon64" ]; then
          echo "  [ATIVADO]    $name"
        else
          echo "  [DESATIVADO] $name"
        fi
      done
      ;;
    enable)
      [ -n "''${2:-}" ] || { echo "Erro: Especifique o nome do addon." >&2; exit 1; }
      name="$2"
      [ -f "$ADDONS_STORE/$name.addon64" ] || { echo "Erro: Addon '$name' nao encontrado em $ADDONS_STORE." >&2; exit 1; }
      cp -f "$ADDONS_STORE/$name.addon64" "$TARGET_DIR/$name.addon64"
      echo "Addon '$name' ativado com sucesso em $TARGET_DIR."
      ;;
    disable)
      [ -n "''${2:-}" ] || { echo "Erro: Especifique o nome do addon." >&2; exit 1; }
      name="$2"
      if [ -f "$TARGET_DIR/$name.addon64" ]; then
        rm -f "$TARGET_DIR/$name.addon64"
        echo "Addon '$name' desativado."
      else
        echo "Addon '$name' nao estava ativo."
      fi
      ;;
    enable-all)
      cp -f "$ADDONS_STORE"/*.addon64 "$TARGET_DIR/"
      echo "Todos os addons foram ativados em $TARGET_DIR."
      ;;
    disable-all)
      rm -f "$TARGET_DIR"/*.addon64
      echo "Todos os addons foram desativados de $TARGET_DIR."
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
