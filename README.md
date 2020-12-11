# macos_smb_reconnect
Bash script for MacOS automatically reopens pre-defined SMB mounts 
Replace pre-defined drives with SMB share name (run "ls /Volumes" to list mounted SMB names)
I recommend scheduling this with "crontab -e" to run on a schedule of your choosing. My drives get constant use so I run this every 15 minutes. 
