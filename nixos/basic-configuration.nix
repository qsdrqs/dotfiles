{ config, pkgs, pkgs-stable, lib, inputs, options, ... }:
let
  # dummy = pkgs.callPackage (import ./packages.nix).dummy { };
  homeDir = config.users.users.qsdrqs.home;
in
{
  # repair nix store
  # nixpkgs.config.sync-before-registering = true;

  environment.systemPackages = with pkgs; [
    appimage-run
    nixfmt
    nixd # nix language server
    cscope
    global
    ctags
    firejail
    # (if config.nixpkgs.system == "x86_64-linux" then cloudflare-warp else dummy)
    openssl
    openssl.out # openssl lib
    parted
    gh
    exiftool
    nix-serve
    socat

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
      proxies.v2ray = {
        type = "socks5";
        host = "127.0.0.1";
        port = 1080;
        enable = true;
      };
      quietMode = true;
    };
    mosh.enable = true;
  };

  services = {
    syncthing = {
      enable = true;
      user = "qsdrqs";
      configDir = "/home/qsdrqs/.config/syncthing";
      dataDir = "/home/qsdrqs";
    };
    v2ray = {
      enable = true;
      configFile = "/etc/v2ray/config.json";
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
    if config.nixpkgs.system == "aarch64-linux" then
      [ ]
    else
      [ "aarch64-linux" ];

  systemd = {
    services.rathole-client = {
      enable = false;
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "Start the rathole client";
      serviceConfig = {
        User = "root";
        ExecStart = ''${pkgs-stable.rathole}/bin/rathole /etc/rathole/client.toml'';
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
        if config.nixpkgs.system == "x86_64-linux" then {
          ExecStart = ''${pkgs.cloudflare-warp}/bin/warp-svc'';
          CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE";
          AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE";
          Restart = "always";
          DynamicUser = "no";
        } else { };
    };
  };

  # avoid v2ray service to create config file
  environment.etc."v2ray/config.json".enable = false;

  networking.wg-quick.interfaces = {
    wg0 = {
      privateKeyFile = "${homeDir}/.wireguard/private";
      peers = lib.mkDefault (pkgs.callPackage ./private/wireguard-server.nix { inputs = inputs; });
    };
  };
}
