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
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  pkgs-stable = import inputs.nixpkgs-stable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  pkgs-last = import inputs.nixpkgs-last {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  packages = builtins.mapAttrs (name: value: pkgs.callPackage value { }) (import ./packages.nix);
in
{
  nixpkgs.overlays = [
    (self: super:
      {
        makeModulesClosure = x:
          super.makeModulesClosure (x // { allowMissing = true; });

        # yazi = inputs.yazi.packages.${super.system}.default;
        #   if pkgs.system == "x86_64-linux" then inputs.yazi.packages.${super.system}.default
        #   else if pkgs.system == "aarch64-linux" then
        #     pkgs.stdenv.mkDerivation
        #       {
        #         pname = "yazi";
        #         version = "nightly";
        #         src = inputs.yazi-aarch64-nightly;
        #         nativeBuildInputs = [ pkgs.installShellFiles ];
        #         phases = [ "installPhase" ]; # Removes all phases except installPhase
        #         installPhase = ''
        #           mkdir -p $out/bin
        #           cp $src/ya $out/bin/ya
        #           cp $src/yazi $out/bin/yazi
        #
        #           installShellCompletion --cmd yazi \
        #             --bash $src/completions/yazi.bash \
        #             --fish $src/completions/yazi.fish \
        #             --zsh  $src/completions/_yazi
        #           installShellCompletion --cmd ya \
        #             --bash $src/completions/ya.bash \
        #             --fish $src/completions/ya.fish \
        #             --zsh  $src/completions/_ya
        #         '';
        #       }
        #   else throw "Unsupported system: ${pkgs.system}";
        # neovim-unwrapped = inputs.nvim-config.neovim.packages.${pkgs.system}.default;

        # Begin Temporary self updated packages, until they are merged upstream, remove them when they are merged
        tzupdate = super.rustPlatform.buildRustPackage {
          pname = "tzupdate";
          version = "unstable-2025-09-02";
          src = super.fetchFromGitHub {
            owner = "cdown";
            repo = "tzupdate";
            rev = "91d65d861c4e10d2353357edfd33158197e8dc09";
            hash = "sha256-XWl0erykdn8mHFczr8jPkjk7jgNOXndmMNrV6QKb0jY=";
          };
          cargoHash = "sha256-96lD0Sc2hdhNKeIS4zkiG4J0dxEFt6/Np7HHMSoF8j4=";
          meta = super.tzupdate.meta;
        };
        # End Temporary self updated packages

        # Begin Temporary fixed version packages
        wrapGAppsHook = super.wrapGAppsHook3;
        scaphandre = super.scaphandre.overrideAttrs (old: {
          cargoDeps = super.runCommand "${old.pname}-${old.version}-vendor-patched" {} ''
            cp -r ${old.cargoDeps} $out
            chmod -R u+w $out
            patch -p1 -d $out < ${./patches/riemann-client-rustfmt.patch}
          '';
          meta.broken = false;
        });
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

        keepassxc = super.keepassxc.overrideAttrs (oldAttrs: {
          src = super.fetchFromGitHub {
            owner = "keepassxreboot";
            repo = "keepassxc";
            rev = "eefee1f092f5f1dc85c7f06da68637c7c5cabbc7";
            hash = "sha256-+/0Ee3tOY51YiKlYPxE33Q+g2AuNXfO/lsnaYx9i5cI=";
          };
          nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
            super.keyutils
          ];
          patches = [
            (builtins.elemAt oldAttrs.patches 0)
          ];
          doCheck = false;
        });

        ranger = super.ranger.overrideAttrs (oldAttrs: {
          src = inputs.ranger-config.ranger;
          propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [ pkgs.python3Packages.pylint ];
        });

        # variety = super.variety.overrideAttrs (oldAttrs: {
        #   prePatch = oldAttrs.prePatch + ''
        #     substituteInPlace data/scripts/set_wallpaper --replace-fail "\"i3\"" "\"none+i3\""
        #     substituteInPlace data/scripts/set_wallpaper --replace-fail "feh --bg-fill" "feh --bg-scale --no-xinerama"
        #   '';
        # });

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
            --replace-fail "patch_path = \"/usr/share/%s/patch.json\" % pkt_name" "patch_path = \"${inputs.code-marketplace}/patch.json\"" \
            --replace-fail "cache_path = \"/usr/share/%s/cache.json\" % pkt_name" "cache_path = \"tmp-marketplace/cache.json\"" \
            --replace-fail "product_path = \"/usr/lib/code/product.json\"" "product_path = \"$out/lib/vscode/resources/app/product.json\""
            ${pkgs.python3}/bin/python3 tmp-marketplace/patch.py dummy patch

            mkdir tmp-features
            cp -r ${inputs.code-features}/* tmp-features
            substituteInPlace tmp-features/patch.py \
            --replace-fail "patch_path = \"/usr/share/%s/patch.json\" % pkt_name" "patch_path = \"${inputs.code-features}/patch.json\"" \
            --replace-fail "cache_path = \"/usr/share/%s/cache.json\" % pkt_name" "cache_path = \"tmp-features/cache.json\"" \
            --replace-fail "product_path = \"/usr/lib/code/product.json\"" "product_path = \"$out/lib/vscode/resources/app/product.json\""
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

        firefox-devedition-unwrapped = super.firefox-devedition-unwrapped.override {
          onnxruntime = (super.onnxruntime.override {
            # prevent firefox building
            cudaSupport = false;
          });
        };
        firefox-devedition = super.firefox-devedition.overrideAttrs (oldAttrs: {
          buildCommand = (oldAttrs.buildCommand or "") + ''
            mkdir -p $out/tmp/firefox-omni
            cd $out/tmp/firefox-omni
            echo $(${pkgs.unzip}/bin/unzip $out/lib/firefox-devedition/browser/omni.ja) # TODO: workaround for omni.ja breaking
            patch chrome/browser/content/browser/browser.xhtml < ${patches/browser.xhtml.patch}
            ${pkgs.zip}/bin/zip -0DXqr $out/tmp/omni.ja *
            cp -f $out/tmp/omni.ja $out/lib/firefox-devedition/browser/omni.ja
            rm -rf $out/tmp
          '';
        });

        interception-tools-plugins.ctrl2esc = super.interception-tools-plugins.caps2esc.overrideAttrs (oldAttrs: {
          pname = "ctrl2esc";
          src = inputs.ctrl2esc;
        });
        interception-tools-plugins.caps2esc = super.interception-tools-plugins.caps2esc;

        neovide = super.neovide.overrideAttrs (oldAttrs: {
          nativeCheckInputs = [ ];
          doCheck = false;
        });

        element-desktop = super.element-desktop.overrideAttrs (oldAttrs: {
          desktopItem = super.makeDesktopItem {
            name = "element-desktop";
            exec = "element-desktop --password-store=\"gnome-libsecret\" %u";
            icon = "element";
            desktopName = "Element";
            genericName = "Matrix Client";
            comment = oldAttrs.meta.description;
            categories = [
              "Network"
              "InstantMessaging"
              "Chat"
            ];
            startupWMClass = "Element";
            mimeTypes = [
              "x-scheme-handler/element"
              "x-scheme-handler/io.element.desktop"
            ];
          };
        });

      })
  ];
}
