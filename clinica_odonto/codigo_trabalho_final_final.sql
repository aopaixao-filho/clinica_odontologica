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