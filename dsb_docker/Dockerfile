FROM alpine:3.13.6
COPY ./nyc_collisions_test.csv nyc_collisions_test.csv
COPY ./dsbulk dsbulk
ENTRYPOINT [ "/usr/bin/env" ]
CMD ./dsbulk/bin/dsbulk load -k db1 -t nyc_collisions -url /nyc_collisions_test.csv -h cdc-test-dc1-service.default.svc.cluster.local --connector.csv.ignoreLeadingWhitespaces true --connector.csv.ignoreTrailingWhitespaces true 
