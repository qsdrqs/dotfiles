#!/usr/bin/env python3
'''
Copyright (C) 2024 qsdrqs

Author: qsdrqs <qsdrqs@gmail.com>
All Right Reserved

This file will save current nixpkgs commit to nixpkgs-last in flake.nix

'''
import sys
import json
import re

def main():
    if len(sys.argv) != 3:
        print("Usage: update-nixpkgs-last.py <flake.nix> <flake.lock>")
        sys.exit(1)

    flake_nix = sys.argv[1]
    flake_lock = sys.argv[2]

    with open(flake_lock, 'r') as f:
        flake_lock_data = json.load(f)
    cur_nixpkgs_rev = flake_lock_data['nodes']['nixpkgs']['locked']['rev']

    with open(flake_nix, 'r') as f:
        flake_nix_data = f.readlines()

    # find nixpkgs_last
    pattern = re.compile(r'^\s*nixpkgs-last.url = "github:NixOS/nixpkgs/([^"]+)";$')
    find = False
    for i in range(len(flake_nix_data)):
        # nixpkgs-last.url = "github:NixOS/nixpkgs/{rev}";
        if pattern.match(flake_nix_data[i]):
            old_rev = pattern.match(flake_nix_data[i]).group(1)
            flake_nix_data[i] = flake_nix_data[i].replace(old_rev, cur_nixpkgs_rev)
            find = True
            break
    if not find:
        exit("Error: Can't find nixpkgs-last in flake.nix")

    with open(flake_nix, 'w') as f:
        f.writelines(flake_nix_data)

if __name__ == '__main__':
    main()
