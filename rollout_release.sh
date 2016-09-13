#!/bin/sh

VERSION=`cat VERSION`

CMD="echo $VERSION > app/shared/public/versions/streamboxx"

echo $CMD

ssh -o ClearAllForwardings=yes vrl '$CMD'

echo -n 'Released '

curl https://voicerepublic.com/versions/streamboxx
