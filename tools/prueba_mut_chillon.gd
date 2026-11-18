# PRUEBA (sin ventana): LOS MUTANTES DEL CHILLON (18/11, memoria chillon-mutante).
#
#   1. La ficha: la base con su Voluntad, el Apagaluces (1a) y la Piña negra (2a, desde el Apagaluces), sus stats y kits.
#   2. El Chillido de oscuridad: magico de Oscuridad, en circulo de 70 alrededor suyo, 0,36.
#   3. Los sprites: cada mutante el suyo (con sus animaciones), y la cria con el suyo.
#   4. A OSCURAS: el estado y su texto; el farolillo al minimo; fuera de la pelea, el reloj del GRUPO (30 s por turno, el
#      que mas le quedaba) y de vuelta a la pelea, el estado en los tuyos.
#   5. LAS PASIVAS: Bebe la luz (+10 % velocidad y +5 % daño por cada uno de los tuyos A oscuras) en el Apagaluces y la Piña,
#      y el Racimo de la Piña (-40 % de todo el daño, -10 % por cria muerta; tope de 2 crias), a la vista y con su texto.
#   6. LAS CRIAS: su ficha (un apagaluces en pequeño; solo su chillido, de 45, apaga) y, EN UNA PELEA DE VERDAD, la Piña
#      suelta una por turno sin pasar de 2, con el 35 % de la vida de un Apagaluces y Bebe la luz; al caer una, su Racimo
#      baja un 10 %; Bebe la luz cuenta a los tuyos A oscuras.
extends Node

const CombatEnemigos = preload("res://scripts/ui/combat_enemigos.gd")
const CHILLON := "res://scenes/actors/enemy/chillon.tres"
var _mal := 0
var sala = null


func _ok(cond: bool, que: String) -> void:
	print(("  ok   " if cond else "  MAL: ") + que)
	if not cond:
		_mal += 1


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	var ed: EnemyData = load(CHILLON)
	_ficha(ed)
	_chillido()
	_sprites(ed)
	_a_oscuras()
	_pasivas(ed)
	_ficha_cria()
	await _pelea()
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _suma(m: Dictionary) -> int:
	var s := 0
	for k in m:
		s += int(m[k])
	return s


func _ficha(ed: EnemyData) -> void:
	print("=== LA FICHA ===")
	_ok([ed.resistencia, ed.fuerza, ed.destreza, ed.agilidad, ed.magia, ed.voluntad] == [20, 30, 38, 58, 14, 20],
		"la base: R20 F30 D38 A58 M14 V20 (suma 180)")
	var ap: MutacionData = ed.mutacion_de(&"apagaluces")
	var pi: MutacionData = ed.mutacion_de(&"pina")
	_ok(ap != null and pi != null, "el Apagaluces y la Piña negra")
	if ap == null or pi == null:
		return
	_ok(ap.grado == 1 and ap.nombre == "Apagaluces", "el Apagaluces, de 1a")
	_ok(pi.grado == 2 and pi.desde == [&"apagaluces"] and pi.nombre == "Piña negra", "la Piña negra, de 2a desde el Apagaluces")
	_ok(_suma(ap.pesos) == 180 and _suma(pi.pesos) == 180, "los dos suman 180 (%d, %d)" % [_suma(ap.pesos), _suma(pi.pesos)])
	_ok(int(ap.pesos["magia"]) == 32 and int(pi.pesos["resistencia"]) == 38 and int(pi.pesos["voluntad"]) == 32,
		"sus stats (Apagaluces M32, Piña R38 V32)")
	_ok(ed.siguiente_mutacion(false, &"")["id"] == &"apagaluces" and ed.siguiente_mutacion(true, &"apagaluces")["id"] == &"pina",
		"del normal al Apagaluces y del Apagaluces a la Piña")
	var noms_a: Array = ap.habilidades.map(func(a): return a.nombre)
	var noms_p: Array = pi.habilidades.map(func(a): return a.nombre)
	_ok(noms_a.has("Chillido de oscuridad") and noms_a.has("Picado"), "el Apagaluces: Chillido de oscuridad y Picado")
	_ok(noms_p == ["Chillido de oscuridad"], "la Piña: Chillido de oscuridad, sin Picado")
	var c: Combatant = ed.crear_combatant(0.5, true, false, &"apagaluces")
	_ok(c.nombre.contains("Apagaluces"), "en la pelea se llama Apagaluces (%s)" % c.nombre)


func _chillido() -> void:
	print("=== EL CHILLIDO DE OSCURIDAD ===")
	var ab: AbilityData = load("res://resources/abilities/chillon_chillido_oscuro.tres")
	_ok(ab.es_magico and ab.elemento_golpe == Elementos.Elemento.OSCURIDAD, "magico de Oscuridad")
	_ok(ab.forma == CombatFormas.Tipo.CIRCULO and ab.forma_apunte == CombatFormas.Apunte.ALREDEDOR
		and is_equal_approx(ab.forma_radio, 70.0), "en circulo de 70 alrededor suyo")
	_ok(is_equal_approx(ab.dano_mult, 0.36) and ab.fx_anim == &"chillido_oscuro", "0,36 y con su gesto")


func _sprites(ed: EnemyData) -> void:
	print("=== LOS SPRITES ===")
	for par in [[&"apagaluces", ["idle_0", "chillido_oscuro_0", "embestida_0", "comer_0", "evolucion_0"]],
			[&"pina", ["idle_0", "chillido_oscuro_0", "soltar_0", "evolucion_0", "muerte_0"]]]:
		_ok(Chillon3DSprites.tiene_mutante(ed, par[0]), "%s tiene su sprite" % par[0])
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, par[0])
		var faltan: Array = (par[1] as Array).filter(func(a): return sf == null or not sf.has_animation(StringName(a)))
		_ok(faltan.is_empty(), "%s: con sus animaciones (faltan %s)" % [par[0], str(faltan)])
	var sp: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"pina")
	_ok(sp != null and not sp.has_animation(&"embestida_0"), "la Piña no pica")


func _a_oscuras() -> void:
	print("=== A OSCURAS ===")
	var A := StatusEffects.Id.A_OSCURAS
	var ab: AbilityData = load("res://resources/abilities/chillon_chillido_oscuro.tres")
	_ok(ab.efectos.size() == 1 and ab.efectos[0].estado == A and is_equal_approx(ab.efectos[0].prob, 0.95)
		and ab.efectos[0].turns == 2, "el Chillido deja A oscuras: 95 %, 2 turnos")
	var c := Combatant.new("Yo", 1, Abilities.new(), 100.0, 5.0, 5.0, 5.0)
	c.apply_status(A, 2)
	var txt: String = String(StatusEffects.chip_de_grupo(c.statuses.filter(func(e): return e.id() == A), c)[1])
	print("     ficha: %s" % txt.replace("\n", " | "))
	_ok(txt.contains("Su farolillo alumbra lo mínimo") and txt.contains("30 s por cada turno"), "su texto")
	_ok(StatusEffects.def(A).get("debuff", false) and not StatusEffects.estados_que_salen(c.statuses).is_empty(),
		"es un estorbo y sale de la pelea")
	# FUERA: el reloj del grupo
	Game.a_oscuras_seg = 0.0
	var pj1: PersonajeData = Game.party[0] if Game.party.size() > 0 else PersonajeData.new()
	var pj2: PersonajeData = Game.party[1] if Game.party.size() > 1 else PersonajeData.new()
	var est1: Array = pj1.estados.duplicate()
	var est2: Array = pj2.estados.duplicate()
	pj1.estados = [{"id": A, "turns": 1, "stacks": 1}]
	Game.refrescar_cache_estados(pj1)
	pj2.estados = [{"id": A, "turns": 2, "stacks": 1}]
	Game.refrescar_cache_estados(pj2)
	_ok(is_equal_approx(Game.a_oscuras_seg, 60.0), "al salir, el grupo: 30 s por turno del que mas le quedaba (%.0f s)" % Game.a_oscuras_seg)
	_ok(pj1.estados.is_empty() and pj2.estados.is_empty(), "y no se queda en la ficha de cada uno")
	_ok(Game.a_oscuras(), "a oscuras por el mapa")
	var luz_lejos: float = Game.radio_lampara(9)
	_ok(is_equal_approx(Game.radio_lampara(), Vision.RADIO_MINIMO), "el farolillo, al minimo (%.1f)" % Game.radio_lampara())
	_ok(Game.radio_lampara(9) == luz_lejos and luz_lejos >= Vision.RADIO_MINIMO, "(la ficha de 'en el piso X' no cambia)")
	Game.tick_estados(25.0)
	_ok(is_equal_approx(Game.a_oscuras_seg, 35.0), "el reloj corre por el mapa (%.0f s)" % Game.a_oscuras_seg)
	# DE VUELTA A UNA PELEA: el estado en los tuyos, con los turnos que le queden (35 s = 2 turnos)
	var c1 := Combatant.new("Uno", 1, Abilities.new(), 100.0, 5.0, 5.0, 5.0)
	var c2 := Combatant.new("Dos", 1, Abilities.new(), 100.0, 5.0, 5.0, 5.0)
	Game.restaurar_estados_de_ficha(c1, pj1)
	Game.restaurar_estados_de_ficha(c2, pj2)
	var t1: int = -1
	var t2: int = -1
	for e in c1.statuses:
		if e.id() == A:
			t1 = e.turns
	for e in c2.statuses:
		if e.id() == A:
			t2 = e.turns
	_ok(t1 == 2 and t2 == 2, "en la siguiente pelea, A oscuras en los dos (%d y %d turnos)" % [t1, t2])
	_ok(is_zero_approx(Game.a_oscuras_seg), "y el reloj del mapa se para (lo lleva la pelea)")
	Game.tick_estados(0.1)
	Game.a_oscuras_seg = 0.0
	pj1.estados = est1
	pj2.estados = est2
	_ok(not Game.a_oscuras(), "sin nada, con luz")


func _pasivas(ed: EnemyData) -> void:
	print("=== LAS PASIVAS ===")
	var B := StatusEffects.Id.BEBE_LUZ
	var R := StatusEffects.Id.RACIMO
	var ap: Combatant = ed.crear_combatant(0.5, true, false, &"apagaluces")
	var pi: Combatant = ed.crear_combatant(0.5, true, false, &"pina")
	var no: Combatant = ed.crear_combatant(0.5, false, false)
	_ok(ap.has_status(B) and not ap.has_status(R), "el Apagaluces nace con Bebe la luz a la vista")
	_ok(pi.has_status(B) and pi.has_status(R), "la Piña, con Bebe la luz y el Racimo")
	_ok(not no.has_status(B) and is_equal_approx(no.mult_bebe_luz_vel(), 1.0) and is_equal_approx(no.mult_pasiva_recibido(), 1.0),
		"el chillon normal, sin nada")
	# BEBE LA LUZ: 2 de los tuyos a oscuras -> x1,2 velocidad y x1,1 daño (fisico y magico)
	var v0: float = ap.spd()
	var a0: float = ap.atk()
	var m0: float = ap.atk_magico()
	ap.bebe_luz_n = 2
	_ok(is_equal_approx(ap.spd(), v0 * 1.2), "Bebe la luz: 2 a oscuras = +20 %% de velocidad (%.2f -> %.2f)" % [v0, ap.spd()])
	_ok(is_equal_approx(ap.atk(), a0 * 1.1) and is_equal_approx(ap.atk_magico(), m0 * 1.1),
		"y +10 %% de daño, fisico y magico (%.2f -> %.2f)" % [a0, ap.atk()])
	ap.bebe_luz_n = 4
	_ok(is_equal_approx(ap.mult_bebe_luz_vel(), 1.4) and is_equal_approx(ap.mult_bebe_luz_dano(), 1.2), "4 a oscuras: +40 % y +20 %")
	# EL RACIMO: -40 % de todo; -10 % por cria muerta; con 4, nada
	_ok(is_equal_approx(pi.mult_pasiva_recibido(), 0.6), "el Racimo: recibe un 40 %% menos (x%.2f)" % pi.mult_pasiva_recibido())
	pi.crias_muertas = 2
	_ok(is_equal_approx(pi.mult_pasiva_recibido(), 0.8), "con 2 crias muertas, un 20 %% menos (x%.2f)" % pi.mult_pasiva_recibido())
	pi.crias_muertas = 5
	_ok(is_equal_approx(pi.mult_pasiva_recibido(), 1.0), "con 4 o mas, nada (x%.2f)" % pi.mult_pasiva_recibido())
	pi.crias_muertas = 0
	_ok(pi.crias_tope == 2, "tope de 2 crias")
	# LOS TEXTOS (con los numeros de quien la tiene)
	var tb: String = "
".join(StatusEffects.texto_pasiva_portador(B, ap))
	var tr: String = "
".join(StatusEffects.texto_pasiva_portador(R, pi))
	print("     Bebe la luz: %s" % tb.replace("
", " | "))
	print("     Racimo: %s" % tr.replace("
", " | "))
	_ok(tb.contains("aumenta en un 10 %") and tb.contains("aumenta en un 5 %"), "el texto de Bebe la luz con sus numeros")
	_ok(tr.contains("un 40 % menos") and tr.contains("en un 10 %") and tr.contains("con 4 derrotadas") and tr.contains("2 crías"),
		"el texto del Racimo con sus numeros")


func _ficha_cria() -> void:
	print("=== LA CRIA ===")
	var cr: EnemyData = load("res://resources/enemigos_invocados/chillon_cria.tres")
	_ok(cr != null and cr.sprite_variante == &"cria" and cr.mutaciones.is_empty(), "su ficha: la variante 'cria', sin mutaciones")
	if cr == null:
		return
	_ok([cr.resistencia, cr.fuerza, cr.destreza, cr.agilidad, cr.magia, cr.voluntad] == [22, 26, 30, 50, 32, 20],
		"con las stats del Apagaluces")
	var sf: SpriteFrames = SpritesEnemigo.frames_de(cr, 0.5, false, &"")
	_ok(sf != null and sf.has_animation(&"idle_0") and sf.has_animation(&"chillido_oscuro_0"), "con su sprite (el apagaluces en pequeño)")
	var chi: AbilityData = null
	for a in cr.habilidades:
		if a.nombre == "Chillido de oscuridad":
			chi = a
	_ok(chi != null and is_equal_approx(chi.forma_radio, 45.0) and chi.efectos.size() == 1
		and chi.efectos[0].estado == StatusEffects.Id.A_OSCURAS, "su Chillido de oscuridad, de 45, deja A oscuras")
	var apagan_otros: bool = cr.al_golpear.any(func(s): return s.estado == StatusEffects.Id.A_OSCURAS)
	for a in cr.habilidades:
		if a != chi and a.efectos.any(func(s): return s.estado == StatusEffects.Id.A_OSCURAS):
			apagan_otros = true
	_ok(not apagan_otros and cr.habilidades.size() == 2, "su basico y su Picado no apagan")
	var pi: Combatant = (load(CHILLON) as EnemyData).crear_combatant(0.5, true, false, &"pina", 10)
	var ap: Combatant = (load(CHILLON) as EnemyData).crear_combatant(0.5, true, false, &"apagaluces", 10)
	var v: float = CombatEnemigos.vida_de_cria(pi, 10)
	_ok(is_equal_approx(v, ap.max_hp * 0.35), "su vida: el 35 %% de la de un Apagaluces (%.1f de %.1f, piso 10)" % [v, ap.max_hp])


func _pelea() -> void:
	print("=== EN UNA PELEA ===")
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_chillon", Game.PISO_ARENA):
		_ok(false, "arranca la sala")
		return
	sala.poner(CHILLON, Vector2(150, 0), {"mutacion": "pina"})
	await _esperar(20)
	if (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)) == null:
		_ok(false, "se abre la pelea")
		return
	await _esperar(5)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null:
		_ok(false, "encuentro la pantalla de combate")
		return
	var pi: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"pina":
			pi = e
	_ok(pi != null, "la Piña negra en la pelea")
	if pi == null:
		return
	for a in combat._aliados:
		a.max_hp = 100000.0
		a.current_hp = 100000.0
	var crias := func() -> Array:
		return combat._enemies.filter(func(c): return c.is_alive() and c.madre_cria == pi)
	for _k in 3:
		combat.enemigos._soltar_cria(pi)
	var cs: Array = crias.call()
	_ok(cs.size() == 2, "suelta una por llamada, sin pasar de 2 vivas (%d)" % cs.size())
	if cs.is_empty():
		return
	var c0: Combatant = cs[0]
	var vida: float = CombatEnemigos.vida_de_cria(pi, combat.altas._piso())
	_ok(is_equal_approx(c0.max_hp, vida) and is_equal_approx(c0.current_hp, vida), "con el 35 %% de la vida de un Apagaluces (%.1f)" % c0.max_hp)
	_ok(c0.has_status(StatusEffects.Id.BEBE_LUZ) and is_equal_approx(c0.bebe_luz_vel, 0.1), "y con Bebe la luz")
	_ok(c0.nombre.contains("Cría"), "se llama Cría de apagaluces (%s)" % c0.nombre)
	# BEBE LA LUZ en la pelea: uno de los tuyos A oscuras
	var yo: Combatant = combat._aliados[0]
	yo.apply_status(StatusEffects.Id.A_OSCURAS, 2)
	combat._contar_a_oscuras()
	_ok(pi.bebe_luz_n == 1 and c0.bebe_luz_n == 1, "Bebe la luz cuenta a los tuyos A oscuras (Piña %d, cria %d)" % [pi.bebe_luz_n, c0.bebe_luz_n])
	# CAE UNA: el Racimo baja
	_ok(is_equal_approx(pi.racimo_ahora(), 0.4), "el Racimo entero mientras viven (40 %)")
	c0.current_hp = 0.0
	combat._morir_enemigo(c0)
	_ok(pi.crias_muertas == 1 and is_equal_approx(pi.racimo_ahora(), 0.3), "cae una cria: el Racimo baja al 30 %% (%.2f)" % pi.racimo_ahora())
	combat._morir_enemigo(c0)
	_ok(pi.crias_muertas == 1, "la misma cria no cuenta dos veces")
	combat.enemigos._soltar_cria(pi)
	_ok(crias.call().size() == 2, "con una muerta, vuelve a soltar hasta 2")
	await _efectos(combat, pi, yo)


# LOS EFECTOS EN PIXEL (18/11, chillon_efectos_horno): las hojas horneadas, los suelos (la sombra de 70 y la de 45, el cono)
# y lo que sale sobre cada uno en una pelea de verdad.
func _hojas_de(arena: Node) -> Array:
	var out: Array = []
	for n in arena.get_children():
		if n is EfectoPixel and n.has_meta("hoja"):
			out.append(String(n.get_meta("hoja")))
	return out


func _efectos(combat: Node, pi: Combatant, yo: Combatant) -> void:
	print("=== LOS EFECTOS EN PIXEL ===")
	var hojas: Dictionary = (load("res://scripts/fx/efectos_pixel_datos.gd").HOJAS as Dictionary).get("chillon", {})
	var faltan: Array = ["sombra70", "sombra45", "cono", "paletos", "oidos", "farol", "mota", "mota_entra"].filter(
		func(h): return not hojas.has(h))
	_ok(faltan.is_empty(), "las hojas horneadas (faltan %s)" % str(faltan))
	_ok(int((hojas.get("cono", {}) as Dictionary).get("filas", 0)) == 5 and int((hojas.get("paletos", {}) as Dictionary).get("filas", 0)) == 5,
		"el cono y los paletos, con 5 direcciones")
	var T := SueloRoto.Tipo
	_ok((load("res://resources/abilities/chillon_chillido_oscuro.tres") as AbilityData).suelo_roto == T.CHILLON_SOMBRA
		and (load("res://resources/abilities/chillon_chillido_cria.tres") as AbilityData).suelo_roto == T.CHILLON_SOMBRA
		and (load("res://resources/abilities/chillon_chillido.tres") as AbilityData).suelo_roto == T.CHILLON_CONO,
		"los chillidos con su suelo (la sombra los de oscuridad, el cono el normal)")
	var arena: Node = combat.turno_mapa._arena()
	var s70 = SueloRoto.lanzar(arena, CombatFormas.circulo(Vector2(0, 0), 70.0), T.CHILLON_SOMBRA, 1)
	var s45 = SueloRoto.lanzar(arena, CombatFormas.circulo(Vector2(0, 0), 45.0), T.CHILLON_SOMBRA, 1)
	var co = SueloRoto.lanzar(arena, CombatFormas.cono(Vector2(0, 0), Vector2.RIGHT, 60.0, 100.0), T.CHILLON_CONO, 1)
	_ok(s70 != null and s70.get_meta("hoja") == "sombra70" and s45 != null and s45.get_meta("hoja") == "sombra45",
		"la sombra: la de 70 y la de 45 segun el radio")
	_ok(co != null and co.get_meta("hoja") == "cono", "las ondas del Chillido normal")
	var f70 := CombatFormas.circulo(Vector2(0, 0), 70.0)
	_ok(is_equal_approx(SueloRoto.retraso(f70, Vector2(70, 0), T.CHILLON_SOMBRA), SueloRoto.T_SOMBRA_LLEGA)
		and SueloRoto.retraso(f70, Vector2(20, 0), T.CHILLON_SOMBRA) < SueloRoto.T_SOMBRA_LLEGA,
		"le llega cuando la sombra le alcanza (antes al de cerca)")
	for n in [s70, s45, co]:
		if n != null:
			n.queue_free()
	await _esperar(2)
	var tm = combat.turno_mapa
	var O := CombatFX.Estilo.SIMA_OIDOS
	# EL CHILLIDO DE OSCURIDAD: a quien NO se ha quedado a oscuras, nada
	yo.quitar_estado(StatusEffects.Id.A_OSCURAS)
	tm._chillon_pixel(arena, {"anim": &"chillido_oscuro"}, O, pi, yo, 0.0, 1.0, 7)
	var h0: Array = _hojas_de(arena)
	_ok(not h0.has("farol") and not h0.has("oidos"), "sin quedarse a oscuras, no se le apaga nada")
	# a quien SI: su luz se apaga y las motas van a la Piña (Bebe la luz)
	yo.apply_status(StatusEffects.Id.A_OSCURAS, 2)
	tm._chillon_pixel(arena, {"anim": &"chillido_oscuro"}, O, pi, yo, 0.0, 1.0, 7)
	var h1: Array = _hojas_de(arena)
	_ok(h1.has("farol"), "a oscuras: su luz se apaga")
	_ok(h1.count("mota_entra") == 4, "y 4 motas de luz vuelan a la Piña (%d)" % h1.count("mota_entra"))
	# EL CHILLIDO NORMAL: los oidos en blanco
	tm._chillon_pixel(arena, {"anim": &"chillido"}, O, pi, yo, 0.0, 1.0, 7)
	_ok(_hojas_de(arena).has("oidos"), "el Chillido normal: los oidos en blanco")
	tm._chillon_pixel(arena, {}, CombatFX.Estilo.SIMA_PALETOS, pi, yo, 0.0, 1.0, 7)
	_ok(_hojas_de(arena).has("paletos"), "el basico y el Picado: los paletos")
