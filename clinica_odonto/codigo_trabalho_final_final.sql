CREATE TABLE dentistas (
    id SERIAL PRIMARY KEY,
    nome_completo VARCHAR(100) NOT NULL,
    cpf VARCHAR(14) UNIQUE NOT NULL,
    cro VARCHAR(20) UNIQUE NOT NULL,
    especialidade VARCHAR(50) NOT NULL
);

CREATE TABLE pacientes (
    id SERIAL PRIMARY KEY,
    nome_completo VARCHAR(100) NOT NULL,
    cpf VARCHAR(14) UNIQUE NOT NULL,
    data_nascimento DATE NOT NULL,
    telefone VARCHAR(15) NOT NULL,
    email VARCHAR(100),
    endereco VARCHAR(200)
);

CREATE TABLE procedimentos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(50) NOT NULL,
    descricao TEXT,
    duracao_media INT NOT NULL CHECK (duracao_media > 0)
);

CREATE TABLE horarios_atendimento (
    id SERIAL PRIMARY KEY,
    dentista_id INT NOT NULL,
    dia_semana VARCHAR(10) CHECK (dia_semana IN ('Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado')) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL,
    FOREIGN KEY (dentista_id) REFERENCES dentistas(id)
);

CREATE TABLE consultas (
    id SERIAL PRIMARY KEY,
    paciente_id INT NOT NULL,
    dentista_id INT NOT NULL,
    data_consulta TIMESTAMP NOT NULL,
    descricao TEXT,
    prescricao TEXT,
    status VARCHAR(10) CHECK (status IN ('agendada', 'realizada', 'cancelada')) DEFAULT 'agendada',
    FOREIGN KEY (paciente_id) REFERENCES pacientes(id) ON DELETE CASCADE,
    FOREIGN KEY (dentista_id) REFERENCES dentistas(id) ON DELETE CASCADE
);

CREATE TABLE consultas_procedimentos (
    id SERIAL PRIMARY KEY,
    consulta_id INT NOT NULL,
    procedimento_id INT NOT NULL,
    observacoes TEXT,
    FOREIGN KEY (consulta_id) REFERENCES consultas(id) ON DELETE CASCADE,
    FOREIGN KEY (procedimento_id) REFERENCES procedimentos(id) ON DELETE CASCADE
);

CREATE INDEX idx_pacientes_cpf ON pacientes(cpf);
CREATE INDEX idx_consultas_data ON consultas(data_consulta);

CREATE OR REPLACE VIEW vw_estatisticas_completas_dentistas AS
WITH consultas_por_dia AS (
    SELECT 
        c.dentista_id,
        TRIM(TO_CHAR(c.data_consulta, 'Day')) AS dia_semana,
        COUNT(*) AS total_consultas
    FROM 
        consultas c
    WHERE 
        LOWER(c.status) = 'realizada'
    GROUP BY 
        c.dentista_id, TRIM(TO_CHAR(c.data_consulta, 'Day'))
)
SELECT 
    d.id AS dentista_id,
    d.nome_completo,
    d.cro,
    d.especialidade,
    COALESCE(COUNT(c.id), 0) AS total_consultas_realizadas,
    COALESCE(ROUND(COUNT(c.id) / NULLIF(COUNT(DISTINCT DATE(c.data_consulta)), 0), 2), 0) AS media_consultas_por_dia
FROM 
    dentistas d
LEFT JOIN 
    consultas c ON d.id = c.dentista_id AND LOWER(c.status) = 'realizada'
GROUP BY 
    d.id, d.nome_completo, d.cro, d.especialidade
ORDER BY 
    total_consultas_realizadas DESC;

-- Atualizações
UPDATE pacientes 
SET telefone = '(11) 90000-0000'
WHERE cpf = '123.456.789-10';

UPDATE consultas 
SET status = 'cancelada'
WHERE data_consulta < NOW();

UPDATE dentistas 
SET especialidade = 'Clínica Geral'
WHERE cro = 'CRO-11223';

-- Exclusões
DELETE FROM pacientes WHERE id = 5;
DELETE FROM consultas WHERE status = 'cancelada';
DELETE FROM horarios_atendimento WHERE hora_inicio < '08:00';

-- Consultas

-- 1. Quantidade de consultas por especialidade
SELECT d.especialidade, COUNT(c.id) AS total_consultas
FROM dentistas d
LEFT JOIN consultas c ON d.id = c.dentista_id
GROUP BY d.especialidade
ORDER BY total_consultas DESC;

-- 2. Quantidade de consultas realizadas por dentista
SELECT d.nome_completo, COUNT(c.id) AS total_consultas
FROM dentistas d
LEFT JOIN consultas c ON d.id = c.dentista_id
WHERE c.status = 'realizada'
GROUP BY d.nome_completo
ORDER BY total_consultas DESC;

-- 3. Pacientes com mais consultas realizadas
SELECT p.nome_completo, COUNT(c.id) AS total_consultas
FROM pacientes p
LEFT JOIN consultas c ON p.id = c.paciente_id
WHERE c.status = 'realizada'
GROUP BY p.nome_completo
ORDER BY total_consultas DESC;

-- 4. View com lista de consultas ordenadas por data
CREATE OR REPLACE VIEW vw_lista_consultas AS
SELECT 
    c.id AS id_consulta,
    p.nome_completo AS nome_paciente,
    d.nome_completo AS nome_dentista,
    c.data_consulta,
    STRING_AGG(pr.nome, ', ') AS procedimentos_realizados
FROM consultas c
JOIN pacientes p ON c.paciente_id = p.id
JOIN dentistas d ON c.dentista_id = d.id
LEFT JOIN consultas_procedimentos cp ON c.id = cp.consulta_id
LEFT JOIN procedimentos pr ON cp.procedimento_id = pr.id
GROUP BY c.id, p.nome_completo, d.nome_completo, c.data_consulta
ORDER BY c.data_consulta DESC;

-- 5. Média de consultas por dentista
SELECT d.nome_completo, ROUND(AVG(consultas_por_dentista), 2) AS media_consultas
FROM (
    SELECT dentista_id, COUNT(*) AS consultas_por_dentista
    FROM consultas
    WHERE status = 'realizada'
    GROUP BY dentista_id
) subquery
JOIN dentistas d ON subquery.dentista_id = d.id
GROUP BY d.nome_completo;
