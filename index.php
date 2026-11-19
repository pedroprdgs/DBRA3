<?php
  require_once(__DIR__ . '/config/connection.php');

  $sql = "
    SELECT
      os.id,
      os.titulo,
      os.status,
      os.prioridade,
      os.data_abertura,
      os.data_previsao,
      c.nome AS cliente,
      f.nome AS responsavel,
      fn_status_prazo(os.id) AS situacao_prazo
    FROM ordem_servico os
    INNER JOIN cliente c ON c.id = os.cliente_id
    LEFT JOIN funcionario f ON f.id = os.funcionario_responsavel_id
    ORDER BY os.data_abertura DESC
  ";
    
  $res = $mysqli->query($sql);
  $ordens = $res->fetch_all(MYSQLI_ASSOC);

  $clientes = $mysqli->query("
    SELECT id, nome
    FROM cliente
    WHERE ativo = 1
    ORDER BY nome
  ")->fetch_all(MYSQLI_ASSOC);

  $departamentos = $mysqli->query("
    SELECT id, nome
    FROM departamento
    WHERE ativo = 1
    ORDER BY nome
  ")->fetch_all(MYSQLI_ASSOC);

  $funcionarios = $mysqli->query("
    SELECT id, nome
    FROM funcionario
    WHERE ativo = 1
    ORDER BY nome
  ")->fetch_all(MYSQLI_ASSOC);

  $categorias = $mysqli->query("
    SELECT id, nome
    FROM categoria_servico
    WHERE ativo = 1
    ORDER BY nome
  ")->fetch_all(MYSQLI_ASSOC);

  $total = count($ordens);

  $pendentes = count(array_filter(
    $ordens,
    fn($os) => $os['status'] === 'aberta'
  ));

  $andamento = count(array_filter(
    $ordens,
    fn($os) => $os['status'] === 'em_andamento'
  ));

  $concluidas = count(array_filter(
    $ordens,
    fn($os) => $os['status'] === 'concluida'
  ));
?>

<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SGOS | Sistema de Ordens de Serviço</title>
  <link rel="stylesheet" href="./css/style.css">
</head>
<body>
  <div class="layout">
    <aside>
      <div class="logo">SGOS</div>
      <div class="sublogo">Sistema de Gestão de Ordens de Serviço</div>
      <div class="menu-titulo">Menu principal</div>
      <nav>
        <a class="ativo" href="#inicio">▦ &nbsp; Dashboard</a>
        <a href="#ordens">▤ &nbsp; Ordens de serviço</a>
        <a href="#cadastro">+ &nbsp; Nova ordem</a>
        <a href="#clientes">♙ &nbsp; Clientes</a>
        <a href="#projetos">▣ &nbsp; Projetos</a>
      </nav>
    </aside>

    <main>
      <header>
        <strong>Sistema de Gestão de Ordens de Serviço</strong>
        <span class="usuario">Usuário: Administrador</span>
      </header>

      <div class="conteudo" id="inicio">
        <?php if (($_GET['cadastro'] ?? '') === 'sucesso'): ?>
          <div class="alerta-sucesso">
            Ordem de serviço cadastrada com sucesso!
          </div>
        <?php endif; ?>
        <section class="titulo">
          <div>
            <h1>Dashboard</h1>
            <p class="descricao">Acompanhe o resumo das ordens de serviço do sistema.</p>
          </div>
          <a class="botao" href="#cadastro">+ Nova ordem de serviço</a>
        </section>

        <section class="cards">
          <div class="card">
            <div class="card-label">Total de ordens</div>
            <div class="card-numero"><?= $total ?></div>
            <div class="card-detalhe">Ordens registradas</div>
          </div>
          <div class="card">
            <div class="card-label">Pendentes</div>
            <div class="card-numero"><?= $pendentes ?></div>
            <div class="card-detalhe">Aguardando atendimento</div>
          </div>
          <div class="card">
            <div class="card-label">Em andamento</div>
            <div class="card-numero"><?= $andamento ?></div>
            <div class="card-detalhe">Em execução pela equipe</div>
          </div>
          <div class="card">
            <div class="card-label">Concluídas</div>
            <div class="card-numero"><?= $concluidas ?></div>
            <div class="card-detalhe">Serviços finalizados</div>
          </div>
        </section>

        <section class="painel" id="cadastro">
          <div class="painel-cabecalho">
            <h2>Cadastrar ordem de serviço</h2>
          </div>
          <div class="painel-corpo">
            <form action="cadastrar_os.php" method="post">
              <div class="form-grid">
                <div class="campo">
                  <label for="titulo">Título da ordem</label>
                  <input type="text" name="titulo" id="titulo" maxlength="150" required>
                </div>

                <div class="campo">
                  <label for="cliente">Cliente *</label>
                  <select name="cliente_id" id="cliente" required>
                    <option value="">Selecione um cliente</option>

                    <?php foreach ($clientes as $cliente): ?>
                      <option value="<?= $cliente['id'] ?>">
                        <?= htmlspecialchars($cliente['nome']) ?>
                      </option>
                    <?php endforeach; ?>
                  </select>
                </div>

                <div class="campo">
                  <label for="departamento">Departamento *</label>
                  <select name="departamento_id" id="departamento" required>
                    <option value="">Selecione um departamento</option>

                    <?php foreach ($departamentos as $departamento): ?>
                      <option value="<?= $departamento['id'] ?>">
                        <?= htmlspecialchars($departamento['nome']) ?>
                      </option>
                    <?php endforeach; ?>
                  </select>
                </div>

                <div class="campo">
                  <label for="categoria">Categoria de serviço *</label>
                  <select name="categoria_id" id="categoria" required>
                    <option value="">Selecione uma categoria</option>

                    <?php foreach ($categorias as $categoria): ?>
                      <option value="<?= $categoria['id'] ?>">
                        <?= htmlspecialchars($categoria['nome']) ?>
                      </option>
                    <?php endforeach; ?>
                  </select>
                </div>
              </div>

              <div class="campo">
                <label for="categoria">Funcionário de abertura *</label>
                <select name="funcionario_id" id="funcionario" required>
                  <option value="">Selecione um funcionário</option>

                  <?php foreach ($funcionarios as $funcionario): ?>
                    <option value="<?= $funcionario['id'] ?>">
                      <?= htmlspecialchars($funcionario['nome']) ?>
                    </option>
                  <?php endforeach; ?>
                </select>
              </div>

              <div class="campo">
                <label for="prioridade">Prioridade *</label>
                <select name="prioridade" id="prioridade">
                  <option value="baixa">Baixa</option>
                  <option value="media" selected>Média</option>
                  <option value="alta">Alta</option>
                </select>
              </div>

              <div class="campo largo">
                <label for="descricao">Descrição do serviço</label>
                <textarea name="descricao" id="descricao" placeholder="Descreva o serviço solicitado..."></textarea>
              </div>

              <div class="acoes">
                <input type="reset" value="Limpar" class="botao-secundario">
                <button class="botao" type="submit">Cadastrar ordem</button>
              </div>
            </form>
          </div>
        </section>

        <section class="painel" id="ordens">
          <div class="painel-cabecalho">
            <h2>Ordens de serviço recentes</h2>
            <div class="filtros">
              <input type="search" placeholder="Buscar ordem...">
              <select aria-label="Filtrar por status">
                <option>Todos os status</option>
                <option>Pendente</option>
                <option>Em andamento</option>
                <option>Concluída</option>
              </select>
            </div>
          </div>
          <div class="tabela-wrap">
            <table>
              <thead>
                <tr>
                  <th>Código</th>
                  <th>Ordem de serviço</th>
                  <th>Cliente</th>
                  <th>Responsável</th>
                  <th>Data</th>
                  <th>Status</th>
                  <th>Situação do Prazo</th>
                </tr>
              </thead>
              <tbody>
                <?php foreach ($ordens as $os): ?>
                  <?php
                    $statusClasses = [
                      'aberta' => 'pendente',
                      'em_andamento' => 'andamento',
                      'concluida' => 'concluida',
                      'cancelada' => 'cancelada'
                    ];

                    $statusNomes = [
                      'aberta' => 'Aberta',
                      'em_andamento' => 'Em andamento',
                      'concluida' => 'Concluída',
                      'cancelada' => 'Cancelada'
                    ];

                    $classe = $statusClasses[$os['status']] ?? '';
                    $nomeStatus = $statusNomes[$os['status']] ?? $os['status'];
                  ?>

                  <tr>
                    <td class="codigo">
                      #OS-<?= str_pad($os['id'], 3, '0', STR_PAD_LEFT) ?>
                    </td>

                    <td>
                      <?= htmlspecialchars($os['titulo']) ?>
                    </td>

                    <td>
                      <?= htmlspecialchars($os['cliente']) ?>
                    </td>

                    <td>
                      <?= htmlspecialchars($os['responsavel'] ?? 'Não atribuído') ?>
                    </td>

                    <td>
                      <?= date('d/m/Y', strtotime($os['data_abertura'])) ?>
                    </td>

                    <td>
                      <span class="status <?= $classe ?>">
                        <?= htmlspecialchars($nomeStatus) ?>
                      </span>
                    </td>

                    <td>
                      <?= htmlspecialchars($os['situacao_prazo']) ?>
                    </td>
                  </tr>
                <?php endforeach; ?>
              </tbody>
            </table>
          </div>
        </section>
        <div class="rodape">SGOS — Sistema de Gestão de Ordens de Serviço</div>
      </div>
    </main>
  </div>
</body>
</html>