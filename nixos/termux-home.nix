{ config, pkgs, inputs, lib, ... }:
let
  dummy = pkgs.callPackage (import ./packages.nix).dummy { };
in
{
  nixpkgs.overlays = [
    (self: super: {
    })
  ];
  nix.settings.auto-optimise-store = false; # android does not support hardlinks
}
