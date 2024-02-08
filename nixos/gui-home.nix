{ config, pkgs, inputs, lib, ... }:

{
  home.file.".icons/default".source = "${pkgs.libsForQt5.breeze-qt5}/share/icons/breeze_cursors";

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/png" = [ "org.kde.gwenview.desktop" ];
      "image/jpeg" = [ "org.kde.gwenview.desktop" ];
      "image/gif" = [ "org.kde.gwenview.desktop" ];
      "application/pdf" = [ "org.pwmt.zathura.desktop" ];
      "inode/directory" = [ "org.kde.dolphin.desktop" ];
      "x-scheme-handler/tg" = [ "userapp-Telegram Desktop-FKA2H2.desktop" ];
    };
  };
}
