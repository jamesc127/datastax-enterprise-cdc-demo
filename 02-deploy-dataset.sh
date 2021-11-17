#!/bin/bash

start_deploy() {
  echo "### Beginning Cassandra Dataset deployment"
  set -x
  set -o pipefail
  trap error ERR
}

error() {
  echo "Error in deploying Cassandra Dataset"
  exit 1
}

start_deploy
kubectl apply -f ./dsb_docker/dsbulk.yaml
kubectl wait --for=condition=Complete=true job/dsbulk-load-meteorite-data
exit 0
