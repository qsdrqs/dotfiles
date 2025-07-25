{
  description = "NixOS flakes";

  # Inputs
  # https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html#flake-inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-last.url = "github:NixOS/nixpkgs/62e0f05ede1da0d54515d4ea8ce9c733f12d9f08";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Specific commits to fix the version of some packages.
    nixpkgs-ghcup.url = "github:qxrein/nixpkgs/patch-1";
    nixpkgs-intel-npu-driver.url = "github:pseudocc/nixpkgs/intel-npu-firmware";
    nixpkgs-howdy.url = "github:fufexan/nixpkgs/howdy";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ctrl2esc = {
      url = "gitlab:qsdrqs/ctrl2esc";
      flake = false;
    };

    yazi = {
      url = "github:sxyazi/yazi";
    };
    # yazi-aarch64-nightly = {
    #   url = "https://github.com/sxyazi/yazi/releases/download/nightly/yazi-aarch64-unknown-linux-gnu.zip";
    #   flake = false;
    # };

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
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    waybar = {
      url = "github:Alexays/Waybar";
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

    # vscode-insiders = {
    #   url = "tarball+https://update.code.visualstudio.com/latest/linux-x64/insider";
    #   flake = false;
    # };

    # tmux
    tmux-resurrect = {
      url = "github:tmux-plugins/tmux-resurrect";
      flake = false;
    };
    tmux-continuum = {
      url = "github:tmux-plugins/tmux-continuum";
      flake = false;
    };

    # yazi
    yazi-searchjump = {
      url = "git+https://gitee.com/DreamMaoMao/searchjump.yazi";
      flake = false;
    };
    yazi-plugins = {
      url = "github:yazi-rs/plugins";
      flake = false;
    };
    yazi-starship = {
      url = "github:Rolv-Apneseth/starship.yazi";
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
          value = (system: import inputs."nix${pkg}" {
            system = system;
            config.allowUnfree = true;
            overlays = (nixpkgs.legacyPackages.${system}.callPackage ./nixos/overlays.nix { inputs = inputs; }).nixpkgs.overlays;
          });
        }) [
          "pkgs-master"
          "pkgs-stable"
          "pkgs-ghcup"
          "pkgs-intel-npu-driver"
          "pkgs-howdy"
          "pkgs-last"
          "pkgs"
        ]
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
      laptopHomeModules = basicHomeModules ++ guiHomeModules;

      special-args = system: {
        inherit inputs;
        pkgs-master = pkgs-collect.pkgs-master system;
        pkgs-stable = pkgs-collect.pkgs-stable system;
        pkgs-ghcup = pkgs-collect.pkgs-ghcup system;
        pkgs-intel-npu-driver = pkgs-collect.pkgs-intel-npu-driver system;
        pkgs-howdy = pkgs-collect.pkgs-howdy system;
        pkgs-last = pkgs-collect.pkgs-last system;
      };

      minimalConfig = rec {
        system = "x86_64-linux";
        specialArgs = special-args system;
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
            home-manager.extraSpecialArgs = specialArgs;
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
            services.vscode-server.installPath = "$HOME/.vscode-server";
          })

          # NUR
          nur.modules.nixos.default

          # nix index database
          inputs.nix-index-database.nixosModules.nix-index

          # nvim plugins
          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = {
              imports = basicHomeModules;
            };
            home-manager.extraSpecialArgs = special-args minimalConfig.system;
          }
        ];
      };
      serverConfig = basicConfig // {
        modules = basicConfig.modules ++ [
          ./nixos/server-configuration.nix
        ];
      };
      rpiConfig = basicConfig // rec {
        system = "aarch64-linux";
        specialArgs = special-args system;
        modules = basicConfig.modules ++ [
          ./nixos/rpi-configuration.nix

          # aarch64-linux home-manager
          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = {
              imports = basicHomeModules;
            };
            home-manager.extraSpecialArgs = special-args system;
          }
        ];
      };
      guiMinimalConfig = minimalConfig // {
        modules = minimalConfig.modules ++ [
          ./nixos/gui-minimal-configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = {
              imports = guiHomeModules;
            };
            home-manager.extraSpecialArgs = special-args minimalConfig.system;
          }
        ];
      };
      guiBasicConfig = guiMinimalConfig // {
        modules = guiMinimalConfig.modules ++ [
          ./nixos/gui-basic-configuration.nix
        ];
      };

      developConfig = basicConfig // {
        modules = basicConfig.modules ++ [
          ./nixos/develop-configuration.nix
        ];
      };

      wslConfig = developConfig // {
        modules = developConfig.modules ++ [
          ./nixos/wsl-configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = {
              imports = wslHomeModules;
            };
            home-manager.extraSpecialArgs = special-args minimalConfig.system;
          }
        ];
      };

      desktopConfig = developConfig // guiBasicConfig // {
        modules = developConfig.modules ++ guiBasicConfig.modules ++ [
          ./nixos/desktop-configuration.nix
        ];
      };
      laptopConfig = developConfig // guiBasicConfig // {
        modules = developConfig.modules ++ guiBasicConfig.modules ++ [
          ./nixos/laptop-configuration.nix
        ];
      };

      minimalHomeConfig =
        let
          system = "x86_64-linux";
        in
        {
          pkgs = pkgs-collect.pkgs system;
          modules = minimalHomeModules;
          extraSpecialArgs = special-args system;
        };
      basicHomeConfig = minimalHomeConfig // {
        modules = basicHomeModules;
      };
      rpiHomeConfig = basicHomeConfig // (
        let
          system = "aarch64-linux";
        in
        {
          pkgs = pkgs-collect.pkgs system;
          extraSpecialArgs = special-args system;
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

      isoBaseConfig = minimalConfig // {
        modules = minimalConfig.modules ++ [
          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = import ./nixos/isohome.nix;
          }

          ({ config, pkgs, lib, ... }: {
            services.getty.autologinUser = nixpkgs.lib.mkForce "qsdrqs";
            users.users.qsdrqs.password = ""; # empty passwd
            programs.hyprlock.enable = lib.mkForce false; # disable hyprlock for iso

            # Disable ZFS for latest kernel, see https://github.com/NixOS/nixpkgs/issues/58959
            boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];
          })
        ];
      };

      isoMinimalConfig = isoBaseConfig // {
        modules = isoBaseConfig.modules ++ [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

          ({ config, pkgs, lib, ... }: {
            networking.wireless.enable = false; # disable wpa_supplicant for iso
          })
        ];
      };

      isoGuiConfig = isoBaseConfig // {
        modules = isoBaseConfig.modules ++ [
          home-manager.nixosModules.home-manager
          {
            home-manager.users.qsdrqs = import ./nixos/gui-home.nix;
          }

          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix"
          ./nixos/gui-minimal-configuration.nix
        ];
      };

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
      nixosConfigurations.develop = nixpkgs.lib.nixosSystem developConfig;
      nixosConfigurations.server = nixpkgs.lib.nixosSystem serverConfig;
      nixosConfigurations.rpi = nixpkgs.lib.nixosSystem rpiConfig;
      nixosConfigurations.gui-minimal = nixpkgs.lib.nixosSystem guiMinimalConfig;
      nixosConfigurations.gui-basic = nixpkgs.lib.nixosSystem guiBasicConfig;
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem wslConfig;
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem desktopConfig;
      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem laptopConfig;

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
          nixos-iso = (nixpkgs.lib.nixosSystem (removeCustom isoMinimalConfig)).config.system.build.isoImage;
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
      devShells = archSpecConfigAll (system: (pkgs-collect.pkgs system).callPackage dev-shell.shells { inputs = inputs; });
      packages =
        let
          orig = archSpecConfigAll (system: pkgs-collect.pkgs system);
        in
        orig // {
          x86_64-linux = orig.x86_64-linux // {
            hack-pylsp = (pkgs-collect.pkgs "x86_64-linux").callPackage ./nixos/hack-pylsp.nix { };
          };
        };
      # direct nix run
      legacyPackages = nixpkgs.legacyPackages;
      inputs_ = inputs;
    };
}
