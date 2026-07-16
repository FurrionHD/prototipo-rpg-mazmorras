# ============================================================
#  craft_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de la BOTICARIA: fabricar/mejorar pociones con los materiales del baul del Hogar.
#  Lo abre la Boticaria del pueblo (boticaria.gd -> abrir()). No hay tecla propia: se
#  entra por el NPC. Congela al jugador via Game.inventory_open mientras esta abierto.
#
#  Toda la MATH vive en Game (recetas_boticaria / seleccion_valida / craftear_con); aqui solo
#  se pinta el estado y se derivan los numeros de los campos (nunca escritos a mano).
# ============================================================

extends CanvasLayer

var _root: Control = null
var _header: VBoxContainer = null    # cabecera FIJA
var _list: VBoxContainer = null      # botones de receta (izquierda), con su scroll
var _detail: VBoxContainer = null    # detalle de la receta seleccionada (derecha), con el suyo
var _aviso_lbl: Label = null         # linea de aviso (lo fabricado), como forja/peletero
var _aviso: String = ""
var _aviso_ok: bool = true
var _recetas: Array = []
var _sel: int = 0
# SELECCION de materiales de la receta actual: Array paralelo a receta.ingredientes; cada
# entrada un {calidad: cantidad}. Es lo que el jugador elige a mano con los contadores. Se
# resetea al cambiar de receta, NO en cada _rebuild (si no, borraria lo que va poniendo).
var _seleccion: Array = []

const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const AMBAR := Color(0.95, 0.72, 0.36)


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("craft_menu")

	# Misma forma que el resto de menus: cabecera fija, lista con su scroll (las recetas) y
	# detalle con el suyo (los contadores de material, que se hacen largos).
	var m: Dictionary = MenuScaffold.construir(self, "BOTICARIA",
		"Fabrica pociones con lo que tengas guardado en el Hogar. Las mejoras (+1, +2) consumen la poción del escalón anterior.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_list = m["lista"]
	_detail = m["content"]
	_aviso_lbl = m["aviso"]   # el scaffold ya la crea; la forja y el peletero tambien la usan


func abrir() -> void:
	# No abrir sobre un combate/extraccion ni con el panel DEBUG abierto.
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_recetas = Game.recetas_boticaria()
	_sel = 0
	_aviso = ""
	_reset_seleccion()
	_root.visible = true
	Game.abrir_menu()   # para el mundo entero mientras el menu esta abierto
	_rebuild()


# Vacia la seleccion y la dimensiona a los ingredientes de la receta actual (una entrada
# {} por ingrediente). Se llama al abrir y al cambiar de receta, nunca en _rebuild.
func _reset_seleccion() -> void:
	_seleccion = []
	if _recetas.is_empty():
		return
	var r: RecipeData = _recetas[clampi(_sel, 0, _recetas.size() - 1)]
	for _ing in r.ingredientes:
		_seleccion.append({})


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for zona in [_header, _list, _detail]:
		for c in zona.get_children():
			c.queue_free()
	MenuScaffold.titulo(_header, "RECETAS")
	_header.add_child(HSeparator.new())
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	if _recetas.is_empty():
		var l := Label.new()
		l.text = "(no hay recetas)"
		_detail.add_child(l)
		return
	_sel = clampi(_sel, 0, _recetas.size() - 1)

	for i in _recetas.size():
		var r: RecipeData = _recetas[i]
		var b := Button.new()
		var puede: bool = _hay_material_para(r)
		b.text = "%s %s" % ["✓" if puede else "·", r.nombre()]
		b.toggle_mode = true
		b.button_pressed = (i == _sel)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 32)
		b.add_theme_color_override("font_color", VERDE if puede else Color(0.75, 0.77, 0.82))
		b.pressed.connect(_pick.bind(i))
		_list.add_child(b)

	_build_detail(_recetas[_sel])


func _pick(i: int) -> void:
	_sel = i
	_aviso = ""            # cambiar de receta borra el aviso de la anterior (como la forja)
	_reset_seleccion()   # otra receta = empezar de cero la eleccion de materiales
	_rebuild()


func _decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


# ¿Hay material EN PRINCIPIO para esta receta? (para el ✓ de la lista, sin mirar la
# seleccion actual): poción base si es mejora + unidades totales suficientes por ingrediente.
func _hay_material_para(r: RecipeData) -> bool:
	if r == null or r.resultado == null:
		return false
	if r.es_mejora() and int(Game.consumables.get(r.pocion_base, 0)) <= 0:
		return false
	for ing in r.ingredientes:
		if ing == null or ing.material == null:
			continue
		if Game.unidades_material_en_hogar(ing.material) < ing.unidades:
			return false
	return true


func _build_detail(r: RecipeData) -> void:
	var maxhp: float = Game.player_max_hp()
	var maxmp: float = Game.player_max_mp()

	var t := Label.new()
	t.text = r.nombre()
	t.add_theme_color_override("font_color", AMBAR)
	t.add_theme_font_size_override("font_size", 16)
	_detail.add_child(t)

	if r.resultado != null:
		_fila(r.resultado.resumen(maxhp, maxmp), Color(0.85, 0.88, 0.92))
		if r.resultado.descripcion != "":
			var d := Label.new()
			d.text = r.resultado.descripcion
			d.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
			d.add_theme_font_size_override("font_size", 11)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail.add_child(d)

	if _seleccion.size() != r.ingredientes.size():
		_reset_seleccion()

	_detail.add_child(HSeparator.new())
	var cab := Label.new()
	cab.text = "Elige los materiales:"
	cab.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	_detail.add_child(cab)

	# Poción base (si es una mejora): coste FIJO, no se elige.
	if r.es_mejora():
		var tengo_p: int = int(Game.consumables.get(r.pocion_base, 0))
		_fila_coste("1× %s" % r.pocion_base.nombre, tengo_p, 1)

	# Ingredientes: por cada uno, un contador -/+ por cada calidad que tengas en el baul.
	# PURO no lo suelta la mazmorra (solo sale de refinar con oficio), pero si algun dia una
	# receta pide un refinado, aqui esta: mejor tenerlo que descubrir que no se puede elegir.
	var cals: Array = [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
		MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]
	var cal_nom: Dictionary = {
		MaterialItem.Calidad.PURO: "Puro",
		MaterialItem.Calidad.INTACTO: "Intacto",
		MaterialItem.Calidad.NORMAL: "Normal",
		MaterialItem.Calidad.DANADO: "Dañado",
	}
	for i in r.ingredientes.size():
		var ing = r.ingredientes[i]
		if ing == null or ing.material == null:
			continue
		var elegidas: int = _uds_sel(i)
		var cubre: int = elegidas / ing.unidades   # cuantas pociones cubre este ingrediente
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var nm := Label.new()
		nm.text = "%s · %d uds/poción" % [ing.material.nombre, ing.unidades]
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		var tot := Label.new()
		tot.text = "%d uds (cubre %d)" % [elegidas, cubre]
		tot.add_theme_color_override("font_color", VERDE if cubre >= 1 else ROJO)
		head.add_child(tot)
		_detail.add_child(head)

		for cal in cals:
			var disp: int = Game.items_calidad_en_hogar(ing.material, int(cal))
			if disp <= 0:
				continue   # no tienes de esta calidad: no la muestres
			var cur: int = int((_seleccion[i] as Dictionary).get(cal, 0))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var lab := Label.new()
			lab.text = "   %s (x%d)" % [cal_nom.get(cal, "?"), disp]
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lab)
			var minus := Button.new()
			minus.text = "−"
			minus.custom_minimum_size = Vector2(30, 0)
			minus.pressed.connect(_mat_delta.bind(i, cal, -1))
			row.add_child(minus)
			var cnt := Label.new()
			cnt.text = str(cur)
			cnt.custom_minimum_size = Vector2(26, 0)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(cnt)
			var plus := Button.new()
			plus.text = "+"
			plus.custom_minimum_size = Vector2(30, 0)
			plus.pressed.connect(_mat_delta.bind(i, cal, 1))
			row.add_child(plus)
			_detail.add_child(row)

	var uds := Label.new()
	uds.text = "(puro = 4 uds · intacto = 3 · normal = 2 · dañado = 1.  Mejor material = más probabilidad de fabricar 2)"
	uds.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	uds.add_theme_font_size_override("font_size", 10)
	uds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(uds)

	# Lo que se GASTA de verdad: si te pasas, el sobrante se queda en el Hogar, y lo que sobre
	# del ultimo trozo puede volver. Mismo trato que en la forja.
	var gasto: Array = Game.gasto_crafteo(r, _seleccion)
	_aviso_recorte(r, gasto)

	# Bonus de DOBLE segun lo que se va a GASTAR (en vivo). Es POR poción fabricada.
	var prob: float = Game.prob_doble_desde_seleccion(r, gasto)
	var bono := Label.new()
	bono.text = "Fabricar 2 de golpe: %d%%  (por poción)" % roundi(prob * 100.0)
	bono.add_theme_color_override("font_color", VERDE if prob > 0.0 else Color(0.55, 0.58, 0.65))
	bono.add_theme_font_size_override("font_size", 12)
	_detail.add_child(bono)

	_detail.add_child(HSeparator.new())
	# Botones de conveniencia.
	var acc := HBoxContainer.new()
	acc.add_theme_constant_override("separation", 8)
	var auto := Button.new()
	auto.text = "Auto (peor primero)"
	auto.pressed.connect(_on_auto)
	acc.add_child(auto)
	var limpiar := Button.new()
	limpiar.text = "Limpiar"
	limpiar.pressed.connect(_on_limpiar)
	acc.add_child(limpiar)
	_detail.add_child(acc)

	# Cuantas pociones saldran = lo que cubra la selección (mete 6 uds en una de 3 -> 2).
	var n: int = Game.pociones_de_seleccion(r, _seleccion)
	var fab := Button.new()
	fab.text = "Fabricar  (%d poción%s)" % [n, "" if n == 1 else "es"] if n >= 1 else "Elige materiales suficientes"
	fab.disabled = n < 1
	fab.custom_minimum_size = Vector2(0, 36)
	fab.pressed.connect(_on_fabricar)
	_detail.add_child(fab)


# Avisa de lo que se va a gastar DE VERDAD (el recorte) por cada ingrediente: lo que sobra se
# queda en el Hogar, y las unidades que sobren del ultimo trozo pueden volver. Solo se pinta si
# hay algo que decir (te has pasado, o el material no cuadra justo con la receta).
func _aviso_recorte(r: RecipeData, gasto: Array) -> void:
	var n: int = Game.pociones_de_seleccion(r, _seleccion)
	if n < 1:
		return
	for i in mini(gasto.size(), r.ingredientes.size()):
		var ing = r.ingredientes[i]
		if ing == null or ing.material == null:
			continue
		var elegidas: int = Game.uds_seleccion(_seleccion[i])
		var gastadas: int = Game.uds_seleccion(gasto[i])
		var necesita: int = n * ing.unidades
		var partes: PackedStringArray = []
		if gastadas < elegidas:
			partes.append("de %s se gastan %d uds y el resto se queda en el Hogar" % [
				ing.material.nombre.to_lower(), gastadas])
		var sobra: int = gastadas - necesita
		if sobra > 0:
			partes.append("sobran %d uds del recorte: vuelven como %d dañado(s)" % [sobra, sobra])
		if not partes.is_empty():
			var l := Label.new()
			l.text = "  " + "; ".join(partes) + "."
			l.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
			l.add_theme_font_size_override("font_size", 11)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_detail.add_child(l)


# Fila simple de texto en el detalle.
func _fila(txt: String, col: Color) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(l)


# Fila de coste "texto ..... tengo/necesito", en verde si llega, rojo si no.
func _fila_coste(txt: String, tengo: int, necesito: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = txt
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(k)
	var v := Label.new()
	v.text = "%d / %d" % [tengo, necesito]
	v.add_theme_color_override("font_color", VERDE if tengo >= necesito else ROJO)
	row.add_child(v)
	_detail.add_child(row)


# Unidades sumadas ya elegidas para el ingrediente i (intacto 3 / normal 2 / dañado 1).
func _uds_sel(i: int) -> int:
	var d: Dictionary = _seleccion[i]
	var u: int = 0
	for cal in d:
		u += int(d[cal]) * _uds(int(cal))
	return u

func _uds(cal: int) -> int:
	return MaterialItem.crear(null, cal).unidades_crafteo()


# Sube/baja el contador de (ingrediente i, calidad cal), acotado a lo que tienes en el baul.
func _mat_delta(i: int, cal: int, delta: int) -> void:
	var ing = _recetas[_sel].ingredientes[i]
	if ing == null or ing.material == null:
		return
	var disp: int = Game.items_calidad_en_hogar(ing.material, int(cal))
	var d: Dictionary = _seleccion[i]
	var nuevo: int = clampi(int(d.get(cal, 0)) + delta, 0, disp)
	if nuevo <= 0:
		d.erase(cal)
	else:
		d[cal] = nuevo
	_rebuild()


func _on_auto() -> void:
	_seleccion = Game.seleccion_auto_peor(_recetas[_sel])
	_rebuild()


func _on_limpiar() -> void:
	_reset_seleccion()
	_rebuild()


func _on_fabricar() -> void:
	var receta: RecipeData = _recetas[_sel]
	# El nombre ANTES de fabricar/resetear (la seleccion se limpia despues).
	var nombre: String = receta.resultado.nombre if receta.resultado != null else "poción"
	var total: int = Game.craftear_con(receta, _seleccion)
	if total > 0:
		_decir("Fabricas %d × %s. Está en tu bolsa." % [total, nombre])
		_reset_seleccion()   # los materiales cambiaron: empezar limpio
	else:
		_decir("No te llega el material.", false)
	_rebuild()
