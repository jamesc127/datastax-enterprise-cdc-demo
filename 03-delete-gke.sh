#!/bin/bash
PROJECT_NAME=$1
K8S_CLUSTER_NAME=$2
GCP_ZONE=$3

gcloud beta container --project "$PROJECT_NAME" clusters delete "$K8S_CLUSTER_NAME" --zone "$GCP_ZONE"
