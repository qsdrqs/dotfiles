{
  rtl88x2bu =
    {
      stdenv,
      lib,
      fetchFromGitHub,
      kernel,
      kmod,
      inputs,
      dpkg,
      bc,
    }:
    stdenv.mkDerivation rec {
      pname = "rtl88x2bu";
      version = "5.13.1";
      name = "${pname}-${version}-${kernel.version}";

      src = inputs.rtl88x2bu-dkms;

      sourceRoot = "usr/src/${pname}-${version}";
      hardeningDisable = [
        "pic"
        "format"
      ];
      nativeBuildInputs = [
        dpkg
        bc
      ]
      ++ kernel.moduleBuildDependencies;

      unpackPhase = ''
        dpkg-deb -x $src .
      '';

      patches = [
        ./patches/rtl88x2bu.patch
      ];

      kernelDir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

      buildPhase = ''
        export src=$PWD
        export KERNEL_DIR=${kernelDir}
        export KERNEL_VERSION=${kernel.modDirVersion}
        export INSTALL_MOD_PATH=$out
        make -j$NIX_BUILD_CORES
      '';

      meta = with lib; {
        description = "BrosTrend linux kernel module";
        homepage = "https://linux.brostrend.com/";
        license = licenses.gpl2;
        platforms = platforms.linux;
      };
    };

  # Patched hid-asus kernel module for ASUS Zenbook Duo UX8406 (incl. UX8406CA).
  #
  # Adds keyboard backlight, Fn keys, Fn-lock support, hotkey mappings, and
  # report descriptor fixups for the detachable Zenbook Duo keyboard
  # (USB and Bluetooth, both UX8406MA and UX8406CA variants).
  #
  # Source of the patch series:
  #   https://github.com/hacker1024/linux/tree/ux8406-hid-6.19
  # Forward-ported to mainline 7.0+: by 7.0 the upstream hid-asus driver had
  # already absorbed the QUIRK_HID_FN_LOCK plumbing and the asus-wmi listener
  # API, and dropped the asus-wmi-leds-ids.h header. Only the device-specific
  # bits (PIDs, quirk, report descriptor fixups, fake-keyboard injection on
  # the dedicated vendor USB interface, vendor init retry, and 0x86/0x9c/0x9d
  # hotkey handling) remain in this patch.
  #
  # Built as an out-of-tree module so that using it does NOT invalidate the
  # stock NixOS kernel binary cache. The resulting hid-asus.ko is placed in
  # /lib/modules/<version>/extra/ which is searched before the in-tree
  # kernel/drivers/hid/hid-asus.ko.xz by kmod, so our patched module wins.
  hid-asus-ux8406 =
    {
      stdenv,
      lib,
      kernel,
    }:
    stdenv.mkDerivation {
      pname = "hid-asus-ux8406";
      version = kernel.version;

      src = kernel.src;

      patches = [ ./patches/ux8406ca-hid-asus.patch ];

      nativeBuildInputs = kernel.moduleBuildDependencies;

      hardeningDisable = [
        "pic"
        "format"
      ];

      enableParallelBuilding = true;

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild

        # Assemble a minimal out-of-tree source directory containing only the
        # files we need from the (now-patched) kernel tree. hid-asus.c only
        # needs hid-ids.h from the same drivers/hid directory.
        mkdir -p build
        cp drivers/hid/hid-asus.c build/
        cp drivers/hid/hid-ids.h  build/

        cat > build/Kbuild <<'EOF'
        obj-m := hid-asus.o
        EOF

        make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
          M=$(pwd)/build \
          modules

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        install -D -m 0644 build/hid-asus.ko \
          $out/lib/modules/${kernel.modDirVersion}/extra/hid-asus.ko

        runHook postInstall
      '';

      meta = {
        description = "Patched hid-asus kernel module for ASUS Zenbook Duo (UX8406)";
        license = lib.licenses.gpl2Only;
        platforms = [ "x86_64-linux" ];
      };
    };

  dummy =
    { pkgs }:
    pkgs.writeShellScriptBin "_dummy" ''
      echo "Dummy package as a placeholder for some other package"
    '';

  editor-wrapped =
    { pkgs }:
    pkgs.writeShellScriptBin "editor-wrapped" ''
      if [[ -z $EDITOR ]]; then
        export EDITOR=nvim
      fi
      if [[ $QUIT_ON_OPEN == "1" ]]; then
        $EDITOR "$@"
        kill -9 $(ps -o ppid= -p $$)
      else
        $EDITOR "$@"
      fi
    '';

  neovim-reloadable-unwrapped =
    { pkgs, lib }:
    pkgs.symlinkJoin (
      let
        reloadable-script = pkgs.writeShellScriptBin "nvim" ''
          while true; do
            ${pkgs.neovim-unwrapped}/bin/nvim "$@"
            RET=$?
            if [[ $RET != 100 ]]; then
              exit $RET
            fi
          done
        '';
      in
      rec {
        inherit (pkgs.neovim-unwrapped) meta lua;
        pname = "neovim-reloadable-unwrapped";
        version = lib.getVersion pkgs.neovim-unwrapped;
        name = "${pname}-${version}";
        paths = [ pkgs.neovim-unwrapped ];
        postBuild = ''
          rm $out/bin/nvim
          cp ${reloadable-script}/bin/nvim $out/bin/nvim
        '';
      }
    );

  mkcd =
    { pkgs }:
    pkgs.writeShellScriptBin "mkcd" ''
      mkdir -p "$1" && cd "$1"
    '';

  patchdir =
    { pkgs }:
    pkgs.writeShellScriptBin "patchdir" ''
      if [[ -z $1 ]]; then
        echo "Usage: patchdir <directory>"
        exit 1
      fi
      ${pkgs.findutils}/bin/find "$1" -type f -exec sh -c '
        if ${pkgs.file}/bin/file "$1" | grep -q "ELF"; then
          ${pkgs.patchelf}/bin/patchelf --add-rpath $NIX_LD_LIBRARY_PATH "$1"
        fi
      ' _ {} \;
    '';
  ctrl2esc =
    { pkgs }:
    pkgs.writeShellScriptBin "ctrl2esc" ''
      sudo systemctl stop interception-tools-caps2esc.service
      sudo systemctl start interception-tools-ctrl2esc.service
    '';
  caps2esc =
    { pkgs }:
    pkgs.writeShellScriptBin "caps2esc" ''
      sudo systemctl stop interception-tools-ctrl2esc.service
      sudo systemctl start interception-tools-caps2esc.service
    '';

  # scaphandre: power consumption metrology agent, used by the laptop
  # profile's Prometheus exporter. Inlined here because upstream nixpkgs
  # removed both the package and the
  # `services.prometheus.exporters.scaphandre` NixOS option in late June
  # 2026 (marked broken with no upstream progress since Feb 2025). Pin the
  # last working release (v1.0.2) and apply the riemann-client rustfmt
  # fixup so it builds under the toolchain in our nixos-unstable input.
  scaphandre =
    {
      lib,
      rustPlatform,
      fetchFromGitHub,
      pkg-config,
      openssl,
      runCommand,
    }:
    let
      version = "1.0.2";
      base = rustPlatform.buildRustPackage {
        pname = "scaphandre";
        inherit version;
        src = fetchFromGitHub {
          owner = "hubblo-org";
          repo = "scaphandre";
          rev = "v${version}";
          hash = "sha256-I+cECdpLoIj4yuWXfirwHlcn0Hkm9NxPqo/EqFiBObw=";
        };
        cargoHash = "sha256-OIoQ2r/T0ZglF1pe25ND8xe/BEWgP9JbWytJp4k7yyg=";
        nativeBuildInputs = [ pkg-config ];
        buildInputs = [ openssl ];
        # These tests hard-code /sys/class/powercap, which is unavailable in the build sandbox.
        checkFlags = [
          "--skip"
          "exporter_qemu"
          "--skip"
          "sensors::powercap_rapl::tests::get_topology_returns_topology_type"
          "--skip"
          "sensors::tests::read_core_stats"
          "--skip"
          "sensors::tests::read_socket_stats"
          "--skip"
          "sensors::tests::read_topology_stats"
        ];
        meta = {
          description = "Electrical power consumption metrology agent";
          homepage = "https://github.com/hubblo-org/scaphandre";
          license = lib.licenses.asl20;
          platforms = [ "x86_64-linux" ];
          maintainers = [ ];
          mainProgram = "scaphandre";
        };
      };
    in
    base.overrideAttrs (old: {
      cargoDeps = runCommand "${old.pname}-${old.version}-vendor-patched" { } ''
        cp -r ${old.cargoDeps} $out
        chmod -R u+w $out
        patch -p1 -d $out/source-registry-0 < ${./patches/riemann-client-rustfmt.patch}
      '';
    });
}
