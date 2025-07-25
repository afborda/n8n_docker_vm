# Configurações de recursos para VM e2-micro

## Distribuição de Memória (1GB total):

### Containers:
- **3x n8n**: 280MB cada = 840MB total
- **1x nginx**: 80MB
- **Sistema/Docker**: ~80MB reservado

### Distribuição de CPU (2 vCPUs):
- **3x n8n**: 0.6 CPU cada = 1.8 CPU total
- **1x nginx**: 0.2 CPU
- **Sistema**: 0.2 CPU reservado para SO

## Configurações aplicadas:

### n8n:
- **Memory Limit**: 280MB por instância
- **Memory Reservation**: 200MB garantido
- **CPU Limit**: 0.6 (60% de 1 CPU)
- **CPU Reservation**: 0.3 garantido

### nginx:
- **Memory Limit**: 80MB
- **Memory Reservation**: 50MB garantido
- **CPU Limit**: 0.2 (20% de 1 CPU)
- **CPU Reservation**: 0.1 garantido

## Monitoramento:

Para monitorar o uso de recursos:

```bash
# Ver uso de memória e CPU
docker stats

# Ver uso específico do projeto
docker-compose exec nginx top
docker-compose exec n8n top
```

## Otimizações adicionais:

Se ainda houver problemas de memória, considere:

1. **Reduzir réplicas para 2**:
   ```yaml
   deploy:
     replicas: 2
   ```

2. **Usar imagem alpine do n8n** (se disponível):
   ```yaml
   image: n8nio/n8n:latest-alpine
   ```

3. **Configurar swap** na VM (com cuidado):
   ```bash
   sudo fallocate -l 512M /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

## Troubleshooting:

### Se containers forem mortos por OOM:
1. Reduza as réplicas para 2
2. Diminua memory limits
3. Adicione swap à VM

### Se performance estiver baixa:
1. Aumente CPU reservations
2. Considere usar apenas 2 réplicas
3. Monitore com `docker stats`
