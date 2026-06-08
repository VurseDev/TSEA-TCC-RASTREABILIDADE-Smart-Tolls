-- Migração para a arquitetura com Worker Local + Backend no Fly.io
-- Execute no PostgreSQL usado pelo Fly antes de subir o novo Program.cs.

-- Se você criou enums manualmente pelo init.sql antigo, adicione os novos valores usados pelo sistema.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ferramenta_status_enum') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'AUSENTE_SEM_REGISTRO' AND enumtypid = 'ferramenta_status_enum'::regtype) THEN
            ALTER TYPE ferramenta_status_enum ADD VALUE 'AUSENTE_SEM_REGISTRO';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'ATRASADO' AND enumtypid = 'ferramenta_status_enum'::regtype) THEN
            ALTER TYPE ferramenta_status_enum ADD VALUE 'ATRASADO';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'motivo_saida_enum') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'VOLUNTARIO' AND enumtypid = 'motivo_saida_enum'::regtype) THEN
            ALTER TYPE motivo_saida_enum ADD VALUE 'VOLUNTARIO';
        END IF;
    END IF;
END $$;

-- Colunas que o Program.cs atual usa.
ALTER TABLE IF EXISTS "Ferramentas" ADD COLUMN IF NOT EXISTS "CodigoBarras" text;
ALTER TABLE IF EXISTS "Usuarios" ADD COLUMN IF NOT EXISTS "Email" text;
ALTER TABLE IF EXISTS "Usuarios" ADD COLUMN IF NOT EXISTS "PasswordHash" text;

-- Fila de comandos: Fly grava LOGIN/LOGOUT aqui; o Worker local busca e envia pela COM7.
CREATE TABLE IF NOT EXISTS "ComandosPendentes" (
    "Id" serial PRIMARY KEY,
    "Comando" text NOT NULL,
    "Executado" boolean NOT NULL DEFAULT false,
    "CriadoEm" timestamp with time zone NOT NULL DEFAULT now(),
    "ExecutadoEm" timestamp with time zone NULL
);

CREATE INDEX IF NOT EXISTS "IX_ComandosPendentes_Executado_CriadoEm"
ON "ComandosPendentes" ("Executado", "CriadoEm");

-- Avisos agora ficam persistidos no banco, não em List<> na memória do Fly.
CREATE TABLE IF NOT EXISTS "AvisosPendentes" (
    "Id" serial PRIMARY KEY,
    "FerramentaId" integer NOT NULL,
    "UsuarioId" text NOT NULL,
    "Mensagem" text NOT NULL,
    "Lido" boolean NOT NULL DEFAULT false,
    "CriadoEm" timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "IX_AvisosPendentes_UsuarioId_Lido_CriadoEm"
ON "AvisosPendentes" ("UsuarioId", "Lido", "CriadoEm");

-- Estado da porta e confirmação do botão físico persistidos no banco.
CREATE TABLE IF NOT EXISTS "EstadoPorta" (
    "Id" integer PRIMARY KEY,
    "Status" text NOT NULL DEFAULT 'DESCONHECIDO',
    "AlarmeSemLogin" boolean NOT NULL DEFAULT false,
    "UltimaAtualizacao" timestamp with time zone NOT NULL DEFAULT now(),
    "BotaoSaidaConfirmado" boolean NOT NULL DEFAULT false
);

INSERT INTO "EstadoPorta" ("Id", "Status", "AlarmeSemLogin", "UltimaAtualizacao", "BotaoSaidaConfirmado")
VALUES (1, 'DESCONHECIDO', false, now(), false)
ON CONFLICT ("Id") DO NOTHING;
