{ config, pkgs, inputs, lib, ... }:

{
  home.file = {
    zinit = lib.mkForce {
      text = "";
      target = ".local/share/nix/dummy/zinit";
    };
  };
}
