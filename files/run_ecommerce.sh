#!/bin/bash

## To create with security disabled remove -u username:password to curl commands

HOST='localhost'
PORT=9200
INDEX_NAME='ufw_logs'
LOG_FILE='ufw.log'
URL="http://${HOST}:${PORT}"
USERNAME=elastic
PASSWORD=changeme

printf "\n== Script for creating index and uploading data == \n \n"

tar -xzf ecommerce.tgz
sed -i 's|2019-08|2020-02|' ecommerce.log

#printf "\n== Deleting old index == \n\n"
#curl -s -u ${USERNAME}:${PASSWORD} -X DELETE ${URL}/${INDEX_NAME}

printf "\n== Creating Index - ${INDEX_NAME} == \n\n"
curl -s  -u ${USERNAME}:${PASSWORD} -X PUT -H 'Content-Type: application/json' ${URL}/${INDEX_NAME} -d '{  
  "settings":{  
      "number_of_shards":1,
      "number_of_replicas":0,
      "default_pipeline" : "ufw_logs-pipeline"
  },
  "mappings": {
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "action": {
          "type": "keyword"
        },
        "destination_ip": {
          "type": "ip"
        },
        "destination_port": {
          "type": "long"
        },
        "in": {
          "type": "keyword"
        },
        "logsource": {
          "type": "keyword"
        },
        "mac": {
          "type": "keyword"
        },
        "message": {
          "type": "text"
        },
        "out": {
          "type": "keyword"
        },
        "program": {
          "type": "keyword"
        },
        "protocol": {
          "type": "keyword"
        },
        "source_ip": {
          "type": "ip"
        },
        "source_port": {
          "type": "long"
        },
        "geoip": {
          "properties": {
            "location": { "type": "geo_point" }
          }
        }        
      }
    }
  }
}'

# curl -s  -u ${USERNAME}:${PASSWORD} -X PUT -H 'Content-Type: application/json' ${URL}/
curl -X PUT "localhost:9200/_ingest/pipeline/${INDEX_NAME}-pipeline?pretty" -H 'Content-Type: application/json' -d'
{
  "description" : "ufw_logs pipeline",
  "processors" : [
  {
    "grok": {
      "field": "message",
      "patterns": [
        "%{SYSLOGBASE} \\[%{DATA}\\] \\[%{DATA:action}\\] IN=(%{WORD:in})? OUT=(%{WORD:out})?( MAC=%{DATA:mac})? SRC=%{IP:source_ip} DST=%{IP:destination_ip} %{DATA} PROTO=%{WORD:protocol}( SPT=%{INT:source_port} DPT=%{INT:destination_port})?"
      ]
    }
  },
  {
    "date": {
      "field": "timestamp",
      "timezone": "America/Sao_Paulo",
      "formats": [
        "MMM dd HH:mm:ss",
        "MMM  d HH:mm:ss",
        "MMM d HH:mm:ss"
      ]
    }
  },
  {
    "remove": {
      "field": "timestamp"
    }
  },
  {
    "geoip": {
      "field": "source_ip"
    }
  }
  ]
}'

printf "\n\n== Check upload \n"
curl -s -u ${USERNAME}:${PASSWORD} -X GET ${URL}/_cat/indices/${INDEX_NAME}?v

printf "\n Log uploaded \n "
