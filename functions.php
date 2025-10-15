<?php
session_start();

function isLogged() {
    return isset($_SESSION['user_id']);
}

function redirectIfNotLogged() {
    if (!isLogged()) {
        header("Location: ../index.php");
        exit;
    }
}

function login($pdo, $email, $senha) {
    $stmt = $pdo->prepare("SELECT * FROM usuarios WHERE email = ? AND senha = ?");
    $stmt->execute([$email, md5($senha)]);
    $user = $stmt->fetch();
    if ($user) {
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['user_email'] = $user['email'];
        return true;
    }
    return false;
}

function logout() {
    session_destroy();
}
