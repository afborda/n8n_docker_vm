#!/bin/bash

# Script de teste rápido para verificar SSL local

LOCAL_DOMAIN="n8n-local.com"

echo "🧪 Teste rápido SSL local"
echo "========================"
echo ""

# 1. Verificar se o domínio resolve
echo "🌐 1. Testando resolução DNS..."
if ping -c 1 $LOCAL_DOMAIN >/dev/null 2>&1; then
    echo "   ✅ DNS: OK"
else
    echo "   ❌ DNS: ERRO"
    echo "   💡 Execute: sudo ./setup-local-hosts.sh"
    exit 1
fi

# 2. Verificar containers
echo ""
echo "🐳 2. Verificando containers..."
if docker-compose -f docker-compose-local-test.yml ps | grep -q "Up"; then
    echo "   ✅ Containers: OK"
else
    echo "   ❌ Containers: ERRO"
    echo "   💡 Execute: docker-compose -f docker-compose-local-test.yml up -d"
    exit 1
fi

# 3. Testar HTTP (deve redirecionar)
echo ""
echo "🔗 3. Testando HTTP redirect..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$LOCAL_DOMAIN)
if [ "$HTTP_STATUS" = "301" ]; then
    echo "   ✅ HTTP redirect: OK ($HTTP_STATUS)"
else
    echo "   ⚠️  HTTP redirect: $HTTP_STATUS"
fi

# 4. Testar HTTPS
echo ""
echo "🔒 4. Testando HTTPS..."
HTTPS_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" https://$LOCAL_DOMAIN)
if [ "$HTTPS_STATUS" = "200" ]; then
    echo "   ✅ HTTPS: OK ($HTTPS_STATUS)"
else
    echo "   ⚠️  HTTPS: $HTTPS_STATUS"
fi

# 5. Verificar certificado
echo ""
echo "📄 5. Verificando certificado..."
if openssl s_client -connect $LOCAL_DOMAIN:443 -servername $LOCAL_DOMAIN </dev/null 2>/dev/null | grep -q "Verify return code: 18"; then
    echo "   ✅ Certificado: Auto-assinado (normal)"
elif openssl s_client -connect $LOCAL_DOMAIN:443 -servername $LOCAL_DOMAIN </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
    echo "   ✅ Certificado: Válido"
else
    echo "   ⚠️  Certificado: Pode ter problemas"
fi

echo ""
echo "🎯 Resultado final:"
echo "==================="
echo ""
if [ "$HTTPS_STATUS" = "200" ]; then
    echo "✅ Tudo funcionando! Acesse: https://$LOCAL_DOMAIN"
    echo ""
    echo "🌐 No navegador:"
    echo "   1. Vá para: https://$LOCAL_DOMAIN"
    echo "   2. Se aparecer aviso de segurança:"
    echo "      Chrome/Edge: 'Avançado' > 'Continuar para n8n-local.com'"
    echo "      Firefox: 'Avançado' > 'Aceitar o risco e continuar'"
    echo "      Safari: 'Mostrar detalhes' > 'Visitar este website'"
else
    echo "❌ Há problemas. Verifique os logs:"
    echo "   docker-compose -f docker-compose-local-test.yml logs"
fi

echo ""
