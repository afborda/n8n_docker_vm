#!/bin/bash

# Script para gerar certificados auto-assinados para teste local
# Domain: n8n-local.com

LOCAL_DOMAIN="n8n-local.com"
SSL_DIR="./ssl"

echo "🔐 Gerando certificados auto-assinados para teste local"
echo "======================================================="
echo "Domínio: $LOCAL_DOMAIN"
echo ""

# Criar diretório SSL se não existir
mkdir -p $SSL_DIR

# Gerar chave privada
echo "🔑 Gerando chave privada..."
openssl genrsa -out $SSL_DIR/local-key.pem 2048

# Gerar certificado auto-assinado
echo "📜 Gerando certificado auto-assinado..."
openssl req -new -x509 -key $SSL_DIR/local-key.pem \
    -out $SSL_DIR/local-cert.pem \
    -days 365 \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=LocalTest/OU=n8n/CN=$LOCAL_DOMAIN" \
    -extensions v3_req \
    -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=BR
ST=SP
L=SaoPaulo
O=LocalTest
OU=n8n
CN=$LOCAL_DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $LOCAL_DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF
)

# Definir permissões
chmod 644 $SSL_DIR/local-cert.pem
chmod 600 $SSL_DIR/local-key.pem

echo "✅ Certificados gerados:"
echo "   📁 Certificado: $SSL_DIR/local-cert.pem"
echo "   🔑 Chave privada: $SSL_DIR/local-key.pem"
echo ""

# Verificar certificado
echo "📋 Informações do certificado:"
openssl x509 -in $SSL_DIR/local-cert.pem -text -noout | grep -E "(Subject:|DNS:|IP Address:)"
echo ""

echo "🖥️  Para usar localmente:"
echo ""
echo "1. Adicione ao seu /etc/hosts (ou C:\\Windows\\System32\\drivers\\etc\\hosts no Windows):"
echo "   127.0.0.1 $LOCAL_DOMAIN"
echo ""
echo "2. Inicie os containers:"
echo "   docker-compose -f docker-compose-ssl.yml up -d"
echo ""
echo "3. Acesse localmente:"
echo "   https://$LOCAL_DOMAIN"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - Seu navegador mostrará aviso de certificado não confiável"
echo "   - Isso é normal para certificados auto-assinados"
echo "   - Clique em 'Avançado' e 'Continuar para o site'"
echo ""
echo "🔧 Para confiar no certificado (opcional):"
echo ""
echo "   macOS:"
echo "   sudo security add-trusted-cert -d -r trustRoot -k /System/Library/Keychains/SystemRootCertificates.keychain $SSL_DIR/local-cert.pem"
echo ""
echo "   Linux:"
echo "   sudo cp $SSL_DIR/local-cert.pem /usr/local/share/ca-certificates/$LOCAL_DOMAIN.crt"
echo "   sudo update-ca-certificates"
echo ""
echo "✅ Configuração completa para teste local!"
