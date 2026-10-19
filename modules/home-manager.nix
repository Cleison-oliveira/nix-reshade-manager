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
  keyReload = hotkeyLib.toReShadeHotkey cfg.hotkeys.reload;
  keyNextPreset = hotkeyLib.toReShadeHotkey cfg.hotkeys.nextPreset;
  keyPreviousPreset = hotkeyLib.toReShadeHotkey cfg.hotkeys.previousPreset;
  keyScreenshot = hotkeyLib.toReShadeHotkey cfg.hotkeys.screenshot;

  defaultPackage = pkgs.callPackage ../pkgs/reshade.nix {
    inherit (cfg) builtinPacks extraPacks disableWelcomeBar;
    inherit keyOverlay keyEffects keyReload keyNextPreset keyPreviousPreset keyScreenshot;
  };

  declarativeAddons = lib.listToAttrs (map (addon: {
    name = "reshade/${addon}.addon64";
    value = {
      source = "${cfg.package}/share/reshade/optional-addons/${addon}.addon64";
    };
  }) cfg.defaultAddons);
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
        type = types.nullOr types.str;
        default = "Shift+F6";
        example = "Home";
        description = "Initial default hotkey to open/close the ReShade in-game menu (e.g. 'Shift+F6', 'Home', 'None', or null/empty).";
      };

      effects = mkOption {
        type = types.nullOr types.str;
        default = "Shift+F5";
        example = "Shift+F5";
        description = "Initial default hotkey to toggle post-processing effects on/off (e.g. 'Shift+F5', 'ScrollLock', 'None', or null/empty).";
      };

      reload = mkOption {
        type = types.nullOr types.str;
        default = "None";
        example = "Shift+F4";
        description = "Initial default hotkey to reload all effects and textures (e.g. 'Shift+F4', 'Ctrl+Shift+R', 'None', or null/empty).";
      };

      nextPreset = mkOption {
        type = types.nullOr types.str;
        default = "None";
        example = "PageUp";
        description = "Initial default hotkey to switch to the next preset (e.g. 'PageUp', 'Shift+F8', 'None', or null/empty).";
      };

      previousPreset = mkOption {
        type = types.nullOr types.str;
        default = "None";
        example = "PageDown";
        description = "Initial default hotkey to switch to the previous preset (e.g. 'PageDown', 'Shift+F7', 'None', or null/empty).";
      };

      screenshot = mkOption {
        type = types.nullOr types.str;
        default = "None";
        example = "PrintScreen";
        description = "Initial default hotkey to take a screenshot (e.g. 'PrintScreen', 'Shift+F12', 'None', or null/empty).";
      };
    };

    disableWelcomeBar = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to patch ReShade binary to permanently suppress the initial welcome/tutorial bar on startup.";
    };

    builtinPacks = {
      legacy = mkOption {
        type = types.bool;
        default = false;
        description = "Standard ReShade shader repository (by crosire / reshade-shaders).";
      };
      sweetfx = mkOption {
        type = types.bool;
        default = false;
        description = "SweetFX shader suite (by CeeJay.dk / CeeJayDK).";
      };
      quint = mkOption {
        type = types.bool;
        default = false;
        description = "qUINT shader framework (by Pascal Gilcher / martymcmodding).";
      };
      prod80 = mkOption {
        type = types.bool;
        default = false;
        description = "Color correction and grading shaders (by prod80).";
      };
      otisfx = mkOption {
        type = types.bool;
        default = false;
        description = "OtisFX cinematic shaders and camera tools (by Frans Bouma / Otis_Inf).";
      };
      fubax = mkOption {
        type = types.bool;
        default = false;
        description = "Fubax optical and styling shaders (by Fubaxiusz).";
      };
      astrayfx = mkOption {
        type = types.bool;
        default = false;
        description = "AstrayFX clarity and depth shaders (by BlueSkyDefender / Clarity.fx).";
      };
      immerse = mkOption {
        type = types.bool;
        default = false;
        description = "iMMERSE Marty's Mods (by Pascal Gilcher / MartysMods_SHARPEN, MartysMods_SMAA).";
      };
      gshade = mkOption {
        type = types.bool;
        default = false;
        description = "GShade & PPFX Bloom collection (by Mortalitas and community).";
      };
      reshadeTextures = mkOption {
        type = types.bool;
        default = false;
        description = "Consolidated textures, blue noise and LUTs collection (curated by Bhhl).";
      };
      barbatos = mkOption {
        type = types.bool;
        default = false;
        description = "Barbatos shaders (XeGTAO, SSR, DLAA-T, GI by BarbatosAWLS).";
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
      description = "List of optional addons to enable declaratively (e.g. 'fps_limit').";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
    ];

    home.sessionVariables = {
      # Avoid collision if legacy layer exists on system
      VK_LOADER_LAYERS_DISABLE = "VK_LAYER_reshade_x86_64";
    };

    # Vulkan manifests for RESHADE=1 and RESHADE_ENABLE=1
    xdg.dataFile = {
      "vulkan/implicit_layer.d/ReShade.json".source =
        "${cfg.package}/share/vulkan/implicit_layer.d/ReShade.json";
      "vulkan/implicit_layer.d/ReShade64.json".source =
        "${cfg.package}/share/vulkan/implicit_layer.d/ReShade64.json";
    } // declarativeAddons;
  };
}
