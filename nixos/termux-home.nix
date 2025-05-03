{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  dummy = pkgs.callPackage (import ./packages.nix).dummy { };
in
{
  nixpkgs.overlays = [
    (self: super: (lib.listToAttrs (
      map
        (pkg_: {
          name = pkg_;
          value = dummy;
        })
        [
          "fastfetch"
          "htop"
        ]
    )))
  ];
  nix.settings.auto-optimise-store = false; # android does not support hardlinks
}
