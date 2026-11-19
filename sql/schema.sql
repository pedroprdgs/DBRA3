CREATE DATABASE IF NOT EXISTS sistema_ordens_servico;
USE sistema_ordens_servico;

-- CLIENTE
CREATE TABLE cliente (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    documento VARCHAR(20) NOT NULL UNIQUE,
    telefone VARCHAR(20),
    tipo_pessoa ENUM('PF', 'PJ') NOT NULL,
    endereco VARCHAR(255),
    email VARCHAR(150),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- PROJETO
CREATE TABLE projeto (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    data_inicio DATE,
    data_fim DATE,
    status VARCHAR(30) NOT NULL,
    cliente_id INT NOT NULL,
    
	FOREIGN KEY (cliente_id) REFERENCES cliente(id)
);

-- DEPARTAMENTO
CREATE TABLE departamento (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

-- EQUIPE
CREATE TABLE equipe (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    departamento_id INT NOT NULL,

    FOREIGN KEY (departamento_id) REFERENCES departamento(id)
);

-- FUNCIONARIO
CREATE TABLE funcionario (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150),
    telefone VARCHAR(20),
    cargo VARCHAR(100),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    data_contratacao DATE,
    equipe_id INT,

    FOREIGN KEY (equipe_id) REFERENCES equipe(id)
);

-- CATEGORIA DE SERVICO
CREATE TABLE categoria_servico (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

-- SERVICO
CREATE TABLE servico (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    valor_base DECIMAL(12,2) NOT NULL DEFAULT 0,
    tempo_estimado INT, -- Em horas
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    categoria_servico_id INT NOT NULL,

    FOREIGN KEY (categoria_servico_id) REFERENCES categoria_servico(id),
    
    CHECK (valor_base >= 0),
	CHECK (tempo_estimado IS NULL OR tempo_estimado >= 0)
);

-- ORDEM DE SERVICO
CREATE TABLE ordem_servico (
    id INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    descricao TEXT,
    prioridade VARCHAR(30),
    status VARCHAR(30) NOT NULL,
    diagnostico TEXT,
    solucao TEXT,
    data_abertura DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_previsao DATETIME,
    data_conclusao DATETIME,

    cliente_id INT NOT NULL,
    departamento_id INT NOT NULL,
    projeto_id INT,
    equipe_id INT,
    funcionario_abertura_id INT NOT NULL,
    funcionario_responsavel_id INT,
    categoria_servico_id INT NOT NULL,

    FOREIGN KEY (cliente_id) REFERENCES cliente(id),
    FOREIGN KEY (departamento_id) REFERENCES departamento(id),
    FOREIGN KEY (projeto_id) REFERENCES projeto(id),
    FOREIGN KEY (equipe_id) REFERENCES equipe(id),
    FOREIGN KEY (funcionario_abertura_id) REFERENCES funcionario(id),
    FOREIGN KEY (funcionario_responsavel_id) REFERENCES funcionario(id),
    FOREIGN KEY (categoria_servico_id) REFERENCES categoria_servico(id)
);

-- HISTORICO DA ORDEM DE SERVICO
CREATE TABLE historico_os (
    id INT AUTO_INCREMENT PRIMARY KEY,
    acao VARCHAR(100) NOT NULL,
    status_anterior VARCHAR(30),
    status_novo VARCHAR(30),
    data_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descricao TEXT,
    ordem_servico_id INT NOT NULL,
    funcionario_id INT,

    FOREIGN KEY (ordem_servico_id) REFERENCES ordem_servico(id),
    FOREIGN KEY (funcionario_id) REFERENCES funcionario(id)
);

-- PROJETO X DEPARTAMENTO (N:N)
CREATE TABLE projeto_departamento (
    projeto_id INT NOT NULL,
    departamento_id INT NOT NULL,

    PRIMARY KEY (projeto_id, departamento_id),

    FOREIGN KEY (projeto_id) REFERENCES projeto(id),
    FOREIGN KEY (departamento_id) REFERENCES departamento(id)
);

-- ORDEM DE SERVICO X SERVICO (N:N)
CREATE TABLE ordem_servico_servico (
    ordem_servico_id INT NOT NULL,
    servico_id INT NOT NULL,
    quantidade INT NOT NULL DEFAULT 1,
    valor_unitario DECIMAL(12,2) NOT NULL,
    observacao TEXT,

    PRIMARY KEY (ordem_servico_id, servico_id),

    FOREIGN KEY (ordem_servico_id) REFERENCES ordem_servico(id),
    FOREIGN KEY (servico_id) REFERENCES servico(id),
    
    CHECK (quantidade > 0),
    CHECK (valor_unitario >= 0)
);

-- ORDEM DE SERVICO X COLABORADOR (N:N)
CREATE TABLE ordem_servico_colaborador (
    ordem_servico_id INT NOT NULL,
    funcionario_id INT NOT NULL,
    data_atribuicao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacao TEXT,

    PRIMARY KEY (ordem_servico_id, funcionario_id),

    FOREIGN KEY (ordem_servico_id) REFERENCES ordem_servico(id),
    FOREIGN KEY (funcionario_id) REFERENCES funcionario(id)
);
