# 🚨 CORREÇÃO URGENTE - Erro nginx upstream

## ❌ Problema identificado:
```
[emerg] 1#1: host not found in upstream "n8n_n8n_1:5678"
```

## 🔍 Causa:
O nginx está tentando se conectar a containers com nomes incorretos. Com `docker-compose` e `deploy.replicas`, o Docker faz load balancing automático para o serviço `n8n`.

## 🔧 SOLUÇÃO RÁPIDA:

### No seu servidor de produção:

```bash
# 1. Ir para o diretório de produção
cd /opt/n8n-production

# 2. Fazer backup da configuração
cp nginx/nginx.conf nginx/nginx.conf.backup

# 3. Corrigir o arquivo nginx.conf
sudo nano nginx/nginx.conf

# 4. Encontrar estas linhas (aprox. linha 243-244):
#    server n8n_n8n_1:5678 max_fails=3 fail_timeout=30s;
#    server n8n_n8n_2:5678 max_fails=3 fail_timeout=30s;

# 5. Substituir por:
#    server n8n:5678 max_fails=3 fail_timeout=30s;
#    (remover a segunda linha)

# 6. Reiniciar containers
docker-compose down
docker-compose up -d

# 7. Verificar se funcionou
docker-compose ps
curl -I https://n8n.abnerfonseca.com.br
```

## 🔧 SOLUÇÃO AUTOMÁTICA:

Se preferir, use o script de correção:

```bash
# 1. Fazer upload do arquivo fix-nginx-upstream.sh para o servidor

# 2. No servidor:
cd /opt/n8n-production
chmod +x fix-nginx-upstream.sh
sudo ./fix-nginx-upstream.sh
```

## ✅ Como deve ficar o upstream correto:

**ANTES (incorreto):**
```nginx
upstream n8n_backend {
    least_conn;
    server n8n_n8n_1:5678 max_fails=3 fail_timeout=30s;
    server n8n_n8n_2:5678 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

**DEPOIS (correto):**
```nginx
upstream n8n_backend {
    least_conn;
    server n8n:5678 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

## 🔍 Verificação final:

```bash
# Ver logs do nginx
docker-compose logs nginx

# Testar conectividade
curl -I https://n8n.abnerfonseca.com.br

# Status dos containers
docker-compose ps
```

## 💡 Por que isso aconteceu:

- Com `deploy.replicas: 2`, o Docker Compose cria múltiplas instâncias do serviço `n8n`
- O Docker faz load balancing automático internamente
- Não precisamos especificar containers individuais no nginx
- Basta usar o nome do serviço: `n8n:5678`

---

## 🚀 Após a correção:

✅ nginx conseguirá se conectar ao serviço n8n  
✅ Load balancing funcionará automaticamente  
✅ https://n8n.abnerfonseca.com.br estará acessível
