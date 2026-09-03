#!/bin/bash

# ============================================================
# run.sh
#
# Inicializa a Elastic Stack e executa a configuração/importação
# dos logs de firewall.
#
# Estrutura esperada:
#
# .
# ├── docker-compose.yml
# ├── run.sh
# ├── log_exemplo_firewall.sh
# └── files/
#     └── exemplo_firewall.log
#
# ============================================================

set -e

echo ""
echo "============================================================"
echo "                 ELASTIC STACK"
echo "============================================================"
echo ""
echo "Iniciando containers..."
echo ""

# ------------------------------------------------------------
# Inicia todos os serviços
# ------------------------------------------------------------

docker compose up -d

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Erro ao iniciar o Docker Compose."
    exit 1
fi

echo ""
echo "✅ Containers iniciados."
echo ""

# ------------------------------------------------------------
# Executa configuração e importação dos logs
# ------------------------------------------------------------

if [ ! -x "./log_exemplo_firewall.sh" ]; then
    echo "⚠️  log_exemplo_firewall.sh não possui permissão de execução."
    echo "    Aplicando chmod +x..."
    chmod +x ./log_exemplo_firewall.sh
fi

echo "Executando configuração dos logs..."
echo ""

unzip ./files/exemplo_firewall.zip

./log_exemplo_firewall.sh

# ------------------------------------------------------------
# Descobre IP público
# ------------------------------------------------------------

IP=$(curl -s --max-time 10 checkip.amazonaws.com || true)

echo ""
echo "============================================================"
echo "                    ACESSO AO AMBIENTE"
echo "============================================================"
echo ""

echo ""
echo "URL de acesso: Kibana"
echo ""
if [ -n "$IP" ]; then
    echo "http://${IP}:5601"
else
    echo "http://SEU_IP:5601"
fi

echo ""
echo "============================================================"
echo ""
