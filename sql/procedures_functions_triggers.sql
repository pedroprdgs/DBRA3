USE sistema_ordens_servico;

-- VIEW DE APOIO: resumo financeiro das ordens de servico
CREATE OR REPLACE VIEW vw_resumo_financeiro_os AS
SELECT os.id AS ordem_servico_id, os.cliente_id, os.status,
       COUNT(oss.servico_id) AS tipos_servico,
       COALESCE(SUM(oss.quantidade * oss.valor_unitario), 0) AS valor_total
FROM ordem_servico os
LEFT JOIN ordem_servico_servico oss ON oss.ordem_servico_id = os.id
GROUP BY os.id, os.cliente_id, os.status;

DROP PROCEDURE IF EXISTS sp_abrir_os;
DROP PROCEDURE IF EXISTS sp_alterar_status_os;
DROP PROCEDURE IF EXISTS sp_atribuir_responsavel;
DROP PROCEDURE IF EXISTS sp_adicionar_servico_os;
DROP PROCEDURE IF EXISTS sp_relatorio_clientes;
DROP PROCEDURE IF EXISTS sp_recalcular_prioridade_atrasadas;
DROP FUNCTION IF EXISTS fn_valor_total_os;
DROP FUNCTION IF EXISTS fn_quantidade_os_cliente;
DROP FUNCTION IF EXISTS fn_dias_em_aberto;
DROP FUNCTION IF EXISTS fn_status_prazo;
DROP FUNCTION IF EXISTS fn_total_horas_os;
DROP FUNCTION IF EXISTS fn_quantidade_colaboradores;
DROP TRIGGER IF EXISTS trg_cliente_bi_documento;
DROP TRIGGER IF EXISTS trg_projeto_bi_datas;
DROP TRIGGER IF EXISTS trg_os_bi_datas;
DROP TRIGGER IF EXISTS trg_os_bu_conclusao;
DROP TRIGGER IF EXISTS trg_oss_bi_validar;
DROP TRIGGER IF EXISTS trg_os_au_historico;

DELIMITER $$

-- PROCEDURE 1: abre OS validando entidades relacionadas
CREATE PROCEDURE sp_abrir_os(
	IN p_titulo VARCHAR(150), IN p_descricao TEXT, IN p_prioridade VARCHAR(30),
	IN p_cliente_id INT, IN p_departamento_id INT,
	IN p_funcionario_id INT, IN p_categoria_id INT
)
BEGIN
	IF p_titulo IS NULL OR TRIM(p_titulo) = '' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Titulo obrigatorio';
	END IF;
    
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id = p_cliente_id AND ativo = 1)
    OR NOT EXISTS (SELECT 1 FROM departamento WHERE id = p_departamento_id AND ativo = 1)
    OR NOT EXISTS (SELECT 1 FROM funcionario WHERE id = p_funcionario_id AND ativo = 1)
    OR NOT EXISTS (SELECT 1 FROM categoria_servico WHERE id = p_categoria_id AND ativo = 1) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente, departamento, funcionario ou categoria invalidos/inativos';
	END IF;
    
	INSERT INTO ordem_servico(titulo, descricao, prioridade, status, cliente_id,
		departamento_id, funcionario_abertura_id, categoria_servico_id)
	VALUES (p_titulo, p_descricao, p_prioridade, 'aberta', p_cliente_id,
		p_departamento_id, p_funcionario_id, p_categoria_id);
        
	SELECT * FROM ordem_servico
    WHERE id = LAST_INSERT_ID();
END$$

-- PROCEDURE 2: atualiza status; trigger registra historico
CREATE PROCEDURE sp_alterar_status_os(IN p_os_id INT, IN p_status VARCHAR(30))
BEGIN
	IF p_status IS NULL OR p_status NOT IN ('aberta','em_andamento','concluida','cancelada') THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Status invalido';
	END IF;
	IF NOT EXISTS (SELECT 1 FROM ordem_servico WHERE id = p_os_id) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS nao encontrada';
	END IF;
    
	UPDATE ordem_servico SET status = p_status WHERE id = p_os_id;
    
	SELECT id, status, data_conclusao FROM ordem_servico WHERE id = p_os_id;
END$$

-- PROCEDURE 3: atribui responsavel da equipe vinculada a OS
CREATE PROCEDURE sp_atribuir_responsavel(IN p_os_id INT, IN p_funcionario_id INT)
BEGIN
	DECLARE v_equipe_id INT DEFAULT NULL;
    
	IF NOT EXISTS (SELECT 1 FROM ordem_servico WHERE id = p_os_id) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS nao encontrada';
	END IF;
    
	SELECT equipe_id INTO v_equipe_id FROM ordem_servico WHERE id = p_os_id;
	
    IF NOT EXISTS (SELECT 1 FROM funcionario f
		WHERE f.id = p_funcionario_id AND f.ativo = 1
		AND (v_equipe_id IS NULL OR f.equipe_id = v_equipe_id)
	) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Funcionario inativo ou fora da equipe';
	END IF;
    
	UPDATE ordem_servico SET funcionario_responsavel_id = p_funcionario_id WHERE id = p_os_id;
END$$

-- PROCEDURE 4: insere/atualiza servico, valor atual fica registrado na OS
CREATE PROCEDURE sp_adicionar_servico_os(IN p_os_id INT, IN p_servico_id INT, IN p_quantidade INT)
BEGIN
	DECLARE v_valor DECIMAL(12,2) DEFAULT NULL;
    
	IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantidade deve ser positiva';
	END IF;
    
	IF NOT EXISTS (SELECT 1 FROM ordem_servico WHERE id = p_os_id) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OS inexistente';
	END IF;
    
	SELECT valor_base INTO v_valor FROM servico WHERE id = p_servico_id AND ativo = 1;
    
	IF v_valor IS NULL THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Servico inexistente ou inativo';
	END IF;
    
	INSERT INTO ordem_servico_servico(ordem_servico_id,servico_id,quantidade,valor_unitario)
	VALUES(p_os_id,p_servico_id,p_quantidade,v_valor)
	ON DUPLICATE KEY UPDATE quantidade = quantidade + p_quantidade;
END$$

-- PROCEDURE 5: usa VIEW, INNER JOIN, LEFT JOIN, GROUP BY e subconsulta
CREATE PROCEDURE sp_relatorio_clientes()
BEGIN
	SELECT c.id, c.nome,
		COUNT(os.id) AS total_os,
        COALESCE(SUM(v.valor_total),0) AS faturamento_previsto,
        (SELECT COUNT(*) FROM projeto p WHERE p.cliente_id = c.id) AS total_projetos
	FROM cliente c
	LEFT JOIN ordem_servico os ON os.cliente_id = c.id
	LEFT JOIN vw_resumo_financeiro_os v ON v.ordem_servico_id = os.id
	GROUP BY c.id,c.nome
	ORDER BY faturamento_previsto DESC;
END$$

-- PROCEDURE 6: cursor percorre OS vencidas e eleva prioridade
CREATE PROCEDURE sp_recalcular_prioridade_atrasadas(OUT p_atualizadas INT)
BEGIN
	DECLARE v_id INT;
	DECLARE v_fim BOOLEAN DEFAULT FALSE;
	DECLARE cur_os CURSOR FOR
		SELECT id FROM ordem_servico
			WHERE data_previsao < NOW() AND status NOT IN ('concluida','cancelada')
			AND (prioridade IS NULL OR prioridade <> 'alta');
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = TRUE;
    
	SET p_atualizadas = 0;
    
	OPEN cur_os;
		leitura: LOOP
			FETCH cur_os INTO v_id;
			IF v_fim THEN LEAVE leitura; END IF;
		
			UPDATE ordem_servico SET prioridade = 'alta' WHERE id = v_id;
		
			SET p_atualizadas = p_atualizadas + 1;
		END LOOP;
	CLOSE cur_os;
END$$

-- FUNCTION 1: soma de servicos associados a OS
CREATE FUNCTION fn_valor_total_os(p_os_id INT) RETURNS DECIMAL(14,2)
READS SQL DATA
BEGIN
	DECLARE v_total DECIMAL(14,2);
    
	SELECT COALESCE(SUM(quantidade * valor_unitario),0) INTO v_total
	FROM ordem_servico_servico WHERE ordem_servico_id = p_os_id;
    
	RETURN v_total;
END$$

-- FUNCTION 2: quantidade de OS do cliente
CREATE FUNCTION fn_quantidade_os_cliente(p_cliente_id INT) RETURNS INT
READS SQL DATA
BEGIN
	DECLARE v_total INT;
    
	SELECT COUNT(*) INTO v_total FROM ordem_servico WHERE cliente_id = p_cliente_id;
    
	RETURN v_total;
END$$

-- FUNCTION 3: dias decorridos desde abertura
CREATE FUNCTION fn_dias_em_aberto(p_os_id INT) RETURNS INT
READS SQL DATA
BEGIN
	DECLARE v_dias INT DEFAULT NULL;
    
	SELECT DATEDIFF(COALESCE(data_conclusao,NOW()),data_abertura)
	INTO v_dias FROM ordem_servico WHERE id = p_os_id;
    
	RETURN v_dias;
END$$

-- FUNCTION 4: classificacao de prazo
CREATE FUNCTION fn_status_prazo(p_os_id INT) RETURNS VARCHAR(20)
READS SQL DATA
BEGIN
	DECLARE v_prazo DATETIME DEFAULT NULL;
	DECLARE v_status VARCHAR(30) DEFAULT NULL;
    
	IF NOT EXISTS (SELECT 1 FROM ordem_servico WHERE id = p_os_id) THEN RETURN 'inexistente'; END IF;
    
	SELECT data_previsao,status INTO v_prazo,v_status FROM ordem_servico WHERE id = p_os_id;
    
	IF v_status = 'concluida' THEN RETURN 'concluida'; END IF;
	IF v_prazo IS NULL THEN RETURN 'sem_prazo'; END IF;
	IF v_prazo < NOW() THEN RETURN 'atrasada'; END IF;
    
	RETURN 'no_prazo';
END$$

-- FUNCTION 5: horas estimadas multiplicadas por quantidade
CREATE FUNCTION fn_total_horas_os(p_os_id INT) RETURNS INT
READS SQL DATA
BEGIN
	DECLARE v_horas INT;
    
	SELECT COALESCE(SUM(oss.quantidade * COALESCE(s.tempo_estimado,0)),0)
	INTO v_horas FROM ordem_servico_servico oss
	INNER JOIN servico s ON s.id = oss.servico_id
	WHERE oss.ordem_servico_id = p_os_id;
    
	RETURN v_horas;
END$$

-- FUNCTION 6: colaboradores distintos por OS
CREATE FUNCTION fn_quantidade_colaboradores(p_os_id INT) RETURNS INT
READS SQL DATA
BEGIN
	DECLARE v_total INT;
    
	SELECT COUNT(DISTINCT funcionario_id) INTO v_total
	FROM ordem_servico_colaborador WHERE ordem_servico_id = p_os_id;
    
	RETURN v_total;
END$$

-- TRIGGER 1: impede documento vazio
CREATE TRIGGER trg_cliente_bi_documento BEFORE INSERT ON cliente
FOR EACH ROW
BEGIN
	IF NEW.documento IS NULL OR TRIM(NEW.documento) = '' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Documento obrigatorio';
	END IF;
END$$

-- TRIGGER 2: valida periodo do projeto
CREATE TRIGGER trg_projeto_bi_datas BEFORE INSERT ON projeto
FOR EACH ROW
BEGIN
	IF NEW.data_inicio IS NOT NULL AND NEW.data_fim IS NOT NULL
    AND NEW.data_fim < NEW.data_inicio THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fim do projeto anterior ao inicio';
	END IF;
END$$

-- TRIGGER 3: valida prazo inicial da OS
CREATE TRIGGER trg_os_bi_datas BEFORE INSERT ON ordem_servico
FOR EACH ROW
BEGIN
	IF NEW.data_previsao IS NOT NULL AND NEW.data_previsao < NEW.data_abertura THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Previsao anterior a abertura';
	END IF;
END$$

-- TRIGGER 4: preenche data de conclusao automaticamente
CREATE TRIGGER trg_os_bu_conclusao BEFORE UPDATE ON ordem_servico
FOR EACH ROW
BEGIN
	IF NEW.status = 'concluida' AND OLD.status <> 'concluida' THEN
		SET NEW.data_conclusao = NOW();
	ELSEIF NEW.status <> 'concluida' AND OLD.status = 'concluida' THEN
		SET NEW.data_conclusao = NULL;
	END IF;
    
	IF NEW.data_conclusao IS NOT NULL AND NEW.data_conclusao < NEW.data_abertura THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conclusao anterior a abertura';
	END IF;
END$$

-- TRIGGER 5: valida itens de servico
CREATE TRIGGER trg_oss_bi_validar BEFORE INSERT ON ordem_servico_servico
FOR EACH ROW
BEGIN
	IF NEW.quantidade IS NULL OR NEW.quantidade <= 0
	OR NEW.valor_unitario IS NULL OR NEW.valor_unitario < 0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantidade ou valor invalido';
	END IF;
END$$

-- TRIGGER 6: auditoria de mudanca de status
CREATE TRIGGER trg_os_au_historico AFTER UPDATE ON ordem_servico
FOR EACH ROW
BEGIN
	IF NOT (OLD.status <=> NEW.status) THEN
		INSERT INTO historico_os(acao,status_anterior,status_novo,data_hora,descricao,ordem_servico_id)
		VALUES('Alteracao de status',OLD.status,NEW.status,NOW(),
			'Registro automatico por trigger',NEW.id);
	END IF;
END$$
DELIMITER ;

-- EXEMPLOS (executar separadamente, apos conferir IDs e dados existentes):
-- CALL sp_abrir_os('Falha de rede','Sem conectividade','alta',1,1,1,1);
-- CALL sp_alterar_status_os(1,'em_andamento');
-- CALL sp_atribuir_responsavel(1,1);
-- CALL sp_adicionar_servico_os(1,1,2);
-- CALL sp_relatorio_clientes();
-- CALL sp_recalcular_prioridade_atrasadas(@total); SELECT @total;
-- SELECT fn_valor_total_os(1),fn_quantidade_os_cliente(1),fn_dias_em_aberto(1);
-- SELECT fn_status_prazo(1),fn_total_horas_os(1),fn_quantidade_colaboradores(1);

