# PRUEBA (sin ventana): LOS MUTANTES DEL ACECHADOR (19/11, memoria acechador-mutante).
#
#   1. La ficha: la base con su Voluntad (suma 178), la Sombra sin rostro (1a) y el Cazador lunar (2a, desde la Sombra),
#      sus stats, sus kits y la vida de verdad en el piso 10 (la del juego: 490 y 656; la tabla del 17/11 la inflaba).
#   2. Las habilidades nuevas del Cazador: Media luna (cono ancho y corto, magica de Oscuridad, sin carga) y Caida de la luna
#      (circulo donde apunte, magica de Oscuridad, carga 1 turno).
#   3. (20/11) Los sprites horneados: cada mutante con el SUYO (antes salian con el del normal) y sus animaciones.
#   4. (20/11) PACIENCIA DEL CAZADOR, en una pelea de verdad: a la vista con su texto; se funde al acabar cada turno suyo;
#      cada turno que empieza escondido suma (aturdido o tras recibir un golpe, no; lo cargado no se pierde); con 3, su
#      golpe sale desde las sombras (+50 %%, le saca de ellas) y al acabar el turno vuelve a 0 y se funde otra vez.
#      Los dos EMPIEZAN LA PELEA YA ESCONDIDOS.
#   5. (20/11) EL CAZADOR LUNAR: las FASES DE LA LUNA (nueva: los golpes no le sacan; creciente: +20 %% de velocidad; llena:
#      +40 %% a lo magico y la de carga sale sin esperar; menguante: +6 %% de vida), la MARCA DE LA LUNA (contra el marcado no
#      gasta la Paciencia) y LUZ DE LUNA (la Luz le hace x1,0), sus pasivas a la vista con su texto y sus iconos.
extends Node

const ACECHADOR := "res://scenes/actors/enemy/acechador.tres"
var sala = null

var _mal := 0


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
	var ed: EnemyData = load(ACECHADOR)
	_ficha(ed)
	_habilidades()
	_sprites(ed)
	await _pelea()
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)


func _suma(m: Dictionary) -> int:
	var s := 0
	for k in m:
		s += int(m[k])
	return s


func _ficha(ed: EnemyData) -> void:
	print("=== LA FICHA ===")
	_ok([ed.resistencia, ed.fuerza, ed.destreza, ed.agilidad, ed.magia, ed.voluntad] == [38, 56, 30, 44, 4, 6],
		"la base: R38 F56 D30 A44 M4 V6 (suma 178)")
	var so: MutacionData = ed.mutacion_de(&"sombra")
	var ca: MutacionData = ed.mutacion_de(&"cazador")
	_ok(so != null and ca != null, "la Sombra sin rostro y el Cazador lunar")
	if so == null or ca == null:
		return
	_ok(so.grado == 1 and so.nombre == "Sombra sin rostro", "la Sombra sin rostro, de 1a")
	_ok(ca.grado == 2 and ca.desde == [&"sombra"] and ca.nombre == "Cazador lunar", "el Cazador lunar, de 2a desde la Sombra")
	_ok(_suma(so.pesos) == 178 and _suma(ca.pesos) == 178, "los dos suman 178 (%d, %d)" % [_suma(so.pesos), _suma(ca.pesos)])
	_ok(int(so.pesos["agilidad"]) == 50 and int(ca.pesos["magia"]) == 42, "sus stats (Sombra A50, Cazador M42: el mas mago)")
	_ok(ed.siguiente_mutacion(false, &"")["id"] == &"sombra" and ed.siguiente_mutacion(true, &"sombra")["id"] == &"cazador",
		"del normal a la Sombra y de la Sombra al Cazador")
	_ok(so.habilidades.is_empty(), "la Sombra: el kit de siempre, todo fisico (Zarpazo doble, Salto, Dentellada)")
	var noms: Array = ca.habilidades.map(func(a): return a.nombre)
	_ok(noms == ["Salto a la yugular", "Media luna", "Caída de la luna", "Marca de la luna"],
		"el Cazador: Salto, Media luna, Caída de la luna y Marca de la luna (%s)" % str(noms))
	var fis: Array = ca.habilidades.filter(func(a): return not a.es_magico).map(func(a): return a.nombre)
	_ok(fis == ["Salto a la yugular", "Marca de la luna"], "el Cazador mixto: el Salto fisico, las dos de luna magicas (la Marca no pega)")
	# LA VIDA DE VERDAD en el piso 10, con los multiplicadores de mutante (la de la tabla)
	var piso_antes: int = Game.current_floor
	Game.current_floor = 10
	var cs: Combatant = ed.crear_combatant(0.5, true, false, &"sombra")
	var cc: Combatant = ed.crear_combatant(0.5, true, false, &"cazador")
	Game.current_floor = piso_antes
	_ok(cs.nombre.contains("Sombra sin rostro") and cc.nombre.contains("Cazador lunar"),
		"en la pelea se llaman asi (%s, %s)" % [cs.nombre, cc.nombre])
	print("     vida en el piso 10: Sombra %.0f, Cazador %.0f (esperada: 490 y 656)" % [cs.max_hp, cc.max_hp])
	_ok(absf(cs.max_hp / 490.0 - 1.0) < 0.03, "la Sombra con su vida (490: x2,0 del normal)")
	_ok(absf(cc.max_hp / 656.0 - 1.0) < 0.03, "el Cazador con su vida (656: x2,7 del normal)")


func _habilidades() -> void:
	print("=== LAS HABILIDADES DE LUNA ===")
	var ml: AbilityData = load("res://resources/abilities/acechador_media_luna.tres")
	_ok(ml.es_magico and ml.elemento_golpe == Elementos.Elemento.OSCURIDAD, "Media luna: magica de Oscuridad")
	_ok(ml.forma == CombatFormas.Tipo.CONO and ml.forma_apunte == CombatFormas.Apunte.DELANTE
		and is_equal_approx(ml.forma_radio, 64.0) and is_equal_approx(ml.forma_apertura, 150.0),
		"Media luna: cono ancho y corto delante (2 casillas, 150 grados)")
	_ok(is_equal_approx(ml.dano_mult, 1.2) and ml.cooldown == 3 and ml.carga_turnos == 0, "Media luna: 1,2, recarga 3, sin carga")
	var cl: AbilityData = load("res://resources/abilities/acechador_caida_luna.tres")
	_ok(cl.es_magico and cl.elemento_golpe == Elementos.Elemento.OSCURIDAD, "Caída de la luna: magica de Oscuridad")
	_ok(cl.forma == CombatFormas.Tipo.CIRCULO and cl.forma_apunte == CombatFormas.Apunte.LIBRE
		and is_equal_approx(cl.forma_radio, 48.0), "Caída de la luna: circulo de 3 casillas de ancho donde apunte")
	_ok(is_equal_approx(cl.dano_mult, 1.6) and cl.cooldown == 4 and cl.carga_turnos == 1,
		"Caída de la luna: 1,6, recarga 4, carga 1 turno")


func _sprites(ed: EnemyData) -> void:
	print("=== LOS SPRITES ===")
	for par in [[&"sombra", ["idle_0", "zarpazo_0", "yugular_0", "fundirse_0", "emerger_0", "comer_0", "evolucion_0"]],
			[&"cazador", ["idle_0", "yugular_0", "media_luna_0", "aullido_0", "marca_0", "fundirse_0", "emerger_0", "comer_0",
				"evolucion_0"]]]:
		_ok(Acechador3DSprites.tiene_mutante(ed, par[0]), "%s tiene su sprite" % par[0])
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, par[0])
		var faltan: Array = (par[1] as Array).filter(func(a): return sf == null or not sf.has_animation(StringName(a)))
		_ok(faltan.is_empty(), "%s: con sus animaciones (faltan %s)" % [par[0], str(faltan)])
	var sc: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"cazador")
	_ok(sc != null and not sc.has_animation(&"zarpazo_0"), "el Cazador ya no usa el Zarpazo doble")
	_ok(not Acechador3DSprites.tiene_mutante(ed, &""), "el normal sigue con el suyo (con el tinte del piso)")


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _pelea() -> void:
	print("=== PACIENCIA DEL CAZADOR (en una pelea) ===")
	var ed: EnemyData = load(ACECHADOR)
	_ok(ed.mutacion_de(&"sombra").paciencia_turnos == 3 and ed.mutacion_de(&"cazador").paciencia_turnos == 3
		and is_equal_approx(ed.mutacion_de(&"cazador").paciencia_extra, 0.5), "los dos con Paciencia: 3 turnos, +50 %")
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_acechador", Game.PISO_ARENA):
		_ok(false, "arranca la sala")
		return
	sala.poner(ACECHADOR, Vector2(150, 0), {"mutacion": "sombra"})
	sala.poner(ACECHADOR, Vector2(150, 90), {"mutacion": "cazador"})
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
	var so: Combatant = null
	var ca: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"sombra":
			so = e
		elif e.mutacion == &"cazador":
			ca = e
	_ok(so != null, "la Sombra sin rostro en la pelea")
	if so == null:
		return
	for a in combat._aliados:
		a.max_hp = 100000.0
		a.current_hp = 100000.0
	var yo: Combatant = combat._aliados[0]
	var en: Variant = combat.enemigos
	# A LA VISTA, con su texto (los numeros de quien la tiene)
	_ok(so.has_status(StatusEffects.Id.PACIENCIA), "la pasiva a la vista en su ficha")
	var txt: String = " ".join(StatusEffects.texto_pasiva_portador(StatusEffects.Id.PACIENCIA, so))
	_ok(txt.contains("3 cargas") and txt.contains("50 %"), "su texto con sus numeros: %s" % txt)
	_ok(FileAccess.file_exists("res://assets/ui/estados/paciencia.png"), "con su icono en pixel (el lobo en la sombra)")
	# SE FUNDE al acabar su turno
	_ok(so.en_sombras() and ca != null and ca.en_sombras(), "los dos empiezan la pelea ya escondidos")
	so.salir_de_sombras()
	en.fin_de_turno(so)
	_ok(so.en_sombras(), "al acabar su turno se funde en las sombras")
	# CARGA: cada turno que empieza escondido, +1
	en.paciencia_al_empezar(so, false)
	_ok(so.paciencia_carga == 1 and not so.paciencia_golpe, "empieza escondido: 1 de 3")
	en.fin_de_turno(so)
	en.paciencia_al_empezar(so, true)
	_ok(so.paciencia_carga == 1, "aturdido no suma (sigue en 1)")
	en.fin_de_turno(so)
	# un golpe le saca: ese turno no suma, pero no pierde lo que llevaba
	so.take_damage(1.0)
	_ok(not so.en_sombras(), "un golpe le saca de las sombras")
	en.paciencia_al_empezar(so, false)
	_ok(so.paciencia_carga == 1, "tras el golpe, ese turno no suma pero no pierde (1)")
	en.fin_de_turno(so)
	_ok(so.en_sombras(), "y al acabar ese turno se vuelve a fundir")
	en.paciencia_al_empezar(so, false)
	en.fin_de_turno(so)
	en.paciencia_al_empezar(so, false)
	_ok(so.paciencia_carga == 3 and so.paciencia_golpe, "con 3, su golpe de este turno sale desde las sombras")
	# EL GOLPE: +50 %, le saca de las sombras; al acabar el turno, a 0 y otra vez a las sombras
	var zarpa: AbilityData = ed.habilidades[0]
	var r: Dictionary = en._enemy_resolver_golpes(so, zarpa, yo, 1, 1.0, false, false)
	_ok(r is Dictionary and so.paciencia_soltada, "suelta el golpe desde las sombras")
	_ok(not so.en_sombras(), "atacar le saca de las sombras")
	en.fin_de_turno(so)
	_ok(so.paciencia_carga == 0 and not so.paciencia_golpe, "al acabar el turno, la cuenta vuelve a 0")
	_ok(so.en_sombras(), "y se funde otra vez")
	# EL +50 %: el mismo golpe sin y con la Paciencia (sin esquivar ni critico: la Ceguera fuera y el azar fijo)
	seed(7)
	so.salir_de_sombras()
	so.paciencia_golpe = false
	var d0: float = float(en._enemy_resolver_golpes(so, zarpa, yo, 1, 1.0, false, false).get("total", 0.0))
	seed(7)
	so.paciencia_golpe = true
	var d1: float = float(en._enemy_resolver_golpes(so, zarpa, yo, 1, 1.0, false, false).get("total", 0.0))
	print("     golpe sin Paciencia %.1f, con ella %.1f" % [d0, d1])
	_ok(d0 > 0.0 and absf(d1 / d0 - 1.5) < 0.02, "con la cuenta llena pega un 50 %% mas (x%.2f)" % (d1 / maxf(d0, 0.001)))
	await _efectos(combat, so, yo)
	await _cazador(combat, ca, yo)


func _cazador(combat: Node, ca: Combatant, yo: Combatant) -> void:
	print("=== EL CAZADOR LUNAR (en una pelea) ===")
	_ok(ca != null, "el Cazador lunar en la pelea")
	if ca == null:
		return
	var en: Variant = combat.enemigos
	for id_p in [StatusEffects.Id.PACIENCIA, StatusEffects.Id.FASES_LUNA, StatusEffects.Id.LUZ_LUNA]:
		_ok(ca.has_status(id_p), "a la vista: %s" % StatusEffects.def(id_p)["nombre"])
		var clave: String = StatusEffects.clave_icono(id_p)
		_ok(FileAccess.file_exists("res://assets/ui/estados/%s.png" % clave), "con su icono (%s)" % clave)
	_ok(FileAccess.file_exists("res://assets/ui/estados/marca_luna.png"), "la Marca de la luna con su icono")
	var txt: String = " ".join(StatusEffects.texto_pasiva_portador(StatusEffects.Id.FASES_LUNA, ca))
	_ok(txt.contains("20 %") and txt.contains("40 %") and txt.contains("6 %"), "las fases con sus numeros: %s" % txt)
	# LUZ DE LUNA: la Luz, x1,0 (el acechador, x1,5)
	_ok(is_equal_approx(float(ca.resist_elemental.get(Elementos.Elemento.LUZ, 0.0)), 1.0)
		and is_equal_approx(float(ca.resist_elemental.get(Elementos.Elemento.OSCURIDAD, 0.0)), 0.7),
		"Luz de luna: la Luz le hace x1,0 (la Oscuridad, x0,7 como siempre)")
	# NUEVA: los golpes no le sacan de las sombras
	en.fase_de_luna(ca)
	_ok(ca.fase_luna == Combatant.FASE_NUEVA and ca.has_status(StatusEffects.Id.FASES_LUNA), "su primer turno: luna nueva")
	if not ca.en_sombras():
		ca.apply_status(StatusEffects.Id.EN_SOMBRAS)
	ca.take_damage(1.0)
	_ok(ca.en_sombras(), "en luna nueva, el golpe no le saca de las sombras")
	# CRECIENTE: +20 % de velocidad
	var v0: float = ca.spd()
	en.fase_de_luna(ca)
	_ok(ca.fase_luna == Combatant.FASE_CRECIENTE and absf(ca.spd() / v0 - 1.2) < 0.01, "creciente: +20 %% de velocidad (x%.2f)" % (ca.spd() / v0))
	ca.take_damage(1.0)
	_ok(not ca.en_sombras(), "fuera de la nueva, el golpe si le saca")
	# LLENA: +40 % a lo magico
	en.fase_de_luna(ca)
	_ok(ca.fase_luna == Combatant.FASE_LLENA, "luego, luna llena")
	var ml: AbilityData = load("res://resources/abilities/acechador_media_luna.tres")
	ca.paciencia_golpe = false
	seed(11)
	var d_llena: float = float(en._enemy_resolver_golpes(ca, ml, yo, 1, 1.0, false, false).get("total", 0.0))
	ca.fase_luna = Combatant.FASE_CRECIENTE
	seed(11)
	var d_otra: float = float(en._enemy_resolver_golpes(ca, ml, yo, 1, 1.0, false, false).get("total", 0.0))
	ca.fase_luna = Combatant.FASE_LLENA
	print("     Media luna fuera de la llena %.2f, en la llena %.2f" % [d_otra, d_llena])
	_ok(d_otra > 0.0 and absf(d_llena / d_otra - 1.4) < 0.03, "llena: lo magico pega un 40 %% mas (x%.2f)" % (d_llena / maxf(d_otra, 0.001)))
	# y la de CARGA sale sin esperar (tras el retraso de todas)
	var cl: AbilityData = load("res://resources/abilities/acechador_caida_luna.tres")
	ca.charging = cl
	ca.retrasando = true
	en._llega_retrasada(ca)
	_ok(ca.charging == null and ca.charge_left == 0, "llena: la Caída de la luna sale sin cargar")
	# MENGUANTE: recupera un 6 % de su vida maxima
	ca.current_hp = ca.max_hp * 0.5
	en.fase_de_luna(ca)
	_ok(ca.fase_luna == Combatant.FASE_MENGUANTE and absf(ca.current_hp - ca.max_hp * 0.56) < 0.5,
		"menguante: recupera un 6 %% de su vida maxima (%.0f de %.0f)" % [ca.current_hp, ca.max_hp])
	en.fase_de_luna(ca)
	_ok(ca.fase_luna == Combatant.FASE_NUEVA, "y vuelta a la nueva")
	# LA MARCA: contra el marcado, el golpe desde las sombras no vacia la Paciencia
	var mar: AbilityData = load("res://resources/abilities/acechador_marca_luna.tres")
	_ok(mar.dano_mult == 0.0 and mar.cooldown == 4 and mar.efectos.size() == 1
		and mar.efectos[0].estado == StatusEffects.Id.MARCA_LUNA and mar.efectos[0].turns == 3,
		"Marca de la luna: no pega, recarga 4, marca 3 turnos")
	yo.apply_status(StatusEffects.Id.MARCA_LUNA, 3)
	ca.paciencia_carga = 3
	if not ca.en_sombras():
		ca.apply_status(StatusEffects.Id.EN_SOMBRAS)
	en.paciencia_al_empezar(ca, false)
	_ok(ca.paciencia_golpe, "con la Paciencia llena")
	_soltar_hasta_acertar(en, ca, ml, yo)
	en.fin_de_turno(ca)
	_ok(ca.paciencia_carga == 1, "con la Marca: suelta el +50 %%, vuelve a 0 y el acierto al marcado ya suma 1 (%d)" % ca.paciencia_carga)
	ca.salir_de_sombras()   # (empieza a la vista: aqui solo cuenta la Marca, no la sombra)
	en.paciencia_al_empezar(ca, false)
	_soltar_hasta_acertar(en, ca, ml, yo)
	_soltar_hasta_acertar(en, ca, ml, yo)
	en.fin_de_turno(ca)
	_ok(ca.paciencia_carga == 2, "UNO por ataque aunque acierte varias veces (%d)" % ca.paciencia_carga)
	yo.statuses = yo.statuses.filter(func(x): return x.id() != StatusEffects.Id.MARCA_LUNA)
	ca.paciencia_carga = 3
	ca.apply_status(StatusEffects.Id.EN_SOMBRAS)
	en.paciencia_al_empezar(ca, false)
	_soltar_hasta_acertar(en, ca, ml, yo)
	en.fin_de_turno(ca)
	_ok(ca.paciencia_carga == 0, "sin marca: suelta el +50 %% y vuelve a 0 (%d)" % ca.paciencia_carga)
	_caida_por_fase(en, ca, yo)
	await _efectos_cazador(combat, ca, yo)
	await _luna_del_cielo(combat, ca, yo)


func _hojas_de(arena: Node) -> Array:
	var out: Array = []
	for n in arena.get_children():
		if n is EfectoPixel and n.has_meta("hoja"):
			out.append(String(n.get_meta("hoja")))
	return out


# (20/11) LOS EFECTOS DEL ACECHADOR EN PIXEL (los de su lamina aprobada, acechador_efectos_horno): las hojas, cada golpe con
# la suya y el Olor a sangre (motas de quien sangra a su hocico; no mientras esta en las sombras).
func _efectos(combat: Node, so: Combatant, yo: Combatant) -> void:
	print("=== LOS EFECTOS EN PIXEL (el normal y la Sombra) ===")
	var hojas: Dictionary = (load("res://scripts/fx/efectos_pixel_datos.gd").HOJAS as Dictionary).get("acechador", {})
	var faltan: Array = ["fauces", "fauces_sangre", "zarpa_i", "zarpa_d", "estela", "olor", "olor_entra"].filter(
		func(h): return not hojas.has(h))
	_ok(faltan.is_empty(), "las hojas horneadas (faltan %s)" % str(faltan))
	_ok(int((hojas.get("fauces", {}) as Dictionary).get("filas", 0)) == 5 and int((hojas.get("estela", {}) as Dictionary).get("filas", 0)) == 5,
		"las fauces y la estela, con 5 direcciones")
	var tm = combat.turno_mapa
	var arena: Node = tm._arena()
	_ok(tm._de_los_acechadores(tm.cuerpo_de(so)), "la Sombra cuenta como acechador (pega con su kit)")
	var E := CombatFX.Estilo
	for par in [[E.FIERA_FAUCES, "fauces"], [E.FIERA_DENTELLADA, "fauces_sangre"]]:
		tm._acechador_pixel(arena, {}, par[0], so, yo, 0.0, 1.0)
		_ok(_hojas_de(arena).has(par[1]), "%s: %s" % [E.find_key(par[0]), par[1]])
	tm._acechador_pixel(arena, {}, E.FIERA_YUGULAR, so, yo, 0.0, 1.0)
	var hy: Array = _hojas_de(arena)
	_ok(hy.has("estela") and hy.count("fauces_sangre") >= 2, "la Yugular: la estela del salto y el bocado con sangre")
	tm._acechador_pixel(arena, {"tanda": 0}, E.FIERA_ZARPA, so, yo, 0.0, 1.0)
	tm._acechador_pixel(arena, {"tanda": 1}, E.FIERA_ZARPA, so, yo, 0.0, 1.0)
	var hz: Array = _hojas_de(arena)
	_ok(hz.has("zarpa_i") and hz.has("zarpa_d"), "el Zarpazo doble: un golpe con cada mano")
	# EL OLOR A SANGRE: motas de quien sangra al acechador; escondido, no (le delataria)
	yo.apply_status(StatusEffects.Id.SANGRADO, 3, 1.0)
	for e in combat._enemies:
		if not e.en_sombras():
			e.apply_status(StatusEffects.Id.EN_SOMBRAS)
	tm._olor.clear()
	var antes: int = _hojas_de(arena).count("olor_entra")
	tm._tick_olor()
	_ok(_hojas_de(arena).count("olor_entra") == antes, "escondidos, el olor no les delata")
	so.salir_de_sombras()
	tm._olor.clear()
	tm._tick_olor()
	_ok(_hojas_de(arena).count("olor_entra") > antes, "a la vista, de quien sangra vuela una mota a su hocico")
	await _esperar(2)


# (20/11) LOS EFECTOS DEL CAZADOR (y el fundirse/emerger de los dos) en pixel, en la pelea.
func _efectos_cazador(combat: Node, ca: Combatant, yo: Combatant) -> void:
	print("=== LOS EFECTOS DEL CAZADOR EN PIXEL ===")
	var hojas: Dictionary = (load("res://scripts/fx/efectos_pixel_datos.gd").HOJAS as Dictionary).get("acechador", {})
	var faltan: Array = ["marca", "media_luna", "charco_sombra", "charco_cazador", "emerge_sombra", "emerge_cazador"].filter(
		func(h): return not hojas.has(h))
	_ok(faltan.is_empty(), "las hojas horneadas (faltan %s)" % str(faltan))
	var tm = combat.turno_mapa
	var arena: Node = tm._arena()
	# LA MARCA: la creciente sobre quien la lleva, mientras la lleve
	yo.apply_status(StatusEffects.Id.MARCA_LUNA, 3)
	tm._tick_marcas()
	_ok(_hojas_de(arena).has("marca"), "con la Marca de la luna, la creciente sobre su cabeza")
	yo.statuses = yo.statuses.filter(func(x): return x.id() != StatusEffects.Id.MARCA_LUNA)
	tm._tick_marcas()
	await _esperar(2)
	_ok(not _hojas_de(arena).has("marca"), "y se va con ella")
	# LA MEDIA LUNA: una hoja por accion aunque pille a varios
	var ev := {"anim": &"media_luna", "semilla": 4242}
	tm._media_luna_pixel(arena, ev, ca, yo, 0.0, 1.0)
	tm._media_luna_pixel(arena, ev, ca, yo, 0.0, 1.0)
	_ok(_hojas_de(arena).count("media_luna") == 1, "la Media luna: una hoja de luna por accion (%d)" % _hojas_de(arena).count("media_luna"))
	# FUNDIRSE / EMERGER (el Cazador: niebla azul)
	var cu: Node2D = tm.cuerpo_de(ca)
	if not ca.en_sombras():
		ca.apply_status(StatusEffects.Id.EN_SOMBRAS)
	cu.remove_meta(&"ya_peleando")
	tm._en_sombras.erase(cu)
	tm._sombras_visibles(false, 0.016)
	_ok(not _hojas_de(arena).has("charco_cazador"), "escondido desde el principio: no se funde (ya estaba)")
	ca.salir_de_sombras()
	tm._sombras_visibles(false, 0.016)
	_ok(_hojas_de(arena).has("emerge_cazador"), "al salir: los ojos en el charco y se abre (la niebla azul)")
	ca.apply_status(StatusEffects.Id.EN_SOMBRAS)
	tm._sombras_visibles(false, 0.016)
	_ok(_hojas_de(arena).has("charco_cazador"), "al volver a esconderse: el charco de niebla")
	_ok(cu.visible and int(cu.get_meta(&"fundiendo_hasta", 0)) > Time.get_ticks_msec(), "y se le ve mientras se funde")
	await _esperar(2)


# (20/11) LA LUNA DEL CIELO: sale con el Cazador, con su fase y sus puntos; apaga los farolillos; la Caida la baja y
# suelta el golpe; se va cuando cae el Cazador.
func _luna_del_cielo(combat: Node, ca: Combatant, yo: Combatant) -> void:
	print("=== LA LUNA DEL CIELO ===")
	var tm = combat.turno_mapa
	var arena: Node = tm._arena()
	ca.fase_luna = Combatant.FASE_LLENA
	ca.paciencia_carga = 2
	tm._tick_luna()
	var luna: LunaCielo = get_tree().get_first_node_in_group(LunaCielo.GRUPO)
	_ok(luna != null, "con el Cazador en la pelea, la luna en el cielo")
	if luna == null:
		return
	_ok(luna.fase == Combatant.FASE_LLENA and luna.puntos == 2, "con su fase (llena) y los puntos de su Paciencia (2)")
	_ok(arena.rect.has_point(luna.global_position), "sobre la pelea")
	_ok(is_equal_approx(Game.radio_lampara(), Vision.RADIO_MINIMO), "los farolillos se apagan (la luz es ella)")
	var f: Dictionary = luna.foco()
	_ok(float(f["intensidad"]) < 1.0 and float(f["radio"]) > 0.0, "y alumbra ella, tenue")
	ca.paciencia_carga = 3
	ca.fase_luna = Combatant.FASE_MENGUANTE
	tm._tick_luna()
	_ok(luna.fase == Combatant.FASE_MENGUANTE and luna.puntos == 3, "cambia de fase y de puntos con el")
	# LA CAIDA: baja hasta ellos, suelta el golpe y vuelve
	var sitio: Vector2 = luna.global_position
	tm._caida_luna({"anim": &"aullido", "semilla": 99}, ca, yo, 0.0)
	await get_tree().create_timer(LunaCielo.T_CAE + 0.2, true).timeout   # (por tiempo: sin ventana los marcos vuelan)
	_ok(_hojas_de(arena).has("luna_golpe"), "la Caida: cae sobre ellos y suelta el golpe")
	_ok(luna.global_position.distance_to(sitio) > 5.0, "y aun no ha vuelto a su sitio (vuelve despacio)")
	# EL CAZADOR CAE: la luna se va
	ca.current_hp = 0.0
	tm._tick_luna()
	_ok(not LunaCielo.hay(get_tree()), "cae el Cazador: la luna se va (y los farolillos vuelven)")


# Ataca con 'ab' hasta que acierte (el golpe se puede esquivar: la prueba no depende del azar).
func _soltar_hasta_acertar(en, ca: Combatant, ab: AbilityData, yo: Combatant) -> void:
	for _i in 30:
		var r: Dictionary = en._enemy_resolver_golpes(ca, ab, yo, 1, 1.0, false, false)
		if float(r.get("total", 0.0)) > 0.0:
			return


# (20/11, su idea) LA CAIDA DE LA LUNA SEGUN LA FASE: nueva = Ceguera, creciente = Lento, llena = nada mas, menguante = cura.
func _caida_por_fase(en, ca: Combatant, yo: Combatant) -> void:
	print("=== LA CAIDA SEGUN LA FASE ===")
	var cl: AbilityData = load("res://resources/abilities/acechador_caida_luna.tres")
	var ficha: String = cl.resumen(1, true)
	print(ficha)
	_ok(ficha.contains("En luna nueva") and ficha.contains("Acierto") and ficha.contains("En luna creciente")
		and ficha.contains("En luna menguante, se cura un 30 % del daño"), "la ficha dice lo de cada fase")
	var limpio := func():
		yo.statuses = yo.statuses.filter(func(x): return x.id() != StatusEffects.Id.CEGUERA and x.id() != StatusEffects.Id.LENTO)
	var pilla := func(fase: int, id_est: int) -> bool:
		ca.fase_luna = fase
		for _i in 40:
			limpio.call()
			en._enemy_tirar_efectos(ca, cl, yo, 1.0, "objetivo")
			if yo.has_status(id_est):
				return true
		return false
	_ok(pilla.call(Combatant.FASE_NUEVA, StatusEffects.Id.CEGUERA), "nueva: deja Ceguera")
	_ok(not yo.has_status(StatusEffects.Id.LENTO), "nueva: y no Lento")
	_ok(pilla.call(Combatant.FASE_CRECIENTE, StatusEffects.Id.LENTO), "creciente: deja Lento")
	_ok(not yo.has_status(StatusEffects.Id.CEGUERA), "creciente: y no Ceguera")
	_ok(not pilla.call(Combatant.FASE_LLENA, StatusEffects.Id.CEGUERA) and not pilla.call(Combatant.FASE_LLENA, StatusEffects.Id.LENTO),
		"llena: ni Ceguera ni Lento (es la gorda)")
	limpio.call()
	# la cura, solo en la menguante
	ca.paciencia_golpe = false
	for f in [Combatant.FASE_MENGUANTE, Combatant.FASE_LLENA]:
		ca.fase_luna = f
		ca.current_hp = ca.max_hp * 0.5
		var r: Dictionary = {}
		for _i in 30:
			yo.current_hp = yo.max_hp
			var antes: float = ca.current_hp
			r = en._enemy_resolver_golpes(ca, cl, yo, 1, 1.0, false, false)
			if float(r.get("total", 0.0)) > 0.0:
				var cura: float = ca.current_hp - antes
				if f == Combatant.FASE_MENGUANTE:
					_ok(absf(cura - float(r["total"]) * 0.3) < 0.5, "menguante: se cura el 30 %% del daño (%.1f de %.1f)" % [cura, float(r["total"])])
				else:
					_ok(is_zero_approx(cura), "fuera de la menguante no se cura (%.1f)" % cura)
				break
	ca.current_hp = ca.max_hp
	yo.current_hp = yo.max_hp
