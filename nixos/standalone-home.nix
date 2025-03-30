{ config, pkgs, inputs, lib, ... }:
let
  packages = builtins.mapAttrs (name: value: pkgs.callPackage value { })
    (import ./packages.nix);
in {
  imports = [
    (if builtins.pathExists ./home-custom.nix then
      ./home-custom.nix
    else
      lib.warn "home-custom.nix not found" lib.warn
      "will use username `qsdrqs` and home directory `/home/qsdrqs`"
      ./empty.nix)
  ];

  home.packages = with pkgs; [
    (wrapNeovim packages.neovim-reloadable-unwrapped { withPython3 = true; })
    yazi
    zoxide
    lsd
    fd
    ripgrep
    grc
    fastfetch
    neofetch
    tmux
    config.nix.package
  ];

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" config.home.username "@wheel" "nix-serve" ];
      substituters =
        [ "https://yazi.cachix.org" "https://nix-community.cachix.org" ];
      trusted-public-keys = [
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    package = pkgs.nixVersions.latest;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
