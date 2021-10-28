#!/bin/bash

start_deploy() {
  echo "### Beginning GKE Deployment"
  set -x
  set -o pipefail
  trap error ERR
}

end_deploy() {
  set +e
  trap - ERR
}

error() {
  echo "Error in deploying GKE cluster"
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

start_deploy
add_helm_repos
sleep 1
deploy_dse
sleep 5
deploy_elk
sleep 5
deploy_luna_streaming
end_deploy
