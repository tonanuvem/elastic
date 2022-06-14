FROM elasticsearch:7.12.1

WORKDIR /usr/share/elasticsearch

RUN mkdir aiops

WORKDIR /usr/share/elasticsearch/aiops

ADD https://download.elastic.co/demos/machine_learning/gettingstarted/server_metrics.tar.gz .

RUN upload_server_metrics.sh
