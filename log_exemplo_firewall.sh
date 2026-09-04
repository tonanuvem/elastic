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
#   7. Importa o Dashboard no Kibana
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
LOG_ZIP="./files/exemplo_firewall.zip"

# Dashboard (tambem vem dentro do zip, no formato legado _id/_type/_source)
DASHBOARD_FILE="./files/dashboard.json"
DASHBOARD_NDJSON="/tmp/ufw_dashboard.ndjson"

BULK_FILE="/tmp/ufw_logs_bulk.ndjson"

# Quantidade de documentos por lote no envio via Bulk API
BATCH_SIZE=5000


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

    # O repositório versiona apenas o .zip; extrai o .log sob demanda.
    if [ -f "$LOG_ZIP" ]; then

        echo "ℹ️  $LOG_FILE não encontrado. Extraindo de $LOG_ZIP..."
        echo ""

        # -j (junk paths) grava o arquivo direto em ./files/,
        # ignorando a subpasta 'exemplo_firewall/' interna do zip.
        unzip -o -j "$LOG_ZIP" "*/exemplo_firewall.log" -d ./files/ >/dev/null

    fi

    if [ ! -f "$LOG_FILE" ]; then
        echo "❌ Arquivo não encontrado:"
        echo ""
        echo "   $LOG_FILE"
        echo ""
        echo "Verifique se existe o arquivo ou o zip em:"
        echo ""
        echo "   ./files/exemplo_firewall.log"
        echo "   ./files/exemplo_firewall.zip"
        echo ""
        exit 1
    fi

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

# Usa -I (HEAD real). Obs.: com "-X HEAD" o curl fica aguardando um corpo
# de resposta que nunca chega e trava ate o timeout.
INDEX_EXISTS=$(es_curl \
    -o /dev/null \
    -w "%{http_code}" \
    -I \
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

# A criacao do indice exige o wrapper "mappings"; MAPPING_JSON contem
# apenas o bloco "properties".
INDEX_RESPONSE=$(echo "{ \"mappings\": ${MAPPING_JSON} }" | \
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
# Divide o NDJSON em lotes (BATCH_SIZE docs = BATCH_SIZE*2 linhas)
# ------------------------------------------------------------

PARTS_DIR=$(mktemp -d)

split -l "$((BATCH_SIZE * 2))" "$BULK_FILE" "${PARTS_DIR}/part_"

DOC_TOTAL=$(( $(wc -l < "$BULK_FILE" | tr -d ' ') / 2 ))
TOTAL_BATCHES=$(ls "${PARTS_DIR}"/part_* | wc -l | tr -d ' ')


# ------------------------------------------------------------
# Envia cada lote e mostra progresso em %
# ------------------------------------------------------------

echo "Enviando ${DOC_TOTAL} documentos em ${TOTAL_BATCHES} lote(s) de ${BATCH_SIZE}..."
echo ""

SENT=0
BATCH_NUM=0
FAILED_BATCHES=0

for part in "${PARTS_DIR}"/part_*; do

    BATCH_NUM=$((BATCH_NUM + 1))
    DOCS_IN_PART=$(( $(wc -l < "$part" | tr -d ' ') / 2 ))

    BATCH_RESPONSE=$(docker exec -i "$ES_CONTAINER" \
        curl -sS \
        -X POST \
        "${ES_URL}/${INDEX_NAME}/_bulk?pipeline=${PIPELINE_NAME}" \
        -H "Content-Type: application/x-ndjson" \
        --data-binary @- < "$part")

    # Verifica apenas a flag de erro (nao imprime a resposta inteira)
    ERRORS=$(echo "$BATCH_RESPONSE" | python3 -c '
import json, sys
try:
    print("true" if json.load(sys.stdin).get("errors") else "false")
except Exception:
    print("unknown")
')

    if [ "$ERRORS" = "true" ]; then
        FAILED_BATCHES=$((FAILED_BATCHES + 1))
    fi

    SENT=$((SENT + DOCS_IN_PART))
    PCT=$(( SENT * 100 / DOC_TOTAL ))

    # \r atualiza a mesma linha em vez de rolar a tela
    printf "\r   [%3d%%] lote %d/%d  —  %d/%d docs" \
        "$PCT" "$BATCH_NUM" "$TOTAL_BATCHES" "$SENT" "$DOC_TOTAL"

done

printf "\n\n"

rm -rf "$PARTS_DIR"


if [ "$FAILED_BATCHES" -gt 0 ]; then

    echo "❌ ${FAILED_BATCHES} lote(s) retornaram erros durante a importação."
    echo ""

    exit 1

fi
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
echo "5/6 - Criando Data View no Kibana"
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


# Verifica resultado (sem imprimir a resposta JSON inteira)
if echo "$DATA_VIEW_RESPONSE" | \
    grep -q '"type":"index-pattern"'; then

    echo "✅ Data View criado:"
    echo "   $INDEX_NAME"

else

    echo "⚠️  Não foi possível confirmar a criação do Data View."
    echo "    Resposta do Kibana:"
    echo "    $DATA_VIEW_RESPONSE"

fi


# ============================================================
# 6/6 - DASHBOARD
# ============================================================

echo ""
echo "------------------------------------------------------------"
echo "6/6 - Importando Dashboard no Kibana"
echo "------------------------------------------------------------"
echo ""


# ------------------------------------------------------------
# Extrai o dashboard.json do zip (formato legado _id/_type/_source)
# ------------------------------------------------------------

if [ ! -f "$DASHBOARD_FILE" ] && [ -f "$LOG_ZIP" ]; then
    unzip -o -j "$LOG_ZIP" "*/dashboard.json" -d ./files/ >/dev/null
fi


if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "⚠️  $DASHBOARD_FILE não encontrado; pulando importação do dashboard."
else

    # --------------------------------------------------------
    # Converte o formato legado ( [{_id,_type,_source,...}] )
    # para o NDJSON que a API /_import espera
    # ( {id,type,attributes,references,migrationVersion} ).
    # --------------------------------------------------------
    python3 - "$DASHBOARD_FILE" > "$DASHBOARD_NDJSON" <<'PY'
import json, sys

objs = json.load(open(sys.argv[1], encoding="utf-8"))

for o in objs:
    rec = {
        "id": o["_id"],
        "type": o["_type"],
        "attributes": o.get("_source", {}),
        "references": o.get("_references", []),
    }
    if "_migrationVersion" in o:
        rec["migrationVersion"] = o["_migrationVersion"]
    print(json.dumps(rec, ensure_ascii=False))
PY

    echo "Enviando objetos salvos para o Kibana..."

    # 1a tentativa: import normal (sobrescrevendo conflitos)
    IMPORT_RESPONSE=$(curl -sS \
        -X POST \
        "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
        -H "kbn-xsrf: true" \
        --form file=@"${DASHBOARD_NDJSON}")

    # Se o import falhar (ex.: um filtro antigo referencia um index-pattern
    # que nao existe mais), reimporta via _resolve_import_errors ignorando as
    # referencias faltantes -- como faz o passo "resolver" da UI. O /_import
    # do Kibana e transacional: uma unica referencia faltante reverte TODOS os
    # objetos, entao os retries precisam listar TODOS eles, nao so os que
    # deram erro.
    NEED_RESOLVE=$(echo "$IMPORT_RESPONSE" | python3 -c '
import json, sys
try:
    print("no" if json.load(sys.stdin).get("success") else "yes")
except Exception:
    print("no")
')

    if [ "$NEED_RESOLVE" = "yes" ]; then

        RETRIES=$(python3 -c '
import json, sys
retries = [
    {"type": o["type"], "id": o["id"],
     "overwrite": True, "ignoreMissingReferences": True}
    for o in (json.loads(l) for l in open(sys.argv[1]) if l.strip())
]
print(json.dumps(retries))
' "$DASHBOARD_NDJSON")

        IMPORT_RESPONSE=$(curl -sS \
            -X POST \
            "${KIBANA_URL}/api/saved_objects/_resolve_import_errors" \
            -H "kbn-xsrf: true" \
            --form file=@"${DASHBOARD_NDJSON}" \
            --form "retries=${RETRIES}")
    fi

    # Relatorio final do import (conciso)
    echo "$IMPORT_RESPONSE" | python3 -c '
import json, sys
try:
    r = json.load(sys.stdin)
except Exception:
    print("⚠️  Resposta inesperada do Kibana."); sys.exit()

if r.get("success"):
    print("✅ Dashboard importado: %d objeto(s) salvos." % r.get("successCount", 0))
    for o in r.get("successResults", []):
        if o.get("type") == "dashboard":
            print("   Dashboard: " + o.get("meta", {}).get("title", o.get("id")))
else:
    print("⚠️  Falha ao importar alguns objetos:")
    for e in r.get("errors", []):
        print("   - %s %s: %s" % (e.get("type"), e.get("id"),
                                  e.get("error", {}).get("type")))
'

fi


# ============================================================
# LIMPEZA
# ============================================================

rm -f "$BULK_FILE"
rm -f "$DASHBOARD_NDJSON"


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

echo "Dashboard:"
echo "   [Shell] UFW"
echo ""

echo "Documentos:"
echo "   $COUNT"
echo ""

echo "============================================================"
echo ""
