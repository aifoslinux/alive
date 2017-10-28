#!/bin/bash

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: $0 (rootdir=<directory>)"
            exit 0;;
        rootdir=*)
            rootdir=${i#*=};;
    esac
done

install -v -Dm755 alive.sh $rootdir/bin/alive

install -v -Dm755 alive.cfg $rootdir/etc/alive.conf

install -v -Dm644 grub.cfg $rootdir/share/alive/grub.cfg
install -v -Dm644 isolinux.cfg $rootdir/share/alive/isolinux.cfg
install -v -m644 install.txt $rootdir/share/alive/install.txt
