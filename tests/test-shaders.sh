#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================================="
echo "    ReShade Shaders Compilation Automated Test Suite     "
echo "=========================================================="

if [ -n "${1:-}" ]; then
  STORE="$1"
  echo "Using specified package: $STORE"
else
  echo "Building reshade-full from local flake repository..."
  STORE="$(nix build "$REPO_DIR#reshade-full" --no-link --print-out-paths)"
  echo "Built package: $STORE"
fi

TMPDIR="$(mktemp -d /tmp/reshade_test_suite.XXXXXX)"
trap 'chmod -R u+w "$TMPDIR" 2>/dev/null || true; rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/layers" "$TMPDIR/data" "$TMPDIR/cache"

cat << JSON_EOF > "$TMPDIR/layers/ReShade_test.json"
{
    "file_format_version" : "1.0.0",
    "layer" : {
      "name": "VK_LAYER_RESHADE_automated_test",
      "type": "GLOBAL",
      "api_version": "1.3.0",
      "library_path": "$STORE/lib/reshade/ReShade64.so",
      "implementation_version": "1",
      "description": "Automated ReShade Shader Test Layer",
      "functions": {
         "vkNegotiateLoaderLayerInterfaceVersion": "vkNegotiateLoaderLayerInterfaceVersion",
         "vkGetInstanceProcAddr": "vkGetInstanceProcAddr"
      }
    }
}
JSON_EOF

export VK_LOADER_LAYERS_DISABLE="VK_LAYER_RESHADE_overlay_x86_64,VK_LAYER_RESHADE_legacy_x86_64"
export VK_LAYER_PATH="$TMPDIR/layers"
export VK_INSTANCE_LAYERS="VK_LAYER_RESHADE_automated_test"
export XDG_DATA_HOME="$TMPDIR/data"
export XDG_CACHE_HOME="$TMPDIR/cache"
export RESHADE=1

if ! command -v vkcube >/dev/null 2>&1; then
  echo "ERROR: vkcube executable not found in PATH! (Install vulkan-tools)" >&2
  exit 1
fi

echo "Running automated shader compilation test with vkcube..."
timeout 7 vkcube >/dev/null 2>&1 || true

LOG="$(find "$TMPDIR" -name "ReShade.log" | head -n 1)"
if [ -z "$LOG" ] || [ ! -f "$LOG" ]; then
  echo "ERROR: ReShade.log was not generated during the test run." >&2
  exit 1
fi

COMPILED_COUNT="$(grep -c "Successfully compiled" "$LOG" || true)"
echo "Total shaders compiled: $COMPILED_COUNT"

if [ "$COMPILED_COUNT" -lt 10 ]; then
  echo "ERROR: Too few shaders compiled ($COMPILED_COUNT). Expected at least 10." >&2
  exit 1
fi

ERRORS="$(grep -E "ERROR|error X[0-9]+|Failed to create .* descriptor table|internal compiler error" "$LOG" || true)"

if [ -n "$ERRORS" ]; then
  echo "FAILED: Shader compilation errors found in ReShade.log:" >&2
  echo "$ERRORS" >&2
  exit 1
fi

echo "=========================================================="
echo " SUCCESS: All $COMPILED_COUNT shaders compiled with 0 errors!"
echo "=========================================================="
