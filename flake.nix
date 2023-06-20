{
  description = "NixOS flakes";

  # Inputs
  # https://nixos.org/manual/nix/unstable/command-ref/new-cli/nix3-flake.html#flake-inputs
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    home-manager.url = github:nix-community/home-manager;
    ranger = {
      url = github:ranger/ranger;
      flake = false;
    };
    neovim = {
      url = github:neovim/neovim;
      flake = false;
    };
    vscode-server.url = github:nix-community/nixos-vscode-server;

    # zsh
    omz = {
      url = github:ohmyzsh/ohmyzsh;
      flake = false;
    };
    fzf-tab = {
      url = github:Aloxaf/fzf-tab;
      flake = false;
    };
    zsh-autosuggestions = {
      url = github:zsh-users/zsh-autosuggestions;
      flake = false;
    };
    zsh-highlight = {
      url = github:zdharma-continuum/fast-syntax-highlighting;
      flake = false;
    };
    p10k = {
      url = github:romkatv/powerlevel10k;
      flake = false;
    };
    spaceship = {
      url = github:denysdovhan/spaceship-prompt;
      flake = false;
    };

    # wsl
    nixos-wsl.url = github:nix-community/NixOS-WSL;
  };

  # Work-in-progress: refer to parent/sibling flakes in the same repository
  # inputs.c-hello.url = "path:../c-hello";

  outputs = { self, nixpkgs, home-manager, vscode-server, ... }@inputs:
  let
    basicConfig = {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        ./nixos/configuration.nix

        # home-manager module
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.qsdrqs = import ./nixos/home.nix;

          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
          home-manager.extraSpecialArgs = {inherit inputs;};
        }

        # vscode-server
        vscode-server.nixosModules.default
        ({ config, pkgs, ... }: {
          services.vscode-server.enable = true;
        })
      ];
    };
  in
  {
    # Utilized by `nix flake check`
    nixosConfigurations.basic = nixpkgs.lib.nixosSystem basicConfig;
    nixosConfigurations.gui = nixpkgs.lib.nixosSystem (basicConfig // {
      modules = basicConfig.modules ++ [
        ./nixos/custom.nix
        ./nixos/gui-configuration.nix
      ];
    });
    nixosConfigurations.wsl = nixpkgs.lib.nixosSystem (basicConfig // {
      modules = basicConfig.modules ++ [
        ./nixos/custom.nix
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
        })
      ];
    });
  };
}
