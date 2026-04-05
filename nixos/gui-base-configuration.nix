{ pkgs, ... }:
let
  google-chromium = pkgs.symlinkJoin {
    name = "google-chromium";
    paths = [ pkgs.chromium ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/chromium \
      --run 'export GOOGLE_DEFAULT_CLIENT_ID=$(cat ${./private/google-default-client-id})' \
      --run 'export GOOGLE_DEFAULT_CLIENT_SECRET=$(cat ${./private/google-default-client-secret})'
      '';
  };
  firefox-alias = pkgs.writeShellScriptBin "firefox" ''
    ${pkgs.firefox-devedition}/bin/firefox-devedition "$@"
  '';
in
{
  # Audio - pipewire
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    jack.enable = true;
  };
  security.rtkit.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Graphics
  hardware.graphics.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.fira-code
    wqy_zenhei
  ];

  # Display manager
  programs.dconf.enable = true;

  # Basic audio tools
  environment.systemPackages = with pkgs; [
    pavucontrol
    pulseaudio
    alsa-utils
    google-chromium
    firefox-devedition
    firefox-alias
    chntpw # Windows registry editor

    playerctl
    libsecret
    keepassxc

    kitty
  ];

  # Audio group
  users.extraUsers.qsdrqs.extraGroups = [ "audio" ];
}
