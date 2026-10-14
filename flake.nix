{
  description = "Declarative ReShade & Shaders manager for NixOS and Home Manager (Linux Vulkan)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    systems = [
      "x86_64-linux"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    }));
    hotkeyLib = import ./pkgs/hotkeys.nix;
  in {
    lib = {
      inherit (hotkeyLib) toReShadeHotkey;
      mkReshade = {
        pkgs,
        version ? "6.8.0-beta.3",
        builtinPacks ? {},
        extraPacks ? {},
        keyOverlay ? "117,0,1,0",
        keyEffects ? "116,0,1,0",
        disableWelcomeBar ? true,
      }:
        pkgs.callPackage ./pkgs/reshade.nix {
          inherit version builtinPacks extraPacks disableWelcomeBar;
          inherit keyOverlay keyEffects;
        };
    };

    packages = forAllSystems (pkgs: let
      reshade = pkgs.callPackage ./pkgs/reshade.nix {};
      reshadeRun = pkgs.callPackage ./pkgs/tools/reshade-run.nix {inherit reshade;};
      reshadeBin = pkgs.writeShellScriptBin "reshade" ''
        exec ${reshadeRun}/bin/reshade-run "$@"
      '';
      reshadePreset = pkgs.callPackage ./pkgs/tools/reshade-preset.nix {};
      reshadeAddon = pkgs.callPackage ./pkgs/tools/reshade-addon.nix {inherit reshade;};
      reshadeInstallShaders = pkgs.callPackage ./pkgs/tools/reshade-install-shaders.nix {inherit reshade;};
    in {
      default = reshade;
      reshade = reshade;
      reshade-run = reshadeRun;
      reshade-bin = reshadeBin;
      reshade-preset = reshadePreset;
      reshade-addon = reshadeAddon;
      reshade-install-shaders = reshadeInstallShaders;
    });

    apps = forAllSystems (pkgs: {
      default = {
        type = "app";
        program = "${self.packages.${pkgs.system}.reshade-run}/bin/reshade-run";
      };
      reshade = {
        type = "app";
        program = "${self.packages.${pkgs.system}.reshade-run}/bin/reshade-run";
      };
      reshade-preset = {
        type = "app";
        program = "${self.packages.${pkgs.system}.reshade-preset}/bin/reshade-preset";
      };
      reshade-addon = {
        type = "app";
        program = "${self.packages.${pkgs.system}.reshade-addon}/bin/reshade-addon";
      };
      reshade-install-shaders = {
        type = "app";
        program = "${self.packages.${pkgs.system}.reshade-install-shaders}/bin/reshade-install-shaders";
      };
    });

    overlays.default = final: prev: {
      reshade = self.packages.${prev.system}.reshade;
      reshade-run = self.packages.${prev.system}.reshade-run;
      reshade-preset = self.packages.${prev.system}.reshade-preset;
      reshade-addon = self.packages.${prev.system}.reshade-addon;
      reshade-install-shaders = self.packages.${prev.system}.reshade-install-shaders;
    };

    nixosModules = {
      default = import ./modules/nixos.nix;
      reshade = import ./modules/nixos.nix;
    };

    homeManagerModules = {
      default = import ./modules/home-manager.nix;
      reshade = import ./modules/home-manager.nix;
    };
  };
}
