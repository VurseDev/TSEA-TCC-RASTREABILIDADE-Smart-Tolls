-- 1. ENTRA NO MODO DE MANUTENÇÃO (DESATIVA TRAVAS)
SET FOREIGN_KEY_CHECKS = 0;

-- 2. GARANTE QUE O BANCO EXISTE E ESTÁ SELECIONADO
CREATE DATABASE IF NOT EXISTS RASTREABILIDADES_TSEA;
USE RASTREABILIDADES_TSEA;

-- 3. APAGA AS TABELAS NA ORDEM CERTA
DROP TABLE IF EXISTS Movimentacoes;
DROP TABLE IF EXISTS LogsAcesso;
DROP TABLE IF EXISTS Ferramentas;
DROP TABLE IF EXISTS Usuarios;

-- 4. CRIAÇÃO DAS TABELAS COM OS CAMPOS QUE O SEU C# PRECISA
CREATE TABLE Usuarios (
    Id INT PRIMARY KEY AUTO_INCREMENT,
    Nome VARCHAR(100),
    CodigoBarras VARCHAR(20) UNIQUE,
    Setor ENUM('ADMIN', 'SOLDAGEM', 'MONTAGEM', 'USINAGEM', 'OPERADOR', 'SOLDA', 'PRODUCAO'),
    Status ENUM('ATIVO', 'INATIVO') DEFAULT 'ATIVO',
    Email VARCHAR(255) DEFAULT NULL,          -- ✅ já incluso
    PasswordHash VARCHAR(255) DEFAULT NULL    -- ✅ já incluso
);

CREATE TABLE Ferramentas (
    Id VARCHAR(50) PRIMARY KEY, -- Aumentado para evitar erro de tamanho
    Descricao VARCHAR(100),
    Status ENUM('DISPONIVEL', 'EM_USO', 'MANUTENCAO') DEFAULT 'DISPONIVEL'
);
ALTER TABLE Ferramentas MODIFY COLUMN Id INT AUTO_INCREMENT;
ALTER TABLE Ferramentas; 
-- Adiciona a coluna para guardar o nome de quem pegou a ferramenta
ALTER TABLE Ferramentas ADD COLUMN Colaborador VARCHAR(100) DEFAULT NULL;
ALTER TABLE ferramentas ADD COLUMN VidaUtil INT DEFAULT 100;

-- 1. Adiciona a coluna física na tabela
ALTER TABLE ferramentas ADD COLUMN Setor VARCHAR(50) DEFAULT 'GERAL';

-- 2. Define alguns setores para teste (senão tudo continuará como GERAL)
UPDATE ferramentas SET Setor = 'SOLDAGEM' WHERE Id = 1;
UPDATE ferramentas SET Setor = 'MONTAGEM' WHERE Id = 2;
UPDATE ferramentas SET Setor = 'USINAGEM' WHERE Id = 3;
CREATE TABLE IF NOT EXISTS Movimentacoes (
    Id INT AUTO_INCREMENT PRIMARY KEY,
    FerramentaId INT, -- MUDADO DE VARCHAR PARA INT
    UsuarioId VARCHAR(20),
    DataRetirada DATETIME DEFAULT CURRENT_TIMESTAMP,
    DataDevolucao DATETIME NULL,
    FOREIGN KEY (FerramentaId) REFERENCES Ferramentas (Id)
);

USE RASTREABILIDADES_TSEA;

-- Ajustando a tabela de Logs para o novo formato
DROP TABLE IF EXISTS LogsAcesso;

CREATE TABLE LogsAcesso (
    Id INT PRIMARY KEY AUTO_INCREMENT,
    UsuarioId VARCHAR(50),
    DataEntrada DATETIME DEFAULT CURRENT_TIMESTAMP,
    DataSaida DATETIME NULL,
    MotivoSaida ENUM('MANUAL', 'EXPIRADO', 'SISTEMA') DEFAULT NULL,
    StatusAcesso VARCHAR(20) DEFAULT 'ATIVO'
);
SET FOREIGN_KEY_CHECKS = 0;
-- Inserir um Administrador (Note o 'A' no final do crachá)
INSERT INTO Usuarios (Nome, CodigoBarras, Setor, Status, Email, PasswordHash) 
VALUES ('ADMINISTRADOR PADRAO', 'TSEA-001A', 'ADMIN', 'ATIVO', 'emillysabrina152009@gmail.com', '123456');




-- Inserir alguns Operadores para teste
INSERT INTO Usuarios (Nome, CodigoBarras, Setor, Status, Email) 
VALUES ('OPERADOR TESTE 01', '1010', 'OPERADOR', 'ATIVO', 'emillysabrinabarbosaalmeida@gmail.com'),
       ('OPERADOR TESTE 02', '2020', 'OPERADOR', 'ATIVO', 'joaopedropereiragomed@gmail.com');

-- Inserir Ferramentas Iniciais
INSERT INTO Ferramentas (Descricao, Status) 
VALUES ('FURADEIRA BOSCH 01', 'DISPONIVEL'),
       ('ESMERILHADEIRA 02', 'DISPONIVEL'),
       ('CHAVE DE IMPACTO 03', 'DISPONIVEL');
SET SQL_SAFE_UPDATES = 1;
-- 6. REATIVA AS TRAVAS DE SEGURANÇA
SET FOREIGN_KEY_CHECKS = 1;


SET SQL_SAFE_UPDATES = 0;
DESCRIBE ferramentas;
UPDATE Ferramentas SET Status = 'DISPONIVEL';
DELETE FROM Movimentacoes;

SET SQL_SAFE_UPDATES = 1;


-- 7. VERIFICAÇÃO FINAL

SELECT * FROM RASTREABILIDADES_TSEA.ferramentas WHERE Status = 'EM_USO';
SELECT UsuarioId, DataEntrada, DataSaida, MotivoSaida FROM LogsAcesso;
SELECT * FROM Usuarios;
SELECT * FROM Ferramentas;
SELECT * FROM Movimentacoes ORDER BY id DESC;
SELECT Nome, Email FROM Usuarios WHERE Setor = 'ADMIN';

