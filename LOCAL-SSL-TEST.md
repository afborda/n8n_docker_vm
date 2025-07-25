# Teste SSL Local - n8n-local.com

Este guia permite testar SSL localmente sem interferir na configuração do domínio de produção.

## 🎯 Objetivo

Testar HTTPS localmente usando:
- **Domínio**: `n8n-local.com` (fictício)
- **Certificados**: Auto-assinados (não confiáveis)
- **DNS**: Configurado via `/etc/hosts`
- **Acesso**: https://n8n-local.com

## 🚀 Setup Rápido

### Opção 1: Script Automático (Recomendado)

```bash
# Setup completo em um comando
./setup-local-ssl-complete.sh
```

Este script faz tudo automaticamente:
1. Gera certificados auto-assinados
2. Configura /etc/hosts
3. Inicia containers SSL
4. Testa conectividade

### Opção 2: Setup Manual

```bash
# 1. Gerar certificados locais
./generate-local-ssl.sh

# 2. Configurar hosts (precisa sudo)
sudo ./setup-local-hosts.sh

# 3. Iniciar containers
docker-compose -f docker-compose-ssl.yml up -d
```

## 🧪 Testando

### Comandos de teste

```bash
# DNS
ping n8n-local.com
nslookup n8n-local.com

# HTTP redirect
curl -I http://n8n-local.com

# HTTPS (ignorando certificado)
curl -k -I https://n8n-local.com/health

# Ver logs
docker-compose -f docker-compose-ssl.yml logs nginx
```

### Navegador

1. Acesse: https://n8n-local.com
2. Clique em "Avançado" (certificado não confiável)
3. Clique em "Continuar para n8n-local.com"
4. Login: admin / admin123

## 📁 Arquivos Gerados

```
ssl/
├── fullchain.pem      # Produção (Let's Encrypt)
├── privkey.pem        # Produção (Let's Encrypt)
├── local-cert.pem     # Local (auto-assinado)
└── local-key.pem      # Local (auto-assinado)
```

## 🔧 Configuração nginx

O `nginx-ssl.conf` tem dois server blocks:

### Produção
```nginx
server {
    listen 443 ssl http2;
    server_name n8n.abnerfonseca.com.br;
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    # Configurações de segurança rigorosas
}
```

### Local
```nginx
server {
    listen 443 ssl http2;
    server_name n8n-local.com;
    ssl_certificate /etc/nginx/ssl/local-cert.pem;
    ssl_certificate_key /etc/nginx/ssl/local-key.pem;
    # Configurações mais relaxadas para teste
}
```

## 🔍 Diferenças Local vs Produção

| Aspecto | Produção | Local |
|---------|----------|-------|
| **Domínio** | n8n.abnerfonseca.com.br | n8n-local.com |
| **Certificado** | Let's Encrypt (confiável) | Auto-assinado |
| **DNS** | Registro público | /etc/hosts |
| **HSTS** | Habilitado | Desabilitado |
| **Headers** | Rigorosos | Relaxados |
| **Acesso** | Internet | Apenas local |

## 🛠️ Troubleshooting

### DNS não resolve
```bash
# Verificar /etc/hosts
cat /etc/hosts | grep n8n-local.com

# Adicionar manualmente se necessário
echo "127.0.0.1 n8n-local.com" | sudo tee -a /etc/hosts
```

### Certificado não funciona
```bash
# Verificar certificados
ls -la ./ssl/local-*

# Regerar se necessário
./generate-local-ssl.sh
```

### Nginx não inicia
```bash
# Ver logs
docker-compose -f docker-compose-ssl.yml logs nginx

# Verificar sintaxe
docker run --rm -v $(pwd)/nginx-ssl.conf:/etc/nginx/nginx.conf nginx:alpine nginx -t
```

### Container não acessa certificados
```bash
# Verificar permissões
ls -la ./ssl/

# Corrigir se necessário
chmod 644 ./ssl/local-cert.pem
chmod 600 ./ssl/local-key.pem
```

## 🗑️ Limpeza

### Parar containers
```bash
docker-compose -f docker-compose-ssl.yml down
```

### Remover certificados locais
```bash
rm -f ./ssl/local-cert.pem ./ssl/local-key.pem
```

### Remover entrada do hosts
```bash
sudo sed -i '/n8n-local.com/d' /etc/hosts
```

### Limpeza completa
```bash
# Script de limpeza
cat > cleanup-local-ssl.sh << 'EOF'
#!/bin/bash
echo "🧹 Limpando configuração SSL local..."
docker-compose -f docker-compose-ssl.yml down
sudo sed -i '/n8n-local.com/d' /etc/hosts
rm -f ./ssl/local-cert.pem ./ssl/local-key.pem
echo "✅ Limpeza concluída!"
EOF

chmod +x cleanup-local-ssl.sh
./cleanup-local-ssl.sh
```

## 💡 Dicas

### Confiança no certificado (opcional)

Para evitar avisos do navegador:

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /System/Library/Keychains/SystemRootCertificates.keychain ./ssl/local-cert.pem
```

**Linux:**
```bash
sudo cp ./ssl/local-cert.pem /usr/local/share/ca-certificates/n8n-local.crt
sudo update-ca-certificates
```

### Teste em diferentes dispositivos

Para testar em outros dispositivos da rede local:

1. **Descobrir IP da máquina:**
   ```bash
   hostname -I | awk '{print $1}'
   ```

2. **Adicionar em outros dispositivos:**
   ```
   # No /etc/hosts do outro dispositivo
   192.168.1.100 n8n-local.com  # Substitua pelo IP real
   ```

3. **Copiar certificado e instalar** (para evitar avisos)

### Monitoramento

```bash
# Status em tempo real
watch 'docker-compose -f docker-compose-ssl.yml ps && echo && curl -k -s -I https://n8n-local.com/health'

# Logs em tempo real
docker-compose -f docker-compose-ssl.yml logs -f nginx
```
