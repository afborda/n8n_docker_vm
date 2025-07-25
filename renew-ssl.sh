#!/bin/bash

# Script para renovar certificados SSL automaticamente
# Deve ser executado via cron

DOMAIN="n8n.abnerfonseca.com.br"
PROJECT_DIR="/root/n8n-docke"  # Ajuste para o caminho do seu projeto
LOG_FILE="/var/log/certbot-renew.log"

echo "$(date): Iniciando renovação de certificado para $DOMAIN" >> $LOG_FILE

cd $PROJECT_DIR

# Parar nginx
echo "$(date): Parando nginx..." >> $LOG_FILE
docker-compose -f docker-compose-ssl.yml stop nginx

# Renovar certificado
echo "$(date): Renovando certificado..." >> $LOG_FILE
if certbot renew --standalone --quiet; then
    echo "$(date): Certificado renovado com sucesso" >> $LOG_FILE
    
    # Copiar certificados atualizados
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./ssl/
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./ssl/
    chmod 644 ./ssl/*.pem
    
    # Reiniciar nginx
    echo "$(date): Reiniciando nginx..." >> $LOG_FILE
    docker-compose -f docker-compose-ssl.yml up -d nginx
    
    echo "$(date): Renovação concluída com sucesso" >> $LOG_FILE
else
    echo "$(date): Erro na renovação do certificado" >> $LOG_FILE
    
    # Tentar reiniciar nginx mesmo com erro
    docker-compose -f docker-compose-ssl.yml up -d nginx
fi
