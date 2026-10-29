# PRUEBA (29/10, "Steam colgado"): LOS PLAZOS DE LA ENTRADA y su reintento (Net.fase_entrada). Ninguna espera de la
# entrada se queda para siempre: vence, se dice, se reintenta UNA vez sola y, si tampoco, se dice que no se ha podido.
#   A) nadie escucha en el puerto: se atasca "conectando" (por el plazo o porque ENet se rinde antes), dos veces.
#   B) una SALA MUDA (ENet que acepta la conexion y no contesta nunca, como una sala colgada o de otro build): conecta,
#      se atasca en el "saludo", reintenta (la sala ve llegar DOS conexiones) y se rinde.
#   C) una sala A MEDIAS que me pide crear personaje y luego no contesta al alta: se atasca en el "alta".
#   D) una sala A MEDIAS que me da mi personaje y luego no me presenta: se atasca en la "presentacion", que ya me habia
#      llevado a mi pueblo; me devuelve al menu, reintenta desde alli y se rinde.
# La sala a medias va en ESTE proceso: un subarbol con su propio SceneMultiplayer y, dentro, Net/Partida con el script de
# verdad (mismos mensajes, mismos canales). Lo que le contesto (_listo, el alta) cae en ese script, que no hace nada
# porque esta maquina no es anfitrion: es justo una sala que se calla a media entrada. (Lo que le mando a Net, a
# Net/Jugadores o a Net/Pisos -el saludo, mi posicion, mi aspecto- no lo tiene nadie en ese subarbol: Godot lo apunta
# como ERROR ("Node not found", "rpc node checksum failed") y lo tira. Son de la prueba, no del juego.)
# La prueba cuelga de la RAIZ y no de la escena: D cambia de escena (al menu) y se la llevaria por delante.
# Un solo proceso, sin ventana:
#   <godot> --headless --path . res://tools/prueba_sala_muda.tscn
extends Node

const PUERTO_NADIE := 24620
const PUERTO_MUDA := 24621
const PUERTO_A_MEDIAS := 24622
const NetPartida = preload("res://scripts/net/net_partida.gd")

var fallos := 0
var _avisos: Array[String] = []
var _muda: ENetConnection = null
var _llegadas_muda := 0
# La sala a medias: que hace cuando llega alguien ("crea" = le pide crear personaje; "jugador" = le da el suyo).
var _a_medias: SceneMultiplayer = null
var _partida_falsa: Node = null
var _modo_a_medias := ""
var _llegadas_a_medias := 0
var _jd_red: Array = []
var _altas := 0


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not has_meta("en_la_raiz"):
		# La de la escena solo cuelga a la de verdad de la raiz.
		var yo: Node = (get_script() as Script).new()
		yo.name = "PruebaSalaMudaRaiz"
		yo.set_meta("en_la_raiz", true)
		get_tree().root.add_child.call_deferred(yo)
		return
	Net.estado_cambiado.connect(func(t: String): _avisos.append(t))
	Net.partida.pedir_personaje.connect(_crear_personaje)
	call_deferred("_correr")


# La sala muda: ENet a pelo, sin MultiplayerAPI. Acepta a quien llegue y no le dice nada.
func _process(_delta: float) -> void:
	if _muda == null:
		return
	var ev: Array = _muda.service()
	while not ev.is_empty() and int(ev[0]) != ENetConnection.EVENT_NONE:
		if int(ev[0]) == ENetConnection.EVENT_CONNECT:
			_llegadas_muda += 1
		ev = _muda.service()


func _montar_a_medias() -> void:
	var raiz := Node.new()
	raiz.name = "SalaAMedias"
	add_child(raiz)
	var net_falso := Node.new()
	net_falso.name = "Net"
	raiz.add_child(net_falso)
	_partida_falsa = NetPartida.new()
	_partida_falsa.name = "Partida"
	net_falso.add_child(_partida_falsa)
	_a_medias = SceneMultiplayer.new()
	get_tree().set_multiplayer(_a_medias, raiz.get_path())
	var peer := ENetMultiplayerPeer.new()
	ok(peer.create_server(PUERTO_A_MEDIAS, 8) == OK, "la sala a medias escucha")
	_a_medias.multiplayer_peer = peer
	_a_medias.peer_connected.connect(_llega_a_medias)


func _llega_a_medias(id: int) -> void:
	_llegadas_a_medias += 1
	await get_tree().create_timer(0.3, true).timeout   # como la de verdad: tras el saludo
	if _modo_a_medias == "crea":
		_partida_falsa._crea_tu_personaje.rpc_id(id, "Mundo de prueba")
	else:
		_partida_falsa._tu_jugador.rpc_id(id, _jd_red, 1234, {})


# Lo que haria el menu al pedirme personaje: lo creo y lo mando (a la sala a medias, que no contesta).
func _crear_personaje(_nombre_mundo: String) -> void:
	_altas += 1
	var pj := PersonajeData.new()
	pj.nombre = "Prueba"
	Game.asegurar_uid(pj)
	Net.partida.mandar_alta_personaje(pj)


# Espera a que la entrada acabe del todo: dos atascos (el primero y el del reintento) y sin sesion.
func _hasta_rendirse(tope: float) -> float:
	var t0 := Time.get_ticks_msec()
	while (Net.entradas_atascadas < 2 or Net.activo) and Time.get_ticks_msec() - t0 < int(tope * 1000.0):
		await get_tree().process_frame
	return (Time.get_ticks_msec() - t0) / 1000.0


func _caso(nombre: String, puerto: int, que_dice: String, tope: float) -> void:
	print("--- %s" % nombre)
	_avisos.clear()
	Net.entradas_atascadas = 0
	ok(Net.unirse("127.0.0.1", "codigo", puerto, true) == OK, "empiezo a entrar")
	var t: float = await _hasta_rendirse(tope)
	print("    avisos: %s" % str(_avisos))
	ok(Net.entradas_atascadas == 2, "se atasca dos veces: la entrada y su UNICO reintento (%d)" % Net.entradas_atascadas)
	ok(not Net.activo, "y se rinde: sin sesion (%.1f s)" % t)
	ok(t < tope, "sin quedarse esperando para siempre (%.1f s de %.0f)" % [t, tope])
	var segundo := _avisos.filter(func(a: String): return a.contains("Segundo intento"))
	var final := _avisos.filter(func(a: String): return a.contains("vuelve a intentarlo"))
	ok(segundo.size() == 1, "dice que lo reintenta, una vez")
	ok(final.size() == 1 and _avisos.find(final[0]) > _avisos.find(segundo[0]) if not segundo.is_empty() else false,
		"y al final, que no se ha podido")
	ok(_avisos.any(func(a: String): return a.contains(que_dice)), "y dice lo que ha pasado («%s»)" % que_dice)
	ok(Net._fase_entrada == "", "no queda ninguna fase en marcha")
	# UN PLAZO VIEJO no puede cortar nada: el de "conectando" del reintento (15 s desde que empezo) puede seguir en
	# marcha cuando la fase de despues ya se ha rendido. Se le deja vencer y no tiene que saltar.
	var antes: int = Net.entradas_atascadas
	await get_tree().create_timer(maxf(1.0, 16.0 - t / 2.0), true).timeout
	ok(Net.entradas_atascadas == antes, "ningun plazo viejo salta despues")


func _correr() -> void:
	# La ficha que da la sala a medias en D: la de la partida de referencia, como viajaria.
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	_jd_red = Net.zip(Net.partida.jd_a_red(Net.partida.jd_a_dict(Game.mi_jugador_data())))

	await _caso("A) nadie escucha", PUERTO_NADIE, "ninguna partida", 45.0)

	_muda = ENetConnection.new()
	ok(_muda.create_host_bound("127.0.0.1", PUERTO_MUDA, 8) == OK, "la sala muda escucha")
	await _caso("B) sala muda", PUERTO_MUDA, "no contesta", 30.0)
	ok(_llegadas_muda == 2, "a la sala muda le llegan dos conexiones: la entrada y el reintento (%d)" % _llegadas_muda)
	_muda.destroy()
	_muda = null

	_montar_a_medias()
	_modo_a_medias = "crea"
	await _caso("C) no contesta al alta", PUERTO_A_MEDIAS, "con tu personaje", 40.0)
	ok(_altas == 2, "me pide crear personaje en la entrada y en el reintento, y lo mando las dos (%d)" % _altas)

	_modo_a_medias = "jugador"
	var antes_llegadas: int = _llegadas_a_medias
	await _caso("D) no me presenta", PUERTO_A_MEDIAS, "a mitad de la entrada", 40.0)
	ok(_llegadas_a_medias - antes_llegadas == 2, "dos entradas: la primera y el reintento (%d)" % (_llegadas_a_medias - antes_llegadas))
	var escena: Node = get_tree().current_scene
	ok(escena != null and escena.scene_file_path == Mundos.MENU_MULTI,
		"y me deja en el menu, no en un pueblo sin sala (%s)" % (escena.scene_file_path if escena else "sin escena"))

	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
