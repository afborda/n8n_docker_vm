#!/bin/bash

# Script para verificar se o servidor está pronto para o deploy de produção

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="n8n.abnerfonseca.com.br"

echo -e "${BLUE}🔍 Verificação de Pré-requisitos para Deploy${NC}"
echo "=================================================="
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Execute como root: sudo $0${NC}"
    exit 1
fi

# Função para verificar item
check_item() {
    local description="$1"
    local status="$2"
    
    if [ "$status" = "ok" ]; then
        echo -e "${GREEN}✅ $description${NC}"
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠️  $description${NC}"
    else
        echo -e "${RED}❌ $description${NC}"
    fi
}

# 1. Verificar sistema operacional
echo "🖥️  Sistema Operacional:"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "   OS: $PRETTY_NAME"
    if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
        check_item "Sistema suportado" "ok"
    else
        check_item "Sistema pode não ser totalmente suportado" "warn"
    fi
else
    check_item "Sistema não identificado" "error"
fi
echo ""

# 2. Verificar recursos do sistema
echo "💾 Recursos do Sistema:"
TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
TOTAL_CPU=$(nproc)
DISK_SPACE=$(df / | awk 'NR==2 {print $4}')

echo "   RAM: ${TOTAL_RAM}MB"
echo "   CPU: ${TOTAL_CPU} cores"
echo "   Disco livre: $((DISK_SPACE/1024))MB"

if [ "$TOTAL_RAM" -ge 1000 ]; then
    check_item "RAM suficiente (≥1GB)" "ok"
else
    check_item "RAM pode ser insuficiente (<1GB)" "warn"
fi

if [ "$TOTAL_CPU" -ge 1 ]; then
    check_item "CPU adequada" "ok"
else
    check_item "CPU insuficiente" "error"
fi

if [ "$DISK_SPACE" -gt 2097152 ]; then  # 2GB em KB
    check_item "Espaço em disco adequado (>2GB)" "ok"
else
    check_item "Pouco espaço em disco (<2GB)" "warn"
fi
echo ""

# 3. Verificar conectividade de rede
echo "🌐 Conectividade:"
if ping -c 1 google.com >/dev/null 2>&1; then
    check_item "Conexão com internet" "ok"
else
    check_item "Sem conexão com internet" "error"
fi

# Verificar IP público
PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null)
if [ -n "$PUBLIC_IP" ]; then
    echo "   IP público: $PUBLIC_IP"
    check_item "IP público detectado" "ok"
else
    check_item "Não foi possível detectar IP público" "warn"
fi
echo ""

# 4. Verificar DNS do domínio
echo "🔍 Verificação do Domínio:"
echo "   Domínio configurado: $DOMAIN"

DOMAIN_IP=$(dig +short $DOMAIN @8.8.8.8 2>/dev/null | tail -n1)
if [ -n "$DOMAIN_IP" ]; then
    echo "   IP do domínio: $DOMAIN_IP"
    if [ "$DOMAIN_IP" = "$PUBLIC_IP" ]; then
        check_item "Domínio aponta para este servidor" "ok"
    else
        check_item "Domínio NÃO aponta para este servidor" "warn"
        echo "      ↳ Configure o DNS para apontar $DOMAIN para $PUBLIC_IP"
    fi
else
    check_item "Domínio não resolve ou não existe" "error"
fi
echo ""

# 5. Verificar portas necessárias
echo "🔌 Portas Necessárias:"
check_port() {
    local port=$1
    local service=$2
    
    if ss -tlnp | grep ":$port " >/dev/null; then
        check_item "Porta $port ($service) está ocupada" "warn"
        echo "      ↳ Serviço usando a porta: $(ss -tlnp | grep ":$port " | awk '{print $7}' | head -1)"
    else
        check_item "Porta $port ($service) livre" "ok"
    fi
}

check_port 80 "HTTP"
check_port 443 "HTTPS"
echo ""

# 6. Verificar firewall
echo "🔥 Firewall:"
if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(ufw status | head -1)
    echo "   UFW: $UFW_STATUS"
    if echo "$UFW_STATUS" | grep -q "active"; then
        if ufw status | grep -q "80/tcp\|443/tcp"; then
            check_item "UFW configurado com portas HTTP/HTTPS" "ok"
        else
            check_item "UFW ativo mas sem portas HTTP/HTTPS liberadas" "warn"
            echo "      ↳ Execute: ufw allow 80 && ufw allow 443"
        fi
    else
        check_item "UFW inativo" "ok"
    fi
elif command -v iptables >/dev/null 2>&1; then
    if iptables -L | grep -q "DROP\|REJECT" && ! iptables -L | grep -q "dpt:http\|dpt:https"; then
        check_item "iptables pode estar bloqueando portas HTTP/HTTPS" "warn"
    else
        check_item "iptables parece liberado" "ok"
    fi
else
    check_item "Nenhum firewall detectado" "ok"
fi
echo ""

# 7. Verificar dependências existentes
echo "📦 Dependências:"
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
    echo "   Docker: $DOCKER_VERSION"
    check_item "Docker já instalado" "ok"
else
    check_item "Docker não instalado (será instalado automaticamente)" "ok"
fi

if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | sed 's/,//')
    echo "   Docker Compose: $COMPOSE_VERSION"
    check_item "Docker Compose já instalado" "ok"
else
    check_item "Docker Compose não instalado (será instalado automaticamente)" "ok"
fi

if command -v certbot >/dev/null 2>&1; then
    CERTBOT_VERSION=$(certbot --version 2>&1 | cut -d' ' -f2)
    echo "   Certbot: $CERTBOT_VERSION"
    check_item "Certbot já instalado" "ok"
else
    check_item "Certbot não instalado (será instalado automaticamente)" "ok"
fi
echo ""

# 8. Verificar usuário e permissões
echo "👤 Usuário e Permissões:"
if [ "$(id -u)" = "0" ]; then
    check_item "Executando como root" "ok"
else
    check_item "Não executando como root" "error"
fi

if [ -w "/opt" ]; then
    check_item "Permissão de escrita em /opt" "ok"
else
    check_item "Sem permissão de escrita em /opt" "error"
fi
echo ""

# 9. Verificar atualizações do sistema
echo "🔄 Sistema:"
if [ -f /var/run/reboot-required ]; then
    check_item "Sistema precisa ser reiniciado" "warn"
    echo "      ↳ Execute: sudo reboot"
else
    check_item "Sistema não precisa de reinicialização" "ok"
fi

# Verificar se há atualizações pendentes
if command -v apt >/dev/null 2>&1; then
    apt update -qq 2>/dev/null
    UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ "$UPDATES" -gt 1 ]; then
        check_item "$((UPDATES-1)) atualizações disponíveis" "warn"
        echo "      ↳ Recomendado: sudo apt upgrade"
    else
        check_item "Sistema atualizado" "ok"
    fi
fi
echo ""

# Resumo final
echo "📋 RESUMO:"
echo "=========="
echo ""
if [ -z "$DOMAIN_IP" ] || [ "$DOMAIN_IP" != "$PUBLIC_IP" ]; then
    echo -e "${RED}❌ AÇÃO NECESSÁRIA:${NC}"
    echo "   Configure o DNS do domínio $DOMAIN para apontar para $PUBLIC_IP"
    echo ""
fi

if [ "$TOTAL_RAM" -lt 1000 ]; then
    echo -e "${YELLOW}⚠️  AVISO:${NC}"
    echo "   RAM baixa ($TOTAL_RAM MB). Considere aumentar para pelo menos 1GB"
    echo ""
fi

echo -e "${GREEN}✅ PRÓXIMOS PASSOS:${NC}"
echo "   1. Configure o DNS se necessário"
echo "   2. Edite o arquivo deploy-production.sh com suas configurações"
echo "   3. Execute: sudo ./deploy-production.sh"
echo ""

if [ "$DOMAIN_IP" = "$PUBLIC_IP" ] && [ "$TOTAL_RAM" -ge 1000 ]; then
    echo -e "${GREEN}🎉 Servidor pronto para deploy!${NC}"
else
    echo -e "${YELLOW}⚠️  Resolva os itens acima antes do deploy${NC}"
fi
