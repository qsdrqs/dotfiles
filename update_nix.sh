#!/usr/bin/env bash
pwd=$(pwd)
cd nvim/flake && nix flake update
cd $pwd
cd zsh && nix flake update
cd $pwd
nix flake update
