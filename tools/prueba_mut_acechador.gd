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
	_ok(noms == ["Salto a la yugular", "Media luna", "Caída de la luna"], "el Cazador: Salto, Media luna y Caída de la luna (%s)" % str(noms))
	var fis: Array = ca.habilidades.filter(func(a): return not a.es_magico).map(func(a): return a.nombre)
	_ok(fis == ["Salto a la yugular"], "el Cazador mixto: el Salto fisico, las dos de luna magicas")
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
	for e in combat._enemies:
		if e.mutacion == &"sombra":
			so = e
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
	_ok(not so.en_sombras(), "empieza la pelea a la vista")
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

