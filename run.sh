#!/bin/bash

echo "Executando Elastic stack para análise dos dados"

# Start up all services
docker-compose up -d

IP=$(curl checkip.amazonaws.com)

echo ""
echo "URL de acesso: Kibana"
echo ""
echo http://$(curl -s checkip.amazonaws.com):5601
echo ""
echo ""
