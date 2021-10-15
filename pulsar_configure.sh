#!/usr/bin/env bash

set -x

USERNAME="cdc-test-superuser"
PASSWORD=$1
CASSANDRA_SERVICE="cdc-test-dc1-service.default.svc.cluster.local"
CASSANDRA_DC="dc1"

PULSAR_ADMIN="/pulsar/bin/pulsar-admin"

PULSAR_BROKER="pulsar+ssl://pulsar-broker.default.svc.cluster.local:6651"
PULSAR_BROKER_HTTP="http://pulsar-broker.default.svc.cluster.local:8080"
PULSAR_ADMIN_AUTH="--auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params token:$PULSAR_TOKEN"

ELASTICSEARCH_URL="http://elasticsearch-master.default.svc.cluster.local:9200"

test_start() {
  echo "### Starting"
  set -x
  set -o pipefail
  trap error ERR
}

test_end() {
  set +e
  trap - ERR
}

error() {
  echo "ERROR occurs, test FAILED"
  exit 1
}

pulsar_configure() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP namespaces set-auto-topic-creation public/default --enable
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP namespaces set-is-allow-auto-update-schema public/default --enable
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP namespaces set-retention public/default --size -1 --time -1
}

# The connector must be deployed when the keyspace exists
deploy_csc() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP source create \
    --archive  https://github.com/jamesc127/source-pulsar/raw/main/source-pulsar-0.2.2.nar \
    --tenant public \
    --namespace default \
    --name cassandra-source-db1-table1 \
    --destination-topic-name data-db1.table1 \
    --source-config "{
      \"keyspace\": \"db1\",
      \"table\": \"table1\",
      \"events.topic\": \"persistent://public/default/events-db1.table1\",
      \"events.subscription.name\": \"sub1\",
      \"key.converter\": \"com.datastax.oss.pulsar.source.converters.AvroConverter\",
      \"value.converter\": \"com.datastax.oss.pulsar.source.converters.AvroConverter\",
      \"contactPoints\": \"$CASSANDRA_SERVICE\",
      \"loadBalancing.localDc\": \"$CASSANDRA_DC\",
      \"auth.provider\": \"PLAIN\",
      \"auth.username\": \"$USERNAME\",
      \"auth.password\": \"$PASSWORD\"
    }"
}

deploy_csc_nyc() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP source create \
    --archive  https://github.com/jamesc127/source-pulsar/raw/main/source-pulsar-0.2.2.nar \
    --tenant public \
    --namespace default \
    --name cassandra-source-db1-imdb_movies \
    --destination-topic-name data-db1.imdb_movies \
    --source-config "{
      \"keyspace\": \"db1\",
      \"table\": \"imdb_movies\",
      \"events.topic\": \"persistent://public/default/events-db1.imdb_movies\",
      \"events.subscription.name\": \"nyc1\",
      \"key.converter\": \"com.datastax.oss.pulsar.source.converters.AvroConverter\",
      \"value.converter\": \"com.datastax.oss.pulsar.source.converters.AvroConverter\",
      \"contactPoints\": \"$CASSANDRA_SERVICE\",
      \"loadBalancing.localDc\": \"$CASSANDRA_DC\",
      \"auth.provider\": \"PLAIN\",
      \"auth.username\": \"$USERNAME\",
      \"auth.password\": \"$PASSWORD\"
    }"
}

deploy_es_sink() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP sink create \
    --sink-type elastic_search \
    --tenant public \
    --namespace default \
    --name elasticsearch-sink-db1-table1 \
    --inputs persistent://public/default/data-db1.table1 \
    --subs-position Earliest \
    --sink-config "{
      \"elasticSearchUrl\":\"$ELASTICSEARCH_URL\",
      \"indexName\":\"db1.table1\",
      \"keyIgnore\":\"false\",
      \"nullValueAction\":\"DELETE\",
      \"schemaEnable\":\"true\"
    }"
}

deploy_es_sink_nyc() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP sink create \
    --sink-type elastic_search \
    --tenant public \
    --namespace default \
    --name elasticsearch-sink-db1-imdb_movies \
    --inputs persistent://public/default/data-db1.imdb_movies \
    --subs-position Earliest \
    --sink-config "{
      \"elasticSearchUrl\":\"$ELASTICSEARCH_URL\",
      \"indexName\":\"db1.imdb_movies\",
      \"keyIgnore\":\"false\",
      \"nullValueAction\":\"DELETE\",
      \"schemaEnable\":\"true\"
    }"
}

test_start

pulsar_configure

deploy_csc

deploy_csc_nyc

deploy_es_sink

deploy_es_sink_nyc

test_end
