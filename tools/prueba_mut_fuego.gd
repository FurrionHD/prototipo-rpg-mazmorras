# LOS MUTANTES DEL SLIME DE FUEGO (06/10): fuego -> CENIZA Y BRASA -> OBSIDIANA en la pelea del mapa. La ceniza suelta
# ceniza (Rescoldo) al pegarle y MOJADA no; Avivar brasas (sus golpes queman) y la Ignicion del de fuego se APAGAN al
# mojarlos; la obsidiana pierde el fuego, resiste rayo y agua, es FRAGIL a contundentes y DEVUELVE cortes. Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_fuego.tscn
extends Node

var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _pelea(mutar_veces: int) -> Array:
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime_fuego.tres", jug.global_position + Vector2(70, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	for _i in mutar_veces:
		nodo.mutar(0.0)
	await _esperar(5)
	if not Game.start_combat([nodo], false):
		return []
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	return [combat, nodo]


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)

	print("1) la CENIZA Y BRASA")
	var r: Array = await _pelea(1)
	var combat: Node = r[0]
	var tm = combat.turno_mapa
	var e: Combatant = combat._enemies[0]
	var al: Combatant = combat._aliados[0]
	print("    %s (grado %d)" % [e.nombre, e.grado_mut])
	_ver(e.nombre == "Slime de ceniza y brasa", "es la ceniza y brasa")
	_ver(tm.cuerpo_de(e).get("_sprite").sprite_frames.has_animation(&"ignicion_0"), "con su sprite (tiene ignicion)")
	var cu_e: Node2D = tm.cuerpo_de(e)
	var cu_a: Node2D = tm.cuerpo_de(al)
	cu_a.global_position = cu_e.global_position + Vector2(-34, 0)
	tm._pos[al] = cu_a.global_position
	al.status_resist = 0.0
	e.al_ser_golpeado_prob = 1.0
	combat._pasiva_al_golpearle(e, al, 10.0)
	_ver(al.has_status(StatusEffects.Id.RESCOLDO), "al pegarle te suelta ceniza (Rescoldo)")
	al.statuses.clear()
	e.apply_status(StatusEffects.Id.MOJADO)
	combat._pasiva_al_golpearle(e, al, 10.0)
	_ver(not al.has_status(StatusEffects.Id.RESCOLDO), "mojada no suelta nada")
	e.statuses.clear()
	e.apply_status(StatusEffects.Id.AVIVADO)
	var nombres: Array = []
	for _i in 30:
		nombres.append_array(e.tirar_refuerzo(al, e.atk()))
	_ver(nombres.has("Quemadura"), "avivada, sus golpes queman")
	e.apply_status(StatusEffects.Id.MOJADO)
	_ver(not e.has_status(StatusEffects.Id.AVIVADO), "mojarla le apaga las brasas avivadas")
	print("2) la OBSIDIANA")
	var ed: EnemyData = load("res://scenes/actors/enemy/slime_fuego.tres")
	var o: Combatant = ed.crear_combatant(0.5, true, false, &"obsidiana")
	combat._enemies.append(o)   # (para que las pasivas la cuenten como enemiga)
	print("    %s (elemento %d, resist %s)" % [o.nombre, o.elemento, o.resist_elemental])
	_ver(o.nombre == "Slime de obsidiana", "es la obsidiana")
	_ver(o.elemento == Elementos.Elemento.NINGUNO and o.elemento_ataque == Elementos.Elemento.NINGUNO, "pierde el fuego")
	_ver(is_equal_approx(float(o.resist_elemental.get(Elementos.Elemento.AGUA, 1.0)), 0.8)
		and is_equal_approx(float(o.resist_elemental.get(Elementos.Elemento.RAYO, 1.0)), 0.8), "resiste agua y rayo un 20 %")
	_ver(o.al_ser_golpeado.is_empty(), "sin pasiva de salpicar")
	var pj: Combatant = al
	pj.dano_tipo = 0
	seed(7)
	var d_corte: float = float(StatsMath.resolve_attack(pj, o, false, -1.0, 0.0, 0.0, false).damage)
	pj.dano_tipo = 1
	seed(7)
	var d_maza: float = float(StatsMath.resolve_attack(pj, o, false, -1.0, 0.0, 0.0, false).damage)
	print("    corte %.2f, contundente %.2f (x%.2f)" % [d_corte, d_maza, d_maza / maxf(d_corte, 0.01)])
	_ver(absf(d_maza / maxf(d_corte, 0.01) - 1.3) < 0.02, "fragil: contundentes le hacen un 30 % mas")
	var cmb: Node = combat
	o.devuelve_corte_prob = 1.0
	pj.dano_tipo = 0
	var hp0: float = pj.current_hp
	cmb._pasiva_al_golpearle(o, pj, 10.0)
	_ver(is_equal_approx(hp0 - pj.current_hp, 5.0), "te devuelve la mitad de un corte (10 -> 5)")
	pj.dano_tipo = 1
	var hp1: float = pj.current_hp
	cmb._pasiva_al_golpearle(o, pj, 10.0)
	_ver(is_equal_approx(hp1, pj.current_hp), "un golpe contundente no lo devuelve")

	print("3) el de fuego normal: la Ignicion se apaga mojandolo")
	var f := Combatant.new("Fuego", 1, Abilities.new(), 100.0, 10.0, 5.0, 5.0)
	f.apply_status(StatusEffects.Id.ENCENDIDO)
	_ver(f.has_status(StatusEffects.Id.ENCENDIDO), "encendido")
	f.apply_status(StatusEffects.Id.MOJADO)
	_ver(not f.has_status(StatusEffects.Id.ENCENDIDO), "mojado, se le apaga")
	var ign: AbilityData = load("res://resources/abilities/slime_ignicion.tres")
	_ver(int(ign.efectos[0].estado) == StatusEffects.Id.ENCENDIDO, "la Ignicion da Encendido")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
