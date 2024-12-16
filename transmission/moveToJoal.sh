#!/bin/bash

TORRENTFILE=/config/torrents/"$TR_TORRENT_HASH".torrent
RESUMEFILE=/config/resume/"$TR_TORRENT_HASH".resume
echo "Starting to move torrent with filename $TORRENTFILE to joal" >> /tmp/transmission-to-joal.log
mv "$TORRENTFILE" /joal/torrents
rm -rf "$RESUMEFILE"
echo "Torrent moved to joal" >> /tmp/transmission-to-joal.log
