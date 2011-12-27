#!/bin/bash

mv /mnt/data/release/"$1" /mnt/data/release/torrent/.
cd /mnt/data/release/torrent/
sha1sum -b "$1" >> "$1".sha1

mktorrent -a http://v6.torrent.speedpartner.de:6969/announce -a http://v4.torrent.speedpartner.de:6969/announce -a http://tracker.publicbt.com:80/announce,udp://tracker.publicbt.com:80/announce -a http://tracker.openbittorrent.com:80/announce,udp://tracker.openbittorrent.com:80/announce -a http://tracker.birkenwald.de:6969/announce -a http://tracker.torrent.to:2710/announce -a http://exodus.1337x.org/announce -w http://mirror.fem-net.de/CCC/28C3/"$2"/"$1" -l 19 "$1" -o "$1".torrent

ln /mnt/data/release/torrent/"$1".sha1 /mnt/data/mirror/28C3/"$2"/"$1".sha1
ln /mnt/data/release/torrent/"$1".torrent /mnt/data/mirror/28C3/"$2"/"$1".torrent
echo "# $1" >> /mnt/data/release/tracker/28c3.txt
transmission-show "$1".torrent | awk '/Hash/ {print $2}' >> /mnt/data/release/tracker/28c3.txt
lftp -f /dev/stdin <<EOF
set cmd:fail-exit true;
open sftp://upload;
put "$1".torrent;
put "$1".sha1;
mkdir -p        /srv/ftp/congress/2011/"$2";
mv "$1".torrent /srv/ftp/congress/2011/"$2"/;
mv "$1".sha1    /srv/ftp/congress/2011/"$2"/;
EOF
echo "$1" >> /mnt/data/release/torrent.txt

sleep 6h
mkdir -p /mnt/data/mirror/28C3/"$2"
ln /mnt/data/release/torrent/"$1" /mnt/data/mirror/28C3/"$2"/"$1"

sleep 15m
lftp -f /dev/stdin <<EOF
set cmd:fail-exit true;
open sftp://upload;
put "$1";
mkdir -p /srv/ftp/congress/2011/"$2";
mv "$1"  /srv/ftp/congress/2011/"$2"/;
EOF

#sftp -P 2222 -i /home/ecki/sshkey_ecki_ftp.ccc.de fem@212.201.68.160
#/srv/ftp/congress/2011

echo "$1" >> /mnt/data/release/released.txt
