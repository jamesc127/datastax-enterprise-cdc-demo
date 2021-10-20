# datastax-enterprise-cdc-demo
## Prerequsites
- gcloud sdk
    - ensure gcloud is at the latest version
- kubectl
- helm
- awk
- jq
- [Configure Cluster Access for kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl)
## TL;DR
- This demo takes about 30-40 minutes to deploy on GKE if you're sure your local environment is stable
## TODO
- can we do this without metricbeats?
## k8s Cluster
TODO add info here
## gcloud
Set your `gcloud` instance to whichever project you have acccess to deploy a k8s cluster into. This should be all you need to do to get `kubectl` access to your k8s cluster in GKE.
```shell
gcloud config set project YOUR_PROJECT_NAME
gcloud container clusters get-credentials YOUR_CLUSTER_NAME --zone YOUR_REGION --project YOUR_PROJECT_NAME
```
## Add Helm Repos
```shell
helm repo add datastax https://datastax.github.io/charts
helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart
helm repo add elastic https://helm.elastic.co
helm repo update
```
## DataStax Enterprise
- [CDC Smoke Test Repo](https://github.com/riptano/dse-cdc-test)
```shell
helm install -f cass-operator-values.yaml cass-operator datastax/cass-operator
kubectl apply -f deploy-cassandra.yaml
```
## Elasticsearch
```shell
helm install elasticsearch elastic/elasticsearch -f elastic-values-gcp.yaml
```
## Kibana
```shell
helm install kibana elastic/kibana
kubectl apply -f kibana-loadbalancer.yaml
```
## Luna Streaming
[Helm Chart](https://docs.datastax.com/en/luna/streaming/2.7/quickstart-helm-installs.html)
```shell
helm install pulsar -f pulsar-values-auth-gcp.yaml datastax-pulsar/pulsar
```
## DSE Studio
```shell
kubectl apply -f studio-deployment.yaml
```
TODO can I automatically define a connection, username, and password? Doesn't seem to be a good way to get the username and password into the studio deployment yet.

`CASSANDRA_SERVICE=cdc-test-dc1-service.default.svc.cluster.local`

`USERNAME=cdc-test-superuser`
## Create Cassandra Schema
Ensure that the DataStax Enterprise cluster is fully up and running before proceeding. Sometimes you may get a `Bad Credentials` error if the cluster has just come up. Just try the commands again.
```shell
CASSANDRA_PASS=$(kubectl get secret cdc-test-superuser -o json | jq -r '.data.password' | base64 --decode)
echo $CASSANDRA_PASS
kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e "CREATE KEYSPACE IF NOT EXISTS db1 WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1':3};"
kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e "CREATE TABLE IF NOT EXISTS db1.table1 (key text PRIMARY KEY, c1 text) WITH cdc=true;"
```
```shell
kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e \
"CREATE TABLE IF NOT EXISTS db1.meteorite (
name text,
id text PRIMARY KEY,
nametype text,
recclass text,
mass float,
fall text,
year int,
geolocation text,
) WITH cdc=true;"
```
## Run Luna Streaming Config Script
```shell
kubectl cp ./pulsar_configure.sh $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}'):/pulsar/bin/pulsar_configure.sh
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- chmod +x /pulsar/bin/pulsar_configure.sh
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- bash /pulsar/bin/pulsar_configure.sh $CASSANDRA_PASS
```
## Run NoSQLBench Initial Data Load
This k8s job will load 100 records into `table1`, which will be persisted in DSE and CDC'd to Elasticsearch.
```shell
kubectl apply -f nb.yaml
```
## Validate Elasticsearch Entries
```shell
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- curl "http://elasticsearch-master.default.svc.cluster.local:9200/db1.table1/_doc/381691746?pretty"
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- curl "http://elasticsearch-master.default.svc.cluster.local:9200/db1.table1/_search?pretty&size=0"
```
## Load IMDB Movie Dataset
```shell
kubectl apply -f dsbulk.yaml
```

TODO set up a kibana dashboard
## Validate Elasticsearch Entries
```shell
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- curl "http://elasticsearch-master.default.svc.cluster.local:9200/db1.imdb_movies/_search?pretty&size=0"
```
## Distroy Env
```bash
kubectl delete cassandradatacenter dc1
helm delete pulsar elasticsearch cass-operator kibana
kubectl delete -f nb.yaml
kubectl delete -f dsbulk.yaml
kubectl delete -f studio-deployment.yaml
kubectl delete -f kibana-loadbalancer.yaml
```
