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
			_ver(filtradas == [tajo], "de su arma toma el Tajo pesado (golpe limpio) y aun no la Provocacion (%s)" % str(
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
				await _turno_de(combat, t, fp, yo, yo.current_hp)
				nuevo = " | ".join(combat.log_entero().slice(log0).map(func(l): return str(l)))
				_ver(nuevo.contains("Tajo pesado") and is_equal_approx(fp.current_energy, en_antes),
					"al volver a la barra lo suelta, sin gastar mas (%s)" % nuevo.left(120))
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
			_ver(t2.size() == 4 and not t2.has("Golpe de escudo"),
				"tanda 2: Oportunista, Danza de acero, Molinete y Disparo perforante si; el Golpe de escudo aun no (%s)" % str(t2))
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


# Un turno suyo entero en el mapa (hasta que pega o pasan 5 s).
func _turno_de(combat: Node, t, e: Combatant, yo: Combatant, hp_antes: float) -> void:
	combat._state = combat.State.ADVANCING
	t.turno_enemigo(e)
	for _i in 300:
		await get_tree().process_frame
		t.tick(1.0 / 60.0)
		if yo.current_hp < hp_antes and int(combat._state) != int(combat.State.ADVANCING):
			break
	for _i in 30:
		await get_tree().process_frame
		t.tick(1.0 / 60.0)


func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position
