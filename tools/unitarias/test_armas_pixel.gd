extends "res://tools/unitarias/caso.gd"
# ============================================================
#  LAS ARMAS EN PIXEL (06/11): cada tipo de arma con dibujo tiene su icono de 32 x 32 en grises de indice
#  (assets/sprites/equipo/arma, de tools/equipo_armas.py --hornear), sus grises tienen papel en ROLES_ICONO
#  (el 14 y el 15 son el BRILLO y el HONDO) y el retrato de la celda lo usa.
# ============================================================

const RetratoPieza = preload("res://scripts/ui/retrato_pieza.gd")


func test_cada_arma_tiene_icono() -> void:
	for tn in ArmaSprites.TIPO_NOMBRE + ArmaSprites.EXTRA:
		if tn == "punos":
			continue
		var r: String = ArmaSprites.icono(String(tn))
		if not cierto(r != "", "falta el icono de %s" % tn):
			continue
		var t := load(r) as Texture2D
		igual(Vector2i(t.get_width(), t.get_height()), Vector2i(32, 32), "tamaño de %s" % r)


func test_los_grises_tienen_papel() -> void:
	igual(ArmaSprites.ROLES_ICONO.size(), 16, "los papeles llenan la rampa de 16")
	igual(ArmaSprites.ROLES_ICONO[14], PaletaEquipo.Rol.MATERIAL_B, "el 14 es el brillo")
	igual(ArmaSprites.ROLES_ICONO[15], PaletaEquipo.Rol.MATERIAL_O, "el 15 es el hondo")
	var img: Image = (load(ArmaSprites.icono("espada_larga")) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var vistos: Dictionary = {}
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				vistos[int(round(c.r * float(CapaJugador.RAMPA_TONOS - 1)))] = true
	cierto(vistos.has(14) and vistos.has(15), "la espada larga lleva el brillo y el hondo")


func test_el_retrato_es_el_icono() -> void:
	var w := WeaponData.new()
	w.tipo = WeaponData.Tipo.ESPADA_LARGA
	var r: Dictionary = RetratoPieza.de(w, 2, 0)
	if cierto(r.has("tex"), "la espada larga tiene retrato"):
		igual((r["tex"] as Texture2D).resource_path, ArmaSprites.icono("espada_larga"), "el retrato es el icono")
