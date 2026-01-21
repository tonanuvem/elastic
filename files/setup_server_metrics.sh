#!/bin/bash

set -e  # faz o script parar se algum comando falhar

echo "📥 Baixando arquivos de métricas..."
wget https://download.elastic.co/demos/machine_learning/gettingstarted/server_metrics.tar.gz

echo "📦 Extraindo arquivos..."
tar -zxvf server_metrics.tar.gz

echo "🐳 Executando script dentro do container Elasticsearch..."
docker exec -it elasticsearch bash -c "
  cd files/files && \
  sh ./upload_server_metrics.sh
"

echo "✅ Processo finalizado com sucesso!"
