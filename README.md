# n8n Escalável com Load Balancer

Este setup fornece uma configuração Docker Compose para executar n8n de forma escalável com nginx como load balancer.

## Arquitetura

- **nginx**: Load balancer na porta 8080
- **n8n**: Múltiplas instâncias escaláveis (padrão: 3 instâncias)

## Como usar

### 1. Iniciar os serviços

```bash
# Subir os containers
docker-compose up -d

# Verificar se os containers estão rodando
docker-compose ps
```

### 2. Escalar o n8n

```bash
# Escalar para 5 instâncias
docker-compose up -d --scale n8n=5

# Verificar as instâncias
docker-compose ps n8n
```

### 3. Acessar o n8n

- URL: http://localhost:8080
- Usuário: admin (configurável no .env)
- Senha: admin123 (configurável no .env)

### 4. Monitoramento

```bash
# Ver logs de todas as instâncias do n8n
docker-compose logs -f n8n

# Ver logs do nginx
docker-compose logs -f nginx

# Status do nginx
curl http://localhost:8080/nginx_status

# Health check
curl http://localhost:8080/health
```

### 5. Parar os serviços

```bash
# Parar todos os containers
docker-compose down

# Parar e remover volumes (cuidado: remove dados)
docker-compose down -v
```

## Configuração

### Variáveis de ambiente (.env)

- `WEBHOOK_URL`: URL base para webhooks
- `N8N_ENCRYPTION_KEY`: Chave de criptografia (MUDE para algo seguro)
- `TIMEZONE`: Fuso horário
- `N8N_BASIC_AUTH_ACTIVE`: Ativar autenticação básica
- `N8N_BASIC_AUTH_USER`: Usuário para login
- `N8N_BASIC_AUTH_PASSWORD`: Senha para login

### Recursos (VM e2-micro - 1GB RAM, 2 vCPUs)

O setup está otimizado para VMs pequenas:

- **n8n (3 instâncias)**: 280MB cada = 840MB total
- **nginx**: 80MB
- **Sistema reservado**: ~80MB

```bash
# Monitorar recursos
docker stats

# Ver detalhes de cada container
docker-compose top
```

### Escalonamento

Para alterar o número padrão de instâncias, edite o `docker-compose.yml`:

```yaml
deploy:
  replicas: 3  # Altere este número
```

Ou use o comando scale:

```bash
docker-compose up -d --scale n8n=<número_de_instâncias>
```

## Load Balancing

O nginx está configurado com:

- **Método**: Round-robin (padrão)
- **Health checks**: Verifica se as instâncias estão funcionando
- **Rate limiting**: 10 requests/segundo por IP
- **WebSocket support**: Para funcionalidades em tempo real
- **Timeouts apropriados**: Para operações longas

### Outros métodos de load balancing

Edite o `nginx.conf` e altere o upstream:

```nginx
upstream n8n_backend {
    # Para least connections
    least_conn;
    
    # Para IP hash (sticky sessions)
    ip_hash;
    
    server n8n:5678;
}
```

## Troubleshooting

### Verificar se as instâncias estão healthy

```bash
# Status detalhado
docker-compose ps

# Health check manual
docker-compose exec nginx wget -qO- http://n8n:5678/healthz
```

### Verificar distribuição de carga

```bash
# Logs em tempo real
docker-compose logs -f nginx n8n
```

### Reiniciar serviços

```bash
# Reiniciar apenas o n8n
docker-compose restart n8n

# Reiniciar nginx
docker-compose restart nginx
```

## Limitações

- **Dados compartilhados**: Como as instâncias compartilham o mesmo volume, workflows são compartilhados
- **Execuções simultâneas**: Podem ocorrer conflitos em workflows que modificam dados
- **Sessões**: Não há persistência de sessão entre instâncias (usar ip_hash no nginx se necessário)

## Melhorias possíveis

1. **Banco de dados externo**: PostgreSQL para execuções compartilhadas
2. **Redis**: Para cache e filas
3. **Monitoring**: Prometheus + Grafana
4. **SSL/TLS**: Certificados HTTPS
5. **Backup**: Estratégia de backup dos volumes
