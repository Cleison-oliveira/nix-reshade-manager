{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  autoPatchelfHook,
  python3,
  wayland,
  libxkbcommon,
  libxcb,
  libxcb-cursor,
  fontconfig,
  vulkan-loader,
  builtinPacks ? {},
  extraPacks ? {},
  keyOverlay ? "117,0,1,0",
  keyEffects ? "116,0,1,0",
  disableWelcomeBar ? true,
  version ? "6.8.0-beta.3",
}: let
  defaultPacks = (import ./default-packs.nix {inherit fetchFromGitHub;});

  # Filter active built-in packs based on user preferences (default to false)
  activeBuiltinPacks =
    lib.filterAttrs (
      name: pack:
        if builtinPacks ? ${name}
        then builtinPacks.${name}
        else false
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
    target_s="$out/share/reshade/reshade-shaders/Shaders/${targetShadersSubdir}"
    target_t="$out/share/reshade/reshade-shaders/Textures/${targetTexturesSubdir}"
    mkdir -p "$target_s" "$target_t"

    if [ -d "${src}/${shadersSubdir}" ]; then
      cp -rn "${src}/${shadersSubdir}/"* "$target_s/" 2>/dev/null || true
    elif [ -d "${src}/shaders" ]; then
      cp -rn "${src}/shaders/"* "$target_s/" 2>/dev/null || true
    else
      find "${src}" -maxdepth 2 \( -name "*.fx" -o -name "*.fxh" \) -exec cp -n {} "$target_s/" + 2>/dev/null || true
    fi

    if [ -n "${texturesSubdir}" ] && [ -d "${src}/${texturesSubdir}" ]; then
      cp -rn "${src}/${texturesSubdir}/"* "$target_t/" 2>/dev/null || true
    elif [ -d "${src}/Textures" ]; then
      cp -rn "${src}/Textures/"* "$target_t/" 2>/dev/null || true
    elif [ -d "${src}/textures" ]; then
      cp -rn "${src}/textures/"* "$target_t/" 2>/dev/null || true
    elif [ -z "${texturesSubdir}" ] && [ -d "${src}" ]; then
      cp -rn "${src}/"* "$target_t/" 2>/dev/null || true
    fi
  '';

  copyBuiltinPacks = lib.concatStringsSep "\n" (lib.mapAttrsToList copyPack activeBuiltinPacks);
  copyExtraPacks = lib.concatStringsSep "\n" (lib.mapAttrsToList copyPack extraPacks);
in
  stdenv.mkDerivation rec {
    pname = "reshade-complete";
    inherit version;

    src = fetchurl {
      url = "https://github.com/TheForgotten69/reshade/releases/download/v${version}/reshade-linux-vulkan-v${version}-x86_64.tar.xz";
      hash = "sha256-yICzjNRnvnOPDxH9JQjbdIwcE6lJNVQM+vzdCo79iUs=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
      python3
    ];

    buildInputs = [
      wayland
      libxkbcommon
      libxcb
      libxcb-cursor
      fontconfig
      stdenv.cc.cc.lib
      vulkan-loader
    ];

    preFixup = ''
      patchelf --add-rpath "$out/lib/reshade" $out/share/reshade/optional-addons/*.addon64 2>/dev/null || true
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/reshade \
               $out/share/vulkan/implicit_layer.d \
               $out/share/reshade/optional-addons \
               $out/share/reshade/reshade-shaders/Shaders \
               $out/share/reshade/reshade-shaders/Textures

      # Copy raw upstream library
      cp lib/reshade/ReShade64.so $out/lib/reshade/ReShade64_orig.so
      cp optional-addons/*.addon64 $out/share/reshade/optional-addons/ 2>/dev/null || true

      ${lib.optionalString disableWelcomeBar ''
        # Binary patch to suppress initial tutorial welcome banner
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

      # Binary patch: automatically save configuration & active tab when overlay is closed
      python3 -c '
import sys
p = sys.argv[1]
with open(p, "rb") as f:
    data = bytearray(f.read())
pattern = b"\x84\xc0\x74\x11\x48\x8b\x83\x48\x05\x00\x00"
idx = data.find(pattern)
if idx != -1:
    data[idx + 3] = 0x31
    trampoline = bytes.fromhex("4889dfe8e2cdf0ffebd6")
    data[idx + 0x35 : idx + 0x35 + 10] = trampoline
with open(p, "wb") as f:
    f.write(data)
' "$out/lib/reshade/ReShade64_orig.so"

      # Binary patch: dock default tabs in reverse order so Home (0x2863d5fc) is docked last and selected by default
      python3 -c '
import sys
p = sys.argv[1]
with open(p, "rb") as f:
    data = bytearray(f.read())
orig = bytes.fromhex("488b9d78f9ffff48898558f9ffff488b3b8bb5a0f9ffffe8aab0e7ff4883c33048399d58f9ffff75e5")
rep  = bytes.fromhex("488d58d00f1f0048898558f9ffff488b3b8bb5a0f9ffffe8aab0e7ff4883eb30483b9d78f9ffff73e5")
idx = data.find(orig)
if idx != -1:
    data[idx : idx + len(rep)] = rep
with open(p, "wb") as f:
    f.write(data)
' "$out/lib/reshade/ReShade64_orig.so"
      # Prepare loader filter with replaced paths
      cp ${./loader_filter.c} ./loader_filter_src.c
      substituteInPlace ./loader_filter_src.c \
        --replace-fail "@ORIG_RESHADE_SO@" "$out/lib/reshade/ReShade64_orig.so" \
        --replace-fail "@NIX_RESHADE_SHADERS@" "$out/share/reshade/reshade-shaders/Shaders" \
        --replace-fail "@NIX_RESHADE_TEXTURES@" "$out/share/reshade/reshade-shaders/Textures"

      # Compile transparent loader filter with configured hotkeys
      $CC -shared -fPIC -O3 \
        -DDEFAULT_KEY_OVERLAY="\"${keyOverlay}\"" \
        -DDEFAULT_KEY_EFFECTS="\"${keyEffects}\"" \
        ./loader_filter_src.c \
        -o $out/lib/reshade/ReShade64.so \
        -ldl

      # Symlink compatibility paths
      mkdir -p $out/lib
      ln -sf reshade/ReShade64.so $out/lib/libReShade_loader_filter.so
      ln -sf reshade/ReShade64.so $out/lib/ReShade64.so
      ln -sf reshade/ReShade64_orig.so $out/lib/ReShade64_orig.so

      # Official default shaders from upstream package
      cp -r share/reshade/reshade-shaders/Shaders/* $out/share/reshade/reshade-shaders/Shaders/ 2>/dev/null || true
      cp -r share/reshade/reshade-shaders/Textures/* $out/share/reshade/reshade-shaders/Textures/ 2>/dev/null || true

      # Copy declaratively enabled built-in packs
      ${copyBuiltinPacks}

      # Copy declaratively configured extra packs
      ${copyExtraPacks}

      chmod -R u+w "$out/share/reshade/reshade-shaders"

      # Normalize backslash include directives (Windows paths)
      find "$out/share/reshade/reshade-shaders/Shaders" -type f \( -name "*.fx" -o -name "*.fxh" \) \
        -exec sed -i '/^[[:space:]]*#include/ s|\\|/|g' {} + 2>/dev/null || true

      # Case-insensitive compatibility symlinks
      for sdir in "$out/share/reshade/reshade-shaders/Shaders"; do
        [ -f "$sdir/ReShade.fxh" ] && ln -sf ReShade.fxh "$sdir/Reshade.fxh" && ln -sf ReShade.fxh "$sdir/reshade.fxh" || true
        [ -f "$sdir/ReShadeUI.fxh" ] && ln -sf ReShadeUI.fxh "$sdir/ReshadeUI.fxh" && ln -sf ReShadeUI.fxh "$sdir/reshadeui.fxh" || true
      done
      find "$out/share/reshade" -name "*.fx" -exec sed -i 's/"Reshade\.fxh"/"ReShade\.fxh"/g' {} + 2>/dev/null || true

      # Main Vulkan manifest for RESHADE=1
      cat << 'MANIFEST_EOF' > $out/share/vulkan/implicit_layer.d/ReShade.json
{
    "file_format_version" : "1.0.0",
    "layer" : {
      "name": "VK_LAYER_RESHADE_overlay_x86_64",
      "type": "GLOBAL",
      "api_version": "1.3.0",
      "library_path": "$out/lib/reshade/ReShade64.so",
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
MANIFEST_EOF

      substituteInPlace $out/share/vulkan/implicit_layer.d/ReShade.json \
        --replace-fail '$out' "$out"

      # Backward compatibility Vulkan manifest for RESHADE_ENABLE=1
      cat << 'MANIFEST_EOF' > $out/share/vulkan/implicit_layer.d/ReShade64.json
{
    "file_format_version" : "1.0.0",
    "layer" : {
      "name": "VK_LAYER_RESHADE_legacy_x86_64",
      "type": "GLOBAL",
      "api_version": "1.3.0",
      "library_path": "$out/lib/reshade/ReShade64.so",
      "implementation_version": "1",
      "description": "ReShade overlay layer with intelligent process filter (legacy RESHADE_ENABLE)",
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
MANIFEST_EOF

      substituteInPlace $out/share/vulkan/implicit_layer.d/ReShade64.json \
        --replace-fail '$out' "$out"

      runHook postInstall
    '';

    meta = with lib; {
      description = "ReShade Vulkan post-processing injector and shader collections for Linux";
      homepage = "https://github.com/Cleison-oliveira/nix-reshade-manager";
      license = licenses.bsd3;
      platforms = platforms.linux;
    };
  }
