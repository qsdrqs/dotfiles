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

  # use vcxsrv instead of wslg
  environment.variables.DISPLAY =
    "$(${pkgs.coreutils-full}/bin/cat /etc/resolv.conf \\
    | ${pkgs.gnugrep}/bin/grep nameserver \\
    | ${pkgs.gawk}/bin/awk '{print $2; exit;}'):0.0";

  home-manager.users.qsdrqs = {
    home.file.wsl.text = "";
  };
}
