
ARG KAFKA_VERSION=3.2.1
ARG SCALA_VERSION=2.13

#
# Download and unpack kafka
#
FROM debian:bookworm-slim AS builder

# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG KAFKA_VERSION \
    SCALA_VERSION

ENV SCALA_VERSION=$SCALA_VERSION \
    KAFKA_VERSION=$KAFKA_VERSION \
    KAFKA_HOME=/opt/kafka \
    KAFKA_URL="https://dlcdn.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"

RUN apt-get update && apt-get install -y wget \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir ${KAFKA_HOME} \
    && wget ${KAFKA_URL} -O /tmp/kafka.tgz \
    && tar xvf /tmp/kafka.tgz --strip-components=1 -C ${KAFKA_HOME}

COPY src/kraft-bootstrap.sh ${KAFKA_HOME}
COPY src/kraft-create-topics.sh ${KAFKA_HOME}

RUN chmod +x ${KAFKA_HOME}/kraft-bootstrap.sh
RUN chmod +x ${KAFKA_HOME}/kraft-create-topics.sh

#
# Install minimal jre, setup kafka user
# 
FROM debian:bookworm-slim AS kafka-kraft

RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    netcat-openbsd \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG KAFKA_VERSION \
    SCALA_VERSION

LABEL org.label-schema.name="kafka-kraft" \
      org.label-schema.description="Apache Kafka KRaft Mode" \
      org.label-schema.version="${SCALA_VERSION}-${KAFKA_VERSION}" \
      org.label-schema.schema-version="1.0"

# VOLUME [ "/data" ]

ENV SCALA_VERSION=$SCALA_VERSION \
    KAFKA_VERSION=$KAFKA_VERSION \
    KAFKA_HOME=/opt/kafka \
    KAFKA_DATA=/data

ENV PATH=${PATH}:${KAFKA_HOME}/bin

RUN groupadd -r kafka \
    && useradd --no-log-init -r -d ${KAFKA_HOME} -u 1000 -g kafka kafka \
    && mkdir -p ${KAFKA_DATA} \
    && chown kafka.kafka ${KAFKA_DATA}

COPY --from=builder --chown=kafka:kafka ${KAFKA_HOME} ${KAFKA_HOME}

USER kafka:kafka
WORKDIR ${KAFKA_HOME}
EXPOSE 9092
EXPOSE 9093

# Use "exec" form so that it runs as PID 1 (useful for graceful shutdown)
CMD ["./kraft-bootstrap.sh"]
