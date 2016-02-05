<?php
require "../config/config.php";
require_once ROOT_PATH.'lib/ajax.class.php';

$ajax = new GCAjax();

$user = new GCUser();
$user->logout();
$ajax->success();
