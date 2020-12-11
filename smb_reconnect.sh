#!/bin/bash
network_drives=('drive_1' 'drive_2' 'drive_3')
for drive in "${network_drives[@]}"
do
    open 'smb://username:password@server/$drive'
done
