FROM ubuntu:21.04
COPY ./meteorite-landings.csv /dsbulk/bin/meteorite-landings.csv
COPY ./dsbulk dsbulk
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /dsbulk/bin
CMD /dsbulk/bin/dsbulk load -k db1 -t meteorite -url ./meteorite-landings.csv -h cdc-test-dc1-service.default.svc.cluster.local \
    --connector.csv.ignoreLeadingWhitespaces true --connector.csv.ignoreTrailingWhitespaces true \
    -verbosity 2 -p $CASS_PASSWORD -u $CASS_USERNAME
