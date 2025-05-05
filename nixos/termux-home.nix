{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  dummy = pkgs.callPackage (import ./packages.nix).dummy { };
  termux_root = "/data/data/com.termux/files";
in
{
  nixpkgs.overlays = [
    (
      self: super:
      (lib.listToAttrs (
        map
          (pkg_: {
            name = pkg_;
            value = dummy;
          })
          [
            "fastfetch"
            "htop"
          ]
      ))
    )
  ];
  home.packages = with pkgs; [
    gcc
  ];
  home.sessionVariables = {
    TZDIR = "${pkgs.tzdata}/share/zoneinfo";
  };
  home.activation = {
    timeZoneFiles = ''
      ETC="${termux_root}/usr/etc"
      if [ -d $ETC ]; then
        ln -snf ${pkgs.tzdata}/share/zoneinfo $ETC/zoneinfo
        TZ=$(${termux_root}/usr/bin/getprop persist.sys.timezone)
        ln -sf $ETC/zoneinfo/$TZ $ETC/localtime
      fi
    '';
  };
  nix.settings.auto-optimise-store = false; # android does not support hardlinks
}
