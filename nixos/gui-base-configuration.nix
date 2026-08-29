{ config, pkgs, ... }:
let
  google-chromium = pkgs.symlinkJoin {
    name = "google-chromium";
    paths = [ pkgs.chromium ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/chromium \
      --run 'export GOOGLE_API_KEY=$(cat ${./private/google-api-key})' \
      --run 'export GOOGLE_DEFAULT_CLIENT_ID=$(cat ${./private/google-default-client-id})' \
      --run 'export GOOGLE_DEFAULT_CLIENT_SECRET=$(cat ${./private/google-default-client-secret})'
    '';
  };
  firefox-alias = pkgs.writeShellScriptBin "firefox" ''
    ${pkgs.firefox-devedition}/bin/firefox-devedition "$@"
  '';
  pamModules = "${config.security.pam.package}/lib/security";
  sudoAuth = config.security.pam.services.sudo.rules.auth;
  sudoAuthBranchOrder = sudoAuth.unix.order - 4;
  pamIsRemoteSsh = pkgs.writeShellScript "pam-is-remote-ssh" ''
    exec ${pkgs.gnugrep}/bin/grep -zq '^SSH_CONNECTION=' "/proc/$PPID/environ"
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
  programs.yubikey-manager.enable = true;

  # Allow a registered YubiKey to authenticate local PAM services.
  # "sufficient" lets a successful U2F assertion replace the password while
  # retaining the existing PAM methods as fallback.
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      # Use one system-managed mapping file instead of per-user home files.
      authfile = "/etc/u2f-mappings";
      cue = true;
      # Keep the U2F origin stable instead of deriving it from the hostname.
      origin = "pam://u2f-local-auth";
      pinverification = 1;
    };
  };

  # Make the private per-user U2F registrations available at the path above.
  environment.etc."u2f-mappings".source = ./private/u2f-mappings;

  # sudo authentication flow:
  #
  #                       +-- SSH --> skip 2 rules --> rssh --+
  # remoteSshSession -----+                                  +--> unix --> deny
  #                       +-- local --> u2f --> skip rssh ----+
  #
  # A successful u2f, rssh, or unix rule authenticates immediately. On the
  # local path, pam_permit always succeeds and success=1 skips the rssh rule.
  security.sudo.extraConfig = ''
    Defaults env_keep+=SSH_CONNECTION
  '';
  security.pam.services.sudo.rules.auth = {
    remoteSshSession = {
      order = sudoAuthBranchOrder;
      control = "[success=2 default=ignore]";
      modulePath = "${pamModules}/pam_exec.so";
      args = [
        "seteuid"
        "quiet"
        "quiet_log"
        "${pamIsRemoteSsh}"
      ];
    };
    u2f.order = sudoAuthBranchOrder + 1;
    skipRsshAfterLocalU2f = {
      order = sudoAuthBranchOrder + 2;
      control = "[success=1 default=ignore]";
      modulePath = "${pamModules}/pam_permit.so";
    };
    rssh.order = sudoAuthBranchOrder + 3;
  };

  assertions = [
    {
      assertion = sudoAuth.u2f.enable;
      message = "Conditional sudo authentication requires the U2F PAM rule.";
    }
    {
      assertion = sudoAuth.rssh.enable;
      message = "Conditional sudo authentication requires the rssh PAM rule.";
    }
    {
      assertion = sudoAuth.unix.enable;
      message = "Conditional sudo authentication requires the Unix password PAM rule.";
    }
  ];

  # Basic audio tools
  environment.systemPackages = with pkgs; [
    pavucontrol
    pulseaudio
    alsa-utils
    google-chromium
    google-chrome
    firefox-devedition
    firefox-alias
    chntpw # Windows registry editor

    playerctl
    libsecret
    keepassxc
    yubioath-flutter

    kitty
  ];

  # Audio group
  users.extraUsers.qsdrqs.extraGroups = [ "audio" ];
}
