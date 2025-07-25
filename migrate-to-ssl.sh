#!/bin/bash

# Script para migrar de HTTP para HTTPS após gerar certificados

echo "🔄 Migrando de HTTP para HTTPS"
echo "================================"

# Verificar se certificados existem
if [ ! -f "./ssl/fullchain.pem" ] || [ ! -f "./ssl/privkey.pem" ]; then
    echo "❌ Certificados SSL não encontrados em ./ssl/"
    echo "Execute primeiro: sudo ./setup-ssl-simple.sh"
    exit 1
fi

echo "✅ Certificados SSL encontrados"

# Parar containers HTTP
echo "⏹️  Parando containers HTTP..."
docker-compose down

# Aguardar containers pararem
sleep 5

# Iniciar containers HTTPS
echo "🚀 Iniciando containers HTTPS..."
docker-compose -f docker-compose-ssl.yml up -d

# Aguardar inicialização
echo "⏳ Aguardando inicialização..."
sleep 15

# Verificar status
echo "📊 Status dos containers:"
docker-compose -f docker-compose-ssl.yml ps

echo ""
echo "🌐 Testando conectividade:"

# Testar HTTP redirect
if curl -s -I http://n8n.abnerfonseca.com.br | grep -q "301"; then
    echo "✅ HTTP redirect funcionando"
else
    echo "⚠️  HTTP redirect pode ter problemas"
fi

# Testar HTTPS
if curl -s -I https://n8n.abnerfonseca.com.br/health | grep -q "200"; then
    echo "✅ HTTPS funcionando"
else
    echo "⚠️  HTTPS pode ter problemas"
fi

echo ""
echo "🎉 Migração completa!"
echo ""
echo "📋 URLs de acesso:"
echo "   HTTP (redirect): http://n8n.abnerfonseca.com.br"
echo "   HTTPS (principal): https://n8n.abnerfonseca.com.br"
echo ""
echo "📊 Para monitorar: docker-compose -f docker-compose-ssl.yml logs -f"
