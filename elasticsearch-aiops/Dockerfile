# The upstream image was built by:
#   https://github.com/elastic/dockerfiles/tree/v7.12.1/elasticsearch

FROM elasticsearch:7.12.1

WORKDIR /usr/share/elasticsearch

RUN mkdir aiops
WORKDIR /usr/share/elasticsearch/aiops

ADD https://download.elastic.co/demos/machine_learning/gettingstarted/server_metrics.tar.gz .
RUN tar -zxvf server_metrics.tar.gz

RUN chmod +x /usr/share/elasticsearch/aiops/files/upload_server_metrics.sh
RUN /usr/share/elasticsearch/aiops/files/upload_server_metrics.sh
