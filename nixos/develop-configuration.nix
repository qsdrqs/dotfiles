{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nodejs
    inferno # flamegraph
    cmake
    gnumake
    gcc
    gdb
    ninja
    clang
    clang-tools
    rustup
    llvm
    bear
    go
    hoppscotch # http request tool
  ];
}
