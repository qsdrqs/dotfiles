{ config, pkgs, inputs, lib, ... }:
let
  dummy = pkgs.callPackage (import ./packages.nix).dummy { };
in
{
  nixpkgs.overlays = [
    (self: super: {
      fastfetch = dummy;
    })
  ];
}
