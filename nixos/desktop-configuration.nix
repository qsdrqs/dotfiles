{ config, pkgs, pkgs-ghcup, pkgs-master, lib, inputs, ... }:
let
  ida64-fhs = pkgs.buildFHSEnv {
    name = "ida64";
    runScript = "env QT_FONT_DPI=144 ${config.users.users.qsdrqs.home}/ida/ida64";
    targetPkgs = pkgs: with pkgs; [
      libglvnd
      zlib
      libGL
      fontconfig
      freetype
      libxkbcommon
      dbus
      fuse
      glib
      gtk3
      libnotify
      libxml2
      libxslt
      openssl.dev
      pkg-config
      strace
      udev
      vulkan-loader
      xorg.libX11
      xorg.xcbutilwm
      xorg.xcbutilimage
      xorg.xcbutilrenderutil
      xorg.libSM
      xorg.libICE
      xorg.libxcb
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXScrnSaver
      xorg.libxshmfence
      xorg.libXtst
      xorg.xcbutilkeysyms
    ];
  };
  qqmusic-hidpi = pkgs.symlinkJoin {
    name = "qqmusic";
    paths = [
      pkgs.nur.repos.xddxdd.qqmusic
      # (config.nur.repos.xddxdd.qqmusic.override {
      #   sources = {
      #     qqmusic = {
      #       pname = "qqmusic";
      #       version = "1.1.7";
      #       src = pkgs.requireFile {
      #         name = "qqmusic_1.1.7_amd64.deb";
      #         url = "https://y.qq.com/download/download.html";
      #         sha256 = "149k6c83ilzm4f30fcqip57y78qrphfidqyfcd6kfkvhnlglgwil";
      #       };
      #     };
      #   };
      # })
    ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/qqmusic \
        --set GDK_DPI_SCALE 1.5 \
        --add-flags --no-sandbox
      sed -i "s|Exec=.*|Exec=$out/bin/qqmusic %U|" $out/share/applications/qqmusic.desktop
    '';
  };
  vscode-wrapper = (exec: cmd: pkgs.writeShellScriptBin cmd ''
    CODE_EXEC=${exec};
    CONFIG=${config.users.users.qsdrqs.home}/.config/Code/User/settings.json;
    sed -i 's/"window.titleBarStyle": "custom"/"window.titleBarStyle": "native"/g' $CONFIG;
    exec -a "$0" "$CODE_EXEC" "$@" &
    sleep 3
    sed -i 's/"window.titleBarStyle": "native"/"window.titleBarStyle": "custom"/g' $CONFIG;
  '');
in
{
  # boot.kernelParams = [
  #   "nvidia_drm.fbdev=1"
  #   "initcall_blacklist=simpledrm_platform_driver_init"
  # ];

  environment.systemPackages = with pkgs; [
    ida64-fhs
    libreoffice
    # seahorse # keyring manager
    # (vscode-wrapper "${vscode-insiders}/bin/code-insiders" "code-wrapper-insiders")
    # (vscode-wrapper "${vscode}/bin/code" "code-wrapper")

    tor-browser
    (llama-cpp.override {
      cudaSupport = true;
    })
    nvitop
    nvtopPackages.full
    (pkgs.callPackage (import "${inputs.nixpkgs-ghcup}/pkgs/development/tools/haskell/ghcup/default.nix") { })

    # NUR
    qqmusic-hidpi
    nur.repos.xddxdd.baidunetdisk
  ];

  services.howdy.settings.core.use_cnn = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  systemd = {
    services = {
      interception-tools-ctrl2esc.wantedBy = [ "multi-user.target" ];
      interception-tools-caps2esc.wantedBy = lib.mkForce [ ];
    };
  };

  programs.obs-studio.package = (
    pkgs.obs-studio.override {
      cudaSupport = true;
    }
  );

  services.xserver = {
    videoDrivers = [
      "modesetting"
      "nvidia"
    ];
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        gpick
        arandr
        variety
        feh
        picom
      ];
    };
  };

  # Enable CUDA support in packages that support it
  nixpkgs.config.cudaSupport = true;

  nixpkgs.config.nvidia.acceptLicense = true;
  services.switcherooControl.enable = true;
  hardware = {
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      nvidiaSettings = true;
      open = true;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Bus ID in custom configuration files
      };
      # package = (config.boot.kernelPackages.nvidiaPackages.production.overrideAttrs (oldAttrs: rec {
      #   version = "535.154.05";
      #   pkgSuffix = oldAttrs.pkgSuffix or "";
      #   src = builtins.fetchurl {
      #     url = "https://download.nvidia.com/XFree86/Linux-x86_64/${version}/NVIDIA-Linux-x86_64-${version}${pkgSuffix}.run";
      #     sha256 = "sha256-fpUGXKprgt6SYRDxSCemGXLrEsIA6GOinp+0eGbqqJg=";
      #   };
      # }));
    };
  };
  # https://wiki.hyprland.org/Nvidia/#fixing-random-flickering-nuclear-method
  environment.etc."modprobe.d/nvidia.conf".text = ''
    options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerLevel=0x3; PowerMizerDefault=0x3; PowerMizerDefaultAC=0x3"
  '';

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # GBM_BACKEND = "nvidia-drm";
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  services.hardware.openrgb.enable = true;

  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = ''
  {
    "rules": [
      {
        "pattern": {
          "feature": "procname",
          "matches": "niri"
        },
        "profile": "Limit Free Buffer Pool On Wayland Compositors"
      },
      {
        "pattern": {
          "feature": "procname",
          "matches": ".firefox-devedition-wrapped"
        },
        "profile": "Limit Free Buffer Pool On Wayland Compositors"
      }
    ],
    "profiles": [
      {
        "name": "Limit Free Buffer Pool On Wayland Compositors",
        "settings": [
          {
            "key": "GLVidHeapReuseRatio",
            "value": 0
          }
        ]
      }
    ]
  }
  '';

}
