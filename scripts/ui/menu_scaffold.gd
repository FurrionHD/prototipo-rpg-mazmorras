# ============================================================
#  menu_scaffold.gd
#  El ESQUELETO que comparten todos los menus a pantalla completa (inventario, tienda,
#  herrero, peletero, boticaria). Antes cada uno se construia su propio armazon a mano, con
#  el mismo codigo copiado cinco veces; ahora sale de aqui.
#
#  La forma, y el porque:
#
#    +----------+--------------------------------------------------+
#    |  LATERAL |  CABECERA   (titulo, pestañas)   <- NUNCA scroll  |
#    |  (tabs,  +---------------------+----------------------------+
#    |  cerrar) |  LISTA  (scroll ↕)  |  DETALLE  (scroll ↕)       |
#    |          |  la cuadricula      |  la ficha de lo elegido    |
#    +----------+---------------------+----------------------------+
#
#  La CABECERA se queda fija: es la brujula del menu, y si se va con el scroll dejas de saber
#  donde estas. La LISTA y el DETALLE se desplazan POR SEPARADO: una ficha larga no tiene por
#  que empujar la cuadricula, ni cien objetos de un tipo tienen por que mover la ficha.
#
#  Es estatico (como StatsMath / Upgrades): solo construye nodos y te devuelve las referencias.
# ============================================================

extends RefCounted
class_name MenuScaffold

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
const FONDO := Color(0.05, 0.06, 0.08, 1.0)

# Ancho de la columna de la lista (la cuadricula de items cabe en dos columnas de 150).
const ANCHO_LISTA := 330.0


# Construye el esqueleto dentro de `capa` (un CanvasLayer) y devuelve sus piezas:
#   {root, side, header, lista, content, dinero}
#  - root: el Control full-rect (empieza invisible; el menu lo enseña en abrir()).
#  - side: la columna izquierda (mete ahi tus pestañas; el titulo y el ✕ Cerrar ya van).
#  - header / lista / content: las tres zonas de arriba.
#  - dinero: la etiqueta de monedas arriba a la derecha (null si con_dinero = false).
static func construir(capa: CanvasLayer, titulo: String, nota: String,
		al_cerrar: Callable, con_dinero: bool = false) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	capa.add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = FONDO
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 16
	hb.offset_top = 16
	hb.offset_right = -16
	hb.offset_bottom = -16
	hb.add_theme_constant_override("separation", 18)
	root.add_child(hb)

	# Monedas arriba a la derecha (donde el jugador ya las busca).
	var dinero: Label = null
	if con_dinero:
		dinero = Label.new()
		dinero.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		dinero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dinero.offset_left = -240
		dinero.offset_right = -20
		dinero.offset_top = 16
		dinero.add_theme_color_override("font_color", Color(0.95, 0.86, 0.5))
		dinero.add_theme_font_size_override("font_size", 18)
		root.add_child(dinero)

	# --- Lateral: titulo, nota, (las pestañas las mete el menu) y cerrar ---
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(230, 0)
	side.add_theme_constant_override("separation", 6)
	hb.add_child(side)

	var t := Label.new()
	t.text = titulo
	t.add_theme_color_override("font_color", AMBAR)
	t.add_theme_font_size_override("font_size", 18)
	side.add_child(t)

	if nota != "":
		var n := Label.new()
		n.text = nota
		n.add_theme_color_override("font_color", GRIS)
		n.add_theme_font_size_override("font_size", 11)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(n)
	side.add_child(HSeparator.new())

	# El menu mete aqui sus pestañas; lo que va DESPUES (spacer + cerrar) se añade ya, asi que
	# el boton de cerrar queda siempre abajo del todo.
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	side.add_child(tabs)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var cerrar := Button.new()
	cerrar.text = "✕ Cerrar  (Esc)"
	cerrar.custom_minimum_size = Vector2(0, 34)
	cerrar.pressed.connect(al_cerrar)
	side.add_child(cerrar)

	# --- Derecha: cabecera fija + lista y detalle, cada uno con su scroll ---
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 16)
	hb.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	# Linea de AVISO ("Sacas 3 lingotes...", "No te llega"). Vive FUERA del header y con una
	# altura FIJA aunque este vacia: si apareciera y desapareciera con el mensaje, empujaria el
	# titulo y todo el menu bailaria cada vez que haces algo.
	var aviso := Label.new()
	aviso.custom_minimum_size = Vector2(0, 22)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(aviso)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(header)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 20)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(split)

	var scroll_lista := ScrollContainer.new()
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_lista.custom_minimum_size = Vector2(ANCHO_LISTA, 0)
	scroll_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_lista)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 4)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_lista.add_child(lista)

	var scroll_det := ScrollContainer.new()
	scroll_det.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_det.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_det)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_det.add_child(content)

	return {
		"root": root, "side": tabs, "header": header, "aviso": aviso,
		"lista": lista, "lista_scroll": scroll_lista, "content": content, "dinero": dinero,
	}


# Pinta (o borra) el mensaje de la linea de aviso. Verde = salio bien, rojo = no.
static func decir(aviso: Label, txt: String, ok: bool = true) -> void:
	if aviso == null:
		return
	aviso.text = txt
	aviso.add_theme_color_override("font_color",
		Color(0.55, 0.85, 0.55) if ok else Color(0.9, 0.5, 0.5))


# --- Piezas sueltas que repiten los cinco menus ---

static func titulo(vb: VBoxContainer, txt: String, tam: int = 16) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", AMBAR)
	l.add_theme_font_size_override("font_size", tam)
	vb.add_child(l)


static func fila(vb: VBoxContainer, etiqueta: String, valor: String, ancho: int = 170) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(ancho, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	vb.add_child(row)


# Texto en gris pequeño. SIN ancho minimo: en el panel de detalle (estrecho) un minimo empuja
# la columna entera fuera de la pantalla.
static func nota(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", GRIS)
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)


# Fila de botones-pestaña (los de arriba de la cabecera). `pulsado` recibe el indice.
static func pestanas(vb: VBoxContainer, nombres: Array, activa: int, pulsado: Callable,
		ancho: int = 120) -> void:
	var fila_tabs := HBoxContainer.new()
	fila_tabs.add_theme_constant_override("separation", 6)
	for i in nombres.size():
		var b := Button.new()
		b.text = str(nombres[i])
		b.toggle_mode = true
		b.button_pressed = (i == activa)
		b.custom_minimum_size = Vector2(ancho, 30)
		b.pressed.connect(pulsado.bind(i))
		fila_tabs.add_child(b)
	vb.add_child(fila_tabs)


# ============================================================
#  FICHA DE ARMA compartida
#  Una SOLA fuente de verdad para las stats de un arma. La tienda, el pack, el inventario y el
#  menu de personaje la pintaban cada uno por su cuenta, y al añadir una stat (la evasion) habia
#  que acordarse de tocar los cuatro sitios -> siempre se olvidaba uno. Ahora sale de aqui:
#  devuelve pares [etiqueta, valor] y cada menu los pinta con su propio _row. Todo se deriva de
#  Upgrades.weapon_mods, la misma math que usa el combate, asi que lo que ves es lo que tienes.
# ============================================================
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]

static func filas_arma(w: WeaponData, tier: int, rareza: int, mejoras: Dictionary) -> Array:
	var m: Dictionary = Upgrades.weapon_mods(w, Game.tier_mult(tier), rareza, mejoras)
	var filas: Array = [
		["Tipo", WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)]
			+ ("  ·  magia" if w.es_magica else "")],
		["Manejo", "Dos manos" if w.dos_manos else "Una mano"],
		["Ataque", "%.1f" % float(m["raw"])],
		["Motion value", "×%.2f" % w.motion_value],
		["Velocidad", "×%.2f" % (w.velocidad_mult * float(m["vel_mult"]))],
	]
	if float(m["crit"]) != 0.0:
		filas.append(["Crítico", "%+.0f%%" % (float(m["crit"]) * 100.0)])
	# Daño critico: el multiplicador REAL de esta arma (base + su crit_dmg, que ya lleva rareza y
	# Precision dentro). Se enseña siempre: toda arma critica por algo, y es lo que sube Precision.
	filas.append(["Daño crítico", "×%.2f" % (StatsMath.CRIT_MULT + float(m["crit_dmg"]))])
	if float(m["precision"]) > 0.0:
		filas.append(["Precisión", "+%.0f%%" % (float(m["precision"]) * 100.0)])
	if float(m["evasion"]) > 0.0:
		filas.append(["Evasión", "+%.0f%%" % (float(m["evasion"]) * 100.0)])
	if float(m["aturdir"]) > 0.0:
		filas.append(["Aturdir", "%.0f%%" % (float(m["aturdir"]) * 100.0)])
	if float(m["bloqueo"]) > 0.0:
		filas.append(["Bloqueo", "+%.2f" % float(m["bloqueo"])])
	if w.es_magica:
		# Lo MAGICO tambien pasa por su math (Upgrades.magic_mods): antes se pintaba el magic_amp
		# CRUDO del .tres (1.70) y se callaban regen/coste/casteo, asi que el inventario enseñaba
		# un baston T3 legendario como uno de madera. Ahora sale lo REAL, igual que el menu C.
		var mg: Dictionary = Upgrades.magic_mods(w.magic_amp, Game.tier_mult(tier), rareza, mejoras)
		filas.append(["Amplif. magia", "×%.2f" % float(mg["magic_amp"])])
		filas.append(["Regen maná", "%.2f/turno" % (w.mp_regen_turno * float(mg["regen_mult"]))])
		filas.append(["Vel. casteo", "×%.2f" % (w.cast_vel_mult + float(mg["cast_vel_add"]))])
		if float(mg["mana_reduccion"]) > 0.0:
			filas.append(["Coste de maná", "-%.0f%%" % (float(mg["mana_reduccion"]) * 100.0)])
	return filas


const SHIELD_TAMANO_LABELS := ["Pequeño", "Normal", "Grande"]

# La ficha del ESCUDO, por la misma via que la del arma (Upgrades -> la math del combate). Estaba
# copiada a pelo en el menu de personaje, el inventario y la tienda, y las tres leian el .tres
# CRUDO: enseñaban el mismo bloqueo para un T1 comun que para un T3 pristino. Ahora sale de aqui.
static func filas_escudo(sh: ShieldData, tier: int, rareza: int, mejoras: Dictionary) -> Array:
	var m: Dictionary = Upgrades.shield_mods(sh, Game.tier_mult(tier), rareza, mejoras)
	var filas: Array = [
		["Tipo", "Escudo %s  ·  mano secundaria"
			% SHIELD_TAMANO_LABELS[clampi(int(sh.tamano), 0, SHIELD_TAMANO_LABELS.size() - 1)].to_lower()],
		# Lo primero es la DEFENSA: es el numero que crece con tier, rareza y mejoras, o sea lo que
		# distingue a este escudo de otro igual peor. Y solo cuenta al Defender: hay que decirlo.
		["Defensa al bloquear", "+%.1f" % float(m["def"])],
		["Bloqueo", "%.0f%%" % (float(m["bloqueo"]) * 100.0)],
	]
	if float(m["resist_estados"]) > 0.0:
		filas.append(["Resist. estados", "+%.0f%%" % (float(m["resist_estados"]) * 100.0)])
	filas.append(["Velocidad", "×%.2f" % float(m["vel_mult"])])
	filas.append(["Penal. esquiva", "-%.0f%%" % (float(m["evasion_penal"]) * 100.0)])
	return filas


# Filas de ATRIBUTO para el PREVIEW de mejora (pestaña Mejorar del herrero): la MISMA math del
# combate (Upgrades.*_mods) calculada dos veces —con las mejoras actuales y con la categoria `cat`
# subida una vez— para enseñar el valor de ahora y, en verde, cuanto sube. Devuelve una lista de
# [etiqueta, valor, delta]; delta = "" cuando ese stat no cambia con esa mejora. Solo se listan los
# stats que una mejora PUEDE tocar (la reduccion/velocidad de tipo/tamaño no salen: son crudas).
static func filas_mejora(item: Resource, tier: int, rareza: int, mejoras: Dictionary, cat: String) -> Array:
	var despues: Dictionary = mejoras.duplicate(true)
	despues[cat] = int(despues.get(cat, 0)) + 1
	var tm: float = Game.tier_mult(tier)
	var filas: Array = []
	if item is WeaponData:
		var w := item as WeaponData
		var a := Upgrades.weapon_mods(w, tm, rareza, mejoras)
		var b := Upgrades.weapon_mods(w, tm, rareza, despues)
		_attr(filas, "Ataque", "%.1f" % float(a["raw"]), _d(float(a["raw"]), float(b["raw"]), "+%.1f"))
		_attr(filas, "Velocidad", "×%.2f" % (w.velocidad_mult * float(a["vel_mult"])),
			_d(w.velocidad_mult * float(a["vel_mult"]), w.velocidad_mult * float(b["vel_mult"]), "+%.2f"))
		if float(a["crit"]) != 0.0 or float(b["crit"]) != 0.0:
			_attr(filas, "Crítico", "%+.0f%%" % (float(a["crit"]) * 100.0),
				_d(float(a["crit"]) * 100.0, float(b["crit"]) * 100.0, "+%.0f%%"))
		_attr(filas, "Daño crítico", "×%.2f" % (StatsMath.CRIT_MULT + float(a["crit_dmg"])),
			_d(StatsMath.CRIT_MULT + float(a["crit_dmg"]), StatsMath.CRIT_MULT + float(b["crit_dmg"]), "+%.2f"))
		if float(a["precision"]) > 0.0 or float(b["precision"]) > 0.0:
			_attr(filas, "Precisión", "+%.0f%%" % (float(a["precision"]) * 100.0),
				_d(float(a["precision"]) * 100.0, float(b["precision"]) * 100.0, "+%.0f%%"))
		if float(a["aturdir"]) > 0.0 or float(b["aturdir"]) > 0.0:
			_attr(filas, "Aturdir", "%.0f%%" % (float(a["aturdir"]) * 100.0),
				_d(float(a["aturdir"]) * 100.0, float(b["aturdir"]) * 100.0, "+%.0f%%"))
		if w.es_magica:
			_filas_mejora_magia(filas, w.magic_amp, w.mp_regen_turno, w.cast_vel_mult, tm, rareza, mejoras, despues)
	elif item is WandData:
		var wd := item as WandData
		_filas_mejora_magia(filas, wd.magic_amp, wd.mp_regen_turno, wd.cast_vel_mult, tm, rareza, mejoras, despues)
	elif item is ShieldData:
		var sh := item as ShieldData
		var a := Upgrades.shield_mods(sh, tm, rareza, mejoras)
		var b := Upgrades.shield_mods(sh, tm, rareza, despues)
		_attr(filas, "Defensa al bloquear", "+%.1f" % float(a["def"]), _d(float(a["def"]), float(b["def"]), "+%.1f"))
		_attr(filas, "Bloqueo", "%.0f%%" % (float(a["bloqueo"]) * 100.0),
			_d(float(a["bloqueo"]) * 100.0, float(b["bloqueo"]) * 100.0, "+%.0f%%"))
		if float(a["resist_estados"]) > 0.0 or float(b["resist_estados"]) > 0.0:
			_attr(filas, "Resist. estados", "+%.0f%%" % (float(a["resist_estados"]) * 100.0),
				_d(float(a["resist_estados"]) * 100.0, float(b["resist_estados"]) * 100.0, "+%.0f%%"))
	elif item is ArmorData:
		var ar := item as ArmorData
		var a := Upgrades.armor_piece_mods(ar, tm, rareza, mejoras)
		var b := Upgrades.armor_piece_mods(ar, tm, rareza, despues)
		_attr(filas, "Defensa", "%.1f" % float(a["def"]), _d(float(a["def"]), float(b["def"]), "+%.1f"))
		if float(a["evasion"]) > 0.0 or float(b["evasion"]) > 0.0:
			_attr(filas, "Evasión", "+%.0f%%" % (float(a["evasion"]) * 100.0),
				_d(float(a["evasion"]) * 100.0, float(b["evasion"]) * 100.0, "+%.0f%%"))
		if float(a["crit_resist"]) > 0.0 or float(b["crit_resist"]) > 0.0:
			_attr(filas, "Resist. crítico", "+%.0f%%" % (float(a["crit_resist"]) * 100.0),
				_d(float(a["crit_resist"]) * 100.0, float(b["crit_resist"]) * 100.0, "+%.0f%%"))
		if float(a["resist_estados"]) > 0.0 or float(b["resist_estados"]) > 0.0:
			_attr(filas, "Resist. estados", "+%.0f%%" % (float(a["resist_estados"]) * 100.0),
				_d(float(a["resist_estados"]) * 100.0, float(b["resist_estados"]) * 100.0, "+%.0f%%"))
	return filas

# La parte magica (baston y varita comparten): amplificacion, regen, casteo y coste de maná.
static func _filas_mejora_magia(filas: Array, base_amp: float, mp_regen: float, cast_base: float,
		tm: float, rareza: int, mejoras: Dictionary, despues: Dictionary) -> void:
	var a := Upgrades.magic_mods(base_amp, tm, rareza, mejoras)
	var b := Upgrades.magic_mods(base_amp, tm, rareza, despues)
	_attr(filas, "Amplif. magia", "×%.2f" % float(a["magic_amp"]), _d(float(a["magic_amp"]), float(b["magic_amp"]), "+%.2f"))
	_attr(filas, "Regen maná", "%.2f/turno" % (mp_regen * float(a["regen_mult"])),
		_d(mp_regen * float(a["regen_mult"]), mp_regen * float(b["regen_mult"]), "+%.2f"))
	_attr(filas, "Vel. casteo", "×%.2f" % (cast_base + float(a["cast_vel_add"])),
		_d(cast_base + float(a["cast_vel_add"]), cast_base + float(b["cast_vel_add"]), "+%.2f"))
	if float(a["mana_reduccion"]) > 0.0 or float(b["mana_reduccion"]) > 0.0:
		_attr(filas, "Coste de maná", "-%.0f%%" % (float(a["mana_reduccion"]) * 100.0),
			_d(float(a["mana_reduccion"]) * 100.0, float(b["mana_reduccion"]) * 100.0, "+%.0f%%"))

static func _attr(filas: Array, etiqueta: String, valor: String, delta: String) -> void:
	filas.append([etiqueta, valor, delta])

# Delta formateado entre parentesis (o "" si no cambia). `fmt` lleva un unico marcador para el
# numero de la DIFERENCIA (ej. "+%.1f"). El umbral evita pintar "(+0.00)" por ruido de redondeo.
static func _d(antes: float, despues: float, fmt: String) -> String:
	if absf(despues - antes) < 0.005:
		return ""
	return "(" + (fmt % (despues - antes)) + ")"


# Cuadricula de botones. Por defecto 2 columnas de 150x44 (la columna de la LISTA de items, que
# lleva nombres largos). Los selectores de material pasan mas columnas y botones mas bajos: sus
# etiquetas son cortas y con 2 por fila la lista se iba a lo alto sin necesidad.
static func cuadricula(vb: VBoxContainer, labels: Array, sel: int, pulsado: Callable,
		columnas: int = 2, tam: Vector2 = Vector2(150, 44)) -> void:
	var grid := GridContainer.new()
	grid.columns = maxi(1, columnas)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in labels.size():
		var b := Button.new()
		b.text = str(labels[i])
		b.toggle_mode = true
		b.button_pressed = (i == sel)
		b.clip_text = true
		b.custom_minimum_size = tam
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(pulsado.bind(i))
		grid.add_child(b)
	vb.add_child(grid)


# ------------------------------------------------------------
#  SELECTOR DE MATERIAL EN DOS NIVELES (tier -> sub-tier)
#  Lo usan los tres oficios que refinan: herrero (fundir/chapas/hebillas), carpintero (aserrar)
#  y peletero (curtir). Va aqui y no en cada menu porque son tres sitios con la MISMA lista y el
#  mismo problema.
#
#  Con los sub-tiers, una fila plana se iba a siete botones repitiendo el tier en cada uno
#  ("Madera comun (T1)", "Madera de veta (T1)", "Madera anillada (T1)", "Madera dura (T2)"...):
#  ilegible, y encima escondia que el tier es el eje gordo y el sub-tier el pequeño. En dos
#  niveles cada fila responde a UNA pregunta: primero de que gama, luego cual de ella.
#
#  La fila de arriba lleva el tier ("Madera T1"); la de abajo ya NO lo repite, que para eso
#  acabas de elegirlo.
# ------------------------------------------------------------

# 4 por fila: las etiquetas ya no repiten el tier, asi que son cortas y caben. Con 2 por fila la
# lista se iba a lo alto sin necesidad y empujaba fuera las filas de calidad, que es lo que de
# verdad vienes a pulsar.
const COLUMNAS_SELECTOR := 4
const TAM_SELECTOR := Vector2(120, 32)


# Los tiers presentes en una lista de MaterialData, ordenados. Es lo que pinta la fila de arriba.
static func tiers_de(mats: Array) -> Array:
	var vistos: Dictionary = {}
	for m in mats:
		if m != null:
			vistos[int((m as MaterialData).tier)] = true
	var out: Array = vistos.keys()
	out.sort()
	return out


# Los materiales de UN tier, ordenados por banda (base primero). Es la fila de abajo.
static func del_tier(mats: Array, tier: int) -> Array:
	var out: Array = []
	for m in mats:
		if m != null and int((m as MaterialData).tier) == tier:
			out.append(m)
	out.sort_custom(func(a, b): return int(a.mejora_min) < int(b.mejora_min))
	return out


# Pinta las DOS filas y devuelve el material elegido (null si la lista viene vacia).
# `nombre_gama` = como se llama la familia en la fila de arriba ("Madera", "Metal", "Piel").
# `tier_sel` / `sub_sel` = lo que hay elegido ahora; `on_tier` / `on_sub` reciben el indice nuevo.
static func selector_material(vb: VBoxContainer, mats: Array, nombre_gama: String,
		tier_sel: int, sub_sel: int, on_tier: Callable, on_sub: Callable) -> MaterialData:
	if mats.is_empty():
		return null
	var tiers: Array = tiers_de(mats)
	var t: int = int(tiers[clampi(tier_sel, 0, tiers.size() - 1)])

	var etiquetas_tier: Array = []
	for x in tiers:
		etiquetas_tier.append("%s  T%d" % [nombre_gama, int(x)])
	cuadricula(vb, etiquetas_tier, clampi(tier_sel, 0, tiers.size() - 1), on_tier,
		COLUMNAS_SELECTOR, TAM_SELECTOR)

	# La fila de abajo solo se pinta si ese tier tiene MAS DE UNO: con un solo sub-tier (hoy el
	# acero, o cualquier tier que aun no se haya desdoblado) una fila de un boton solo estorba.
	var subs: Array = del_tier(mats, t)
	if subs.size() > 1:
		var etiquetas_sub: Array = []
		for m in subs:
			etiquetas_sub.append((m as MaterialData).nombre)
		cuadricula(vb, etiquetas_sub, clampi(sub_sel, 0, subs.size() - 1), on_sub,
			COLUMNAS_SELECTOR, TAM_SELECTOR)
	return subs[clampi(sub_sel, 0, subs.size() - 1)] as MaterialData


# Stepper editable: −  [ n ]  +  con el numero ESCRIBIBLE (no solo con los botones). −/+ y escribir +
# Enter (o salir del campo) actualizan el numero, CAPADO a [minv, maxv]. Si `on_set` es valido, se
# llama con el nuevo valor en cada cambio (para guardar en la seleccion y rebuildear: OJO, que ese
# on_set NO rebuildee si el valor no cambia, o focus_exited durante el rebuild se realimenta).
# Si maxv <= minv no hay nada que elegir: todo va disabled (gris). DEVUELVE el LineEdit, para los
# casos (refinar) que leen la cantidad en el momento de pulsar "Crear" en vez de guardarla.
static func stepper(parent: Node, valor: int, minv: int, maxv: int, on_set: Callable = Callable()) -> LineEdit:
	var vacio: bool = maxv <= minv
	var v: int = clampi(valor, minv, maxv) if not vacio else minv
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)

	var campo := LineEdit.new()
	var menos := Button.new()
	var mas := Button.new()

	var aplicar := func(nuevo: int) -> void:
		var c: int = clampi(nuevo, minv, maxv)
		campo.text = str(c)
		menos.disabled = vacio or c <= minv
		mas.disabled = vacio or c >= maxv
		if on_set.is_valid():
			on_set.call(c)

	menos.text = "−"
	menos.custom_minimum_size = Vector2(30, 0)
	menos.disabled = vacio or v <= minv
	menos.focus_mode = Control.FOCUS_NONE
	menos.pressed.connect(func() -> void: aplicar.call(int(campo.text) - 1))
	caja.add_child(menos)

	campo.text = str(v)
	campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	campo.custom_minimum_size = Vector2(46, 0)
	campo.editable = not vacio
	campo.select_all_on_focus = true
	campo.max_length = 6
	campo.text_submitted.connect(func(t: String) -> void: aplicar.call(int(t)))
	campo.focus_exited.connect(func() -> void: aplicar.call(int(campo.text)))
	caja.add_child(campo)

	mas.text = "+"
	mas.custom_minimum_size = Vector2(30, 0)
	mas.disabled = vacio or v >= maxv
	mas.focus_mode = Control.FOCUS_NONE
	mas.pressed.connect(func() -> void: aplicar.call(int(campo.text) + 1))
	caja.add_child(mas)

	parent.add_child(caja)
	return campo


# Fila de un refinado: etiqueta + stepper editable + boton "Crear". `salen` = maximo que puedes hacer
# (0 = en gris, no se puede). Al pulsar Crear se lee la cantidad del stepper y se llama a `crear(n)`.
# Reemplaza el viejo "Hacer 1 / Hacer todo": ahora eliges cuantos (escribiendo o con −/+) y creas.
static func fila_refino(parent: Node, etiqueta: String, salen: int, crear: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = etiqueta
	l.custom_minimum_size = Vector2(240, 0)
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92) if salen > 0 else Color(0.6, 0.63, 0.7))
	row.add_child(l)
	var campo: LineEdit = stepper(row, 1 if salen >= 1 else 0, 0, salen)
	var b := Button.new()
	b.text = "Crear"
	b.disabled = salen < 1
	b.pressed.connect(func() -> void:
		var n: int = clampi(int(campo.text), 1, salen)
		if n >= 1:
			crear.call(n))
	row.add_child(b)
	parent.add_child(row)
