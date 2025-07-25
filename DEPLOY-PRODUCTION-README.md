# 🚀 Deploy Automático n8n - Produção

Este script automatiza completamente o deploy do n8n em produção com SSL, nginx e otimização para VM e2-micro.

## 📋 O que o script faz automaticamente:

✅ **Instala dependências**: Docker, Docker Compose, Certbot  
✅ **Configura SSL**: Let's Encrypt com renovação automática  
✅ **Configura nginx**: Load balancer com otimizações de segurança  
✅ **Deploy n8n**: Múltiplas instâncias com configuração otimizada  
✅ **Cria scripts**: Gerenciamento, backup, logs, status  
✅ **Testes**: Verificação completa de funcionamento  

## 🚀 Como usar:

### 1. **Preparar o script**
```bash
# Baixar o arquivo deploy-production.sh
# Editar as configurações no início do arquivo:
```

```bash
DOMAIN="n8n.abnerfonseca.com.br"    # Seu domínio
EMAIL="seu-email@gmail.com"         # Seu email (OBRIGATÓRIO)
N8N_INSTANCES=2                      # Número de instâncias (2 recomendado para e2-micro)
```

### 2. **Executar o deploy**
```bash
# Dar permissão de execução
chmod +x deploy-production.sh

# Executar como root (vai pedir confirmação)
sudo ./deploy-production.sh
```

### 3. **Aguardar conclusão**
O script irá:
- ✅ Verificar se o domínio aponta para o servidor
- ✅ Instalar todas as dependências automaticamente
- ✅ Gerar certificado SSL via Let's Encrypt
- ✅ Configurar nginx com segurança
- ✅ Iniciar n8n com load balancing
- ✅ Executar testes de conectividade
- ✅ Mostrar resumo com credenciais

## 📱 Após o deploy:

### **Acesso ao n8n:**
```
URL: https://n8n.abnerfonseca.com.br
Usuário: admin
Senha: [gerada automaticamente e mostrada no final]
```

### **Scripts de gerenciamento criados:**
```bash
cd /opt/n8n-production

./status.sh    # Ver status dos containers e recursos
./logs.sh      # Ver logs em tempo real
./backup.sh    # Criar backup completo
./update.sh    # Atualizar n8n para última versão
```

### **Comandos Docker Compose:**
```bash
cd /opt/n8n-production

# Ver status
docker-compose ps

# Ver logs
docker-compose logs -f

# Reiniciar serviços
docker-compose restart

# Parar serviços
docker-compose down

# Iniciar serviços
docker-compose up -d
```

## ⚙️ Configurações automáticas:

### **Otimizações para e2-micro (1GB RAM):**
- 🐳 nginx: 128MB limite, 64MB reservado
- 🐳 n8n (2 instâncias): 400MB limite, 256MB reservado cada
- 🔧 Gzip habilitado para reduzir tráfego
- 🔧 Rate limiting configurado
- 🔧 Keepalive otimizado

### **Segurança configurada:**
- 🔒 SSL/TLS com certificados Let's Encrypt
- 🔒 Headers de segurança (HSTS, XSS Protection, etc.)
- 🔒 Rate limiting em endpoints críticos
- 🔒 Renovação automática de certificados

### **Load Balancing:**
- ⚖️ nginx com algoritmo least_conn
- ⚖️ Health checks automáticos
- ⚖️ Failover automático entre instâncias

## 🔧 Personalização:

Se quiser modificar após o deploy:

### **Alterar número de instâncias:**
```bash
cd /opt/n8n-production
# Editar docker-compose.yml, linha "replicas: 2"
docker-compose up -d --scale n8n=3  # Para 3 instâncias
```

### **Alterar configurações nginx:**
```bash
# Editar arquivo
nano /opt/n8n-production/nginx/nginx.conf

# Recarregar configuração
docker-compose exec nginx nginx -s reload
```

### **Ver configurações atuais:**
```bash
cd /opt/n8n-production
cat .env  # Ver variáveis de ambiente
```

## 🆘 Solução de problemas:

### **Se algo der errado durante o deploy:**
```bash
# Ver logs do script
sudo ./deploy-production.sh 2>&1 | tee deploy.log

# Verificar status após deploy
cd /opt/n8n-production
./status.sh
```

### **Se o n8n não responder:**
```bash
cd /opt/n8n-production
docker-compose ps          # Ver status containers
docker-compose logs n8n    # Ver logs do n8n
docker-compose restart     # Reiniciar tudo
```

### **Se SSL não funcionar:**
```bash
# Verificar certificado
sudo certbot certificates

# Renovar manualmente
sudo certbot renew

# Verificar nginx
docker-compose logs nginx
```

## 📊 Monitoramento:

### **Verificar saúde dos serviços:**
```bash
# Status geral
curl -I https://n8n.abnerfonseca.com.br/health

# Status detalhado
cd /opt/n8n-production
./status.sh
```

### **Verificar recursos:**
```bash
# Uso de CPU/Memória
docker stats

# Espaço em disco
df -h
```

## 🔄 Backup e Restore:

### **Backup automático:**
```bash
cd /opt/n8n-production
./backup.sh  # Cria backup em /opt/n8n-backups/
```

### **Restore manual:**
```bash
# Parar serviços
docker-compose down

# Restaurar dados
docker run --rm -v n8n-production_n8n_data:/data -v /caminho/backup:/backup alpine \
  tar xzf /backup/n8n-data.tar.gz -C /data

# Reiniciar
docker-compose up -d
```

---

## ⚡ Execução rápida (TL;DR):

```bash
# 1. Editar configurações no script
nano deploy-production.sh

# 2. Executar
sudo ./deploy-production.sh

# 3. Acessar
# https://n8n.abnerfonseca.com.br
# usuário: admin / senha: [mostrada no final]
```

🎉 **Pronto! n8n rodando em produção com SSL!**
