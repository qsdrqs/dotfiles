{
  description = "NixOS flakes";

  # Inputs
  # https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html#flake-inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-fix.url = "github:NixOS/nixpkgs/c75037bbf9093a2acb617804ee46320d6d1fea5a";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ranger-config.url = "path:ranger";
    zsh-config.url = "path:zsh";
    nvim-config.url = "path:nvim";
    dev-shell.url = "path:nixos/dev-shell";

    # wsl
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };

    # brostrend rtl88x2bu wifi dkms
    rtl88x2bu-dkms = {
      url = "https://linux.brostrend.com/rtl88x2bu-dkms.deb";
      flake = false;
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nur
    nur.url = "github:nix-community/NUR";

    # nix-on-droid = {
    #   url = "github:t184256/nix-on-droid";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.home-manager.follows = "home-manager";
    # };

    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xdph = {
      url = "github:hyprwm/xdg-desktop-portal-hyprland";
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

    vscode-insiders = {
      url = "tarball+https://update.code.visualstudio.com/latest/linux-x64/insider";
      flake = false;
    };

    # tmux
    tmux-resurrect = {
      url = "github:tmux-plugins/tmux-resurrect";
      flake = false;
    };
    tmux-continuum = {
      url = "github:tmux-plugins/tmux-continuum";
      flake = false;
    };
  };

  # Work-in-progress: refer to parent/sibling flakes in the same repository
  # inputs.c-hello.url = "path:../c-hello";

  outputs = { self, nixpkgs, home-manager, vscode-server, nur, dev-shell, ... }@inputs:
    rec {
      pkgs-collect = builtins.listToAttrs (builtins.map
        (pkg: {
          name = pkg;
          value = (system: import inputs.${pkg} {
            system = system;
            config.allowUnfree = true;
          });
        }) [ "nixpkgs-master" "nixpkgs-fix" ]
      );
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
      standaloneHomeModules = basicHomeModules ++ [
        ./nixos/standalone-home.nix
      ];
      desktopHomeModules = basicHomeModules ++ guiHomeModules;

      minimalConfig = rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          pkgs-master = pkgs-collect.nixpkgs-master system;
          pkgs-fix = pkgs-collect.nixpkgs-fix system;
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
            services.vscode-server.installPath = "~/.vscode-server-insiders";
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
      rpiConfig = basicConfig // {
        system = "aarch64-linux";
        modules = basicConfig.modules ++ [
          ./nixos/rpi-configuration.nix
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

      minimalHomeConfig =
        let
          system = "x86_64-linux";
        in
        {
          pkgs = pkgs' system;
          modules = minimalHomeModules;
          extraSpecialArgs = { inherit inputs; };
        };
      basicHomeConfig = minimalHomeConfig // {
        modules = basicHomeModules;
      };
      rpiHomeConfig = basicHomeConfig // (
        let
          system = "aarch64-linux";
        in
        {
          pkgs = pkgs' system;
        }
      );
      wslHomeConfig = basicHomeConfig // {
        modules = wslHomeModules;
      };
      # for non-NixOS systems
      standaloneHomeConfig = basicHomeConfig // {
        modules = standaloneHomeModules;
      };
      termuxHomeConfig = rpiHomeConfig // {
        modules = standaloneHomeModules ++ [
          ./nixos/termux-home.nix
        ];
      };

      isoConfig = minimalConfig // {
        modules = minimalConfig.modules ++ [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = import ./nixos/isohome.nix;
          }

          ({ config, pkgs, lib, ... }: {
            services.getty.autologinUser = nixpkgs.lib.mkForce "qsdrqs";
            networking.networkmanager.enable = nixpkgs.lib.mkForce false;

            # Disable ZFS for latest kernel, see https://github.com/NixOS/nixpkgs/issues/58959
            boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];
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
        overlays = (nixpkgs.legacyPackages.${system}.callPackage ./nixos/overlays.nix { inputs = inputs; }).nixpkgs.overlays;
      });
      archSpecConfig = func: archs: builtins.listToAttrs (builtins.map
        (system: {
          name = system;
          value = func system;
        })
        archs);
      archSpecConfigAll = func: archSpecConfig func [ "x86_64-linux" "aarch64-linux" "i686-linux" ];

      #####################Configuration#####################

      nixosConfigurations.minimal = nixpkgs.lib.nixosSystem minimalConfig;
      nixosConfigurations.basic = nixpkgs.lib.nixosSystem basicConfig;
      nixosConfigurations.server = nixpkgs.lib.nixosSystem serverConfig;
      nixosConfigurations.rpi = nixpkgs.lib.nixosSystem rpiConfig;
      nixosConfigurations.gui = nixpkgs.lib.nixosSystem guiConfig;
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem wslConfig;
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem desktopConfig;

      # nix-on-droid
      # nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration rec {
      #   system = "aarch64-linux";
      #   modules = [
      #     ./nixos/nix-on-droid.nix
      #   ];
      #   extraSpecialArgs = { inherit inputs; pkgs = pkgs' system; hm-module = basicHomeModules; };
      # };

      images =
        let
          # we don't want to build the iso with custom.nix
          removeCustom = (config: config // {
            modules = (nixpkgs.lib.lists.remove ./nixos/custom.nix config.modules);
          });
        in
        {
          # iso, build through #images.nixos-iso
          nixos-iso = (nixpkgs.lib.nixosSystem (removeCustom isoConfig)).config.system.build.isoImage;
          nixos-iso-gui = (nixpkgs.lib.nixosSystem (removeCustom isoGuiConfig)).config.system.build.isoImage;
          # rpi, build through #images.rpi
          rpi = (nixpkgs.lib.nixosSystem (removeCustom rpiConfig // {
            modules = rpiConfig.modules ++ [
              "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
              ({ config, pkgs, ... }: {
                # empty passwd
                users.users.qsdrqs.password = "";
              })
            ];
          })).config.system.build.sdImage;
        };

      # home-manager
      homeConfigurations.minimal = home-manager.lib.homeManagerConfiguration minimalHomeConfig;
      homeConfigurations.basic = home-manager.lib.homeManagerConfiguration basicHomeConfig;
      homeConfigurations.rpi = home-manager.lib.homeManagerConfiguration rpiHomeConfig;
      homeConfigurations.wsl = home-manager.lib.homeManagerConfiguration wslHomeConfig;
      homeConfigurations.standalone = home-manager.lib.homeManagerConfiguration standaloneHomeConfig;
      homeConfigurations.termux = home-manager.lib.homeManagerConfiguration termuxHomeConfig;

      # dev shells
      devShells = archSpecConfigAll (system: (pkgs' system).callPackage dev-shell.shells { inputs = inputs; });
      # direct nix run
      packages = archSpecConfigAll (system: pkgs' system) // {
        x86_64-linux.hack-pylsp = (pkgs' "x86_64-linux").callPackage ./nixos/hack-pylsp.nix { };
      };
      legacyPackages = nixpkgs.legacyPackages;
      inputs_ = inputs;
    };
}
