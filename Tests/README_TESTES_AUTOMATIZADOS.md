# Testes automatizados do projeto TSEA

Este projeto agora tem uma bateria automatica em PowerShell para validar:

- build do backend ASP.NET;
- build do ArduinoBridgeWorker;
- frontend publicado;
- endpoints principais da API;
- protecao por token das rotas do worker;
- relatorio JSON;
- relatorio XLSX;
- opcionalmente, eventos reais do worker que alteram o estado da porta.

## Arquivo principal

```text
Tests/run-tests.ps1
```

## Como executar

Abra o PowerShell na raiz do projeto:

```powershell
cd C:\Users\ocaua\Downloads\tsea_migrado_worker\tsea_migrado
.\Tests\run-tests.ps1
```

Por padrao, o script testa a API publicada:

```text
https://tsea-tcc-rastreabilidade-smart-tolls.fly.dev
```

Para testar as rotas protegidas do worker, informe o token por parâmetro:

```powershell
.\Tests\run-tests.ps1 -WorkerToken "SEU_TOKEN_DO_WORKER"
```

ou por variável de ambiente:

```powershell
$env:WORKER_TOKEN = "SEU_TOKEN_DO_WORKER"
.\Tests\run-tests.ps1
```

## Rodar sem compilar

Use quando quiser testar apenas a API remota:

```powershell
.\Tests\run-tests.ps1 -SkipBuild
```

## Rodar contra backend local

Se o backend estiver rodando localmente em `http://localhost:5050`:

```powershell
.\Tests\run-tests.ps1 -BaseUrl "http://localhost:5050"
```

## Testes que alteram estado

Por padrao, a bateria evita alterar o estado do banco. Para testar tambem eventos do Arduino/worker:

```powershell
.\Tests\run-tests.ps1 -IncludeMutating
```

Esse modo envia:

```text
PORTA_ABERTA
PORTA_FECHADA
```

para:

```text
POST /worker/evento
```

e valida se:

```text
GET /status/porta
```

reflete a mudanca.

## Testes incluidos

```text
Build Backend
Build ArduinoBridgeWorker
GET /
GET /ferramentas
GET /status/porta
GET /worker/comandos sem token deve negar
GET /worker/comandos com token
GET /relatorio padrao
GET /relatorio?tipo=MENSAL
GET /relatorio/xlsx
POST /worker/evento PORTA_ABERTA       (somente com -IncludeMutating)
POST /worker/evento PORTA_FECHADA      (somente com -IncludeMutating)
```

## Como ler o resultado

No final, o script imprime uma tabela:

```text
Test                              Status Details
----                              ------ -------
GET /                             PASS   Frontend respondeu 200.
GET /relatorio/xlsx               FAIL   Esperado 200, recebido 500.
```

Se qualquer teste falhar, o script encerra com codigo `1`. Isso permite usar a bateria em CI/CD futuramente.

## Observacao sobre o XLSX

O teste `GET /relatorio/xlsx` existe de proposito porque esse endpoint ja apresentou erro `500`.
Se ele falhar, a API JSON ainda pode estar funcionando normalmente; nesse caso, investigue especificamente a geracao do Excel/EPPlus.

O endpoint testado e:

```text
/relatorio/xlsx?tipo=DIARIO&dataInicio=YYYY-MM-DD
```

## Fluxo recomendado antes de deploy

1. Rodar:

```powershell
.\Tests\run-tests.ps1
```

2. Corrigir qualquer falha.

3. Publicar:

```powershell
fly deploy -a tsea-tcc-rastreabilidade-smart-tolls
```

4. Rodar novamente:

```powershell
.\Tests\run-tests.ps1 -SkipBuild
```

Assim voce valida a versao local antes do deploy e a versao publicada depois do deploy.
