# MIRAR EL SUELO QUE SE ROMPE EN UNA PELEA DE VERDAD (arena de pruebas): lanza una habilidad del
# martillo hacia tres enemigos y saca fotos mientras la rotura sale, con el instante en que le llega el
# golpe a cada uno. CON VENTANA.
#   SUELO_HAB=temblor SUELO_SALIDA=/ruta/pref godot --path . res://tools/ver_suelo_pelea.tscn
extends Node

const BICHOS := [
	["rata", Vector2(55, -15)],
	["slime", Vector2(80, 35)],
	["slime", Vector2(40, 60)],
]
const FOTOS := [0.15, 0.45, 0.8, 1.2, 1.7, 2.4]
var _salida: String = ""


func _ready() -> void:
	_salida = OS.get_environment("SUELO_SALIDA")
	if _salida == "":
		_salida = "user://suelo_pelea"
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


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	var ruta: String = "%s_%s.png" % [_salida, nombre]
	img.save_png(ruta)
	print("[foto] ", ruta)


func _correr() -> void:
	var nom: String = OS.get_environment("SUELO_HAB")
	if nom == "":
		nom = "temblor"
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	# SUELO_DUAL=espada_corta,daga: la principal y la secundaria (la mano que se ve pegar en cada golpe).
	var dual: String = OS.get_environment("SUELO_DUAL")
	if dual != "":
		var pz: PackedStringArray = dual.split(",")
		Game.equipar_arma(load("res://resources/weapons/%s.tres" % pz[0]))
		print("  secundaria: ", Game.equipar_secundaria(load("res://resources/weapons/%s.tres" % pz[1])))
		# Y la habilidad EQUIPADA: sin eso no se sabe que arma la aporta y cae a la principal.
		var hab: String = OS.get_environment("SUELO_HAB")
		print("  equipada: ", Game.colocar_habilidad(load("res://resources/abilities/%s.tres" % hab), 0))
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if jug == null:
		print("MAL: no hay jugador")
		get_tree().quit(1)
		return
	for b in BICHOS:
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % b[0],
			jug.global_position + (b[1] as Vector2), {})
		await _esperar(3)
	await _esperar(20)
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
	var ok: bool = await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0)
	if not ok:
		print("MAL: no llego un turno en el que se pueda andar")
		get_tree().quit(1)
		return
	var media := Vector2.ZERO
	for e in enemigos:
		media += (e as Node2D).global_position
	media /= float(enemigos.size())
	var ab: AbilityData = load("res://resources/abilities/%s.tres" % nom)
	combat._player.current_energy = combat._player.max_energy
	# SUELO_STATS=1: el ataque y la defensa de cada uno de los tuyos (de donde sale lo que pega un escudazo).
	if OS.get_environment("SUELO_STATS") != "":
		for al in combat._aliados:
			var a: Combatant = al
			print("  stats %s: nv=%d atk=%.1f (base %.1f + arma %.1f, mv %.2f) def=%.1f (base %.1f + armadura %.1f) escudo_def=%.1f atk_escudo=%.1f fx_escudo=%d multiplic=%s" % [
				a.nombre, a.level, a.atk(), a.base_attack, a.ataque_arma, a.motion_value, a.def_value(),
				a.base_defense, a.extra_defense, a.defend_defense, a.atk_escudo(), a.fx_escudo,
				str(a.stats_multiplicativas)])
			print("    habs: fuerza=%.0f resistencia=%.0f" % [a.hab("fuerza"), a.hab("resistencia")])
	t.apunte = media
	# Las de un solo enemigo, al MAS CERCANO: el centro del grupo les queda fuera de alcance.
	if OS.get_environment("SUELO_APUNTE") == "cerca":
		var mejor: float = INF
		for e in combat._enemies:
			if t.hueco_entre(combat._player, e) < mejor:
				mejor = t.hueco_entre(combat._player, e)
				t.apunte = t.pos_de(e)
	# SUELO_ARRIMAR=1: el jugador se pone pegado a la izquierda del grupo (las de alcance corto de la daga).
	if OS.get_environment("SUELO_ARRIMAR") != "":
		var izq: Combatant = null
		for e in combat._enemies:
			if izq == null or t.pos_de(e).x < t.pos_de(izq).x:
				izq = e
		t._colocar(combat._player, t.cuerpo_de(combat._player), t.pos_de(izq) + Vector2(-26, 0))
		t.apunte = t.pos_de(izq) + Vector2(20, 0)
	# SUELO_ALCANCE=32.25: el alcance del arma que se prueba (el personaje de referencia lleva la suya).
	if OS.get_environment("SUELO_ALCANCE") != "":
		combat._player.alcance = float(OS.get_environment("SUELO_ALCANCE"))
	# SUELO_APUNTE=lejos: hacia atras, lejos del grupo (el Paso ligero para irse).
	if OS.get_environment("SUELO_APUNTE") == "lejos":
		t.apunte = t.pies_de(combat._player) + Vector2(-80, 0)
	# SUELO_APUNTE=aliado: al compañero mas alejado del jugador (el Muro, la Escolta).
	if OS.get_environment("SUELO_APUNTE") == "aliado":
		var lejos: float = -1.0
		for al in combat._aliados:
			if al != combat._player and t.pos_de(al).distance_to(t.pos_de(combat._player)) > lejos:
				lejos = t.pos_de(al).distance_to(t.pos_de(combat._player))
				t.apunte = t.pies_de(al)
	# SUELO_SEGUIMIENTO=1: el jugador lleva Oportunista y "un compañero" (el primer enemigo, prestado como
	# _player) acaba de pegar al segundo. Se mira si entra, salta a su espalda y gasta carga.
	if OS.get_environment("SUELO_SEGUIMIENTO") != "":
		var yo: Combatant = combat._player
		yo.apply_status(StatusEffects.Id.OPORTUNISTA, 30)
		# SIN GOLPE (el Filo emponzoñado, una cura): no tiene que entrar nadie.
		combat.golpeados_en_la_accion.clear()
		var vida_antes: float = combat._enemies[1].current_hp
		combat._player = combat._enemies[0]
		combat._disparar_seguimientos(combat._enemies[1])
		combat._player = yo
		print("  sin golpe: %s" % ("BIEN, no entra nadie" if is_equal_approx(vida_antes, combat._enemies[1].current_hp)
			else "MAL: ha entrado sin que nadie pegara"))
		for obj in [combat._enemies[1], combat._enemies[2]]:
			combat.golpeados_en_la_accion.append(obj)   # "el compañero le acaba de pegar"
			print("  seguimiento: yo en %s, pega %s a %s en %s (distancia %.0f)" % [str(t.pos_de(yo).round()),
				combat._enemies[0].nombre, obj.nombre, str(t.pos_de(obj).round()),
				t.pies_de(yo).distance_to(t.pies_de(obj))])
			combat._player = combat._enemies[0]
			combat._disparar_seguimientos(obj)
			combat._player = yo
			combat._fx.arrancar_cola()
			await get_tree().create_timer(1.0, true, false, true).timeout
			var usos: int = -1
			for e in yo.statuses:
				if e.id() == StatusEffects.Id.OPORTUNISTA:
					usos = int(e.get("usos")) if e.get("usos") != null else -2
			print("  -> yo en %s, %s vida=%.1f, usos=%d" % [str(t.pos_de(yo).round()), obj.nombre,
				obj.current_hp, usos])
		print("=== FIN ===")
		get_tree().quit(0)
		return
	# SUELO_DEFENSA=1: pulsa Defender y mira que el muñeco se queda en su postura de defensa.
	if OS.get_environment("SUELO_DEFENSA") != "":
		var mun_d: MunecoJugador = t.cuerpo_de(combat._player).get("_muneco")
		combat._accion_defender()
		await get_tree().create_timer(1.5, true, false, true).timeout
		print("  defensa: postura=%s anim=%s" % [str(mun_d.postura_defensa), mun_d.anim_actual()])
		# SOLO POR DELANTE: mirando a cada enemigo, y de espaldas a el.
		var yo_d: Combatant = combat._player
		var cu_d: Node2D = t.cuerpo_de(yo_d)
		for e in combat._enemies:
			var hacia_e: Vector2 = (t.pies_de(e) - t.pies_de(yo_d)).normalized()
			t._frente_defensa[yo_d] = hacia_e
			var de_frente: bool = t.cubre_de_frente(yo_d, e)
			t._frente_defensa[yo_d] = -hacia_e
			print("  %s: mirandole cubre=%s, de espaldas cubre=%s" % [e.nombre, str(de_frente),
				str(t.cubre_de_frente(yo_d, e))])
		print("=== FIN ===")
		get_tree().quit(0)
		return
	# SUELO_ESQUIVA=1: el primer enemigo le pega al jugador (en guardia) y lo esquiva. Se mide lo que se aparta
	# el muñeco y que vuelve a su sitio.
	if OS.get_environment("SUELO_ESQUIVA") != "":
		var yo2: Combatant = combat._player
		yo2.en_guardia = true
		var mun: Node2D = t.cuerpo_de(yo2).get("_muneco")
		var base: Vector2 = mun.position
		combat.efectos._fx_golpe(combat._enemies[0], yo2, 0.0, false, true)
		print("  en guardia marcado en la cola: %s" % str(combat._fx._cola.back().get("guardia", false)))
		combat._fx.arrancar_cola()
		var maximo: float = 0.0
		var t1: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 1500:
			await get_tree().process_frame
			maximo = maxf(maximo, mun.position.distance_to(base))
		print("  esquiva: se aparto %.1f px y acabo a %.1f px de su sitio" % [maximo, mun.position.distance_to(base)])
		print("=== FIN ===")
		get_tree().quit(0)
		return
	t._hay_apunte = true
	print("%s: pilla a %d, escudazo a %d, de los tuyos %d  (jugador en %s)" % [nom,
		t.reparto_habilidad(ab, t._quien).size(), t.reparto_escudazo(ab, t._quien).size(),
		t.aliados_de_huella(ab, t._quien).size() if ab.forma_a_aliados else 0,
		str(t.pos_de(combat._player).round())])
	for e in combat._enemies:
		print("  antes: %s vida=%.1f pos=%s hueco=%.1f" % [e.nombre, e.current_hp, str(t.pos_de(e).round()),
			t.hueco_entre(combat._player, e)])
	# Cada aviso de gesto del cuerpo, con su animacion (la finta y luego pinchazos, la bomba y puñaladas...).
	var t_av: int = Time.get_ticks_msec()
	combat._fx.gesto_iniciado.connect(func(_b, _d, dur, anim, m) -> void:
		print("  aviso: %s mano=%d a %.2f s (dura %.2f)" % [anim, m, (Time.get_ticks_msec() - t_av) / 1000.0, dur])
		var mu = t.cuerpo_de(combat._player).get("_muneco")
		if mu != null:
			(func() -> void: print("    muneco: ", mu._anim)).call_deferred())
	# Las de carga (Martillo de guerra), soltadas ya: lo que se mira es el golpe, no el turno de cargar.
	# Con SUELO_DUAL y la habilidad sin desbloquear en la partida de referencia, su mano como la reparte Game
	# (build del Combatant): la de las armas que la traen.
	if dual != "" and not combat._player.ability_hands.has(ab):
		var idxs: Array = []
		var pj: PersonajeData = Game.lider()
		if Game.habilidades_de_item(pj.equipped_main).has(ab):
			idxs.append(0)
		if pj.equipped_off is WeaponData and Game.habilidades_de_item(pj.equipped_off).has(ab):
			idxs.append(1)
		combat._player.ability_hands[ab] = idxs if not idxs.is_empty() else [0]
		print("  manos de la habilidad: ", combat._player.ability_hands[ab])
	combat.habilidades._usar_habilidad(ab, ab.carga_turnos > 0)
	var t0: int = Time.get_ticks_msec()
	await _esperar(1)
	for ev in combat._fx._cola:
		print("  golpe: t=%.2f retraso_suelo=%.2f dmg=%.1f" % [float(ev["t"]), float(ev.get("retraso_suelo", -1.0)), float(ev["dmg"])])
	# Y el gesto del cuerpo: su arranque y su primer golpe (en tiempo de animacion), y la escala.
	for g in combat._fx._gestos:
		print("  gesto: anim=%s t_ini=%.2f t_imp=%.2f escala=%.2f" % [str(g.get("anim", "")), float(g["t_ini"]),
			float(g["t_imp"]), combat._fx.escala_tiempo])
	# SIN FOTOS (headless): la vida y el sitio de cada enemigo antes y despues de que se vea el golpe.
	# Sirve para los repartos (Carniceria) y los tirones (Desgarro).
	if OS.get_environment("SUELO_SIN_FOTOS") != "":
		await get_tree().create_timer(1.2, true, false, true).timeout
		for e in combat._enemies:
			print("  despues: %s vida=%.1f pos=%s hueco=%.1f" % [e.nombre, e.current_hp,
				str(t.pos_de(e).round()), t.hueco_entre(combat._player, e)])
		print("  despues: jugador en %s" % str(t.pos_de(combat._player).round()))
		# LO DE LOS TUYOS (las de apoyo de la espada larga y el escudo, 25/09): defensa, estados, provocacion.
		for al in combat._aliados:
			print("  aliado %s: pos=%s defiende=%s estados=[%s] provoca=%d a %d guardia=%s escudazo=%s" % [
				al.nombre, str(t.pos_de(al).round()), str(combat._defendiendo.get(al, false)),
				al.status_summary(), al.provocar_turnos, al.provocados.size(), str(al.en_guardia),
				str(al.guardia_contra_escudo)])
		print("=== FIN ===")
		get_tree().quit(0)
		return
	for i in FOTOS.size():
		var falta: float = FOTOS[i] - float(Time.get_ticks_msec() - t0) / 1000.0
		if falta > 0.0:
			await get_tree().create_timer(falta, true, false, true).timeout
		await _foto("%s_%d" % [nom, i])
	print("=== FIN ===")
	get_tree().quit(0)
