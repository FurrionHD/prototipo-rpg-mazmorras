# PRUEBA (sin ventana, en solitario): LA ARENA DE PRUEBAS.
#   - se entra y se construye como una sala grande con su porton y la puerta de vuelta;
#   - el spawner coloca (con el muñeco puesto EN el enemigo) y limpia;
#   - NADA sale de ella: el plato que te comes, la excelia, el dinero y lo que recojas vuelven a como
#     estaban al entrar, y guardar dentro guarda lo de ANTES y en el pueblo;
#   - al salir por la puerta apareces junto al porton del pueblo.
# Tarda unos segundos. Tope razonable: 60 s.
extends Node

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
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _correr() -> void:
	print("=== LA ARENA DE PRUEBAS ===")
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	var plato: ConsumableData = load(PLATO) as ConsumableData
	Game.consumables[plato] = 3
	var lider: PersonajeData = Game.lider()
	var dinero_antes: int = Game.money
	var fuerza_antes: float = float(lider.ability_internal.get("fuerza", 0.0))
	var estados_antes: int = lider.estados.size()
	var bolsa_antes: int = Game.materiales.size()

	# 1) ENTRAR (lo que hace el porton del pueblo).
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
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
	await _esperar(3)
	var enem: Array = get_tree().get_nodes_in_group("enemy")
	_ok("el spawner pone un enemigo", enem.size() == 1)
	_ok("con el muñeco EN el enemigo (Saco, 777 de vida)", enem.size() == 1
		and int(Game.muneco_de(enem[0]).get("modo", 0)) == 1 and float(Game.muneco_de(enem[0]).get("hp", 0)) == 777.0)
	Net.pisos.pedir_limpiar_arena()
	await _esperar(3)
	_ok("Limpiar la deja vacia", get_tree().get_nodes_in_group("enemy").is_empty())

	# 3) HACER COSAS DENTRO: comer, ganar excelia, dinero y un material.
	_ok("me como un plato", Game.comer_plato(plato, lider))
	lider.ability_internal["fuerza"] = fuerza_antes + 500.0
	Game.money = dinero_antes + 12345
	var mat: MaterialItem = null
	for m in Game.materiales:
		mat = m
		break
	if mat != null:
		Game.materiales.append(mat)
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
	await _esperar(10)
	_ok("fuera de la arena", not Game.es_arena() and not Game.en_foto_de_arena())
	_ok("el plato vuelve a estar en la bolsa (3)", int(Game.consumables.get(plato, 0)) == 3)
	_ok("y su estado se ha ido", lider.estados.size() == estados_antes)
	_ok("la excelia vuelve a la de antes", float(lider.ability_internal.get("fuerza", 0.0)) == fuerza_antes)
	_ok("el dinero tambien", Game.money == dinero_antes)
	_ok("y lo recogido no sale", Game.materiales.size() == bolsa_antes)
	jug = get_tree().get_first_node_in_group("player") as Node2D
	var junto: bool = jug != null and jug.global_position.distance_to(PuebloPlano.vuelta_de_arena_px()) < 40.0
	_ok("aparezco junto al porton del pueblo", junto)
	_ok("y en el pueblo esta el porton de la arena",
		get_tree().current_scene.find_children("*", "Node2D", true, false).any(
			func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("porton_arena.gd")))

	print("RESULTADO: ", "TODO PASA" if _malos == 0 else "FALLAN %d" % _malos)
	get_tree().quit()
