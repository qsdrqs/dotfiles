{ pkgs, config, modulesPath, inputs, lib, options, utils, ... }:
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

    # Enable integration with Docker Desktop (needs to be installed)
    # docker-desktop.enable = config.virtualisation.docker.enable;
    interop.register = true;

    usbip.enable = true;
  };

  environment.systemPackages = with pkgs; [
    kitty
    texlive.combined.scheme-full
    zathura
    xdg-utils
    (python3.withPackages python-packages)
  ];
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.fira-code
  ];

  # Set syncthing GUI address to 0.0.0.0
  # So that it's accessible from Windows
  services.syncthing.guiAddress = "0.0.0.0:8384";

  # WSL2 does not support modprobe for wireguard
  systemd.services.wg-quick-wg0.serviceConfig.ExecStart = lib.mkForce (
    utils.systemdUtils.lib.makeJobScript {
      name = "wg-quick-wg0-start";
      text =
        let
          str2list = lib.strings.splitString "\n" config.systemd.services.wg-quick-wg0.script;
          listRemove = lib.lists.remove "${pkgs.kmod}/bin/modprobe wireguard" str2list;
        in
        lib.strings.concatStrings listRemove;
      enableStrictShellChecks = false;
  });

  # use vcxsrv instead of wslg
  # environment.variables.DISPLAY =
  #   "$(${pkgs.coreutils-full}/bin/cat /etc/resolv.conf \\
  #   | ${pkgs.gnugrep}/bin/grep nameserver \\
  #   | ${pkgs.gawk}/bin/awk '{print $2; exit;}'):0.0";
}
