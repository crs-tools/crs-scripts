#!/bin/bash

#$1 Dateiname
#$2 Orndername/Profilname
echo "$1"
echo "$2"

#variablen definieren
#zwspeicher="/mnt/raid/release"
#mirror="/mnt/raid/mirror"
#xxc3="29C3"
xxc3=$3
zwspeicher=$4
mirror=$5
torrenttime=$6

#zum zwischenspeicherverzeichnis wechseln
cd $zwspeicher

#sha1 summe zur datei erstellen
sha1sum -b "$1" >> "$1".sha1

#torrent zur datei erstellen mit mehreren trackern und webseed
mktorrent -a http://v6.torrent.speedpartner.de:6969/announce -a http://v4.torrent.speedpartner.de:6969/announce -a http://tracker.ccc.de:80/announce,udp://tracker.ccc.de:80/announce -a http://tracker.publicbt.com:80/announce,udp://tracker.publicbt.com:80/announce -a http://tracker.openbittorrent.com:80/announce,udp://tracker.openbittorrent.com:80/announce -a http://tracker.birkenwald.de:6969/announce -a http://tracker.istole.it:80/announce,udp://tracker.istole.it:80/announce -w http://mirror.fem-net.de/CCC/"$xxc3"/"$2"/"$1" -l 19 "$1" -o "$1".torrent

#dateinamen und hashwert des torrents in die passende datei schreiben
echo "# $1" >> "$zwspeicher"/tracker/"$xxc3".txt
transmission-show "$1".torrent | awk '/Hash/ {print $2}' >> "$zwspeicher"/tracker/"$xxc3".txt

#endgültiges spiegelverzeichnis erstellen
mkdir -p "$mirror"/"$xxc3"/"$2"

#sha1 torrent vom zwischenspeicher zum spiegelverzeichnis verschieben
mv "$zwspeicher"/"$1".sha1 "$mirror"/"$xxc3"/"$2"/
mv "$zwspeicher"/"$1".torrent "$mirror"/"$xxc3"/"$2"/

#status des torrents auf fertig setzen
echo "$1" >> "$zwspeicher"/torrent.txt


#warten auf torrenttime und datei verschieben
sleep $torrenttime;
mv "$zwspeicher"/"$1" "$mirror"/"$xxc3"/"$2"/

#status der datei auf fertig setzen
echo "$1" >> "$zwspeicher"/released.txt

