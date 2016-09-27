#!/bin/sh

echo "Syncing clock..."
service ntp stop
htpdate -s voicerepublic.com
service ntp start
