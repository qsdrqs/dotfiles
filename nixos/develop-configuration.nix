{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nodejs
    inferno # flamegraph
    cmake
    extra-cmake-modules
    gnumake
    gcc
    libgcc
    gdb
    ninja
    clang
    clang-tools
    rustup
    llvm
    bear
    go
    hoppscotch # http request tool
    bfg-repo-cleaner
  ];
}
