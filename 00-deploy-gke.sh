#!/bin/bash
PROJECT_NAME=$1
K8S_CLUSTER_NAME=$2
GCP_ZONE=$3

create_k8s_cluster(){
  gcloud beta container --project "$PROJECT_NAME" clusters create "$K8S_CLUSTER_NAME" --zone "$GCP_ZONE" --no-enable-basic-auth \
  --cluster-version "1.19.16-gke.6100" --release-channel "None" --machine-type "e2-standard-8" --image-type "COS_CONTAINERD" \
  --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true \
  --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
  --max-pods-per-node "110" --num-nodes "3" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias \
  --network "projects/$PROJECT_NAME/global/networks/default" --subnetwork "projects/$PROJECT_NAME/regions/us-central1/subnetworks/default" \
  --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes
#  --node-locations "$GCP_ZONE"
}

authenticate_kubectl(){
  gcloud config set project $PROJECT_NAME
  gcloud container clusters get-credentials $K8S_CLUSTER_NAME --zone $GCP_ZONE --project $PROJECT_NAME
}

start_deploy() {
  echo "### Beginning GKE Deployment"
  set -x
  set -o pipefail
  trap error ERR
}

error() {
  echo "Error in deploying GKE cluster"
  exit 1
}

start_deploy
create_k8s_cluster
authenticate_kubectl
exit 0
