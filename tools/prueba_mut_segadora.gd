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

	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)
