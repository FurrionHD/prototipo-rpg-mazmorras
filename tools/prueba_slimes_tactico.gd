# LOS SLIMES EN EL TACTICO (28/09): la IA de punteria de sus habilidades, la huella roja de las cargas y que
# salirse de ella te libra. Sin ventana:
#   godot --headless --path . res://tools/prueba_slimes_tactico.tscn
# Coloca a los tuyos a mano (dos juntos cerca del slime, el resto lejos) y para cada habilidad de slime dice
# donde apunta, a cuantos pilla y con cuanto. Acaba con BIEN/MAL por comprobacion.
extends Node

const HABS := ["slime_placaje_viscoso", "slime_placaje_corrosivo", "slime_doble_embate", "slime_reventon",
	"slime_rociada_corrosiva", "slime_escupitajo_toxico", "slime_llamarada", "slime_salpicadura_ardiente",
	"slime_combustion", "slime_presion_abismo", "slime_tromba_abisal", "rey_slime_aplastamiento",
	"rey_slime_escision", "rey_slime_marea"]
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


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if jug == null:
		print("MAL: no hay jugador")
		get_tree().quit(1)
		return
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(70, 0), {})
	await _esperar(25)
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	if not Game.start_combat(enemigos, false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	var e: Combatant = combat._enemies[0]
	var al: Array = combat._aliados
	print("slime %s en %s; los tuyos: %d" % [e.nombre, str(t.pies_de(e).round()), al.size()])
	if al.size() < 3:
		print("MAL: hacen falta 3 de los tuyos y hay %d" % al.size())
		get_tree().quit(1)
		return
	# Todos aguantan: se mira a quien le cae, no quien cae.
	for a in al:
		a.max_hp = 99999.0
		a.current_hp = 99999.0
	# DOS JUNTOS delante del slime (a la derecha), el TERCERO lejos a la izquierda, el resto mas lejos aun.
	var pe: Vector2 = t.pies_de(e)
	var sitios: Array = [pe + Vector2(38, -6), pe + Vector2(40, 16), pe + Vector2(-150, 0)]
	for i in al.size():
		var s: Vector2 = sitios[i] if i < sitios.size() else pe + Vector2(-150 - 40 * i, 60)
		t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	await _esperar(2)
	for i in al.size():
		print("  %s en %s (hueco al slime %.1f)" % [al[i].nombre, str(t.pies_de(al[i]).round()), t.hueco_entre(e, al[i])])

	# 1) A DONDE APUNTA cada habilidad, desde el slime.
	print("--- punteria ---")
	for nom in HABS:
		var ab: AbilityData = load("res://resources/abilities/%s.tres" % nom)
		var plan: Dictionary = t.mejor_apunte(e, ab, al[0])
		var f = t.forma_de(ab, e, plan["punto"])
		var quienes: Array = []
		for d in t._reparto_en(ab, e, f):
			quienes.append("%s x%.2f" % [d["c"].nombre, float(d["escala"])])
		print("  %s: %s apunta a %s, pilla %d [%s]" % [nom, str(f), str((plan["punto"] as Vector2).round()),
			int(plan["n"]), ", ".join(quienes)])
		# Nadie de lejos (el tercero, a 150 px) sale en las que no llegan tanto.
		if nom in ["slime_placaje_viscoso", "slime_doble_embate", "slime_reventon", "slime_combustion"]:
			_ver(int(plan["n"]) == 2, "%s pilla a los DOS de delante y no al de lejos" % nom)
	# La Marea (r120) llega al de lejos? No: esta a 150. Y los dos de dentro, en el anillo de dentro.
	var marea: AbilityData = load("res://resources/abilities/rey_slime_marea.tres")
	var rep_m: Array = t._reparto_en(marea, e, t.forma_de(marea, e, t.pies_de(e)))
	_ver(rep_m.size() == 2 and is_equal_approx(float(rep_m[0]["escala"]), 1.0), "la Marea pilla a los 2 de cerca al 100%")

	# 2) DESDE LEJOS: el escupitajo llega sin andar al que esta a ~40 px, y no hace falta acercarse.
	print("--- desde lejos ---")
	var escupe: AbilityData = load("res://resources/abilities/slime_escupitajo_toxico.tres")
	var habs_antes: Array = e.habilidades
	var prob_antes: float = e.prob_habilidad
	e.habilidades = [escupe]
	e.prob_habilidad = 1.0
	t._colocar(al[0], t.cuerpo_de(al[0]), pe + Vector2(85, 0) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	t._colocar(al[1], t.cuerpo_de(al[1]), pe + Vector2(95, 30) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	await _esperar(2)
	_ver(t.hueco_entre(e, al[0]) > t.alcance_de(e), "el de delante esta FUERA del alcance del basico (%.0f)" % t.hueco_entre(e, al[0]))
	_ver(t._decidir_de_lejos(e) and t.sacar_decidida(e) == escupe, "decide escupir desde lejos sin andar")
	t._tiradas.clear()
	e.habilidades = habs_antes
	e.prob_habilidad = prob_antes
	t._colocar(al[0], t.cuerpo_de(al[0]), sitios[0] - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	t._colocar(al[1], t.cuerpo_de(al[1]), sitios[1] - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	await _esperar(2)

	# 3) LA CARGA: el Reventon deja su huella ROJA; uno se sale y se libra, el otro se la come.
	print("--- carga ---")
	var rev: AbilityData = load("res://resources/abilities/slime_reventon.tres")
	combat.enemigos._enemy_begin_charge(e, rev, al[0])
	var arena: ArenaCombate = t._arena()
	var h: Dictionary = arena.huellas.get(e, {})
	_ver(not h.is_empty(), "la carga deja huella en el suelo")
	_ver(not h.is_empty() and (h["color"] as Color).is_equal_approx(t.COLOR_ENEMIGO), "y es ROJA")
	_ver(t._huellas_red.has(t._cod(e) * t.CLASES_HUELLA + t.CLASE_CARGA), "y viaja a los espejos")
	var forma_carga = t._cargas[e][2]
	print("  huella: %s en %s" % [str(forma_carga), str(forma_carga.centro.round())])
	# El primero se aparta lejos; el segundo se queda.
	t._colocar(al[0], t.cuerpo_de(al[0]), pe + Vector2(0, -130) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	await _esperar(2)
	var vida: Dictionary = {}
	for a in al:
		vida[a] = a.current_hp
	e.charging = null
	combat.enemigos._enemy_use_ability(e, rev)
	for a in al:
		print("  %s: %.1f -> %.1f" % [a.nombre, float(vida[a]), a.current_hp])
	_ver(is_equal_approx(float(vida[al[0]]), al[0].current_hp), "el que se aparto se libra")
	_ver(al[1].current_hp < float(vida[al[1]]) or combat._log_lines.back().find("no te ha dado") >= 0,
		"al que se quedo le cae (o lo esquiva)")
	_ver(not arena.huellas.has(e) and not t._cargas.has(e), "al soltar la huella se borra")
	for l in combat._log_lines.slice(maxi(0, combat._log_lines.size() - 2)):
		print("  log: ", l)

	# 4) ATURDIDO CARGANDO: se le borra la huella.
	combat.enemigos._enemy_begin_charge(e, rev, al[1])
	t.olvidar_carga(e)
	e.charging = null   # como hace el aturdido de verdad (combat_enemigos)
	_ver(not arena.huellas.has(e), "interrumpida, la huella se va")

	# 5) EL CUERPO: el Reventon SALTA al centro de su circulo y el placaje EMBISTE por su linea, con su animacion.
	print("--- cuerpo ---")
	var cu: Node2D = t.cuerpo_de(e)
	var sp: AnimatedSprite2D = cu.get("_sprite")
	# El del GENERADOR, no el horneado: las animaciones nuevas (hinchado, aplaston...) no estan en disco
	# hasta que se rehornea.
	sp.sprite_frames = SlimeSprites.generar_de(cu.get("data"), 0.0)
	var vistas: Dictionary = {}
	for prueba in [["slime_reventon", "hinchado,aplaston,deshincharse", 62.0], ["slime_placaje_viscoso", "embestida", 44.0]]:
		# Que acabe lo anterior ANTES de colocar: la pelea sigue viva y en un segundo se mueven los turnos.
		await get_tree().create_timer(1.0, true, false, true).timeout
		# Los dos de delante otra vez delante, con trecho (el placaje es una linea de 40: mas cerca).
		# Respecto al NODO del slime: sus pies salen de su dibujo, y en pleno 'inflar' estan movidos.
		var pe2: Vector2 = t.pos_de(e)
		t._colocar(al[0], t.cuerpo_de(al[0]), pe2 + Vector2(float(prueba[2]), -14))
		t._colocar(al[1], t.cuerpo_de(al[1]), pe2 + Vector2(float(prueba[2]) + 2.0, 12))
		var ab2: AbilityData = load("res://resources/abilities/%s.tres" % prueba[0])
		var antes_pos: Vector2 = t.pos_de(e)
		var sp_y0: float = sp.position.y
		vistas.clear()
		var alto_max: float = 0.0
		combat.enemigos._enemy_use_ability(e, ab2, al[0])
		combat._fx.arrancar_cola()
		var t1: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 2500:
			await get_tree().process_frame
			vistas[String(sp.animation)] = true
			alto_max = maxf(alto_max, sp_y0 - sp.position.y)
		var movido: float = antes_pos.distance_to(t.pos_de(e))
		print("    forma %s centro %s; pies slime %s; los tuyos %s / %s; log: %s" % [str(t.ultima_forma_enemigo),
			str(t.ultima_forma_enemigo.centro.round()) if t.ultima_forma_enemigo != null else "-", str(t.pies_de(e).round()),
			str(t.pos_de(al[0]).round()), str(t.pos_de(al[1]).round()), combat._log_lines.back()])
		print("  %s: se movio %.1f px (de %s a %s), subio %.1f, anims %s" % [prueba[0], movido,
			str(antes_pos.round()), str(t.pos_de(e).round()), alto_max, str(vistas.keys())])
		_ver(movido > 8.0, "%s mueve al slime" % prueba[0])
		for quiere in String(prueba[1]).split(","):
			var hizo: bool = false
			for k in vistas:
				if String(k).begins_with(quiere):
					hizo = true
			_ver(hizo, "%s: el cuerpo del mapa hace '%s'" % [prueba[0], quiere])
		if prueba[0] == "slime_reventon":
			_ver(alto_max > 10.0, "el Reventon va por el aire")
		_ver(absf(sp.position.y - sp_y0) < 0.5, "y el dibujo acaba en el suelo")
		_ver(not cu.has_meta("gesto_pelea"), "y el gesto se suelta")

	# 6) LA POSE DE CARGA: se infla y se QUEDA hinchado; si la carga se va sin soltarla, se deshincha.
	print("--- pose de carga ---")
	await get_tree().create_timer(1.0, true, false, true).timeout
	vistas.clear()
	combat.enemigos._enemy_begin_charge(e, rev, al[1])
	var t2: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 2000:
		await get_tree().process_frame
		vistas[String(sp.animation)] = true
	print("  cargando: anims %s, ahora %s" % [str(vistas.keys()), sp.animation])
	_ver(vistas.keys().any(func(k): return String(k).begins_with("inflar")), "al cargar se infla")
	_ver(String(sp.animation).begins_with("hinchado") and cu.has_meta("gesto_pelea"), "y se queda hinchado")
	e.charging = null
	t.olvidar_carga(e)
	vistas.clear()
	var t3: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t3 < 3000:
		await get_tree().process_frame
		vistas[String(sp.animation)] = true
	print("  interrumpida: anims %s" % str(vistas.keys()))
	_ver(vistas.keys().any(func(k): return String(k).begins_with("deshincharse")), "interrumpida, se deshincha")
	_ver(not cu.has_meta("gesto_pelea"), "y vuelve a lo suyo")

	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
