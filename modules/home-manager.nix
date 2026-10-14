{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkEnableOption mkIf types literalExpression;
  cfg = config.programs.reshade;
  hotkeyLib = import ../pkgs/hotkeys.nix;

  keyOverlay = hotkeyLib.toReShadeHotkey cfg.hotkeys.overlay;
  keyEffects = hotkeyLib.toReShadeHotkey cfg.hotkeys.effects;

  defaultPackage = pkgs.callPackage ../pkgs/reshade.nix {
    inherit (cfg) builtinPacks extraPacks disableWelcomeBar;
    inherit keyOverlay keyEffects;
  };

  reshadeRun = pkgs.callPackage ../pkgs/tools/reshade-run.nix {
    reshade = cfg.package;
  };

  reshadeBin = pkgs.writeShellScriptBin "reshade" ''
    exec ${reshadeRun}/bin/reshade-run "$@"
  '';

  reshadePreset = pkgs.callPackage ../pkgs/tools/reshade-preset.nix {};

  reshadeAddon = pkgs.callPackage ../pkgs/tools/reshade-addon.nix {
    reshade = cfg.package;
  };

  reshadeInstallShaders = pkgs.callPackage ../pkgs/tools/reshade-install-shaders.nix {
    reshade = cfg.package;
  };

  enableAddonCmds = lib.concatMapStringsSep "\n" (addon: ''
    ${reshadeAddon}/bin/reshade-addon enable "${addon}" || true
  '') cfg.defaultAddons;
in {
  options.programs.reshade = {
    enable = mkEnableOption "ReShade post-processing injector for Linux Vulkan";

    package = mkOption {
      type = types.package;
      default = defaultPackage;
      defaultText = literalExpression "pkgs.callPackage .../pkgs/reshade.nix { ... }";
      description = "The ReShade derivation to use.";
    };

    hotkeys = {
      overlay = mkOption {
        type = types.str;
        default = "Shift+F6";
        example = "Home";
        description = "Hotkey to open/close the ReShade in-game menu (e.g. 'Shift+F6', 'Home', 'Shift+Home', 'F2', or raw '117,0,1,0').";
      };

      effects = mkOption {
        type = types.str;
        default = "Shift+F5";
        example = "Shift+F5";
        description = "Hotkey to toggle post-processing effects on/off (e.g. 'Shift+F5', 'ScrollLock', or raw '116,0,1,0').";
      };
    };

    disableWelcomeBar = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to patch ReShade binary to permanently suppress the initial welcome/tutorial bar on startup.";
    };

    autoSyncShaders = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically sync the shader collection into ~/.local/share/reshade/reshade-shaders on activation.";
    };

    builtinPacks = {
      legacy = mkOption {
        type = types.bool;
        default = true;
        description = "Standard ReShade shader repository (crosire/reshade-shaders).";
      };
      sweetfx = mkOption {
        type = types.bool;
        default = true;
        description = "SweetFX shader suite (CeeJayDK/SweetFX).";
      };
      quint = mkOption {
        type = types.bool;
        default = true;
        description = "qUINT shader framework (martymcmodding/qUINT).";
      };
      prod80 = mkOption {
        type = types.bool;
        default = true;
        description = "prod80 color correction and grading shaders.";
      };
      otisfx = mkOption {
        type = types.bool;
        default = true;
        description = "OtisFX cinematic shaders and camera tools (FransBouma/OtisFX).";
      };
      fubax = mkOption {
        type = types.bool;
        default = true;
        description = "Fubax shaders and post-processing tools.";
      };
      astrayfx = mkOption {
        type = types.bool;
        default = true;
        description = "AstrayFX clarity and sharpness shaders (Clarity.fx).";
      };
      immerse = mkOption {
        type = types.bool;
        default = true;
        description = "iMMERSE Marty's Mods (MartysMods_SHARPEN, MartysMods_SMAA).";
      };
      gshade = mkOption {
        type = types.bool;
        default = true;
        description = "GShade & PPFX Bloom collection (PPFX_Bloom.fx).";
      };
      reshadeTextures = mkOption {
        type = types.bool;
        default = true;
        description = "Consolidated textures and LUTs collection.";
      };
      barbatos = mkOption {
        type = types.bool;
        default = true;
        description = "Barbatos shaders (XeGTAO, SSR, DLAA-T, GI).";
      };
    };

    extraPacks = mkOption {
      type = types.attrsOf (types.either types.package types.attrs);
      default = {};
      example = literalExpression ''
        {
          my-shaders = pkgs.fetchFromGitHub {
            owner = "author";
            repo = "my-shaders";
            rev = "main";
            hash = "...";
          };
        }
      '';
      description = "Declarative custom shader pack derivations to bundle into ReShade.";
    };

    defaultAddons = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["fps_limit"];
      description = "List of optional addons to enable (e.g. 'fps_limit').";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
      reshadeBin
      reshadeRun
      reshadePreset
      reshadeAddon
      reshadeInstallShaders
    ];

    home.sessionVariables = {
      # Evita colisao caso exista camada legada no sistema
      VK_LOADER_LAYERS_DISABLE = "VK_LAYER_reshade_x86_64";
    };

    # Manifesto Vulkan para RESHADE=1 e RESHADE_ENABLE=1
    xdg.dataFile."vulkan/implicit_layer.d/ReShade.json".source =
      "${cfg.package}/share/vulkan/implicit_layer.d/ReShade.json";
    xdg.dataFile."vulkan/implicit_layer.d/ReShade64.json".source =
      "${cfg.package}/share/vulkan/implicit_layer.d/ReShade64.json";

    # Sincronizacao automatica da biblioteca de shaders na ativacao
    home.activation.setupReshadeShaders = mkIf cfg.autoSyncShaders (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD ${reshadeInstallShaders}/bin/reshade-install-shaders --sync
        ${enableAddonCmds}
      ''
    );
  };
}
