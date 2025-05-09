{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nodejs
    inferno # flamegraph
    cmake
    extra-cmake-modules
    gnumake
    gcc
    (gcc.cc // { meta.priority = 10; }) # set a lower priority for gcc.cc (higher number means lower priority)
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
    tree-sitter
  ];
}
