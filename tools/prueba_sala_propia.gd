# MI SALA DE PRUEBA (fase 2, etapa 4, paso 2). Jugar solo ya va siempre por la sala, asi que las pruebas que pelean no
# pueden seguir abriendo la pelea por el camino sin red (Game.start_combat en un proceso sin sesion): ese camino se borra.
# Decidido el 26/10: LA PRUEBA ES LA SALA. El proceso de la prueba arranca como la sala (su puerto, sacado del nombre de
# la prueba, para que vayan varias a la vez), monta el piso o la arena como lo monta ella (servidor_pisos, cada piso en
# su mundo), mete DENTRO al jugador con su grupo (player.tscn, que trae a sus compañeros) y abre la pelea por donde la
# abre la sala (Game.abrir_pelea_de_fichas con las fichas del grupo, colgada de un PeleaViva del piso).
#
# El grupo entra con peer 0, un JUGADOR DE MENTIRA: sus combatientes no tienen dueño, asi que la pantalla de la sala los
# juega desde esta maquina (combat_tactico._es_mio) y la prueba puede seguir tocando la pelea por dentro como antes. Un
# solo Godot por prueba. Lo que ve el jugador de verdad por la red lo prueban las town_*.
#
#   var sala = preload("res://tools/prueba_sala_propia.gd").new()
#   add_child(sala)
#   if not await sala.arrancar("prueba_alcances", Game.PISO_ARENA): ...
#   sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(200, -40))   # respecto al jugador
#   var combat: Node = await sala.pelear()                                  # con todos los enemigos del piso
extends Node

const _SERVIDOR := preload("res://scripts/net/servidor_pisos.gd")
const _JUGADOR := preload("res://scenes/actors/player/player.tscn")
const _SALA := preload("res://scripts/net/sala.gd")
# Las town_* van en el 246xx: estas, de 26000 a 26999 (una por nombre de prueba).
const PUERTO_BASE := 26000
const PUERTOS := 1000
# A nombre de quien quedan RESERVADOS los enemigos de la pelea (Net.peleas._enem_ocupados): no hay humano de verdad.
const PEER_PRUEBA := 1 << 29

var piso: PisoVivo = null
var jugador: Node2D = null
var pe: PeleaViva = null


static func puerto_de(nombre: String) -> int:
	return PUERTO_BASE + absi(hash(nombre)) % PUERTOS


# Este proceso pasa a ser la sala, con el piso 'numero' montado (Game.PISO_ARENA = la arena) y el jugador dentro.
# 'cargar_ref' = false: la prueba ya ha cargado mundo_ref y le ha puesto lo suyo (equipo, bolsa...).
func arrancar(nombre: String, numero: int, semilla: int = 424242, cargar_ref: bool = true) -> bool:
	if cargar_ref:
		var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
		if ref is SaveData:
			Game.importar_partida(ref)
	Game.semilla_mundo = semilla
	Net.soy_sala = true
	Net._mi_lugar = _SALA.ARG
	Net.servidor = _SERVIDOR.new()
	Net.servidor.name = "Pisos"
	Net.add_child(Net.servidor)
	# El puerto sale del nombre; si otra prueba que va a la vez cayo en el mismo, el siguiente libre.
	var puerto: int = -1
	for k in 20:
		if Net.hostear(nombre, PUERTO_BASE + (puerto_de(nombre) - PUERTO_BASE + k) % PUERTOS) == OK:
			puerto = PUERTO_BASE + (puerto_de(nombre) - PUERTO_BASE + k) % PUERTOS
			break
	if puerto < 0:
		push_error("[sala propia] no se pudo abrir ningun puerto desde el %d" % puerto_de(nombre))
		return false
	var juega: int = Game.arena_piso_juego if numero == Game.PISO_ARENA else numero
	Game.fijar_piso(numero)
	piso = Net.servidor.montar(numero, juega)
	Net._dueno_piso[numero] = 1
	# El jugador entra YA: el piso lo coloca en la entrada al construirse (dungeon_floor busca al 'player' de su piso).
	jugador = _JUGADOR.instantiate()
	piso.add_child(jugador)
	var suelo: Node = null
	for i in 600:
		suelo = piso.primero(&"dungeon_floor")
		if suelo != null and suelo.get("gen") != null:
			break
		await get_tree().physics_frame
	if suelo == null:
		push_error("[sala propia] el piso %d no se ha montado" % numero)
		return false
	# El piso se monta en el mismo fotograma y no llega a colocarlo: se le pone donde lo pondria el. En la arena, delante
	# del porton (dungeon_floor._construir_arena); en un piso, en el centro de su primera sala.
	if jugador.global_position == Vector2.ZERO and not (suelo.gen.salas as Array).is_empty():
		var sala: Rect2i = suelo.gen.salas[0]
		var celda := Vector2i(sala.get_center().x, sala.end.y - 4) if numero == Game.PISO_ARENA else sala.get_center()
		jugador.recolocar(suelo.gen.centro_px(celda))
	print("[sala propia] %s: sala en el puerto %d, piso %d montado, jugador en %s" % [nombre, puerto, numero,
		str(jugador.global_position.round())])
	for i in 10:
		await get_tree().physics_frame
	return true


# Un enemigo en la arena, a 'desde' del jugador ('muneco' como el panel de la arena: modo, hp...).
func poner(ruta: String, desde: Vector2, muneco: Dictionary = {}) -> void:
	poner_en(ruta, jugador.global_position + desde, muneco)


# Lo mismo, en 'pos' del mundo.
func poner_en(ruta: String, pos: Vector2, muneco: Dictionary = {}) -> void:
	var suelo: Node = piso.primero(&"dungeon_floor")
	var data: EnemyData = load(ruta) as EnemyData
	if suelo != null and suelo.has_method("colocar_en_arena") and data != null:
		suelo.colocar_en_arena(data, pos, muneco)


func enemigos() -> Array:
	return piso.nodos(&"enemy")


# Abre la pelea como la abre la sala: un PeleaViva colgado del piso, con el grupo del jugador de mentira, contra
# 'contra' (todos los del piso si va vacio). Va con los PERSONAJES DE VERDAD y no con dobles de sus fichas (lo que hace
# la sala con un humano de verdad, Game.abrir_pelea_de_fichas): asi sus cuerpos son los del jugador de este piso y lo que
# pasa en la pelea les pasa a ellos, como miran las pruebas. Devuelve la pantalla de combate (o null).
func pelear(contra: Array = [], emboscada: bool = false) -> Node:
	var nodos: Array = contra if not contra.is_empty() else enemigos()
	for n in nodos:
		_reservar(n)
	pe = PeleaViva.new()
	pe.name = "Pelea"
	pe.humano = 0
	piso.add_child(pe, true)
	var pjs: Array = [Game.lider()] + Game.companeros()
	var p: Node = Net.peleas._pantalla_combate(pe) if Game._abrir_pelea(nodos, emboscada, pjs, pe) else null
	if p == null or pe.id == 0:
		push_error("[sala propia] no se ha podido abrir la pelea (%d enemigos)" % nodos.size())
		pe.queue_free()
		pe = null
		return null
	# NO va a Net.peleas._peleas: la sala cierra sola la pelea acabada sin humanos delante (_cierre_de), y esta no tiene
	# ninguno; se cerraria antes de verse morir al ultimo. La cierran las pruebas (Continuar), como sin red.
	# EL MAPA PARADO mientras dure, como hace la sala de verdad jugando uno solo (Net._revisar_pausa_solo: peleando, el MAPA
	# quieto). Sin esto el mapa sigue vivo, gasta tiradas del azar y las pruebas dejan de salir siempre igual (26/10:
	# bajos_tactico fallaba 1 de cada 6). Los de la pelea siguen: la pelea los pone en PROCESS_MODE_ALWAYS.
	Net.pausa_solo = Net.PAUSA_SOLO_MAPA
	Net.servidor.pausar(true)
	pe.tree_exiting.connect(func():
		Net.pausa_solo = 0
		if Net.servidor != null:
			Net.servidor.pausar(false))
	# EL SEQUITO QUIETO mientras dure: sin red el arbol entero se pausaba con la pelea; en la sala no, y party_trail solo
	# mira la pelea de la maquina (Game.pelea), no la del piso. Los compañeros volvian andando detras del lider y no se
	# quedaban donde los pone la pelea. (En la sala de verdad el grupo son los avatares de la red, que no tienen sequito.)
	var sequito = jugador.get("_sequito")
	if sequito != null and is_instance_valid(sequito):
		sequito.set_physics_process(false)
		pe.tree_exiting.connect(func():
			if is_instance_valid(sequito):
				sequito.set_physics_process(true))
	for i in 5:
		await get_tree().process_frame
	return p


# Las capas donde buscar la pantalla de combate (las pruebas la buscan entre las CanvasLayer de la raiz): en la sala la
# de la pelea cuelga de su PeleaViva, no de la raiz.
func capas() -> Array:
	return [pe.capa] if pe != null and is_instance_valid(pe) and is_instance_valid(pe.capa) else []


# LA RESERVA, como Net.peleas._reservar_grupo: suyo y CONGELADO (sin esto sigue andando por el mapa en mitad de la pelea,
# y su anillo y su hueco no estan donde miran las pruebas).
func _reservar(n) -> void:
	if is_instance_valid(n) and n.has_meta("net_id"):
		Net.peleas._enem_ocupados[int(n.get_meta("net_id"))] = PEER_PRUEBA
		n._combat_triggered = true
		n.velocity = Vector2.ZERO
		n._cancelar_aviso()


# Un refuerzo que entra en la pelea en marcha, como en la sala (Net.peleas._meter_reservados): reservado y a SU pelea
# (Game.unir_enemigo_al_combate sin pelea es la de la maquina, que en la sala no es ninguna). 'hueco' -1 = el que toque.
func unir(nodo, hueco: int = -1) -> bool:
	_reservar(nodo)
	if Game.unir_enemigo_al_combate(nodo, hueco, pe):
		return true
	# No entra: se le suelta y sigue con lo suyo, como hace la sala (Net.peleas._soltar_reservados).
	if is_instance_valid(nodo) and nodo.has_meta("net_id"):
		Net.peleas._enem_ocupados.erase(int(nodo.get_meta("net_id")))
		if not nodo.esta_muerto() and PeleaViva.de_enemigo(nodo) == null:
			nodo.reanudar_tras_combate(-1.0)
	return false


# ¿Sigue la pelea? (al cerrarse, su PeleaViva se libera: no se le puede preguntar a Game por ella sin mirar esto)
func peleando() -> bool:
	return pe != null and is_instance_valid(pe) and (Game.combate_activo(pe) or Game.hay_pelea_en_pantalla(pe))


# La pelea que abre un enemigo al alcanzarte: EL Y SUS VECINOS, como la sala (Net.peleas._reservar_grupo con nodo.vecinos()).
func pelear_con_vecinos(nodo, emboscada: bool = true) -> Node:
	var grupo: Array = []
	for n in nodo.vecinos():
		if is_instance_valid(n) and not n.esta_muerto():
			grupo.append(n)
	if not grupo.has(nodo):
		grupo.push_front(nodo)
	return await pelear(grupo, emboscada)
