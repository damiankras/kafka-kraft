# kafka-kraft
[Apache Kafka](https://kafka.apache.org) in KRaft mode (without Zookeeper)

## Pre-Requisites

To build and run container
- docker

To run examples
- docker-compose installed https://docs.docker.com/compose/install/

## Build

To build image use docker-buildx.sh script.
It requires Scala and Kafka version to be provided,
look into https://kafka.apache.org/downloads for available combinations

Example:
```bash
SCALA_VERSION=2.13
KAFKA_VERSION=3.2.1
./docker-buildx.sh $SCALA_VERSION $KAFKA_VERSION
```

# Quick start

## docker

To start single instance (controller and broker) use command:

```bash
docker run -it --rm -p 9092:9092 tidexenso/kafka-kraft:latest
```

Remember to review console output with server setting.
In this mode CLUSTER_ID is randomized so each time you will get new single node cluster.

## single-node docker compose

To run single node cluster using docker compose from root directory of repository run command:

```bash
docker-compose -f examples/docker-compose-single.yaml up
```

Compose file contains [Kafka UI](https://github.com/provectus/kafka-ui) (web application - http://localhost:8080) which can be used to review cluster.

## multi-node docker compose

To run multi node cluster using docker compose from root directory of repository run command:

```bash
docker-compose -f examples/docker-compose-multi.yaml up
```

Compose file contains [Kafka UI](https://github.com/provectus/kafka-ui) (web application - http://localhost:8080) which can be used to review cluster.


## Kubernetes single-node sample

To run this example you need k8s and kubectl
```bash
kubectl apply -f examples/k8s-kafka-kraft-single.yaml
```

| service                    | type      | port             |
|:-                          |:-         |:-                |
| service/kafka-nodeport-svc | NodePort  | 30092:30092/TCP  |
| service/kafka-svc          | ClusterIP | 9092/TCP         |
| service/kafka-ui-svc       | NodePort  | 8080:30080/TCP   |

Deployment contains [Kafka UI](https://github.com/provectus/kafka-ui) (web application - http://localhost:8080) which is exposed as NodePort and can be used to review kafka cluster.

Kafka is exposed via NodePort service and can be reach from k8s worker node on port 30092.
> NOTE! </br>
> When using Docker Desktop or minikube kafka will be available on **localhost:30092**

# Configuration

Kafka broker by default is set to store **kafka logs (kafka data)**<sup>1)</sup> in `/data` directory of container which could be mounted as volume to make it persistent.

> IMPORTANT! </br>
> <sup>1)</sup> kafka logs are not a application logs. 
> In this meaining kafka log means data about stored in partitions related to topics

## Server properties configuration

Configuration of kafka `server.properies` is possible via environment variables.
To set or change any kafka property into server.properties combine `KAFKA_PROP_` prefix 
with uppercase name of property from `server.properies`.
Dots separtors (`.`) should be replaced with underscore (`_`).

Examples:
| property               | variable
|:-----------------------| :--------------------------------
| `node.id`              | `KAFKA_PROP_NODE_ID`
| `process.roles`        | `KAFKA_PROP_PROCESS_ROLES` 
| `advertised.listeners` | `KAFKA_PROP_ADVERTISED_LISTENERS`

## LOG4J properties configuration

Works same way as [**Server properties configuration**](#server-properties-configuration) but for `$KAFKA_HOME/config/log4j.properties` file.
Prefix `LOG4J_` is used to control log4j properties.

## Predefined environment variables

Predefined variables which should not be overriden
| variable          | description
| :---------------- | :-
| `SCALA_VERSION`   | contains version of scala used by kafka
| `KAFKA_VERSION`   | contains version of kafka installed
| `KAFKA_HOME`      | directory where kafka is installed
| `KAFKA_DATA`      | direcotry where kafka data will be sotred
changed

## Configuration environment variables

Variables which should be overriden to change configuration
| variable                                | description
| :------------------------               | :-
| `KAFKA_CLUSTER_ID`                      | See: [Kafka Kraft CLUSTER_ID](#kafka-kraft-cluster-id)
| `KAFKA_CREATE_TOPICS`                   | See: [Automatically create topics](#automatically-create-topics)
| `KAFKA_CREATE_TOPICS_BOOTSTRAP_SERVERS` | See: [Automatically create topics](#automatically-create-topics)
| `KAFKA_HEAP_OPTS`                       | allow to override KAFKA_HEAP_OPTS in `kafka-server-start.sh`
| `KAFKA_JMX_OPTS`                        | allow to set JMX options for [kafka debugging](https://stackoverflow.com/questions/36708384/how-to-enable-remote-jmx-on-kafka-brokers-for-jmxtool)
| `JMX_PORT`                              | allow to set JMX port for debugging and monitoring

## Kafka Kraft cluster id

`KAFKA_CLUSTER_ID` needs to be provided in multi-node configuration to build cluster. 
Kafka kraft idicate belonging of brokers and controller to cluster by this identifier,
so it need to be set on all brokers and controllers to the same value for them to belong to one cluster.

To generate unique cluster id command can be used:
```bash
docker run -it --rm tidexenso/kafka-kraft:latest /opt/kafka/bin/kafka-storage.sh random-uuid
```

## Automatically create topics

If you want to have kafka kraft automatically create topics in Kafka during creation, 
a `KAFKA_CREATE_TOPICS` environment variable can be defined.
There is possibility to set `KAFKA_CREATE_TOPICS_BOOTSTRAP_SERVERS` 
to point servers on which command should be performed, by default it is performed on `localhost:9092`.
(to see it in action review k8s example)

Syntax: `<topic_name>[:partition][:replicas][:cleanup.policy]`

Where:
- topic_name - (required) string : name of new topic
- partition - (optional) int > 0 : number of partitions
- replicas - (optional) int > 0 : replication factor
- cleanup.policy - (optional) : `compact` or (default) `delete`

Here is an example snippet from docker-compose.yml :

```yaml
  environment:
    KAFKA_CREATE_TOPICS_BOOTSTRAP_SERVERS: "localhost:9092"
    KAFKA_CREATE_TOPICS: "topic_1:1:3,topic_2:1:1:compact"
```

- `topic_1` will have 1 partition and 3 replicas
- `topic_2` will have 1 partition, 1 replica and a cleanup.policy set to compact. Also, see FAQ: [Topic compaction does not work in  wurstmeister/kafka-docker](https://github.com/wurstmeister/kafka-docker/wiki#topic-compaction-does-not-work) from where inspiration for topic creation script was taken.

If you wish to use multi-line YAML or some other delimiter between your topic definitions, override the default , separator by specifying the KAFKA_CREATE_TOPICS_SEPARATOR environment variable.


# Examples

### simple docker
```bash
docker run -it --rm -p 9092:9092 tidexenso/kafka-kraft:latest
```

### single-node docker compose
```bash
 docker-compose -f docker-compose-single.yaml up
```

### multi-node docker compose
```bash
 docker-compose -f docker-compose-multi.yaml up
```

### docker with persistance

```bash
VOLUME=$(docker volume create kafka_data)
CONTAINER=$(docker run -p 9092:9092 \
  -e KAFKA_CREATE_TOPICS="topic_1:3:1,topic_2:1:1:compact" \
  --mount source=kafka_data,destination=/data \
  -it --rm -d tidexenso/kafka-kraft:latest)

# Check if topics exist
kafkacat -L -b localhost:9092

docker rm -f $CONTAINER
docker volume rm -f $VOLUME
```
