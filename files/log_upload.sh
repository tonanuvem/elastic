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
printf "\n== Deleting old index == \n\n"
curl -s -u ${USERNAME}:${PASSWORD} -X DELETE ${URL}/${INDEX_NAME}

printf "\n== Creating Index - ${INDEX_NAME} == \n\n"
curl -s  -u ${USERNAME}:${PASSWORD} -X PUT -H 'Content-Type: application/json' ${URL}/${INDEX_NAME} -d '{  
  "settings":{  
      "number_of_shards":1,
      "number_of_replicas":0
  },
  "mappings": {
    "_doc": {
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
        "geoip": {
          "properties": {
            "city_name": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "continent_name": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "country_iso_code": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "country_name": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "location": {
              "type": "geo_point"
            },
            "region_iso_code": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            },
            "region_name": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            }
          }
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


curl -s -u ${USERNAME}:${PASSWORD} -X POST -H "Content-Type: application/json" ${URL}/${INDEX_NAME}/ --data-binary ${LOG_FILE} > /dev/null

#printf "\n== Bulk uploading data to index... \n"
#for i in `seq 1 20`;
#do
#    curl -s -u ${USERNAME}:${PASSWORD} -X POST -H "Content-Type: application/json" ${URL}/${INDEX_NAME}/_bulk --data-binary "@server-metrics_${i}.json" > /dev/null
#    printf "\nServer-metrics_${i} uploaded"
#done

#printf "\n done - output to /dev/null"

printf "\n\n== Check upload \n"
curl -s -u ${USERNAME}:${PASSWORD} -X GET ${URL}/_cat/indices/${INDEX_NAME}?v

printf "\n Log uploaded \n "
