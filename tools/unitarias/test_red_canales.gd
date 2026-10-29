extends "res://tools/unitarias/caso.gd"
# Los canales de la red y la barrera (scripts/net/net_canales.gd, 29/10, protocolo 58).

const NC := preload("res://scripts/net/net_canales.gd")

# El canal de cada tema; las excepciones, por mensaje (el porque, en la cabecera de net_canales.gd).
const CANAL_DE := {
	"net": NC.CONTROL, "net_jugadores": NC.CONTROL, "net_peleas": NC.COMBATE, "net_pisos": NC.MUNDO,
	"net_enemigos": NC.MUNDO, "net_suelo": NC.MUNDO, "net_recoleccion": NC.MUNDO, "net_jefes": NC.MUNDO,
	"net_extraccion": NC.MUNDO, "net_pesca": NC.MUNDO, "net_mapa": NC.MUNDO, "net_hogar": NC.HOGAR,
	"net_formacion": NC.HOGAR, "net_partida": NC.PARTIDA, "net_fotos": NC.FOTOS,
}
const EXCEPCIONES := {"_set_aspecto": NC.CONTROL, "_rel_aspecto": NC.CONTROL, "_pedir_enemigos": NC.CONTROL}


func _config(tema: String) -> Dictionary:
	var s: Script = load("res://scripts/net/%s.gd" % tema)
	var c = s.get_rpc_config()
	return c if c is Dictionary else {}


func test_cada_mensaje_por_su_canal() -> void:
	var fiables := 0
	var no_fiables := 0
	for tema in CANAL_DE:
		var conf: Dictionary = _config(tema)
		cierto(not conf.is_empty(), "%s tiene mensajes" % tema)
		for metodo in conf:
			var m: Dictionary = conf[metodo]
			var canal: int = int(m.get("channel", 0))
			if int(m.get("transfer_mode", 0)) != MultiplayerPeer.TRANSFER_MODE_RELIABLE:
				# Lo no fiable, en el 0: alli ENet lo lleva por su carril y no espera a los reenvios de lo fiable.
				no_fiables += 1
				igual(canal, 0, "%s.%s (no fiable) en el 0" % [tema, metodo])
				continue
			fiables += 1
			igual(canal, int(EXCEPCIONES.get(String(metodo), CANAL_DE[tema])), "%s.%s" % [tema, metodo])
	igual(fiables + no_fiables, 197, "los 197 mensajes auditados (uno nuevo: pensar su canal y contarlo aqui)")
	igual(no_fiables, 11, "los no fiables")


func test_las_marcas_cada_una_por_su_canal() -> void:
	var conf: Dictionary = (NC as Script).get_rpc_config()
	var canales: Array = []
	for metodo in conf:
		canales.append(int((conf[metodo] as Dictionary).get("channel", -1)))
	canales.sort()
	igual(canales, NC.TODOS, "una marca por canal, y todas")


func test_barrera_espera_a_todos_los_canales() -> void:
	var c = NC.new()
	cierto(c.completa(7, 0), "sin barrera (un build de antes) no se espera")
	cierto(not c.completa(7, 1), "sin ninguna marca, no")
	for canal in [NC.CONTROL, NC.COMBATE, NC.MUNDO, NC.HOGAR, NC.PARTIDA]:
		c.apuntar_marca(7, canal, 1)
	cierto(not c.completa(7, 1), "falta la de las fotos")
	c.apuntar_marca(7, NC.FOTOS, 1)
	cierto(c.completa(7, 1), "con las seis, si")
	cierto(not c.completa(7, 2), "la siguiente aun no")
	cierto(not c.completa(8, 1), "las de otro peer no cuentan")
	c.free()


func test_barrera_una_marca_vieja_no_retrocede() -> void:
	var c = NC.new()
	for canal in NC.TODOS:
		c.apuntar_marca(3, canal, 5)
	c.apuntar_marca(3, NC.MUNDO, 2)   # una barrera vieja que llega tarde por otro camino
	cierto(c.completa(3, 5), "lo ya visto se queda visto")
	cierto(c.completa(3, 4), "y las de antes, tambien")
	c.olvidar_peer(3)
	cierto(not c.completa(3, 1), "al irse, se olvida")
	c.free()
