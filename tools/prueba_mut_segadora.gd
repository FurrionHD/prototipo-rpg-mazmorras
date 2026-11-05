# LOS MUTANTES DE LA SEGADORA (05/11): Segadora -> SEGADORA DE SIERRA -> VENDAVAL ROJO. El arbol, las seis stats (misma suma),
# los ataques y las fichas de Siega y Vendaval de cortes. (Las pasivas y la pelea, cuando esten: paso 4.)
#   godot --headless --path . res://tools/prueba_mut_segadora.tscn
extends Node

var _mal: int = 0


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _nombres(c: Combatant) -> Array:
	return c.habilidades.map(func(a): return a.nombre)


func _ready() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/segadora.tres")
	print("1) EL ARBOL")
	var si: Combatant = ed.crear_combatant(0.5, true, false, &"sierra")
	var ve: Combatant = ed.crear_combatant(0.5, true, false, &"vendaval")
	_ver(si.nombre == "Segadora de sierra" and ve.nombre == "Vendaval rojo", "nombres (%s, %s)" % [si.nombre, ve.nombre])
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"sierra", "de la segadora sale la de sierra")
	_ver(ed.siguiente_mutacion(true, &"sierra")["id"] == &"vendaval", "de la de sierra, el vendaval")

	print("2) LAS STATS")
	var suma_normal: int = ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad
	_ver(suma_normal == 200 and ed.voluntad == 12 and ed.magia == 8, "la normal estrena Voluntad 12, Magia 8, suma %d" % suma_normal)
	for id in [&"sierra", &"vendaval"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == suma_normal and p.size() == 6, "%s: las seis, suma %d" % [id, suma])
	_ver(si.hab("fuerza") > si.hab("magia"), "la de sierra pega con la fuerza")
	_ver(ve.hab("magia") > ve.hab("fuerza") and ve.hab("voluntad") > ve.hab("resistencia"), "el vendaval es maga: mas magia que fuerza y mas voluntad que resistencia")

	print("3) LOS ATAQUES")
	_ver(_nombres(si) == ["Doble guadaña", "Ensarte", "Siega"], "sierra: %s" % [_nombres(si)])
	_ver(_nombres(ve) == ["Doble guadaña", "Ensarte", "Siega", "Vendaval de cortes"], "vendaval: %s" % [_nombres(ve)])
	var sie: AbilityData = load("res://resources/abilities/segadora_siega.tres")
	_ver(sie.carga_turnos == 1 and sie.forma == 2 and sie.forma_radio == 60.0 and sie.forma_apertura == 180.0, "Siega: carga, semicirculo r60")
	var ven: AbilityData = load("res://resources/abilities/vendaval_cortes.tres")
	_ver(ven.es_magico and ven.elemento_golpe == Elementos.Elemento.VIENTO and ven.lineas_abanico == 3, "Vendaval: magico, de viento, tres lineas")

	print("4) LOS SPRITES")
	_ver(Segadora3DSprites.tiene_mutante(ed, &"sierra") and Segadora3DSprites.tiene_mutante(ed, &"vendaval"), "los dos tienen sprite")
	for id in [&"sierra", &"vendaval"]:
		var sf: SpriteFrames = Segadora3DSprites.generar_mutante_de(ed, 0.5, id)
		_ver(sf != null and sf.has_animation("siega_0") and sf.has_animation("evolucion_7"), "%s: hojas cargadas" % id)
	var sfv: SpriteFrames = Segadora3DSprites.generar_mutante_de(ed, 0.5, &"vendaval")
	_ver(sfv != null and sfv.has_animation("vendaval_0") and sfv.has_animation("salto_atras_4"), "el vendaval lleva las suyas")

	print("5) LOS EFECTOS EN PIXEL")
	var hojas: Dictionary = preload("res://scripts/fx/efectos_pixel_datos.gd").HOJAS.get("segadora", {})
	var faltan: Array = []
	for quien in ["normal", "sierra", "vendaval"]:
		for g in ["basico", "basico_der", "guadanas", "ensarte"] + (["siega"] if quien != "normal" else []) \
				+ (["vendaval", "salto_atras"] if quien == "vendaval" else []):
			if not hojas.has("%s_%s" % [quien, g]):
				faltan.append("%s_%s" % [quien, g])
	_ver(faltan.is_empty(), "las estelas de las garras de las tres (faltan: %s)" % [faltan])
	_ver(hojas.has("impacto_hueso") and hojas.has("impacto_metal") and hojas.has("estocada_hueso") and hojas.has("estocada_metal"), "los impactos")
	var padre := Node2D.new()
	add_child(padre)
	var caja := Rect2(100, 100, 20, 30)
	for m in [InsectoAire.Modo.TAJO, InsectoAire.Modo.GUADANA, InsectoAire.Modo.ESTOCADA]:
		var e = InsectoAire.sobre_cuerpo(padre, m, Vector2(60, 110), caja, 1, 0.0, 1.0, 1.0)
		_ver(e is EfectoPixel, "golpe %d: el impacto es el de pixel" % m)
	padre.queue_free()

	print("6) LAS PASIVAS (los datos; la pelea, en prueba_segadora_pelea)")
	var no: Combatant = ed.crear_combatant(0.5, false, false, &"")
	_ver(si.zona_siega == 0.5 and si.cortes_viento == 0.0 and si.vuelo_corto_prob == 0.0, "sierra: Zona de siega x0,5, sin cortes")
	_ver(ve.cortes_viento == 0.5 and ve.cortes_melee_mult == 0.8 and ve.vuelo_corto_prob == 0.3,
		"vendaval: cortes x0,5, cuerpo a cuerpo x0,8, Vuelo corto 30 %")
	_ver(no.zona_siega == 0.0 and no.cortes_viento == 0.0, "la normal no tiene nada de eso")
	var esc: float = float(EnemyData.mult_mutante(false, 1)["escala"])
	_ver(absf(si.alcance - ed.alcance_real(esc) * 1.43) < 0.01, "sierra: las garras llegan x1,43 (%.1f, la normal %.1f)" % [si.alcance, no.alcance])

	print("7) EL ABANICO DEL VENDAVAL (tres lineas)")
	var f = CombatFormas.de_habilidad_mapa(ven, Vector2.ZERO, 0.0, 50.0, Vector2(100, 0))
	_ver(f.abanico == 3 and f.lineas().size() == 3, "la forma lleva tres lineas")
	var r_lejos := Rect2(Vector2(120, -6), Vector2(12, 12))
	var r_pegado := Rect2(Vector2(6, -6), Vector2(12, 12))
	var r_lado := Rect2(Vector2(0, 120), Vector2(12, 12))
	var r_ala: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(20.0)) * 120.0
	_ver(f.veces(r_lejos) == 1, "lejos y de frente, una linea (%d)" % f.veces(r_lejos))
	_ver(f.veces(r_pegado) == 3, "pegado a ella, donde se cruzan, las tres (%d)" % f.veces(r_pegado))
	_ver(f.veces(Rect2(r_ala - Vector2(6, 6), Vector2(12, 12))) == 1, "en un ala del abanico, una")
	_ver(f.veces(r_lado) == 0 and not f.toca(r_lado), "de lado, ninguna")
	var tac = load("res://scripts/ui/combat_tactico.gd")
	var viaje = tac._desempaquetar(tac._empaquetar(3, 1, f, 0.0), 0)[2]
	_ver(viaje.abanico == 3 and is_equal_approx(viaje.abanico_angulo, f.abanico_angulo) and viaje.veces(r_pegado) == 3,
		"la huella viaja por red con su abanico (el espejo ve las tres lineas)")

	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)
