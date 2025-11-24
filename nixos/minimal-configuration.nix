# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, options, ... }:
let
  packages = builtins.mapAttrs (name: value: pkgs.callPackage value { }) (import ./packages.nix);
in
{
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_6_14; # TODO: temperary fix
  # boot.kernelPackages = pkgs.linuxPackages;
  boot.tmp.useTmpfs = true;

  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  services.tzupdate = {
    enable = true;
    timer = {
      enable = true;
      interval = "*:0/5"; # Update timezone data every 5 minutes.
    };
  };
  # Configure network proxy if necessary
  # networking.proxy.default = "http://127.0.0.1:1081";
  # networking.proxy.noProxy = "127.0.0.1,localhost";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
    "zh_TW.UTF-8/UTF-8"
  ];
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkbOptions in tty.
  };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.qsdrqs = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "input"
    ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
    openssh.authorizedKeys.keyFiles = [
      (
        if builtins.pathExists ./private/authorized_keys then
          ./private/authorized_keys
        else
          lib.warn "No authorized_keys found, please create one in ./private/authorized_keys" ./empty
      )
    ];
  };

  # enable normal users to use reboot or shutdown
  security.polkit.enable = true;

  system.activationScripts.link_bin_bash.text = ''
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
    mkdir -p /usr/bin
    ln -sf ${pkgs.bash}/bin/bash /usr/bin/bash
  '';

  security.wrappers.direnv = {
    source = "${pkgs.direnv}/bin/direnv";
    owner = "root";
    group = "keys";
    setgid = true;
    setuid = true;
  };

  # gc
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 21d";
    };
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "qsdrqs"
        "@wheel"
        "nix-serve"
      ];
    };
    package = pkgs.nixVersions.latest;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  nixpkgs.config.allowUnfree = true;
  # remove packages installed by default (e.g. nano, etc.)
  environment.defaultPackages = [ ];

  environment.localBinInPath = true;

  nix.settings = {
    # need to explicitly set this to use cachix
    substituters = [
      "https://yazi.cachix.org"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = [
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  environment.systemPackages = with pkgs; [
    vim-full # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    (if config.boot.loader.grub.enable then grub2 else packages.dummy)
    zoxide
    packages.mkcd
    packages.patchdir
    lsd
    wget
    curl
    ranger
    yazi
    starship
    tmux
    perl # for tmux to work
    fastfetch
    neofetch
    grc
    git
    git-lfs
    fzf
    fd
    ripgrep
    gnutar
    zip
    unzip
    p7zip
    gcc
    gnumake
    killall
    (pkgs.buildFHSEnv {
      name = "fhs";
      runScript = "zsh";
      targetPkgs = pkgs: with pkgs; [ ];
    })
    config.boot.kernelPackages.cpupower
    memtester
    patchelf
    (python3.withPackages (
      ps: with ps; [
        ipython
        tkinter
        pip
      ]
    ))
    lsof
    bat
    file
    rsync
    iptables
    kmod
    nmap
    lm_sensors
    lua
    home-manager
    nix-tree
    duf
    gdu
    lsb-release
    valgrind
    sqlite
    sshfs
    (lib.hiPrio inetutils)
    net-tools
    iw
    cntr # container debug tool
    libinput

    # perfing
    perf
    strace
    ltrace

    usbutils
    libusb1

    packages.caps2esc
    packages.ctrl2esc
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      enableGlobalCompInit = false; # enabled in my own zshrc
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      package = packages.neovim-reloadable-unwrapped;
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        glib
        libGL
      ];
    };
    gnupg.agent.enable = true;
    command-not-found.enable = false;
    nix-index.enable = true;
    ssh.startAgent = true;
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = true;
        GatewayPorts = "yes";
        # AllowTcpForwarding = true;
      };
    };
    journald.extraConfig = ''
      SystemMaxUse=500M
      RuntimeMaxUse=500M
    '';
    locate = {
      enable = true;
      package = pkgs.plocate;
      interval = "daily";
      # localuser = null;
      pruneBindMounts = false; # btrfs can't be pruned
      prunePaths = options.services.locate.prunePaths.default ++ [
        "/mnt"
        "/btrfs_root"
        "/home/.snapshots"
      ];
    };
  };

  # interception tools
  systemd.services =
    let
      interception-tools-plugins = [
        pkgs.interception-tools-plugins.caps2esc
        pkgs.interception-tools-plugins.ctrl2esc
      ];
      udevmonConfig = plugin: ''
        - JOB: "${pkgs.interception-tools}/bin/intercept -g $DEVNODE | ${
          pkgs.interception-tools-plugins."${plugin}"
        }/bin/${plugin} | ${pkgs.interception-tools}/bin/uinput -d $DEVNODE"
          DEVICE:
            EVENTS:
              EV_KEY: [KEY_CAPSLOCK, KEY_ESC, KEY_LEFTCTRL]
      '';
      interception-tools-service = plugin: {
        description = "Interception tools";
        path = [
          pkgs.bash
          pkgs.interception-tools
        ] ++ interception-tools-plugins;
        serviceConfig = {
          ExecStart = ''
            ${pkgs.interception-tools}/bin/udevmon -c \
            ${
              if builtins.typeOf (udevmonConfig plugin) == "path" then
                (udevmonConfig plugin)
              else
                pkgs.writeText "udevmon.yaml" (udevmonConfig plugin)
            }
          '';
          Nice = -20;
        };
        wantedBy = [ "multi-user.target" ];
      };
    in
    {
      interception-tools-caps2esc = interception-tools-service "caps2esc";
      interception-tools-ctrl2esc = interception-tools-service "ctrl2esc" // {
        wantedBy = [ ];
      };

      # remove this when upstream provide option to enable it
      tzupdate.script = lib.mkForce ''
        timezone="$(${lib.getExe pkgs.tzupdate} --consensus --print-only)"
        if [[ -n "$timezone" ]]; then
          echo "Setting timezone to '$timezone'"
          timedatectl set-timezone "$timezone"
        fi
      '';
    };

  environment.variables = {
    NIX_CURR_PROFILE_SOURCE = ../.;
  };

  environment.etc = {
    "nix_current_profile_source" = {
      source = ../.;
      target = "nix/current-profile-source";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
