{
  rtl88x2bu =
    { stdenv
    , lib
    , fetchFromGitHub
    , kernel
    , kmod
    , inputs
    , dpkg
    , bc
    }: stdenv.mkDerivation rec {
      pname = "rtl88x2bu";
      version = "5.13.1";
      name = "${pname}-${version}-${kernel.version}";

      src = inputs.rtl88x2bu-dkms;

      sourceRoot = "usr/src/${pname}-${version}";
      hardeningDisable = [ "pic" "format" ];
      nativeBuildInputs = [
        dpkg
        bc
      ] ++ kernel.moduleBuildDependencies;

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

  dummy = { pkgs }: pkgs.writeShellScriptBin "_dummy" ''
    echo "Dummy package as a placeholder for some other package"
  '';

  editor-wrapped = { pkgs }: pkgs.writeShellScriptBin "editor-wrapped" ''
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

  neovim-reloadable-unwrapped = { pkgs, lib }: pkgs.symlinkJoin (
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

  mkcd = { pkgs }: pkgs.writeShellScriptBin "mkcd" ''
    mkdir -p "$1" && cd "$1"
  '';

patchdir = { pkgs }: pkgs.writeShellScriptBin "patchdir" ''
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
}
