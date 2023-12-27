#!/usr/bin/env python3
# -*- coding: utf-8 -*-
'''
Copyright (C) 2023

Author: qsdrqs <qsdrqs@gmail.com>
All Right Reserved

This file can auto control fan to start

'''

from gpiozero import CPUTemperature, DigitalOutputDevice
import time
import sys

low = int(sys.argv[1])
high = int(sys.argv[2])

if __name__ == '__main__':
    fan = DigitalOutputDevice(14)

    while True:
        cputemp = CPUTemperature().value * 100
        if cputemp > high:
            fan.on()
        elif cputemp > low:
            pass
        else:
            fan.off()
        print("current temp: ", cputemp)
        time.sleep(3)

