# JOIN Pushdown Tests

Este diretório contém testes para verificar a funcionalidade de JOIN pushdown do tds_fdw.

## Estrutura dos Testes

Cada teste consiste em dois arquivos:
- `NNN_test_name.sql` - O SQL a ser executado
- `NNN_test_name.json` - Metadados do teste

### Formato do arquivo JSON

```json
{
    "test_desc": "Descrição do teste",
    "expect_pushdown": true,
    "server": {
        "version": {
            "min": "9.5.0",
            "max": ""
        }
    },
    "setup_sql": "SQL opcional para setup antes do teste",
    "cleanup_sql": "SQL opcional para cleanup após o teste"
}
```

### Variáveis disponíveis no SQL

- `@SYBASE_HOST` - Host do servidor remoto
- `@SYBASE_PORT` - Porta do servidor remoto
- `@SYBASE_USER` - Usuário do servidor remoto
- `@SYBASE_PASSWORD` - Senha do servidor remoto
- `@SYBASE_DATABASE` - Database do servidor remoto
- `@SYBASE_SCHEMA` - Schema do servidor remoto

## Executando os Testes

### Executar um teste específico

```bash
docker build -t tds_fdw_test -f tests/docker/Dockerfile.test .

docker run --rm \
    -e SYBASE_HOST=host.docker.internal \
    -e SYBASE_PORT=5000 \
    -e SYBASE_USER=sa \
    -e SYBASE_PASSWORD=myPassword \
    -e SYBASE_DATABASE=master \
    -e TEST_NAME=001_simple_inner_join \
    tds_fdw_test
```

### Executar todos os testes

```bash
docker run --rm \
    -e SYBASE_HOST=host.docker.internal \
    -e SYBASE_PORT=5000 \
    -e SYBASE_USER=sa \
    -e SYBASE_PASSWORD=myPassword \
    -e SYBASE_DATABASE=master \
    -e TEST_NAME=all \
    tds_fdw_test
```

### Modo debug

```bash
docker run --rm \
    -e SYBASE_HOST=host.docker.internal \
    -e SYBASE_PORT=5000 \
    -e SYBASE_USER=sa \
    -e SYBASE_PASSWORD=myPassword \
    -e SYBASE_DATABASE=master \
    -e TEST_NAME=001_simple_inner_join \
    -e DEBUG_MODE=1 \
    tds_fdw_test
```

## Adicionando Novos Testes

1. Crie um arquivo SQL com a query a ser testada
2. Crie um arquivo JSON com os metadados do teste
3. Use a numeração sequencial (ex: 007_novo_teste.sql)
4. O teste deve ser auto-contido (criar/dropar tabelas se necessário)

