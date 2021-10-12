FROM nosqlbench/nosqlbench:latest
COPY ./cql-cdc-test.yaml cql-cdc-test.yaml
ENTRYPOINT [ "/usr/bin/env" ]
CMD java -jar /nb.jar run driver=cql workload=cql-cdc-test.yaml tags=phase:main cycles=100 threads=1 host=cdc-test-dc1-service.default.svc.cluster.local username=cdc-test-superuser password=$CASS_PASSWORD
