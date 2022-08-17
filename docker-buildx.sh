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

REGISTRY=tidexenso
REVISION=$(git log --format="%h" -n 1)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build for amd64 and arm64
# PLATFORMS="linux/amd64,linux/arm64"
PLATFORMS="linux/amd64"

docker buildx build \
    --platform "${PLATFORMS}" \
    --progress=plain \
    --build-arg KAFKA_VERSION=$KAFKA_VERSION \
    --build-arg SCALA_VERSION=$SCALA_VERSION \
    --build-arg REVISION=$REVISION \
    --build-arg BUILD_DATE=$BUILD_DATE \
    -t $REGISTRY/kafka-kraft:$TAG \
    -f Dockerfile .

docker tag $REGISTRY/kafka-kraft:$TAG $REGISTRY/kafka-kraft:latest
