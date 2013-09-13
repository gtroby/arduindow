<?php

error_reporting (E_ALL ^ E_NOTICE);
set_time_limit (0);

// Requested fields 
$fields = array ("A_METEO_STAZ","P_DATA_AGG","A_LATITUDINE","A_LONGITUDIN","P_TOT_OGGI","P_TOT_1GG","T_ULTIMO_DATO");

$months = array ("JAN"=>1,"FEB"=>2,"MAR"=>3,"APR"=>4,"MAY"=>5,"JUN"=>6,"JUL"=>7,"AUG"=>8,"SEP"=>9,"OCT"=>10,"NOV"=>11,"DEC"=>12);
$p = array ();

// loads stuff from config.txt
function loadData () {
	global $meteoStation,$lastUpdate,$lastPrecip,$windowStatus;
	list ($meteoStation, $lastUpdate, $lastPrecip,$windowStatus)=explode("\n",file_get_contents ("config.txt"));
}

// updates config.txt
function updateData () {
	global $meteoStation,$lastUpdate,$lastePrecip,$windowStatus;
	$fp = fopen ("config.txt","w");
	fputs ($fp,"{$meteoStation}\n{$lastUpdate}\n{$lastPrecip}\n{$windowStatus}");
	fclose ($fp);
}

/*
 * gets and parses a JSON file.
 * I only found out about json_decode () seconds after I wrote this
 * function... And since I didn't feel like throwing away years and
 * years of hard work (maybe not that much, but still...) I decided
 * to use getJson () rather than json_decode ().
 */
function getJson () {
	global $fields;
	// JSON file URL
	$url = "http://webgis.arpa.piemonte.it/free/rest/services/climatologia-meteorologia-atmosfera/Pluviometri_tempo_reale_RADAR/MapServer/0/query?where=1%3D1&outFields=".join($fields,"%2C")."&f=json";
	$data = file_get_contents ($url);

	global $p;
	// Some parsing...
	while (preg_match ("|\"attributes\":\{(.+?)\}|",$data,$preg)) {
		$l = explode(",",$preg[1]);
		$index=trim(array_pop(explode("\":",$l[0])),'"');
		$p[$index]=array();
		for ($i=1;$i<count($l);$i++) {
			$tmp=explode("\":",$l[$i]);
			if (isset($tmp[1])) {
				$p[$index][trim($tmp[0],'"')]=trim($tmp[1],'"');
			}
		}
		preg_match ("|([0-9]{2})\-([A-Z]{3})\-([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2})|",$p[$index]['P_DATA_AGG'],$time);
		$p[$index]['TIMESTAMP']=mktime($time[4],$time[5],$time[6],$months[$time[2]],$time[1],$time[3]);
		$p[$index]['DELAY']=time()-$p[$index]['TIMESTAMP'];
		$data = str_replace ($preg[0],"",$data);
	}
}

loadData ();
getJson ();

if (!isset($p[$meteoStation])) {
	die ("[!] Meteo station non trovata :(\n");
}

$delta = (date("j",$p[$meteoStation]['TIMESTAMP'])!=date("j",$lastUpdate))?$p[$meteoStation]['P_TOT_OGGI']:$p[$meteoStation]['P_TOT_OGGI']-$lastPrecip;

// index.php?v => returns a JSON containing some
// interesting infos (see below to actually know
// what's being returned). Mainly used for the 
// iPhone (ewww :/) and, maybe, in a near future,
// for other devices as well (a web control panel
// would be really nice).
if (isset($_GET['v'])) {
	header ("Content-Type: application/json");
	echo "{\n";
	echo "\t\"date_fancy\": {$p[$meteoStation]['P_DATA_AGG']},\n";
	echo "\t\"timestamp\": {$p[$meteoStation]['TIMESTAMP']},\n";
	echo "\t\"delay\": {$p[$meteoStation]['DELAY']},\n";
	echo "\t\"temperature_celsius\": {$p[$meteoStation]['T_ULTIMO_DATO']},\n";
	echo "\t\"precip_day\": {$p[$meteoStation]['P_TOT_OGGI']},\n";
	echo "\t\"precip_delta\": {$delta},\n";
	echo "\t\"window_status\": {$windowStatus}\n";
	echo "}\n";

}
// index.php?r => the client is left hanging until
// either someone decides to open/close the window
// or it starts raining (this command is mainly used
// by the Arduino)
else if (isset($_GET['r'])) {
	$last=file_get_contents("config.txt");
	$new = $last;
	while ($p[$meteoStation]['TIMESTAMP']==$lastUpdate && $last==$new) {
		$new = file_get_contents ("config.txt");
		getJson();
	}
	$delta = (date("j",$p[$meteoStation]['TIMESTAMP'])!=date("j",$lastUpdate))?$p[$meteoStation]['P_TOT_OGGI']:$p[$meteoStation]['P_TOT_OGGI']-$lastPrecip;
	if ($new!=$last) {
		$delta = !($windowStatus=="close");
	}
	if ($delta>0) {
		echo "00";
		$windowStatus="close";
	}
	else {
		echo "99";
		$windowStatus="open";
	}
	$lastUpdate=$p[$meteoStation]['TIMESTAMP'];
	$lastPrecip=$p[$meteoStation]['P_TOT_OGGI'];
	updateData ();
}
// index.php?e&open  Opens the window 
// index.php?e&close Closes the window
else if (isset($_GET['e'])) {
	$action = (isset($_GET['open'])?'open':(isset($_GET['close'])?'close':''));
	if (!empty ($action)) {
		$windowStatus=$action;
		updateData ();
	}
}

?>
