# PRUEBA (25/11): LAS MECANICAS NUEVAS DEL ARBOL DEL ESTOQUE, en una pelea tactica de verdad en su sala. Tres enemigos
# delante de quien tenga el turno (cada seccion los vuelve a colocar) y las habilidades montadas con sus nodos:
#   ESTOCADA PENETRANTE  de serie a los tres, Ensartar, Desequilibrio, Herida que se abre, Estocada doble
#   PASO LIGERO          Pasar cortando, Al costado, Ida y vuelta, Encadenar, Paso que despista, Presteza mayor,
#                        Recobrar aliento, Paso de guardia
#   PUNZADA AL NERVIO    Cadena nerviosa, Temblor, Clavado, Sobre lo tocado, Leña al caido
#   EN GUARDIA           quita la prisa, Reto, Respiro, Paciencia, Guardia que no cae, Ojos en la espalda, Salir al paso
#   FINTAS / DANZA       Leer la guardia, Sin guardia, Herida en cruz, Bailar esquivando
#   godot --headless --path . res://tools/prueba_arbol_estoque.tscn
extends Node

const Mejoras = preload("res://scripts/core/mejoras.gd")
const HAB := "res://resources/abilities/%s.tres"

var sala
var combat: Node = null
var t = null
var es: Array = []
var lado := Vector2.LEFT
var centro := Vector2.ZERO
var _mal := 0


func _ready() -> void:
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


func _montar(hab: String, ids: Array) -> AbilityData:
	var base: AbilityData = load(HAB % hab)
	return Mejoras.montar_sin_nombre(base, (base.arbol as Array).filter(func(n): return ids.has(String(n.id)))) as AbilityData


# EL SIGUIENTE TURNO de uno de los tuyos (el que sea): espera a que acaben los efectos y llegue, y le llena la energia.
func _turno() -> Combatant:
	await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 10.0)
	await _esperar_a(func() -> bool: return t._deslices.is_empty(), 5.0)
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 30.0):
		print("MAL: no llego un turno de los tuyos")
		return null
	var yo: Combatant = combat._player
	yo.max_energy = 1000.0
	yo.current_energy = 1000.0
	yo.salir_de_guardia()
	yo.statuses.clear()
	yo.descuento_hab = 0.0
	return yo


# 'yo' en el centro y los tres enemigos hacia 'lado', a 'seps' px de hueco del cuerpo de 'yo' (y 'fuera' px de lado).
func _colocar(yo: Combatant, seps: Array, fuera: Array = [0.0, 0.0, 0.0]) -> void:
	t._colocar(yo, t.cuerpo_de(yo), centro - Vector2(0, PoseJugador.PIES_BAJO_NODO))
	var arriba := lado.orthogonal()
	for i in 3:
		var e: Combatant = es[i]
		var pe: Vector2 = centro + lado * (t.radio_pisa(yo) + t.radio_pisa(e) + float(seps[i])) + arriba * float(fuera[i])
		t._colocar(e, t.cuerpo_de(e), pe - (t.pies_de(e) - t.pos_de(e)))
		e.statuses.clear()
		e.current_hp = e.max_hp
		e.en_guardia = false
	await _esperar(3)


func _lanzar(ab: AbilityData, punto: Vector2) -> void:
	combat._state = combat.State.WAITING_PLAYER
	t.anotar_apunte([punto.x, punto.y])
	combat.habilidades._usar_habilidad(ab, true)


func _estado(c: Combatant, id: int):
	return c.get_status(id)


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_arbol_estoque", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	for i in 3:
		sala.poner("res://scenes/actors/enemy/guardian_rango.tres", Vector2(-220 - 40 * i, 70), {})
	await _esperar(25)
	if not (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false) != null):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(5)
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico or combat._enemies.size() < 3:
		print("MAL: la pelea no es tactica o no estan los tres")
		get_tree().quit(1)
		return
	t = combat.turno_mapa
	es = combat._enemies.slice(0, 3)
	for c in combat._aliados + es:
		c.max_hp = 9999999.0
		c.current_hp = 9999999.0
	print("    enemigos: %s" % str(es.map(func(e): return e.nombre)))
	centro = t._arena().rect.get_center()
	lado = Vector2.LEFT if t._en_arena(centro + Vector2(-200, 0)) else Vector2.RIGHT
	# los demas de los tuyos, lejos al otro lado
	for i in combat._aliados.size():
		var o: Combatant = combat._aliados[i]
		t._colocar(o, t.cuerpo_de(o), centro - lado * 160.0 + Vector2(0, -60 + 50 * i) - Vector2(0, PoseJugador.PIES_BAJO_NODO))
	await _estocada()
	await _paso()
	await _punzada()
	await _guardia()
	await _fintas_y_danza()
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


# ------------------------------------------------------------ ESTOCADA PENETRANTE
func _estocada() -> void:
	print("--- ESTOCADA PENETRANTE")
	var yo: Combatant = await _turno()
	await _colocar(yo, [12.0, 38.0, 64.0])
	var punta: Vector2 = t.pies_de(es[2]) + lado * 10.0
	t.anotar_apunte([punta.x, punta.y])
	var base_rep: Array = t.reparto_habilidad(_montar("estocada_penetrante", []), yo)
	_ver(base_rep.size() == 3 and base_rep.all(func(o): return is_equal_approx(float(o["escala"]), 1.0)),
		"de serie, la linea pega entera a los tres")
	var esc_de := {}
	for o in t.reparto_habilidad(_montar("estocada_penetrante", ["atravesar", "ensartar"]), yo):
		esc_de[o["c"]] = float(o["escala"])
	_ver(is_equal_approx(esc_de.get(es[0], 0.0), 1.0) and is_equal_approx(esc_de.get(es[1], 0.0), 1.15)
		and is_equal_approx(esc_de.get(es[2], 0.0), 1.3), "Ensartar: el 1o entero, el 2o +15 %, el 3o +30 %")
	var ab: AbilityData = _montar("estocada_penetrante", ["atravesar", "ensartar", "desequilibrio", "herida_se_abre"])
	ab.crit_extra = 5.0
	ab.efectos_prob_mult = 10.0
	ab.infalible = true   # (que no se esquive ninguno: se mira la barra de los tres)
	var barra0: Array = es.map(func(e): return float(combat._gauge.get(e, 0.0)))
	_lanzar(ab, punta)
	var barra1: Array = es.map(func(e): return float(combat._gauge.get(e, 0.0)))
	_ver(range(3).all(func(i): return float(barra1[i]) > float(barra0[i]) + 1.0),
		"Desequilibrio: el critico echa atras en la barra a los tres")
	var de_serie: int = int(StatusEffects.def(StatusEffects.Id.VULNERABLE).get("turns", 1))
	var con_v: Array = es.filter(func(e): return _estado(e, StatusEffects.Id.VULNERABLE) != null)
	print("    Vulnerable en %d de 3 (prob con techo del 95 %%)" % con_v.size())
	_ver(not con_v.is_empty() and con_v.all(func(e): return int(_estado(e, StatusEffects.Id.VULNERABLE).turns) == de_serie + 2),
		"Herida que se abre: el Vulnerable dura 2 turnos mas")

	yo = await _turno()
	var d: AbilityData = _montar("estocada_penetrante", ["sin_armadura", "corazon", "grieta", "estocada_doble"])
	d.crit_extra = -5.0
	d.infalible = true
	await _colocar(yo, [12.0, 38.0, 64.0])
	var hp0: float = es[0].current_hp
	_lanzar(d, t.pies_de(es[2]) + lado * 10.0)
	_ver(d.golpes_max == 2 and hp0 - es[0].current_hp > 0.0, "Estocada doble: dos golpes y pegan")


# ------------------------------------------------------------ PASO LIGERO
func _paso() -> void:
	print("--- PASO LIGERO")
	# PASAR CORTANDO: el de la estocada entero; los que cruza el paso, al 30 %.
	var yo: Combatant = await _turno()
	await _colocar(yo, [4.0, 40.0, 300.0], [0.0, 0.0, 80.0])   # con hueco detras del 2o, donde caer
	var lejos: Vector2 = t.pies_de(yo) + lado * 200.0
	t.anotar_apunte([lejos.x, lejos.y])
	var corte: AbilityData = _montar("paso_ligero", ["paso_largo", "al_costado", "pasar_cortando"])
	corte.forma_rango = 170.0   # que caiga pasado el 2o (sus cajas son anchas)
	var esc := {}
	for o in t.reparto_habilidad(corte, yo):
		esc[o["c"]] = float(o["escala"])
	print("    Pasar cortando: %s" % str(es.map(func(e): return esc.get(e, -1.0))))
	var plan_c: Dictionary = t.plan_paso(corte, yo)
	print("    plan: modo %d, de %s a %s; bultos %s" % [int(plan_c["modo"]), str(t.pies_de(yo)), str(Vector2(plan_c["hasta"]) + t._bajo_de(yo)),
		str(es.map(func(e): return t.bulto_de(e)))])
	_ver(is_equal_approx(esc.get(es[0], 0.0), 1.0) and is_equal_approx(esc.get(es[1], 0.0), 0.3),
		"Pasar cortando: el de la estocada entero, el que cruzas al 30 %")
	_ver(not esc.has(es[2]) or is_equal_approx(esc[es[2]], 0.3), "y al que no cruzas, nada")

	# AL COSTADO: de cara, no; de espaldas, si.
	t._pies_golpe.erase(yo)
	t.cuerpo_de(es[0]).set("_facing", -lado)
	_ver(not t.golpe_de_costado(yo, es[0]), "Al costado: si te mira, no cuenta")
	t.cuerpo_de(es[0]).set("_facing", lado)
	_ver(t.golpe_de_costado(yo, es[0]), "Al costado: de espaldas, si")
	t.cuerpo_de(es[0]).set("_facing", lado.orthogonal())
	_ver(t.golpe_de_costado(yo, es[0]), "Al costado: de lado, si")

	# IDA Y VUELTA + ENCADENAR + PRESTEZA MAYOR: el enemigo a 50 px (paso ANTES), al acabar vuelves a tu sitio.
	var ida: AbilityData = _montar("paso_ligero", ["al_costado", "encadenar", "presteza_mayor"])
	ida.vuelve = true
	ida.infalible = true
	await _colocar(yo, [50.0, 140.0, 170.0])
	var sitio: Vector2 = t.pos_de(yo)
	var hp0: float = es[0].current_hp
	_lanzar(ida, t.pies_de(yo) + lado * 60.0)
	var vueltas: int = t._deslices.filter(func(dd): return dd["c"] == yo and int(dd["modo"]) == t.Desliz.VUELTA).size()
	_ver(vueltas == 1, "Ida y vuelta: pide la vuelta")
	_ver(is_equal_approx(yo.descuento_hab, 0.2), "Encadenar: tu siguiente habilidad, -20 %")
	var fin: AbilityData = load(HAB % "fintas")
	_ver(yo.coste_hab(fin, 1) < fin.coste(1), "y la ficha de otra la cobra mas barata (%d -> %d)" % [fin.coste(1), yo.coste_hab(fin, 1)])
	var pr = _estado(yo, StatusEffects.Id.PRESTEZA)
	_ver(pr != null and is_equal_approx(pr.mult_override, 1.4), "Presteza mayor: +40 %")
	var lej: Array = [0.0]   # (las lambdas copian las variables: un Array si se comparte)
	await _esperar_a(func() -> bool:
		lej[0] = maxf(float(lej[0]), t.cuerpo_de(yo).global_position.distance_to(sitio))
		return t._deslices.is_empty(), 10.0)
	var lejos_max: float = float(lej[0])
	print("    Ida y vuelta: se alejo %.0f px y acaba a %.0f px de donde estaba" % [lejos_max,
		t.cuerpo_de(yo).global_position.distance_to(sitio)])
	_ver(lejos_max > 20.0 and t.cuerpo_de(yo).global_position.distance_to(sitio) < 3.0, "Ida y vuelta: va y vuelve a su sitio")
	_ver(hp0 - es[0].current_hp > 0.0, "y la estocada entra")

	# SIN NADIE: Recobrar aliento (+10 % EN), Paso que despista (amenaza a la mitad) y Paso de guardia (en otro).
	yo = await _turno()
	await _colocar(yo, [150.0, 180.0, 210.0])
	for e in es:
		e.amenaza[yo] = 100.0
	var rec: AbilityData = _montar("paso_ligero", ["al_costado", "encadenar", "paso_despista", "recobrar_aliento"])
	yo.current_energy = 100.0
	_lanzar(rec, t.pies_de(yo) - lado * 60.0)
	print("    energia %.0f, amenaza %s" % [yo.current_energy, str(es.map(func(e): return float(e.amenaza.get(yo, -1.0))))])
	_ver(is_equal_approx(yo.current_energy, 200.0), "Recobrar aliento: sin golpear, +10 % de energia")
	_ver(es.all(func(e): return float(e.amenaza.get(yo, 0.0)) <= 50.01), "Paso que despista: amenaza a la mitad")

	yo = await _turno()
	await _colocar(yo, [150.0, 180.0, 210.0])
	var pg: AbilityData = _montar("paso_ligero", ["paso_largo", "esquiva_paso", "presteza_mayor", "paso_guardia"])
	_lanzar(pg, t.pies_de(yo) - lado * 60.0)
	print("    en guardia %s, barra x%.2f, capa %.2f, presteza %s" % [yo.en_guardia, yo.guardia_spd_mult, yo.guardia_capa,
		_estado(yo, StatusEffects.Id.PRESTEZA) != null])
	_ver(yo.en_guardia and is_equal_approx(yo.guardia_spd_mult, 1.0) and yo.guardia_capa > 0.0,
		"Paso de guardia: sin golpear, en guardia y sin frenar la barra")
	_ver(_estado(yo, StatusEffects.Id.PRESTEZA) != null, "y sin quitarte la Presteza")
	_ver(_estado(yo, StatusEffects.Id.ESQUIVO) != null, "Esquiva en el paso: Esquivo")


# ------------------------------------------------------------ PUNZADA AL NERVIO
func _punzada() -> void:
	print("--- PUNZADA AL NERVIO")
	var yo: Combatant = await _turno()
	# el 1o en la linea; el 2o, pegado al 1o pero fuera de la linea; el 3o, detras en la linea y lejos
	await _colocar(yo, [12.0, 14.0, 90.0], [0.0, 34.0, 0.0])
	var punta: Vector2 = t.pies_de(es[0]) + lado * 20.0
	t.anotar_apunte([punta.x, punta.y])
	var cad: AbilityData = _montar("punzada_al_nervio", ["nervio_brazo", "temblor", "cadena_nerviosa"])
	var esc := {}
	for o in t.reparto_habilidad(cad, yo):
		esc[o["c"]] = float(o["escala"])
	print("    Cadena: %s" % str(es.map(func(e): return esc.get(e, -1.0))))
	_ver(is_equal_approx(esc.get(es[0], 0.0), 1.0) and is_equal_approx(esc.get(es[1], 0.0), 0.5) and not esc.has(es[2]),
		"Cadena nerviosa: el 1o entero y salta al mas cercano a el, a la mitad")

	# TEMBLOR (el Debil, al techo del 95 %: hasta 3 intentos)
	cad.infalible = true
	cad.efectos_prob_mult = 10.0
	var deb = null
	for intento in 3:
		if intento > 0:
			yo = await _turno()
			await _colocar(yo, [12.0, 14.0, 90.0], [0.0, 34.0, 0.0])
		_lanzar(cad, punta)
		deb = _estado(es[0], StatusEffects.Id.DEBIL)
		if deb != null:
			break
	print("    %s: Debil %s (inmune %s, prob %.2f), critico de estados %.2f" % [es[0].nombre, deb != null,
		es[0].es_inmune(StatusEffects.Id.DEBIL), StatusEffects.prob_final(cad.prob_de_efecto(cad.efectos[0]) * 10.0, yo, es[0],
		StatusEffects.Id.DEBIL), es[0].status_crit_flat()])
	_ver(deb != null and is_equal_approx(deb.mult_override, 0.65), "Nervio del brazo: su Debil al x0,65")
	_ver(deb != null and is_equal_approx(es[0].status_crit_flat(), -0.1), "Temblor: -10 puntos de critico")

	# CLAVADO: con Lento puesto, Enraizado
	# (el Enraizado, al techo del 95 %: hasta 3 intentos)
	var enr = null
	for _intento in 3:
		yo = await _turno()
		await _colocar(yo, [12.0, 120.0, 150.0], [0.0, 60.0, -60.0])
		var cla: AbilityData = _montar("punzada_al_nervio", ["nervio_pierna", "clavado"])
		cla.infalible = true
		cla.enraiza_si_lento = 10.0
		es[0].apply_status(StatusEffects.Id.LENTO, 3)
		_lanzar(cla, t.pies_de(es[0]) + lado * 20.0)
		enr = _estado(es[0], StatusEffects.Id.ENRAIZADO)
		if enr != null:
			break
	_ver(enr != null, "Clavado: Lento -> Enraizado")

	# SOBRE LO TOCADO (+30 % al Debil): en UNA estocada que atraviesa, el 1o sin Debil y el 2o con el (mismo golpe, misma
	# tirada de quien la lanza; los dos enemigos son del mismo tipo)
	yo = await _turno()
	await _colocar(yo, [12.0, 30.0, 300.0], [0.0, 0.0, 80.0])
	var sob: AbilityData = _montar("punzada_al_nervio", ["nervio_brazo", "temblor", "atravesar_p", "sobre_lo_tocado"])
	sob.infalible = true
	sob.crit_extra = -5.0
	sob.efectos = []
	es[1].apply_status(StatusEffects.Id.DEBIL, 3)
	var h0: Array = [es[0].current_hp, es[1].current_hp]
	_lanzar(sob, t.pies_de(es[1]) + lado * 20.0)
	var d0: float = float(h0[0]) - es[0].current_hp
	var d1: float = float(h0[1]) - es[1].current_hp
	print("    Sobre lo tocado (%s y %s): %.1f sin Debil, %.1f con Debil (x%.2f)" % [es[0].nombre, es[1].nombre, d0, d1,
		d1 / maxf(d0, 0.01)])
	# (cada golpe lleva su variacion de daño: la cuenta exacta esta en las unitarias; aqui, que entra a los dos y mas al Debil)
	_ver(d0 > 0.0 and d1 / d0 > 1.05, "Sobre lo tocado: al Debil le pega mas")

	# (la Marca va al 100 %, que con el techo de los estados es un 95 %: hasta 3 intentos)
	var mar = null
	for _intento in 3:
		yo = await _turno()
		await _colocar(yo, [12.0, 120.0, 150.0], [0.0, 60.0, -60.0])
		var lena: AbilityData = _montar("punzada_al_nervio", ["nervio_brazo", "temblor", "atravesar_p", "lena_al_caido"])
		lena.infalible = true
		lena.estado_golpe_prob = 10.0   # (los Minotauros resisten estados: al techo del 95 %)
		_lanzar(lena, t.pies_de(es[0]) + lado * 20.0)
		mar = _estado(es[0], StatusEffects.Id.MARCA)
		if mar != null:
			break
	_ver(mar != null and is_equal_approx(mar.mult_override, 1.1) and int(mar.turns) <= 1, "Leña al caido: Marca +10 %, 1 turno")


# ------------------------------------------------------------ EN GUARDIA
func _guardia() -> void:
	print("--- EN GUARDIA")
	var yo: Combatant = await _turno()
	await _colocar(yo, [20.0, 40.0, 400.0], [0.0, 40.0, 0.0])
	yo.apply_status(StatusEffects.Id.PRESTEZA, 3)
	var g: AbilityData = _montar("en_guardia", ["guardia_alta", "reto", "respiro", "guardia_no_cae"])
	for e in es:
		e.amenaza.clear()
	_lanzar(g, t.pies_de(yo) + lado * 20.0)
	_ver(yo.en_guardia and _estado(yo, StatusEffects.Id.PRESTEZA) == null, "En guardia: te quita la Presteza")
	_ver(is_equal_approx(yo.guardia_capa, 0.28 + 0.08), "Guardia alta: capa del 36 % (28 del nivel 5 + 8)")
	var retados: Array = es.filter(func(e): return float(e.amenaza.get(yo, 0.0)) > 0.0)
	print("    Reto: %d de 3 con amenaza hacia ti" % retados.size())
	_ver(retados.has(es[0]) and retados.has(es[1]) and not retados.has(es[2]), "Reto: los de cerca, no el de lejos")
	yo.current_energy = 0.0
	combat.enemigos.al_esquivar_en_guardia(yo)
	_ver(is_equal_approx(yo.current_energy, 50.0), "Respiro: cada esquiva +5 % de energia")
	yo.salir_de_guardia()
	var esq = _estado(yo, StatusEffects.Id.ESQUIVO)
	_ver(esq != null, "Guardia que no cae: al salir, Esquivo")
	print("    capas de esquiva al salir: %s" % str(yo.capas_esquiva()))

	yo = await _turno()
	await _colocar(yo, [20.0, 400.0, 400.0], [0.0, 60.0, -60.0])
	var g2: AbilityData = _montar("en_guardia", ["guardia_paciente", "salir_al_paso", "paciencia_g"])
	_lanzar(g2, t.pies_de(yo) + lado * 20.0)
	_ver(is_equal_approx(yo.guardia_spd_mult, 0.35), "Guardia paciente: la barra al 35 %")
	combat.enemigos.al_esquivar_en_guardia(yo)
	_ver(_estado(yo, StatusEffects.Id.AL_ACECHO) != null, "Paciencia: Al acecho")
	# SALIR AL PASO: el enemigo un poco mas lejos de lo que llegas
	var e: Combatant = es[0]
	var pe: Vector2 = t.pies_de(yo) + lado * (t.radio_pisa(yo) + t.radio_pisa(e) + t.alcance_de(yo) + 25.0)
	t._colocar(e, t.cuerpo_de(e), pe - (t.pies_de(e) - t.pos_de(e)))
	await _esperar(2)
	# (su caja cambia de ancho segun hacia donde mira: se corrige con el hueco medido, a 20 px mas de lo que llegas)
	var falta: float = t.alcance_de(yo) + 20.0 - t.hueco_entre(yo, e)
	t._colocar(e, t.cuerpo_de(e), t.pos_de(e) + lado * falta)
	await _esperar(2)
	print("    hueco %.0f, alcance %.0f" % [t.hueco_entre(yo, e), t.alcance_de(yo)])
	_ver(not t.llega(yo, e), "(el enemigo esta fuera de tu alcance)")
	_ver(combat.enemigos._devuelve_en_guardia(yo, e), "Salir al paso: se la devuelves dando un paso")
	yo.guardia_paso = 0.0
	_ver(not combat.enemigos._devuelve_en_guardia(yo, e), "sin el nodo, no")
	# OJOS EN LA ESPALDA
	t.cuerpo_de(yo).set("_facing", -lado)
	t._frente_defensa.erase(yo)
	_ver(not t.cubre_de_frente(yo, e), "sin Ojos en la espalda, por detras no cubre")
	yo.guardia_todos_lados = true
	_ver(t.cubre_de_frente(yo, e), "Ojos en la espalda: cubre por detras")
	yo.salir_de_guardia()


# ------------------------------------------------------------ FINTAS Y DANZA DE ACERO
func _fintas_y_danza() -> void:
	print("--- FINTAS Y DANZA DE ACERO")
	var yo: Combatant = await _turno()
	await _colocar(yo, [6.0, 10.0, 14.0], [0.0, 30.0, -30.0])
	var f: AbilityData = _montar("fintas", ["abanico", "ninguno_se_libra", "leer_guardia"])
	f.infalible = true
	f.estado_golpe_prob = 10.0   # (los Minotauros resisten estados: al techo del 95 %)
	_lanzar(f, t.pies_de(es[0]) + lado * 10.0)
	var leidos: Array = es.filter(func(e): return _estado(e, StatusEffects.Id.GUARDIA_LEIDA) != null)
	print("    Guardia leida en %d de 3" % leidos.size())
	_ver(leidos.size() >= 2, "Leer la guardia: Guardia leida a los que golpea")

	yo = await _turno()
	await _colocar(yo, [10.0, 40.0, 300.0], [0.0, 0.0, 80.0])   # con sitio libre al final de la linea
	for e in es:
		e.en_guardia = true
	var d: AbilityData = _montar("danza_de_acero", ["cuarto_tiempo", "compas", "herida_cruz", "bailar_esquivando"])
	d.quita_guardia = true
	d.infalible = true
	_lanzar(d, t.pies_de(yo) + lado * 200.0)
	_ver(not es[0].en_guardia and not es[1].en_guardia, "Sin guardia: a los que golpea se les quita")
	_ver(es[2].en_guardia, "y al que no golpea, no")
	_ver(_estado(es[1], StatusEffects.Id.VULNERABLE) != null and _estado(es[0], StatusEffects.Id.VULNERABLE) == null,
		"Herida en cruz: solo el ultimo, Vulnerable")
	_ver(_estado(yo, StatusEffects.Id.ESQUIVO) != null, "Bailar esquivando: Esquivo al acabar")
	# (25/11) LA DANZA CONTRA UN GRUPO APIÑADO: pega a los que pilla su linea y sales por detras (antes no pegaba a nadie).
	yo = await _turno()
	await _colocar(yo, [6.0, 30.0, 54.0])
	var apiñada: AbilityData = _montar("danza_de_acero", [])
	apiñada.infalible = true
	var sitio: Vector2 = t.pies_de(yo)
	var hp0: Array = es.map(func(e): return e.current_hp)
	_lanzar(apiñada, t.pies_de(yo) + lado * 200.0)
	var pegados: int = range(3).filter(func(i): return es[i].current_hp < float(hp0[i])).size()
	await _esperar_a(func() -> bool: return t._deslices.is_empty(), 10.0)
	var avanzo: float = (t.pies_de(yo) - sitio).dot(lado)
	print("    apiñados: pega a %d, avanza %.0f px (el 1o esta a %.0f, el ultimo a %.0f)" % [pegados, avanzo,
		(t.pies_de(es[0]) - sitio).dot(lado), (t.pies_de(es[2]) - sitio).dot(lado)])
	_ver(pegados >= 2, "Danza contra un grupo apiñado: pega")
	_ver(avanzo > (t.pies_de(es[0]) - sitio).dot(lado), "y pasa al otro lado del primero")
