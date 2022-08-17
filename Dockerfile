
ARG KAFKA_VERSION=3.2.1
ARG SCALA_VERSION=2.13
ARG REVISION=unspecified
ARG BUILD_DATE=unspecified

#
# Download and unpack kafka
#
FROM debian:bookworm-slim AS builder

# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG KAFKA_VERSION \
    SCALA_VERSION \
    REVISION \
    BUILD_DATE

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
    SCALA_VERSION \
    REVISION \
    BUILD_DATE

# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.authors="tidexenso" \
    org.opencontainers.image.url="https://github.com/tidexenso/kafka-kraft" \
    org.opencontainers.image.documentation="https://github.com/tidexenso/kafka-kraft/blob/main/README.md" \
    org.opencontainers.image.source="https://github.com/tidexenso/kafka-kraft" \
    org.opencontainers.image.version="${SCALA_VERSION}-${KAFKA_VERSION}" \
    org.opencontainers.image.revision="${REVISION}" \
    org.opencontainers.image.vendor="tidexenso" \
    org.opencontainers.image.licenses="Apache License 2.0" \
    org.opencontainers.image.title="tidexenso/kafka-kraft" \
    org.opencontainers.image.description="Apache Kafka KRaft Mode"

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
