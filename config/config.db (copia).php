<?php
$domain=explode(".",$_SERVER["HTTP_HOST"]);
$userIp=$_SERVER['REMOTE_ADDR'];
$dbName='geoweb_genova';
$dbSchema='gisclient_33';
$dbUser = 'postgres';
$dbPwd = 'postgres';
$dbPort = 5433; 
$userSchema=$dbSchema;
$charSet='UTF-8';


if(in_array('geoweb',$domain)){
	$dbName='geoweb_genova';
	$dbSchema='gisclient_33';
	$userSchema=$dbSchema;
	define('PUBLIC_URL', 'http://geoweb.server2/');

	//define('MAPPROXY_URL', '/ows/');
	//define('MAP_URL', '/gisclient/template/');
    define('SUPER_USER','zio'); //Superutente author
    //define('PRINT_RELATIVE_URL_PREFIX', 'http://gisclient.rr.nu'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
}

if(in_array('testgrg',$domain)){
	$dbName='geoweb_genova';
	$dbSchema='gisclient_3';
	$userSchema=$dbSchema;
	define('PUBLIC_URL', '/gisclient/');
	define('MAP_URL', '/gisclient/maps/');
	define('GISCLIENT_OWS_URL','/gisclient/services/ows.php');
    define('SUPER_USER','admin'); //Superutente author
    define('PRINT_RELATIVE_URL_PREFIX', 'http://testgrg.gisclient.vmserver/'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
	define('CLIENT_LOGO', 'http://testgrg.gisclient.vmserver/images/logo-consorzio.png');
	//define('MAPPROXY_URL', '/ows/');
	//define('MAP_URL', '/gisclient/template/');
    //define('PRINT_RELATIVE_URL_PREFIX', 'http://gisclient.rr.nu'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
}

if(in_array('maciste',$domain)){
	$dbName='maciste_antartide';
	$dbSchema='gisclient_34';
	$userSchema=$dbSchema;
	define('PUBLIC_URL', '/gisclient/');
	define('MAP_URL', '/gisclient/maps/');
	define('GISCLIENT_OWS_URL','/gisclient/services/ows.php');
    define('SUPER_USER','zio'); //Superutente author
    define('PRINT_RELATIVE_URL_PREFIX', 'http://testgrg.gisclient.vmserver/'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
	define('CLIENT_LOGO', 'http://testgrg.gisclient.vmserver/images/logo-consorzio.png');
	//define('MAPPROXY_URL', '/ows/');
	//define('MAP_URL', '/gisclient/template/');
    //define('PRINT_RELATIVE_URL_PREFIX', 'http://gisclient.rr.nu'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
}



if(in_array('meta',$domain)){
	$dbName='meta';
	$dbSchema='gisclient_3';
	$userSchema=$dbSchema;
	define('PUBLIC_URL', 'http://meta.gisclient.vmserver/');
	define('MAP_URL', PUBLIC_URL.'maps/');
	define('GISCLIENT_OWS_URL',PUBLIC_URL.'/services/owsgw.php');
    define('SUPER_USER','davide'); //Superutente author
    define('PRINT_RELATIVE_URL_PREFIX', 'http://meta.gisclient.vmserver'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
	define('CLIENT_LOGO', 'http://meta.gisclient.vmserver/images/logo-consorzio.png');
	//define('MAPPROXY_URL', '/ows/');
	//define('MAP_URL', '/gisclient/template/');
    //define('PRINT_RELATIVE_URL_PREFIX', 'http://gisclient.rr.nu'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
}

if(in_array('alghero',$domain)){
	$dbName='sit_alghero';
	$dbSchema='gisclient_34';
	$userSchema=$dbSchema;
	$dbPort = 5432; 
	define('PUBLIC_URL', 'http://sit.alghero.vmserver/');
	define('MAP_URL', PUBLIC_URL.'maps/');
	define('GISCLIENT_OWS_URL',PUBLIC_URL.'services/ows.php');
	//define('MAPPROXY_URL', '/ows/');
	//define('MAP_URL', '/gisclient/template/');
    define('SUPER_USER','claudio'); //Superutente author
    define('PRINT_RELATIVE_URL_PREFIX', 'http://gisclient.rr.nu'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
}

if(in_array('bonificamarche',$domain)){
	$dbName='dbsit';
	$dbSchema='gisclient_3';
	$userSchema=$dbSchema;
	define('PUBLIC_URL', 'http://sit.bonificamarche.vmserver/');
	define('MAP_URL', PUBLIC_URL.'maps/');
	define('GISCLIENT_OWS_URL',PUBLIC_URL.'services/owsgw.php');
    define('SUPER_USER','davide'); //Superutente author
    define('PRINT_RELATIVE_URL_PREFIX', 'http://sit.bonificamarche.vmserver'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
	define('CLIENT_LOGO', 'http://sit.bonificamarche.vmserver/images/logo-consorzio.png');

}

if(in_array('parcoticino',$domain)){
	$dbName='parcoticino';
	$dbSchema='gisclient_33';
	$userSchema=$dbSchema;
	define('PUBLIC_URL', 'http://parcoticino.server2/');
	define('MAP_URL', PUBLIC_URL.'map/');
    define('SUPER_USER','admin'); //Superutente author
    //define('PRINT_RELATIVE_URL_PREFIX', 'http://consorziobonifica.rr.nu'); // se GISCLIENT_OWS_URL è relativo, questo prefisso viene aggiunto in fase di stampa
	define('CLIENT_LOGO', 'http://parcoticino.server2/map/images/logo_sx.png');

}



//if (!defined('GISCLIENT_OWS_URL')) define('GISCLIENT_OWS_URL','/gisclient/services/owsgw.php');
//Impostazioni database Postgresql;

	define('DB_NAME',$dbName);
	define('DB_SCHEMA',$dbSchema);
	if (!defined('USER_SCHEMA')) define('USER_SCHEMA', $userSchema);
	define('CHAR_SET',$charSet);
	define('DB_USER',$dbUser); //Superutente;
	define('DB_PWD',$dbPwd);
	define('DB_HOST','127.0.0.1');
	define('DB_PORT',$dbPort);
	
	//Utente scritto sul file .map;
	define('MAP_USER','mapserver');
	define('MAP_PWD','mapserver');
	define('POSTGIS_TRANSOFRM_GEOMETRY','postgis_transform_geometry');
	define('PRINT_SERVICE_PWD','printservice$');

	
$gMapKey = '';
$bingKey = 'AlFQX6e7DTj28pq390UUNj_uSgyuEsgouug_LZqPHs_NH7kk_WvrEnn7GXheP7sQ';
