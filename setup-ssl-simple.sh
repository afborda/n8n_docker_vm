#!/bin/bash

# Script simplificado para configurar SSL na VM
# Execute na sua VM como: sudo ./setup-ssl-simple.sh

DOMAIN="n8n.abnerfonseca.com.br"
EMAIL="admin@abnerfonseca.com.br"  # Altere para seu email

echo "🔐 Configurando SSL para $DOMAIN"
echo "================================="

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Execute como root: sudo $0"
   exit 1
fi

# Verificar se o domínio resolve para esta VM
echo "🔍 Verificando DNS..."
CURRENT_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)

if [ "$CURRENT_IP" != "$DOMAIN_IP" ]; then
    echo "⚠️  AVISO: DNS não aponta para esta VM"
    echo "   VM IP: $CURRENT_IP"
    echo "   Domain IP: $DOMAIN_IP"
    echo "   Certifique-se de configurar o DNS antes de continuar"
    read -p "Continuar mesmo assim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Instalar certbot
echo "📦 Instalando Certbot..."
apt update
apt install -y certbot

# Parar nginx se estiver rodando
echo "⏹️  Parando nginx..."
cd /home/*/n8n-local/n8n-docke 2>/dev/null || cd /root/n8n-docke 2>/dev/null || cd .
docker-compose stop nginx 2>/dev/null || true

# Gerar certificado
echo "🔒 Gerando certificado SSL..."
certbot certonly \
    --standalone \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --domains $DOMAIN \
    --non-interactive

if [ $? -eq 0 ]; then
    echo "✅ Certificado gerado!"
    
    # Copiar certificados
    echo "📁 Copiando certificados..."
    mkdir -p ./ssl
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./ssl/
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./ssl/
    chmod 644 ./ssl/*.pem
    
    echo "✅ Configuração SSL completa!"
    echo ""
    echo "📋 Próximos passos:"
    echo "1. Atualizar nginx.conf para usar SSL"
    echo "2. Atualizar docker-compose.yml para portas 80/443"
    echo "3. Reiniciar containers: docker-compose up -d"
    echo ""
else
    echo "❌ Erro ao gerar certificado"
    echo "Verifique se:"
    echo "- O domínio aponta para esta VM"
    echo "- As portas 80/443 estão liberadas"
    echo "- Não há outros serviços usando porta 80"
    exit 1
fi
