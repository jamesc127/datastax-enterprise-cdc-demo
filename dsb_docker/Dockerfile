FROM ubuntu:21.04
COPY ./nyc_collisions_test.csv /dsbulk/bin/nyc_collisions_test.csv
COPY ./dsbulk dsbulk
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /dsbulk/bin
CMD /dsbulk/bin/dsbulk load -k db1 -t nyc_collisions -url ./nyc_collisions_test.csv -h cdc-test-dc1-service.default.svc.cluster.local \
    --connector.csv.ignoreLeadingWhitespaces true --connector.csv.ignoreTrailingWhitespaces true -p $CASS_PASSWORD -u $CASS_USERNAME
