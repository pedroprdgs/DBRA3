<?php
    $host = "localhost";
    $banco = "sistema_ordens_servico";
    $usuario = "root";
    $senha = "root";

    $mysqli = new mysqli($host, $usuario, $senha, $banco);

    if ($mysqli->connect_error) {
        die("Erro ao se conectar ao banco: $mysqli->connect_error");
    }
?>