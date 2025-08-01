#!/usr/bin/env bash
pwd=$(pwd)
cd nvim && nix flake update
cd $pwd
cd zsh && nix flake update
cd $pwd
cd ranger && nix flake update
cd $pwd
python3 $pwd/nixos/scripts/update-nixpkgs-last.py $pwd/flake.nix $pwd/flake.lock
python3 $pwd/nvim/dump_input.py
nix flake update
