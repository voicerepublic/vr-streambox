#!/bin/sh

set -x

pwd

echo "Initial launch..."

launchtool -t streambox -u root -g root -Lnvc ./update_and_start.sh
