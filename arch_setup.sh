#!/bin/bash

brew install macfuse
brew install ext4fuse

DISK_NUM="2"
DISK="disk$DISK_NUM"

sudo diskutil unmountDisk /dev/disk2
sudo dd if=/dev/zero of=/dev/rdisk2 bs=1m count=8
diskutil partitionDisk /dev/disk2 MBR FAT32 BOOT 100M FAT32 ROOT R
sudo diskutil unmountDisk /dev/disk2
sudo /usr/local/opt/e2fsprogs/sbin/mkfs.ext4 /dev/disk2s2
sudo /usr/local/opt/ext4fuse/bin/ext4fuse /dev/disk2s2 /Volumes/ROOT -o allow_other

sudo tar -xpvf image.tar.gz -C /Volumes/ROOT
