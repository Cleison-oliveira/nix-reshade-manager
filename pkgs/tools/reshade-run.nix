{
  pkgs,
  reshade,
}:
pkgs.writeShellScriptBin "reshade-run" ''
  set -euo pipefail

  show_help() {
    cat << "HELP"
reshade-run - Inicializador nativo do ReShade para Linux Vulkan

USO:
  reshade-run [OPCOES] <comando> [argumentos...]
  reshade-run %command%                  (Nas Opcoes de Inicializacao da Steam)
  reshade-run flatpak run <app-id>       (Para jogos/emuladores Flatpak)

VARIAVEIS DE AMBIENTE (alternativa para non-Steam games, Heronite, Heroic, Lutris):
  RESHADE=1 <comando>                    Ativa o ReShade diretamente via variavel
  RESHADE_ENABLE=1 <comando>             Sintaxe alternativa compativel

OPCOES:
  -p, --profile <NOME>  Define um perfil explicito do ReShade
                        (Configuracoes em ~/.local/share/reshade/configurations/<NOME>)
  -w, --wayland         Ativa PROTON_ENABLE_WAYLAND=1 (Wine Wayland nativo)
  -n, --no-log          Ativa RESHADE_DISABLE_LOGGING=1 (desativa gravacao de logs)
  -h, --help            Exibe esta ajuda

CONFIGURACOES E INTERFACE:
  - Atalhos padronizados (ou configurados declarativamente via Nix):
      * Ativar / Desativar efeitos: Shift + F5
      * Abrir / Fechar menu de configuracao: Shift + F6
  - Todas as configuracoes (temas, estilos, atalhos de teclado, presets e shaders)
    sao salvas e gerenciadas diretamente na interface nativa do ReShade.
  - O ReShade mantem suas escolhas preservadas automaticamente no ReShade.ini.
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
        [ -n "''${2:-}" ] || { echo "Erro: --profile requer um nome." >&2; exit 1; }
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

  [ $# -gt 0 ] || { echo "Erro: Nenhum comando especificado." >&2; exit 1; }

  BASE_RESHADE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/reshade"
  CONFIGS_DIR="$BASE_RESHADE_DIR/configurations"
  SHADERS_DIR="$BASE_RESHADE_DIR/reshade-shaders"
  mkdir -p "$CONFIGS_DIR"

  # Define perfil explicito se solicitado
  if [ -n "$PROFILE" ]; then
    export RESHADE_PROFILE="$PROFILE"
  fi

  export RESHADE=1
  export RESHADE_ENABLE=1
  export VK_LOADER_LAYERS_DISABLE="''${VK_LOADER_LAYERS_DISABLE:+''$VK_LOADER_LAYERS_DISABLE:}VK_LAYER_reshade_x86_64"
  export XDG_DATA_DIRS="${reshade}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
  [ "$WAYLAND" -eq 1 ] && export PROTON_ENABLE_WAYLAND=1
  [ "$NO_LOG" -eq 1 ] && export RESHADE_DISABLE_LOGGING=1

  # Execucao compativel com Flatpak
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
