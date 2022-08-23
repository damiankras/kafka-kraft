#!/bin/bash

#
# usage
# setProperty "listeners" "${KAFKA_LISTENERS}" "${KAFKA_SERVER_CONFIG_FILE}"
#
function setProperty() {
    local key=$1
    local value=$2
    local filename=$3
    if ! grep -R "^[#]*\s*${key}=.*" $filename > /dev/null; then
        # echo "APPENDING because '${key}' not found"
        echo "${key}=${value}" >> $filename
    else
        # echo "SETTING because '${key}' found already"
        sed -ir "s#^[\#]*\s*${key}=.*#${key}=${value}#" $filename
    fi
}

# Store original IFS config, so we can restore it at various stages
ORIG_IFS=$IFS

#
# Create topics in background 
#
${KAFKA_HOME}/kraft-create-topics.sh &
unset KAFKA_CREATE_TOPICS

#
# Setup server.properties
#
KAFKA_SERVER_CONFIG_FILE=${KAFKA_HOME}/config/kraft/server.properties

if [[ -z "$KAFKA_PROP_LOG_DIRS" ]]; then
    export KAFKA_PROP_LOG_DIRS="/data/kraft-logs"
fi

if [[ -z "$KAFKA_PROP_LOG_DIR" ]]; then
    export KAFKA_PROP_LOG_DIR="${KAFKA_PROP_LOG_DIRS}"
fi

if [[ -n "$KAFKA_HEAP_OPTS" ]]; then
    sed -r -i 's/(export KAFKA_HEAP_OPTS)="(.*)"/\1="'"$KAFKA_HEAP_OPTS"'"/g' "$KAFKA_HOME/bin/kafka-server-start.sh"
    unset KAFKA_HEAP_OPTS
fi

#Issue newline to config file in case there is not one already
echo "" >> ${KAFKA_SERVER_CONFIG_FILE}

for VAR in $(env)
do
    env_var=$(echo "$VAR" | cut -d= -f1)

    if [[ $env_var =~ ^KAFKA_PROP_ ]]; then
        property_name=$(echo "$env_var" | cut -d_ -f3- | tr '[:upper:]' '[:lower:]' | tr _ .)
        setProperty "$property_name" "${!env_var}" "${KAFKA_SERVER_CONFIG_FILE}"
    fi

    if [[ $env_var =~ ^LOG4J_ ]]; then
        property_name=$(echo "$env_var" | tr '[:upper:]' '[:lower:]' | tr _ .)
        setProperty "$property_name" "${!env_var}" "$KAFKA_HOME/config/log4j.properties"
    fi
done

#
# Setup kraft cluster 
#
if [[ -z "$KAFKA_CLUSTER_ID" ]]; then
    KAFKA_CLUSTER_ID=$(/opt/kafka/bin/kafka-storage.sh random-uuid)
    export KAFKA_CLUSTER_ID
fi
/opt/kafka/bin/kafka-storage.sh format -t ${KAFKA_CLUSTER_ID} -c ${KAFKA_SERVER_CONFIG_FILE}

echo "Starting Kafka"
# First one runs in background
exec /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
