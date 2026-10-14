{
  lib,
  stdenv,
  fetchFromGitHub,
  reshade-linux-vulkan,
  meson,
  ninja,
  pkg-config,
  xorg,
  vulkan-headers,
  vulkan-loader,
  builtinPacks ? {},
  extraPacks ? {},
  keyOverlay ? "117,0,1,0",
  keyEffects ? "116,0,1,0",
  disableWelcomeBar ? true,
}: let
  defaultPacks = (import ./default-packs.nix {inherit fetchFromGitHub;});

  # Filter active built-in packs based on user preferences (default to true)
  activeBuiltinPacks =
    lib.filterAttrs (
      name: pack:
        if builtinPacks ? ${name}
        then builtinPacks.${name}
        else true
    )
    defaultPacks;

  # Script to copy a shader pack into the output directory
  copyPack = name: pack: let
    src = pack.src or pack;
    shadersSubdir = pack.shadersSubdir or "Shaders";
    texturesSubdir = pack.texturesSubdir or "Textures";
    targetShadersSubdir = pack.targetShadersSubdir or "";
    targetTexturesSubdir = pack.targetTexturesSubdir or "";
  in ''
    # Copy pack: ${name}
    if [ -d "${src}/${shadersSubdir}" ]; then
      mkdir -p "$out/share/reshade/reshade-shaders/Shaders/${targetShadersSubdir}"
      cp -rn "${src}/${shadersSubdir}"/* "$out/share/reshade/reshade-shaders/Shaders/${targetShadersSubdir}/" 2>/dev/null || true
    fi
    if [ -d "${src}/${texturesSubdir}" ]; then
      mkdir -p "$out/share/reshade/reshade-shaders/Textures/${targetTexturesSubdir}"
      cp -rn "${src}/${texturesSubdir}"/* "$out/share/reshade/reshade-shaders/Textures/${targetTexturesSubdir}/" 2>/dev/null || true
    fi
    # If src is flat with .fx files directly
    if ls "${src}"/*.fx 1>/dev/null 2>&1; then
      mkdir -p "$out/share/reshade/reshade-shaders/Shaders/${targetShadersSubdir}"
      cp -rn "${src}"/*.fx "$out/share/reshade/reshade-shaders/Shaders/${targetShadersSubdir}/" 2>/dev/null || true
    fi
  '';

  copyBuiltinPacks = lib.concatStringsSep "\n" (lib.mapAttrsToList copyPack activeBuiltinPacks);
  copyExtraPacks = lib.concatStringsSep "\n" (lib.mapAttrsToList copyPack extraPacks);
in
  stdenv.mkDerivation {
    pname = "reshade-complete";
    version = "6.8.0-beta.3";

    srcs = [
      reshade-linux-vulkan
      ./loader_filter.c
    ];

    sourceRoot = ".";

    nativeBuildInputs = [pkg-config];
    buildInputs = [vulkan-headers];

    buildPhase = ''
      runHook preBuild
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib
      mkdir -p $out/share/vulkan/implicit_layer.d
      mkdir -p $out/share/reshade/reshade-shaders/Shaders
      mkdir -p $out/share/reshade/reshade-shaders/Textures
      mkdir -p $out/share/reshade/optional-addons

      # Copy raw upstream libraries
      cp -f ${reshade-linux-vulkan}/lib/libreShade.so $out/lib/libreShade_raw.so
      cp -f ${reshade-linux-vulkan}/lib/libreShade.so $out/lib/libreShade.so

      ${lib.optionalString disableWelcomeBar ''
        # Binary patch to suppress initial tutorial welcome banner
        sed -i 's/\x00Tutorial\x00/\x00Tutorial_Off\x00/g' $out/lib/libreShade_raw.so 2>/dev/null || true
        sed -i 's/\x00Tutorial\x00/\x00Tutorial_Off\x00/g' $out/lib/libreShade.so 2>/dev/null || true
      ''}

      # Compile transparent loader filter
      $CC -O3 -fPIC -shared -Wall \
        -DDEFAULT_KEY_OVERLAY="\"${keyOverlay}\"" \
        -DDEFAULT_KEY_EFFECTS="\"${keyEffects}\"" \
        ${./loader_filter.c} \
        -o $out/lib/libReShade_loader_filter.so \
        -ldl

      # Copy default official shaders
      cp -r ${reshade-linux-vulkan}/share/reshade/reshade-shaders/Shaders/* $out/share/reshade/reshade-shaders/Shaders/ || true
      cp -r ${reshade-linux-vulkan}/share/reshade/reshade-shaders/Textures/* $out/share/reshade/reshade-shaders/Textures/ || true

      # Copy enabled built-in packs
      ${copyBuiltinPacks}

      # Copy custom extra packs
      ${copyExtraPacks}

      # Copy optional addons if available
      cp -rf ${reshade-linux-vulkan}/share/reshade/*.addon64 $out/share/reshade/optional-addons/ 2>/dev/null || true

      # Normalize backslash include directives
      find "$out/share/reshade/reshade-shaders/Shaders" -type f \( -name "*.fx" -o -name "*.fxh" \) \
        -exec sed -i '/^[[:space:]]*#include/ s|\\|/|g' {} + 2>/dev/null || true

      # Compatibility symlinks for case-sensitive includes
      for f in "$out/share/reshade/reshade-shaders/Shaders"/*; do
        if [ -d "$f" ]; then
          b=$(basename "$f")
          lb=$(echo "$b" | tr '[:upper:]' '[:lower:]')
          if [ "$b" != "$lb" ] && [ ! -e "$out/share/reshade/reshade-shaders/Shaders/$lb" ]; then
            ln -sf "$b" "$out/share/reshade/reshade-shaders/Shaders/$lb"
          fi
        fi
      done

      # Main Vulkan manifest for RESHADE=1
      cat << 'JSON' > $out/share/vulkan/implicit_layer.d/ReShade.json
      {
        "file_format_version": "1.0.0",
        "layer": {
          "name": "VK_LAYER_RESHADE_overlay_x86_64",
          "type": "GLOBAL",
          "library_path": "OUT_DIR/lib/libReShade_loader_filter.so",
          "api_version": "1.3.0",
          "implementation_version": "1",
          "description": "ReShade overlay layer with intelligent process filter",
          "functions": {
            "vkNegotiateLoaderLayerInterfaceVersion": "vkNegotiateLoaderLayerInterfaceVersion",
            "vkGetInstanceProcAddr": "vkGetInstanceProcAddr"
          },
          "enable_environment": {
            "RESHADE": "1"
          },
          "disable_environment": {
            "DISABLE_RESHADE": "1"
          }
        }
      }
      JSON
      sed -i "s|OUT_DIR|$out|g" $out/share/vulkan/implicit_layer.d/ReShade.json

      # Backward compatibility Vulkan manifest for RESHADE_ENABLE=1
      cat << 'JSON' > $out/share/vulkan/implicit_layer.d/ReShade64.json
      {
        "file_format_version": "1.0.0",
        "layer": {
          "name": "VK_LAYER_RESHADE_overlay_x86_64",
          "type": "GLOBAL",
          "library_path": "OUT_DIR/lib/libReShade_loader_filter.so",
          "api_version": "1.3.0",
          "implementation_version": "1",
          "description": "ReShade overlay layer with intelligent process filter",
          "functions": {
            "vkNegotiateLoaderLayerInterfaceVersion": "vkNegotiateLoaderLayerInterfaceVersion",
            "vkGetInstanceProcAddr": "vkGetInstanceProcAddr"
          },
          "enable_environment": {
            "RESHADE_ENABLE": "1"
          },
          "disable_environment": {
            "DISABLE_RESHADE": "1"
          }
        }
      }
      JSON
      sed -i "s|OUT_DIR|$out|g" $out/share/vulkan/implicit_layer.d/ReShade64.json

      runHook postInstall
    '';

    meta = with lib; {
      description = "ReShade Vulkan post-processing injector and shader collections for Linux";
      homepage = "https://github.com/Cleison-oliveira/nix-reshade-manager";
      license = licenses.bsd3;
      platforms = platforms.linux;
    };
  }
