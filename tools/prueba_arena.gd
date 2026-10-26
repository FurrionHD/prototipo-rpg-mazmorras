# PRUEBA (sin ventana): LA ARENA DE PRUEBAS, COMO JUGADOR con su sala (etapa 4, 26/10: el spawner es de la sala y la
# foto de la arena, lo que se devuelve al salir, del jugador).
#   - se entra y se construye como una sala grande con su porton y la puerta de vuelta;
#   - el spawner coloca (con el muñeco puesto EN el enemigo) y limpia;
#   - NADA sale de ella: el plato que te comes, la excelia, el dinero y lo que recojas vuelven a como
#     estaban al entrar, y guardar dentro guarda lo de ANTES y en el pueblo;
#   - al salir por la puerta apareces junto al porton del pueblo.
# Tarda unos segundos. Tope razonable: 60 s.
#   godot --headless --path . res://tools/prueba_arena.tscn -- nube_local
extends Node

var j = null   # el jugador con su sala: tools/prueba_con_jugador.gd

const PLATO := "res://resources/consumables/plato_caldo_puerro.tres"
var _malos: int = 0


func _ok(texto: String, cond: bool) -> void:
	print(("  ok   " if cond else "  MAL  ") + texto)
	if not cond:
		_malos += 1


# Recorre el piso entero y apunta los Control que NO dejan pasar el raton. IGNORE es el unico
# filtro valido para decorado: PASS tambien deja pasar, pero un decorado no tiene por que recibir
# nada, asi que aqui se exige IGNORE y se evita la duda.
func _controles_que_atrapan(n: Node, fuera: Array[String]) -> void:
	if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		fuera.append("%s [%s]" % [n.name, n.get_class()])
	for h in n.get_children():
		_controles_que_atrapan(h, fuera)


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _ready() -> void:
	call_deferred("_empezar")


# La prueba cambia de escena (pueblo -> arena -> pueblo) y ella ES la escena actual: se cuelga de la raiz
# y deja en su sitio una escena vacia, para que el primer cambio no se la lleve por delante.
func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _correr() -> void:
	print("=== LA ARENA DE PRUEBAS ===")
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_arena", 78, 0):
		_ok("arranca la sala y entro al pueblo", false)
		await _fin()
		return
	var plato: ConsumableData = load(PLATO) as ConsumableData
	Game.consumables[plato] = 3
	var lider: PersonajeData = Game.lider()
	var dinero_antes: int = Game.money
	var fuerza_antes: float = float(lider.ability_internal.get("fuerza", 0.0))
	var estados_antes: int = lider.estados.size()
	var bolsa_antes: int = Game.bolsa.total()

	# 1) ENTRAR (lo que hace el porton del pueblo).
	Game.entrar_arena_de_pruebas()
	await j._hasta(func(): return Net._mi_lugar == "piso:%d" % Game.PISO_ARENA 		and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0)
	await _esperar(10)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	_ok("estoy en la arena (arena_activa y piso de juego %d)" % Game.current_floor,
		Game.es_arena() and Game.current_floor == Game.ARENA_PISO_JUEGO)
	_ok("la sala se ha construido: una sola sala de %s" % str(piso.gen.salas[0].size if piso != null else "-"),
		piso != null and piso.gen.salas.size() == 1 and piso.gen.salas[0].size == piso.ARENA_SALA)
	_ok("con su porton dibujado", piso != null and piso.get_node_or_null("Geo/PortonArena") != null)
	_ok("sin zonas que paran enemigos", piso != null and piso._zonas == null)
	_ok("y vacia", get_tree().get_nodes_in_group("enemy").is_empty())
	# NINGUN Control DEL MUNDO PUEDE ATRAPAR EL RATON. El fondo de roca del piso es un ColorRect del
	# tamaño del mapa entero, y un ColorRect NACE en MOUSE_FILTER_STOP: se quedaba todos los clics
	# sobre el suelo antes de que llegaran a nadie. En la mazmorra no se notaba (ahi no se hace clic
	# en el suelo), pero dejaba MUERTO el boton "Colocar" del spawner -- el panel respondia y el clic
	# en el mapa no llegaba nunca a _unhandled_input.
	# Se comprueba la familia entera y no solo ese nodo: cualquier Control nuevo que se cuelgue del
	# piso volveria a taparlo, y el sintoma (un boton que no hace nada, sin un solo error) no se
	# parece en nada a la causa.
	var atrapan: Array[String] = []
	if piso != null:
		_controles_que_atrapan(piso, atrapan)
	_ok("ningun Control del piso se come los clics%s"
		% ("" if atrapan.is_empty() else ": " + ", ".join(atrapan)), atrapan.is_empty())

	# 2) EL SPAWNER: coloca con el muñeco puesto en el enemigo, y limpia.
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(0, 120),
		{"modo": 1, "hp": 777.0})
	await j._hasta(func(): return not get_tree().get_nodes_in_group("enemy").is_empty(), 10.0)
	await _esperar(3)
	var enem: Array = get_tree().get_nodes_in_group("enemy")
	_ok("el spawner pone un enemigo", enem.size() == 1)
	_ok("con el muñeco EN el enemigo (Saco, 777 de vida)", enem.size() == 1
		and int(Game.muneco_de(enem[0]).get("modo", 0)) == 1 and float(Game.muneco_de(enem[0]).get("hp", 0)) == 777.0)
	Net.pisos.pedir_limpiar_arena()
	await j._hasta(func(): return get_tree().get_nodes_in_group("enemy").is_empty(), 10.0)
	_ok("Limpiar la deja vacia", get_tree().get_nodes_in_group("enemy").is_empty())

	# 3) HACER COSAS DENTRO: comer, ganar excelia, dinero y un material.
	_ok("me como un plato", Game.comer_plato(plato, lider))
	lider.ability_internal["fuerza"] = fuerza_antes + 500.0
	Game.money = dinero_antes + 12345
	var mat: MaterialItem = null
	for m in Game.bolsa.montones():
		mat = m
		break
	if mat != null:
		Game.bolsa.anadir(mat, 1)   # UNA mas (mat es un monton de dentro: sin el 1 metia el monton entero)
	_ok("el plato se ha gastado y me ha puesto su estado",
		int(Game.consumables.get(plato, 0)) == 2 and lider.estados.size() > estados_antes)

	# 4) GUARDAR DENTRO guarda lo de ANTES, en el pueblo, y no toca lo de dentro.
	var d: SaveData = Game.exportar_partida()
	_ok("el save es del pueblo (piso %d, en mazmorra=%s)" % [d.current_floor, str(d.en_mazmorra)],
		d.current_floor == 1 and not d.en_mazmorra)
	_ok("con el dinero de antes de entrar (%d)" % d.money, d.money == dinero_antes)
	_ok("y dentro sigo con lo de dentro", Game.money == dinero_antes + 12345 and Game.es_arena())

	# 5) SALIR por la puerta.
	var puerta: Node = null
	for n in get_tree().get_nodes_in_group("salida_pueblo"):
		puerta = n
	_ok("la puerta dice 'Volver al pueblo'", puerta != null and puerta.texto_interaccion() == "Volver al pueblo")
	puerta.interact_with_player()
	await j._hasta(func(): return not Game.es_arena() and get_tree().get_first_node_in_group("dungeon_floor") == null 		and get_tree().get_first_node_in_group("player") != null, 40.0)
	await _esperar(10)
	_ok("fuera de la arena", not Game.es_arena() and not Game.en_foto_de_arena())
	_ok("el plato vuelve a estar en la bolsa (3)", int(Game.consumables.get(plato, 0)) == 3)
	_ok("y su estado se ha ido", lider.estados.size() == estados_antes)
	_ok("la excelia vuelve a la de antes", float(lider.ability_internal.get("fuerza", 0.0)) == fuerza_antes)
	_ok("el dinero tambien", Game.money == dinero_antes)
	_ok("y lo recogido no sale", Game.bolsa.total() == bolsa_antes)
	jug = get_tree().get_first_node_in_group("player") as Node2D
	var junto: bool = jug != null and jug.global_position.distance_to(PuebloPlano.vuelta_de_arena_px()) < 40.0
	_ok("aparezco junto al porton del pueblo", junto)
	_ok("y en el pueblo esta el porton de la arena",
		get_tree().current_scene.find_children("*", "Node2D", true, false).any(
			func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("porton_arena.gd")))

	await _fin()


func _fin() -> void:
	print("RESULTADO: ", "TODO PASA" if _malos == 0 else "FALLAN %d" % _malos)
	await j.cerrar()
	get_tree().quit(1 if _malos > 0 else 0)
