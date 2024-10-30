{ config, pkgs, lib, inputs, options, ... }:
let
  rtl88x2bu_module = config.boot.kernelPackages.callPackage (import ./packages.nix).rtl88x2bu { inputs = inputs; };
  python-packages = ps: with ps; [
    rpi-gpio
    gpiozero
  ];
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];
  hardware = {
    raspberry-pi."4" = {
      apply-overlays-dtmerge.enable = true;
      fkms-3d.enable = true;
    };
    deviceTree = {
      enable = true;
      # filter = "*rpi-4-*.dtb";
    };
  };
  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
    wiringpi
    (python3.withPackages python-packages)
  ];
  boot.kernelPackages = lib.mkForce pkgs.linuxKernel.packages.linux_rpi4;

  # Create gpio group
  users.groups.gpio = { };

  # Change permissions gpio devices
  services.udev.extraRules = ''
    SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="gpio",MODE="0660"
    SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", RUN+="${pkgs.bash}/bin/bash -c 'chown root:gpio  /sys/class/gpio/export /sys/class/gpio/unexport ; chmod 220 /sys/class/gpio/export /sys/class/gpio/unexport'"
    SUBSYSTEM=="gpio", KERNEL=="gpio*", ACTION=="add",RUN+="${pkgs.bash}/bin/bash -c 'chown root:gpio /sys%p/active_low /sys%p/direction /sys%p/edge /sys%p/value ; chmod 660 /sys%p/active_low /sys%p/direction /sys%p/edge /sys%p/value'"
  '';

  users.users.qsdrqs.extraGroups = [ "gpio" ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.initrd.availableKernelModules = [ "xhci_pci" ];
  boot.initrd.kernelModules = [ ];

  boot.kernelModules = [ "88x2bu" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.rtl88x2bu ];
  # boot.extraModulePackages = [ rtl88x2bu_module ];


  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.end0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlan0.useDHCP = lib.mkDefault true;

  systemd.network = {
    enable = true;
    networks = {
      enp1s0 = {
        matchConfig.Name = "enp1s0*";
        networkConfig = {
          Address = "192.168.100.1/24";
          DHCPServer = true;
          IPMasquerade = "both";
        };
        dhcpServerConfig = {
          EmitDNS = true;
          PoolSize = 20;
          PoolOffset = 0;
        };
      };
      ap = {
        matchConfig = {
          # Name = "wlan0";
          Name = "wlp1s0u1u2";
          WLANInterfaceType = "ap";
        };
        networkConfig = {
          Address = "192.168.12.1/24";
          DHCPServer = true;
          IPMasquerade = "both";
          IgnoreCarrierLoss = true;
        };
        dhcpServerConfig = {
          EmitDNS = true;
          PoolSize = 30;
          PoolOffset = 0;
        };
      };
    };
  };
  networking.networkmanager.unmanaged = [ "wlp1s0u1u2" ];

  services.hostapd = {
    enable = true;
    # radios.wlan0 = {
    #   wifi4.capabilities = [
    #     "HT40"
    #     "HT40-"
    #     "SHORT-GI-20"
    #     # "SHORT-GI-40"
    #   ];
    #   countryCode = "US";
    #   networks = {
    #     wlan0 = {
    #       ssid = "RaspNix";
    #       authentication = {
    #         mode = "wpa2-sha256";
    #         wpaPasswordFile = ./private/wpa-password;
    #       };
    #       settings = {
    #         wpa_key_mgmt = lib.mkForce "WPA-PSK";
    #       };
    #     };
    #   };
    # };
    radios.wlp1s0u1u2 = {
      channel = 7;
      countryCode = "US";
      networks = {
        wlp1s0u1u2 = {
          ssid = "RaspNix";
          authentication = {
            mode = "wpa2-sha256";
            wpaPasswordFile = ./private/wpa-password;
            # saePasswordsFile = ./private/wpa-password;
          };
          settings = {
            wpa_key_mgmt = lib.mkForce "WPA-PSK";
          };
        };
      };
    };
  };


  # auto fan on/off
  systemd.services.autofan =
    let
      low = 45;
      high = 60;
    in
    {
      wantedBy = [ "multi-user.target" ];
      description = "Auto control fan on/off";
      serviceConfig = {
        ExecStart = ''${(pkgs.python3.withPackages python-packages)}/bin/python ${./scripts/rpi-autofan.py} ${builtins.toString low} ${builtins.toString high}'';
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

  systemd.services.wifi-rebuild =
    let
      wifi-interface = "wlp1s0u1u2";
      rpi-config = "rpi";
    in
    {
      wantedBy = [ "multi-user.target" ];
      description = "Auto detect wifi down and rebuild nixos";
      path = [
        pkgs.iproute2
        pkgs.gnugrep
        pkgs.bash
        pkgs.git
        pkgs.nixos-rebuild
        pkgs.nix
      ];
      serviceConfig = {
        ExecStart = ''${(pkgs.python3.withPackages python-packages)}/bin/python ${./scripts/rpi-wifi-rebuild.py} ${wifi-interface} ${rpi-config}'';
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  services.syncthing.guiAddress = "0.0.0.0:8384";
  systemd.services.rathole-client.enable = lib.mkForce true;
}
