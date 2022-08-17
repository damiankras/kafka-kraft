#!/bin/bash

if [[ -z "$1" ]]; then
    echo "Missing required parameter SCALA_VERSION"
    exit 1;
fi

if [[ -z "$2" ]]; then
    echo "Missing required parameter KAFKA_VERSION"
    exit 1;
fi

SCALA_VERSION="$1"
KAFKA_VERSION="$2"

TAG="${SCALA_VERSION}-${KAFKA_VERSION}"

echo "TAG : $TAG"

# Build for amd64 and arm64
# PLATFORMS="linux/amd64,linux/arm64"
PLATFORMS="linux/amd64"

docker buildx build \
    --platform "${PLATFORMS}" \
    --progress=plain \
    --build-arg KAFKA_VERSION=$KAFKA_VERSION \
    --build-arg SCALA_VERSION=$SCALA_VERSION \
    --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    -t kafka-kraft:$TAG \
    -f Dockerfile .