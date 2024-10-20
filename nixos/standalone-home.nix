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
    editor-wrapped
    lsd
    fd
    ripgrep
    grc
    fastfetch
    neofetch
    tmux
  ];
}
