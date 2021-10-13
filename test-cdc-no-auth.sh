#!/usr/bin/env bash

set -x

USERNAME="cdc-test-superuser"
PASSWORD="T2Rmp9oQANutJrSSam9HFPkAnOm1DmiLvnZWNk5Zl4hjCVXCM7Pe5Q"
CASSANDRA_SERVICE="cdc-test-dc1-service.default.svc.cluster.local"
CASSANDRA_DC="dc1"

PULSAR_TOKEN="ZXlKaGJHY2lPaUpTVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnpkV0lpT2lKaFpHMXBiaUo5Lkd5Uk81OXR6SjZhaDczQlkyT0hOTnNua25CN0tIcFFudXRDSmxIdFJ6TC1kdFB0ak1Ya2hFSU5uQ1ctdy1aQzZqejFUbXZFNzNTSndTWFNWUlFHRHpGbGdOcjV0elJtRHpGTW1XQ3liVGh1cjdUVm1lUW9lbDl1MEdRU19WWW8yTkg5ZmFSall3NlFRbVRsWnVvMkUxTUp6clBwRHlsQ0JlZTE1dzBoaEFJTXRhZUJYMnEtTjlraFB0alNaYXFVbnFSR1NYb1ZpQlVBUi1NU3JxTkxtYmdwYVg4d2x4eHRMZWs2TllQNjRuaTNYbXo0d2p1UW81WnVGZ1UxQjVFcGNuUml6LWt3dy1QY254QzNxdDdnX3k5c2pnZGRmZXA5bnNQUzRCYTlqWGtmX1I1OERVMmxjQkNvYXlfSHZWekxxZkZvSFZ0WnZJNE4wMmlkcHU3eDJYQQ=="
PULSAR_ADMIN="./pulsar-admin"

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

deploy_csc_nyc() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP source create \
    --archive  https://github.com/jamesc127/source-pulsar/raw/main/source-pulsar-0.2.2.nar \
    --tenant public \
    --namespace default \
    --name cassandra-source-db1-nyc-collisions \
    --destination-topic-name data-db1.nyc-collisions \
    --source-config "{
      \"keyspace\": \"db1\",
      \"table\": \"nyc-collisions\",
      \"events.topic\": \"persistent://public/default/events-db1.nyc-collisions\",
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
    --name elasticsearch-sink-db1-nyc-collisions \
    --inputs persistent://public/default/data-db1.nyc-collisions \
    --subs-position Earliest \
    --sink-config "{
      \"elasticSearchUrl\":\"$ELASTICSEARCH_URL\",
      \"indexName\":\"db1.nyc-collisions\",
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
