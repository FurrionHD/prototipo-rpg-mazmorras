# LOS MUTANTES DEL REY SLIME (07/10): Rey -> REY TIRANO -> REY DESTRONADO en la pelea del mapa. El arbol y sus sprites
# (el Rey retocado sin ignicion ni encogido), la tabla de jefe de la 2a, y sus mecanicas: ORDEN REAL (un subdito gratis
# cada 2 turnos), ESCUDO DE SUBDITOS, TRIBUTO, DECRETO (el marcado: sus subditos solo a por el y +20 %), el destronado
# SIN SEQUITO, su RABIA POR TRAMOS, las ESQUIRLAS DE LA CORONA (y las que se quedan clavadas) y la ESCISION con sus
# PEDAZOS (se aplastan al pisarlos; los que quedan se le vuelven a juntar). Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_rey.tscn
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


func _segura(nombre: String) -> AbilityData:
	var ab: AbilityData = _ab(nombre).duplicate(true)
	for a in ab.efectos:
		a.prob = 1.0
	return ab


func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position


func _lejos(tm, al: Array, desde: Vector2, menos: Array = []) -> void:
	for i in al.size():
		if not menos.has(al[i]):
			_poner(tm, al[i], desde + Vector2(0, -400 - 40 * i))


func _piezas(tm, e: Combatant, tipo: int) -> Array:
	var out: Array = []
	for k in tm._charcos.keys():
		var ch: Dictionary = tm._charcos[k]
		if ch["dueno"] == e and int(ch.get("pieza", 0)) == tipo:
			out.append(k)
	return out


func _vivos_slimes(combat, menos: Combatant) -> int:
	var n: int = 0
	for e in combat._enemies:
		if e != menos and e.is_alive() and e.es_slime:
			n += 1
	return n


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var ed: EnemyData = load("res://scenes/actors/enemy/rey_slime.tres")

	print("1) EL ARBOL")
	var c0: Combatant = ed.crear_combatant(0.5, false, true)
	var c1: Combatant = ed.crear_combatant(0.5, true, true, &"tirano")
	var c2: Combatant = ed.crear_combatant(0.5, true, true, &"destronado")
	print("    %s / %s" % [c1.nombre, c2.nombre])
	_ver(c1.nombre == "Rey tirano" and c2.nombre == "Rey destronado", "nombres")
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"tirano" and ed.siguiente_mutacion(true, &"tirano")["id"] == &"destronado",
		"del Rey al tirano y del tirano al destronado")
	var noms1: Array = c1.habilidades.map(func(a): return a.nombre)
	var noms2: Array = c2.habilidades.map(func(a): return a.nombre)
	print("    tirano %s / destronado %s" % [noms1, noms2])
	_ver(noms1.has("Decreto") and not noms1.has("Brote") and noms1.size() == 4, "el tirano: Decreto y sin Brote")
	_ver(noms2.has("Esquirlas de la corona") and noms2.has("Escisión") and not noms2.has("Decreto") and noms2.size() == 4,
		"el destronado: Esquirlas y su Escision")
	_ver(c1.orden_real and is_equal_approx(c1.escudo_subditos_prob, 0.35) and is_equal_approx(c1.tributo_cura, 0.05),
		"el tirano: Orden real, escudo de subditos 35 %, tributo 5 %")
	_ver(is_equal_approx(c1.sequito_reduccion_por_slime, 0.1) and is_equal_approx(c2.sequito_reduccion_por_slime, 0.0),
		"el tirano conserva el sequito; el destronado no")
	# (la vida se redondea: margen de un 1 %)
	_ver(absf(c1.max_hp / c0.max_hp - 1.65) < 0.02, "vida del tirano x%.2f (tabla de jefe)" % (c1.max_hp / c0.max_hp))
	_ver(absf(c2.max_hp / c0.max_hp - 2.3) < 0.02, "vida del destronado x%.2f (jefe 2a)" % (c2.max_hp / c0.max_hp))
	_ver(absf(c2.base_attack / c0.base_attack - 1.35) < 0.02, "ataque del destronado x%.2f" % (c2.base_attack / c0.base_attack))

	print("2) LA RABIA POR TRAMOS")
	c2.current_hp = c2.max_hp
	_ver(c2.rabia_tramos() == 0 and is_equal_approx(c2.mult_rabia_tramos(), 1.0), "entero, nada")
	c2.current_hp = c2.max_hp * 0.70
	_ver(c2.rabia_tramos() == 1 and is_equal_approx(c2.mult_rabia_tramos(), 1.1), "a 70 %%: un tramo (+10 %%)")
	c2.current_hp = c2.max_hp * 0.10
	_ver(c2.rabia_tramos() == 3 and is_equal_approx(c2.mult_rabia_tramos(), 1.3), "a 10 %%: tope de tres (+30 %%)")
	_ver(c1.rabia_tramos() == 0, "(el tirano no tiene rabia)")

	print("3) LOS SPRITES")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	var sf1: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"tirano")
	var sf2: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"destronado")
	_ver(sf0 != null and sf0.has_animation(&"comer_0") and sf0.has_animation(&"brote_0")
		and not sf0.has_animation(&"ignicion_0"), "el Rey: come, brota y ya no lleva ignicion")
	_ver(sf1 != null and sf1.has_animation(&"decreto_0") and sf1.has_animation(&"brote_3") and sf1.has_animation(&"evolucion_0"),
		"el tirano con sus anims (decreto, brote, evolucion)")
	_ver(sf2 != null and sf2.has_animation(&"esquirlas_0") and sf2.has_animation(&"evolucion_0")
		and not sf2.has_animation(&"brote_0"), "el destronado con las suyas (esquirlas; sin brote)")
	_ver(SpritesEnemigo.parpados_de(ed, 0.5, false, &"") != null and SpritesEnemigo.parpados_de(ed, 0.5, true, &"tirano") != null
		and SpritesEnemigo.parpados_de(ed, 0.5, true, &"destronado") != null, "los tres parpadean")

	print("4) LA PELEA")
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/rey_slime.tres", jug.global_position + Vector2(110, 0), {})
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/rey_slime.tres", jug.global_position + Vector2(130, 120), {})
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(160, -60), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	var reyes: Array = nodos.filter(func(n): return n.data != null and n.data.corona_slime)
	reyes[0].mutar(0.0)
	reyes[1].mutar(0.0)
	reyes[1].mutar(0.0)
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
	combat.set_process(false)
	var tm = combat.turno_mapa
	var en = combat.enemigos
	var tir: Combatant = null
	var des: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"tirano":
			tir = e
		elif e.mutacion == &"destronado":
			des = e
	_ver(tir != null and des != null, "en la pelea, un tirano y un destronado")
	if tir == null or des == null:
		print("FIN: HAY FALLOS (%d MAL)" % _mal)
		get_tree().quit(1)
		return
	var al: Array = combat._aliados_vivos()
	for a in al:
		(a as Combatant).status_resist = 0.0
		(a as Combatant).current_hp = (a as Combatant).max_hp
		(a as Combatant).invulnerable = false
	tir.precision = 5.0
	des.precision = 5.0

	print("5) SIN SEQUITO")
	_ver(tir._reduccion_sequito() > 0.0, "el tirano se tapa con los slimes (%.0f %%)" % (tir._reduccion_sequito() * 100.0))
	_ver(is_equal_approx(des._reduccion_sequito(), 0.0), "el destronado no (nadie le sigue)")

	print("6) ORDEN REAL")
	var n0: int = _vivos_slimes(combat, tir)
	tir.orden_espera = 0
	en._orden_real(tir)
	var n1: int = _vivos_slimes(combat, tir)
	_ver(n1 == n0 + 1, "saca un subdito gratis (%d -> %d)" % [n0, n1])
	en._orden_real(tir)
	_ver(_vivos_slimes(combat, tir) == n1, "el turno siguiente, no (cada 2)")
	en._orden_real(tir)
	_ver(_vivos_slimes(combat, tir) == n1 + 1 or _vivos_slimes(combat, tir) == n1 and not en._hay_sitio_para_invocar(tir),
		"y al otro, otra vez (o ya no cabe)")
	await _esperar(3)

	print("7) ESCUDO DE SUBDITOS")
	var sub: Combatant = null
	for e in combat._enemies:
		if e != tir and e != des and e.is_alive() and e.es_slime:
			sub = e
			break
	_poner(tm, sub, tm.pies_de(tir) + Vector2(0, tm.radio_pisa(tir) * 0.5 + tm.radio_pisa(sub) * 0.5 + 6.0))
	print("    hueco subdito-rey %.1f" % tm.hueco_entre(sub, tir))
	tir.escudo_subditos_prob = 1.0
	var quien: Combatant = combat.escudo_subdito(tir, al[0])
	_ver(quien != tir and quien.es_slime, "un subdito pegado se come el golpe (%s)" % quien.nombre)
	tir.escudo_subditos_prob = 0.0
	_ver(combat.escudo_subdito(tir, al[0]) == tir, "(sin la tirada, le llega a el)")
	tir.escudo_subditos_prob = 0.35
	_ver(combat.escudo_subdito(des, al[0]) == des, "(el destronado no tiene escudo)")

	print("8) TRIBUTO")
	tir.current_hp = tir.max_hp * 0.5
	var hp_t: float = tir.current_hp
	sub.current_hp = 0.0
	combat._morir_enemigo(sub)
	_ver(is_equal_approx(tir.current_hp - hp_t, tir.max_hp * 0.05), "al caer un subdito se cura un 5 %% (+%.1f)"
		% (tir.current_hp - hp_t))
	await _esperar(3)

	print("9) DECRETO")
	for a in al:
		(a as Combatant).statuses.clear()
	en._enemy_use_ability(tir, _ab("rey_slime_decreto"))
	var marcado: Combatant = null
	for a in al:
		if (a as Combatant).has_status(StatusEffects.Id.DECRETO):
			marcado = a
	_ver(marcado != null, "señala a uno de los tuyos (%s)" % (marcado.nombre if marcado != null else "nadie"))
	var otro_sub: Combatant = null
	for e in combat._enemies:
		if e != tir and e != des and e.is_alive() and e.es_slime:
			otro_sub = e
	if marcado != null and otro_sub != null:
		_ver(combat.objetivos.presa_por_decreto(otro_sub) == marcado, "sus subditos van a por el")
		_ver(is_equal_approx(combat._mult_pasivas(otro_sub, marcado), 1.2), "y le pegan un 20 %% mas (x%.2f)"
			% combat._mult_pasivas(otro_sub, marcado))
		_ver(combat.objetivos.presa_por_decreto(tir) == null and combat.objetivos.presa_por_decreto(des) == null,
			"(los reyes no son subditos)")
	await _esperar(3)
	for a in al:
		(a as Combatant).statuses.clear()

	print("10) LA RABIA EN LA PELEA")
	des.current_hp = des.max_hp * 0.45
	_ver(is_equal_approx(combat._mult_pasivas(des, al[0]), 1.2), "a 45 %% de vida pega un 20 %% mas (x%.2f)"
		% combat._mult_pasivas(des, al[0]))
	des.current_hp = des.max_hp

	print("11) ESQUIRLAS DE LA CORONA")
	var pd: Vector2 = tm.pies_de(des)
	_poner(tm, al[0], pd + Vector2(-60, 0))
	_lejos(tm, al, pd, [al[0]])
	tm._animar(tm.cuerpo_de(des), Vector2(-1, 0), false)
	var hp: float = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(des, _segura("rey_slime_esquirlas_corona"), al[0])
	_ver(al[0].current_hp < hp, "le alcanzan (%.1f -> %.1f)" % [hp, al[0].current_hp])
	_ver(al[0].has_status(StatusEffects.Id.SANGRADO), "y le abren un corte")
	var clavadas: Array = _piezas(tm, des, AbilityData.Pieza.ESQUIRLA)
	_ver(clavadas.size() >= 3, "se quedan clavadas en el suelo (%d)" % clavadas.size())
	await _esperar(3)
	if not clavadas.is_empty():
		al[1].statuses.clear()
		var ch: Dictionary = tm._charcos[clavadas[0]]
		_poner(tm, al[1], ch["f"].centro)
		tm._pisado.erase(al[1])
		var h1: float = al[1].current_hp
		seed(4242)
		tm._pisar_si(al[1], ch["f"].centro, ch["f"].centro)
		_ver(al[1].current_hp < h1 and al[1].has_status(StatusEffects.Id.SANGRADO), "pisar una corta y abre Sangrado")
		_ver(not tm._charcos.has(clavadas[0]), "y esa ya no esta")
		_lejos(tm, al, pd, [al[0]])
	for a in al:
		(a as Combatant).statuses.clear()

	print("12) ESCISION Y SUS PEDAZOS")
	pd = tm.pies_de(des)
	_poner(tm, al[0], pd + Vector2(-50, 0))
	_lejos(tm, al, pd, [al[0]])
	hp = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(des, _segura("rey_slime_escision_destronado"), al[0])
	_ver(al[0].current_hp < hp, "pega (%.1f -> %.1f)" % [hp, al[0].current_hp])
	var pedazos: Array = _piezas(tm, des, AbilityData.Pieza.PEDAZO)
	_ver(pedazos.size() == 3, "deja tres pedazos (%d)" % pedazos.size())
	await _esperar(3)
	des.current_hp = des.max_hp * 0.5
	var hp_d: float = des.current_hp
	tm.charcos_turno_enemigo(des)
	_ver(_piezas(tm, des, AbilityData.Pieza.PEDAZO).size() == pedazos.size(), "un turno suyo: siguen ahi")
	tm.charcos_turno_enemigo(des)
	_ver(_piezas(tm, des, AbilityData.Pieza.PEDAZO).is_empty(), "al segundo se le vuelven a juntar")
	_ver(is_equal_approx(des.current_hp - hp_d, des.max_hp * 0.03 * pedazos.size()),
		"y le curan un 3 %% cada uno (+%.1f)" % (des.current_hp - hp_d))

	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "HAY FALLOS (%d MAL)" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
