{ config, pkgs, lib, inputs, ... }:
let
  treeSitterGrub = pkgs.stdenv.mkDerivation {
    name = "tree-sitter-grub";
    src = inputs.tree-sitter-grub;
    nativeBuildInputs = [ pkgs.tree-sitter ];
    buildPhase = ''
      HOME=$TMPDIR
      tree-sitter build -o grub.so .
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp grub.so $out/lib/
    '';
  };
  grubPatchPythonEnv = pkgs.python3.withPackages (ps: [ ps.tree-sitter ]);
  installGrubPatch = pkgs.writeShellScript "install-grub-patch" ''
    export PATH="${pkgs.grub2}/bin:$PATH"
    exec ${grubPatchPythonEnv}/bin/python3 ${./scripts/patch_grub_cfg}/install_grub_patch.py \
      --grammar-lib "${treeSitterGrub}/lib/grub.so" "$@"
  '';
in
{
  boot.loader = {
    grub = {
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
      gfxmodeEfi = "1024x768";
      default = "saved";
      extraGrubInstallArgs = [
        "--disable-shim-lock"
        "--modules=tpm gcry_sha512 gcry_rsa"
      ];
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
  };

  boot.loader.grub.extraInstallCommands = ''
    set -euo pipefail

    # sign EFI binaries for Secure Boot
    export PATH=${lib.makeBinPath [ pkgs.sbctl pkgs.util-linux pkgs.gawk pkgs.coreutils ]}:$PATH

    if [ -f /boot/efi/EFI/NixOS-boot-efi/grubx64.efi ]; then
      sbctl sign /boot/efi/EFI/NixOS-boot-efi/grubx64.efi
    fi

    for f in /boot/grub/**/*.efi; do
      [ -e "$f" ] && sbctl sign "$f"
    done

    if [ -d /boot/kernels ]; then
      for f in /boot/kernels/*-bzImage; do
        [ -e "$f" ] && sbctl sign "$f"
      done
    fi

    # patch grub.cfg to use custom grubenv location (AST-based)
    ${installGrubPatch} --efi-mount ${lib.escapeShellArg config.boot.loader.efi.efiSysMountPoint} --grub-dir /boot/grub
  '';
}
