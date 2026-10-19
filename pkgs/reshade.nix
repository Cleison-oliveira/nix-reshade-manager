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
  keyReload ? "0,0,0,0",
  keyNextPreset ? "0,0,0,0",
  keyPreviousPreset ? "0,0,0,0",
  keyScreenshot ? "0,0,0,0",
  disableWelcomeBar ? true,
  showOverlayOnStartup ? false,
  version ? "6.8.0-beta.3",
}: let
  defaultPacks = (import ./default-packs.nix {inherit fetchFromGitHub;});
  hotkeyLib = import ./hotkeys.nix;
  safeKey = k: hotkeyLib.toReShadeHotkey (if k == null then "" else k);

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

      # Binary patch: iterate overlay callbacks in reverse order (About -> ... -> Home) in draw_gui()
      # This ensures Home is submitted last, placing it at the top of ImGui focus order so it is naturally focused on startup
      # Also patch DockNodeUpdateTabBar fallback from Tabs.back() to Tabs.front() so uninitialized docks select Home
      python3 -c '
import sys
p = sys.argv[1]
with open(p, "rb") as f:
    data = bytearray(f.read())

# 1. Reverse overlay_callbacks loop in runtime::draw_gui
p2_orig = bytes.fromhex("488b8558f9ffff4883c3304839c375bf")
p2_rep  = bytes.fromhex("4883eb30483b9d78f9ffff73c2909090")
idx2 = data.find(p2_orig)
if idx2 != -1:
    idx1 = idx2 - 0x38
    p1_orig = bytes.fromhex("488b9d78f9ffff")
    p1_rep  = bytes.fromhex("488d9d90fcffff")
    if data[idx1:idx1+len(p1_orig)] == p1_orig:
        data[idx1:idx1+len(p1_rep)] = p1_rep
        data[idx2:idx2+len(p2_rep)] = p2_rep

# 2. DockNodeUpdateTabBar fallback: select Tabs.front() instead of Tabs.back()
p3_orig = bytes.fromhex("488b4c2408488d14c5000000004829c2488d04d50000000048034110488b40d0660f6e80c0000000660f70c0e0660fd64120")
p3_rep  = bytes.fromhex("488b4c2408488b4110488b4008" + "90"*19 + "660f6e80c0000000660f70c0e0660fd64120")
idx3 = data.find(p3_orig)
if idx3 != -1:
    data[idx3:idx3+len(p3_rep)] = p3_rep

with open(p, "wb") as f:
    f.write(data)
' "$out/lib/reshade/ReShade64_orig.so"

      # Binary patch: allow closing/exiting the ReShade overlay with ESC key
      python3 -c '
import sys
p = sys.argv[1]
with open(p, "rb") as f:
    data = bytearray(f.read())

prefix = bytes.fromhex("498b7c2478be1b000000e89aa6fbff84c00f8492ecffff")
idx = data.find(prefix)
if idx != -1:
    patch_start = idx + len(prefix)
    rep = bytes.fromhex("c68560f9ffff00e9c1ecffff" + "90" * 70)
    data[patch_start : patch_start + len(rep)] = rep

with open(p, "wb") as f:
    f.write(data)
' "$out/lib/reshade/ReShade64_orig.so"

      ${lib.optionalString showOverlayOnStartup ''
        # Binary patch: automatically open overlay on startup
        python3 -c '
import sys
p = sys.argv[1]
with open(p, "rb") as f:
    data = bytearray(f.read())
orig = bytes.fromhex("31c00fb68751050000888560f9ffff")
rep  = bytes.fromhex("b00188875105000090888560f9ffff")
idx = data.find(orig)
if idx != -1:
    data[idx:idx+len(rep)] = rep
with open(p, "wb") as f:
    f.write(data)
' "$out/lib/reshade/ReShade64_orig.so"
      ''}

      # Binary patch: increase Vulkan descriptor pool limits for effects
      # Allows hundreds of shaders to compile without descriptor pool exhaustion
      python3 -c '
import sys
p = sys.argv[1]
with open(p, "rb") as f:
    data = bytearray(f.read())

p1 = bytes.fromhex("0000000080000000010000000004000002000000000400000300000000020000")
r1 = bytes.fromhex("0000000000200000010000000040000002000000004000000300000000100000")
idx1 = data.find(p1)
if idx1 != -1:
    data[idx1:idx1+len(r1)] = r1

p2 = bytes.fromhex("06000000800000002000000005000000ffffffff000000000100000000020000")
r2 = bytes.fromhex("06000000002000002000000005000000ffffffff000000000100000000400000")
idx2 = data.find(p2)
if idx2 != -1:
    data[idx2:idx2+len(r2)] = r2

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
        -DDEFAULT_KEY_OVERLAY="\"${safeKey keyOverlay}\"" \
        -DDEFAULT_KEY_EFFECTS="\"${safeKey keyEffects}\"" \
        -DDEFAULT_KEY_RELOAD="\"${safeKey keyReload}\"" \
        -DDEFAULT_KEY_NEXT_PRESET="\"${safeKey keyNextPreset}\"" \
        -DDEFAULT_KEY_PREVIOUS_PRESET="\"${safeKey keyPreviousPreset}\"" \
        -DDEFAULT_KEY_SCREENSHOT="\"${safeKey keyScreenshot}\"" \
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

      # Fix AstrayFX compilation hazards (error X3020 sampling from render target)
      python3 -c '
import os, sys
shaders_dir = sys.argv[1]

snow_path = os.path.join(shaders_dir, "AstrayFX/OneShot/SnowScape.fx")
if os.path.exists(snow_path):
    with open(snow_path, "r", encoding="utf-8", errors="ignore") as f:
        c = f.read()
    old_sn = """float3 SmoothNormals(float2 TC, int NS,int Dir, float SNOffset)
{   //Smooth Normals done in two passes now Faster. But, still slow.
\tfloat4 StoredNormals_Depth = float4(Dir ? DepthNormals(TC) : tex2Dlod(N_Sampler_A,float4(TC,0,0)).xyz,DepthM(TC).x), SmoothedNormals = float4(StoredNormals_Depth.xyz,1);

\t[loop] // -1 0 +1 on x and y
\tfor(float xy = -NS; xy <= NS; xy++)
\t{
\t\tif(smoothstep(0,1,StoredNormals_Depth.w) > MaxDepth_Cutoff)
\t\t\tbreak;
\t\tfloat2 XY = Dir ? float2(xy,0) : float2(0,xy);
\t\tfloat2 offsetcoords = TC + XY * pix * SNOffset;
\t\tfloat4 Normals_Depth     = float4(Dir ? DepthNormals(offsetcoords) : tex2Dlod(N_Sampler_A,float4(offsetcoords,0,0)).xyz,DepthM(offsetcoords).x);
\t\tif (abs(StoredNormals_Depth.w - Normals_Depth.w) < 0.001 && dot(Normals_Depth.xyz, StoredNormals_Depth.xyz) > 0.5f)
\t\t{
\t\t\tSmoothedNormals.xyz += Normals_Depth.xyz;
\t\t\t++SmoothedNormals.w;
\t\t}
\t}

\treturn SmoothedNormals.xyz / SmoothedNormals.w;
}"""
    new_sn = """float3 SmoothNormalsH(float2 TC, int NS, float SNOffset)
{
\tfloat4 StoredNormals_Depth = float4(DepthNormals(TC), DepthM(TC).x), SmoothedNormals = float4(StoredNormals_Depth.xyz,1);

\t[loop]
\tfor(float xy = -NS; xy <= NS; xy++)
\t{
\t\tif(smoothstep(0,1,StoredNormals_Depth.w) > MaxDepth_Cutoff)
\t\t\tbreak;
\t\tfloat2 XY = float2(xy,0);
\t\tfloat2 offsetcoords = TC + XY * pix * SNOffset;
\t\tfloat4 Normals_Depth = float4(DepthNormals(offsetcoords), DepthM(offsetcoords).x);
\t\tif (abs(StoredNormals_Depth.w - Normals_Depth.w) < 0.001 && dot(Normals_Depth.xyz, StoredNormals_Depth.xyz) > 0.5f)
\t\t{
\t\t\tSmoothedNormals.xyz += Normals_Depth.xyz;
\t\t\t++SmoothedNormals.w;
\t\t}
\t}

\treturn SmoothedNormals.xyz / SmoothedNormals.w;
}

float3 SmoothNormalsV(float2 TC, int NS, float SNOffset)
{
\tfloat4 StoredNormals_Depth = float4(tex2Dlod(N_Sampler_A,float4(TC,0,0)).xyz, DepthM(TC).x), SmoothedNormals = float4(StoredNormals_Depth.xyz,1);

\t[loop]
\tfor(float xy = -NS; xy <= NS; xy++)
\t{
\t\tif(smoothstep(0,1,StoredNormals_Depth.w) > MaxDepth_Cutoff)
\t\t\tbreak;
\t\tfloat2 XY = float2(0,xy);
\t\tfloat2 offsetcoords = TC + XY * pix * SNOffset;
\t\tfloat4 Normals_Depth = float4(tex2Dlod(N_Sampler_A,float4(offsetcoords,0,0)).xyz, DepthM(offsetcoords).x);
\t\tif (abs(StoredNormals_Depth.w - Normals_Depth.w) < 0.001 && dot(Normals_Depth.xyz, StoredNormals_Depth.xyz) > 0.5f)
\t\t{
\t\t\tSmoothedNormals.xyz += Normals_Depth.xyz;
\t\t\t++SmoothedNormals.w;
\t\t}
\t}

\treturn SmoothedNormals.xyz / SmoothedNormals.w;
}"""
    c = c.replace(old_sn, new_sn)
    c = c.replace("Normals = SmoothNormals(texcoord, SN_offset.x, 1, SN_offset.y);", "Normals = SmoothNormalsH(texcoord, SN_offset.x, SN_offset.y);")
    c = c.replace("Normals_LM = float4(SmoothNormals(texcoord, SN_offset.x, 0, SN_offset.y).xyz,DepthM(texcoord).x);", "Normals_LM = float4(SmoothNormalsV(texcoord, SN_offset.x, SN_offset.y).xyz,DepthM(texcoord).x);")
    with open(snow_path, "w", encoding="utf-8") as f:
        f.write(c)

radiant_path = os.path.join(shaders_dir, "AstrayFX/RadiantGI.fx")
if os.path.exists(radiant_path):
    with open(radiant_path, "r", encoding="utf-8", errors="ignore") as f:
        c = f.read()
    c = c.replace("Ublur( PCGIcurrColor, texcoords, 5, 100)", "Ublur( BackBufferPCGI, texcoords, 5, 100)")
    with open(radiant_path, "w", encoding="utf-8") as f:
        f.write(c)
' "$out/share/reshade/reshade-shaders/Shaders" 

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

      # Create single unified reshade launcher command
      mkdir -p $out/bin
      cat << 'RUNNER_EOF' > $out/bin/reshade
#!/usr/bin/env bash
set -euo pipefail

BASE_RESHADE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/reshade"
CONFIGS_DIR="$BASE_RESHADE_DIR/configurations"

show_help() {
  cat << "HELP"
reshade - Native ReShade launcher for Linux Vulkan

USAGE:
  reshade [OPTIONS] <command> [args...]
  reshade %command%                  (Launcher launch options syntax)
  reshade flatpak run <app-id>       (Flatpak applications)

ENVIRONMENT VARIABLES:
  RESHADE=1 <command>                Enable ReShade via environment variable
  RESHADE_ENABLE=1 <command>         Alternative syntax
  DISABLE_RESHADE=1 <command>        Explicitly disable ReShade

OPTIONS:
  -p, --profile <NAME>  Set an explicit ReShade profile
                        (Configs in ~/.local/share/reshade/configurations/<NAME>)
  -l, --list            List existing profiles and presets
  -w, --wayland         Enable PROTON_ENABLE_WAYLAND=1 (Wine Wayland native)
  -n, --no-log          Enable RESHADE_DISABLE_LOGGING=1 (disable log generation)
  -h, --help            Show this help message
HELP
}

list_profiles() {
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
    -l|--list|list)
      list_profiles
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

mkdir -p "$CONFIGS_DIR"

if [ -n "$PROFILE" ]; then
  export RESHADE_PROFILE="$PROFILE"
fi

export RESHADE=1
export RESHADE_ENABLE=1
export VK_LOADER_LAYERS_DISABLE="''${VK_LOADER_LAYERS_DISABLE:+''$VK_LOADER_LAYERS_DISABLE:}VK_LAYER_reshade_x86_64"
export XDG_DATA_DIRS="@OUT@/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
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
RUNNER_EOF

      substituteInPlace $out/bin/reshade --replace-fail '@OUT@' "$out"
      chmod +x $out/bin/reshade

      runHook postInstall
    '';

    meta = with lib; {
      description = "ReShade Vulkan post-processing injector and shader collections for Linux";
      homepage = "https://github.com/Cleison-oliveira/nix-reshade-manager";
      license = licenses.bsd3;
      platforms = platforms.linux;
      mainProgram = "reshade";
    };
  }
