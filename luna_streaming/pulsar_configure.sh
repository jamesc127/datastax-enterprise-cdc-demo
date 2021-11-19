# !/usr/bin/env bash

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

start_config() {
  echo "Starting Luna Streaming Configuration"
  set -x
  set -o pipefail
  trap error ERR
}

error() {
  echo "Error Configuring Luna Streaming"
  exit 1
}

pulsar_configure() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP namespaces set-auto-topic-creation public/default --enable
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP namespaces set-is-allow-auto-update-schema public/default --enable
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP namespaces set-retention public/default --size -1 --time -1
}

# The connector must be deployed when the keyspace exists
deploy_csc_meteorite() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP source create \
    --name cassandra-source-db1-meteorite \
    --archive https://github.com/jamesc127/source-pulsar/raw/main/pulsar-cassandra-source-1.0.0.nar \
    --tenant public \
    --namespace default \
    --destination-topic-name data-db1.meteorite \
    --parallelism 1 \
    --source-config "{
      \"keyspace\": \"db1\",
      \"table\": \"meteorite\",
      \"events.topic\": \"persistent://public/default/events-db1.meteorite\",
      \"events.subscription.name\": \"meteorite\",
      \"contactPoints\": \"$CASSANDRA_SERVICE\",
      \"loadBalancing.localDc\": \"$CASSANDRA_DC\",
      \"auth.provider\": \"PLAIN\",
      \"auth.username\": \"$USERNAME\",
      \"auth.password\": \"$PASSWORD\"
    }"
}

deploy_csc_starbucks() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP source create \
    --name cassandra-source-db1-starbucks \
    --archive https://github.com/jamesc127/source-pulsar/raw/main/pulsar-cassandra-source-1.0.0.nar \
    --tenant public \
    --namespace default \
    --destination-topic-name data-db1.starbucks \
    --parallelism 1 \
    --source-config "{
      \"keyspace\": \"db1\",
      \"table\": \"starbucks\",
      \"events.topic\": \"persistent://public/default/events-db1.starbucks\",
      \"events.subscription.name\": \"starbucks\",
      \"contactPoints\": \"$CASSANDRA_SERVICE\",
      \"loadBalancing.localDc\": \"$CASSANDRA_DC\",
      \"auth.provider\": \"PLAIN\",
      \"auth.username\": \"$USERNAME\",
      \"auth.password\": \"$PASSWORD\"
    }"
}

deploy_es_sink_starbucks() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP sink create \
    --sink-type elastic_search \
    --tenant public \
    --namespace default \
    --name elasticsearch-sink-db1-starbucks \
    --inputs persistent://public/default/data-db1.starbucks \
    --subs-position Earliest \
    --sink-config "{
      \"elasticSearchUrl\":\"$ELASTICSEARCH_URL\",
      \"indexName\":\"db1.starbucks\",
      \"keyIgnore\":\"false\",
      \"nullValueAction\":\"DELETE\",
      \"schemaEnable\":\"true\"
    }"
}

deploy_es_sink_meteorite() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP sink create \
    --sink-type elastic_search \
    --tenant public \
    --namespace default \
    --name elasticsearch-sink-db1-meteorite \
    --inputs persistent://public/default/data-db1.meteorite \
    --subs-position Earliest \
    --sink-config "{
      \"elasticSearchUrl\":\"$ELASTICSEARCH_URL\",
      \"indexName\":\"db1.meteorite\",
      \"keyIgnore\":\"false\",
      \"nullValueAction\":\"DELETE\",
      \"schemaEnable\":\"true\"
    }"
}

create_es_index_starbucks() {
  curl -XPUT $ELASTICSEARCH_URL/db1.starbucks?include_type_name=true \
    -H 'Content-Type: application/json' \
    -d '{
            "mappings": {
              "_doc" : {
                "properties": {
                  "@timestamp": {
                    "type": "alias",
                    "path": "locdate"
                  },
                  "lon": {
                    "type": "text",
                    "fields": {
                      "keyword": {
                        "type": "keyword",
                        "ignore_above": 256
                      }
                    }
                  },
                  "store_num": {
                    "type": "integer"
                  },
                  "lat": {
                    "type": "text",
                    "fields": {
                      "keyword": {
                        "type": "keyword",
                        "ignore_above": 256
                      }
                    }
                  },
                  "address": {
                    "type": "text",
                    "fields": {
                      "keyword": {
                        "type": "keyword",
                        "ignore_above": 256
                      }
                    }
                  },
                  "description": {
                    "type": "text",
                    "fields": {
                      "keyword": {
                        "type": "keyword",
                        "ignore_above": 256
                      }
                    }
                  },
                  "locdate": {
                    "type": "date",
                    "format":"yyyy-MM-dd"
                  },
                  "geolocation": {
                    "type": "geo_point"
                  }
                }
              }
            }
          }'
}

create_es_index_meteorite() {
  curl -XPUT $ELASTICSEARCH_URL/db1.meteorite?include_type_name=true \
    -H 'Content-Type: application/json' \
    -d '{
            "mappings": {
              "_doc" : {
                "properties": {
                  "@timestamp": {
                    "type": "alias",
                    "path": "finddate"
                  },
                  "fall": {
                    "type": "text",
                    "fields": {
                      "keyword": {
                        "type": "keyword",
                        "ignore_above": 256
                      }
                    }
                  },
                  "mass": {
                    "type": "float"
                  },
                  "name": {
                    "type": "text",
                    "fields": {
                      "keyword": {
                        "type": "keyword",
                        "ignore_above": 256
                      }
                    }
                  },
                  "nametype": {
                    "type": "text",
                    "fields": {
                      "keyword": {
                        "type": "keyword",
                        "ignore_above": 256
                      }
                    }
                  },
                  "recclass": {
                    "type": "text",
                    "fields": {
                      "keyword": {
                        "type": "keyword",
                        "ignore_above": 256
                      }
                    }
                  },
                  "finddate": {
                    "type": "date",
                    "format":"yyyy-MM-dd"
                  },
                  "geolocation": {
                    "type": "geo_point"
                  }
                }
              }
            }
          }'
}

start_config
pulsar_configure
deploy_csc_meteorite
create_es_index_meteorite
sleep 5
deploy_es_sink_meteorite
exit 0
