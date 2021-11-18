# DataStax Enterprise & Luna Streaming CDC Demo
## TL;DR
- This demo is intended to demonstrate [CDC for Apache Cassandra](https://www.datastax.com/cdc-apache-cassandra)
- End to end, this will deploy a GKE Cluster, DSE Cluster, Pulsar Cluster, Elasticsearch, and Kibana
- Data will be automatically loaded into the DSE cluster and sent via Pulsar & CDC to an Elasticsearch index
- This demo takes about 30-40 minutes to deploy on GKE if your local environment is stable
## Prerequsites
- GCP account 
- Permissions to a GCP Project where GKE clusters can be deployed (e.g. `gcp-data-architects-dev`)
- gcloud sdk
    - ensure gcloud is at the latest version
    - [Configure Cluster Access for kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl)
- kubectl
- helm
- awk
- jq
## Setup
- Clone the repo and provide execute permissions to the four shell scripts via something like `chmod +x`
- Ensure your local machine has all the above prerequisites 
- Run the shell scripts in order (00-02) to deploy the environment and load data
- Script 00 takes three arguments to deploy the GKE cluster
  - Your GCP project name (where you have permissions to deploy a GKE cluster)
  - The name you want to give your GKE cluster (like `my-name-dse-cdc-test`)
  - The GCP region you want to deploy your cluster in (e.g. `us-central1-c`)
## Conduct the Demo
- The GKE [Services & Ingress](https://console.cloud.google.com/kubernetes/discovery) page has links for your UI's
  - Kibana
  - Grafana
  - Pulsar Admin Console
  - DSE Studio
- Use the UI's to demonstrate data movement from DSE to Elasticsearch
## DSE Studio
You will need to create a DS Studio notebook and new connection to visualize data in your DSE cluster. 
Use the following for connection details. 
You'll need to run a few `kubectl` commands to get the DSE password.
```shell
Host = cdc-test-dc1-service.default.svc.cluster.local
User Name = cdc-test-superuser
CASSANDRA_PASS=$(kubectl get secret cdc-test-superuser -o json | jq -r '.data.password' | base64 --decode)
echo $CASSANDRA_PASS
```
## Tear Down
- Run script 03 with the same three arguments to tear down your GKE cluster
  - Your GCP project name (where you have rights to deploy a GKE cluster)
  - The name you want to give your GKE cluster (like `dse-cdc-test`)
  - The GCP region you want to deploy your cluster in (e.g. `us-central1-c`)
