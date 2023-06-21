{ pkgs, config, modulesPath, inputs, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    inputs.home-manager.nixosModules.home-manager
  ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = "qsdrqs";
    startMenuLaunchers = true;
    nativeSystemd = true;

    # Enable native Docker support
    # docker-native.enable = true;

    # Enable integration with Docker Desktop (needs to be installed)
    # docker-desktop.enable = true;

  };

  home-manager.users.qsdrqs.home.file.wsl.text = "";
}
