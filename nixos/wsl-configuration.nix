{ pkgs, config, modulesPath, inputs, lib, ... }:
let
  python-packages = ps: with ps; [
    rpi-gpio
    gpiozero
  ];
in
{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    inputs.home-manager.nixosModules.home-manager
  ];

  wsl = {
    enable = true;
    wslConf = {
      automount.root = "/mnt";
      interop.appendWindowsPath = true;
    };
    defaultUser = "qsdrqs";
    startMenuLaunchers = true;
    nativeSystemd = true;

    # Enable extra bin, for vscode server to work
    extraBin = with pkgs; [
      { src = "${coreutils}/bin/uname"; }
      { src = "${coreutils}/bin/dirname"; }
      { src = "${coreutils}/bin/readlink"; }
    ];

    # Enable native Docker support
    # docker-native.enable = true;

    # Enable integration with Docker Desktop (needs to be installed)
    # docker-desktop.enable = true;

  };

  environment.systemPackages = with pkgs; [
    kitty
    texlive.combined.scheme-full
    zathura
    (python3.withPackages python-packages)
  ];
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "Hack" ]; })
  ];

  # Set syncthing GUI address to 0.0.0.0
  # So that it's accessible from Windows
  services.syncthing.guiAddress = "0.0.0.0:8384";

  # use vcxsrv instead of wslg
  # environment.variables.DISPLAY =
  #   "$(${pkgs.coreutils-full}/bin/cat /etc/resolv.conf \\
  #   | ${pkgs.gnugrep}/bin/grep nameserver \\
  #   | ${pkgs.gawk}/bin/awk '{print $2; exit;}'):0.0";
}
