#!/bin/bash

start_deploy() {
  echo "### Beginning Cassandra and Pulsar Configuration"
  set -x
  set -o pipefail
  trap error ERR
}

end_deploy() {
  set +e
  trap - ERR
}

error() {
  echo "Error in deploying Cassandra and Pulsar Configuration"
  exit 1
}

create_cassandra_table(){
  kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e \
  "CREATE TABLE IF NOT EXISTS db1.meteorite (
  name text,
  id text PRIMARY KEY,
  nametype text,
  recclass text,
  mass float,
  fall text,
  finddate text,
  geolocation text,
  ) WITH cdc=true;"
}

configure_luna_streaming(){
  kubectl cp ./luna_streaming/pulsar_configure.sh $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}'):/pulsar/bin/pulsar_configure.sh
  kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- chmod +x /pulsar/bin/pulsar_configure.sh
  kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- bash /pulsar/bin/pulsar_configure.sh $CASSANDRA_PASS
}

start_deploy
CASSANDRA_PASS=$(kubectl get secret cdc-test-superuser -o json | jq -r '.data.password' | base64 --decode)
kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e "CREATE KEYSPACE IF NOT EXISTS db1 WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1':3};"
sleep 3
create_cassandra_table
sleep 2
configure_luna_streaming
sleep 3
kubectl apply -f ./dsb_docker/dsbulk.yaml
end_deploy
