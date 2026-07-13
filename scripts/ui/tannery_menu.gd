# ============================================================
#  tannery_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del PELETERO: CURTIR el cuero crudo del baul (cuero curtido = lo unico que admite la
#  forja). Misma regla que el herrero al fundir: NO se mezclan calidades, hacen falta N pieles
#  de la MISMA calidad y sale un cuero de esa calidad. Sube el contador de Peleteria.
#
#  Cuando existan las MOCHILAS (Game.extra_capacity, hoy placeholder), se confeccionan aqui.
#
#  La math vive en Game/Forge; aqui solo se pinta.
# ============================================================

extends CanvasLayer

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

# De mejor a peor (el enum de calidad NO esta ordenado: PURO se añadio al final).
const CALIDADES := [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
	MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]

var _root: Control = null
var _content: VBoxContainer = null
var _aviso: String = ""
var _aviso_ok: bool = true


func _ready() -> void:
	layer = 91
	add_to_group("tannery_menu")

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 16
	hb.offset_top = 16
	hb.offset_right = -16
	hb.offset_bottom = -16
	hb.add_theme_constant_override("separation", 18)
	_root.add_child(hb)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(230, 0)
	side.add_theme_constant_override("separation", 6)
	hb.add_child(side)

	var titulo := Label.new()
	titulo.text = "PELETERO"
	titulo.add_theme_color_override("font_color", AMBAR)
	titulo.add_theme_font_size_override("font_size", 18)
	side.add_child(titulo)
	var nota := Label.new()
	nota.text = "Curte las pieles que traigas de la mazmorra. Sin cuero curtido no hay armadura que valga."
	nota.add_theme_color_override("font_color", GRIS)
	nota.add_theme_font_size_override("font_size", 11)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(nota)
	side.add_child(HSeparator.new())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var cerrar := Button.new()
	cerrar.text = "✕ Cerrar  (Esc)"
	cerrar.custom_minimum_size = Vector2(0, 34)
	cerrar.pressed.connect(_cerrar)
	side.add_child(cerrar)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 16)
	hb.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_aviso = ""
	_root.visible = true
	Game.inventory_open = true
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.inventory_open = false


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()

	if _aviso != "":
		var a := Label.new()
		a.text = _aviso
		a.add_theme_color_override("font_color", VERDE if _aviso_ok else ROJO)
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(a)

	var crudo: MaterialData = Game.cuero_crudo()
	var curtido: MaterialData = Game.cuero_forja()

	_title("CURTIR")
	_note("%d pieles de la MISMA calidad = 1 cuero curtido de esa calidad. No se mezclan: juntando pieles rotas no sale una buena. Solo la Peletería puede regalarte un escalón." % Forge.CUERO_POR_CURTIDO)
	_content.add_child(HSeparator.new())

	var hubo: bool = false
	for cal in CALIDADES:
		if cal == MaterialItem.Calidad.PURO:
			continue   # no hay piel pura: el PURO solo sale del curtido
		var tengo: int = Game.items_calidad_en_hogar(crudo, int(cal))
		if tengo <= 0:
			continue
		hubo = true
		var salen: int = Game.refinados_posibles(crudo, int(cal), Forge.CUERO_POR_CURTIDO)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = "%s:  %d piel%s  →  %d cuero%s" % [
			_cal_txt(int(cal)), tengo, "" if tengo == 1 else "es", salen, "" if salen == 1 else "s"]
		l.custom_minimum_size = Vector2(320, 0)
		l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92) if salen > 0 else GRIS)
		row.add_child(l)
		var b1 := Button.new()
		b1.text = "Curtir 1"
		b1.disabled = salen < 1
		b1.pressed.connect(_on_curtir.bind(int(cal), 1))
		row.add_child(b1)
		var bt := Button.new()
		bt.text = "Curtir todo (%d)" % salen
		bt.disabled = salen < 1
		bt.pressed.connect(_on_curtir.bind(int(cal), salen))
		row.add_child(bt)
		_content.add_child(row)
	if not hubo:
		_note("No tienes pieles guardadas en el Hogar. Las sueltan los bichos con pelo; guárdalas al volver.")

	_content.add_child(HSeparator.new())
	_title("EN EL ALMACÉN")
	var alguno: bool = false
	for cal in CALIDADES:
		var n: int = Game.items_calidad_en_hogar(curtido, int(cal))
		if n > 0:
			alguno = true
			_row("%s (%s)" % [curtido.nombre, _cal_txt(int(cal))], "%d" % n)
	if not alguno:
		_note("Ningún cuero curtido todavía.")

	_content.add_child(HSeparator.new())
	_row("Peletería", "%s de oficio%s" % [
		str(snappedf(Game.peleteria_exp, 0.1)),
		"" if Game.habilidad_peleteria else "   (habilidad aún bloqueada)"])
	if not Game.habilidad_peleteria:
		_note("El progreso se guarda desde ya: cuando se desbloquee, tirará por sacar el cuero un escalón por encima de la piel que metas.")
	_note("Aquí se confeccionarán también las mochilas, cuando las haya.")


func _on_curtir(cal: int, veces: int) -> void:
	var n: int = Game.curtir(cal, veces)
	if n > 0:
		_decir("Curtes %d cuero%s de calidad %s." % [n, "" if n == 1 else "s", _cal_txt(cal).to_lower()])
	else:
		_decir("No te llegan las pieles.", false)
	_rebuild()


func _decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


func _cal_txt(cal: int) -> String:
	match cal:
		MaterialItem.Calidad.PURO: return "Puro"
		MaterialItem.Calidad.INTACTO: return "Intacto"
		MaterialItem.Calidad.NORMAL: return "Normal"
		MaterialItem.Calidad.DANADO: return "Dañado"
		_: return "Roto"


func _title(txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", AMBAR)
	l.add_theme_font_size_override("font_size", 16)
	_content.add_child(l)


func _row(etiqueta: String, valor: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(200, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	_content.add_child(row)


func _note(txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", GRIS)
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(l)
