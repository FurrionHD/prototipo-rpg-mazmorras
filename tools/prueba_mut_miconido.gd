# LOS MUTANTES DEL MICONIDO (09/11, memoria miconido-mutante), en una pelea de verdad en la arena y sin ventana:
#   1) las fichas: Campana palida y Aventurero florecido (stats, habilidades, basico propio, alcance, magicos y elementos)
#   2) LUZ QUE ATRAE: al empezar su turno acerca a los tuyos que tiene cerca; a los de lejos, no
#   3) NO SIENTE EL DOLOR: el florecido aguanta mas el control
#   4) INFECTADO: las Esporas de infeccion tambien a los suyos que esten dentro (sin daño)
#   5) FLORECER: el enemigo que cae infectado se levanta con hongos (el mismo, media vida, estado Florecido), tope 2
#   6) EL ELEMENTO EXPLICITO: una habilidad sin elemento escrito ya no hereda el de la ficha
#   godot --headless --path . res://tools/prueba_mut_miconido.tscn
extends Node

const R := "res://scenes/actors/enemy/miconido.tres"
var sala = null
var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	await _correr()
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


# (10/11) Las setas de un florecido, clavadas en la SILUETA del fotograma que se ve (AnclasHongos) y no flotando por
# encima de la caja: la hoja esta medida, hay setas por arriba Y por los lados/frente, y todos los pies caen dentro del
# dibujo. Se mira en varios fotogramas de su animacion (que sigan al cuerpo al moverse).
func _setas_en_cuerpo(setas, quien: String) -> void:
	if setas == null or not is_instance_valid(setas):
		_ver(false, "%s: sin setas que medir" % quien)
		return
	var m: Dictionary = setas.medida()
	_ver(bool(m["medida"]), "%s: su hoja tiene las anclas medidas" % quien)
	_ver(int(m["pies"]) >= 4, "%s: setas por arriba, los lados y el frente (%d puestas de %d)" % [quien, m["pies"], setas._plantadas.size()])
	# (10/11, version E) la mancha podrida cuelga del dibujo del cuerpo y las de los lados van por DEBAJO de los cuerpos
	_ver(is_instance_valid(setas._mancha) and setas._mancha.get_parent() == setas._spr
		and int(setas._mancha.material.get_shader_parameter("n_pies")) > 0,
		"%s: la mancha podrida al pie, sobre su cuerpo" % quien)
	_ver(is_instance_valid(setas._detras) and setas._detras.z_index < Game.Z_PERSONAJES,
		"%s: las setas de los lados, por detras del cuerpo" % quien)
	var mal: int = 0
	var spr: AnimatedSprite2D = setas._spr
	var n: int = spr.sprite_frames.get_frame_count(spr.animation) if spr != null and spr.sprite_frames != null else 0
	for f in n:
		spr.frame = f
		var mf: Dictionary = setas.medida()
		if int(mf["dentro"]) < int(mf["pies"]):
			mal += 1
	_ver(mal == 0, "%s: en los %d fotogramas de '%s' todas las setas salen del cuerpo (%d mal)" % [quien, n, spr.animation if spr != null else "", mal])


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _log(combat: Node) -> String:
	return "\n".join(combat.log_entero().map(func(l): return str(l)))


func _correr() -> void:
	print("1) LAS FICHAS")
	var ed: EnemyData = load(R)
	var camp: MutacionData = ed.mutacion_de(&"campana")
	var flo: MutacionData = ed.mutacion_de(&"florecido")
	_ver(camp != null and flo != null and camp.grado == 1 and flo.grado == 2 and flo.desde.has(&"campana"),
		"linea: Campana palida (1a) -> Aventurero florecido (2a)")
	_ver(ed.voluntad == 12 and ed.magia == 22 and ed.fuerza == 26, "el normal estrena Voluntad (26/48/12/10/22/12)")
	_ver(int(camp.pesos["magia"]) == 34 and int(flo.pesos["fuerza"]) == 30, "stats de los mutantes (campana M34, florecido F30)")
	_ver(camp.basico_propio != null and camp.basico_propio.nombre == "Latigazo de filamentos" and is_equal_approx(camp.alcance_mult, 1.75),
		"Campana: su basico es el latigazo de filamentos y llega a 35")
	_ver(flo.basico_propio != null and flo.basico_propio.nombre == "Tajo oxidado", "Florecido: su basico es el tajo oxidado")
	var nombres_f: Array = flo.habilidades.map(func(a): return a.nombre)
	_ver(nombres_f.has("Estocada del muerto") and nombres_f.has("Esporas de infección") and nombres_f.has("Destello"),
		"Florecido: Estocada, Esporas de infeccion y Destello")
	var bocanada: AbilityData = load("res://resources/abilities/miconido_esporas.tres")
	var lum: AbilityData = load("res://resources/abilities/miconido_esporas_luminosas.tres")
	var des: AbilityData = load("res://resources/abilities/miconido_destello.tres")
	var inf: AbilityData = load("res://resources/abilities/miconido_esporas_infeccion.tres")
	_ver(bocanada.es_magico and lum.es_magico and des.es_magico and inf.es_magico, "esporas y luz son magicas")
	_ver(lum.elemento_golpe == Elementos.Elemento.LUZ and des.elemento_golpe == Elementos.Elemento.LUZ
		and inf.elemento_golpe < 0 and bocanada.elemento_golpe < 0, "luminosas y Destello de luz; las demas esporas, sin elemento")
	_ver(is_equal_approx(lum.dano_mult, 0.26) and is_equal_approx(inf.dano_mult, 0.49), "multiplicadores calibrados")
	_ver(des.carga_turnos == 1 and des.forma == CombatFormas.Tipo.CONO and is_equal_approx(des.forma_radio, 60.0),
		"Destello: carga un turno, cono de 60")
	_ver(is_equal_approx(inf.infecta_suyos, 0.6), "las Esporas de infeccion tambien a los suyos (60 %)")

	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_miconido", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner(R, Vector2(140, 0), {"mutacion": "campana"})
	sala.poner(R, Vector2(0, 170), {"mutacion": "florecido"})
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(-170, 0))
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(-170, 120))
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(-170, -120))
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(-170, 240))
	await _esperar(20)
	if (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)) == null:
		_ver(false, "se abre la pelea")
		return
	await _esperar(5)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	var t = combat.turno_mapa
	var campana: Combatant = null
	var florecido: Combatant = null
	var ratas: Array = []
	for e in combat._enemies:
		if e.mutacion == &"campana":
			campana = e
		elif e.mutacion == &"florecido":
			florecido = e
		elif e.nombre.to_lower().contains("rata"):
			ratas.append(e)
	_ver(campana != null and florecido != null and ratas.size() >= 3, "en la pelea: la campana, el florecido y tres ratas")
	if campana == null or florecido == null or ratas.size() < 3:
		return
	var yo: Combatant = combat._aliados[0]
	yo.max_hp = 100000.0
	yo.current_hp = 100000.0

	print("2) LUZ QUE ATRAE")
	_ver(is_equal_approx(campana.atrae_radio, 60.0) and is_equal_approx(campana.atrae_px, 15.0), "la campana atrae a 60 px, 15 px")
	var pc: Vector2 = t.pies_de(campana)
	_poner(t, yo, pc + Vector2(-50, 0))
	for otro in combat._aliados.slice(1):
		_poner(t, otro, pc + Vector2(-400, 200))
	var antes: float = t.pies_de(yo).distance_to(pc)
	combat.enemigos._luz_que_atrae(campana)
	await _esperar(40)
	var despues: float = t.pies_de(yo).distance_to(pc)
	_ver(despues < antes - 5.0, "a 50 px le acerca (%.1f -> %.1f)" % [antes, despues])
	_ver(_log(combat).contains("atrae"), "y lo dice el registro")
	_poner(t, yo, pc + Vector2(-200, 0))
	antes = t.pies_de(yo).distance_to(pc)
	combat.enemigos._luz_que_atrae(campana)
	await _esperar(40)
	_ver(is_equal_approx(t.pies_de(yo).distance_to(pc), antes), "a 200 px, nada")

	print("2b) LOS EFECTOS EN PIXEL (10/11, sin rejilla)")
	await _efectos_pixel(t, campana, florecido, yo)

	print("3) NO SIENTE EL DOLOR")
	_ver(is_equal_approx(florecido.stun_resist, 0.7) and is_equal_approx(campana.stun_resist, 0.3),
		"florecido 0,7 de aguante al control (la campana, el del normal 0,3)")

	print("4) INFECTADO")
	var pf: Vector2 = t.pies_de(florecido)
	_poner(t, ratas[0], pf + Vector2(25, 0))
	_poner(t, ratas[1], pf + Vector2(300, 0))
	var inf_seguro: AbilityData = inf.duplicate()
	inf_seguro.infecta_suyos = 1.0
	combat.enemigos._infectar_suyos(florecido, inf_seguro)
	_ver(ratas[0].has_status(StatusEffects.Id.INFECTADO), "la rata de dentro queda infectada")
	_ver(not ratas[1].has_status(StatusEffects.Id.INFECTADO), "la de lejos, no")
	_ver(ratas[0].current_hp >= ratas[0].max_hp - 0.01, "sin daño (son los suyos)")
	_ver(not florecido.has_status(StatusEffects.Id.INFECTADO), "el no se infecta a si mismo")
	_poner(t, campana, pf + Vector2(-25, 0))
	combat.enemigos._infectar_suyos(florecido, inf_seguro)
	_ver(not campana.has_status(StatusEffects.Id.INFECTADO), "a los micónidos no les hace nada: son el hongo")

	print("5) FLORECER")
	var r0: Combatant = ratas[0]
	var max0: float = r0.max_hp
	var n_antes: int = combat._enemies.size()
	r0.take_damage(r0.current_hp + 10.0)
	_ver(r0.has_status(StatusEffects.Id.INFECTADO), "(al caer sigue infectada)")
	combat._morir_enemigo(r0)
	await _esperar(10)
	var flor: Array = combat._enemies.filter(func(o): return o.is_alive() and o.has_status(StatusEffects.Id.FLORECIDO))
	_ver(flor.size() == 1, "se levanta una florecida (%d)" % flor.size())
	if flor.size() == 1:
		var fl: Combatant = flor[0]
		_ver(fl.nombre.to_lower().contains("rata"), "es la misma: una rata (%s)" % fl.nombre)
		_ver(is_equal_approx(fl.max_hp, max0) and is_equal_approx(fl.current_hp, max0 * 0.5), "con la mitad de su vida")
		_ver(not fl.has_status(StatusEffects.Id.INFECTADO), "ya no esta infectada")
		# LAS SETAS Y EL GRIS DE MUERTO (TacticoHongos), del estado.
		for _k in 30:
			await get_tree().process_frame
			t.tick(1.0 / 60.0)
		var cu_fl: Node2D = t.cuerpo_de(fl)
		_ver(cu_fl != null and cu_fl.has_meta(TacticoHongos.MARCA), "su cuerpo lleva la marca del gris de muerto")
		var setas = t._hongos._setas.get(fl) if t._hongos != null else null
		_ver(setas != null and is_instance_valid(setas) and not setas._plantadas.is_empty(),
			"le brotan setas (%d)" % (setas._plantadas.size() if setas != null and is_instance_valid(setas) else 0))
		_setas_en_cuerpo(setas, "la florecida")
		var spr = cu_fl.get("_sprite") if cu_fl != null else null
		if spr is CanvasItem:
			var mo: Color = (spr as CanvasItem).self_modulate
			_ver(mo.r < 0.8 and mo.g < 0.8, "y se ve apagado (self_modulate %s)" % str(mo))
		# Cae otra vez (infectada de nuevo): se queda en el suelo.
		fl.apply_status(StatusEffects.Id.INFECTADO)
		fl.take_damage(fl.current_hp + 10.0)
		combat._morir_enemigo(fl)
		await _esperar(10)
		_ver(combat._enemies.filter(func(o): return o.is_alive() and o.has_status(StatusEffects.Id.FLORECIDO)).size() == 0,
			"una florecida que vuelve a caer se queda en el suelo")
	_ver(_log(combat).contains("brotan setas"), "y lo dice el registro")
	# El tope: dos de pie a la vez.
	for k in 2:
		var rk: Combatant = ratas[1 + k]
		rk.apply_status(StatusEffects.Id.INFECTADO)
		rk.take_damage(rk.current_hp + 10.0)
		combat._morir_enemigo(rk)
		await _esperar(5)
	var de_pie: int = combat._enemies.filter(func(o): return o.is_alive() and o.has_status(StatusEffects.Id.FLORECIDO)).size()
	_ver(de_pie == 2, "dos florecidas de pie (%d)" % de_pie)
	# LA FOTO (MICONIDO_CAPTURA=<ruta sin .png>, con ventana): las florecidas con sus setas, para mirarlas.
	var salida: String = OS.get_environment("MICONIDO_CAPTURA")
	if salida != "" and DisplayServer.get_name() != "headless":
		var flor_v: Array = combat._enemies.filter(func(o): return o.is_alive() and o.has_status(StatusEffects.Id.FLORECIDO))
		var cam := Camera2D.new()
		cam.zoom = Vector2(3.0, 3.0)
		cam.process_mode = Node.PROCESS_MODE_ALWAYS
		t._arena().add_child(cam)
		cam.global_position = t.pies_de(flor_v[0]) + Vector2(0, -20) if not flor_v.is_empty() else t.pies_de(campana)
		cam.make_current()
		for _k in 40:
			await get_tree().process_frame
			t.tick(1.0 / 60.0)
		get_tree().root.get_viewport().get_texture().get_image().save_png(salida + ".png")
		print("     captura: %s.png" % salida)
	var vivo_otro: Combatant = null
	for o in combat._enemies:
		if o.is_alive() and not o.has_status(StatusEffects.Id.FLORECIDO) and o != campana and o != florecido:
			vivo_otro = o
	if vivo_otro != null:
		vivo_otro.apply_status(StatusEffects.Id.INFECTADO)
		vivo_otro.take_damage(vivo_otro.current_hp + 10.0)
		combat._morir_enemigo(vivo_otro)
		await _esperar(5)
		_ver(combat._enemies.filter(func(o): return o.is_alive() and o.has_status(StatusEffects.Id.FLORECIDO)).size() == 2,
			"con dos de pie, la tercera no se levanta (tope 2)")
	print("   (enemigos %d -> %d)" % [n_antes, combat._enemies.size()])

	print("7) TU PERSONAJE FLORECIDO (fase 1: su basico; fase 2: las habilidades de su arma con su energia)")
	var al: Combatant = combat._aliados[1] if combat._aliados.size() > 1 else null
	_ver(al != null, "hay un segundo de los tuyos")
	if al != null:
		var pj_al: PersonajeData = Game.pj_de_combatant(al)
		var max_al: float = al.max_hp
		al.max_energy = 120.0
		al.current_energy = 37.0
		var en_max_al: float = al.max_energy
		var en_al: float = al.current_energy
		_poner(t, al, t.pies_de(yo) + Vector2(30, 0))
		al.apply_status(StatusEffects.Id.INFECTADO)
		al.take_damage(al.current_hp + 10.0)
		combat.altas._caer_aliado(al)
		await _esperar(5)
		var fp: Combatant = null
		for o in combat._enemies:
			if o.is_alive() and o.has_status(StatusEffects.Id.FLORECIDO) and o.nombre == al.nombre:
				fp = o
		_ver(fp != null, "%s se levanta en el bando del hongo" % al.nombre)
		if fp != null:
			_ver(is_equal_approx(fp.max_hp, max_al * 2.0) and is_equal_approx(fp.current_hp, fp.max_hp),
				"con el doble de vida, entera (%.0f -> %.0f)" % [max_al, fp.max_hp])
			var w: WeaponData = pj_al.equipped_main as WeaponData if pj_al != null else null
			_ver(fp.fx_basico == int(CombatFX.FX_ARMA.get(int(w.tipo) if w != null else 0, -9)), "su basico, con el dibujo de su arma")
			# (fase 2, tanda 1) LAS HABILIDADES DE SU ARMA con SU ENERGIA de jugador.
			_ver(fp.energia_de_jugador and is_equal_approx(fp.max_energy, en_max_al) and is_equal_approx(fp.current_energy, en_al),
				"con la energia que tenia al caer (%.0f/%.0f)" % [fp.current_energy, fp.max_energy])
			var esperadas: Array = combat.habilidades_florecido(fp)
			_ver(fp.habilidades == esperadas and fp.habilidades.all(func(a): return al.abilities_combate.has(a)),
				"las habilidades de su arma que sabe usar (%s)" % ", ".join(fp.habilidades.map(func(a): return a.nombre)))
			var cu_a: Node2D = t.cuerpo_de(al)
			_ver(cu_a != null and t.cuerpo_de(fp) == cu_a, "usa el muñeco del caido")
			# LO QUE VIAJA A LOS ESPEJOS: su fila del roster lleva la direccion del muñeco (peer/cuerpo), no la de un bicho.
			var ro: Dictionary = combat.espejo.roster_para_espejo()
			var filas_e: Array = ro.get("enemigos", [])
			var ie: int = combat._enemies.find(fp)
			var fila: Dictionary = filas_e[ie] if ie >= 0 and ie < filas_e.size() else {}
			var dir_al: Dictionary = t.direccion_red(al)
			_ver(fila.has("peer") and int(fila.get("peer", -1)) == int(dir_al.get("peer", -2))
				and int(fila.get("cuerpo", -1)) == int(dir_al.get("cuerpo", -2)),
				"en el roster su fila lleva la direccion del muñeco del caido (%s)" % str(dir_al))
			_ver(cu_a != null and not cu_a.has_meta(t.MARCA_CAIDO), "y el muñeco esta de pie")
			# (10/11) SUS SETAS, CLAVADAS EN EL CUERPO DE SU MUÑECO (la capa "cuerpo"), fotograma a fotograma.
			for _k in 10:
				await get_tree().process_frame
				t.tick(1.0 / 60.0)
			var setas_p = t._hongos._setas.get(fp) if t._hongos != null else null
			_ver(setas_p != null and is_instance_valid(setas_p) and setas_p._spr != null
				and setas_p._spr.get_parent() is MunecoJugador, "sus setas siguen la capa del cuerpo de su muñeco")
			_setas_en_cuerpo(setas_p, "tu personaje florecido")
			# SU TURNO: pega a los tuyos.
			_poner(t, yo, t.pies_de(fp) + Vector2(-20, 0))
			for otro in combat._aliados:
				if otro != yo and otro != al:
					_poner(t, otro, t.pies_de(fp) + Vector2(-500, 300))
			var hp_yo: float = yo.current_hp
			var log0: int = combat.log_entero().size()
			combat._state = combat.State.ADVANCING
			t.turno_enemigo(fp)
			for _i in 300:
				await get_tree().process_frame
				t.tick(1.0 / 60.0)
				if yo.current_hp < hp_yo:
					break
			var nuevo: String = "\n".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
			_ver(yo.current_hp < hp_yo or nuevo.contains(al.nombre), "en su turno te ataca (%s)" % nuevo.replace("\n", " | ").left(160))
			# CON ENERGIA, UNA HABILIDAD (y la gasta). Para que no dependa del arma que lleve: el Tajo pesado (un golpe
			# limpio, 73 de energia), y sin otras.
			var tajo: AbilityData = load("res://resources/abilities/tajo_pesado.tres")
			var prov: AbilityData = load("res://resources/abilities/provocacion.tres")
			var guardadas: Array = fp.abilities_combate
			fp.abilities_combate = [tajo, prov]
			var filtradas: Array = combat.habilidades_florecido(fp)
			fp.abilities_combate = guardadas
			_ver(filtradas == [tajo, prov], "de su arma toma el Tajo pesado y la Provocacion (tanda 4) (%s)" % str(
				filtradas.map(func(a): return a.nombre)))
			fp.habilidades = [tajo]
			fp.ability_cooldowns.clear()
			fp.current_energy = fp.max_energy
			var hp1: float = yo.current_hp
			log0 = combat.log_entero().size()
			await _turno_de(combat, t, fp, yo, hp1)
			nuevo = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
			_ver(nuevo.contains("Tajo pesado"), "con energia usa una habilidad de su arma (%s)" % nuevo.left(160))
			_ver(is_equal_approx(fp.current_energy, fp.max_energy - tajo.coste(fp.ability_manos(tajo))),
				"y gasta su coste (%.0f -> %.0f)" % [fp.max_energy, fp.current_energy])
			# El Tajo pesado SE PREPARA (sale al volver a llegar a la barra): ese turno lo suelta, sin gastar otra vez.
			if fp.retrasando:
				var en_antes: float = fp.current_energy
				log0 = combat.log_entero().size()
				# (el 09/11 fallo una vez con el golpe fallado: aqui se FUERZA que lo esquives, para mirar ese caso siempre)
				yo.evasion_bonus = 5.0
				await _turno_de(combat, t, fp, yo, yo.current_hp)
				yo.evasion_bonus = 0.0
				nuevo = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
				_ver(nuevo.contains("Tajo pesado") and is_equal_approx(fp.current_energy, en_antes),
					"al volver a la barra lo suelta, sin gastar mas (energia %.1f -> %.1f; %s)" % [en_antes, fp.current_energy,
					nuevo.left(120)])
			# SIN ENERGIA, EL BASICO (y la repone).
			fp.ability_cooldowns.clear()
			fp.current_energy = 5.0
			hp1 = yo.current_hp
			log0 = combat.log_entero().size()
			await _turno_de(combat, t, fp, yo, hp1)
			nuevo = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
			_ver(not nuevo.contains("Tajo pesado") and fp.current_energy > 5.0,
				"sin energia pega el basico y la repone (5 -> %.0f)" % fp.current_energy)
			# (tanda 2) LOS GOLPES CON DETALLES: ya entran (area, critico, penetracion, el salto, el avance...); los apoyos y
			# las posturas aun no (el golpe de escudo deja en guardia: tanda 3).
			var nombres_t2: Array = ["oportunista", "danza_de_acero", "molinete", "disparo_perforante", "golpe_escudo_normal"]
			var habs_t2: Array = nombres_t2.map(func(n): return load("res://resources/abilities/%s.tres" % n))
			fp.abilities_combate = habs_t2
			var t2: Array = combat.habilidades_florecido(fp).map(func(a): return a.nombre)
			fp.abilities_combate = guardadas
			_ver(t2.size() == 5, "tandas 2 y 3b: Oportunista, Danza de acero, Molinete, Disparo perforante y Golpe de escudo (%s)" % str(t2))
			# EL OPORTUNISTA: salta a la espalda de su presa (la huella, un circulo pequeño delante) y le pega.
			for pr in [["oportunista", 30.0], ["danza_de_acero", 30.0]]:
				var hab: AbilityData = load("res://resources/abilities/%s.tres" % pr[0])
				# (en el centro de la arena: pegado a la pared, la linea de la Danza se corta en 4 px, como la tuya)
				_poner(t, fp, t._arena().rect.get_center())
				_poner(t, yo, t.pies_de(fp) + Vector2(-float(pr[1]), 0))
				fp.habilidades = [hab]
				fp.ability_cooldowns.clear()
				fp.retrasando = false
				fp.charging = null
				fp.current_energy = fp.max_energy
				var desde: Vector2 = t.pies_de(fp)
				log0 = combat.log_entero().size()
				# (las que se preparan salen al turno siguiente: hasta que la USA, como mucho tres turnos)
				for _turno in 3:
					await _turno_de(combat, t, fp, yo, yo.current_hp)
					nuevo = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
					if nuevo.contains("usa " + hab.nombre):
						break
				for _k in 60:
					await get_tree().process_frame
					t.tick(1.0 / 60.0)
				nuevo = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
				var anda: float = t.pies_de(fp).distance_to(desde)
				_ver(nuevo.contains("usa " + hab.nombre) and anda > 15.0, "%s: la usa y se mueve como la tuya (%.0f px; %s)" % [
					hab.nombre, anda, nuevo.left(110)])
			# (tanda 3a) LOS APOYOS, a SU bando (los bichos), y lo que se hace a si mismo.
			var cargar := func(n: String) -> AbilityData: return load("res://resources/abilities/%s.tres" % n)
			fp.abilities_combate = ["egida_menor", "grito_de_aliento", "purificar", "filo_emponzonado", "cambio_de_ritmo",
				"paso_ligero", "escolta"].map(func(n): return cargar.call(n))
			var t3: Array = combat.habilidades_florecido(fp).map(func(a): return a.nombre)
			fp.abilities_combate = guardadas
			_ver(t3.size() == 7, "tandas 3a y 3b: los apoyos, lo propio y la Escolta (%s)" % str(t3))
			_poner(t, fp, t._arena().rect.get_center())
			var suyos: Array = combat._enemies.filter(func(o): return o.is_alive() and o != fp)
			for k in suyos.size():
				_poner(t, suyos[k], t.pies_de(fp) + Vector2(25 + 12 * k, 20 * (k % 3) - 20))
				suyos[k].current_hp = suyos[k].max_hp
				suyos[k].limpiar_debuffs(99)
			for otro in combat._aliados:
				_poner(t, otro, t.pies_de(fp) + Vector2(-40, 0))
			var b: Combatant = suyos[0]
			# ÉGIDA MENOR: al que mas lo necesita de los suyos (el mas tocado), no a los tuyos.
			var egida: AbilityData = cargar.call("egida_menor")
			var id_egida: int = int(egida.efectos[0].estado)
			b.current_hp = b.max_hp * 0.2
			nuevo = await _usa_hasta(combat, t, fp, yo, egida)
			_ver(nuevo.contains("usa Égida menor") and b.has_status(id_egida) and not combat._aliados.any(func(a): return a.has_status(id_egida)),
				"Égida menor: al bicho mas tocado (%s), no a los tuyos (%s)" % [b.nombre, nuevo.left(110)])
			b.current_hp = b.max_hp
			# PURIFICAR: le quita lo malo a uno de los suyos (Lento: los micónidos son inmunes al veneno). Tiene que USARLA.
			b.apply_status(StatusEffects.Id.LENTO, 3, 1.0)
			_ver(b.has_status(StatusEffects.Id.LENTO), "(%s va Lento)" % b.nombre)
			nuevo = await _usa_hasta(combat, t, fp, yo, cargar.call("purificar"))
			_ver(nuevo.contains("usa Purificar") and not b.has_status(StatusEffects.Id.LENTO),
				"Purificar: la usa y le quita el Lento a %s (%s)" % [b.nombre, nuevo.left(90)])
			# GRITO DE ALIENTO: a los suyos de alrededor.
			var grito: AbilityData = cargar.call("grito_de_aliento")
			var id_grito: int = int(grito.efectos[0].estado)
			nuevo = await _usa_hasta(combat, t, fp, yo, grito)
			var con_grito: int = suyos.filter(func(o): return o.has_status(id_grito)).size()
			_ver(nuevo.contains("usa Grito de aliento") and con_grito >= 2 and not combat._aliados.any(func(a): return a.has_status(id_grito)),
				"Grito de aliento: a los suyos de alrededor (%d), no a los tuyos" % con_grito)
			# FILO EMPONZOÑADO: imbuye SU arma.
			var filo: AbilityData = cargar.call("filo_emponzonado")
			nuevo = await _usa_hasta(combat, t, fp, yo, filo)
			_ver(nuevo.contains("usa Filo emponzoñado") and fp.imbue_estado == filo.imbue_estado and fp.imbue_usos == filo.imbue_usos,
				"Filo emponzoñado: su arma puede envenenar %d ataques (%s)" % [fp.imbue_usos, nuevo.left(80)])
			# CAMBIO DE RITMO: pega y le recorta un turno la espera de las demas.
			var cambio: AbilityData = cargar.call("cambio_de_ritmo")
			fp.habilidades = [cambio, tajo]
			fp.ability_cooldowns.clear()
			fp.ability_cooldowns[tajo] = 4
			nuevo = await _usa_hasta(combat, t, fp, yo, cambio, false)
			_ver(nuevo.contains("usa Cambio de ritmo") and fp.ability_cd_left(tajo) <= 2,
				"Cambio de ritmo: recorta la espera del Tajo pesado (4 -> %d)" % fp.ability_cd_left(tajo))
			# PASO LIGERO: se planta junto a su presa y le pega.
			_poner(t, yo, t.pies_de(fp) + Vector2(-55, 0))
			var desde_p: Vector2 = t.pies_de(fp)
			var paso_l: AbilityData = cargar.call("paso_ligero")
			nuevo = await _usa_hasta(combat, t, fp, yo, paso_l)
			_ver(nuevo.contains("usa Paso ligero") and t.pies_de(fp).distance_to(desde_p) > 10.0,
				"Paso ligero: se planta junto a su presa (%.0f px)" % t.pies_de(fp).distance_to(desde_p))
			# (tanda 3b) LAS DEFENSAS. Tus golpes miran si el defiende, esta en guardia o cubre a otro.
			fp.abilities_combate = ["en_guardia", "postura_rodela", "muro_guardian", "voto_de_guardia", "muro_de_aliados",
				"guardia_rota", "escolta", "provocacion"].map(func(n): return cargar.call(n))
			var t3b: Array = combat.habilidades_florecido(fp).map(func(a): return a.nombre)
			fp.abilities_combate = guardadas
			_ver(t3b.size() == 8 and t3b.has("Provocación"), "tanda 3b y 4: las defensas y la Provocacion (%s)" % str(t3b))
			for k in suyos.size():
				suyos[k].current_hp = suyos[k].max_hp
				_poner(t, suyos[k], t.pies_de(fp) + Vector2(25 + 12 * k, 20 * (k % 3) - 20))
			_poner(t, yo, t.pies_de(fp) + Vector2(-30, 0))
			# EL GOLPE DE ESCUDO le deja DEFENDIENDO, y tus golpes de frente lo miran; al empezar su turno baja la guardia.
			nuevo = await _usa_hasta(combat, t, fp, yo, cargar.call("golpe_escudo_normal"))
			# Se planta mirando al que golpeo (no a ti): se mira contra los tuyos que tenga de frente.
			var de_frente: Array = combat._aliados.filter(func(a): return a.is_alive() and combat.enemigo_defiende(fp, a))
			_ver(nuevo.contains("usa Golpe de escudo") and bool(combat._defendiendo.get(fp, false)) and not de_frente.is_empty(),
				"Golpe de escudo: se queda defendiendo y tus golpes de frente lo notan (%s)" % ", ".join(de_frente.map(func(a): return a.nombre)))
			_ver(nuevo.contains(fp.nombre + " se queda en guardia") and not nuevo.contains("Causa se queda"),
				"y el registro lo dice con su nombre (%s)" % nuevo.right(70))
			fp.habilidades = []
			await _turno_de(combat, t, fp, yo, yo.current_hp)
			_ver(not bool(combat._defendiendo.get(fp, false)), "al empezar su turno baja la guardia")
			# EN GUARDIA: si esquiva tu golpe, te lo devuelve (sin entrenar a tu personaje: es tu ficha la que te pega).
			nuevo = await _usa_hasta(combat, t, fp, yo, cargar.call("en_guardia"))
			_ver(fp.en_guardia, "En guardia: se pone en postura (%s)" % nuevo.left(70))
			var exc0: String = str(pj_al.ability_internal) if pj_al != null else ""
			fp.evasion_bonus = 5.0
			var jugador_antes: Combatant = combat._player
			combat._player = yo
			var hp_c: float = yo.current_hp
			log0 = combat.log_entero().size()
			# A SU LADO (10/11): solo devuelve el golpe si te alcanza (CombatEnemigos._devuelve_en_guardia); tras los turnos
			# de antes puede haberse movido, y entonces la esquiva salia sin contraataque (bien hecho por el juego).
			_poner(t, yo, t.pies_de(fp) + Vector2(-20, 0))
			_ver(combat.turno_mapa.llega(fp, yo), "(estas a su alcance)")
			# La esquiva tiene TOPE (65 %): se repite el golpe hasta que lo esquive (sin postura no hay nada que mirar).
			var entro: bool = true
			for _int in 12:
				fp.current_hp = fp.max_hp
				entro = combat._golpe_basico(fp, 1.0, "", true, 0, "su arma", 1.0, Game.pj_de_combatant(yo))
				if not entro:
					break
			combat._player = jugador_antes
			nuevo = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
			_ver(not entro and (yo.current_hp < hp_c or nuevo.contains("contraataca")),
				"tu golpe lo esquiva en guardia y te lo devuelve (%s)" % nuevo.right(120))
			_ver(pj_al != null and str(pj_al.ability_internal) == exc0, "y a tu personaje florecido no le da excelia")
			fp.salir_de_guardia()
			# EL MURO: se pone delante de un bicho y tus golpes a ese bicho le llegan a el.
			var muro: AbilityData = cargar.call("muro_guardian")
			nuevo = await _usa_hasta(combat, t, fp, yo, muro)
			var cubierto: Combatant = fp.protegiendo_a
			_ver(nuevo.contains("usa Muro") and cubierto != null and cubierto.protegido_por == fp 				and combat.cobertura_enemiga(cubierto) == fp, "Muro: cubre a %s y tus golpes a el le llegan al florecido" % (
				cubierto.nombre if cubierto != null else "nadie"))
			combat.objetivos._romper_cobertura(fp)
			# EL VOTO DE GUARDIA: los suyos de la huella, en defensa.
			for o in suyos:
				combat._defendiendo.erase(o)
			nuevo = await _usa_hasta(combat, t, fp, yo, cargar.call("voto_de_guardia"))
			var en_def: int = suyos.filter(func(o): return bool(combat._defendiendo.get(o, false))).size()
			_ver(nuevo.contains("usa Voto de guardia") and en_def >= 1, "Voto de guardia: %d de los suyos en defensa" % en_def)
			# LA ESCOLTA: sigue a un bicho y entra detras cuando el pega.
			nuevo = await _usa_hasta(combat, t, fp, yo, cargar.call("escolta"))
			var seguido: Combatant = fp.escoltando_a
			_ver(nuevo.contains("usa Escolta") and seguido != null and fp.has_status(StatusEffects.Id.ESCOLTA),
				"Escolta: sigue a %s" % (seguido.nombre if seguido != null else "nadie"))
			if seguido != null and seguido.is_alive():
				_poner(t, yo, t.pies_de(seguido) + Vector2(-22, 0))
				seguido.habilidades = []
				seguido.prob_habilidad = 0.0
				var log_s: int = combat.log_entero().size()
				for _turno in 3:
					await _turno_de(combat, t, seguido, yo, yo.current_hp)
					if combat.log_entero().slice(log_s).any(func(l): return str(l).contains("entra detrás")):
						break
				nuevo = " | ".join(combat.log_entero().slice(log_s).map(func(l): return str(l)))
				_ver(nuevo.contains("entra detrás"), "cuando %s te pega, el entra detras (%s)" % [seguido.nombre, nuevo.left(140)])
			# LA GUARDIA ROTA: tajo y escudazo, cada uno a los suyos.
			_poner(t, yo, t.pies_de(fp) + Vector2(-25, 0))
			nuevo = await _usa_hasta(combat, t, fp, yo, cargar.call("guardia_rota"))
			_ver(nuevo.contains("usa Guardia rota"), "Guardia rota: la usa (%s)" % nuevo.left(100))
			# (10/11, TANDA 4) SU PROVOCACION: los tuyos que pille quedan con el OBJETIVO FIJADO en el.
			await _tanda4_provocacion(combat, t, fp, yo, cargar)
			# (10/11, FASE 3) SUS MAGIAS: recita tantos turnos como frases y las suelta.
			await _fase3_magias(combat, t, fp, yo)
			# LO TUMBAS: su muñeco vuelve a caer (no se desvanece como un bicho).
			fp.take_damage(fp.current_hp + 10.0)
			t.morir_en_mapa(fp)
			_ver(cu_a != null and cu_a.has_meta(t.MARCA_CAIDO) and cu_a.modulate.a > 0.9,
				"al tumbarlo, el muñeco vuelve a caer (sin desvanecerse)")

	print("6) EL ELEMENTO EXPLICITO")
	# La campana no lleva elemento en la ficha; se le pone uno de mentira: una habilidad sin elemento escrito no lo usa.
	campana.elemento_ataque = Elementos.Elemento.FUEGO
	var visto: Array = []
	var micelio: AbilityData = load("res://resources/abilities/miconido_micelio.tres")
	var antes_el: int = campana.elemento_ataque
	visto.append(micelio.elemento_golpe)
	_ver(micelio.elemento_golpe < 0 and antes_el == Elementos.Elemento.FUEGO, "(el micelio no lleva elemento escrito)")
	var esc: AbilityData = load("res://resources/abilities/slime_escupitajo_brasas.tres")
	_ver(esc.elemento_golpe == Elementos.Elemento.FUEGO, "el Escupitajo de brasas lo lleva escrito: fuego")
	var tor: AbilityData = load("res://resources/abilities/tormentosa_red.tres")
	_ver(tor.elemento_golpe == Elementos.Elemento.RAYO, "la Red electrificada, rayo")
	var expl: AbilityData = load("res://resources/abilities/arana_explosion.tres")
	var rd: AbilityData = load("res://resources/abilities/rata_destello.tres")
	_ver(expl.elemento_golpe == Elementos.Elemento.FUEGO and rd.elemento_golpe == Elementos.Elemento.OSCURIDAD,
		"Explosion de brasas de fuego y el Destello de la rata de oscuridad")

	print("7) EL SET CONTAGIO (la runa del micónido)")
	var set_c: RunaSetData = Runas.set_por_id(&"miconido")
	_ver(set_c != null and set_c.efecto == &"contagio" and is_equal_approx(float(set_c.params["radio"]), 40.0)
		and is_equal_approx(float(set_c.params["prob"]), 0.6), "el set Contagio carga con sus numeros (40 y 60 %)")
	_ver(set_c != null and Runas.efecto_txt(set_c).contains("60 %"), "su texto: %s" % (Runas.efecto_txt(set_c) if set_c != null else "-"))
	var md: EnemyData = load("res://scenes/actors/enemy/miconido.tres")
	_ver(md.drop_runa != null and md.drop_runa.id == &"runa_miconido", "el micónido suelta su runa")
	# (los micónidos son inmunes al Veneno: con las ratas, que se envenenan)
	var vivas: Array = combat._enemies.filter(func(o: Combatant) -> bool: return o.is_alive() and not o.es_inmune(StatusEffects.Id.VENENO))
	# Con dos que se envenenen basta: el que cae vuelve a ponerse en pie para el paso siguiente.
	if vivas.size() >= 2:
		var r1: Combatant = vivas[0]
		var r2: Combatant = vivas[1]
		var cont_de_pie := func(r: Combatant) -> void:
			r.current_hp = r.max_hp
			r.statuses.clear()
			if r.has_meta(&"contagio_hecho"):
				r.remove_meta(&"contagio_hecho")
		var cont_caer := func(r: Combatant) -> void:
			r.apply_status(StatusEffects.Id.VENENO)
			r.take_damage(r.current_hp + 10.0)
		combat._player = yo
		yo.runa_contagio_radio = 40.0
		# (con 10 y no con su 60 %: la tirada no puede fallar; lo que se mira es A QUIEN llega la nube)
		yo.runa_contagio_prob = 10.0
		cont_de_pie.call(r1)
		cont_de_pie.call(r2)
		_poner(t, r1, t.pies_de(yo) + Vector2(60, 0))
		_poner(t, r2, t.pies_de(r1) + Vector2(0, 200))
		cont_caer.call(r1)
		combat._contagio(r1, yo)
		_ver(not r2.has_status(StatusEffects.Id.VENENO), "la nube no llega al de lejos")
		var n_log: int = combat._log_lines.size()
		combat._contagio(r1, yo)
		_ver(combat._log_lines.size() == n_log, "una sola vez por muerto")
		cont_de_pie.call(r1)
		_poner(t, r2, t.pies_de(r1) + Vector2(30, 0))
		cont_caer.call(r1)
		combat._contagio(r1, yo)
		_ver(r2.has_status(StatusEffects.Id.VENENO), "al caer envenenado, la nube envenena al de al lado")
		# EN CADENA: el que envenena la nube, al caer a tus manos, revienta igual (sobre el primero, de pie otra vez)
		cont_de_pie.call(r1)
		r2.take_damage(r2.current_hp + 10.0)
		combat._contagio(r2, yo)
		_ver(r1.has_status(StatusEffects.Id.VENENO), "en cadena: el que envenena la nube tambien revienta")
		cont_de_pie.call(r1)
		cont_de_pie.call(r2)
		yo.runa_contagio_prob = 0.0
		cont_caer.call(r1)
		combat._contagio(r1, yo)
		_ver(not r2.has_status(StatusEffects.Id.VENENO), "sin el set, nada")
		cont_de_pie.call(r1)
		cont_de_pie.call(r2)
	else:
		_ver(false, "quedan dos enemigos que se envenenan para probar el Contagio (%d)" % vivas.size())


# Le deja SOLO esa habilidad (con 'sola') y energia llena, y juega sus turnos hasta que la USA (las que se preparan salen al
# turno siguiente; como mucho tres). Devuelve el registro de esos turnos.
# (10/11) LOS EFECTOS DEL MICONIDO EN PIXEL: cada uno, segun quien ataca, lanza su hoja (miconido_efectos_horno.py).
func _efectos_pixel(t, campana: Combatant, florecido: Combatant, yo: Combatant) -> void:
	var arena: Node = t._arena()
	var cuenta := func(nombre: String) -> int:
		return arena.get_children().filter(func(n): return n is EfectoPixel and String(n.get_meta("hoja", "")) == nombre).size()
	var casos: Array = [
		[campana, CombatFX.Estilo.SIMA_PORRAZO, "filamentos_golpe"], [florecido, CombatFX.Estilo.SIMA_PORRAZO, "tajo_golpe"],
		[campana, CombatFX.Estilo.SIMA_TOS, "tos_luz"], [florecido, CombatFX.Estilo.SIMA_TOS, "tos_seta"],
		[florecido, CombatFX.Estilo.SIMA_ESTOCADA, "estocada_golpe"], [campana, CombatFX.Estilo.SIMA_DESTELLO, "destello_golpe"],
		[campana, CombatFX.Estilo.SIMA_ATRAE, "atrae"]]
	for caso in casos:
		var n0: int = cuenta.call(caso[2])
		t._miconido_pixel(arena, caso[1], caso[0], yo, 0.0, 1.0)
		_ver(cuenta.call(caso[2]) > n0, "%s: %s, en pixel" % [(caso[0] as Combatant).nombre, caso[2]])
	var c0: int = arena.get_children().filter(func(n): return n is CintaPixel).size()
	t._miconido_pixel(arena, CombatFX.Estilo.SIMA_LATIGO, campana, yo, 0.0, 1.0)
	_ver(arena.get_children().filter(func(n): return n is CintaPixel).size() > c0, "el Latigazo de micelio: su cordon, en pixel")
	# LOS GESTOS: la estela de la espada, los filamentos, la carga y el cono del Destello
	var gestos: Array = [[florecido, "embestida", "tajo"], [florecido, "estocada", "estocada"], [campana, "embestida", "filamentos"],
		[campana, "destello_carga", "campana_destello_carga"], [florecido, "destello_carga", "florecido_destello_carga"]]
	for g in gestos:
		var n1: int = cuenta.call(g[2])
		t._pixel.al_gesto(g[0], t.cuerpo_de(g[0]), g[1], 0.6)
		_ver(cuenta.call(g[2]) > n1, "%s, gesto '%s': %s" % [(g[0] as Combatant).nombre, g[1], g[2]])
	# (10/11) EL DESTELLO ES UN FOCO: su cono de luz lo pinta su SUELO con la forma del golpe (FocoAire), no una hoja en el aire
	var des_f: AbilityData = load("res://resources/abilities/miconido_destello.tres")
	_ver(des_f.suelo_roto == SueloRoto.Tipo.MICONIDO_FOCO, "el Destello lleva su foco en el suelo (MICONIDO_FOCO)")
	var cono_f := CombatFormas.cono(t.pies_de(campana), (t.pies_de(yo) - t.pies_de(campana)).normalized(), des_f.forma_radio, des_f.forma_apertura)
	var foco: Node2D = SueloRoto.lanzar(arena, cono_f, des_f.suelo_roto, 1, 0.0, 0.0)
	_ver(foco != null and foco.get_parent() == arena, "el foco del Destello sale en la arena")
	_ver(is_equal_approx(SueloRoto.retraso(cono_f, cono_f.origen + cono_f.dir * des_f.forma_radio, des_f.suelo_roto), 0.22),
		"y al borde del cono el golpe llega cuando llega la luz (0,22 s)")
	# LA NUBE QUE SE QUEDA: la del venenoso (PiezaPixel), teñida
	_ver(ResourceLoader.exists("res://assets/sprites/efectos/miconido/atado_dura_a.png"), "el atado de micelio horneado")
	for _k in 30:
		await get_tree().process_frame
		t.tick(1.0 / 60.0)


# (10/11) TANDA 4: la Provocacion de tu personaje florecido. Provoca a los tuyos que pille; mientras dure, lo que lancen
# contra enemigos tiene que alcanzarle a EL (el basico va a el; un area, con el dentro); curar, libre; baja en sus turnos;
# viaja a tu pantalla (campo 14 de la instantanea) y la sala lo vuelve a mirar.
func _tanda4_provocacion(combat: Node, t, fp: Combatant, yo: Combatant, cargar: Callable) -> void:
	var otro: Combatant = null
	for a in combat._enemies:
		if a != fp and a.is_alive():
			otro = a
			break
	_poner(t, yo, t.pies_de(fp) + Vector2(-25, 0))
	if otro != null:
		_poner(t, otro, t.pies_de(fp) + Vector2(260, 0))
	fp.salir_de_guardia()
	var nuevo: String = await _usa_hasta(combat, t, fp, yo, cargar.call("provocacion"))
	_ver(nuevo.contains("usa Provocación") and fp.provocar_turnos == 3 and fp.provocados.has(yo),
		"Provocación: %s provocado 3 turnos (%s)" % [yo.nombre, nuevo.right(110)])
	_ver(nuevo.contains(fp.nombre + " provoca a"), "y el registro lo dice con su nombre")
	_ver(combat.objetivos.provocador_mio(yo) == fp, "a %s le provoca %s" % [yo.nombre, fp.nombre])
	var chips: Array = combat.efectos._chips_de(yo)
	_ver(chips.any(func(ch): return String(ch[0]).begins_with("💢")), "y lleva el icono de provocado")
	# EL BASICO: tu objetivo es el, y no te deja elegir a otro.
	var jug: Combatant = combat._player
	combat._player = yo
	if otro != null:
		combat.figuras._seleccionar(combat._enemies.find(otro))
	_ver(combat._objetivo() == fp, "tu basico va a por el (objetivo %s)" % combat._objetivo().nombre)
	# UN AREA: solo si el queda dentro de la huella.
	# (una con HUELLA: el Tajo pesado va a tu objetivo, que ya es el)
	var tajo: AbilityData = load("res://resources/abilities/aplastamiento.tres")
	t._quien = yo
	t.apunte = t.pies_de(fp)
	t._hay_apunte = true
	_ver(t.bloqueo_provocado(tajo, yo) == "", "un Aplastamiento hacia el: vale")
	if otro != null:
		# al otro lado de ti: el area hacia alli ya no pilla al florecido
		_poner(t, otro, t.pies_de(yo) + Vector2(-120, 0))
		t.apunte = t.pies_de(otro)
		var rep: Array = t.reparto_habilidad(tajo, yo).map(func(o): return o["c"])
		_ver(not rep.has(fp) and t.bloqueo_provocado(tajo, yo) != "",
			"un Aplastamiento hacia otro, sin el dentro: no deja (%s)" % t.bloqueo_provocado(tajo, yo))
	# UN HECHIZO DE DAÑO, igual; una CURA, libre.
	var bola: SpellData = load("res://resources/spells/bola_fuego.tres")
	t.apunte = t.pies_de(fp)
	_ver(t.bloqueo_provocado(null, yo, bola) == "", "una bola de fuego encima de el: vale")
	t.apunte = t.pies_de(yo) + Vector2(-400, 300)
	_ver(t.bloqueo_provocado(null, yo, bola) != "", "una bola de fuego lejos de el: no deja")
	var cura: AbilityData = AbilityData.new()
	cura.forma = 1
	cura.forma_apunte = 2
	cura.forma_a_aliados = true
	_ver(t.bloqueo_provocado(cura, yo) == "", "lo que va a los tuyos: libre")
	# LA SALA: si le llega una habilidad que no le pilla, pega su basico a el (sin perder el turno).
	_ver(combat.espejo._provocado_no_deja("", "habilidad", 0) == false, "(la sala deja pasar lo que vale)")
	# A TU PANTALLA (espejo): el campo 14 de la instantanea dice quien te provoca.
	var vals: Array = combat.espejo._valores(combat._aliados, true)
	var iy: int = combat._aliados.find(yo)
	_ver(iy >= 0 and int(vals[iy][14]) == combat._enemies.find(fp), "viaja a tu pantalla: el campo 14 lleva a %s" % fp.nombre)
	yo.provocador_remoto = combat._enemies.find(fp)
	var guarda: Array = fp.provocados.duplicate()
	fp.provocados.clear()
	_ver(combat.objetivos.provocador_mio(yo) == fp, "y en el espejo (sin provocados) se lee del campo 14")
	fp.provocados = guarda
	yo.provocador_remoto = -2
	combat._player = jug
	# BAJA EN SUS TURNOS y al acabarse quedas libre.
	fp.habilidades = []
	for _k in 3:
		await _turno_de(combat, t, fp, yo, yo.current_hp)
	_ver(fp.provocar_turnos == 0 and fp.provocados.is_empty() and combat.objetivos.provocador_mio(yo) == null,
		"a los 3 turnos suyos se acaba y quedas libre (%d)" % fp.provocar_turnos)


# (10/11) FASE 3: las magias de tu personaje florecido, hechas acciones suyas (CombatPantalla.habilidad_de_hechizo).
func _fase3_magias(combat: Node, t, fp: Combatant, yo: Combatant) -> void:
	fp.salir_de_guardia()
	fp.imbue_usos = 0
	if fp.max_mp < 200.0:
		fp.max_mp = 200.0
	_poner(t, yo, t.pies_de(fp) + Vector2(-40, 0))
	# 1) UN HECHIZO DE ATAQUE: Bola de fuego
	var bola: SpellData = load("res://resources/spells/bola_fuego.tres")
	var hb: AbilityData = combat.habilidad_de_hechizo(bola)
	_ver(hb != null and hb.es_magico and hb.carga_turnos == bola.longitud() and hb.dano_mult > 0.0,
		"Bola de fuego: recita %d turnos (sus %d frases), magica y de daño" % [hb.carga_turnos, bola.longitud()])
	fp.current_mp = fp.max_mp
	var mp0: float = fp.current_mp
	var hp0: float = yo.current_hp
	var vida_tuyos0: float = combat._aliados.reduce(func(acc, a): return acc + a.current_hp, 0.0)
	var nuevo: String = await _lanza_hasta(combat, t, fp, yo, hb, bola.longitud() + 6)
	_ver(nuevo.contains("empieza a recitar " + bola.nombre), "empieza a recitar %s y lo dice" % bola.nombre)
	_ver(_circulo_visto, "mientras recita, su circulo magico a sus pies")
	_ver(is_equal_approx(_mp_al_empezar, mp0 - float(bola.coste_mana)), "y paga su mana al empezar (%.0f -> %.0f, coste %d)" % [
		mp0, _mp_al_empezar, bola.coste_mana])
	# (es DISPERSA: sus bolas caen al azar en la zona; a alguno de los tuyos le da)
	var vida_tuyos1: float = combat._aliados.reduce(func(acc, a): return acc + a.current_hp, 0.0)
	_ver(nuevo.contains(bola.nombre) and vida_tuyos1 < vida_tuyos0,
		"al acabar de recitar la suelta y os pega (%.0f de vida menos entre los tuyos)" % (vida_tuyos0 - vida_tuyos1))
	# LOS DE VERDAD: la Descarga salta en CADENA entre los tuyos (como contra los bichos)
	var desc: SpellData = load("res://resources/spells/descarga.tres")
	var hdesc: AbilityData = combat.habilidad_de_hechizo(desc)
	var los_mios: Array = combat._aliados.filter(func(a): return a.is_alive())
	for k in los_mios.size():
		_poner(t, los_mios[k], t.pies_de(fp) + Vector2(-40 - 22 * k, 10 * k))
	var vidas: Array = los_mios.map(func(a): return a.current_hp)
	fp.current_mp = fp.max_mp
	nuevo = await _lanza_hasta(combat, t, fp, yo, hdesc, desc.longitud() + 6)
	var heridos: int = 0
	for k in los_mios.size():
		if los_mios[k].current_hp < float(vidas[k]):
			heridos += 1
	_ver(heridos >= 2, "Descarga: salta entre los tuyos (%d heridos): %s" % [heridos, nuevo.right(120)])
	# el TIRON del Chorro de agua te arrastra
	var chorro: SpellData = load("res://resources/spells/chorro_agua.tres")
	var hch: AbilityData = combat.habilidad_de_hechizo(chorro)
	# (los demas, lejos: el empuje se para contra un cuerpo, como contra un bicho)
	for k in los_mios.size():
		if los_mios[k] != yo:
			_poner(t, los_mios[k], t.pies_de(fp) + Vector2(-260, -60 * k))
	# hacia el centro de la arena (con pared detras se para, como contra un bicho)
	var al_centro: Vector2 = (t._arena().global_position - t.pies_de(fp)).normalized() if t._arena() != null else Vector2.DOWN
	if al_centro.length() < 0.5:
		al_centro = Vector2.DOWN
	_poner(t, yo, t.pies_de(fp) + al_centro * 60.0)
	var donde0: Vector2 = t.pies_de(yo)
	fp.current_mp = fp.max_mp
	nuevo = await _lanza_hasta(combat, t, fp, yo, hch, chorro.longitud() + 6)
	var movido: float = t.pies_de(yo).distance_to(donde0)
	# (sin ventana el gesto no llega a verse: el empuje arranca a los T_TIRON_ESPERA s de margen)
	for _k in 240:
		await get_tree().process_frame
		t.tick(1.0 / 60.0)
		movido = maxf(movido, t.pies_de(yo).distance_to(donde0))
	_ver(nuevo.contains(chorro.nombre) and movido > 8.0,
		"%s: te empuja (%.0f px): %s" % [chorro.nombre, movido, nuevo.right(100)])
	# sin mana, no la elige
	fp.current_mp = 0.0
	_ver(combat.enemigos._le_llega_el_mana(fp, hb) == false, "sin mana no la puede recitar")
	# 2) UNA CURA A LOS BICHOS: Vendaje de luz
	var vend: SpellData = load("res://resources/spells/vendaje_de_luz.tres")
	var hv: AbilityData = combat.habilidad_de_hechizo(vend)
	var herido: Combatant = null
	for o in combat._enemies:
		if o != fp and o.is_alive():
			herido = o
			break
	_ver(hv.forma_a_aliados and herido != null, "Vendaje de luz: va a los suyos (los bichos)")
	if herido != null:
		_poner(t, herido, t.pies_de(fp) + Vector2(30, 0))
		herido.current_hp = herido.max_hp * 0.3
		var hh0: float = herido.current_hp
		fp.current_mp = fp.max_mp
		nuevo = await _lanza_hasta(combat, t, fp, yo, hv, vend.longitud() + 3)
		_ver(herido.current_hp > hh0, "cura a %s (%.0f -> %.0f): %s" % [herido.nombre, hh0, herido.current_hp, nuevo.right(90)])
	# 3) UN DEBILITAMIENTO: Debilidad, a los tuyos
	var deb: SpellData = load("res://resources/spells/debilidad.tres")
	var hd: AbilityData = combat.habilidad_de_hechizo(deb)
	_ver(not hd.forma_a_aliados and hd.dano_mult == 0.0, "Debilidad: va a los tuyos, sin daño")
	# 4) SU FILO: a si mismo
	var filo: SpellData = load("res://resources/spells/filo_ardiente.tres")
	var hf: AbilityData = combat.habilidad_de_hechizo(filo)
	fp.current_mp = fp.max_mp
	fp.imbue_usos = 0
	nuevo = await _lanza_hasta(combat, t, fp, yo, hf, filo.longitud() + 3)
	_ver(fp.imbue_usos > 0 and nuevo.contains("se imbuye"), "Filo ardiente: se imbuye el arma (%d ataques): %s" % [
		fp.imbue_usos, nuevo.right(90)])
	_ver(combat.enemigos._le_llega_el_mana(fp, hf) == false, "y con el filo puesto no lo repite")
	fp.habilidades = []
	fp.imbue_usos = 0


var _circulo_visto: bool = false
var _mp_al_empezar: float = -1.0

# Sus turnos hasta que suelte 'ab' (la recita: sus turnos de carga y el de soltarla).
func _lanza_hasta(combat: Node, t, e: Combatant, yo: Combatant, ab: AbilityData, turnos: int) -> String:
	e.habilidades = [ab]
	e.ability_cooldowns.clear()
	e.retrasando = false
	e.charging = null
	var log0: int = combat.log_entero().size()
	_circulo_visto = false
	var empezo: bool = false
	for _turno in turnos:
		await _turno_de(combat, t, e, yo, yo.current_hp)
		for _k in 6:
			await get_tree().process_frame
			t.tick(1.0 / 60.0)
		if e.charging == ab:
			if not empezo:
				_mp_al_empezar = e.current_mp
			empezo = true
			if t._circulos.has(e) and is_instance_valid(t._circulos[e]):
				_circulo_visto = true
		var txt: String = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
		if txt.contains("usa " + ab.nombre) or (empezo and e.charging == null):
			break
	for _k in 40:
		await get_tree().process_frame
		t.tick(1.0 / 60.0)
	return " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))


func _usa_hasta(combat: Node, t, e: Combatant, yo: Combatant, ab: AbilityData, sola: bool = true) -> String:
	if sola:
		e.habilidades = [ab]
		e.ability_cooldowns.clear()
	e.retrasando = false
	e.charging = null
	e.current_energy = e.max_energy
	var log0: int = combat.log_entero().size()
	var txt: String = ""
	for _turno in 3:
		await _turno_de(combat, t, e, yo, yo.current_hp)
		txt = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
		if txt.contains("usa " + ab.nombre):
			break
	for _k in 40:
		await get_tree().process_frame
		t.tick(1.0 / 60.0)
	return " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))


# Un turno suyo entero en el mapa: hasta que su accion sale en el registro (o pasan 5 s). (09/11: antes esperaba a que te
# bajara la vida, y si fallaba se quedaba los 5 s y en ese rato la barra le daba OTRO turno: un basico de mas.)
func _turno_de(combat: Node, t, e: Combatant, yo: Combatant, _hp_antes: float) -> void:
	var log0: int = combat.log_entero().size()
	combat._state = combat.State.ADVANCING
	t.turno_enemigo(e)
	for _i in 300:
		await get_tree().process_frame
		t.tick(1.0 / 60.0)
		if combat.log_entero().slice(log0).any(func(l): return str(l).contains(e.nombre)):
			break
	for _i in 30:
		await get_tree().process_frame
		t.tick(1.0 / 60.0)


func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position
