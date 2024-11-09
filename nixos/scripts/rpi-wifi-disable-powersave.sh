#!/bin/sh
while [ 1 ]; do
    iw dev $1 set power_save off
    sleep 300
done
