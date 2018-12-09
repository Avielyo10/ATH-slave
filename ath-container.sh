#!/usr/bin/env bash
# https://disconnected.systems/blog/another-bash-strict-mode/
set -euo pipefail
trap 's=$?; echo "$0: Error $s on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

uid=10001
gid=10000
tag="jenkins/ath"

docker build --rm --build-arg=uid="$uid" --build-arg=gid="$gid" . -t "$tag"

docker run -ti -P --rm -u ath-user -v /var/run/docker.sock:/var/run/docker.sock \
 -v ${HOME}/.m2/repository:/home/ath-user/.m2/repository "$tag" 