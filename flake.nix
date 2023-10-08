{
  description = "NixOS flakes";

  # Inputs
  # https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html#flake-inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    home-manager.url = "github:nix-community/home-manager";
    ranger = {
      url = "github:ranger/ranger";
      flake = false;
    };
    neovim = {
      url = "github:neovim/neovim";
      flake = false;
    };
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    zsh-config.url = "path:zsh";

    # wsl
    nixos-wsl.url = "github:nix-community/NixOS-WSL";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # nur
    nur.url = "github:nix-community/NUR";

    nix-on-droid = {
      url = "github:t184256/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
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
      minimalConfig = {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          pkgs-master = pkgs-master;
        };
        modules = [
          (if builtins.pathExists ./nixos/custom.nix then ./nixos/custom.nix else ./nixos/empty.nix)
          ./nixos/minimal-configuration.nix
          ./nixos/overlays.nix

          # home-manager module
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.qsdrqs = import ./nixos/home.nix;

            # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix
            home-manager.extraSpecialArgs = { inherit inputs; };
          }

        ];
      };
      serverConfig = minimalConfig // {
        modules = minimalConfig.modules ++ [
          ./nixos/server-configuration.nix

          # vscode-server
          vscode-server.nixosModules.default
          ({ config, pkgs, ... }: {
            services.vscode-server.enable = true;
          })

          # NUR
          nur.nixosModules.nur

          # nix index database
          inputs.nix-index-database.nixosModules.nix-index
        ];
      };
      guiConfig = minimalConfig // {
        modules = minimalConfig.modules ++ [
          ./nixos/gui-configuration.nix
        ];
      };

      wslConfig = serverConfig // {
        modules = serverConfig.modules ++ [
          ./nixos/wsl-configuration.nix
        ];
      };

      desktopConfig = serverConfig // guiConfig // {
        modules = serverConfig.modules ++ guiConfig.modules ++ [
          ./nixos/desktop-configuration.nix
        ];
      };

      minimalHomeConfig = {
        pkgs = x86_64-linux-pkgs;
        modules = [
          ./nixos/home.nix
        ];
        extraSpecialArgs = { inherit inputs; };
      };
      guiHomeConfig = minimalHomeConfig // {
        modules = minimalHomeConfig.modules ++ [
          ./nixos/gui-home.nix
        ];
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
      nixosConfigurations.server = nixpkgs.lib.nixosSystem serverConfig;
      nixosConfigurations.gui = nixpkgs.lib.nixosSystem guiConfig;
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem wslConfig;
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem desktopConfig;

      # nix-on-droid
      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        modules = [
          ./nixos/nix-on-droid.nix
        ];
        extraSpecialArgs = { inherit inputs; };
      };

      # iso, build through #nixos-iso.config.system.build.isoImage
      nixos-iso = nixpkgs.lib.nixosSystem isoConfig;
      nixos-iso-gui = nixpkgs.lib.nixosSystem isoGuiConfig;

      # home-manager
      homeConfigurations.basic = home-manager.lib.homeManagerConfiguration minimalHomeConfig;

      homeConfigurations.gui = home-manager.lib.homeManagerConfiguration guiHomeConfig;
      # dev shells
      devShells' = (arch: pkgs: with pkgs; {
        rust =
          let
            clangShortVer = builtins.head (
              nixpkgs.lib.splitString "." (
                nixpkgs.lib.getVersion llvmPackages_latest.clang
              )
            );
          in
          mkShell {
            packages = [
              rustup
              rustc
              rustfmt
              clippy
              rust-analyzer
              cmake
              llvmPackages_latest.llvm
            ];
            shellHook = ''
              export LIBCLANG_PATH="${llvmPackages_latest.libclang.lib}/lib"
              export BINDGEN_EXTRA_CLANG_ARGS="
                -isystem ${llvmPackages_latest.libclang.lib}/lib/clang/${clangShortVer}/include
                -isystem ${libjpeg_turbo.dev}/include
                -isystem ${glibc.dev}/include
              "
              export RUST_SRC_PATH="${rust.packages.stable.rustPlatform.rustLibSrc}"
            '';
          };
        cpp = mkShell {
          packages = [
            cmake
            gnumake
            gdb
            ninja
            bear
            clang-tools_16
            clang_16
            llvm_16
          ];
        };
        rust_cpp = mkShell {
          inputsFrom = [
            self.devShells.${arch}.rust
            self.devShells.${arch}.cpp
          ];
        };
        python = mkShell {
          packages = [
            python3Packages.virtualenv
            python3Packages.numpy
            python3Packages.matplotlib
            python3Packages.autopep8
            python3Packages.debugpy
            nodePackages.pyright
          ];
        };
        go = mkShell {
          packages = [
            go
            gopls
          ];
        };
        base_dev = mkShell {
          packages = [
            ranger
            neovim
            lazygit
            neofetch
          ];
          LD_LIBRARY_PATH = lib.makeLibraryPath [ openssl ];
        };
        node = mkShell {
          packages = [
            nodePackages.pnpm
            nodePackages.yarn
          ];
        };
      });

      devShells = {
        x86_64-linux = self.devShells' "x86_64-linux" x86_64-linux-pkgs;
        aarch64-linux = self.devShells' "aarch64-linux" aarch64-linux-pkgs;
      };
      # direct nix run
      packages = {
        x86_64-linux = x86_64-linux-pkgs;
        aarch64-linux = aarch64-linux-pkgs;
      };
      rust = self.devShells.x86_64-linux.rust;
    };
}
