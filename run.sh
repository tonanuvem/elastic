#!/bin/bash

echo "Executando Elastic stack"
echo ""
echo ""

# Start up all services
docker-compose up -d

IP=$(curl checkip.amazonaws.com)

echo ""
echo "URL de acesso: Aplicação Node.js"
echo ""
echo http://$(curl -s checkip.amazonaws.com):3001
echo ""
echo ""
echo ""
echo "URL de acesso: Kibana"
echo ""
echo http://$(curl -s checkip.amazonaws.com):5601
echo ""
echo ""
