#!/bin/bash

# Script completo para configurar teste SSL local
# Combina hosts + certificados + containers

LOCAL_DOMAIN="n8n-local.com"

echo "🧪 Setup completo para teste SSL local"
echo "======================================"
echo "Domínio: $LOCAL_DOMAIN"
echo ""

# 1. Verificar se os scripts existem
if [ ! -f "./generate-local-ssl-fixed.sh" ] || [ ! -f "./setup-local-hosts.sh" ]; then
    echo "❌ Scripts necessários não encontrados"
    echo "Certifique-se de que os seguintes arquivos existam:"
    echo "  - generate-local-ssl-fixed.sh"
    echo "  - setup-local-hosts.sh"
    exit 1
fi

# 2. Gerar certificados SSL locais
echo "🔐 Passo 1: Gerando certificados SSL compatíveis..."
chmod +x generate-local-ssl-fixed.sh
./generate-local-ssl-fixed.sh

if [ $? -ne 0 ]; then
    echo "❌ Erro ao gerar certificados SSL"
    exit 1
fi

echo ""
echo "✅ Certificados gerados com sucesso!"
echo ""

# 3. Configurar hosts (precisa de sudo)
echo "🌐 Passo 2: Configurando hosts..."
echo "💡 Será solicitada sua senha para modificar /etc/hosts"

chmod +x setup-local-hosts.sh
sudo ./setup-local-hosts.sh

if [ $? -ne 0 ]; then
    echo "❌ Erro ao configurar hosts"
    exit 1
fi

echo ""
echo "✅ Hosts configurado com sucesso!"
echo ""

# 4. Verificar se docker-compose-local-test.yml existe
if [ ! -f "./docker-compose-local-test.yml" ]; then
    echo "❌ Arquivo docker-compose-local-test.yml não encontrado"
    echo "Certifique-se de ter o arquivo de configuração local"
    exit 1
fi

# 5. Iniciar containers SSL
echo "🐳 Passo 3: Iniciando containers SSL (configuração local)..."
docker-compose -f docker-compose-local-test.yml up -d

if [ $? -ne 0 ]; then
    echo "❌ Erro ao iniciar containers"
    exit 1
fi

echo ""
echo "✅ Containers iniciados com sucesso!"
echo ""

# 6. Aguardar containers ficarem prontos
echo "⏳ Aguardando containers ficarem prontos..."
sleep 10

# 7. Testar conectividade
echo "🧪 Passo 4: Testando conectividade..."
echo ""

echo "📍 Testando resolução DNS:"
if ping -c 1 $LOCAL_DOMAIN >/dev/null 2>&1; then
    echo "✅ DNS: OK"
else
    echo "❌ DNS: ERRO - Verifique /etc/hosts"
fi

echo ""
echo "🔗 Testando HTTP redirect:"
if curl -s -I http://$LOCAL_DOMAIN 2>/dev/null | grep -q "301"; then
    echo "✅ HTTP redirect: OK"
else
    echo "⚠️  HTTP redirect: Pode ter problemas"
fi

echo ""
echo "🔒 Testando HTTPS:"
if curl -k -s -I https://$LOCAL_DOMAIN/health 2>/dev/null | grep -q "200"; then
    echo "✅ HTTPS: OK"
else
    echo "⚠️  HTTPS: Pode ter problemas"
fi

echo ""
echo "🎉 Setup local SSL completo!"
echo "============================"
echo ""
echo "📋 URLs de acesso:"
echo "   🧪 Local: https://$LOCAL_DOMAIN"
echo ""
echo "🔧 Comandos úteis:"
echo "   docker-compose -f docker-compose-local-test.yml ps"
echo "   docker-compose -f docker-compose-local-test.yml logs -f"
echo "   curl -k https://$LOCAL_DOMAIN/health"
echo ""
echo "⚠️  Avisos importantes:"
echo "   - Navegador mostrará aviso de certificado não confiável"
echo "   - Isso é normal para certificados auto-assinados"
echo "   - Clique em 'Avançado' > 'Continuar para o site'"
echo ""
echo "🗑️  Para limpar depois:"
echo "   docker-compose -f docker-compose-local-test.yml down"
echo "   sudo sed -i '/$LOCAL_DOMAIN/d' /etc/hosts"
echo "   rm -f ./ssl/local-cert.pem ./ssl/local-key.pem"
