HOST='localhost'
PORT=9200
JOB_ID='scripted_response_request_partition-app'
INDEX_NAME='server-metrics'
ROOT="http://${HOST}:${PORT}/_xpack/ml"
JOBS="${ROOT}/anomaly_detectors"
DATAFEEDS="${ROOT}/datafeeds"
USERNAME=elastic
PASSWORD=changeme
printf "\n== Script started for... $JOBS/$JOB_ID"

printf "\n\n== Stopping datafeed... "
curl -s -u ${USERNAME}:${PASSWORD} -X POST ${DATAFEEDS}/datafeed-${JOB_ID}/_stop

printf "\n\n== Deleting datafeed... "
curl -s -u ${USERNAME}:${PASSWORD} -X DELETE ${DATAFEEDS}/datafeed-${JOB_ID}

printf "\n\n== Closing job... "
curl -s -u ${USERNAME}:${PASSWORD} -X POST ${JOBS}/${JOB_ID}/_close

printf "\n\n== Deleting job... "
curl -s -u ${USERNAME}:${PASSWORD} -X DELETE ${JOBS}/${JOB_ID}

printf "\n\n== Creating job... \n"
curl -s -u ${USERNAME}:${PASSWORD} -X PUT -H 'Content-Type: application/json' ${JOBS}/${JOB_ID}?pretty -d '{
    "description" : "Unusual service behaviour",
    "analysis_config" : {
        "bucket_span":"10m",
        "detectors" :[
          {
            "detector_description": "Unusual sum for each  service",
            "function": "sum",
            "field_name": "total",
            "partition_field_name": "service"
          },
          {
            "detector_description": "Unusually high response for each service",
            "function": "high_mean",
            "field_name": "response",
            "partition_field_name": "service"
          }
        ],
        "influencers": ["host"]
        },
        "data_description" : {
          "time_field":"@timestamp",
          "time_format": "epoch_ms"
    }
}'
printf "\n\n== Creating Datafeed... \n"
curl -s -u ${USERNAME}:${PASSWORD} -X PUT -H 'Content-Type: application/json' ${DATAFEEDS}/datafeed-${JOB_ID}?pretty -d '{
      "job_id" : "'"$JOB_ID"'",
      "indexes" : [
        "'"$INDEX_NAME"'"
      ],
      "types" : [
        "metric"
      ],
      "scroll_size" : 1000
}'
printf "\n\n== Opening job for ${JOB_ID}... "
curl -u ${USERNAME}:${PASSWORD} -X POST ${JOBS}/${JOB_ID}/_open

printf "\n\n== Starting datafeed-${JOB_ID}... "
curl -u ${USERNAME}:${PASSWORD} -X POST "${DATAFEEDS}/datafeed-${JOB_ID}/_start?start=1970-01-02T10:00:00Z&end=2017-06-01T00:00:00Z"

sleep 20s

printf "\n\n== Stopping datafeed-${JOB_ID}... "
curl -u ${USERNAME}:${PASSWORD} -X POST "${DATAFEEDS}/datafeed-${JOB_ID}/_stop"

printf "\n\n== Closing job for ${JOB_ID}... "
curl -u ${USERNAME}:${PASSWORD} -X POST ${JOBS}/${JOB_ID}/_close

printf "\n\n== Finished ==\n\n"
