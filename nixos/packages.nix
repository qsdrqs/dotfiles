{ config, pkgs, lib, inputs,... }:

{
  rtl88x2bu = { stdenv, lib, fetchFromGitHub, kernel, kmod }: stdenv.mkDerivation rec {
    pname = "rtl88x2bu";
    version = "5.13.1";
    name = "${pname}-${version}-${kernel.version}";

    src = inputs.rtl88x2bu-dkms;

    sourceRoot = "usr/src/${pname}-${version}";
    hardeningDisable = [ "pic" "format" ];
    nativeBuildInputs = with pkgs; [
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

}
