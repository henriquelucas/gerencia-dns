<?php
require '../pdo.php';
require '../functions.php';
redirectIfNotLogged();

$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $url = $_POST['url'] ?? '';
    $tipo = $_POST['tipo'] ?? 'bloqueado';

    if ($url && in_array($tipo, ['bloqueado','permitido'])) {
        $stmt = $pdo->prepare("INSERT INTO lista (url, tipo) VALUES (?, ?)");
        $stmt->execute([$url, $tipo]);
        $message = "Site adicionado com sucesso!";
    } else {
        $message = "Dados inválidos!";
    }
}
?>

<!doctype html>
<html lang="pt-br">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Adicionar Site</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
<div class="container mt-4">
    <h3>Adicionar Site</h3>
    <?php if($message): ?>
        <div class="alert alert-info"><?= $message ?></div>
    <?php endif; ?>
    <form method="post" class="mt-3">
        <div class="mb-3">
            <label>URL</label>
            <input type="text" name="url" class="form-control" required>
        </div>
        <div class="mb-3">
            <label>Tipo</label>
            <select name="tipo" class="form-select">
                <option value="bloqueado">Bloqueado</option>
                <option value="permitido">Permitido</option>
            </select>
        </div>
        <button class="btn btn-primary">Adicionar</button>
        <a href="dashboard.php" class="btn btn-secondary">Voltar</a>
    </form>
</div>
</body>
</html>
