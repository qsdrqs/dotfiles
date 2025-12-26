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
    # (if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then cloudflare-warp else dummy)
    openssl
    openssl.out # openssl lib
    parted
    gh
    exiftool
    socat
    xray
    samba

    poppler-utils # pdf2txt
    jless

    w3m
    wireguard-tools
    ffmpeg
    scc
    sshping
    nasm
    nodejs
    aichat
    nix-serve-ng
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
      user = userName;
      configDir = "${homeDir}/.config/syncthing";
      dataDir = "${homeDir}";
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

  # Enable QEMU binfmt on x86_64 build hosts (for building aarch64 derivations locally when cache misses).
  boot.binfmt.emulatedSystems = lib.mkDefault (
    lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [ "aarch64-linux" ]
  );

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
      enable = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      wantedBy = [ "multi-user.target" ];
      after = [ "pre-network.target" ];
      description = "CloudflareWARP daemon";
      serviceConfig =
        if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
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
    services."chown-ssh" = {
      wantedBy = [ "multi-user.target" ];
      before = [ "home-manager-${userName}.service" ];
      description = "Change ownership of .ssh directory";
      path = [ pkgs.inotify-tools pkgs.coreutils ];
      serviceConfig = {
        ExecStart = ./scripts/chown_ssh.sh;
      };
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
