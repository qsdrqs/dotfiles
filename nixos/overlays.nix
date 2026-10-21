{ pkgs, lib, inputs, config, ... }:
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
  pkgs-unstable = import inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  pkgs-last = import inputs.nixpkgs-last {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
    config.cudaSupport = cudaSupport;
  };
  packages = builtins.mapAttrs (name: value: pkgs.callPackage value { }) (import ./packages.nix);
  cudaSupport = config.nixpkgs.config.cudaSupport or false;
in
{
  nixpkgs.overlays = [
    (self: super:
      {
        makeModulesClosure = x:
          super.makeModulesClosure (x // { allowMissing = true; });

        yazi = pkgs-unstable.yazi;
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
        # BlueZ master fixes the A2DP endpoint cache regression in 5.87.
        # https://github.com/bluez/bluez/commit/b7d71e5067856b0daf2f1f73b3fc95483236610e
        # Remove this package and the hardware.bluetooth.package override once
        # nixpkgs includes that fix.
        bluez-master = super.bluez.overrideAttrs (oldAttrs: {
          version = "5.87-unstable-2026-10-14";
          src = super.fetchFromGitHub {
            owner = "bluez";
            repo = "bluez";
            rev = "fa6ba55020dee3c3183041c854c347b4582448be";
            hash = "sha256-zACKSe0Kh/hqBRZnugXICD4udfO6us4JoclQgjDu+sg=";
          };
          patches = [ ./patches/bluez-master-readline.patch ];
          # gatttool was removed upstream.
          postInstall = builtins.replaceStrings
            [ "install -Dm755 attrib/gatttool $out/bin/gatttool" ]
            [ "" ]
            oldAttrs.postInstall;
        });

        # WayVR 26.8.0 closes capture frame fds before main-thread upload.
        # Use the owned-frame fix until it reaches a stable release.
        # https://github.com/wayvr-org/wayvr/commit/11a5c8305bba5a4bc61ed07dbf90e63ce4b4b81f
        wayvr = super.wayvr.overrideAttrs (finalAttrs: oldAttrs: {
          version = "26.8.0-unstable-2026-10-18";
          src = super.fetchFromGitHub {
            owner = "wayvr-org";
            repo = "wayvr";
            rev = "adf852971fa06afcf859dfe8d734493ed1d7004e";
            hash = "sha256-QjPZYGydnkOk62kVBjqirUHS8J6yUK2PLPP0C3J5K98=";
          };
          cargoHash = "sha256-1452r/EUSwCgdLhU0xmNCYUKJD2girlaUMRx21P/5SU=";
          cargoDeps = super.rustPlatform.fetchCargoVendor {
            inherit (finalAttrs) pname version src;
            hash = finalAttrs.cargoHash;
          };
        });

        # Zotero 10.0.2 fixes HTML indexing with Firefox ESR 140.15.
        # https://github.com/NixOS/nixpkgs/pull/562964
        # Built on nixpkgs-last because the current zotero needs a CUDA firefox-esr-153 that is not
        # in cache.nixos-cuda.org yet; remove together with the nixpkgs-last overrides below.
        zotero =
          let
            zoteroNixpkgs = super.fetchFromGitHub {
              owner = "NixOS";
              repo = "nixpkgs";
              rev = "363fdbe57ed052c76e816e6270206b0cb348e53a";
              hash = "sha256-eaIzbbImStaHMgxftbumWoZuMC+Xm7TraQSsf6da+VI=";
            };
          in
          pkgs-last.callPackage "${zoteroNixpkgs}/pkgs/by-name/zo/zotero/package.nix" { };

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
        # freerdp = super.freerdp.override { openh264 = null; };
        # Lix 2.95.4 fails Meson configuration because mimalloc was introduced in 2.96.
        # https://github.com/NixOS/nixpkgs/pull/573942
        # Remove once the locked nixpkgs includes this fix.
        lix = super.lix.overrideAttrs (oldAttrs: {
          mesonFlags = builtins.filter (flag: flag != "-Dmimalloc=disabled") oldAttrs.mesonFlags;
        });
        # WiVRn 26.9 leaves layer UBO writes unflushed on non-coherent memory,
        # causing stereo corruption during head motion. Remove once fixed upstream.
        # https://github.com/WiVRn/WiVRn/commit/22a819b8c88a1fa03e8d5b8359fed656f23126bb
        wivrn = super.wivrn.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./patches/wivrn-flush-layer-ubo.patch
          ];
        });
        # Current CUDA Firefox builds are not in cache.nixos-cuda.org yet.
        # Use nixpkgs-last for Firefox and Zotero (above) until those builds are cached.
        firefox-devedition-unwrapped = pkgs-last.firefox-devedition-unwrapped;
        # minted 3.7.0 ships latexminted 0.6.0, whose ArgParser does not accept
        # the `color` keyword that Python 3.14's argparse now forwards, so every
        # minted document fails. Upstream fixed this in minted 3.8.0 with
        # latexminted 0.7.x; nixpkgs (including nixpkgs-master) still ships
        # 3.7.0. Replace both halves: the LaTeX package (minted.sty >= 3.8.0)
        # and the Python executable (0.7.1).
        # https://github.com/NixOS/nixpkgs/issues/542483
        # Remove once nixpkgs ships minted >= 3.8.0.
        texlive = super.texlive // {
          pkgs = super.texlive.pkgs // {
            minted =
              let
                version = "3.8.0";
                src = super.fetchFromGitHub {
                  owner = "gpoore";
                  repo = "minted";
                  rev = "631f7e8e93f37d4f6e7767ff45692d53e7c7360d"; # "[latex] minted v3.8.0"
                  hash = "sha256-xUWScWRR62ikRxxz/YEauWLirvhsQPCcyE1O6cpWZRw=";
                };
                minted = super.texlive.pkgs.minted;
                container =
                  name: container: script:
                  super.runCommand "minted-${version}${name}" {
                    inherit (container) meta;
                    passthru = container.passthru // {
                      inherit version;
                    };
                  } script;
              in
              minted // {
                tex = container "-tex" minted.tex ''
                  install -Dm444 -t "$out"/tex/latex/minted \
                    ${src}/latex/minted/minted.sty \
                    ${src}/latex/minted/minted1.sty \
                    ${src}/latex/minted/minted2.sty
                '';
                out = container "" minted.out ''
                  mkdir -p "$out"/bin
                  ln -s ${lib.getExe super.latexminted} "$out"/bin/latexminted
                '';
              };
          };
        };
        # End Temporary fixed version packages

        ckb-next = super.ckb-next.overrideAttrs (oldAttrs: {
          src = inputs.ckb-next;
          patches = (oldAttrs.patches or [ ]) ++ [
            ./patches/ckb-next-k70-pro-mech.patch
          ];
        });

        # moonlight-qt = super.moonlight-qt.overrideAttrs (oldAttrs: {
        #   patches = (oldAttrs.patches or [ ]) ++ [
        #     (super.fetchpatch {
        #       url = "https://github.com/moonlight-stream/moonlight-qt/commit/13880353d8741ae331bf13433c5ad80071d5f44f.patch";
        #       hash = "sha256-bAOAMQteO1XGH6Xn957mNAqnRdaeHIlOtLM8FBzcTJA=";
        #     })
        #     (super.fetchpatch {
        #       url = "https://github.com/moonlight-stream/moonlight-qt/commit/6ce02616f04fb83cd7c5d1492b03367f2220ac46.patch";
        #       hash = "sha256-kiIF60OLle43rD34uJr0Zu4fa0dlggdoWUfJ5j5mtU4=";
        #     })
        #   ];
        # });

        # Fix blueman to expose root properties on D-Bus menu, which is required for the applet to work properly in waybar.
        blueman = super.blueman.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./patches/blueman-dbusmenu-root-properties.patch
          ];
        });

        scaphandre = packages.scaphandre;

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
        neovide = pkgs-unstable.neovide; # use neovide directly from unstable pkgs to avoid build

        # keepassxc = super.keepassxc.overrideAttrs (oldAttrs: {
        #   src = super.fetchFromGitHub {
        #     owner = "keepassxreboot";
        #     repo = "keepassxc";
        #     rev = "331a2de136398f733136c51f1badae5d154878bc";
        #     hash = "sha256-deIg59jSCW5e0WZ5nCTkV46ZK6cwjneA1+3nLlzekE4=";
        #   };
        #   nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        #     super.keyutils
        #   ];
        # });

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

        firefox-devedition = pkgs-last.firefox-devedition.overrideAttrs (oldAttrs: {
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

        howdy = super.howdy.overrideAttrs (old: {
          patches = old.patches ++ [
            ./patches/howdy.patch
          ];
          mesonFlags = old.mesonFlags ++ [
            "-Dextra_path=${super.kbd}/bin/"
          ];
        });

        # Carry per-device tablet/touch config, virtual outputs, and vertical
        # layout with physical direction actions on top of upstream niri main.
        # Keep cross-monitor fullscreen as a separate local feature patch.
        # Remove each patch once its functionality is merged upstream.
        niri = (inputs.niri.overlays.default self super).niri.overrideAttrs (oldAttrs: {
          src = inputs.niri;
          outputs = (oldAttrs.outputs or [ "out" ]) ++ [ "doc" ];
          patches = (oldAttrs.patches or [ ]) ++ [
            ./patches/niri-pr1856-per-device-tablet-touch.patch
            ./patches/niri-pr3800-virtual-outputs.patch
            ./patches/niri-vertical-layout.patch
            ./patches/niri-spanned-fullscreen.patch
            # Reclaim dead GPU imports while outputs are off; remove when merged.
            # https://github.com/niri-wm/niri/pull/4550
            ./patches/niri-pr4550-idle-renderer-cleanup.patch
          ];
          postInstall = (oldAttrs.postInstall or "") + ''
            install -Dm0644 README.md resources/default-config.kdl -t $doc/share/doc/niri
            mv docs/wiki $doc/share/doc/niri/wiki
          '';
        });

      })
  ];
}
