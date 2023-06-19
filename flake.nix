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
  };

  # Work-in-progress: refer to parent/sibling flakes in the same repository
  # inputs.c-hello.url = "path:../c-hello";

  outputs = { self, nixpkgs, ... }@inputs: {

    # Utilized by `nix flake check`
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        ./nixos/configuration.nix
      ];
    };
  };
}
