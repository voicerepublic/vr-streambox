#!/bin/bash

mkdir -p ../recordings

sox -q -t alsa $DEVICE ../recordings/recording_`date +%s`_%4n.ogg \
    silence 1 1.0 5% 1 10.0 5% : newfile : restart >record.log 2>&1

#sox -t alsa $DEVICE ../recordings/recording_`date +%s`_%4n.ogg \
#    silence 1 1.0 5% 1 10.0 5% : newfile : restart
