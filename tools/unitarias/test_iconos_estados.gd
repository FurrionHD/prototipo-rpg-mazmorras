extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/ui/status_chip.gd, res://scripts/ui/tooltip_button.gd, res://scripts/core/status_effects.gd
# LOS ICONOS DE LOS ESTADOS EN PIXEL ART (05/11): cada estado del catalogo tiene su dibujo, el chip lo pinta en vez del
# emoji (y su ficha tambien), y el emoji sigue en los datos para el registro, la red y CombatFX.


func test_cada_estado_del_catalogo_tiene_su_dibujo() -> void:
	var faltan: Array = []
	for id in StatusEffects.all_ids():
		var clave: String = StatusEffects.clave_icono(int(id))
		if StatusChip.textura(clave) == null:
			faltan.append(clave)
	igual(faltan, [], "estados sin icono en assets/ui/estados (tools/iconos_estados_pixel.py --hornear)")


func test_los_chips_del_combate_tienen_su_dibujo() -> void:
	for p in StatusChip.PREFIJOS:
		cierto(StatusChip.textura(String(p[1])) != null, "falta el icono del chip '%s'" % p[1])


func test_el_chip_de_un_estado_lleva_el_icono_y_no_el_emoji() -> void:
	var c := Combatant.new("Prueba", 1, Abilities.new(), 100.0, 1.0, 1.0, 1.0)
	c.apply_status(StatusEffects.Id.VENENO, 3, 5.0)
	var par: Array = StatusEffects.chip_de_grupo(c.statuses)
	igual(String(par[2]), "☠", "el emoji sigue en los datos (registro, red, CombatFX)")
	igual(String(par[5]), "veneno", "y la clave del dibujo va detras")
	var b: Button = StatusChip.de_par(par)
	cierto(b.icon != null, "el chip pinta el dibujo")
	igual(b.text, "", "y no el emoji")
	# Su ficha: el dibujo delante y el texto sin el emoji del principio.
	var panel: Control = b._make_custom_tooltip(b.tooltip_text)
	var etiquetas: Array = panel.find_children("*", "Label", true, false)
	cierto(not etiquetas.is_empty() and not String(etiquetas[0].text).begins_with("☠"), "la ficha no empieza por el emoji")
	cierto(not panel.find_children("*", "TextureRect", true, false).is_empty(), "la ficha lleva el dibujo")
	panel.free()
	b.free()


func test_los_chips_de_mecanica_conservan_lo_que_cuentan() -> void:
	var b: Button = StatusChip.de_par(["⏳3t", "CARGANDO: Pisoton"])
	cierto(b.icon != null, "el reloj de arena es un dibujo")
	igual(b.text, "3t", "y detras los turnos que faltan")
	b.free()
	b = StatusChip.de_par(["🔮×2", "Foco arcano: 2 cargas", "🔮", Color(0.55, 0.7, 1.0)])
	igual(StatusChip.clave_de(["🔮×2"])[0], "foco", "el foco no se confunde con recitar")
	b.free()
	igual(StatusChip.clave_de(["🛡→2t"])[0], "cubriendo", "cubrir antes que defender")
	igual(StatusChip.clave_de(["🔮2/3"])[0], "recitando", "recitando")


func test_un_chip_sin_dibujo_se_queda_como_estaba() -> void:
	# Un espejo con una version vieja manda pares sin clave y con una etiqueta que no conocemos: texto de siempre.
	var b: Button = StatusChip.de_par(["🗡x3", "Arma imbuida"])
	cierto(b.icon == null, "sin dibujo")
	igual(b.text, "🗡x3", "con su texto")
	b.free()
