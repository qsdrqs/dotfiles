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
  automake = mkShell {
    buildInputs = [
      gcc
      autoconf
      automake
      libtool
      pkg-config
    ];
  };
  python =
    let
      defaultPyPkgs = (pypkgs: with pypkgs; [
        numpy
        matplotlib
      ]);
      common_shell = rec {
        packages = [
          python3Packages.virtualenv
          pyright
          python3Packages.autopep8
          python3Packages.isort
          python3Packages.debugpy
        ];
        buildInputs = [
          zlib
          glibc
        ];
        shellHook = ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
          export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib.outPath}/lib:$LD_LIBRARY_PATH"
        '';
      };
    in
    (mkShell common_shell // {
      packages = [
        (python3.withPackages defaultPyPkgs)
      ] ++ common_shell.packages;
    }) // {
    extraPyPkgs = (extraPyPkgs: mkShell common_shell // {
      packages = [
        (python3.withPackages (pypkgs: (defaultPyPkgs pypkgs) ++ (extraPyPkgs pypkgs)))
      ] ++ common_shell.packages;
    });
  };
  java = mkShell {
    packages = [
      jdk8
      maven
      gradle
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
      fastfetch
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
