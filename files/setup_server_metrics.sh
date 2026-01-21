#!/bin/bash

set -e

ES_HOST="http://localhost:9200"
INDEX_NAME="server-metrics"

echo "📥 Baixando arquivos de métricas..."
wget https://download.elastic.co/demos/machine_learning/gettingstarted/server_metrics.tar.gz

echo "📦 Extraindo arquivos..."
tar -zxvf server_metrics.tar.gz

echo "🐳 Executando script dentro do container Elasticsearch..."
docker exec -it elasticsearch bash -c "
  cd files/files && \
  sh ./upload_server_metrics.sh
"

echo "⏳ Aguardando Elasticsearch indexar os dados..."
sleep 10

echo "🔍 Verificando se o índice '${INDEX_NAME}' foi criado..."

INDEX_LINE=$(curl -s -X GET "${ES_HOST}/_cat/indices?v" | grep "${INDEX_NAME}" || true)

if [[ -z "$INDEX_LINE" ]]; then
  echo "❌ ERRO: Índice '${INDEX_NAME}' não encontrado no Elasticsearch"
  exit 1
fi

echo "✅ Índice encontrado:"
echo "$INDEX_LINE"

echo "📊 Validando status, shards e quantidade de documentos..."

# Extrai colunas relevantes (_cat/indices):
# health status index uuid pri rep docs.count docs.deleted store.size pri.store.size
STATUS=$(echo "$INDEX_LINE" | awk '{print $2}')
DOCS_COUNT=$(echo "$INDEX_LINE" | awk '{print $7}')

if [[ "$STATUS" != "open" ]]; then
  echo "❌ ERRO: Índice '${INDEX_NAME}' não está OPEN (status atual: $STATUS)"
  exit 1
fi

if [[ "$DOCS_COUNT" -le 0 ]]; then
  echo "❌ ERRO: Nenhum documento carregado no índice '${INDEX_NAME}'"
  exit 1
fi

echo "✅ Índice está OPEN"
echo "✅ Documentos carregados: $DOCS_COUNT"

echo "🎉 Verificação concluída com sucesso!"
