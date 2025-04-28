{
  config,
  pkgs,
  pkgs-stable,
  lib,
  inputs,
  options,
  ...
}:
let
  # dummy = pkgs.callPackage (import ./packages.nix).dummy { };
  userName = "qsdrqs";
  homeDir = config.users.users.qsdrqs.home;
in
{
  # repair nix store
  # nixpkgs.config.sync-before-registering = true;

  environment.systemPackages = with pkgs; [
    appimage-run
    nixfmt-rfc-style
    nixd # nix language server
    cscope
    global
    ctags
    openconnect_openssl
    # (if config.nixpkgs.system == "x86_64-linux" then cloudflare-warp else dummy)
    openssl
    openssl.out # openssl lib
    parted
    gh
    exiftool
    nix-serve
    socat
    xray

    poppler_utils # pdf2txt
    jless

    w3m
    wireguard-tools
    ffmpeg
    scc
    sshping
    nasm
  ];

  environment.variables = {
    LIBCLANG_PATH = "${pkgs.llvmPackages_latest.libclang.lib}/lib";
  };

  programs = {
    proxychains = {
      enable = true;
      proxies.xray = {
        type = "socks5";
        host = "127.0.0.1";
        port = 1080;
        enable = true;
      };
      quietMode = true;
    };
    mosh.enable = true;
    firejail.enable = true;
  };

  services = {
    syncthing = {
      enable = true;
      user = "qsdrqs";
      configDir = "/home/qsdrqs/.config/syncthing";
      dataDir = "/home/qsdrqs";
    };
    xray = {
      enable = true;
      settingsFile = "/etc/xray/config.jsonc";
    };
  };

  virtualisation = {
    docker = {
      enable = lib.mkDefault false;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
  };

  # enable qemu emulation compile, only for x86_64-linux to emulate aarch64-linux
  boot.binfmt.emulatedSystems =
    if config.nixpkgs.system == "aarch64-linux" then [ ] else [ "aarch64-linux" ];

  systemd = {
    services.frpc = {
      enable = false;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "Start the frp client";
      serviceConfig = {
        User = "root";
        ExecStart = ''${pkgs.frp}/bin/frpc -c /etc/frp/frpc.toml'';
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
    services.warp-svc = {
      enable = if config.nixpkgs.system == "x86_64-linux" then true else false;
      wantedBy = [ "multi-user.target" ];
      after = [ "pre-network.target" ];
      description = "CloudflareWARP daemon";
      serviceConfig =
        if config.nixpkgs.system == "x86_64-linux" then
          {
            ExecStart = ''${pkgs.cloudflare-warp}/bin/warp-svc'';
            CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE";
            AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE";
            Restart = "always";
            DynamicUser = "no";
          }
        else
          { };
    };
    services."chown-home@" = {
      description = "Recursively chown /home/%i back to %i";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/chown -R %i:users /home/%i";
      };
    };
    timers."chown-home@${userName}" = {
      enable = false;
      description = "Run chown-home@${userName}.service daily";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true; # if the system was off when the timer was supposed to run
        Unit = "chown-home@${userName}.service";
      };
      wantedBy = [ "timers.target" ];
    };
  };

  # 3) Define a timer that triggers that service every hour
  # avoid v2ray service to create config file
  environment.etc."v2ray/config.json".enable = false;

  networking.wg-quick.interfaces = {
    wg0 = {
      privateKeyFile = "${homeDir}/.wireguard/private";
      peers = lib.mkDefault (pkgs.callPackage ./private/wireguard-server.nix { inputs = inputs; });
    };
  };
}
