#!/bin/bash

# Script completo para deploy de n8n em produção
# Automatiza: nginx + SSL Let's Encrypt + n8n escalável + otimização para e2-micro

set -e  # Parar em qualquer erro

# ================================
# CONFIGURAÇÕES (EDITE AQUI)
# ================================

DOMAIN="n8n.abnerfonseca.com.br"
EMAIL="seu-email@exemplo.com"  # IMPORTANTE: Altere para seu email real
N8N_INSTANCES=2               # Número de instâncias n8n (recomendado 2 para e2-micro)

# ================================
# CORES E EMOJIS
# ================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ================================
# FUNÇÕES AUXILIARES
# ================================

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Este script precisa ser executado como root (use sudo)"
    fi
}

check_domain() {
    log "🌐 Verificando domínio $DOMAIN..."
    
    # Verificar se o domínio aponta para este servidor
    SERVER_IP=$(curl -s ifconfig.me)
    DOMAIN_IP=$(dig +short $DOMAIN @8.8.8.8 | tail -n1)
    
    if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
        warn "Domínio $DOMAIN não aponta para este servidor"
        echo "   IP do servidor: $SERVER_IP"
        echo "   IP do domínio: $DOMAIN_IP"
        echo ""
        read -p "Continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Configuração cancelada"
        fi
    else
        log "✅ Domínio configurado corretamente"
    fi
}

install_dependencies() {
    log "📦 Instalando dependências..."
    
    # Atualizar sistema
    apt update -qq
    
    # Instalar Docker se não existir
    if ! command -v docker &> /dev/null; then
        log "🐳 Instalando Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        systemctl enable docker
        systemctl start docker
    fi
    
    # Instalar Docker Compose se não existir
    if ! command -v docker-compose &> /dev/null; then
        log "🐙 Instalando Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Instalar certbot
    if ! command -v certbot &> /dev/null; then
        log "🔒 Instalando Certbot..."
        apt install -y certbot
    fi
    
    log "✅ Dependências instaladas"
}

create_directories() {
    log "📁 Criando estrutura de diretórios..."
    
    mkdir -p /opt/n8n-production/{ssl,nginx}
    cd /opt/n8n-production
    
    log "✅ Diretórios criados"
}

create_docker_compose() {
    log "🐳 Criando docker-compose.yml para produção..."
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: n8n-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - n8n
    networks:
      - n8n-network
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M

  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=\${N8N_PASSWORD:-changeme123}
      - N8N_HOST=\${N8N_HOST:-localhost}
      - N8N_PORT=5678
      - WEBHOOK_URL=https://$DOMAIN
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - N8N_LOG_LEVEL=info
      - N8N_METRICS=true
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      mode: replicated
      replicas: $N8N_INSTANCES
      resources:
        limits:
          memory: 400M
        reservations:
          memory: 256M

networks:
  n8n-network:
    driver: bridge

volumes:
  n8n_data:
    driver: local
EOF

    log "✅ docker-compose.yml criado"
}

create_nginx_config() {
    log "🌐 Criando configuração do nginx..."
    
    cat > nginx/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Log format
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 16M;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;
    
    # Upstream para load balancing
    upstream n8n_backend {
        least_conn;
        server n8n_n8n_1:5678 max_fails=3 fail_timeout=30s;
        server n8n_n8n_2:5678 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }
    
    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $DOMAIN;
        
        # Let's Encrypt challenge
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        # Redirect everything else to HTTPS
        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }
    
    # HTTPS server
    server {
        listen 443 ssl;
        http2 on;
        server_name $DOMAIN;
        
        # SSL configuration
        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:50m;
        ssl_session_tickets off;
        
        # Modern configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        
        # HSTS
        add_header Strict-Transport-Security "max-age=63072000" always;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Referrer-Policy "strict-origin-when-cross-origin";
        
        # Main location
        location / {
            proxy_pass http://n8n_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            
            # Rate limiting
            limit_req zone=api burst=20 nodelay;
        }
        
        # API endpoints with stricter rate limiting
        location /rest/login {
            proxy_pass http://n8n_backend;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            limit_req zone=login burst=5 nodelay;
        }
        
        # Health check endpoint
        location /health {
            proxy_pass http://n8n_backend/health;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
        }
    }
}
EOF

    log "✅ Configuração do nginx criada"
}

generate_ssl_certificate() {
    log "🔒 Gerando certificado SSL com Let's Encrypt..."
    
    # Parar nginx temporariamente se estiver rodando
    systemctl stop nginx 2>/dev/null || true
    
    # Gerar certificado
    certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email $EMAIL \
        --domains $DOMAIN
    
    if [ $? -ne 0 ]; then
        error "Falha ao gerar certificado SSL"
    fi
    
    log "✅ Certificado SSL gerado"
}

setup_certbot_renewal() {
    log "🔄 Configurando renovação automática do certificado..."
    
    # Criar script de renovação
    cat > /usr/local/bin/renew-ssl.sh << EOF
#!/bin/bash
certbot renew --quiet
if [ \$? -eq 0 ]; then
    docker-compose -f /opt/n8n-production/docker-compose.yml exec nginx nginx -s reload
fi
EOF
    
    chmod +x /usr/local/bin/renew-ssl.sh
    
    # Adicionar ao crontab
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/local/bin/renew-ssl.sh") | crontab -
    
    log "✅ Renovação automática configurada"
}

create_env_file() {
    log "⚙️  Criando arquivo de ambiente..."
    
    # Gerar senha aleatória se não definida
    N8N_PASSWORD=${N8N_PASSWORD:-$(openssl rand -base64 32)}
    
    cat > .env << EOF
# Configurações do n8n
N8N_PASSWORD=$N8N_PASSWORD
N8N_HOST=$DOMAIN

# Configurações do domínio
DOMAIN=$DOMAIN
EMAIL=$EMAIL

# Número de instâncias
N8N_INSTANCES=$N8N_INSTANCES
EOF
    
    chmod 600 .env
    
    log "✅ Arquivo .env criado"
    log "🔑 Senha do n8n: $N8N_PASSWORD"
}

start_services() {
    log "🚀 Iniciando serviços..."
    
    # Parar serviços existentes se houver
    docker-compose down 2>/dev/null || true
    
    # Iniciar serviços
    docker-compose up -d
    
    if [ $? -ne 0 ]; then
        error "Falha ao iniciar serviços"
    fi
    
    log "✅ Serviços iniciados"
}

wait_for_services() {
    log "⏳ Aguardando serviços ficarem prontos..."
    
    # Aguardar nginx
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -s -k https://$DOMAIN/health >/dev/null 2>&1; then
            break
        fi
        sleep 2
        timeout=$((timeout-2))
    done
    
    if [ $timeout -le 0 ]; then
        warn "Timeout aguardando serviços. Verificando status..."
        docker-compose ps
        docker-compose logs --tail=20
    else
        log "✅ Serviços prontos"
    fi
}

run_tests() {
    log "🧪 Executando testes de conectividade..."
    
    # Teste HTTP redirect
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN)
    if [ "$HTTP_STATUS" = "301" ]; then
        log "✅ HTTP redirect: OK"
    else
        warn "HTTP redirect retornou: $HTTP_STATUS"
    fi
    
    # Teste HTTPS
    HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN)
    if [ "$HTTPS_STATUS" = "200" ]; then
        log "✅ HTTPS: OK"
    else
        warn "HTTPS retornou: $HTTPS_STATUS"
    fi
    
    # Teste SSL
    if openssl s_client -connect $DOMAIN:443 -servername $DOMAIN </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
        log "✅ Certificado SSL: Válido"
    else
        warn "Certificado SSL pode ter problemas"
    fi
}

create_management_scripts() {
    log "📝 Criando scripts de gerenciamento..."
    
    # Script de status
    cat > status.sh << 'EOF'
#!/bin/bash
echo "🐳 Status dos containers:"
docker-compose ps
echo ""
echo "📊 Uso de recursos:"
docker stats --no-stream
echo ""
echo "🔒 Status do certificado SSL:"
certbot certificates
EOF
    
    # Script de logs
    cat > logs.sh << 'EOF'
#!/bin/bash
echo "📋 Logs dos serviços:"
docker-compose logs -f --tail=50
EOF
    
    # Script de backup
    cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/n8n-backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
echo "💾 Criando backup em $BACKUP_DIR..."
docker-compose exec -T n8n tar czf - /home/node/.n8n > $BACKUP_DIR/n8n-data.tar.gz
cp .env $BACKUP_DIR/
cp docker-compose.yml $BACKUP_DIR/
echo "✅ Backup criado em $BACKUP_DIR"
EOF
    
    # Script de update
    cat > update.sh << 'EOF'
#!/bin/bash
echo "🔄 Atualizando n8n..."
docker-compose pull
docker-compose up -d
echo "✅ n8n atualizado"
EOF
    
    chmod +x *.sh
    
    log "✅ Scripts de gerenciamento criados"
}

show_summary() {
    log "🎉 Deploy concluído com sucesso!"
    echo ""
    echo "======================================"
    echo "📋 RESUMO DO DEPLOY"
    echo "======================================"
    echo ""
    echo "🌐 URL de acesso: https://$DOMAIN"
    echo "👤 Usuário: admin"
    echo "🔑 Senha: $N8N_PASSWORD"
    echo ""
    echo "📂 Diretório: /opt/n8n-production"
    echo "🐳 Instâncias n8n: $N8N_INSTANCES"
    echo ""
    echo "🔧 Scripts disponíveis:"
    echo "   ./status.sh    - Ver status dos serviços"
    echo "   ./logs.sh      - Ver logs em tempo real"
    echo "   ./backup.sh    - Criar backup"
    echo "   ./update.sh    - Atualizar n8n"
    echo ""
    echo "🔒 Certificado SSL: Configurado (renovação automática)"
    echo "📧 Email para avisos: $EMAIL"
    echo ""
    echo "⚠️  IMPORTANTE:"
    echo "   - Salve a senha do n8n em local seguro"
    echo "   - Configure firewall se necessário (portas 80, 443)"
    echo "   - Monitore os logs regularmente"
    echo ""
    echo "======================================"
}

# ================================
# EXECUÇÃO PRINCIPAL
# ================================

main() {
    echo ""
    echo "🚀 Deploy Automático do n8n em Produção"
    echo "========================================"
    echo ""
    echo "📋 Configurações:"
    echo "   🌐 Domínio: $DOMAIN"
    echo "   📧 Email: $EMAIL"
    echo "   🐳 Instâncias: $N8N_INSTANCES"
    echo ""
    
    # Validações iniciais
    if [ "$EMAIL" = "seu-email@exemplo.com" ]; then
        error "Por favor, configure um email válido no início do script"
    fi
    
    read -p "Continuar com o deploy? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deploy cancelado"
        exit 0
    fi
    
    # Verificações
    check_root
    check_domain
    
    # Instalação e configuração
    install_dependencies
    create_directories
    create_docker_compose
    create_nginx_config
    generate_ssl_certificate
    setup_certbot_renewal
    create_env_file
    start_services
    wait_for_services
    run_tests
    create_management_scripts
    
    # Resumo final
    show_summary
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
