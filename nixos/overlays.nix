{ pkgs, lib, inputs, ... }:
let
  # Neovim Treesitter Parsers
  # The following code is taken from {github.com/neovim/neovim}/contrib/flake.nix
  # which is licensed under the Apache License, Version 2.0
  # Copyright Neovim contributors
  treesitter-parsers = (final: lib.pipe "${inputs.nvim-config.neovim}/cmake.deps/deps.txt" [
    builtins.readFile
    (lib.splitString "\n")
    (map (builtins.match "TREESITTER_([A-Z_]+)_(URL|SHA256)[[:space:]]+([^[:space:]]+)[[:space:]]*"))
    (lib.remove null)
    (lib.flip builtins.foldl' { }
      (acc: matches:
        let
          lang = lib.toLower (builtins.elemAt matches 0);
          type = lib.toLower (builtins.elemAt matches 1);
          value = builtins.elemAt matches 2;
        in
        acc // {
          ${lang} = acc.${lang} or { } // {
            ${type} = value;
          };
        }))
    (builtins.mapAttrs (lib.const final.fetchurl))
    (self: self // {
      markdown = final.stdenv.mkDerivation {
        inherit (self.markdown) name;
        src = self.markdown;
        installPhase = ''
          mv tree-sitter-markdown $out
        '';
      };
    })
  ]);
  pkgs-master = import inputs.nixpkgs-master {
    system = pkgs.system;
    config.allowUnfree = true;
  };
  pkgs-fix = import inputs.nixpkgs-fix {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in
{
  nixpkgs.overlays = [
    (self: super:
      {
        makeModulesClosure = x:
          super.makeModulesClosure (x // { allowMissing = true; });

        yazi =
          if pkgs.system == "x86_64-linux" then inputs.yazi.packages.${super.system}.default
          else
            let
              inherit (pkgs.stdenv.hostPlatform) system;
              throwSystem = throw "Unsupported system: ${system}";
            in
            pkgs.stdenv.mkDerivation rec {
              pname = "yazi";
              version = "nightly";
              platform = {
                x86_64-linux = "x86_64-unknown-linux-gnu";
                aarch64-linux = "aarch64-unknown-linux-gnu";
              }.${system} or throwSystem;
              sha256 = {
                x86_64-linux = "0gvzzpfjlsv1gmdn6pc701arx5vnfwxcsgqd37rlpf02a5qkhagy";
                aarch64-linux = "02a6bpyknlj8q6ywxbjd6nn5dh7n68b9rwj5cs9qvnv927xb5dwp";
              }.${system} or throwSystem;
              src = builtins.fetchurl {
                url = "https://github.com/sxyazi/yazi/releases/download/nightly/yazi-${platform}.zip";
                inherit sha256;
              };
              nativeBuildInputs = [ pkgs.installShellFiles ];
              phases = [ "installPhase" ]; # Removes all phases except installPhase
              installPhase = ''
                mkdir -p $out/bin
                ${pkgs.unzip}/bin/unzip $src -d tmp
                cp tmp/yazi-${platform}/ya $out/bin/ya
                cp tmp/yazi-${platform}/yazi $out/bin/yazi

                installShellCompletion --cmd yazi \
                  --bash ./tmp/yazi-${platform}/completions/yazi.bash \
                  --fish ./tmp/yazi-${platform}/completions/yazi.fish \
                  --zsh  ./tmp/yazi-${platform}/completions/_yazi
                installShellCompletion --cmd ya \
                  --bash ./tmp/yazi-${platform}/completions/ya.bash \
                  --fish ./tmp/yazi-${platform}/completions/ya.fish \
                  --zsh  ./tmp/yazi-${platform}/completions/_ya
              '';
            };
        neovim-unwrapped = inputs.nvim-config.neovim.packages.${pkgs.system}.default;

        # Begin Temporary self updated packages, until they are merged upstream, remove them when they are merged
        # End Temporary self updated packages

        # Begin Temporary fixed version packages
        # End Temporary fixed version packages

        # neovim-unwrapped =
        #   (super.neovim-unwrapped.override {
        #     treesitter-parsers = treesitter-parsers self;
        #   }).overrideAttrs
        #     (oldAttrs: {
        #       src = inputs.nvim-config.neovim;
        #       version = "0.10.0-dev";
        #       postInstall = (oldAttrs.postInstall or "") + ''
        #         # disable treesitter by default for ftplugins
        #         ${pkgs.gnugrep}/bin/grep -rl 'vim.treesitter.start()' $out/share/nvim/runtime/ftplugin |\
        #         ${pkgs.findutils}/bin/xargs ${pkgs.gnused}/bin/sed -i 's/vim.treesitter.start()/-- vim.treesitter.start()/g'
        #       '';
        #     });

        # for config.programs.neovim
        wrapNeovim = (nvim: args: super.wrapNeovim nvim (args // {
          withPython3 = true;
          extraPython3Packages = p: with p; [
            # for CopilotChat.nvim
            python-dotenv
            requests
            prompt-toolkit
            tiktoken
          ];
        }));

        ranger = super.ranger.overrideAttrs (oldAttrs: {
          src = inputs.ranger-config.ranger;
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

        # vscode-insiders = (super.vscode.override (prev: {
        #   commandLineArgs = (prev.commandLineArgs or [ ]) ++ [ "--enable-wayland-ime" "-g" ];
        #   isInsiders = true;
        # })).overrideAttrs (prev: {
        #   src = inputs.vscode-insiders;
        #   version = "latest";
        #   buildInputs = prev.buildInputs ++ [ pkgs.krb5 ];
        # });

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
            echo $(${pkgs.unzip}/bin/unzip $out/lib/firefox/browser/omni.ja) # TODO: workaround for omni.ja breaking
            patch chrome/browser/content/browser/browser.xhtml < ${patches/browser.xhtml.patch}
            ${pkgs.zip}/bin/zip -0DXqr $out/tmp/omni.ja *
            cp -f $out/tmp/omni.ja $out/lib/firefox/browser/omni.ja
            rm -rf $out/tmp
          '';
        });

        interception-tools-plugins.ctrl2esc = super.interception-tools-plugins.caps2esc.overrideAttrs (oldAttrs: {
          pname = "ctrl2esc";
          src = pkgs.fetchFromGitLab {
            owner = "qsdrqs";
            repo = "ctrl2esc";
            rev = "master";
            hash = "sha256-rpob9VLKt1aL0Jys9OkhwDZb0dCoch/A0SkHIBDhRSU=";
          };
        });
        interception-tools-plugins.caps2esc = super.interception-tools-plugins.caps2esc;

        neovide = super.neovide.overrideAttrs (oldAttrs: {
          nativeCheckInputs = [ ];
          doCheck = false;
        });
      })
  ];
}
