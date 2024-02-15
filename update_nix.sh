#!/usr/bin/env bash
pwd=$(pwd)
cd nvim && nix flake update
cd $pwd
cd zsh && nix flake update
cd $pwd
cd ranger && nix flake update
cd $pwd
nix flake update
