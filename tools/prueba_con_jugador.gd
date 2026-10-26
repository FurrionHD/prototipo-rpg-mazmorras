# EL JUGADOR CON SU SALA (fase 2, etapa 4, paso 4). Para las pruebas que miran lo que hace la maquina DEL JUGADOR y no la
# sala: lo que se pinta (el orden de los muñecos), el HUD de la pelea, la huida que aplica el jugador al cerrar su
# espejo... La sala no pinta ni aplica eso, asi que aqui no vale que la prueba sea la sala (tools/prueba_sala_propia.gd):
# este proceso es EL JUGADOR. Prepara su ranura (desde mundo_ref), lanza su sala en otro Godot, se conecta como en el
# juego, entra en la arena y pelea pulsando, con la pelea en espejo (la ejecuta la sala). Dos Godot por prueba: va con
# las de red, de una en una.
#
#   var j = preload("res://tools/prueba_con_jugador.gd").new()
#   add_child(j)
#   if not await j.arrancar("prueba_orden_dibujo", 70): ...       # ranura 70, puerto 24570
#   var slime: Node2D = await j.poner("res://scenes/actors/enemy/slime.tres", Vector2(70, 0))
#   var combat: Node = await j.pelear(slime)                          # la pantalla del espejo
#   ...
#   await j.cerrar()
# Se lanza con -- nube_local (la sala sube la ranura a la nube LOCAL de pruebas).
extends "res://tools/prueba_town_dos_comun.gd"

const Sala = preload("res://scripts/net/sala.gd")
const CODIGO := "abc"

var slot: int = 0
var puerto: int = 0
var _p_sala: int = 0
var _pid_nube: String = ""
var _entrado := false


# Prepara la ranura, lanza la sala, me conecto y bajo a 'destino' (la arena, o un piso por la puerta del pueblo). false si
# algo no llega.
func arrancar(nombre: String, ranura: int, destino: int = Game.PISO_ARENA) -> bool:
	process_mode = Node.PROCESS_MODE_ALWAYS
	slot = ranura
	puerto = 24500 + ranura
	if Nube.es_remota():
		push_error("[con jugador] va con -- nube_local (si no, escribe en la nube de verdad)")
		return false
	Identidad.clave()
	Perfil.nube_activa = false
	_borrar_ranura()
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (ref is SaveData):
		return false
	var d: SaveData = ref
	d.mundo_compartido = false
	d.jugadores = {}
	d.en_mazmorra = false
	d.trazado = SaveData.TRAZADO_ACTUAL
	if not Perfil._guardar_bd(slot, d):
		return false
	Perfil._cerrar_bd()
	if not Perfil.convertir_a_mundo(slot).get("ok", false):
		return false
	var bd := PartidaBD.new()
	bd.abrir(Perfil.ruta_bd(slot))
	_pid_nube = Perfil._nube_id_de(bd)
	bd.cerrar()
	# Su sala, como la lanza Mundos._lanzar_sala (la contraseña por fichero).
	var clave: String = Mundos.clave_de_ranura(slot)
	DirAccess.make_dir_recursive_absolute(Sala.CARPETA)
	var f := FileAccess.open(Sala.ruta_pedido(clave), FileAccess.WRITE)
	f.store_string(CODIGO)
	f.close()
	_p_sala = OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", OS.get_user_data_dir().path_join("logs/%s_sala.log" % nombre), "--", "sala", clave, str(puerto),
		Identidad.id, "nube_local", "sala_vacia=3", "sala_espera=30"])
	var lista := false
	for i in 400:
		await get_tree().create_timer(0.1).timeout
		var est: Dictionary = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			lista = String(est.get("estado", "")) == "lista"
			break
	if not lista:
		push_error("[con jugador] la sala no arranca")
		return false
	# Entro como en el juego: al tener mi ficha, al pueblo.
	Net.partida.entrada_lista.connect(func():
		var arbol := get_tree()
		arbol.change_scene_to_file("res://scenes/levels/town.tscn")
		await arbol.process_frame
		Net.anunciar_lugar("pueblo")
		_entrado = true, CONNECT_ONE_SHOT)
	if Net.unirse("127.0.0.1", CODIGO, puerto, true) != OK:
		return false
	if not await _hasta(func(): return _entrado, 60.0):
		push_error("[con jugador] no entro en el mundo")
		return false
	await _esperar(1.0)
	# Abajo (la arena o el piso los lleva la sala). 'destino' 0 = me quedo en el pueblo (la prueba baja ella).
	if destino <= 0:
		print("[con jugador] %s: sala en el puerto %d, ranura %d, en el pueblo" % [nombre, puerto, slot])
		return true
	if destino == Game.PISO_ARENA:
		Game.entrar_arena_de_pruebas()
	else:
		Net.pisos.solicitar_entrar(destino)
	if not await _hasta(func(): return Net._mi_lugar == "piso:%d" % destino \
			and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0):
		push_error("[con jugador] no llego al piso %d" % destino)
		return false
	await _esperar(1.0)
	print("[con jugador] %s: sala en el puerto %d, ranura %d, en el piso %d" % [nombre, puerto, slot, destino])
	return true


# Un enemigo en la arena a 'desde' de mi cuerpo, por la sala (como el panel de la arena). Devuelve su espejo.
func poner(ruta: String, desde: Vector2, muneco: Dictionary = {}) -> Node2D:
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var antes: Array = Net.enemigos._enem_nodos.keys()
	Net.pisos.pedir_spawn_arena(ruta, yo.global_position + desde, muneco)
	var nuevo: Node2D = null
	var t := 0.0
	while nuevo == null and t < 10.0:
		for nid in Net.enemigos._enem_nodos:
			var n = Net.enemigos._enem_nodos[nid]
			if not antes.has(nid) and is_instance_valid(n):
				nuevo = n
		await _esperar(0.25)
		t += 0.25
	return nuevo


# Los espejos de enemigos, lejos y quietos: se sacan de la lista de la red para que lo que manda la sala (ir_a) no los
# devuelva a su sitio. Para las pruebas que no quieren enemigos en medio.
func apartar_enemigos() -> void:
	for n in get_tree().get_nodes_in_group("enemy"):
		(n as Node2D).global_position = Vector2(-9999, -9999)
		(n as Node).set_physics_process(false)
	Net.enemigos._enem_nodos.clear()


# Le pego y espero a mi pantalla (el espejo de la pelea que monta la sala). null si no se abre.
func pelear(nodo: Node2D) -> Node:
	await pelear_con(nodo)
	await _hasta(func(): return pantalla() != null and Net.peleas.espejando(), 10.0)
	return pantalla()


# Me voy, la sala se cierra sola (sala_vacia=3) y se borra la ranura.
func cerrar() -> void:
	Net.desconectar()
	var t := 0.0
	while _p_sala > 0 and OS.is_process_running(_p_sala) and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	if _p_sala > 0 and OS.is_process_running(_p_sala):
		OS.kill(_p_sala)
	if _pid_nube != "":
		await Nube.partida_borrar(_pid_nube)
	_borrar_ranura()


func _borrar_ranura() -> void:
	Perfil._cerrar_bd()
	PartidaBD.borrar(Perfil.ruta_bd(slot))


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()
