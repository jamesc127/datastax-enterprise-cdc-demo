FROM ubuntu:21.04
COPY ./IMDb_movies.csv /dsbulk/bin/IMDb_movies.csv
COPY ./dsbulk dsbulk
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /dsbulk/bin
CMD /dsbulk/bin/dsbulk load -k db1 -t imdb_movies -url ./IMDb_movies.csv -h cdc-test-dc1-service.default.svc.cluster.local \
    --connector.csv.ignoreLeadingWhitespaces true --connector.csv.ignoreTrailingWhitespaces true \
    -maxErrors -1 -p $CASS_PASSWORD -u $CASS_USERNAME
