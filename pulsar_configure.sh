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

source_list() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP source list
}

sink_list() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP sink list
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

csc_status() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP source status --name cassandra-source-db1-table1
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

es_sink_status() {
   $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP sink status --name elasticsearch-sink-db1-table1
}

es_refresh() {
  curl -XPOST "$ELASTICSEARCH_URL/db1.table1/_refresh"
}

es_total_hits() {
  TOTAL_HIT=$(curl "$ELASTICSEARCH_URL/db1.table1/_search?pretty&size=0" 2>/dev/null | jq '.hits.total.value')
  if [ "$TOTAL_HIT" != "${1}" ]; then
	     echo "### total_hit : unexpected total.hits = $TOTAL_HIT"
	     return 1
	fi
}

run_cqlsh() {
  cqlsh -u $USERNAME -p $PASSWORD -e "${1}"
}

cleanup_test() {
  curl -XDELETE "$ELASTICSEARCH_URL/db1.table1"
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP topics delete -d -f persistent://public/default/events-db1.table1
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP topics delete -d -f persistent://public/default/data-db1.table1
}

test_start

pulsar_configure

deploy_csc

deploy_es_sink

test_end