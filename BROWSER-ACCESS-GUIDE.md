# 🌐 Guia de Acesso via Browser

## ✅ Status Atual
- ✅ Containers rodando corretamente
- ✅ nginx funcionando
- ✅ SSL configurado
- ✅ DNS local configurado
- ✅ n8n respondendo

## 🔒 Como Acessar no Browser

### Passo 1: Acesse a URL
```
https://n8n-local.com
```

### Passo 2: Contorne o Aviso de Segurança

**Chrome/Edge:**
1. Você verá: "Sua conexão não é particular"
2. Clique em **"Avançado"**
3. Clique em **"Continuar para n8n-local.com (não seguro)"**

**Firefox:**
1. Você verá: "Aviso: risco de segurança potencial"
2. Clique em **"Avançado"**
3. Clique em **"Aceitar o risco e continuar"**

**Safari:**
1. Você verá: "Esta conexão não é privada"
2. Clique em **"Mostrar detalhes"**
3. Clique em **"Visitar este website"**
4. Clique em **"Visitar"** novamente

## 🧪 Testes de Conectividade

```bash
# Teste DNS
ping n8n-local.com

# Teste HTTP (deve redirecionar)
curl -I http://n8n-local.com

# Teste HTTPS
curl -k -I https://n8n-local.com

# Teste completo do n8n
curl -k https://n8n-local.com
```

## ⚠️ Por que isso acontece?

1. **Certificado Auto-assinado**: Não é assinado por uma autoridade certificadora confiável
2. **Comportamento Normal**: Todos os browsers modernos mostram este aviso
3. **Seguro para Teste**: É perfeitamente seguro continuar em ambiente local

## 🔧 Comandos Úteis

```bash
# Ver status dos containers
docker-compose -f docker-compose-local-test.yml ps

# Ver logs
docker-compose -f docker-compose-local-test.yml logs -f

# Parar containers
docker-compose -f docker-compose-local-test.yml down
```

## 🎯 URL Final
Após aceitar o certificado: **https://n8n-local.com**
