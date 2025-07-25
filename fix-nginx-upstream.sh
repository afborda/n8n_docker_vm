#!/bin/bash

# Script para corrigir o erro de upstream no nginx em produção

echo "🔧 Corrigindo configuração do nginx em produção..."
echo "================================================="

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Erro: Execute este script no diretório /opt/n8n-production"
    echo "💡 Comando: cd /opt/n8n-production && ./fix-nginx-upstream.sh"
    exit 1
fi

# Backup da configuração atual
echo "📋 Fazendo backup da configuração atual..."
cp nginx/nginx.conf nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

# Corrigir configuração do upstream
echo "🔄 Corrigindo upstream do nginx..."
sed -i 's/server n8n_n8n_1:5678 max_fails=3 fail_timeout=30s;/server n8n:5678 max_fails=3 fail_timeout=30s;/g' nginx/nginx.conf
sed -i 's/server n8n_n8n_2:5678 max_fails=3 fail_timeout=30s;//g' nginx/nginx.conf

# Verificar se a correção foi aplicada
if grep -q "server n8n:5678" nginx/nginx.conf && ! grep -q "n8n_n8n_" nginx/nginx.conf; then
    echo "✅ Configuração corrigida com sucesso!"
else
    echo "❌ Erro ao aplicar correção"
    exit 1
fi

# Reiniciar containers
echo "🔄 Reiniciando containers..."
docker-compose down
sleep 2
docker-compose up -d

echo ""
echo "✅ Correção aplicada com sucesso!"
echo ""
echo "🔍 Verificando status dos containers..."
sleep 5
docker-compose ps

echo ""
echo "📋 Para verificar se está funcionando:"
echo "   curl -I https://$(grep DOMAIN .env | cut -d'=' -f2)"
echo "   docker-compose logs nginx"
