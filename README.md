# datastax-enterprise-cdc-demo
## Prerequsites
- gcloud sdk
    - ensure gcloud is at the latest version
- kubectl
- helm
- awk
- jq
- [Configure Cluster Access for kubectl](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl)
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
[CDC Smoke Test Repo](https://github.com/riptano/dse-cdc-test)
TODO add back in the user name get
```shell
helm install -f cass-operator-values.yaml cass-operator datastax/cass-operator
kubectl apply -f deploy-cassandra.yaml
CASSANDRA_PASS=$(kubectl get secret cdc-test-superuser -o json | jq -r '.data.password' | base64 --decode)
echo $CASSANDRA_PASS
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
## Metricbeat
```shell
helm install metricbeat elastic/metricbeat
```

## Create Cassandra Schema
```shell
kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e "CREATE KEYSPACE IF NOT EXISTS db1 WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1':3};"
kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e "CREATE TABLE IF NOT EXISTS db1.table1 (key text PRIMARY KEY, c1 text) WITH cdc=true;"
```
```shell
kubectl exec cdc-test-dc1-rack1-sts-0 -- cqlsh -u cdc-test-superuser -p $CASSANDRA_PASS -e \
"CREATE TABLE IF NOT EXISTS db1.nyc_collisions (\
crash_date text,\
crash_time text,\
borough text,\
zip int,\
latitude double,\
longitude double,\
location text,\
on_street_name text,\
cross_street_name text,\
off_street_name text,\
persons_injured int,\
persons_killed int,\
pedestrians_injured int,\
pedestrians_killed int,\
cyclist_injured int,\
cyclist_killed int,\
motorist_injured int,\
motorist_killed int,\
contributing_factor_vehicle_1 text,\
contributing_factor_vehicle_2 text,\
contributing_factor_vehicle_3 text,\
contributing_factor_vehicle_4 text,\
contributing_factor_vehicle_5 text,\
collision_id text PRIMARY KEY,\
vehicle_type_code_1 text,\
vehicle_type_code_2 text,\
vehicle_type_code_3 text,\
vehicle_type_code_4 text,\
vehicle_type_code_5 text) WITH cdc=true;"
```
## Luna Streaming
[Helm Chart](https://docs.datastax.com/en/luna/streaming/2.7/quickstart-helm-installs.html)
```shell
helm install pulsar -f pulsar-values-auth-gcp.yaml datastax-pulsar/pulsar
```
## Run Luna Streaming Config Script
```shell
kubectl cp ./pulsar_configure.sh $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}'):/pulsar/bin/pulsar_configure.sh
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- chmod +x /pulsar/bin/pulsar_configure.sh
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- bash /pulsar/bin/pulsar_configure.sh $CASSANDRA_PASS
```
## DSE Studio
```shell
kubectl apply -f studio-deployment.yaml
```
TODO can I automatically define a connection, username, and password? Doesn't seem to be a good way to get the username and password into the studio deployment yet.

`CASSANDRA_SERVICE=cdc-test-dc1-service.default.svc.cluster.local`

`USERNAME=cdc-test-superuser`

## Run NoSQLBench test
```shell
kubectl apply -f nb.yaml
```
## Validate Elasticsearch Entries
```shell
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- curl "http://elasticsearch-master.default.svc.cluster.local:9200/db1.table1/_doc/381691746?pretty"
kubectl exec $(kubectl get pods | grep "pulsar-bastion-*" | awk '{print $1}') -- curl "http://elasticsearch-master.default.svc.cluster.local:9200/db1.table1/_search?pretty&size=0"
```
## Load NYC Collision Dataset
TODO set up k8s job to use DSBulk and load csv dataset

TODO set up a kibana dashboard

## Distroy Env
```bash
kubectl delete cassandradatacenter dc1
helm delete pulsar elasticsearch cass-operator kibana metricbeat
kubectl delete -f nb.yaml
kubectl delete -f studio-deployment.yaml
kubectl delete -f kibana-loadbalancer.yaml
```
