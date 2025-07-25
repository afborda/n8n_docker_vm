#!/bin/bash

echo "=== n8n Escalável - Monitoramento de Recursos ==="
echo "VM: e2-micro (1GB RAM, 2 vCPUs)"
echo ""

echo "📊 Status dos Containers:"
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "💾 Uso de Recursos:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.PIDs}}"
echo ""

echo "🔍 Resumo de Memória:"
TOTAL_MEM=$(docker stats --no-stream --format "{{.MemUsage}}" | grep -o '[0-9.]*MiB' | sed 's/MiB//' | awk '{sum += $1} END {print sum}')
echo "Uso total: ${TOTAL_MEM}MB / 1024MB disponível"
echo "Livre: $((1024 - ${TOTAL_MEM%.*}))MB"
echo ""

echo "🌐 Teste de Conectividade:"
if curl -s http://localhost:8080/health > /dev/null; then
    echo "✅ nginx: OK"
else
    echo "❌ nginx: ERRO"
fi

if curl -s -u admin:admin123 http://localhost:8080/rest/settings > /dev/null; then
    echo "✅ n8n: OK"
else
    echo "❌ n8n: ERRO"
fi
echo ""

echo "📋 Para escalar:"
echo "docker-compose up -d --scale n8n=2  # Reduzir para 2 instâncias"
echo "docker-compose up -d --scale n8n=4  # Aumentar para 4 instâncias (cuidado com RAM!)"
