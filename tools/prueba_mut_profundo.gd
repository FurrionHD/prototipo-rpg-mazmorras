# LOS MUTANTES DEL SLIME PROFUNDO (07/10): profundo -> SLIME DE ARRECIFE -> SLIME DE ESCARCHA en la pelea del mapa. El
# arbol y sus sprites, la CONGELACION (la mitad del camino), el basico propio de cada uno (Mojado / Congelacion), la
# ANEMONA URTICANTE, el AURA FRIA, MOJADO SE HIELA y los ataques: Reventon de marea, Chorro a presion, Esquirlas de coral,
# Estallido helado, Aliento gelido y Carambanos (la fila de circulos). Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_profundo.tscn
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


func _ab(nombre: String) -> AbilityData:
	return load("res://resources/abilities/%s.tres" % nombre) as AbilityData


# La ficha con sus estados SEGUROS (aqui se mira que entran, no la suerte).
func _segura(nombre: String) -> AbilityData:
	var ab: AbilityData = _ab(nombre).duplicate(true)
	for a in ab.efectos:
		a.prob = 1.0
	return ab


# Pone a 'c' (de los tuyos) en 'p' (sus pies).
func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position


func _lejos(tm, al: Array, desde: Vector2, menos: Array = []) -> void:
	for i in al.size():
		if not menos.has(al[i]):
			_poner(tm, al[i], desde + Vector2(0, -400 - 40 * i))


func _empuja(tm, c: Combatant) -> bool:
	for tr in tm._tirones:
		if tr.get("c") == c and float(tr.get("px", 0.0)) < 0.0:
			return true
	return false


# (07/10) EL DADO FIJO: ningun estado entra seguro (StatusEffects.PROB_TECHO = 95 %), asi que se fija la semilla
# antes de cada habilidad que se mira: misma tirada en cada pasada, la prueba no depende de la suerte.
func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var ed: EnemyData = load("res://scenes/actors/enemy/slime_profundo.tres")

	print("1) EL ARBOL")
	var c1: Combatant = ed.crear_combatant(0.5, true, false, &"arrecife")
	var c2: Combatant = ed.crear_combatant(0.5, true, false, &"escarcha")
	var c0: Combatant = ed.crear_combatant(0.5, false, false)
	print("    %s / %s" % [c1.nombre, c2.nombre])
	_ver(c1.nombre == "Slime de arrecife" and c2.nombre == "Slime de escarcha", "nombres")
	_ver(c1.habilidades.size() == 4 and c2.habilidades.size() == 3, "4 ataques el arrecife, 3 la escarcha")
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"arrecife" and ed.siguiente_mutacion(true, &"arrecife")["id"] == &"escarcha",
		"del profundo al arrecife y del arrecife a la escarcha")
	_ver(c1.elemento == Elementos.Elemento.AGUA and c0.elemento == Elementos.Elemento.NINGUNO
		and c2.elemento == Elementos.Elemento.NINGUNO, "el arrecife es de AGUA (los otros dos, sin elemento)")
	_ver(is_equal_approx(Elementos.mult_recibido(Elementos.Elemento.RAYO, c1), 1.5), "el arrecife, debil al rayo (x%.2f)"
		% Elementos.mult_recibido(Elementos.Elemento.RAYO, c1))
	_ver(c1.es_inmune(StatusEffects.Id.MOJADO), "y no se le puede mojar")
	_ver(is_equal_approx(c1.fragil_contundente, 0.8) and is_equal_approx(c2.fragil_contundente, 1.0),
		"el arrecife resiste lo contundente un 20 %% (la escarcha no)")
	_ver(is_equal_approx(Elementos.mult_recibido(Elementos.Elemento.FUEGO, c2), 1.5), "la escarcha, debil al fuego (x%.2f)"
		% Elementos.mult_recibido(Elementos.Elemento.FUEGO, c2))
	_ver(c1.on_hit.size() == 1 and int(c1.on_hit[0].estado) == StatusEffects.Id.MOJADO, "el basico del arrecife MOJA")
	_ver(c2.on_hit.size() == 1 and int(c2.on_hit[0].estado) == StatusEffects.Id.CONGELACION, "el de la escarcha CONGELA")
	_ver(c0.on_hit.size() == 1 and int(c0.on_hit[0].estado) == StatusEffects.Id.PEGAJOSO, "(el profundo sigue pegando baba)")
	_ver(c1.al_ser_golpeado.size() == 1 and is_equal_approx(c1.al_ser_golpeado_prob, 0.3), "el arrecife lleva la anemona (30 %%)")
	_ver(c2.al_ser_golpeado.is_empty(), "la escarcha, sin anemona")
	_ver(c2.aura_fria and is_equal_approx(c2.aura_prob, 0.35) and not c1.aura_fria, "la escarcha lleva el aura fria (35 %%)")
	_ver(c2.mojado_se_hiela and not c1.mojado_se_hiela, "y 'mojado se hiela'")

	print("2) LOS SPRITES")
	var sf1: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"arrecife")
	var sf2: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"escarcha")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	_ver(sf1 != null and sf1.has_animation(&"sacudir_0") and sf1.has_animation(&"escupir_3")
		and sf1.has_animation(&"evolucion_0") and sf1.has_animation(&"inflar_2"), "el arrecife con sus anims")
	_ver(sf2 != null and sf2.has_animation(&"soplar_0") and sf2.has_animation(&"carambanos_5")
		and not sf2.has_animation(&"sacudir_0"), "la escarcha con las suyas (y sin sacudir)")
	_ver(sf0 != null and sf0.has_animation(&"comer_0"), "el profundo COME")
	_ver(SpritesEnemigo.parpados_de(ed, 0.5, true, &"arrecife") != null
		and SpritesEnemigo.parpados_de(ed, 0.5, true, &"escarcha") != null
		and SpritesEnemigo.parpados_de(ed, 0.5, false, &"") != null, "los tres parpadean")

	print("3) LA LINEA EN BOLAS (los Carambanos)")
	var fb := CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 140.0, 36.0)
	fb.ancho_fin = CombatFormas.BOLAS
	_ver(fb.en_bolas() and fb.centros_bolas().size() == 4, "4 circulos (%d)" % fb.centros_bolas().size())
	_ver(fb.contiene(Vector2(35, 0)) and fb.contiene(Vector2(140, 10)) and not fb.contiene(Vector2(52, 17)),
		"pega en los circulos, no en el hueco entre dos")
	_ver(not fb.contiene(Vector2(160, 0)) or fb.contiene(Vector2(155, 0)), "el ultimo, en la punta")

	print("4) LA PELEA")
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime_profundo.tres", jug.global_position + Vector2(70, 0), {})
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime_profundo.tres", jug.global_position + Vector2(90, 40), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	nodos[0].mutar(0.0)
	nodos[1].mutar(0.0)
	nodos[1].mutar(0.0)
	await _esperar(5)
	if not Game.start_combat(nodos, false):
		print("FIN: HAY FALLOS (no arranca la pelea)")
		get_tree().quit(1)
		return
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)   # la barra la movemos a mano
	var tm = combat.turno_mapa
	var en = combat.enemigos
	var arr: Combatant = null
	var esc: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"arrecife":
			arr = e
		elif e.mutacion == &"escarcha":
			esc = e
	_ver(arr != null and esc != null, "en la pelea, un arrecife y una escarcha")
	if arr == null or esc == null:
		print("FIN: HAY FALLOS (%d MAL)" % _mal)
		get_tree().quit(1)
		return
	var al: Array = combat._aliados_vivos()
	for a in al:
		(a as Combatant).status_resist = 0.0
		(a as Combatant).current_hp = (a as Combatant).max_hp
	arr.precision = 5.0   # (que no los esquiven: aqui se mira lo que hacen al entrar)
	esc.precision = 5.0
	var pa: Vector2 = tm.pies_de(arr)
	var pe: Vector2 = tm.pies_de(esc)

	print("5) LA CONGELACION")
	var r0: float = tm.radio_de(al[0])
	al[0].apply_status(StatusEffects.Id.CONGELACION)
	var r1: float = tm.radio_de(al[0])
	_ver(r0 > 0.0 and is_equal_approx(r1, r0 * 0.5), "anda la mitad (%.0f -> %.0f)" % [r0, r1])
	_ver(al[0].congelado() and (al[0].puertas() & Combatant.PUERTA_CONGELADO) != 0, "y viaja como puerta del espejo")
	_ver(int(StatusEffects.def(StatusEffects.Id.CONGELACION)["turns"]) == 1, "dura 1 turno")
	al[0].statuses.clear()

	print("6) LA ANEMONA URTICANTE")
	_poner(tm, al[0], pa + Vector2(-30, 0))
	_lejos(tm, al, pa, [al[0]])
	arr.al_ser_golpeado_prob = 1.0
	seed(4242)
	combat._pasiva_al_golpearle(arr, al[0], 1.0)
	_ver(al[0].has_status(StatusEffects.Id.DEBIL), "pegarle de cerca te deja DEBIL")
	arr.al_ser_golpeado_prob = 0.3
	al[0].statuses.clear()

	print("7) MOJADO SE HIELA")
	esc.on_hit = []   # (sin su Congelacion al 25 %: que se vea la que entra por estar mojado)
	al[0].apply_status(StatusEffects.Id.MOJADO)
	seed(4242)
	esc.roll_on_hit(al[0])
	_ver(al[0].has_status(StatusEffects.Id.CONGELACION), "su golpe a uno MOJADO lo congela seguro")
	al[0].statuses.clear()
	seed(4242)
	esc.roll_on_hit(al[0])
	_ver(not al[0].has_status(StatusEffects.Id.CONGELACION), "(seco, no)")
	al[0].statuses.clear()

	print("8) EL AURA FRIA")
	_poner(tm, al[0], pe + Vector2(-28, 0))
	esc.aura_prob = 1.0
	seed(4242)
	combat._aura_fria(al[0])
	_ver(al[0].has_status(StatusEffects.Id.CONGELACION), "acabar pegado a el te congela")
	al[0].statuses.clear()
	_poner(tm, al[0], pe + Vector2(-200, 0))
	seed(4242)
	combat._aura_fria(al[0])
	_ver(not al[0].has_status(StatusEffects.Id.CONGELACION), "(lejos, no)")
	esc.aura_prob = 0.35
	al[0].statuses.clear()

	print("9) REVENTON DE MAREA")
	_poner(tm, al[0], pa + Vector2(-70, 0))
	_lejos(tm, al, pa, [al[0]])
	var rm: AbilityData = _segura("slime_reventon_marea")
	tm.guardar_carga_enemigo(arr, rm, al[0])
	tm._tirones.clear()
	var hp: float = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(arr, rm)
	_ver(al[0].current_hp < hp, "pega (%.1f -> %.1f)" % [hp, al[0].current_hp])
	_ver(al[0].has_status(StatusEffects.Id.MOJADO), "y le moja")
	_ver(_empuja(tm, al[0]), "y le empuja")
	await _esperar(3)
	al[0].statuses.clear()

	print("10) CHORRO A PRESION")
	pa = tm.pies_de(arr)
	_poner(tm, al[0], pa + Vector2(-45, 0))
	_poner(tm, al[1], pa + Vector2(-95, 0))
	_lejos(tm, al, pa, [al[0], al[1]])
	tm._animar(tm.cuerpo_de(arr), Vector2(-1, 0), false)
	tm._tirones.clear()
	var h0: float = al[0].current_hp
	var h1: float = al[1].current_hp
	seed(4242)
	en._enemy_use_ability(arr, _segura("slime_chorro_presion"), al[0])
	_ver(al[0].current_hp < h0 and al[1].current_hp < h1, "barre a los dos de la linea")
	_ver(al[0].has_status(StatusEffects.Id.MOJADO) and al[1].has_status(StatusEffects.Id.MOJADO), "y los moja")
	_ver(_empuja(tm, al[0]) and _empuja(tm, al[1]), "y los empuja")
	await _esperar(3)
	for a in al:
		(a as Combatant).statuses.clear()

	print("11) ESQUIRLAS DE CORAL")
	_poner(tm, al[0], pa + Vector2(-40, 0))
	_lejos(tm, al, pa, [al[0]])
	hp = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(arr, _segura("slime_esquirlas_coral"), al[0])
	_ver(al[0].current_hp < hp, "le alcanzan (%.1f -> %.1f)" % [hp, al[0].current_hp])
	_ver(al[0].has_status(StatusEffects.Id.SANGRADO), "y le abren un corte")
	await _esperar(3)
	al[0].statuses.clear()

	print("12) ESTALLIDO HELADO")
	pe = tm.pies_de(esc)
	_poner(tm, al[0], pe + Vector2(-70, 0))
	_lejos(tm, al, pe, [al[0]])
	var eh: AbilityData = _segura("slime_estallido_helado")
	tm.guardar_carga_enemigo(esc, eh, al[0])
	hp = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(esc, eh)
	print("    hp %.1f -> %.1f, estados %s" % [hp, al[0].current_hp, al[0].statuses.map(func(x): return x.id())])
	_ver(al[0].current_hp < hp and al[0].has_status(StatusEffects.Id.CONGELACION), "pega y congela")
	await _esperar(3)
	al[0].statuses.clear()

	print("13) ALIENTO GELIDO")
	pe = tm.pies_de(esc)
	_poner(tm, al[0], pe + Vector2(-45, 0))
	_lejos(tm, al, pe, [al[0]])
	tm._animar(tm.cuerpo_de(esc), Vector2(-1, 0), false)
	seed(4242)
	en._enemy_use_ability(esc, _segura("slime_aliento_gelido"), al[0])
	_ver(al[0].has_status(StatusEffects.Id.CONGELACION), "el vaho congela al de delante")
	await _esperar(3)
	al[0].statuses.clear()

	print("14) CARAMBANOS")
	pe = tm.pies_de(esc)
	_poner(tm, al[0], pe + Vector2(-80, 0))
	_lejos(tm, al, pe, [al[0]])
	tm._animar(tm.cuerpo_de(esc), Vector2(-1, 0), false)
	hp = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(esc, _segura("slime_carambanos"), al[0])
	var fc = tm.ultima_forma_enemigo
	_ver(fc != null and fc.en_bolas(), "la huella es una fila de circulos")
	_ver(al[0].current_hp < hp and al[0].has_status(StatusEffects.Id.CONGELACION), "le cae uno y le congela")
	await _esperar(3)

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
