# nix-reshade-manager

Declarative ReShade and shader pack manager for NixOS and Home Manager with native Vulkan layer support on Linux.

Compatible with native Linux games, Steam (Proton), Heronite, Heroic Games Launcher, Lutris, Flatpak, and emulators.

---

## Features

- Native Vulkan Layer Injection: Uses implicit layer `VK_LAYER_RESHADE_overlay_x86_64`, activated via `RESHADE=1` or `RESHADE_ENABLE=1`.
- Transparent Loader Filter (`loader_filter.c`):
  - Prevents injection into desktop launchers (Heroic, Lutris, Heronite, Steam).
  - Ignores Wine/Proton background daemons (`explorer.exe`, `services.exe`, `winedevice.exe`).
  - Supports 64-bit and 32-bit Windows games through Wine New WoW64 (`PROTON_USE_WOW64=1`).
- Manual and Modular Shader Pack Management:
  - By default, no extra shader packs are bundled, keeping builds fast and lightweight.
  - Users explicitly choose which curated packs to enable via `builtinPacks`.
  - Full support for arbitrary custom shader repositories via `extraPacks`.
- In-Game UI Modifiable & Persistent Configurations:
  - Default hotkeys and search paths are configured declaratively in Nix.
  - Any modifications made in-game via the ReShade UI (custom hotkeys, overlay styling, parameters, presets) are saved and preserved permanently in writable user storage (`~/.local/share/reshade/configurations/<game>/`).
- Welcome Tutorial Suppression:
  - Optional binary patch (`disableWelcomeBar = true`) that permanently suppresses the startup welcome banner.
- Included CLI Tools:
  - `reshade-run` / `reshade`: Game launcher compatible with Flatpak, Wayland, and Steam.
  - `reshade-preset`: Inspect profiles and presets per game.

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
    # NixOS
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        reshade.nixosModules.default
        ./configuration.nix
      ];
    };

    # Home Manager
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

## Tutorial: Configuring Shader Packs Manually

Shader packs are **opt-in** by default. ReShade only includes its essential core files (`ReShade.fxh`, `DisplayDepth`, `LUT.fx`, etc.) unless you explicitly enable curated packs or declare custom repositories.

### 1. Enabling Curated Built-in Packs

To enable any of the built-in shader packs, set their respective attributes to `true` in `programs.reshade.builtinPacks`:

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

### 2. Adding Custom Shader Packs (`extraPacks`)

You can declare any external Git repository or local directory using `extraPacks`. Nix will download the repository at build time and bundle its shaders into ReShade:

```nix
programs.reshade = {
  enable = true;

  extraPacks = {
    # Simple GitHub derivation:
    my-custom-shaders = pkgs.fetchFromGitHub {
      owner = "crosire";
      repo = "reshade-shaders";
      rev = "v6.0.0";
      hash = "sha256-...";
    };

    # Custom repository with specified subdirectories:
    advanced-pack = {
      src = pkgs.fetchFromGitHub {
        owner = "example-author";
        repo = "custom-shaders";
        rev = "main";
        hash = "sha256-...";
      };
      shadersSubdir = "Shaders";          # Subdirectory inside src containing .fx files (default: "Shaders")
      texturesSubdir = "Textures";        # Subdirectory inside src containing textures (default: "Textures")
      targetShadersSubdir = "MyPack";     # Nested directory inside ReShade shaders folder
      targetTexturesSubdir = "MyPack";    # Nested directory inside ReShade textures folder
    };
  };
};
```

---

## Configuration Examples

### NixOS Module (`configuration.nix`)

```nix
{ pkgs, ... }: {
  programs.reshade = {
    enable = true;

    # Initial default hotkeys (can still be modified in-game via UI)
    hotkeys = {
      overlay = "Shift+F6";   # Open / close ReShade menu
      effects = "Shift+F5";   # Toggle effects on / off
    };

    # Suppress welcome banner on game launch
    disableWelcomeBar = true;

    # Manually choose which shader packs to include
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

### Home Manager Module (`home.nix`)

```nix
{ pkgs, ... }: {
  programs.reshade = {
    enable = true;

    hotkeys = {
      overlay = "Shift+F6";
      effects = "Shift+F5";
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

    # Optional addons enabled declaratively
    defaultAddons = [ "fps_limit" ];
  };
}
```

---

## Game Launcher Integration

### Heronite
1. Open game settings in Heronite.
2. In **Environment Variables**, add:
   - `RESHADE = 1`
3. *(For legacy 32-bit Windows games like Gears of War or classic titles)*:
   - Enable **WoW64** (`enableWoW64 = true`) or set `PROTON_USE_WOW64 = 1`.
4. Launch the game.

### Heroic Games Launcher
1. Open game settings -> **Environment Variables**.
2. Add `RESHADE = 1`.
3. Launch the game.

### Steam
Set in the game's **Launch Options**:
```bash
reshade-run %command%
# or
RESHADE=1 %command%
```

### Flatpak
```bash
reshade-run flatpak run org.ppsspp.PPSSPP
```

### Direct Terminal
```bash
RESHADE=1 vkcube
```

---

## Default Hotkeys & In-Game UI Customization

- **Open / Close ReShade Menu**: Shift + F6
- **Toggle Effects**: Shift + F5

All shader selections, tweaks, hotkeys modified via the ReShade Settings tab, and presets are automatically saved and preserved in `~/.local/share/reshade/configurations/<game>/`.

---

## CLI Utilities

```bash
# Launch any executable with ReShade enabled
reshade-run my-game

# Launch with native Wine Wayland enabled
reshade-run -w my-game

# Inspect game profiles and configuration paths
reshade-preset list
reshade-preset dir my-game
```

---

## Credits and Acknowledgments

This project is built upon the open source ReShade ecosystem and brings together work from graphics researchers, developers, and artists:

### Core and Linux Vulkan Layer

- **ReShade**: Created and maintained by **Patrick Mours ([crosire](https://github.com/crosire))** and the ReShade community ([official site](https://reshade.me), [source code](https://github.com/crosire/reshade)).
- **ReShade Linux Vulkan Layer**: Native Linux Vulkan layer implementation developed by **[TheForgotten69](https://github.com/TheForgotten69)** ([source code](https://github.com/TheForgotten69/reshade)).
- **nix-reshade**: Initial packaging and inspiration for Nix/NixOS by **[LovingMelody](https://github.com/LovingMelody)** ([source code](https://github.com/LovingMelody/nix-reshade)).

### Shader and Texture Pack Authors

| Pack | Author / Maintainer | Repository | Highlights & Notable Effects |
| :--- | :--- | :--- | :--- |
| **Legacy** | **crosire** (Patrick Mours) & community | [crosire/reshade-shaders](https://github.com/crosire/reshade-shaders) | Standard official repository with core shaders (`FXAA`, `SMAA`, `Curves`, `Tonemap`, `Levels`, `Vibrance`, `LumaSharpen`, `Bloom`). |
| **SweetFX** | **CeeJay.dk** (Christian Cann Schuldt Jensen) | [CeeJayDK/SweetFX](https://github.com/CeeJayDK/SweetFX) | The pioneering post-processing suite that defined modern PC game visual modding (`HDR`, `Bloom`, `Cineon DPX`, `Technicolor`, `Monochrome`, `Curves`). |
| **qUINT** | **Marty McFly** (Pascal Gilcher) | [martymcmodding/qUINT](https://github.com/martymcmodding/qUINT) | High-fidelity post-processing framework (`qUINT_lightroom`, `qUINT_mxao`, `qUINT_dof`, `qUINT_sharp`, `qUINT_bloom`, `qUINT_ssr`). |
| **prod80** | **prod80** | [prod80/prod80-ReShade-Repository](https://github.com/prod80/prod80-ReShade-Repository) | Professional color grading and color correction suite (`Color Temperature`, `Color Balance`, `CMatrix`, `Film Grain`, `Shadows / Midtones / Highlights`). |
| **OtisFX** | **Frans Bouma** (Otis_Inf) | [FransBouma/OtisFX](https://github.com/FransBouma/OtisFX) | Cinematic depth and camera tools for in-game virtual photography (`CinematicDOF`, `AdaptiveFog`, `Emphasize`, `GoldenRatio`, `DepthAlpha`). |
| **Fubax** | **Fubaxiusz** | [Fubaxiusz/fubax-shaders](https://github.com/Fubaxiusz/fubax-shaders) | Stylized camera and lens optical effects (`Chromatic Aberration`, `PerfectPerspective`, `Prism`, `Fisheye`, `PaintFX`). |
| **AstrayFX** | **BlueSkyDefender** | [BlueSkyDefender/AstrayFX](https://github.com/BlueSkyDefender/AstrayFX) | Depth-aware enhancement shaders, notably `Clarity.fx` (local contrast boost without over-saturation) and `Depth_Refargo`. |
| **iMMERSE** | **Marty McFly** (Pascal Gilcher) | [martymcmodding/iMMERSE](https://github.com/martymcmodding/iMMERSE) | Modern Marty's Mods post-processing tools (`MartysMods_SHARPEN`, `MartysMods_SMAA`, `MartysMods_ReGrade`, `LAUNCHPAD`). |
| **GShade & PPFX** | **Mortalitas**, Marot Satil & community | [Mortalitas/GShade-Shaders](https://github.com/Mortalitas/GShade-Shaders) | Established shader collection popular in RPG/MMO communities, featuring `PPFX_Bloom.fx` and custom SSAO filters. |
| **Barbatos** | **BarbatosAWLS** | [BarbatosAWLS/Reshade-Shaders](https://github.com/BarbatosAWLS/Reshade-Shaders) | Real-time raymarched visual enhancements (`XeGTAO` Intel Ground Truth Ambient Occlusion, `SSR`, `DLAA-T`, `GI` Global Illumination). |
| **Textures & LUTs** | **Bhhl** (curator) | [Bhhl/Reshade-NewFinalRender-textures](https://github.com/Bhhl/Reshade-NewFinalRender-textures) | Consolidated blue noise tables, lens dirt masks, and LUT maps required by advanced shaders. |

---

## Automated Testing & Shader Verification

An automated verification test suite is provided to validate that every single shader across all curated packs compiles without any compilation errors, HLSL resource hazards, or Vulkan descriptor pool exhaustion.

```bash
# Run the automated test suite directly via Nix
nix run github:Cleison-oliveira/nix-reshade-manager#test-shaders

# Or run locally from this repository
nix run .#test-shaders
# Or:
./tests/test-shaders.sh
```

### What the Automated Test Validates:
1. Builds a standalone instance of ReShade with **all built-in shader packs enabled** (`reshade-full`).
2. Spawns an isolated Vulkan environment using `vkcube` with temporary sandboxed XDG data and cache directories.
3. Automatically parses `ReShade.log` upon completion to verify:
   - Over 900+ shaders were discovered and compiled.
   - Zero HLSL compilation errors (`error X...`).
   - Zero resource hazards or texture binding collisions.
   - Zero Vulkan descriptor pool exhaustion errors (`Failed to create sampler descriptor table`).

---

## Stability & Shader Compilation Fixes

### 1. Vulkan Descriptor Pool Expansion (Fixing Pool Exhaustion)
- **Problem**: Upstream ReShade hardcodes conservative descriptor limits in `source/vulkan/vulkan_impl_device.cpp` (only 128 samplers and 128 uniform buffers). When enabling rich shader packs (such as iMMERSE, Barbatos, or qUINT), loading more than 128 shaders causes Vulkan to exhaust its descriptor pool, throwing `Failed to create sampler descriptor table for effect file ...` or `Failed to create constant buffer descriptor table ...` and failing to load subsequent effects.
- **Solution**: The derivation applies a binary patch to `ReShade64_orig.so`, increasing the descriptor limits to 8,192 samplers and UBOs and 16,384 maximum descriptor sets. This allows all shader packs to compile and execute concurrently without pool exhaustion.

### 2. AstrayFX Shader Hazard Fixes (HLSL Error X3020)
- **Problem**: Several shaders from the AstrayFX pack failed to compile with:
  `error X3020: cannot sample from texture that is also used as render target in the same pass`
  - In `SnowScape.fx`: A single `SmoothNormals` function branched based on direction, referencing `N_Sampler_A` (which samples `Normals_A`) while rendering pass `Alpha` into `RenderTarget0 = Normals_A`.
  - In `RadiantGI.fx`: Pass `CopyFrame` sampled `PCGIcurrColor` (`PCGIcurrColorTex`) in `Ublur()` while setting `RenderTarget0 = PCGIcurrColorTex`.
- **Solution**:
  - `SnowScape.fx`: Separated into two distinct directional smoothing routines (`SmoothNormalsH` and `SmoothNormalsV`) so pass `Alpha` never references `N_Sampler_A`.
  - `RadiantGI.fx`: Replaced `PCGIcurrColor` with `BackBufferPCGI` in `CurrentFrame`, sampling the source backbuffer instead of the target texture.

### 3. Declarative Search Path Sanitization
- **Problem**: Changing NixOS generations or updating the flake changed the `/nix/store/...` hash. In previous iterations, old store paths accumulated in `ReShade.ini`, causing ReShade worker threads to scan and compile 4-5 duplicate copies of every shader in parallel, exhausting CPU cache and leading to race conditions.
- **Solution**: `loader_filter.c` automatically purges obsolete `/nix/store/...` paths, ensures the current authoritative Nix store path is prioritized, and preserves user custom paths without duplication.

---

## License

Distributed under the BSD-3-Clause license, matching upstream ReShade. Individual shader packs remain under their respective licenses specified by their authors in their repositories.
