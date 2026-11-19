<?php
    require_once(__DIR__ . '/config/connection.php');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        exit('Método não permitido');
    }

    $titulo = trim($_POST['titulo'] ?? '');
    $descricao = trim($_POST['descricao'] ?? '');
    $prioridade = $_POST['prioridade'] ?? '';

    $clienteId = filter_input(INPUT_POST, 'cliente_id', FILTER_VALIDATE_INT);
    $departamentoId = filter_input(INPUT_POST, 'departamento_id', FILTER_VALIDATE_INT);
    $funcionarioId = filter_input(INPUT_POST, 'funcionario_id', FILTER_VALIDATE_INT);
    $categoriaId = filter_input(INPUT_POST, 'categoria_id', FILTER_VALIDATE_INT);

    $prioridadesPermitidas = ['baixa', 'media', 'alta'];

    if (
        $titulo === '' ||
        strlen($titulo) > 150 ||
        !in_array($prioridade, $prioridadesPermitidas, true) ||
        !$clienteId ||
        !$departamentoId ||
        !$funcionarioId ||
        !$categoriaId
    ) {
        http_response_code(400);
        exit('Dados inválidos');
    }

    try {
        $stmt = $mysqli->prepare("CALL sp_abrir_os(?, ?, ?, ?, ?, ?, ?)");

        $stmt->bind_param(
            "sssiiii",
            $titulo,
            $descricao,
            $prioridade,
            $clienteId,
            $departamentoId,
            $funcionarioId,
            $categoriaId
        );

        $stmt->execute();

        $res = $stmt->get_result();
        $ordemCriada = $res->fetch_assoc();

        $stmt->close();

        header('Location: index.php?cadastro=sucesso#ordens');
        exit();
    } catch (mysqli_sql_exception $e) {
        http_response_code(500);
        exit('Erro ao cadastrar OS: ' . htmlspecialchars($e->getMessage()));
    }
?>