{ pkgs, lib, ... }:
with pkgs; {
  rust =
    let
      clangShortVer = builtins.head (
        lib.splitString "." (
          lib.getVersion llvmPackages_latest.clang
        )
      );
    in
    mkShell {
      packages = [
        rustup
        rustc
        rustfmt
        clippy
        rust-analyzer
        cmake
        llvmPackages_latest.llvm
      ];
      shellHook = ''
        export LIBCLANG_PATH="${llvmPackages_latest.libclang.lib}/lib"
        export BINDGEN_EXTRA_CLANG_ARGS="
          -isystem ${llvmPackages_latest.libclang.lib}/lib/clang/${clangShortVer}/include
          -isystem ${libjpeg_turbo.dev}/include
          -isystem ${glibc.dev}/include
        "
        export RUST_SRC_PATH="${rust.packages.stable.rustPlatform.rustLibSrc}"
      '';
    };
  cpp = mkShell {
    packages = [
      cmake
      gnumake
      gdb
      ninja
      bear
      clang-tools_16
      clang_16
      llvm_16
      pkg-config
    ];
  };
  python = mkShell {
    packages = [
      python3Packages.virtualenv
      python3Packages.numpy
      python3Packages.matplotlib
      python3Packages.autopep8
      python3Packages.debugpy
      python3Packages.isort
      nodePackages.pyright
    ];
  };
  go = mkShell {
    packages = [
      go
      gopls
    ];
  };
  base_dev = mkShell {
    packages = [
      ranger
      neovim
      lazygit
      neofetch
    ];
    LD_LIBRARY_PATH = lib.makeLibraryPath [ openssl ];
  };
  node = mkShell {
    packages = [
      nodePackages.pnpm
      nodePackages.yarn
    ];
  };
}
