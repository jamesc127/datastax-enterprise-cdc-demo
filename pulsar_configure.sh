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
    --archive  https://github.com/jamesc127/source-pulsar/raw/main/pulsar-cassandra-source-0.2.7-SNAPSHOT.nar \
    --tenant public \
    --namespace default \
    --name cassandra-source-db1-table1 \
    --destination-topic-name data-db1.table1 \
    --source-config "{
      \"keyspace\": \"db1\",
      \"table\": \"table1\",
      \"events.topic\": \"persistent://public/default/events-db1.table1\",
      \"events.subscription.name\": \"sub1\",
      \"key.converter\": \"com.datastax.oss.pulsar.source.converters.NativeAvroConverter\",
      \"value.converter\": \"com.datastax.oss.pulsar.source.converters.NativeAvroConverter\",
      \"contactPoints\": \"$CASSANDRA_SERVICE\",
      \"loadBalancing.localDc\": \"$CASSANDRA_DC\",
      \"auth.provider\": \"PLAIN\",
      \"auth.username\": \"$USERNAME\",
      \"auth.password\": \"$PASSWORD\"
    }"
}

deploy_csc_meteorite() {
  $PULSAR_ADMIN --admin-url $PULSAR_BROKER_HTTP source create \
    --archive  https://github.com/jamesc127/source-pulsar/raw/main/pulsar-cassandra-source-0.2.7-SNAPSHOT.nar \
    --tenant public \
    --namespace default \
    --name cassandra-source-db1-meteorite \
    --destination-topic-name data-db1.meteorite \
    --source-config "{
      \"keyspace\": \"db1\",
      \"table\": \"meteorite\",
      \"events.topic\": \"persistent://public/default/events-db1.meteorite\",
      \"events.subscription.name\": \"meteorite\",
      \"key.converter\": \"com.datastax.oss.pulsar.source.converters.NativeAvroConverter\",
      \"value.converter\": \"com.datastax.oss.pulsar.source.converters.NativeAvroConverter\",
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

create_es_index_movies() {
  curl -XPUT $ELASTICSEARCH_URL/db1.imdb_movies/ \
  -H 'Content-Type: application/json' \
  -d '
  {
  "settings": {
  "analysis": {
  "filter": {
  "autocomplete_filter": {
  "type": "edge_ngram",
  "min_gram": 1,
  "max_gram": 20
  }
  },
  "analyzer": {
  "autocomplete": {
  "type": "custom",
  "tokenizer": "standard",
  "filter": [
  "lowercase",
  "autocomplete_filter"
  ]
  }
  }
  }
  },
  "mappings": {
  "properties" : {

      "@timestamp" : {
            "type" : "date"
          },
          "@version" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "actors" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "avg_vote" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "budget" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "country" : {
            "type" : "text",
            "fields" : {
            "raw": {
            "type": "keyword"
            }
            }
          },
          "description" : {
            "type" : "text", "analyzer" : "english"
          },
          "director" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
         "duration" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "genre" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "host" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "language" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "message" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "path" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "production_company" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "reviews_from_critics" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "reviews_from_users" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "title" : {
            "type" : "text", "analyzer": "autocomplete"
          },
          "votes" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "writer" : {
            "type" : "text",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          },
          "year" : {
            "type" : "date",
            "fields" : {
              "keyword" : {
                "type" : "keyword",
                "ignore_above" : 256
              }
            }
          }



  }
  }
  }
  }'
}

create_es_index_meteorite() {
  curl -XPUT $ELASTICSEARCH_URL/db1.meteorite/ \
    -H 'Content-Type: application/json' \
    -d '{
            "mappings": {
                "properties": {
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
                  "year": {
                    "type": "long"
                  },
                  "geolocation": {
                    "type": "geo_point"
                  }
                }
              }
            }'
}

test_start

pulsar_configure

deploy_csc

deploy_csc_meteorite

deploy_es_sink

create_es_index_meteorite

sleep 5

deploy_es_sink_meteorite

test_end
