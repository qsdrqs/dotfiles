{ config, pkgs, lib, inputs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      neovim-unwrapped = super.neovim-unwrapped.overrideAttrs (oldAttrs: {
        src = inputs.neovim;
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
        commandLineArgs = (old.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" ];
      });

      vscode-insiders = (super.vscode.override (prev: {
        commandLineArgs = (prev.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" ];
        isInsiders = true;
      })).overrideAttrs (prev: {
        src = (builtins.fetchTarball {
          url = "https://update.code.visualstudio.com/latest/linux-x64/insider";
          sha256 = "1gkyagbrkihxbzcw8z0rg7plvgp7gg7yq6nlc0r7hwczsgz1dj1j";
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

    })
  ];
}
