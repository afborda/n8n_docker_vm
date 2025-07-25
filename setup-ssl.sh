#!/bin/bash

# Script para configurar SSL com Certbot para n8n.abnerfonseca.com.br
# Deve ser executado como root ou com sudo

set -e

DOMAIN="n8n.abnerfonseca.com.br"
EMAIL="admin@abnerfonseca.com.br"  # Altere para seu email
WEBROOT_PATH="/var/www/certbot"
NGINX_CONF_PATH="./nginx-ssl.conf"

echo "🔐 Configurando SSL para $DOMAIN"
echo "====================================="

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script deve ser executado como root"
   echo "Use: sudo $0"
   exit 1
fi

# 1. Instalar certbot
echo "📦 Instalando Certbot..."
apt update
apt install -y certbot

# 2. Criar diretório para webroot
echo "📁 Criando diretório webroot..."
mkdir -p $WEBROOT_PATH
chown -R www-data:www-data $WEBROOT_PATH

# 3. Parar nginx temporariamente para liberar porta 80
echo "⏹️  Parando nginx..."
docker-compose stop nginx || true

# 4. Gerar certificado usando standalone
echo "🔒 Gerando certificado SSL..."
certbot certonly \
    --standalone \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --domains $DOMAIN \
    --verbose

if [ $? -eq 0 ]; then
    echo "✅ Certificado gerado com sucesso!"
else
    echo "❌ Erro ao gerar certificado"
    exit 1
fi

# 5. Criar diretório SSL no projeto
echo "📁 Criando diretório SSL..."
mkdir -p ./ssl
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./ssl/
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./ssl/
chown -R 1000:1000 ./ssl

# 6. Gerar configuração nginx com SSL
echo "⚙️  Gerando configuração nginx com SSL..."
cat > $NGINX_CONF_PATH << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Upstream para load balancing do n8n
    upstream n8n_backend {
        server n8n:5678 max_fails=3 fail_timeout=30s;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=n8n_limit:10m rate=50r/s;
    limit_req_zone $binary_remote_addr zone=assets_limit:10m rate=100r/s;

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name DOMAIN_PLACEHOLDER;
        
        # Certbot webroot
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        # Redirect all other traffic to HTTPS
        location / {
            return 301 https://$server_name$request_uri;
        }
    }

    # HTTPS Server
    server {
        listen 443 ssl http2;
        server_name DOMAIN_PLACEHOLDER;

        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        # SSL Settings
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        
        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Assets estáticos
        location ~* \.(js|css|woff|woff2|ttf|eot|ico|png|jpg|jpeg|gif|svg)$ {
            limit_req zone=assets_limit burst=200 nodelay;
            
            proxy_pass http://n8n_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            expires 1h;
            add_header Cache-Control "public, immutable";
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        location /assets/ {
            limit_req zone=assets_limit burst=200 nodelay;
            
            proxy_pass http://n8n_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            expires 1h;
            add_header Cache-Control "public, immutable";
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }

        # Proxy para n8n
        location / {
            limit_req zone=n8n_limit burst=100 nodelay;

            proxy_pass http://n8n_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;

            proxy_buffering on;
            proxy_buffer_size 128k;
            proxy_buffers 4 256k;
            proxy_busy_buffers_size 256k;

            client_max_body_size 50M;
        }

        # Status page do nginx
        location /nginx_status {
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            allow 172.16.0.0/12;
            deny all;
        }
    }
}
EOF

# Substituir placeholder pelo domínio real
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" $NGINX_CONF_PATH

echo "📝 Configuração nginx SSL criada: $NGINX_CONF_PATH"

# 7. Atualizar docker-compose.yml para usar SSL
echo "🐳 Atualizando docker-compose.yml..."
cat > docker-compose-ssl.yml << 'EOF'
services:
  # n8n instances (scalable)
  n8n:
    image: n8nio/n8n:latest
    restart: always
    environment:
      # Webhook configuration - HTTPS
      WEBHOOK_URL: https://DOMAIN_PLACEHOLDER
      
      # Security
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY:-your-encryption-key-here}
      
      # General settings
      GENERIC_TIMEZONE: ${TIMEZONE:-America/Sao_Paulo}
      N8N_LOG_LEVEL: info
      
      # Basic settings
      N8N_BASIC_AUTH_ACTIVE: ${N8N_BASIC_AUTH_ACTIVE:-true}
      N8N_BASIC_AUTH_USER: ${N8N_BASIC_AUTH_USER:-admin}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_BASIC_AUTH_PASSWORD:-admin123}
      
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network
    deploy:
      replicas: 2  # Otimizado para e2-micro
      resources:
        limits:
          memory: 400M  # Mais memória por instância
          cpus: '0.8'   
        reservations:
          memory: 300M  
          cpus: '0.4'   
    healthcheck:
      test: ['CMD-SHELL', 'wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1']
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # Nginx Load Balancer with SSL
  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"    # HTTP redirect
      - "443:443"  # HTTPS
    volumes:
      - ./nginx-ssl.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - /var/www/certbot:/var/www/certbot:ro
    networks:
      - n8n-network
    depends_on:
      - n8n
    deploy:
      resources:
        limits:
          memory: 100M   
          cpus: '0.2'   
        reservations:
          memory: 50M   
          cpus: '0.1'   
    healthcheck:
      test: ['CMD', 'wget', '--no-verbose', '--tries=1', '--spider', 'http://localhost/health']
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  n8n_data:

networks:
  n8n-network:
    driver: bridge
EOF

sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" docker-compose-ssl.yml

# 8. Atualizar .env para HTTPS
echo "⚙️  Atualizando .env..."
if [ -f .env ]; then
    sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=https://$DOMAIN|g" .env
else
    echo "WEBHOOK_URL=https://$DOMAIN" >> .env
    echo "N8N_ENCRYPTION_KEY=your-encryption-key-change-this-to-something-secure" >> .env
    echo "TIMEZONE=America/Sao_Paulo" >> .env
    echo "N8N_BASIC_AUTH_ACTIVE=true" >> .env
    echo "N8N_BASIC_AUTH_USER=admin" >> .env
    echo "N8N_BASIC_AUTH_PASSWORD=admin123" >> .env
fi

# 9. Criar script de renovação
echo "🔄 Criando script de renovação..."
cat > renew-ssl.sh << 'EOF'
#!/bin/bash

DOMAIN="DOMAIN_PLACEHOLDER"

echo "🔄 Renovando certificado SSL..."

# Parar nginx
docker-compose -f docker-compose-ssl.yml stop nginx

# Renovar certificado
certbot renew --standalone

# Copiar certificados atualizados
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./ssl/
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./ssl/
chown -R 1000:1000 ./ssl

# Reiniciar nginx
docker-compose -f docker-compose-ssl.yml up -d nginx

echo "✅ Certificado renovado com sucesso!"
EOF

sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" renew-ssl.sh
chmod +x renew-ssl.sh

# 10. Configurar cron para renovação automática
echo "⏰ Configurando renovação automática..."
(crontab -l 2>/dev/null; echo "0 3 * * * cd $(pwd) && ./renew-ssl.sh >> /var/log/certbot-renew.log 2>&1") | crontab -

echo ""
echo "✅ Configuração SSL completa!"
echo "================================="
echo ""
echo "📋 Próximos passos:"
echo "1. Verificar se o DNS aponta para esta VM:"
echo "   nslookup $DOMAIN"
echo ""
echo "2. Iniciar com SSL:"
echo "   docker-compose -f docker-compose-ssl.yml up -d"
echo ""
echo "3. Acessar:"
echo "   https://$DOMAIN"
echo ""
echo "4. Verificar certificado:"
echo "   curl -I https://$DOMAIN"
echo ""
echo "📁 Arquivos criados:"
echo "   - nginx-ssl.conf (configuração nginx com SSL)"
echo "   - docker-compose-ssl.yml (compose com SSL)"
echo "   - renew-ssl.sh (script de renovação)"
echo "   - ./ssl/ (certificados)"
echo ""
echo "🔄 Renovação automática configurada para executar às 3h da manhã"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - Certifique-se de que o domínio aponta para esta VM"
echo "   - A porta 80 e 443 devem estar abertas no firewall"
echo "   - Use docker-compose-ssl.yml em vez do arquivo original"
