#!/usr/bin/env bash
# https://disconnected.systems/blog/another-bash-strict-mode/
set -euo pipefail
trap 's=$?; echo "$0: Error $s on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

tag="jenkins/ath"

docker build --rm . -t "$tag"

docker run -ti -P --rm -u ath-user -v /var/run/docker.sock:/var/run/docker.sock \
 -v ${HOME}/.m2/repository:/home/ath-user/.m2/repository "$tag" 