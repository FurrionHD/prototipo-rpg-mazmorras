extends "res://tools/unitarias/caso.gd"
# ============================================================
#  LAS ARMADURAS EN PIXEL (06/11): cada tipo y pieza tiene su icono de 32 x 32 en grises de indice
#  (assets/sprites/equipo/armadura, de tools/equipo_armaduras.py --hornear), el retrato de la celda lo usa y los
#  dos tonos nuevos del metal (BRILLO y HONDO) salen mas claro y mas oscuro que el material.
# ============================================================

const RetratoPieza = preload("res://scripts/ui/retrato_pieza.gd")


func test_cada_tipo_y_pieza_tiene_icono() -> void:
	for tipo in ArmaduraSprites.TIPO_NOMBRE:
		for slot in ArmaduraSprites.SLOT_NOMBRE:
			var r: String = ArmaduraSprites.icono(String(tipo), String(slot))
			if not cierto(r != "", "falta el icono de %s %s" % [tipo, slot]):
				continue
			var t := load(r) as Texture2D
			igual(Vector2i(t.get_width(), t.get_height()), Vector2i(32, 32), "tamaño de %s" % r)


func test_los_grises_son_tonos_con_papel() -> void:
	# Cada gris del icono tiene que ser un tono con papel en ROLES_ICONO (si no, el shader lo pinta de otro color).
	var img: Image = (load(ArmaduraSprites.icono("placas", "pecho")) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var vistos: Dictionary = {}
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				vistos[int(round(c.r * float(CapaJugador.RAMPA_TONOS - 1)))] = true
	for t in vistos:
		cierto(int(t) < ArmaduraSprites.ROLES_ICONO.size(), "el tono %d no tiene papel" % int(t))
	cierto(vistos.has(11) and vistos.has(12), "el peto de placas lleva el BRILLO (11) y el HONDO (12)")


func test_brillo_y_hondo() -> void:
	var cols: Array = PaletaEquipo.colores_de(ArmaduraSprites.ROLES_ICONO, PaletaEquipo.METAL, 2, 0)
	var mat: Color = cols[4]
	cierto((cols[11] as Color).v > mat.v, "el BRILLO es mas claro que el material")
	cierto((cols[12] as Color).v < (cols[3] as Color).v, "el HONDO es mas oscuro que la sombra del material")


func test_el_retrato_de_la_celda_es_el_icono() -> void:
	var a := ArmorData.new()
	a.tipo = ArmorData.Tipo.PLACAS
	a.slot = ArmorData.Slot.PECHO
	var r: Dictionary = RetratoPieza.de(a, 2, 0)
	if cierto(r.has("tex"), "el peto de placas tiene retrato"):
		igual((r["tex"] as Texture2D).resource_path, ArmaduraSprites.icono("placas", "pecho"), "el retrato es el icono")
		cierto(r["material"] is ShaderMaterial, "y va con el shader de la paleta")
