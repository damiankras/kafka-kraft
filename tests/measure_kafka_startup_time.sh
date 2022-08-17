#!/bin/bash

START_TIMESTAMP=$(python3 time.py)

IMAGE=$(docker run -it --rm -d -p 9092:9092 -e KAFKA_CREATE_TOPICS="test-topic:1:1" kafka-kraft)

until $(kafkacat -L -b localhost:9092 -t test-topic &>/dev/null); do
    echo "Could't connect to Kafka"
    sleep 0.01s
done

END_TIMESTAMP=$(python3 time.py)
DIFF=$(($END_TIMESTAMP - $START_TIMESTAMP))

echo "Kafka start with usable topic took $DIFF miliseconds"
docker stop $IMAGE
