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
        rustc
        cargo
        rustfmt
        clippy
        cargo-depgraph
        rust-analyzer
        cmake
        llvmPackages_latest.llvm
        # rustup
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
  python =
    let
      defaultPyPkgs = (pypkgs: with pypkgs; [
        virtualenv
        numpy
        matplotlib
        autopep8
        debugpy
        isort
      ]);
    in
    (mkShell {
      packages = [
        (python3.withPackages defaultPyPkgs)
        nodePackages.pyright
      ];
    }) // {
    extraPyPkgs = (extraPyPkgs: mkShell {
      packages = [
        (python3.withPackages (pypkgs: (defaultPyPkgs pypkgs) ++ (extraPyPkgs pypkgs)))
      ];
    });
  };
  java = mkShell {
    packages = [
      jdk8
      maven
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
