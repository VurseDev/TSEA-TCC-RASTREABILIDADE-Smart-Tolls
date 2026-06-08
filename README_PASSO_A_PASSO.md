# Migração: Backend no Fly.io + Arduino via Worker Local

## Resumo da nova arquitetura

Antes, o `Program.cs` tentava abrir `COM7` dentro do backend. Isso só funciona quando o backend roda no mesmo PC do Arduino. No Fly.io não existe porta USB/COM7.

Agora fica assim:

```text
Frontend / navegador
        ↓ HTTPS
Backend ASP.NET no Fly.io
        ↓
PostgreSQL no Fly.io
        ↑ HTTPS
ArduinoBridgeWorker no PC local
        ↓ COM7 USB
Arduino
```

## Arquivos gerados

- `Backend/Program.cs` — backend alterado para não usar mais `SerialPort`.
- `ArduinoBridgeWorker/Program.cs` — worker local que lê a serial e conversa com o backend.
- `ArduinoBridgeWorker/ArduinoBridgeWorker.csproj` — projeto do worker.
- `ArduinoBridgeWorker/appsettings.example.json` — configuração exemplo do worker.
- `Database/migration_worker.sql` — cria tabelas novas no PostgreSQL.
- `Frontend/index.html` — seu frontend original, sem mudança obrigatória.
- `Arduino/main.ino` — seu Arduino original, sem mudança obrigatória.

## O que mudou no Backend

### Removido do Fly.io

Saiu do backend:

- `using System.IO.Ports;`
- `ArduinoSerial.Inicializar();`
- `Task.Run(...)` que lia a serial continuamente.
- `EnviarComandoArduino(...)`.
- `ArduinoSerial`, `BotaoControle` e `EstadoPorta` em memória.

### Adicionado no Backend

Foram adicionadas tabelas/modelos:

- `ComandosPendentes` — fila de comandos para o Arduino.
- `AvisosPendentes` — avisos persistidos no PostgreSQL.
- `EstadoPorta` — status da porta e confirmação do botão físico persistidos no PostgreSQL.

Foram adicionadas rotas para o Worker:

```http
GET  /worker/comandos
POST /worker/comandos/{id}/concluido
POST /worker/evento
```

## Como funciona o login agora

Antes:

```csharp
EnviarComandoArduino("LOGIN");
```

Agora:

```csharp
await EnfileirarComandoArduino(db, "LOGIN");
```

O backend grava o comando no banco. O Worker local busca o comando e envia para o Arduino pela COM7.

## Como funciona o logout agora

Antes:

```csharp
EnviarComandoArduino("LOGOUT");
```

Agora:

```csharp
await EnfileirarComandoArduino(db, "LOGOUT");
```

O Worker recebe o comando e manda `LOGOUT` pela serial. O Arduino liga o buzzer e espera a chave física.

## Como funcionam os sensores agora

O Arduino continua enviando pela serial:

```text
FERRAMENTA_1_RETIRADA
FERRAMENTA_1_DEVOLVIDA
PORTA_ABERTA
PORTA_FECHADA
PORTA_SEM_LOGIN
BOTAO_SAIDA_OK
```

O Worker lê isso da COM7 e envia para o backend:

```http
POST /worker/evento
```

O backend processa o evento e altera o PostgreSQL.

## Passo 1 — aplicar SQL no PostgreSQL do Fly

Execute:

```sql
Database/migration_worker.sql
```

Esse arquivo cria:

- `ComandosPendentes`
- `AvisosPendentes`
- `EstadoPorta`

Também adiciona `CodigoBarras` em `Ferramentas`, caso não exista.

## Passo 2 — configurar token do Worker no Fly

No Fly.io, configure um token simples:

```powershell
fly secrets set WORKER_TOKEN="troque-este-token"
```

Use o mesmo token no Worker local.

Se você não configurar `WORKER_TOKEN`, as rotas do worker ficam liberadas. Para TCC/local funciona, mas em produção é melhor usar o token.

## Passo 3 — substituir o Program.cs do Backend

Substitua seu arquivo:

```text
Backend/Program.cs
```

pelo arquivo gerado:

```text
Backend/Program.cs
```

Depois faça build:

```powershell
dotnet build -c Release
```

E faça deploy no Fly:

```powershell
fly deploy
```

## Passo 4 — criar e configurar o Worker local

Copie a pasta:

```text
ArduinoBridgeWorker
```

para o PC que está conectado fisicamente no Arduino.

Renomeie:

```text
appsettings.example.json
```

para:

```text
appsettings.json
```

Edite:

```json
{
  "API_URL": "https://SEU-APP.fly.dev",
  "WORKER_TOKEN": "troque-este-token",
  "SERIAL_PORT": "COM7",
  "BAUD_RATE": "9600"
}
```

## Passo 5 — rodar o Worker

No PC local:

```powershell
cd ArduinoBridgeWorker
dotnet restore
dotnet run
```

Você deve ver algo parecido com:

```text
ArduinoBridgeWorker iniciado.
API: https://SEU-APP.fly.dev
Serial: COM7 @ 9600
[Serial] Conectado em COM7 @ 9600.
```

## Passo 6 — teste completo

1. Abra o frontend.
2. Faça login com um usuário.
3. O backend grava `LOGIN` em `ComandosPendentes`.
4. O Worker busca esse comando.
5. O Worker envia `LOGIN` para o Arduino.
6. O Arduino abre o armário.
7. Retire uma ferramenta.
8. O Arduino envia `FERRAMENTA_1_RETIRADA`.
9. O Worker envia para `/worker/evento`.
10. O backend atualiza o PostgreSQL.
11. O frontend passa a mostrar o status atualizado.

## Observação importante sobre tabelas PostgreSQL

Seu projeto atual usa EF Core. O arquivo `migration_worker.sql` usa nomes com aspas, como:

```sql
"Ferramentas"
"Usuarios"
"ComandosPendentes"
```

Se seu banco foi criado manualmente com SQL sem aspas, o PostgreSQL pode ter criado tabelas em minúsculo, como:

```sql
ferramentas
usuarios
```

Nesse caso, você provavelmente já teria conflito com o EF Core. Se precisar, veja o arquivo:

```text
Database/worker_tables_lowercase_if_needed.sql
```

Mas a recomendação é manter o banco no padrão do EF usado pelo backend.

## O que NÃO precisa mudar

- O Arduino pode continuar com o mesmo `main.ino`.
- O frontend pode continuar chamando `/login`, `/logout`, `/ferramentas`, `/movimentacao/retirar`, etc.
- O PostgreSQL continua no Fly.io.
- O backend continua no Fly.io.
