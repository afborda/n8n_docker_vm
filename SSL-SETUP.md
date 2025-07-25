# Configuração SSL para n8n.abnerfonseca.com.br

Este guia vai configurar SSL/TLS com certificados Let's Encrypt para seu domínio.

## Pré-requisitos

1. **DNS configurado**: O domínio `n8n.abnerfonseca.com.br` deve apontar para o IP da sua VM
2. **Portas abertas**: 80 e 443 devem estar liberadas no firewall
3. **Acesso root**: Scripts devem ser executados como root

## Verificar DNS

Antes de começar, verifique se o DNS está correto:

```bash
# Na sua VM, verificar IP atual
curl ifconfig.me

# Verificar para onde o domínio aponta
nslookup n8n.abnerfonseca.com.br
```

Os IPs devem ser iguais!

## Instalação SSL - Método Simples

### 1. Dar permissões aos scripts

```bash
chmod +x setup-ssl-simple.sh
chmod +x renew-ssl.sh
```

### 2. Executar configuração SSL

```bash
sudo ./setup-ssl-simple.sh
```

Este script vai:
- Verificar DNS
- Instalar certbot
- Parar nginx temporariamente
- Gerar certificado SSL
- Copiar certificados para ./ssl/

### 3. Usar configuração SSL

Após gerar os certificados, use os arquivos SSL:

```bash
# Parar containers atuais
docker-compose down

# Usar configuração SSL
docker-compose -f docker-compose-ssl.yml up -d
```

### 4. Testar SSL

```bash
# Testar se está funcionando
curl -I https://n8n.abnerfonseca.com.br

# Verificar certificado
openssl s_client -connect n8n.abnerfonseca.com.br:443 -servername n8n.abnerfonseca.com.br
```

## Renovação Automática

### Configurar cron para renovação

```bash
# Editar crontab como root
sudo crontab -e

# Adicionar linha (roda todo dia às 3h da manhã)
0 3 * * * /caminho/para/seu/projeto/renew-ssl.sh
```

### Testar renovação manual

```bash
sudo ./renew-ssl.sh
```

## Troubleshooting

### DNS não resolve
- Verifique se o registro A aponta para o IP correto
- Aguarde propagação DNS (pode levar até 24h)

### Erro "port 80 already in use"
```bash
# Verificar o que está usando porta 80
sudo netstat -tlnp | grep :80

# Parar nginx do docker
docker-compose stop nginx
```

### Certificado expirado
```bash
# Verificar validade
openssl x509 -in ./ssl/fullchain.pem -text -noout | grep "Not After"

# Renovar manualmente
sudo ./renew-ssl.sh
```

### Nginx não aceita certificados
```bash
# Verificar permissões
ls -la ./ssl/

# Corrigir se necessário
sudo chmod 644 ./ssl/*.pem
```

## Estrutura de Arquivos

Após configuração, você terá:

```
.
├── docker-compose.yml          # Original (HTTP)
├── docker-compose-ssl.yml      # Versão SSL (HTTPS)
├── nginx.conf                  # Configuração original
├── nginx-ssl.conf              # Configuração SSL
├── setup-ssl-simple.sh         # Script de instalação
├── renew-ssl.sh               # Script de renovação
├── ssl/                       # Certificados
│   ├── fullchain.pem
│   └── privkey.pem
└── .env                       # Variáveis (atualizar WEBHOOK_URL)
```

## Configurações importantes

### .env para SSL

Atualize seu `.env`:

```bash
WEBHOOK_URL=https://n8n.abnerfonseca.com.br
N8N_ENCRYPTION_KEY=sua-chave-super-secreta-aqui
TIMEZONE=America/Sao_Paulo
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=sua-senha-segura
```

### Otimizações para e2-micro

O `docker-compose-ssl.yml` está otimizado para VM pequena:
- **2 instâncias n8n** (em vez de 3)
- **400MB por instância** (em vez de 280MB)
- **Total: ~900MB** (deixa margem para SO)

## Monitoramento

```bash
# Ver status
docker-compose -f docker-compose-ssl.yml ps

# Ver recursos
docker stats

# Logs nginx
docker-compose -f docker-compose-ssl.yml logs nginx

# Verificar SSL
curl -I https://n8n.abnerfonseca.com.br/health
```

## Backup

Importante fazer backup dos certificados:

```bash
# Backup certificados
sudo tar -czf ssl-backup-$(date +%Y%m%d).tar.gz /etc/letsencrypt/ ./ssl/
```
