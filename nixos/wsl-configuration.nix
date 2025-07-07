{ pkgs, config, modulesPath, inputs, lib, options, utils, ... }: {
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
  programs.fuse.userAllowOther = true;

  environment.systemPackages = with pkgs; [
    kitty
    zathura
    xdg-utils
  ];
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.fira-code
    wqy_zenhei
  ];

  systemd.user = {
    services.ssh-agent-share =
      let user_local = "${config.users.users.qsdrqs.home}/.local";
      in {
        description = "Share SSH agent socket between WSL and Windows";
        wantedBy = [ "default.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = ''
            ${pkgs.socat}/bin/socat UNIX-LISTEN:/tmp/ssh-agent.sock,fork EXEC:"${user_local}/bin/winsocat.exe STDIO NPIPE\\:openssh-ssh-agent"'';
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
  };

  # Set syncthing GUI address to 0.0.0.0
  # So that it's accessible from Windows
  services.syncthing.guiAddress = "0.0.0.0:8384";

  # WSL2 does not support modprobe for wireguard
  systemd.services.wg-quick-wg0.enable = false;
  systemd.services.wg-quick-wg0.serviceConfig.ExecStart = lib.mkForce
    (utils.systemdUtils.lib.makeJobScript {
      name = "wg-quick-wg0-start";
      text = let
        str2list = lib.strings.splitString "\n"
          config.systemd.services.wg-quick-wg0.script;
        listRemove =
          lib.lists.remove "${pkgs.kmod}/bin/modprobe wireguard" str2list;
      in lib.strings.concatStrings listRemove;
      enableStrictShellChecks = false;
    });

  # use vcxsrv instead of wslg
  # environment.variables.DISPLAY =
  #   "$(${pkgs.coreutils-full}/bin/cat /etc/resolv.conf \\
  #   | ${pkgs.gnugrep}/bin/grep nameserver \\
  #   | ${pkgs.gawk}/bin/awk '{print $2; exit;}'):0.0";
}
