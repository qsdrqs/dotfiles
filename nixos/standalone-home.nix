{ config, pkgs, inputs, lib, ... }:
let
  packages = builtins.mapAttrs (name: value: pkgs.callPackage value { }) (import ./packages.nix);
in
{
  imports = [
    (if builtins.pathExists ./home-custom.nix then
      ./home-custom.nix
    else
      lib.warn "home-custom.nix not found"
        lib.warn "will use username `qsdrqs` and home directory `/home/qsdrqs`"
        ./empty.nix
    )
  ];

  home.packages = with pkgs; [
    (wrapNeovim packages.neovim-reloadable-unwrapped {
      withPython3 = true;
    })
    yazi
    zoxide
    lsd
    fd
    ripgrep
    grc
    fastfetch
    neofetch
    tmux
  ];

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [
        "root"
        config.home.username
        "@wheel"
        "nix-serve"
      ];
    };
    package = pkgs.nixVersions.nix_2_26;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
}
