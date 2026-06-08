-- Use este arquivo SOMENTE se suas tabelas foram criadas manualmente sem aspas
-- e aparecem como usuarios/ferramentas/movimentacoes/logsacesso no PostgreSQL.
-- O ideal é padronizar com EF/Program.cs usando nomes com aspas: "Usuarios", "Ferramentas", etc.

ALTER TABLE IF EXISTS ferramentas ADD COLUMN IF NOT EXISTS codigobarras text;
ALTER TABLE IF EXISTS usuarios ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE IF EXISTS usuarios ADD COLUMN IF NOT EXISTS passwordhash text;

CREATE TABLE IF NOT EXISTS comandospendentes (
    id serial PRIMARY KEY,
    comando text NOT NULL,
    executado boolean NOT NULL DEFAULT false,
    criadoem timestamp with time zone NOT NULL DEFAULT now(),
    executadoem timestamp with time zone NULL
);

CREATE TABLE IF NOT EXISTS avisospendentes (
    id serial PRIMARY KEY,
    ferramentaid integer NOT NULL,
    usuarioid text NOT NULL,
    mensagem text NOT NULL,
    lido boolean NOT NULL DEFAULT false,
    criadoem timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS estadoporta (
    id integer PRIMARY KEY,
    status text NOT NULL DEFAULT 'DESCONHECIDO',
    alarmesemlogin boolean NOT NULL DEFAULT false,
    ultimaatualizacao timestamp with time zone NOT NULL DEFAULT now(),
    botaosaidaconfirmado boolean NOT NULL DEFAULT false
);

INSERT INTO estadoporta (id, status, alarmesemlogin, ultimaatualizacao, botaosaidaconfirmado)
VALUES (1, 'DESCONHECIDO', false, now(), false)
ON CONFLICT (id) DO NOTHING;
