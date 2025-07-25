# 🎯 DEPLOY PRODUÇÃO - ARQUIVOS CRIADOS

## 📁 Arquivos de Deploy Completo:

### 🚀 **deploy-production.sh** (PRINCIPAL)
- **Função**: Script único que automatiza TUDO
- **O que faz**: 
  - ✅ Instala Docker, Docker Compose, Certbot
  - ✅ Configura SSL Let's Encrypt automaticamente
  - ✅ Cria nginx com load balancing otimizado
  - ✅ Deploy n8n com múltiplas instâncias
  - ✅ Configurações de segurança e performance
  - ✅ Scripts de gerenciamento
  - ✅ Testes de conectividade
  - ✅ Backup automático e renovação SSL

### 🔍 **check-prerequisites.sh**
- **Função**: Verifica se o servidor está pronto
- **O que verifica**:
  - ✅ Recursos (RAM, CPU, disk)
  - ✅ DNS configurado corretamente
  - ✅ Portas livres (80, 443)
  - ✅ Firewall
  - ✅ Conectividade internet
  - ✅ Sistema atualizado

### 📖 **DEPLOY-PRODUCTION-README.md**
- **Função**: Manual completo de uso
- **Conteúdo**: Instruções passo a passo, troubleshooting, customização

---

## 🚀 COMO USAR (Passo a Passo):

### **1. Preparação no servidor:**
```bash
# Fazer upload dos arquivos para o servidor
scp deploy-production.sh usuario@servidor:/tmp/
scp check-prerequisites.sh usuario@servidor:/tmp/
```

### **2. Configurar o script:**
```bash
# Editar configurações no início do arquivo
nano deploy-production.sh

# Alterar estas linhas:
DOMAIN="n8n.abnerfonseca.com.br"     # Seu domínio
EMAIL="seu-email@gmail.com"          # SEU EMAIL REAL
N8N_INSTANCES=2                       # 2 para e2-micro
```

### **3. Verificar pré-requisitos:**
```bash
# Executar verificação
sudo ./check-prerequisites.sh
```

### **4. Deploy automático:**
```bash
# Executar deploy completo
sudo ./deploy-production.sh
```

### **5. Resultado:**
- ✅ n8n rodando em: `https://n8n.abnerfonseca.com.br`
- ✅ SSL configurado automaticamente
- ✅ Senha gerada e mostrada no final
- ✅ Scripts de gerenciamento criados

---

## 📋 O QUE O SCRIPT DE DEPLOY FAZ:

### **Instalação Automática:**
- 🐳 Docker + Docker Compose
- 🔒 Certbot (Let's Encrypt)
- 📦 Dependências do sistema

### **Configuração SSL:**
- 🔐 Gera certificado Let's Encrypt
- 🔄 Configura renovação automática
- 🛡️ Headers de segurança HTTPS

### **nginx Load Balancer:**
- ⚖️ Balanceamento entre instâncias n8n
- 🔒 Terminação SSL
- 🚀 Otimizações de performance
- 🛡️ Rate limiting e segurança

### **n8n Otimizado:**
- 🐳 Múltiplas instâncias (escalonável)
- 💾 Limites de memória para e2-micro
- 🔧 Configuração de produção
- 💾 Volume persistente para dados

### **Scripts de Gerenciamento:**
- 📊 `status.sh` - Ver status e recursos
- 📋 `logs.sh` - Logs em tempo real
- 💾 `backup.sh` - Backup completo
- 🔄 `update.sh` - Atualizar n8n

### **Testes Automáticos:**
- 🌐 Conectividade HTTP/HTTPS
- 🔒 Validação SSL
- 🏥 Health checks

---

## ⚙️ CONFIGURAÇÕES APLICADAS:

### **Otimização e2-micro (1GB RAM):**
```yaml
nginx: 128MB limite (64MB reservado)
n8n-1: 400MB limite (256MB reservado)  
n8n-2: 400MB limite (256MB reservado)
Total: ~800MB (deixa 200MB para sistema)
```

### **Segurança:**
- 🔒 SSL/TLS moderno (TLS 1.2+)
- 🛡️ Headers de segurança (HSTS, XSS, etc)
- 🚦 Rate limiting configurado
- 🔐 Autenticação básica do n8n

### **Performance:**
- 🗜️ Gzip habilitado
- 🔄 Keepalive otimizado
- ⚡ HTTP/2 habilitado
- 📈 Load balancing least_conn

---

## 🎯 RESULTADO FINAL:

Após executar `sudo ./deploy-production.sh`:

### **✅ Funcionando:**
- 🌐 **URL**: https://n8n.abnerfonseca.com.br
- 👤 **Login**: admin
- 🔑 **Senha**: [gerada automaticamente]
- 🔒 **SSL**: Certificado válido Let's Encrypt
- ⚖️ **Load Balancer**: 2 instâncias n8n
- 🔄 **Auto-renovação**: Certificado SSL

### **✅ Monitoramento:**
```bash
cd /opt/n8n-production
./status.sh    # Status completo
./logs.sh      # Logs em tempo real
```

### **✅ Manutenção:**
```bash
./backup.sh    # Backup completo
./update.sh    # Atualizar n8n
```

---

## 🔧 CUSTOMIZAÇÃO PÓS-DEPLOY:

### **Alterar número de instâncias:**
```bash
cd /opt/n8n-production
# Editar docker-compose.yml, linha "replicas: 2"
docker-compose up -d --scale n8n=3
```

### **Ver configuração atual:**
```bash
cd /opt/n8n-production
cat .env                    # Variáveis
cat docker-compose.yml      # Configuração containers
cat nginx/nginx.conf        # Configuração nginx
```

### **Logs detalhados:**
```bash
docker-compose logs n8n     # Logs do n8n
docker-compose logs nginx   # Logs do nginx
```

---

## 🆘 TROUBLESHOOTING:

### **Se o deploy falhar:**
```bash
# Ver logs do script
sudo ./deploy-production.sh 2>&1 | tee deploy.log

# Verificar status
cd /opt/n8n-production && ./status.sh
```

### **Se SSL não funcionar:**
```bash
sudo certbot certificates           # Ver certificados
sudo certbot renew --dry-run       # Testar renovação
```

### **Se n8n não responder:**
```bash
cd /opt/n8n-production
docker-compose restart              # Reiniciar tudo
curl -I https://n8n.abnerfonseca.com.br/health  # Testar
```

---

## 🎉 RESUMO EXECUTIVO:

### **Para deploy imediato:**
1. ✏️  Editar `deploy-production.sh` (email + domínio)
2. 🔍 Executar `sudo ./check-prerequisites.sh`
3. 🚀 Executar `sudo ./deploy-production.sh`
4. 🎯 Acessar `https://n8n.abnerfonseca.com.br`

**Total: ~5-10 minutos para deploy completo!** 🚀
