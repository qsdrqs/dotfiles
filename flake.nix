{
  description = "NixOS flakes";

  # Inputs
  # https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html#flake-inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ranger = {
      url = "github:ranger/ranger";
      flake = false;
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zsh-config.url = "path:zsh";
    nvim-config.url = "path:nvim/flake";

    # wsl
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nur
    nur.url = "github:nix-community/NUR";

    nix-on-droid = {
      url = "github:t184256/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    code-marketplace = {
      url = "git+https://aur.archlinux.org/code-marketplace.git?ref=master";
      flake = false;
    };
    code-features = {
      url = "git+https://aur.archlinux.org/code-features.git?ref=master";
      flake = false;
    };
  };

  # Work-in-progress: refer to parent/sibling flakes in the same repository
  # inputs.c-hello.url = "path:../c-hello";

  outputs = { self, nixpkgs, home-manager, vscode-server, nur, nix-on-droid, ... }@inputs:
    let
      pkgs-master = import inputs.nixpkgs-master {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      minimalHomeModules = [
        ./nixos/home.nix
      ];
      basicHomeModules = minimalHomeModules ++ [
        ./nixos/nvim-plugins.nix
      ];
      guiHomeModules = minimalHomeModules ++ [
        ./nixos/gui-home.nix
      ];
      wslHomeModules = basicHomeModules ++ [
        ./nixos/wsl-home.nix
      ];
      desktopHomeModules = basicHomeModules ++ guiHomeModules;

      minimalConfig = {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          pkgs-master = pkgs-master;
        };
        modules = [
          (if builtins.pathExists ./nixos/custom.nix then
            ./nixos/custom.nix
          else
            nixpkgs.lib.warn "No custom.nix found, maybe you forgot to copy the hardware-configuration.nix?"
              ./nixos/empty.nix
          )
          ./nixos/minimal-configuration.nix
          ./nixos/overlays.nix

          # home-manager module
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.qsdrqs = {
              imports = minimalHomeModules;
            };

            # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix
            home-manager.extraSpecialArgs = { inherit inputs; };
          }

        ];
      };
      basicConfig = minimalConfig // {
        modules = minimalConfig.modules ++ [
          ./nixos/basic-configuration.nix

          # vscode-server
          vscode-server.nixosModules.default
          ({ config, pkgs, ... }: {
            services.vscode-server.enable = true;
          })

          # NUR
          nur.nixosModules.nur

          # nix index database
          inputs.nix-index-database.nixosModules.nix-index

          # nvim plugins
          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = {
              imports = basicHomeModules;
            };
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };
      serverConfig = basicConfig // {
        modules = basicConfig.modules ++ [
          ./nixos/server-configuration.nix
        ];
      };
      guiConfig = minimalConfig // {
        modules = minimalConfig.modules ++ [
          ./nixos/gui-configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = {
              imports = guiHomeModules;
            };
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };

      wslConfig = basicConfig // {
        modules = basicConfig.modules ++ [
          ./nixos/wsl-configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = {
              imports = wslHomeModules;
            };
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };

      desktopConfig = basicConfig // guiConfig // {
        modules = basicConfig.modules ++ guiConfig.modules ++ [
          ./nixos/desktop-configuration.nix
        ];
      };

      minimalHomeConfig = {
        pkgs = x86_64-linux-pkgs;
        modules = minimalHomeModules;
        extraSpecialArgs = { inherit inputs; };
      };
      guiHomeConfig = minimalHomeConfig // {
        modules = guiHomeModules;
      };
      basicHomeConfig = minimalHomeConfig // {
        modules = basicHomeModules;
      };
      desktopHomeConfig = guiHomeConfig // {
        modules = desktopHomeModules;
      };
      wslHomeConfig = basicHomeConfig // {
        modules = wslHomeModules;
      };

      isoConfig = minimalConfig // {
        modules = minimalConfig.modules ++ [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

          home-manager.nixosModules.home-manager
          {
            # impure
            home-manager.users.qsdrqs = import ./nixos/isohome.nix;
          }

          ({ config, pkgs, ... }: {
            services.getty.autologinUser = nixpkgs.lib.mkForce "qsdrqs";

            services.interception-tools = {
              enable = true;
              plugins = [ pkgs.interception-tools-plugins.caps2esc ];
              udevmonConfig = ''
                - JOB: "${pkgs.interception-tools}/bin/intercept -g $DEVNODE | ${pkgs.interception-tools-plugins.caps2esc}/bin/caps2esc | ${pkgs.interception-tools}/bin/uinput -d $DEVNODE"
                  DEVICE:
                    EVENTS:
                      EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
              '';
            };

            networking.networkmanager.enable = nixpkgs.lib.mkForce false;
          })
        ];
      };

      isoGuiConfig = isoConfig // {
        modules = isoConfig.modules ++ [
          ./nixos/gui-configuration.nix
        ];
      };

      pkgs' = (system: import nixpkgs {
        system = system;
        config.allowUnfree = true;
        overlays = (import ./nixos/overlays.nix {
          inherit inputs;
          pkgs = nixpkgs.legacyPackages.${system};
          config = nixpkgs.config;
          lib = nixpkgs.lib;
        }).nixpkgs.overlays;
      });
      x86_64-linux-pkgs = pkgs' "x86_64-linux";
      aarch64-linux-pkgs = pkgs' "aarch64-linux";
    in
    {
      nixosConfigurations.minimal = nixpkgs.lib.nixosSystem minimalConfig;
      nixosConfigurations.basic = nixpkgs.lib.nixosSystem basicConfig;
      nixosConfigurations.server = nixpkgs.lib.nixosSystem serverConfig;
      nixosConfigurations.gui = nixpkgs.lib.nixosSystem guiConfig;
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem wslConfig;
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem desktopConfig;

      # nix-on-droid
      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        modules = [
          ./nixos/nix-on-droid.nix
        ];
        extraSpecialArgs = { inherit inputs; pkgs = aarch64-linux-pkgs; hm-module = basicHomeModules;};
      };

      # iso, build through #nixos-iso.config.system.build.isoImage
      nixos-iso = nixpkgs.lib.nixosSystem isoConfig;
      nixos-iso-gui = nixpkgs.lib.nixosSystem isoGuiConfig;

      # home-manager
      homeConfigurations.minimal = home-manager.lib.homeManagerConfiguration minimalHomeConfig;
      homeConfigurations.basic = home-manager.lib.homeManagerConfiguration basicHomeConfig;
      homeConfigurations.gui = home-manager.lib.homeManagerConfiguration guiHomeConfig;
      homeConfigurations.wsl = home-manager.lib.homeManagerConfiguration wslHomeConfig;

      homeConfigurations.desktop = home-manager.lib.homeManagerConfiguration desktopHomeConfig;
      # dev shells
      devShells = {
        x86_64-linux = (import ./nixos/dev-shell.nix {
          pkgs = x86_64-linux-pkgs;
          lib = nixpkgs.lib;
        });
        aarch64-linux = (import ./nixos/dev-shell.nix {
          pkgs = aarch64-linux-pkgs;
          lib = nixpkgs.lib;
        });
      };
      # direct nix run
      packages = {
        x86_64-linux = x86_64-linux-pkgs;
        aarch64-linux = aarch64-linux-pkgs;
      };
      legacyPackages = nixpkgs.legacyPackages;
    };
}
