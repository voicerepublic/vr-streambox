#!/bin/bash

mkdir -p ../recordings

inotifywait -d -e create --outfile ../recordings/creation-times.log --format "%w%f | %T" --timefmt "%s | %FT%T%z" ../recordings
