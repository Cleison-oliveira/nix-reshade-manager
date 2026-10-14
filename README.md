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
- Declarative Shader Pack Management:
  - Curated built-in packs enabled or disabled individually (crosire, SweetFX, qUINT, prod80, OtisFX, Fubax, AstrayFX, iMMERSE, GShade, Barbatos, Textures).
  - Support for custom declarative packs via `extraPacks`.
- Standardized Hotkeys:
  - Configure key combinations using friendly strings (e.g. `"Shift+F6"`, `"Home"`, `"Shift+F5"`, `"ScrollLock"`) or raw ReShade codes.
  - Default: **Shift + F6** (ReShade menu) and **Shift + F5** (Toggle effects).
- Welcome Tutorial Suppression:
  - Optional binary patch (`disableWelcomeBar = true`) that permanently suppresses the startup welcome banner.
- Included CLI Tools:
  - `reshade-run` / `reshade`: Game launcher compatible with Flatpak, Wayland, and Steam.
  - `reshade-preset`: Inspect profiles and presets per game.
  - `reshade-addon`: Enable and disable optional addons (`.addon64`).
  - `reshade-install-shaders`: Sync and manage the shader library.

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

## Configuration

### 1. NixOS Module (`configuration.nix`)

```nix
{ pkgs, ... }: {
  programs.reshade = {
    enable = true;

    # In-game hotkeys
    hotkeys = {
      overlay = "Shift+F6";   # Open / close ReShade menu
      effects = "Shift+F5";   # Toggle effects on / off
    };

    # Suppress welcome banner on game launch
    disableWelcomeBar = true;

    # Enable or disable built-in shader packs
    builtinPacks = {
      legacy = true;           # Standard ReShade shaders (crosire)
      sweetfx = true;          # SweetFX shaders (CeeJay.dk)
      quint = true;            # qUINT framework (Marty McFly / Pascal Gilcher)
      prod80 = true;           # Color grading shaders (prod80)
      otisfx = true;           # Cinematic photography shaders (Frans Bouma / Otis_Inf)
      fubax = true;            # Optical effects shaders (Fubaxiusz)
      astrayfx = true;         # Clarity and depth effects (BlueSkyDefender)
      immerse = true;          # iMMERSE Marty's Mods (Marty McFly / Pascal Gilcher)
      gshade = true;           # GShade & PPFX Bloom (Mortalitas)
      reshadeTextures = true;  # Consolidated textures and LUTs (Bhhl)
      barbatos = true;         # XeGTAO, SSR, DLAA-T, GI (BarbatosAWLS)
    };

    # Optional custom shader packs
    extraPacks = {
      custom-shaders = pkgs.fetchFromGitHub {
        owner = "crosire";
        repo = "reshade-shaders";
        rev = "master";
        hash = "sha256-...";
      };
    };
  };
}
```

### 2. Home Manager Module (`home.nix`)

```nix
{ pkgs, ... }: {
  programs.reshade = {
    enable = true;

    hotkeys = {
      overlay = "Shift+F6";
      effects = "Shift+F5";
    };

    # Automatically sync shader files to ~/.local/share/reshade on activation
    autoSyncShaders = true;

    # Addons enabled by default
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

## Default Hotkeys

- **Open / Close ReShade Menu**: Shift + F6
- **Toggle Effects**: Shift + F5

All shader selections, tweaks, and custom presets are automatically saved under `~/.local/share/reshade/configurations/<game>/`.

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

# Manage optional addons
reshade-addon list
reshade-addon enable fps_limit
reshade-addon disable fps_limit

# Synchronize or restore shader files
reshade-install-shaders --sync
reshade-install-shaders --force
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

## License

Distributed under the BSD-3-Clause license, matching upstream ReShade. Individual shader packs remain under their respective licenses specified by their authors in their repositories.
