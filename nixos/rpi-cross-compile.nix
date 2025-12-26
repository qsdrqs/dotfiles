{ lib, inputs, ... }:
let
  rpi-nixpkgs = inputs.nixos-raspberrypi.inputs.nixpkgs;
  global-overlays =
    (rpi-nixpkgs.legacyPackages."x86_64-linux".callPackage ./overlays.nix { inputs = inputs; }).nixpkgs.overlays;
  pkgs-x86_64 = import rpi-nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
    overlays = global-overlays ++ [
      inputs.nixos-raspberrypi.overlays.vendor-kernel
      inputs.nixos-raspberrypi.overlays.vendor-firmware
      inputs.nixos-raspberrypi.overlays.kernel-and-firmware
    ];
  };
  pkgs-cross-aarch64 = pkgs-x86_64.pkgsCross.aarch64-multiplatform;
  cross-only-packages = [
    # "yazi"
  ];
in
{
  nixpkgs.overlays = [
    (final: prev:
      (lib.genAttrs cross-only-packages (name: pkgs-cross-aarch64.${name}))
      // {
        linuxPackages_rpi5 = pkgs-cross-aarch64.linuxPackages_rpi5;
      })
  ];
}
