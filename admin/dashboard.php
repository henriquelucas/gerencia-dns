<?php
require '../pdo.php';
require '../functions.php';
redirectIfNotLogged();

// Obter todas URLs
$stmt = $pdo->query("SELECT * FROM lista ORDER BY id DESC");
$urls = $stmt->fetchAll();
?>

<!doctype html>
<html lang="pt-br">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dashboard</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark bg-dark">
    <div class="container-fluid">
        <a class="navbar-brand" href="#">Admin Panel</a>
        <div class="d-flex">
            <a href="add-sites.php" class="btn btn-success me-2">Adicionar Site</a>
            <a href="../logout.php" class="btn btn-danger">Sair</a>
        </div>
    </div>
</nav>

<div class="container mt-4">
    <h3>Lista de Sites</h3>
    <table class="table table-bordered table-striped mt-3">
        <thead>
            <tr>
                <th>ID</th>
                <th>URL</th>
                <th>Tipo</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach($urls as $url): ?>
            <tr>
                <td><?= $url['id'] ?></td>
                <td><?= htmlspecialchars($url['url']) ?></td>
                <td><?= $url['tipo'] ?></td>
            </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
</div>
</body>
</html>
