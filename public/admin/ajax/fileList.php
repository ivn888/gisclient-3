<?php
require_once "../../../config/config.php";
require_once ROOT_PATH.'lib/ajax.class.php';
require_once ADMIN_PATH.'lib/functions.php';

$ajax = new GCAjax();


$result = array('steps'=>1, 'data'=>array(), 'data_objects'=>array(), 'step'=>1, 'fields'=>array('file'=>'File'));
$n = 0;

$path = ADMIN_PATH.'export/';
if ($handle = opendir($path)) {
    while (false !== ($entry = readdir($handle))) {
        if ($entry == "." || $entry == "..") continue;
        $result['data'][$n] = array('file'=>$entry);
        $result['data_objects'][$n] = array('filename'=>$entry);
        $n++;
    }
    closedir($handle);
}


$ajax->success($result);