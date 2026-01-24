{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
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
    act
    inotify-tools
    pkg-config

    # android
    android-file-transfer
    android-tools

    keepassxc
    texlive.combined.scheme-full
    distrobox
    bun
  ];

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu.vhostUserPackages = [ pkgs.virtiofsd ];
    };
    docker.enable = true;
    podman.enable = true;
  };

}
