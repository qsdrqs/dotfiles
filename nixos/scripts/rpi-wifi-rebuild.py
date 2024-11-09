#!/usr/bin/env python3
'''
Copyright (C) 2024 qsdrqs

Author: qsdrqs <qsdrqs@gmail.com>
All Right Reserved

This file try to rebuild rpi if wifi is down

'''

import sys
import subprocess
import os
import time

def check_and_rebuild(wifi_interface, nixos_config):
    # check if wifi is down
    # ip addr | grep <interface> | grep "DOWN"
    cmd = f"ip addr | grep {wifi_interface} | grep 'DOWN'"
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    down_out, down_err = p.communicate()
    cmd = f"ip addr | grep {wifi_interface} | grep 'UP'"
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    up_out, up_err = p.communicate()
    if down_err:
        print(down_err)
        exit(1)
    if up_err:
        print(up_err)
        exit(1)

    if up_out == b'' and down_out != b'':
        # if wifi is down, try to rebuild nixos
        print("Wifi is down, try to rebuild nixos")
        cwd = "/etc/nix/current-profile-source"
        cmd_pre = ["./install.sh", "nixpre"]
        subprocess.run(cmd_pre, cwd=cwd)
        # sudo nixos-rebuild switch --flake path:.#$@
        cmd_rebuild = ["nixos-rebuild", "switch", "--flake", f"path:.#{nixos_config}"]
        subprocess.run(cmd_rebuild, cwd=cwd)


def main():
    # check root
    if not os.geteuid() == 0:
        sys.exit('Script must be run as root')

    if len(sys.argv) != 3:
        sys.exit('Usage: python3 rpi-wifi-rebuild.py <wifi_interface> <nixos_config>')

    wifi_interface = sys.argv[1]
    nixos_config = sys.argv[2]

    while True:
        check_and_rebuild(wifi_interface, nixos_config)
        time.sleep(30)



if __name__ == '__main__':
    main()
