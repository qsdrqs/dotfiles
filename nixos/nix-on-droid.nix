{ config, pkgs, lib, inputs, options, ... }:
let
  systemConfig = builtins.removeAttrs (import ./configuration.nix {
    inherit config pkgs lib inputs options;
  });
in
{
  environment.systemPackages = with pkgs; [
    openssh
  ];
}
