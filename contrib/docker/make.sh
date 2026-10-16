#!/bin/sh
set -e

DEFAULT_TAG=v9.8.0-r1
TAG=${1:-${TAG:-$DEFAULT_TAG}}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

out=tjhei/candi:$TAG-ubuntu-24.04
echo "building $out from candi ref $TAG"
docker build \
  --file "$SCRIPT_DIR/Dockerfile" \
  --build-arg "TAG=$TAG" \
  --tag "$out" \
  "$SCRIPT_DIR"
docker run --rm \
  --volume "$SCRIPT_DIR/check.sh:/tmp/check.sh:ro" \
  --entrypoint /bin/sh \
  "$out" /tmp/check.sh
echo "built $out"
