# nix-reshade-manager

Declarative ReShade and shader pack manager for NixOS and Home Manager with native Linux Vulkan layer support.

Provides high-performance post-processing injection, intelligent background process filtering, guaranteed startup focus on the Home tab, customizable hotkeys (including ESC to close), and expanded descriptor limits for comprehensive shader compatibility.

---

## Features

- **Native Vulkan Layer Injection**:
  - Operates via the high-performance implicit layer `VK_LAYER_RESHADE_overlay_x86_64`.
  - Activated on demand via `RESHADE=1` or `RESHADE_ENABLE=1`.
  - Can be explicitly disabled for any command with `DISABLE_RESHADE=1`.

- **Intelligent Process Filter (`loader_filter.c`)**:
  - Automatically isolates target applications and ignores background daemons, crash reporters, diagnostic helpers, web sub-processes, and launcher wrappers.
  - Supports 64-bit and 32-bit Windows applications through Wine WoW64 (`PROTON_USE_WOW64=1`).
  - Automatic profile resolution: generates and persists independent settings per application in `~/.local/share/reshade/configurations/<app-name>/`.
  - Declarative store path cleanup: automatically purges stale `/nix/store/...` paths across NixOS generations without corrupting custom user configurations.

- **Guaranteed Home Tab Focus**:
  - Resolves the upstream Dear ImGui / ReShade focus order issue where overlays opened on the "About" tab.
  - ImGui focus stack and dock tab bar fallback are patched so the **Home / Effects** tab is always active and focused on startup.

- **Universal ESC Key Exit**:
  - Pressing `ESC` when the ReShade menu is open immediately closes the overlay, smoothly returning input focus to the application.

- **Declarative Hotkeys & In-Game UI Persistence**:
  - Configure all 5 primary ReShade hotkeys (`overlay`, `effects`, `reload`, `nextPreset`, `previousPreset`) plus `screenshot` declaratively in Nix.
  - Unbind any key by setting it to `"None"`, `"Empty"`, `""`, or `null`.
  - Any modifications made in-game via the ReShade Settings tab are automatically saved and preserved permanently in writable user storage.

- **Expanded Vulkan Descriptor Pools**:
  - Patches conservative upstream descriptor limits (expanding from 128 to 8,192 samplers and uniform buffers, and 16,384 descriptor sets), allowing hundreds of shaders to compile concurrently without descriptor table exhaustion.

- **Opt-in Modular Shader Packs**:
  - Minimal by default: only bundles core ReShade headers and basic shaders.
  - Curated built-in packs can be enabled individually via `builtinPacks`.
  - Arbitrary Git repositories or local directories can be declared via `extraPacks`.

- **Welcome Tutorial Suppression**:
  - Optional binary patch (`disableWelcomeBar = true`) permanently suppresses the initial startup tutorial/welcome bar.

- **Included CLI Utility**:
  - `reshade`: Unified application runner with profile selection, preset listing, Wine Wayland support, and logging controls.
  - `test-shaders`: Automated test suite to validate shader compilation.

---

## Installation

Add this repository to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";

    reshade = {
      url = "github:Cleison-oliveira/nix-reshade-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, reshade, ... }@inputs: {
    # NixOS System Configuration
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        reshade.nixosModules.default
        ./configuration.nix
      ];
    };

    # Home Manager User Configuration
    homeConfigurations.myuser = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        reshade.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
```

---

## Configuration Reference

### Available Options (`programs.reshade`)

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `enable` | `bool` | `false` | Enable the ReShade Vulkan layer and tools. |
| `package` | `package` | `pkgs.reshade` | The underlying ReShade package derivation. |
| `hotkeys.overlay` | `nullOr str` | `"Shift+F6"` | Hotkey to toggle the in-game ReShade menu. |
| `hotkeys.effects` | `nullOr str` | `"Shift+F5"` | Hotkey to toggle all post-processing effects. |
| `hotkeys.reload` | `nullOr str` | `"None"` | Hotkey to reload all shaders and textures. |
| `hotkeys.nextPreset` | `nullOr str` | `"None"` | Hotkey to switch to the next preset. |
| `hotkeys.previousPreset` | `nullOr str` | `"None"` | Hotkey to switch to the previous preset. |
| `hotkeys.screenshot` | `nullOr str` | `"None"` | Hotkey to capture a screenshot via ReShade. |
| `disableWelcomeBar` | `bool` | `true` | Suppress the initial welcome tutorial banner. |
| `builtinPacks` | `attrsOf bool` | `{}` | Set of built-in shader packs to enable (see table below). |
| `extraPacks` | `attrs` | `{}` | Custom external shader repositories or local directories. |
| `defaultAddons` | `listOf str` | `[]` | List of optional addons to deploy (e.g. `["fps_limit"]`). |

---

## Hotkey System

Hotkeys can be declared using human-friendly names or raw keycode tuples (`<KeyCode>,<Ctrl>,<Shift>,<Alt>`).

### Supported Key Names

- **Function Keys**: `F1` through `F24`
- **Letters**: `A` through `Z` (e.g. `"Ctrl+Shift+R"`)
- **Numbers**: `0` through `9`
- **Navigation**: `Home`, `End`, `Insert`, `Delete`, `PageUp`, `PageDown`
- **Arrows**: `Up`, `Down`, `Left`, `Right`
- **Common**: `Space`, `Tab`, `Escape`, `Return`, `Backspace`, `PrintScreen`, `Pause`, `ScrollLock`
- **Modifiers**: Combine any key with `Ctrl+`, `Shift+`, or `Alt+`
- **Unbound / Disabled**: `"None"`, `"Empty"`, `""`, or `null`

### Hotkey Examples

```nix
programs.reshade = {
  enable = true;

  hotkeys = {
    overlay = "Shift+F6";         # Open/close menu
    effects = "Shift+F5";         # Toggle effects
    reload = "Ctrl+Shift+R";      # Reload effects
    nextPreset = "PageUp";        # Next preset
    previousPreset = "PageDown";  # Previous preset
    screenshot = "PrintScreen";   # Capture screenshot
  };
};
```

To leave any hotkey unbound, set it to `"None"`, `"Empty"`, `""`, or `null`:

```nix
programs.reshade.hotkeys = {
  reload = "None";      # or null
  nextPreset = "Empty"; # or ""
};
```

> [!TIP]
> Pressing the **`ESC`** key while the ReShade menu is open will always exit the menu immediately, even if your overlay hotkey is set to something else.

---

## Shader Pack Management

Shader packs are **opt-in** by default to maintain fast build times and minimal package footprint. ReShade includes only its essential core files (`ReShade.fxh`, `DisplayDepth.fx`, `LUT.fx`, etc.) unless you explicitly enable packs.

### 1. Curated Built-in Packs (`builtinPacks`)

Enable any of the curated packs in `programs.reshade.builtinPacks`:

```nix
programs.reshade = {
  enable = true;

  builtinPacks = {
    legacy = true;           # Official ReShade repository (FXAA, SMAA, Curves, Tonemap)
    sweetfx = true;          # SweetFX suite (HDR, Bloom, Cartoon, Cineon DPX)
    quint = true;            # qUINT framework (Lightroom, MXAO, DOF, Sharp, Bloom)
    prod80 = true;           # Color grading suite (Color Temperature, CMatrix, Shadows/Highlights)
    otisfx = true;           # Cinematic photography (CinematicDOF, AdaptiveFog, GoldenRatio)
    fubax = true;            # Optical effects (Chromatic Aberration, PerfectPerspective, Fisheye)
    astrayfx = true;         # Clarity.fx and depth enhancement
    immerse = true;          # iMMERSE Marty's Mods (Sharpen, SMAA, ReGrade)
    gshade = true;           # GShade & PPFX Bloom
    reshadeTextures = true;  # Consolidated textures, noise tables, and LUTs
    barbatos = true;         # Advanced raymarching (XeGTAO, SSR, DLAA-T, GI)
  };
};
```

### Curated Pack Details

| Pack | Maintainer | Description & Notable Shaders |
| :--- | :--- | :--- |
| **`legacy`** | crosire & community | Core shaders: `FXAA`, `SMAA`, `Curves`, `Tonemap`, `Levels`, `Vibrance`, `LumaSharpen`. |
| **`sweetfx`** | CeeJay.dk | Classic post-processing: `HDR`, `Bloom`, `Cineon DPX`, `Technicolor`, `Curves`. |
| **`quint`** | Pascal Gilcher (Marty McFly) | High-fidelity shaders: `qUINT_lightroom`, `qUINT_mxao`, `qUINT_dof`, `qUINT_sharp`, `qUINT_bloom`. |
| **`prod80`** | prod80 | Professional color grading: `Color Temperature`, `Color Balance`, `CMatrix`, `Film Grain`. |
| **`otisfx`** | Frans Bouma (Otis_Inf) | Virtual photography: `CinematicDOF`, `AdaptiveFog`, `Emphasize`, `GoldenRatio`. |
| **`fubax`** | Fubaxiusz | Lens & camera optical effects: `Chromatic Aberration`, `PerfectPerspective`, `Prism`, `Fisheye`. |
| **`astrayfx`** | BlueSkyDefender | Local contrast and depth enhancement: `Clarity.fx`, `Depth_Refargo`. |
| **`immerse`** | Pascal Gilcher (Marty McFly) | Modern suite: `MartysMods_SHARPEN`, `MartysMods_SMAA`, `MartysMods_ReGrade`, `LAUNCHPAD`. |
| **`gshade`** | Mortalitas & community | Popular RPG/MMO collection: `PPFX_Bloom.fx`, custom ambient occlusion filters. |
| **`barbatos`** | BarbatosAWLS | Real-time raymarching: `XeGTAO` (Ground Truth Ambient Occlusion), `SSR`, `DLAA-T`, `GI`. |
| **`reshadeTextures`** | Curated by Bhhl | Blue noise tables, lens dirt masks, and LUT texture maps required by advanced shaders. |

### 2. Custom Shader Packs (`extraPacks`)

Declare external repositories or local directories with `extraPacks`:

```nix
programs.reshade = {
  enable = true;

  extraPacks = {
    # Direct GitHub repository derivation
    my-custom-shaders = pkgs.fetchFromGitHub {
      owner = "crosire";
      repo = "reshade-shaders";
      rev = "v6.0.0";
      hash = "sha256-...";
    };

    # Repository with custom subdirectory layouts
    advanced-pack = {
      src = pkgs.fetchFromGitHub {
        owner = "example-author";
        repo = "custom-shaders";
        rev = "main";
        hash = "sha256-...";
      };
      shadersSubdir = "Shaders";       # Source folder with .fx files (default: "Shaders")
      texturesSubdir = "Textures";     # Source folder with textures (default: "Textures")
      targetShadersSubdir = "MyPack";  # Target subdirectory inside ReShade shaders path
      targetTexturesSubdir = "MyPack"; # Target subdirectory inside ReShade textures path
    };
  };
};
```

---

## Configuration Examples

### Complete NixOS Example (`configuration.nix`)

```nix
{ pkgs, ... }: {
  programs.reshade = {
    enable = true;

    hotkeys = {
      overlay = "Shift+F6";
      effects = "Shift+F5";
      reload = "Ctrl+Shift+R";
      nextPreset = "PageUp";
      previousPreset = "PageDown";
      screenshot = "PrintScreen";
    };

    disableWelcomeBar = true;

    builtinPacks = {
      legacy = true;
      sweetfx = true;
      quint = true;
      prod80 = true;
      otisfx = true;
      astrayfx = true;
      immerse = true;
      reshadeTextures = true;
    };
  };
}
```

### Complete Home Manager Example (`home.nix`)

```nix
{ pkgs, ... }: {
  programs.reshade = {
    enable = true;

    hotkeys = {
      overlay = "Shift+F6";
      effects = "Shift+F5";
      reload = "None";
    };

    builtinPacks = {
      legacy = true;
      sweetfx = true;
      quint = true;
      prod80 = true;
      otisfx = true;
      fubax = true;
      astrayfx = true;
      immerse = true;
      gshade = true;
      reshadeTextures = true;
      barbatos = true;
    };

    defaultAddons = [ "fps_limit" ];
  };
}
```

---

## Usage & Execution

### 1. Environment Variable

Enable ReShade for any Vulkan application by setting `RESHADE=1`:

```bash
RESHADE=1 <application>
# or
RESHADE_ENABLE=1 <application>
```

To explicitly disable ReShade:

```bash
DISABLE_RESHADE=1 <application>
```

### 2. Using Launchers / Game Runners

Add the environment variable or runner to the application launch command:

```bash
# Using launch options syntax
reshade %command%

# Or using the environment variable directly
RESHADE=1 %command%
```

### 3. Flatpak Applications

```bash
reshade flatpak run <application-id>
```

### 4. Direct Terminal Execution

```bash
reshade <executable> [arguments...]

# Direct execution with native Wine Wayland enabled
reshade -w <executable>
```

---

## CLI Usage

```bash
# Launch any executable with ReShade enabled
reshade [OPTIONS] <command> [args...]

# Inspect existing application profiles and active presets
reshade --list
```

---

## Automated Testing & Validation

The repository includes an automated test suite verifying that all shaders across all curated packs compile without errors, resource hazards, or Vulkan descriptor pool exhaustion.

```bash
# Run the automated test suite directly via Nix Flake
nix run github:Cleison-oliveira/nix-reshade-manager#test-shaders

# Or run locally from this repository
nix run .#test-shaders
# Or:
./tests/test-shaders.sh
```

### What the Test Suite Validates:
1. Builds a standalone instance of ReShade with **all built-in packs enabled** (`reshade-full`).
2. Spawns an isolated Vulkan environment using `vkcube` with temporary sandboxed XDG data and cache directories.
3. Automatically parses `ReShade.log` upon completion to verify:
   - Over 460+ shaders discovered and compiled.
   - Zero HLSL compilation errors (`error X...`).
   - Zero resource hazards or texture binding collisions.
   - Zero Vulkan descriptor pool exhaustion errors.

---

## Technical Architecture & Improvements

### 1. Home Tab Focus Correction
- **Issue**: Upstream ReShade registered callbacks in forward order (`Home`, `Add-ons`, `Settings`, `Statistics`, `Log`, `About`). Dear ImGui's focus order pushed newly registered windows to the top of its focus stack, causing the last submitted window (`About`) to be focused on startup. Docking fallback logic also selected `Tabs.back()`.
- **Solution**: The derivation binary patches `runtime::draw_gui()` to iterate callbacks in reverse order, placing `Home` at the top of the focus order, and patches `DockNodeUpdateTabBar()` fallback to `Tabs.front()`. Additionally, `loader_filter.c` initializes the dockspace with `ID=0xB0DF600F` and `Selected=0xCBCD3A85` (Home).

### 2. ESC Key Close Handler
- **Issue**: Standard ReShade does not consistently close the overlay when pressing `ESC`.
- **Solution**: `draw_gui()` is binary patched to check keycode `0x1B` (ESC) when the overlay is open, immediately setting overlay visibility to false, triggering configuration auto-save, and returning input focus to the application.

### 3. Vulkan Descriptor Pool Expansion
- **Issue**: Upstream hardcodes conservative descriptor limits (128 samplers and uniform buffers). Loading multiple shader suites (such as iMMERSE, Barbatos, or qUINT) exhausted the descriptor pool, failing with `Failed to create sampler descriptor table`.
- **Solution**: `ReShade64_orig.so` is binary patched to expand descriptor limits to 8,192 samplers and uniform buffers and 16,384 descriptor sets.

### 4. AstrayFX Shader Hazard Resolution (HLSL Error X3020)
- **Issue**: Shaders referencing render target textures in the same pass failed with `error X3020: cannot sample from texture that is also used as render target in the same pass`.
- **Solution**: Patched `SnowScape.fx` and `RadiantGI.fx` to separate sampling routines and sample from source backbuffers rather than target textures.

### 5. Declarative Search Path Sanitization
- **Issue**: Nix store hash changes across generations accumulated duplicate `/nix/store/...` paths in `ReShade.ini`, causing ReShade worker threads to compile duplicate shaders in parallel.
- **Solution**: `loader_filter.c` automatically cleans obsolete `/nix/store/...` paths, prioritizing current paths and preserving user custom directories.

---

## Credits and Acknowledgments

- **[ReShade](https://reshade.me)**: Created and maintained by **Patrick Mours ([crosire](https://github.com/crosire))** and the ReShade community ([source code](https://github.com/crosire/reshade)).
- **[ReShade Linux Vulkan Layer](https://github.com/TheForgotten69/reshade)**: Native Linux Vulkan layer implementation by **TheForgotten69**.
- **[nix-reshade](https://github.com/LovingMelody/nix-reshade)**: Initial packaging and inspiration for Nix/NixOS by **LovingMelody**.
- **Shader Authors**: Patrick Mours, Christian Cann Schuldt Jensen (CeeJay.dk), Pascal Gilcher (Marty McFly), prod80, Frans Bouma (Otis_Inf), Fubaxiusz, BlueSkyDefender, Mortalitas, BarbatosAWLS, Bhhl, and the open-source graphics community.

---

## License

Distributed under the BSD-3-Clause license, matching upstream ReShade. Individual shader packs remain under their respective licenses specified by their authors.
