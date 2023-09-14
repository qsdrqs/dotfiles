{ config, pkgs, inputs, lib, ... }:

{
  home.file.".icons/default".source = "${pkgs.libsForQt5.breeze-qt5}/share/icons/breeze_cursors";
}
