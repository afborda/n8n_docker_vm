#!/bin/bash

# Script para configurar hosts para teste local SSL

LOCAL_DOMAIN="n8n-local.com"
HOSTS_FILE="/etc/hosts"

echo "🌐 Configurando hosts para teste local SSL"
echo "==========================================="
echo "Domínio: $LOCAL_DOMAIN"
echo ""

# Verificar se é root/sudo para modificar hosts
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script precisa de permissões de root para modificar $HOSTS_FILE"
   echo "Execute: sudo $0"
   echo ""
   echo "📝 Ou adicione manualmente ao $HOSTS_FILE:"
   echo "127.0.0.1 $LOCAL_DOMAIN"
   exit 1
fi

# Verificar se entrada já existe
if grep -q "$LOCAL_DOMAIN" $HOSTS_FILE; then
    echo "✅ Entrada para $LOCAL_DOMAIN já existe em $HOSTS_FILE"
    echo "📋 Entrada atual:"
    grep "$LOCAL_DOMAIN" $HOSTS_FILE
else
    # Adicionar entrada ao hosts
    echo "➕ Adicionando entrada ao $HOSTS_FILE..."
    echo "127.0.0.1 $LOCAL_DOMAIN" >> $HOSTS_FILE
    echo "✅ Entrada adicionada com sucesso!"
fi

echo ""
echo "🧪 Para testar a configuração:"
echo ""
echo "1. Gerar certificados SSL locais:"
echo "   ./generate-local-ssl.sh"
echo ""
echo "2. Iniciar containers SSL:"
echo "   docker-compose -f docker-compose-ssl.yml up -d"
echo ""
echo "3. Testar resolução DNS:"
echo "   ping $LOCAL_DOMAIN"
echo "   nslookup $LOCAL_DOMAIN"
echo ""
echo "4. Testar HTTPS:"
echo "   curl -k https://$LOCAL_DOMAIN/health"
echo "   # -k ignora certificado auto-assinado"
echo ""
echo "5. Acessar no navegador:"
echo "   https://$LOCAL_DOMAIN"
echo ""
echo "🗑️  Para remover depois:"
echo "   sudo sed -i '/$LOCAL_DOMAIN/d' $HOSTS_FILE"
