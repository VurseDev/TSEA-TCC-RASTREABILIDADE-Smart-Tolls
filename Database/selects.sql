USE RASTREABILIDADES_TSEA;
SELECT * FROM Ferramentas;
SELECT Id, Nome, CodigoBarras, Setor, Email, 
       CASE WHEN PasswordHash IS NULL THEN 'SEM SENHA' ELSE 'TEM SENHA' END AS Senha
FROM Usuarios;

-- Garante que a coluna Setor existe e tem um padrão
ALTER TABLE Ferramentas MODIFY COLUMN Setor VARCHAR(50) DEFAULT 'GERAL';

SELECT * FROM Movimentacoes ORDER BY DataRetirada DESC;
SELECT Nome, Email FROM Usuarios WHERE Setor = 'ADMIN';
-- 3. Ver quem logou no sistema
SELECT * FROM LogsAcesso ORDER BY DataEntrada DESC;
SET SQL_SAFE_UPDATES = 0;

-- 1. Adiciona a coluna se ela não existir
ALTER TABLE Ferramentas ADD COLUMN CodigoBarras VARCHAR(50);

-- 2. Vincula os códigos de barras aos IDs que você já tem
UPDATE Ferramentas SET CodigoBarras = 'TSEA-001' WHERE Id = 1;
UPDATE Ferramentas SET CodigoBarras = 'TSEA-002' WHERE Id = 2;
UPDATE Ferramentas SET CodigoBarras = 'TSEA-003' WHERE Id = 3;

SET SQL_SAFE_UPDATES = 1;




-- Adiciona Email se não existir  

ALTER TABLE Usuarios ADD COLUMN Email VARCHAR(255) DEFAULT NULL;
ALTER TABLE Usuarios ADD COLUMN PasswordHash VARCHAR(255) DEFAULT NULL;
-- Atualiza o admin padrão com um email
UPDATE Usuarios 
SET Email = 'seuemail@gmail.com' 
WHERE Setor = 'ADMIN';
INSERT INTO Usuarios (Nome, CodigoBarras, Setor, Status, Email, PasswordHash) 
VALUES ('ADMINISTRADOR PADRAO', 'TSEA-001A', 'ADMIN', 'ATIVO', 'emillysabrina152009@gmail.com', '123456');



