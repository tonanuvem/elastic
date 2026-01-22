#!/bin/sh

set -e

CONTAINER_NAME="elasticsearch"
INDEX_NAME="server-metrics"

echo "📥 Baixando arquivos de métricas..."
wget https://download.elastic.co/demos/machine_learning/gettingstarted/server_metrics.tar.gz

echo "📦 Extraindo arquivos..."
tar -zxvf server_metrics.tar.gz

echo "🐳 Executando upload dentro do container..."
docker exec -i "$CONTAINER_NAME" sh -c '
  cd files/files && \
  sh ./upload_server_metrics.sh
'

echo "⏳ Aguardando Elasticsearch indexar os dados..."
sleep 10

echo "🔍 Verificando índice '"$INDEX_NAME"' dentro do container..."

INDEX_LINE=$(docker exec "$CONTAINER_NAME" sh -c \
  "curl -s http://localhost:9200/_cat/indices?v | grep $INDEX_NAME" || true)

# --- SUBSTITUI [[ -z ... ]]
if [ -z "$INDEX_LINE" ]; then
  echo "❌ ERRO: Índice '$INDEX_NAME' não encontrado no Elasticsearch"
  exit 1
fi

echo "🐳 Verificando upload dentro do container..."
docker exec -i "$CONTAINER_NAME" sh -c '
  cd files/files && \
  sh ./upload_server_metrics.sh
'

echo "✅ Índice encontrado:"
echo "$INDEX_LINE"

STATUS=$(echo "$INDEX_LINE" | awk '{print $2}')
DOCS_COUNT=$(echo "$INDEX_LINE" | awk '{print $7}')

# --- SUBSTITUI [[ "$STATUS" != "open" ]]
if [ "$STATUS" != "open" ]; then
  echo "❌ ERRO: Índice não está OPEN (status atual: $STATUS)"
  exit 1
fi

# --- SUBSTITUI [[ "$DOCS_COUNT" -le 0 ]]
if [ "$DOCS_COUNT" -le 0 ]; then
  echo "❌ ERRO: Nenhum documento carregado"
  exit 1
fi

echo "🎉 Server-metrics carregado com sucesso!"
echo "📊 Total de documentos: $DOCS_COUNT"
