# LOS MUTANTES DEL TRENT (02/11): Trent -> TOCON AMBARINO -> ESPANTAJO, unidos por la savia. El arbol, sus stats (las
# seis, suma 135, el trent estrena Voluntad), sus ataques (la Resina en vez de la Savia corrosiva; el Espantajo, la Savia
# negra y el Geiser) y sus sprites (cada uno con su cuerpo; la variante del Tocon sin costra; el trent normal ya come).
# Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_trent.tscn
extends Node

var _mal: int = 0


func _ready() -> void:
	call_deferred("_correr")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _nombres(c: Combatant) -> Array:
	return c.habilidades.map(func(a): return a.nombre)


func _tiene(ab: AbilityData, estado: int, prob: float, stacks: int = 1) -> bool:
	for a in ab.efectos:
		if a.estado == estado and is_equal_approx(a.prob, prob) and a.stacks == stacks:
			return true
	return false


func _correr() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/trent.tres")

	print("1) EL ARBOL")
	var c1: Combatant = ed.crear_combatant(0.5, true, false, &"ambarino")
	var c2: Combatant = ed.crear_combatant(0.5, true, false, &"espantajo")
	_ver(c1.nombre == "Tocón ambarino" and c2.nombre == "Espantajo", "nombres (%s / %s)" % [c1.nombre, c2.nombre])
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"ambarino", "del trent sale el Tocon ambarino")
	_ver(ed.siguiente_mutacion(true, &"ambarino")["id"] == &"espantajo", "y de el, el Espantajo")

	print("2) LAS STATS (las seis, suma 135)")
	_ver(ed.voluntad == 12 and ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad == 135,
		"el trent: 32/50/14/10/17/12 (estrena Voluntad)")
	for id in [&"ambarino", &"espantajo"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == 135 and p.size() == 6, "%s: reparto de las seis, suma %d" % [id, suma])
	_ver(c1.hab("resistencia") > c2.hab("resistencia") and c2.hab("fuerza") > c1.hab("fuerza"),
		"el Tocon aguanta mas; el Espantajo pega mas")

	print("3) LOS ATAQUES")
	print("    ambarino  %s" % [_nombres(c1)])
	print("    espantajo %s" % [_nombres(c2)])
	_ver(_nombres(c1) == ["Resina", "Ramazo", "Raíces atenazantes"], "el Tocon: la Resina en vez de la Savia corrosiva")
	_ver(_nombres(c2) == ["Savia negra", "Ramazo", "Raíces atenazantes", "Géiser"], "el Espantajo: Savia negra y Geiser")
	var res: AbilityData = c1.habilidades[0]
	_ver(is_equal_approx(res.dano_mult, 0.9) and _tiene(res, StatusEffects.Id.RESINADO, 0.7)
		and _tiene(res, StatusEffects.Id.LENTO, 0.7) and int(res.charco_turnos) == 0,
		"Resina: x0,9, Resinado y Lento al 70 %, sin charco")
	var sav: AbilityData = c2.habilidades[0]
	_ver(_tiene(sav, StatusEffects.Id.VENENO, 0.6) and _tiene(sav, StatusEffects.Id.SAVIA_NEGRA, 1.0),
		"Savia negra: Veneno 60 % y una carga de Savia negra")
	var gei: AbilityData = c2.habilidades[3]
	_ver(gei.carga and gei.carga_turnos == 1 and is_equal_approx(gei.dano_mult, 1.2) and is_equal_approx(gei.forma_radio, 45.0)
		and _tiene(gei, StatusEffects.Id.SAVIA_NEGRA, 1.0, 2) and gei.cooldown == 4,
		"Geiser: un turno cargando, circulo r45, x1,2, 2 cargas de Savia negra, recarga 4")

	print("4) LOS ESTADOS")
	var sn: Dictionary = StatusEffects.def(StatusEffects.Id.SAVIA_NEGRA)
	_ver(int(sn["max_stacks"]) == 5 and is_equal_approx(float(sn["def_mult"]), 0.92), "Savia negra: -8 % de Defensa por carga, hasta 5")
	_ver(bool(StatusEffects.def(StatusEffects.Id.RESINADO).get("enraiza", false)), "Resinado: no te mueves (como el Enraizado)")

	print("5) LOS SPRITES")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	_ver(sf0 != null and sf0.has_animation(&"comer_0"), "el trent normal ya come")
	for id in [&"ambarino", &"espantajo"]:
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		_ver(sf != null and SpritesEnemigo.mutante_propio(ed, id) and sf.has_animation(&"evolucion_1")
			and sf.has_animation(&"escupir_2") and sf.has_animation(&"comer_3"), "%s: su hoja propia (evolucion, escupir, comer)" % id)
		_ver(sf == SpritesEnemigo.frames_de(ed, 0.9, true, id), "%s: sin tinte de piso" % id)
	var sfe: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"espantajo")
	_ver(sfe.has_animation(&"geiser_carga_0") and sfe.has_animation(&"geiser_5"), "el Espantajo: su Geiser (cargando y soltando)")
	_ver(sfe.get_frame_count(&"evolucion_0") == 24, "su evolucion, de 24 (se pudre poco a poco)")
	var sv: SpriteFrames = SpritesEnemigo.frames_variante(ed, &"ambarino", &"sin_costra")
	_ver(sv != null and sv.has_animation(&"idle_0") and sv.has_animation(&"raices_4")
		and sv != SpritesEnemigo.frames_de(ed, 0.5, true, &"ambarino"), "el Tocon sin costra: su variante")

	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
