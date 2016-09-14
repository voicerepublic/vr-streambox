#!/bin/bash

mkdir -p ../recordings

sox --buffer 100000 -q -t alsa $DEVICE ../recordings/recording_`date +%s`_%4n.ogg \
    silence 1 1.0 5% 1 10.0 5% : newfile : restart >record.sh.log 2>&1
