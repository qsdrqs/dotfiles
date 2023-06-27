{
  description = "NixOS flakes";

  # Inputs
  # https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html#flake-inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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

    # zsh
    omz = {
      url = "github:ohmyzsh/ohmyzsh";
      flake = false;
    };
    fzf-tab = {
      url = "github:Aloxaf/fzf-tab";
      flake = false;
    };
    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
      flake = false;
    };
    zsh-highlight = {
      url = "github:zdharma-continuum/fast-syntax-highlighting";
      flake = false;
    };
    p10k = {
      url = "github:romkatv/powerlevel10k";
      flake = false;
    };
    spaceship = {
      url = "github:denysdovhan/spaceship-prompt";
      flake = false;
    };

    # wsl
    nixos-wsl.url = "github:nix-community/NixOS-WSL";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # nur
    nur.url = "github:nix-community/NUR";
  };

  # Work-in-progress: refer to parent/sibling flakes in the same repository
  # inputs.c-hello.url = "path:../c-hello";

  outputs = { self, nixpkgs, home-manager, vscode-server, nur, ... }@inputs:
    let
      basicConfig = {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/configuration.nix
          ./nixos/overlays.nix
          (if builtins.pathExists ./nixos/custom.nix then ./nixos/custom.nix else null)

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

          # vscode-server
          vscode-server.nixosModules.default
          ({ config, pkgs, ... }: {
            services.vscode-server.enable = true;
          })

        ];
      };
      pkgs' = (system: import nixpkgs {
        system = system;
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
      # Utilized by `nix flake check`
      nixosConfigurations.basic = nixpkgs.lib.nixosSystem basicConfig;
      nixosConfigurations.gui = nixpkgs.lib.nixosSystem (basicConfig // {
        modules = basicConfig.modules ++ [
          ./nixos/gui-configuration.nix
          nur.nixosModules.nur
        ];
      });
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem (basicConfig // {
        modules = basicConfig.modules ++ [
          ./nixos/wsl.nix
        ];
      });

      # iso, build through #nixos-iso.config.system.build.isoImage
      nixos-iso = nixpkgs.lib.nixosSystem (basicConfig // {
        modules = basicConfig.modules ++ [
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

          })
        ];
      });

      # dev shells
      devShells' = (pkgs: with pkgs; {
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
              cargo
              rustc
              rustfmt
              clippy
              rust-analyzer
              llvmPackages_latest.llvm
            ];
            LIBCLANG_PATH = "${llvmPackages_latest.libclang.lib}/lib";
            BINDGEN_EXTRA_CLANG_ARGS = ''
              -isystem ${llvmPackages_latest.libclang.lib}/lib/clang/${clangShortVer}/include
              -isystem ${libjpeg_turbo.dev}/include
              -isystem ${glibc.dev}/include
            '';
            RUST_SRC_PATH = "${rust.packages.stable.rustPlatform.rustLibSrc}";
          };
        cpp = mkShell {
          name = "cpp";
          nativeBuildInputs = [
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
        python = mkShell {
          packages = [
            virtualenv
          ];
        };
        base_dev = mkShell {
          packages = [
            ranger
            neovim
            lazygit
          ];
          LD_LIBRARY_PATH = lib.makeLibraryPath [ openssl ];
        };
      });

      devShells = {
        x86_64-linux = self.devShells' x86_64-linux-pkgs;
        aarch64-linux = self.devShells' aarch64-linux-pkgs;
      };
      # direct nix run
      packages = {
        x86_64-linux = x86_64-linux-pkgs;
        aarch64-linux = aarch64-linux-pkgs;
      };
    };
}
