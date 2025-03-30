#!/usr/bin/env python3
'''
Copyright (C) 2024 qsdrqs

Author: qsdrqs <qsdrqs@gmail.com>
All Right Reserved

This file try to rebuild rpi if ethernet is down

'''

import sys
import subprocess
import os
import time

def check_and_rebuild(eth_interface, ip_addr_prefix):
    # check if eth is down
    # ip addr | grep <interface> | grep "DOWN"
    cmd = f"ip addr show {eth_interface}"
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = p.communicate()
    if err:
        print(err)
        exit(1)

    if out.find(ip_addr_prefix.encode()) == -1:
        # if eth is down, try to restart eth
        print("eth is down, try to restart eth")
        cmd = f'ip link set {eth_interface} down'
        p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = p.communicate()
        if p.returncode != 0:
            print("failed to set down eth")
            print(err)
        cmd = f'ip link set {eth_interface} up'
        p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = p.communicate()
        if p.returncode != 0:
            print("failed to set up eth")
            print(err)


def main():
    # check root
    if not os.geteuid() == 0:
        sys.exit('Script must be run as root')

    if len(sys.argv) != 3:
        sys.exit('Usage: python3 rpi-eth-rebuild.py <eth_interface> <ip_addr_prefix>')

    eth_interface = sys.argv[1]
    ip_addr_prefix = sys.argv[2]

    while True:
        check_and_rebuild(eth_interface, ip_addr_prefix)
        time.sleep(30)



if __name__ == '__main__':
    main()
