{ config, pkgs, inputs, lib, ... }:

{
  ### add the customizations here for different machines
  # home.username = "qsdrqs";
  # home.homeDirectory = "/home/qsdrqs";
  ###
  imports = [
    (if builtins.pathExists ./home-custom.nix then
      ./home-custom.nix
    else
      lib.warn "home-custom.nix not found"
        lib.warn "will use username qsdrqs and home directory /home/qsdrqs"
        ./empty.nix
    )
  ];

  home.packages = with pkgs; [
    nvim-final
    yazi
  ];
}
