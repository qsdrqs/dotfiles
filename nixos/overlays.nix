{ config, pkgs, lib, inputs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      libvterm-neovim = super.libvterm-neovim.overrideAttrs (oldAttrs: {
        version = "0.3.3";
        src = builtins.fetchurl {
          url = "https://launchpad.net/libvterm/trunk/v0.3/+download/libvterm-0.3.3.tar.gz";
          sha256 = "1q16fbznm54p24hqvw8c9v3347apk86ybsxyghsbsa11vm1ny589";
        };
      });
      neovim-unwrapped = super.neovim-unwrapped.overrideAttrs (oldAttrs: {
        src = inputs.nvim-config.neovim;
        version = "0.10.0-dev";
      });

      ranger = super.ranger.overrideAttrs (oldAttrs: {
        src = inputs.ranger;
        propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [ pkgs.python3Packages.pylint ];
      });

      variety = super.variety.overrideAttrs (oldAttrs: {
        prePatch = oldAttrs.prePatch + ''
          substituteInPlace data/scripts/set_wallpaper --replace "\"i3\"" "\"none+i3\""
          substituteInPlace data/scripts/set_wallpaper --replace "feh --bg-fill" "feh --bg-scale --no-xinerama"
        '';
      });

      vscode = super.vscode.override (old: {
        commandLineArgs = (old.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" "-g" ];
      });

      vscode-insiders = (super.vscode.override (prev: {
        commandLineArgs = (prev.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" "-g" ];
        isInsiders = true;
      })).overrideAttrs (prev: {
        src = (builtins.fetchTarball {
          url = "https://update.code.visualstudio.com/latest/linux-x64/insider";
          sha256 = "0pvmhwxprpdmxm2z4cb365sbxii0v6rn7jnyhybfiii7r309cg7v";
        });
        version = "latest";
        buildInputs = prev.buildInputs ++ [ pkgs.krb5 ];
      });

      vscodium = super.vscodium.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          mkdir tmp-marketplace
          cp -r ${inputs.code-marketplace}/* tmp-marketplace
          substituteInPlace tmp-marketplace/patch.py \
          --replace "patch_path = \"/usr/share/%s/patch.json\" % pkt_name" "patch_path = \"${inputs.code-marketplace}/patch.json\"" \
          --replace "cache_path = \"/usr/share/%s/cache.json\" % pkt_name" "cache_path = \"tmp-marketplace/cache.json\"" \
          --replace "product_path = \"/usr/lib/code/product.json\"" "product_path = \"$out/lib/vscode/resources/app/product.json\""
          ${pkgs.python3}/bin/python3 tmp-marketplace/patch.py dummy patch

          mkdir tmp-features
          cp -r ${inputs.code-features}/* tmp-features
          substituteInPlace tmp-features/patch.py \
          --replace "patch_path = \"/usr/share/%s/patch.json\" % pkt_name" "patch_path = \"${inputs.code-features}/patch.json\"" \
          --replace "cache_path = \"/usr/share/%s/cache.json\" % pkt_name" "cache_path = \"tmp-features/cache.json\"" \
          --replace "product_path = \"/usr/lib/code/product.json\"" "product_path = \"$out/lib/vscode/resources/app/product.json\""
          ${pkgs.python3}/bin/python3 tmp-features/patch.py dummy patch
        '';
      });

      deadd-notification-center = super.deadd-notification-center.overrideAttrs (oldAttrs: {
        src = pkgs.fetchFromGitHub {
          owner = "phuhl";
          repo = "linux_notification_center";
          rev = "master";
          hash = "sha256-VU9NaQVS0n8hFRjWMvCMkaF5mZ4hpnluV31+/SAK7tU=";
        };
        version = "2.1.1";
      });

      firefox-devedition = super.firefox-devedition.overrideAttrs (oldAttrs: {
        buildCommand = (oldAttrs.buildCommand or "") + ''
          mkdir -p $out/tmp/firefox-omni
          cd $out/tmp/firefox-omni
          ${pkgs.unzip}/bin/unzip $out/lib/firefox/browser/omni.ja
          patch chrome/browser/content/browser/browser.xhtml < ${patches/browser.xhtml.patch}
          ${pkgs.zip}/bin/zip -0DXqr $out/tmp/omni.ja *
          cp -f $out/tmp/omni.ja $out/lib/firefox/browser/omni.ja
          rm -rf $out/tmp
        '';
      });

      grc = super.grc.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          sed -i 's/.{commands\[\$0\]}/\$0/g' $out/etc/grc.zsh
        '';
      });

    })
  ];
}
