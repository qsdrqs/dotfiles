{ config, pkgs, inputs, lib, ... }:
let
  homeDir = config.home.homeDirectory;
in
{
  home.file.".icons/default".source = "${pkgs.kdePackages.breeze}/share/icons/breeze_cursors";

  # xdg.mimeApps = {
  #   enable = true;
  #   associations.added = {
  #     "x-scheme-handler/tonsite" = "userapp-Telegram Desktop-0VB4X2.desktop;";
  #   };
  #   defaultApplications = {
  #     "image/png" = [ "org.kde.gwenview.desktop" ];
  #     "image/jpeg" = [ "org.kde.gwenview.desktop" ];
  #     "image/gif" = [ "org.kde.gwenview.desktop" ];
  #     "application/pdf" = [ "org.pwmt.zathura.desktop" ];
  #     "inode/directory" = [ "org.kde.dolphin.desktop" ];
  #     "x-scheme-handler/tg" = [ "userapp-Telegram Desktop-FKA2H2.desktop" ];
  #     "x-scheme-handler/tonsite" = [ "userapp-Telegram Desktop-0VB4X2.desktop" ];
  #     "x-scheme-handler/baiduyunguanjia" = [ "baidunetdisk.desktop" ];
  #   };
  # };

  home.file."rofi-hyprwindow" = {
    source = ../hypr/rofi-hyprwindow.sh;
    target = ".local/bin/rofi-hyprwindow";
    executable = true;
  };
  services.swaync = {
    enable = true;
    # settings = {
    #   scripts = {
    #     sound-script = {
    #       exec = ../swaync/sound-script.sh;
    #       "app-name" = ".*";
    #     };
    #   };
    # };
    style = ../swaync/style.css;
  };

  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  home.activation.configs = let
    linkConfigs = [
      "hypr"
      "waybar"
      "kitty"
      "rofi"
      "niri"
    ];
    touchConfigs = [
      "hypr-monitor.conf"
      "niri-monitor.kdl"
    ];
  in ''
    mkdir -p ~/.config
    ${lib.concatMapStringsSep "\n" (cfg: ''
      if [ ! -e ${homeDir}/.config/${cfg} ]; then
        ln -s ${homeDir}/dotfiles/${cfg} ${homeDir}/.config
      fi
    '') linkConfigs}
    ${lib.concatMapStringsSep "\n" (cfg: ''
      if [ ! -e ${homeDir}/.config/${cfg} ]; then
        touch ${homeDir}/.config/${cfg}
      fi
    '') touchConfigs}
  '';

}
