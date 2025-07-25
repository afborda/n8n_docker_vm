#!/bin/bash

# Script para gerar certificados SSL locais compatíveis com navegadores modernos
# Inclui todas as extensões necessárias para evitar ERR_SSL_KEY_USAGE_INCOMPATIBLE

LOCAL_DOMAIN="n8n-local.com"
SSL_DIR="./ssl"

echo "🔐 Gerando certificados SSL locais compatíveis..."
echo "Domínio: $LOCAL_DOMAIN"

# Criar diretório SSL se não existir
mkdir -p $SSL_DIR

# Remover certificados antigos
rm -f $SSL_DIR/local-cert.pem $SSL_DIR/local-key.pem

# Criar arquivo de configuração OpenSSL
cat > $SSL_DIR/openssl.conf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=BR
ST=SP
L=SaoPaulo
O=LocalTest
OU=n8n
CN=$LOCAL_DOMAIN

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
extendedKeyUsage = serverAuth, clientAuth

[alt_names]
DNS.1 = $LOCAL_DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

echo "📋 Arquivo de configuração criado"

# Gerar chave privada
echo "🔑 Gerando chave privada..."
openssl genrsa -out $SSL_DIR/local-key.pem 2048

if [ $? -ne 0 ]; then
    echo "❌ Erro ao gerar chave privada"
    exit 1
fi

# Gerar certificado
echo "📄 Gerando certificado..."
openssl req -new -x509 -key $SSL_DIR/local-key.pem \
    -out $SSL_DIR/local-cert.pem \
    -days 365 \
    -config $SSL_DIR/openssl.conf \
    -extensions v3_req

if [ $? -ne 0 ]; then
    echo "❌ Erro ao gerar certificado"
    exit 1
fi

# Definir permissões corretas
chmod 600 $SSL_DIR/local-key.pem
chmod 644 $SSL_DIR/local-cert.pem

echo ""
echo "✅ Certificados gerados com sucesso!"
echo ""
echo "📂 Arquivos criados:"
echo "   🔑 Chave privada: $SSL_DIR/local-key.pem"
echo "   📄 Certificado: $SSL_DIR/local-cert.pem"
echo "   ⚙️  Configuração: $SSL_DIR/openssl.conf"
echo ""

# Verificar o certificado
echo "🔍 Verificando certificado..."
echo "Domínio principal:"
openssl x509 -in $SSL_DIR/local-cert.pem -text -noout | grep "Subject:"

echo ""
echo "SANs (Subject Alternative Names):"
openssl x509 -in $SSL_DIR/local-cert.pem -text -noout | grep -A 4 "Subject Alternative Name"

echo ""
echo "Extensões de uso da chave:"
openssl x509 -in $SSL_DIR/local-cert.pem -text -noout | grep -A 2 "Key Usage"

echo ""
echo "✅ Certificado SSL compatível gerado!"
