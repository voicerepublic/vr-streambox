#!/bin/sh

set -e

VERSION=$((`cat VERSION`+1))

echo $VERSION > VERSION

git commit -m "bump version to $VERSION" VERSION
