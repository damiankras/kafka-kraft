#!/bin/bash

if [[ -z "$KAFKA_CREATE_TOPICS" ]]; then
    exit 0
fi

if [[ -z "$START_TIMEOUT" ]]; then
    START_TIMEOUT=1000
fi

if [[ -z "$KAFKA_CREATE_TOPICS_BOOTSTRAP_SERVERS" ]]; then
    KAFKA_CREATE_TOPICS_BOOTSTRAP_SERVERS="localhost:9092"
fi

arrIN=(${KAFKA_CREATE_TOPICS_BOOTSTRAP_SERVERS//,/ })
arrIN=${arrIN[0]}
arrIN=(${arrIN//:/ })

# get first server to be able to wait for it using nc
KAFKA_HOST=${arrIN[0]}
KAFKA_PORT=${arrIN[1]}

start_timeout_exceeded=false
count=0
step=10
while ! nc -z $KAFKA_HOST $KAFKA_PORT; do
    echo "waiting for kafka to be ready"
    sleep $step;
    count=$((count + step))
    if [ $count -gt $START_TIMEOUT ]; then
        start_timeout_exceeded=true
        break
    fi
done

if $start_timeout_exceeded; then
    echo "Not able to auto-create topic (waited for $START_TIMEOUT sec)"
    exit 1
fi

# Expected format:
#   name[:partitions][:replicas][:cleanup.policy]
IFS="${KAFKA_CREATE_TOPICS_SEPARATOR-,}"; for topicToCreate in $KAFKA_CREATE_TOPICS; do
    echo "creating topics: $topicToCreate"
    IFS=':' read -r -a topicConfig <<< "$topicToCreate"
    
    partitions=
    if [ -n "${topicConfig[1]}" ]; then
        partitions="--partitions ${topicConfig[1]}"
    fi

    replication_factor=
    if [ -n "${topicConfig[2]}" ]; then
        replication_factor="--replication-factor ${topicConfig[2]}"
    fi
    
    config=
    if [ -n "${topicConfig[3]}" ]; then
        config="--config=cleanup.policy=${topicConfig[3]}"
    fi

    COMMAND="JMX_PORT='' ${KAFKA_HOME}/bin/kafka-topics.sh \\
		--bootstrap-server '${KAFKA_CREATE_TOPICS_BOOTSTRAP_SERVERS}' \\
        --create \\
		--topic ${topicConfig[0]} \\
		${partitions} \\
		${replication_factor} \\
		${config} \\
		--if-not-exists &"
    eval "${COMMAND}"
done

wait
