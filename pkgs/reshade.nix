{
  pkgs,
  lib ? pkgs.lib,
  version ? "6.8.0-beta.3",
  builtinPacks ? {},
  extraPacks ? {},
  keyOverlay ? "117,0,1,0",
  keyEffects ? "116,0,1,0",
  disableWelcomeBar ? true,
}: let
  availableDefaultPacks = (import ./default-packs.nix) pkgs;

  # Filter active built-in packs based on user preferences (default to true)
  activeDefaultPacks = lib.filterAttrs (name: pack:
    if builtinPacks ? ${name}
    then builtinPacks.${name}
    else true
  ) availableDefaultPacks;

  # Script to copy a shader pack into the output directory
  copyPackScript = name: pack: let
    src = if builtins.isAttrs pack && pack ? src then pack.src else pack;
    sSub = if builtins.isAttrs pack && pack ? shadersSubdir then pack.shadersSubdir else "Shaders";
    tSub = if builtins.isAttrs pack && pack ? texturesSubdir then pack.texturesSubdir else "Textures";
    targSSub = if builtins.isAttrs pack && pack ? targetShadersSubdir then pack.targetShadersSubdir else "";
    targTSub = if builtins.isAttrs pack && pack ? targetTexturesSubdir then pack.targetTexturesSubdir else "";
  in ''
    # Copiar pack: ${name}
    target_s="$out/share/reshade/reshade-shaders/Shaders/${targSSub}"
    target_t="$out/share/reshade/reshade-shaders/Textures/${targTSub}"
    mkdir -p "$target_s" "$target_t"

    if [ -d "${src}/${sSub}" ]; then
      cp -rn "${src}/${sSub}/"* "$target_s/" 2>/dev/null || true
    elif [ -d "${src}/shaders" ]; then
      cp -rn "${src}/shaders/"* "$target_s/" 2>/dev/null || true
    else
      find "${src}" -maxdepth 2 \( -name "*.fx" -o -name "*.fxh" \) -exec cp -n {} "$target_s/" + 2>/dev/null || true
    fi

    if [ -d "${src}/${tSub}" ]; then
      cp -rn "${src}/${tSub}/"* "$target_t/" 2>/dev/null || true
    elif [ -d "${src}/textures" ]; then
      cp -rn "${src}/textures/"* "$target_t/" 2>/dev/null || true
    fi
  '';
in
  pkgs.stdenv.mkDerivation rec {
    pname = "reshade-linux-vulkan";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/TheForgotten69/reshade/releases/download/v${version}/reshade-linux-vulkan-v${version}-x86_64.tar.xz";
      hash = "sha256-yICzjNRnvnOPDxH9JQjbdIwcE6lJNVQM+vzdCo79iUs=";
    };

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      python3
    ];

    buildInputs = with pkgs; [
      wayland
      libxkbcommon
      libxcb
      libxcb-cursor
      fontconfig
      stdenv.cc.cc.lib
      vulkan-loader
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/reshade \
               $out/share/vulkan/implicit_layer.d \
               $out/share/reshade/optional-addons \
               $out/share/reshade/reshade-shaders/Shaders \
               $out/share/reshade/reshade-shaders/Textures

      cp lib/reshade/ReShade64.so $out/lib/reshade/ReShade64_orig.so
      cp optional-addons/*.addon64 $out/share/reshade/optional-addons/

      ${lib.optionalString disableWelcomeBar ''
        # Patch binario para desativar a exibicao forcada do tutorial/splash inicial
        python3 -c '
with open("'"$out/lib/reshade/ReShade64_orig.so"'", "rb") as f:
    data = bytearray(f.read())
pattern = b"\xc6\x83\x50\x05\x00\x00\x01"
idx = data.find(pattern)
if idx != -1:
    data[idx + 6] = 0x00
with open("'"$out/lib/reshade/ReShade64_orig.so"'", "wb") as f:
    f.write(data)
'
      ''}

      # Copiar o filtro Vulkan e compilar
      cp ${./loader_filter.c} loader_filter.c
      substituteInPlace loader_filter.c \
        --replace-fail "@ORIG_RESHADE_SO@" "$out/lib/reshade/ReShade64_orig.so"

      $CC -shared -fPIC -O2 \
        -DDEFAULT_KEY_EFFECTS=\"${keyEffects}\" \
        -DDEFAULT_KEY_OVERLAY=\"${keyOverlay}\" \
        -Wl,-rpath,$out/lib/reshade \
        -o $out/lib/reshade/ReShade64.so loader_filter.c -ldl

      # Shaders padrao oficiais do pacote ReShade
      cp -r share/reshade/reshade-shaders/Shaders/* $out/share/reshade/reshade-shaders/Shaders/
      cp -r share/reshade/reshade-shaders/Textures/* $out/share/reshade/reshade-shaders/Textures/

      # Copiar colecoes padrao ativadas declarativamente
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList copyPackScript activeDefaultPacks)}

      # Copiar colecoes customizadas declarativas adicionais
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList copyPackScript extraPacks)}

      chmod -R u+w "$out/share/reshade/reshade-shaders"

      # Normaliza includes com barras invertidas do Windows (".\Includes\...")
      find "$out/share/reshade/reshade-shaders/Shaders" -type f \( -name "*.fx" -o -name "*.fxh" \) \
        -exec sed -i '/^[[:space:]]*#include/ s|\\|/|g' {} + 2>/dev/null || true

      # Symlinks de compatibilidade para includes case-sensitive
      for sdir in "$out/share/reshade/reshade-shaders/Shaders"; do
        [ -f "$sdir/ReShade.fxh" ] && ln -sf ReShade.fxh "$sdir/Reshade.fxh" && ln -sf ReShade.fxh "$sdir/reshade.fxh"
        [ -f "$sdir/ReShadeUI.fxh" ] && ln -sf ReShadeUI.fxh "$sdir/ReshadeUI.fxh" && ln -sf ReShadeUI.fxh "$sdir/reshadeui.fxh"
      done
      find $out/share/reshade -name "*.fx" -exec sed -i 's/"Reshade\.fxh"/"ReShade\.fxh"/g' {} + 2>/dev/null || true

      # Manifesto Vulkan principal para RESHADE=1
      cat << 'MANIFEST_EOF' > $out/share/vulkan/implicit_layer.d/ReShade.json
{
    "file_format_version" : "1.0.0",
    "layer" : {
      "name": "VK_LAYER_RESHADE_overlay_x86_64",
      "type": "GLOBAL",
      "api_version": "1.3.0",
      "library_path": "$out/lib/reshade/ReShade64.so",
      "implementation_version": "1",
      "description": "ReShade post-processing injector",
      "functions": {
         "vkNegotiateLoaderLayerInterfaceVersion": "vkNegotiateLoaderLayerInterfaceVersion"
      },
      "enable_environment": {
        "RESHADE": "1"
      },
      "disable_environment": {
        "DISABLE_RESHADE": "1"
      }
    }
}
MANIFEST_EOF

      substituteInPlace $out/share/vulkan/implicit_layer.d/ReShade.json \
        --replace-fail '$out' "$out"

      # Manifesto Vulkan de compatibilidade retroativa para RESHADE_ENABLE=1
      cat << 'MANIFEST_EOF' > $out/share/vulkan/implicit_layer.d/ReShade64.json
{
    "file_format_version" : "1.0.0",
    "layer" : {
      "name": "VK_LAYER_RESHADE_legacy_x86_64",
      "type": "GLOBAL",
      "api_version": "1.3.0",
      "library_path": "$out/lib/reshade/ReShade64.so",
      "implementation_version": "1",
      "description": "ReShade post-processing injector (legacy RESHADE_ENABLE)",
      "functions": {
         "vkNegotiateLoaderLayerInterfaceVersion": "vkNegotiateLoaderLayerInterfaceVersion"
      },
      "enable_environment": {
        "RESHADE_ENABLE": "1"
      },
      "disable_environment": {
        "DISABLE_RESHADE": "1"
      }
    }
}
MANIFEST_EOF

      substituteInPlace $out/share/vulkan/implicit_layer.d/ReShade64.json \
        --replace-fail '$out' "$out"

      runHook postInstall
    '';

    preFixup = ''
      patchelf --add-rpath "$out/lib/reshade" $out/share/reshade/optional-addons/*.addon64 2>/dev/null || true
    '';

    meta = {
      description = "ReShade post-processing injector for Linux Vulkan with declarative management";
      homepage = "https://github.com/Cleison-oliveira/nix-reshade-manager";
      license = lib.licenses.bsd3;
      platforms = ["x86_64-linux"];
    };
  }
