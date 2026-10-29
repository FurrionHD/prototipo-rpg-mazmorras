# PRUEBA (29/10): LOS CANALES Y LA BARRERA CON PERDIDAS DE VERDAD (scripts/net/net_canales.gd). Una sala y un cliente en
# este proceso, cada uno con su SceneMultiplayer, hablando por un RELE UDP que pierde el 10 % de los paquetes y les pone
# 25 ms por sentido (un Steam malo). Sin el juego: solo la red.
#   1) LO QUE GANAN LOS CANALES: la sala manda a la vez un chorro del hogar (1 KB por mensaje, a ritmo fijo) y golpes
#      de pelea pequeños. Se mide cuanto tardan los golpes con todo por el canal 0 y con cada cosa en el suyo, en RONDAS
#      ALTERNADAS y con la MISMA perdida en las dos de cada pareja (semilla): en el banco van tres pruebas a la vez y,
#      medido un modo detras del otro, la carga del PC decidia mas que los canales (29/10: salio al reves una vez).
#      Solo falla si con canales la MEDIANA va peor.
#   2) LA BARRERA: la sala manda una racha de cambios por el hogar y enseguida pide el estado por la partida, como el
#      guardado (_dame_tu_estado). Con barrera, el estado cuenta SIEMPRE todos los cambios. Sin ella (de control),
#      alguna vez no: si nunca falla sin barrera, la prueba no estaria probando nada y lo dice.
#   <godot> --headless --path . res://tools/prueba_canales_perdidas.tscn
extends Node

const NC := preload("res://scripts/net/net_canales.gd")
const PUERTO_SALA := 24630
const PUERTO_RELE := 24631
const PERDIDA := 0.10
const RETRASO_MS := 25
const RONDAS_BARRERA := 30
const RONDAS_MEDIDA := 3          # parejas de rondas (canal 0 / cada uno el suyo), alternadas
const SEG_RONDA := 3.0
const HOGAR_POR_SEG := 120.0      # el chorro del hogar, por TIEMPO (no por fotograma: con el PC cargado cambiaria)
const CAMBIOS_POR_RONDA := 40


# Lo que se hablan la sala y el cliente: un nodo con el mismo nombre en los dos lados.
class Hilo extends Node:
	var golpes_ms: Array = []     # cliente: cuanto ha tardado cada golpe
	var cambios := 0              # cliente: cambios del hogar recibidos
	var respuestas: Array = []    # sala: [ronda, cambios que contaba el cliente al responder]
	var canales: Node = null      # el NetCanales de este lado

	@rpc("authority", "call_remote", "reliable", NC.CONTROL)
	func hogar_en_cero(_relleno: PackedByteArray) -> void:
		cambios += 1

	@rpc("authority", "call_remote", "reliable", NC.CONTROL)
	func golpe_en_cero(t_ms: int) -> void:
		golpes_ms.append(Time.get_ticks_msec() - t_ms)

	@rpc("authority", "call_remote", "reliable", NC.HOGAR)
	func hogar_en_su_canal(_relleno: PackedByteArray) -> void:
		cambios += 1

	@rpc("authority", "call_remote", "reliable", NC.COMBATE)
	func golpe_en_su_canal(t_ms: int) -> void:
		golpes_ms.append(Time.get_ticks_msec() - t_ms)

	# Como _dame_tu_estado: con barrera > 0 espera a tener todo lo de antes; con 0, contesta ya.
	@rpc("authority", "call_remote", "reliable", NC.PARTIDA)
	func dame_tu_estado(ronda: int, barrera: int) -> void:
		var de := multiplayer.get_remote_sender_id()
		await canales.pasada(de, barrera)
		mi_estado.rpc_id(1, ronda, cambios)

	@rpc("any_peer", "call_remote", "reliable", NC.PARTIDA)
	func mi_estado(ronda: int, n: int) -> void:
		respuestas.append([ronda, n])


var fallos := 0
var _sala: SceneMultiplayer
var _cli: SceneMultiplayer
var _hilo_s: Hilo
var _hilo_c: Hilo
var _canales_s: Node
var _rele := PacketPeerUDP.new()
var _puerto_cliente := 0
var _cola: Array = []   # [cuando_ms, puerto_destino, datos]


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 240
	call_deferred("_correr")


# EL RELE: lo del cliente va a la sala y lo de la sala al cliente, perdiendo PERDIDA y con RETRASO_MS.
func _process(_delta: float) -> void:
	while _rele.get_available_packet_count() > 0:
		var p: PackedByteArray = _rele.get_packet()
		var desde: int = _rele.get_packet_port()
		var hacia: int = 0
		if desde == PUERTO_SALA:
			hacia = _puerto_cliente
		else:
			_puerto_cliente = desde
			hacia = PUERTO_SALA
		if hacia != 0 and randf() >= PERDIDA:
			_cola.append([Time.get_ticks_msec() + RETRASO_MS, hacia, p])
	var ahora := Time.get_ticks_msec()
	while not _cola.is_empty() and int(_cola[0][0]) <= ahora:
		var c: Array = _cola.pop_front()
		_rele.set_dest_address("127.0.0.1", int(c[1]))
		_rele.put_packet(c[2])


func _lado(nombre: String) -> Array:
	var raiz := Node.new()
	raiz.name = nombre
	add_child(raiz)
	var hilo := Hilo.new()
	hilo.name = "Hilo"
	raiz.add_child(hilo)
	var canales: Node = NC.new()
	canales.name = "Canales"
	raiz.add_child(canales)
	hilo.canales = canales
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, raiz.get_path())
	return [api, hilo, canales]


func _correr() -> void:
	ok(_rele.bind(PUERTO_RELE, "127.0.0.1") == OK, "el rele escucha")
	var s: Array = _lado("Sala")
	_sala = s[0]
	_hilo_s = s[1]
	_canales_s = s[2]
	var c: Array = _lado("Cliente")
	_cli = c[0]
	_hilo_c = c[1]
	var ps := ENetMultiplayerPeer.new()
	ok(ps.create_server(PUERTO_SALA, 4) == OK, "la sala escucha")
	_sala.multiplayer_peer = ps
	var pc := ENetMultiplayerPeer.new()
	ok(pc.create_client("127.0.0.1", PUERTO_RELE) == OK, "el cliente conecta por el rele")
	_cli.multiplayer_peer = pc
	var t := 0.0
	while _sala.get_peers().is_empty() and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	ok(not _sala.get_peers().is_empty(), "conectados")
	var cli_id: int = _sala.get_peers()[0]

	# 1) LO QUE GANAN LOS CANALES
	var g_cero: Array = []
	var g_sep: Array = []
	for r in RONDAS_MEDIDA:
		g_cero.append_array(await _medir(cli_id, false, 1000 + r))
		g_sep.append_array(await _medir(cli_id, true, 1000 + r))
	var en_cero: Array = _resumen(g_cero)
	var separados: Array = _resumen(g_sep)
	print("    golpes con todo por el 0:    mediana %.0f ms, media %.0f, p95 %.0f, peor %.0f (%d golpes)" % en_cero)
	print("    golpes con cada uno el suyo: mediana %.0f ms, media %.0f, p95 %.0f, peor %.0f (%d golpes)" % separados)
	ok(int(en_cero[4]) > 100 and int(separados[4]) > 100, "llegan los golpes de las dos maneras")
	ok(float(separados[0]) <= float(en_cero[0]), "con canales los golpes no van peor (mediana %.0f frente a %.0f ms)" % [
		separados[0], en_cero[0]])

	# 2) LA BARRERA
	var sin: int = await _rondas(cli_id, false)
	var con: int = await _rondas(cli_id, true)
	print("    estado que no contaba todo lo de antes: sin barrera %d de %d, con barrera %d de %d" % [
		sin, RONDAS_BARRERA, con, RONDAS_BARRERA])
	ok(sin > 0, "sin barrera, alguna vez el estado sale sin todo lo de antes (si no, esto no prueba nada)")
	ok(con == 0, "con barrera, el estado cuenta SIEMPRE todo lo de antes")
	ok(_canales_s.plazos_vencidos == 0 and _hilo_c.canales.plazos_vencidos == 0, "ninguna barrera se queda sin completar")

	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


# Una ronda de SEG_RONDA: el chorro del hogar a HOGAR_POR_SEG y un golpe cada 50 ms, con la perdida sorteada desde
# 'semilla'. Devuelve lo que tardo cada golpe (ms).
func _medir(cli_id: int, separados: bool, semilla: int) -> Array:
	_hilo_c.golpes_ms.clear()
	seed(semilla)
	var relleno := PackedByteArray()
	relleno.resize(1024)
	var t0 := Time.get_ticks_msec()
	var fin := t0 + int(SEG_RONDA * 1000.0)
	var hogar_mandados := 0
	var t_golpe := 0
	while Time.get_ticks_msec() < fin:
		var deben: int = int((Time.get_ticks_msec() - t0) / 1000.0 * HOGAR_POR_SEG)
		while hogar_mandados < deben:
			hogar_mandados += 1
			if separados:
				_hilo_s.hogar_en_su_canal.rpc_id(cli_id, relleno)
			else:
				_hilo_s.hogar_en_cero.rpc_id(cli_id, relleno)
		if Time.get_ticks_msec() >= t_golpe:
			t_golpe = Time.get_ticks_msec() + 50
			if separados:
				_hilo_s.golpe_en_su_canal.rpc_id(cli_id, Time.get_ticks_msec())
			else:
				_hilo_s.golpe_en_cero.rpc_id(cli_id, Time.get_ticks_msec())
		await get_tree().process_frame
	# Lo que quede en camino.
	var hasta := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < hasta:
		await get_tree().process_frame
	return _hilo_c.golpes_ms.duplicate()


# [mediana, media, p95, peor, cuantos]
func _resumen(g: Array) -> Array:
	if g.is_empty():
		return [0.0, 0.0, 0.0, 0.0, 0]
	g.sort()
	var suma := 0.0
	for x in g:
		suma += float(x)
	return [float(g[g.size() / 2]), suma / g.size(), float(g[int(g.size() * 0.95)]), float(g[-1]), g.size()]


# Cuantas rondas el estado NO contaba todos los cambios mandados antes de pedirlo.
func _rondas(cli_id: int, con_barrera: bool) -> int:
	_hilo_s.respuestas.clear()
	var relleno := PackedByteArray()
	relleno.resize(1024)
	var mal := 0
	for ronda in RONDAS_BARRERA:
		_hilo_c.cambios = 0
		# Que no quede nada de la ronda anterior en camino.
		await get_tree().create_timer(0.3).timeout
		_hilo_c.cambios = 0
		for i in CAMBIOS_POR_RONDA:
			_hilo_s.hogar_en_su_canal.rpc_id(cli_id, relleno)
		var b: int = _canales_s.barrera(cli_id) if con_barrera else 0
		_hilo_s.dame_tu_estado.rpc_id(cli_id, ronda, b)
		var t0 := Time.get_ticks_msec()
		while _hilo_s.respuestas.size() <= ronda and Time.get_ticks_msec() - t0 < 12000:
			await get_tree().process_frame
		if _hilo_s.respuestas.size() <= ronda or int(_hilo_s.respuestas[ronda][1]) < CAMBIOS_POR_RONDA:
			mal += 1
	return mal
