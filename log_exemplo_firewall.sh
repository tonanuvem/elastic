#!/bin/bash

# ============================================================
# log_exemplo_firewall.sh
#
# Configura e importa exemplo_firewall.log no Elasticsearch.
#
# Fluxo:
#
#   1. Aguarda Elasticsearch
#   2. Aguarda Kibana
#   3. Cria Ingest Pipeline
#   4. Cria Index + Mapping
#   5. Importa os logs usando Bulk API
#   6. Cria Data View no Kibana
#
# Elasticsearch/Kibana:
#   7.12.1
#
# ============================================================

set -e

# ============================================================
# CONFIGURAÇÕES
# ============================================================

ES_CONTAINER="elasticsearch"
KIBANA_CONTAINER="kibana"

ES_URL="http://localhost:9200"
KIBANA_URL="http://localhost:5601"

INDEX_NAME="ufw_logs"
PIPELINE_NAME="ufw_logs_pipeline"

LOG_FILE="./files/exemplo_firewall.log"

BULK_FILE="/tmp/ufw_logs_bulk.ndjson"


# ============================================================
# INÍCIO
# ============================================================

echo ""
echo "============================================================"
echo "             IMPORTAÇÃO DOS LOGS DE FIREWALL"
echo "============================================================"
echo ""


# ============================================================
# VALIDAÇÕES
# ============================================================

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ Arquivo não encontrado:"
    echo ""
    echo "   $LOG_FILE"
    echo ""
    echo "Verifique se o arquivo está em:"
    echo ""
    echo "   ./files/exemplo_firewall.log"
    echo ""
    exit 1
fi


if ! docker ps --format '{{.Names}}' | grep -q "^${ES_CONTAINER}$"; then
    echo "❌ Container '$ES_CONTAINER' não está em execução."
    echo ""
    exit 1
fi


if ! docker ps --format '{{.Names}}' | grep -q "^${KIBANA_CONTAINER}$"; then
    echo "❌ Container '$KIBANA_CONTAINER' não está em execução."
    echo ""
    exit 1
fi


# ============================================================
# FUNÇÃO - CURL NO ELASTICSEARCH
# ============================================================

es_curl() {

    docker exec -i "$ES_CONTAINER" \
        curl -sS "$@"

}


# ============================================================
# AGUARDA ELASTICSEARCH
# ============================================================

echo "------------------------------------------------------------"
echo "Aguardando Elasticsearch..."
echo "------------------------------------------------------------"
echo ""

ES_READY=false

for i in $(seq 1 60); do

    if es_curl "${ES_URL}/_cluster/health" >/dev/null 2>&1; then

        ES_READY=true

        echo "✅ Elasticsearch disponível."
        echo ""

        break

    fi

    echo "   Tentativa $i/60..."

    sleep 2

done


if [ "$ES_READY" != "true" ]; then

    echo ""
    echo "❌ Elasticsearch não ficou disponível."
    echo ""

    exit 1

fi


# ============================================================
# AGUARDA KIBANA
# ============================================================

echo "------------------------------------------------------------"
echo "Aguardando Kibana..."
echo "------------------------------------------------------------"
echo ""

KIBANA_READY=false

for i in $(seq 1 60); do

    HTTP_CODE=$(curl -s \
        -o /dev/null \
        -w "%{http_code}" \
        --max-time 5 \
        "${KIBANA_URL}/api/status" || true)


    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then

        KIBANA_READY=true

        echo "✅ Kibana disponível."
        echo ""

        break

    fi

    echo "   Tentativa $i/60..."

    sleep 2

done


if [ "$KIBANA_READY" != "true" ]; then

    echo ""
    echo "❌ Kibana não ficou disponível."
    echo ""

    exit 1

fi


# ============================================================
# 1/5 - INGEST PIPELINE
# ============================================================

echo "------------------------------------------------------------"
echo "1/5 - Criando Ingest Pipeline"
echo "------------------------------------------------------------"
echo ""

PIPELINE_RESPONSE=$(docker exec -i "$ES_CONTAINER" \
    curl -sS \
    -X PUT \
    "${ES_URL}/_ingest/pipeline/${PIPELINE_NAME}" \
    -H "Content-Type: application/json" \
    -d @- <<'EOF'
{
  "description": "Ingest pipeline created by file structure finder",
  "processors": [
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
        "formats": [
          "MMM dd HH:mm:ss",
          "MMM d HH:mm:ss",
          "MMM  d HH:mm:ss"
        ]
      }
    },
    {
      "remove": {
        "field": "timestamp",
        "ignore_missing": true
      }
    },
    {
      "geoip": {
        "field": "source_ip",
        "ignore_missing": true
      }
    }
  ]
}
EOF
)


echo "$PIPELINE_RESPONSE" | python3 -m json.tool 2>/dev/null || \
    echo "$PIPELINE_RESPONSE"


if echo "$PIPELINE_RESPONSE" | grep -q '"acknowledged":true'; then

    echo ""
    echo "✅ Pipeline criado:"
    echo "   $PIPELINE_NAME"

else

    echo ""
    echo "❌ Erro ao criar o pipeline."
    exit 1

fi


# ============================================================
# 2/5 - MAPPING
# ============================================================

echo ""
echo "------------------------------------------------------------"
echo "2/5 - Preparando Mapping"
echo "------------------------------------------------------------"
echo ""

MAPPING_JSON='
{
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
        "location": {
          "type": "geo_point"
        }
      }
    }
  }
}
'


echo "✅ Mapping preparado."


# ============================================================
# 3/5 - INDEX
# ============================================================

echo ""
echo "------------------------------------------------------------"
echo "3/5 - Criando Index"
echo "------------------------------------------------------------"
echo ""


# ------------------------------------------------------------
# Verifica se índice já existe
# ------------------------------------------------------------

INDEX_EXISTS=$(es_curl \
    -o /dev/null \
    -w "%{http_code}" \
    -X HEAD \
    "${ES_URL}/${INDEX_NAME}")


# ------------------------------------------------------------
# Se existir, remove
# ------------------------------------------------------------

if [ "$INDEX_EXISTS" = "200" ]; then

    echo "⚠️  Índice '$INDEX_NAME' já existe."
    echo "    Removendo para recriar..."
    echo ""

    DELETE_RESPONSE=$(es_curl \
        -X DELETE \
        "${ES_URL}/${INDEX_NAME}")


    echo "$DELETE_RESPONSE" | \
        python3 -m json.tool 2>/dev/null || \
        echo "$DELETE_RESPONSE"

    echo ""

fi


# ------------------------------------------------------------
# Cria índice
# ------------------------------------------------------------

INDEX_RESPONSE=$(echo "$MAPPING_JSON" | \
    docker exec -i "$ES_CONTAINER" \
    curl -sS \
    -X PUT \
    "${ES_URL}/${INDEX_NAME}" \
    -H "Content-Type: application/json" \
    -d @-)


echo "$INDEX_RESPONSE" | \
    python3 -m json.tool 2>/dev/null || \
    echo "$INDEX_RESPONSE"


if echo "$INDEX_RESPONSE" | grep -q '"acknowledged":true'; then

    echo ""
    echo "✅ Índice criado:"
    echo "   $INDEX_NAME"

else

    echo ""
    echo "❌ Erro ao criar o índice."
    exit 1

fi


# ============================================================
# 4/5 - IMPORTAÇÃO
# ============================================================

echo ""
echo "------------------------------------------------------------"
echo "4/5 - Importando exemplo_firewall.log"
echo "------------------------------------------------------------"
echo ""


TOTAL_LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')


echo "Arquivo:"
echo "   $LOG_FILE"
echo ""

echo "Linhas encontradas:"
echo "   $TOTAL_LINES"
echo ""


# ------------------------------------------------------------
# Gera arquivo NDJSON para Bulk API
# ------------------------------------------------------------

echo "Preparando Bulk API..."

python3 - "$LOG_FILE" > "$BULK_FILE" <<'PY'

import json
import sys

filename = sys.argv[1]

with open(
    filename,
    "r",
    encoding="utf-8",
    errors="replace"
) as f:

    for line in f:

        line = line.rstrip("\r\n")

        if not line.strip():
            continue

        print(
            json.dumps(
                {"index": {}},
                ensure_ascii=False
            )
        )

        print(
            json.dumps(
                {"message": line},
                ensure_ascii=False
            )
        )

PY


if [ ! -s "$BULK_FILE" ]; then

    echo ""
    echo "❌ Não foi possível gerar o arquivo Bulk."
    exit 1

fi


# ------------------------------------------------------------
# Copia Bulk para Elasticsearch
# ------------------------------------------------------------

docker cp \
    "$BULK_FILE" \
    "${ES_CONTAINER}:/tmp/ufw_logs_bulk.ndjson"


# ------------------------------------------------------------
# Executa Bulk API
# ------------------------------------------------------------

echo "Enviando documentos para Elasticsearch..."
echo ""


BULK_RESPONSE=$(docker exec "$ES_CONTAINER" \
    curl -sS \
    -X POST \
    "${ES_URL}/${INDEX_NAME}/_bulk?pipeline=${PIPELINE_NAME}" \
    -H "Content-Type: application/x-ndjson" \
    --data-binary "@/tmp/ufw_logs_bulk.ndjson"
)


# ------------------------------------------------------------
# Exibe resposta
# ------------------------------------------------------------

echo "$BULK_RESPONSE" | \
    python3 -m json.tool 2>/dev/null || \
    echo "$BULK_RESPONSE"


# ------------------------------------------------------------
# Verifica erros
# ------------------------------------------------------------

ERRORS=$(echo "$BULK_RESPONSE" | python3 -c '

import json
import sys

try:

    data = json.load(sys.stdin)

    print(
        "true"
        if data.get("errors")
        else "false"
    )

except Exception:

    print("unknown")

')


if [ "$ERRORS" = "true" ]; then

    echo ""
    echo "❌ O Elasticsearch retornou erros durante a importação."
    echo ""

    exit 1

fi


echo ""
echo "✅ Logs importados com sucesso."


# ------------------------------------------------------------
# Consulta quantidade de documentos
# ------------------------------------------------------------

echo ""
echo "Consultando quantidade de documentos..."


COUNT_RESPONSE=$(es_curl \
    "${ES_URL}/${INDEX_NAME}/_count")


COUNT=$(echo "$COUNT_RESPONSE" | \
    python3 -c '
import json
import sys

try:
    print(json.load(sys.stdin)["count"])
except:
    print("0")
')


echo ""
echo "📊 Documentos no índice: $COUNT"


# ============================================================
# 5/5 - DATA VIEW
# ============================================================

echo ""
echo "------------------------------------------------------------"
echo "5/5 - Criando Data View no Kibana"
echo "------------------------------------------------------------"
echo ""


DATA_VIEW_RESPONSE=$(curl -sS \
    -X POST \
    "${KIBANA_URL}/api/saved_objects/index-pattern/${INDEX_NAME}?overwrite=true" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d "{
      \"attributes\": {
        \"title\": \"${INDEX_NAME}\",
        \"timeFieldName\": \"@timestamp\"
      }
    }"
)


echo "$DATA_VIEW_RESPONSE" | \
    python3 -m json.tool 2>/dev/null || \
    echo "$DATA_VIEW_RESPONSE"


# ------------------------------------------------------------
# Verifica resultado
# ------------------------------------------------------------

if echo "$DATA_VIEW_RESPONSE" | \
    grep -q '"type":"index-pattern"'; then

    echo ""
    echo "✅ Data View criado:"
    echo "   $INDEX_NAME"

else

    echo ""
    echo "⚠️  Não foi possível confirmar a criação do Data View."
    echo "    Verifique a resposta do Kibana acima."

fi


# ============================================================
# LIMPEZA
# ============================================================

rm -f "$BULK_FILE"

docker exec "$ES_CONTAINER" \
    rm -f /tmp/ufw_logs_bulk.ndjson 2>/dev/null || true


# ============================================================
# FINAL
# ============================================================

echo ""
echo "============================================================"
echo "                 PROCESSO CONCLUÍDO"
echo "============================================================"
echo ""

echo "Pipeline:"
echo "   $PIPELINE_NAME"
echo ""

echo "Index:"
echo "   $INDEX_NAME"
echo ""

echo "Data View:"
echo "   $INDEX_NAME"
echo ""

echo "Documentos:"
echo "   $COUNT"
echo ""

echo "============================================================"
echo ""
