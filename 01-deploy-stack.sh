#!/bin/bash

start_deploy() {
  echo "### Beginning Stack Deployment"
  set -x
  set -o pipefail
  trap error ERR
}

error() {
  echo "Error in deploying Stack"
  exit 1
}

add_helm_repos(){
  helm repo add datastax https://datastax.github.io/charts
  helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart
  helm repo add elastic https://helm.elastic.co
  helm repo update
}

deploy_dse(){
  helm install -f ./datastax_enterprise/cass-operator-values.yaml cass-operator datastax/cass-operator
  sleep 5
  kubectl apply -f ./datastax_enterprise/deploy-cassandra.yaml
  kubectl apply -f ./datastax_enterprise/studio-deployment.yaml
}

deploy_elk(){
  helm install elasticsearch elastic/elasticsearch -f ./elk/elastic-values-gcp.yaml
  helm install kibana elastic/kibana
  kubectl apply -f ./elk/kibana-loadbalancer.yaml
}

deploy_luna_streaming(){
  helm install pulsar -f ./luna_streaming/pulsar-values-auth-gcp.yaml datastax-pulsar/pulsar
}

create_cassandra_table_meteorite(){
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

create_cassandra_table_starbucks(){
  kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e \
  "CREATE TABLE IF NOT EXISTS db1.starbucks (
  store_num int PRIMARY KEY,
  lon text,
  lat text,
  geolocation text,
  description text,
  address text,
  locdate text,
  ) WITH cdc=true;"
}

configure_luna_streaming(){
  kubectl cp ./luna_streaming/pulsar_configure.sh $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}'):/pulsar/bin/pulsar_configure.sh
  kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- chmod +x /pulsar/bin/pulsar_configure.sh
  kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- bash /pulsar/bin/pulsar_configure.sh $CASSANDRA_PASS
}

create_cassandra_keyspace(){
  CASSANDRA_PASS=$(kubectl get secret cdc-test-superuser -o json | jq -r '.data.password' | base64 --decode)
  until kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e "CREATE KEYSPACE IF NOT EXISTS db1 WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1':3};"
  do
   CASSANDRA_PASS=$(kubectl get secret cdc-test-superuser -o json | jq -r '.data.password' | base64 --decode)
   echo "Waiting for all DataStax Enterprise nodes to become available"
   sleep 10
  done
}

start_deploy
add_helm_repos
sleep 1
deploy_dse
sleep 5
deploy_elk
sleep 5
deploy_luna_streaming
kubectl wait --for=condition=available --timeout=600s --all deployments
sleep 60
create_cassandra_keyspace
create_cassandra_table_meteorite
sleep 2
configure_luna_streaming
exit 0
