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
reshade-install-shaders - Instalador e sincronizador da biblioteca de shaders do ReShade

USO:
  reshade-install-shaders [OPCOES]

OPCOES:
  -s, --sync (padrao)   Sincroniza os shaders sem sobrescrever modificacoes locais
  -f, --force           Restaura uma copia limpa de todos os shaders e texturas
  -h, --help            Exibe esta ajuda
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
    echo "-> Restaurando shaders e texturas (sobrescrevendo)..."
    cp -rf "$SRC_DIR"/* "$TARGET_DIR/"
  else
    echo "-> Sincronizando shaders e texturas para $TARGET_DIR..."
    cp -rn "$SRC_DIR"/* "$TARGET_DIR/" 2>/dev/null || true
  fi

  chmod -R u+w "$TARGET_DIR" 2>/dev/null || true

  shader_count=$(find "$TARGET_DIR/Shaders" -name "*.fx" 2>/dev/null | wc -l)
  texture_count=$(find "$TARGET_DIR/Textures" -type f 2>/dev/null | wc -l)

  echo "==> Concluido com sucesso!"
  echo "    Localizacao: $TARGET_DIR"
  echo "    Efeitos (.fx) disponiveis: $shader_count"
  echo "    Texturas/LUTs disponiveis:  $texture_count"
''
