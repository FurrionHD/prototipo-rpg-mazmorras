# PRUEBA (sin ventana): LOS MUTANTES DEL ACECHADOR (19/11, memoria acechador-mutante).
#
#   1. La ficha: la base con su Voluntad (suma 178), la Sombra sin rostro (1a) y el Cazador lunar (2a, desde la Sombra),
#      sus stats, sus kits y la vida de verdad en el piso 10 (la del juego: 490 y 656; la tabla del 17/11 la inflaba).
#   2. Las habilidades nuevas del Cazador: Media luna (cono ancho y corto, magica de Oscuridad, sin carga) y Caida de la luna
#      (circulo donde apunte, magica de Oscuridad, carga 1 turno).
#   3. (20/11) Los sprites horneados: cada mutante con el SUYO (antes salian con el del normal) y sus animaciones.
extends Node

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	print(("  ok   " if cond else "  MAL: ") + que)
	if not cond:
		_mal += 1


func _ready() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/acechador.tres")
	_ficha(ed)
	_habilidades()
	_sprites(ed)
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
