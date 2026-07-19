# ============================================================
#  tannery_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del PELETERO. Tres pestañas:
#    1) CURTIR   - cuero crudo -> CUERO CURTIDO (lo unico que admite la forja).
#    2) CORREAS  - cuero curtido -> CORREAS (los tirantes de la mochila).
#    3) MOCHILAS - hebillas (del herrero) + correas + cuero curtido -> MOCHILA.
#
#  Curtir y hacer correas son REFINADOS: NO se mezclan calidades (N piezas de la MISMA calidad
#  dan una de esa calidad); solo la Peleteria puede regalarte un escalon. Coser la mochila, en
#  cambio, SI mezcla: la calidad media tira su RAREZA, que es lo unico que la diferencia (no
#  lleva mejoras). El TIER lo ponen las hebillas.
#
#  La math vive en Game/Forge; aqui solo se pinta.
# ============================================================

extends CanvasLayer

const TABS := ["Curtir", "Correas", "Mochilas"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

# De mejor a peor (el enum de calidad NO esta ordenado: PURO se añadio al final).
const CALIDADES := [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
	MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]

var _root: Control = null
var _header: VBoxContainer = null    # cabecera FIJA
var _content: VBoxContainer = null   # lo que se desplaza
var _aviso_lbl: Label = null         # linea de aviso, de altura fija (no empuja el titulo)
var _tab_buttons: Array = []
var _aviso: String = ""
var _aviso_ok: bool = true

var _tab: int = 0

# --- MOCHILAS ---
var _heb_idx: int = 0                # metal de las hebillas (fija el tier)
var _sel_heb: Dictionary = {}
var _sel_cor: Dictionary = {}
var _sel_cue: Dictionary = {}


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("tannery_menu")

	var m: Dictionary = MenuScaffold.construir(self, "PELETERO",
		"Curte las pieles que traigas de la mazmorra. Sin cuero curtido no hay armadura que valga... ni mochila que te deje cargar con el botín.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_aviso_lbl = m["aviso"]
	# El peletero no tiene cuadricula de piezas: una sola columna, a lo ancho.
	(m["lista_scroll"] as ScrollContainer).visible = false

	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		(m["side"] as VBoxContainer).add_child(b)
		_tab_buttons.append(b)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = 0
	_aviso = ""
	_limpiar()
	_root.visible = true
	Game.abrir_menu()   # para el mundo entero mientras el menu esta abierto
	_rebuild()


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


func _limpiar() -> void:
	_sel_heb = {}
	_sel_cor = {}
	_sel_cue = {}


func _on_tab(i: int) -> void:
	_tab = i
	_aviso = ""
	_limpiar()
	_rebuild()


func _rebuild() -> void:
	for zona in [_header, _content]:
		for c in zona.get_children():
			c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)

	match _tab:
		0: _build_refinar(false)   # piel -> cuero curtido
		1: _build_refinar(true)    # cuero curtido -> correa
		2: _build_mochilas()


# ============================================================
#  CURTIR y CORREAS: el mismo refinado, distinto material
# ============================================================

func _build_refinar(correas: bool) -> void:
	var origen: MaterialData = Game.cuero_forja() if correas else Game.cuero_crudo()
	var destino: MaterialData = Game.correa() if correas else Game.cuero_forja()
	var por_uno: int = Forge.CUERO_POR_CORREA if correas else Forge.CUERO_POR_CURTIDO

	MenuScaffold.titulo(_header, "HACER CORREAS" if correas else "CURTIR")
	if correas:
		MenuScaffold.nota(_header, "%d cueros curtidos de la MISMA calidad = 1 correa. Son los tirantes de la mochila: sin ellas, un fardo de cuero es un fardo de cuero." % por_uno)
	else:
		MenuScaffold.nota(_header, "%d pieles de la MISMA calidad = 1 cuero curtido de esa calidad. No se mezclan: juntando pieles rotas no sale una buena. Solo la Peletería puede regalarte un escalón." % por_uno)
	_header.add_child(HSeparator.new())

	# Fila-selector de tier, igual que el herrero (Fundir) y el carpintero (Tablones): un botón por
	# cada cuero de esta categoria, mostrado SIEMPRE (aunque tengas 0), con su tier. Hoy el cuero es
	# de un solo tier, asi que la fila tiene un boton; si aparecen mas, crece sola. Da la consistencia
	# visual que faltaba (antes esto iba directo a las filas de calidad y se veia distinto).
	var origenes: Array = [origen]
	var fila := GridContainer.new()
	fila.columns = 2
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for o in origenes:
		var mat: MaterialData = o as MaterialData
		var b := Button.new()
		b.text = "%s  (T%d)" % [mat.nombre, mat.tier]
		b.toggle_mode = true
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = (mat == origen)
		b.custom_minimum_size = Vector2(0, 32)
		fila.add_child(b)
	_content.add_child(fila)
	_content.add_child(HSeparator.new())
	_row("Sale", "%s  ·  Tier %d" % [destino.nombre, destino.tier])

	var tengo_algo: bool = false
	for cal in CALIDADES:
		var tengo: int = Game.items_calidad_en_hogar(origen, int(cal))
		if int(cal) == MaterialItem.Calidad.PURO and tengo <= 0:
			continue
		tengo_algo = tengo_algo or tengo > 0
		var salen: int = Game.refinados_posibles(origen, int(cal), por_uno)
		var c: int = int(cal)
		MenuScaffold.fila_refino(_content, "%s  ·  tienes %d  (máx %d)" % [_cal_txt(c), tengo, salen],
			salen, func(n: int) -> void: _on_refinar(correas, c, n))
	if not tengo_algo:
		if correas:
			_note("No tienes cuero curtido. Cúrtelo primero en la pestaña Curtir.")
		else:
			_note("No tienes pieles guardadas en el Hogar. Las sueltan los bichos con pelo; guárdalas al volver.")

	_content.add_child(HSeparator.new())
	MenuScaffold.titulo(_content, "EN EL ALMACÉN")
	var alguno: bool = false
	for cal in CALIDADES:
		var n: int = Game.items_calidad_en_hogar(destino, int(cal))
		if n > 0:
			alguno = true
			_row("%s (%s)" % [destino.nombre, _cal_txt(int(cal))], str(n))
	if not alguno:
		_note("Ningún %s todavía." % destino.nombre.to_lower())

	_estado_peleteria()


func _on_refinar(correas: bool, cal: int, veces: int) -> void:
	var n: int = Game.hacer_correa(cal, veces) if correas else Game.curtir(cal, veces)
	if n > 0:
		_decir("Sacas %d %s de calidad %s." % [n, "correa(s)" if correas else "cuero(s)",
			_cal_txt(cal).to_lower()])
	else:
		_decir("No te llega el material.", false)
	_rebuild()


# ============================================================
#  MOCHILAS
# ============================================================

func _build_mochilas() -> void:
	MenuScaffold.titulo(_header, "COSER UNA MOCHILA")
	MenuScaffold.nota(_header, "Lo único que sube tu capacidad de carga. El METAL de las hebillas le pone el tier; la CALIDAD de lo que metas tira su rareza, que es lo único que la diferencia (una mochila no se mejora con núcleos). Y la Fuerza la aprovecha: multiplica el zurrón entero, mochila incluida.")
	_header.add_child(HSeparator.new())

	# Solo los metales que conoces (mismo criterio que el herrero: ver Game.materiales_vistos).
	var hebillas: Array = Game.hebillas_conocidas()
	if hebillas.is_empty():
		MenuScaffold.nota(_header, "No conoces ningún metal, y sin hebillas no hay mochila que valga. Pica una veta y pásate por el herrero.")
		return
	_heb_idx = clampi(_heb_idx, 0, hebillas.size() - 1)
	var heb: MaterialData = hebillas[_heb_idx]
	var coste: Dictionary = Game.MOCHILA_COSTE

	# --- Metal de las hebillas: fija el TIER ---
	var fila := GridContainer.new()
	fila.columns = 2
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in hebillas.size():
		var h: MaterialData = hebillas[i]
		var tengo: int = Game.unidades_material_en_hogar(h)
		var b := Button.new()
		b.text = "%s (T%d) · %d uds" % [h.nombre, h.tier, tengo]
		b.toggle_mode = true
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = (i == _heb_idx)
		b.disabled = tengo <= 0
		b.pressed.connect(_on_hebillas.bind(i))
		fila.add_child(b)
	_content.add_child(fila)

	var tier: int = Forge.tier_de_metal(heb)
	_row("Tier", "T%d  (por las hebillas de %s)" % [tier, heb.nombre.to_lower()])

	# --- Contadores de los tres materiales ---
	_content.add_child(HSeparator.new())
	_contadores(heb, _sel_heb, int(coste["hebillas"]))
	_contadores(Game.correa(), _sel_cor, int(coste["correa"]))
	_contadores(Game.cuero_forja(), _sel_cue, int(coste["cuero"]))
	_note("Puro = 4 unidades · intacto = 3 · normal = 2 · dañado = 1. Meter buen material no abarata la mochila: mejora la RAREZA, y con ella lo que te cabe dentro.")

	# --- Rareza EN VIVO, y lo que daria cada una ---
	_content.add_child(HSeparator.new())
	var score: float = Game.score_mochila(heb, _sel_heb, _sel_cor, _sel_cue)
	MenuScaffold.titulo(_content, "Rareza que puede salir")
	var probs: Array = Forge.probs_rareza(score)
	for i in probs.size():
		var p: float = float(probs[i])
		if p <= 0.0:
			continue
		_row(Upgrades.rareza_nombre(i), "%s%%   →  +%.0f de carga" % [
			str(snappedf(p * 100.0, 0.1)), _carga_de(tier, i)])
	_row("Llevas ahora", "%d de capacidad" % roundi(Game.capacidad_carga()))

	_content.add_child(HSeparator.new())
	var ok: bool = Game.mochila_valida(heb, _sel_heb, _sel_cor, _sel_cue)
	var b_hacer := Button.new()
	b_hacer.text = "Coser la mochila" if ok else "Faltan materiales"
	b_hacer.disabled = not ok
	b_hacer.custom_minimum_size = Vector2(0, 36)
	b_hacer.pressed.connect(_on_coser)
	_content.add_child(b_hacer)

	_estado_peleteria()


# Lo que daria una mochila de este tier y esta rareza (derivado, nunca escrito a mano).
func _carga_de(tier: int, rareza: int) -> float:
	return Game.mochila_base().capacidad * Game.mochila_tier_factor(tier) \
		* Upgrades.rareza_mult_capacidad(rareza)


func _on_hebillas(i: int) -> void:
	_heb_idx = i
	_sel_heb = {}
	_rebuild()


func _on_coser() -> void:
	var hebillas: Array = Game.hebillas_conocidas()
	if hebillas.is_empty():
		return
	var heb: MaterialData = hebillas[clampi(_heb_idx, 0, hebillas.size() - 1)]
	var m: Resource = Game.fabricar_mochila(heb, _sel_heb, _sel_cor, _sel_cue)
	if m != null:
		_decir("Coses %s: +%.0f de carga. Equípala en el menú de personaje [C]." % [
			Game.item_display_name(m), Game.capacidad_mochila(m as BackpackData)])
	else:
		_decir("Te faltan materiales.", false)
	_limpiar()
	_rebuild()


# Fila "material: −  n  +" por cada calidad que tengas en el baul (igual que en el herrero).
func _contadores(mat: MaterialData, sel: Dictionary, necesita: int) -> void:
	var uds: int = Game.uds_seleccion(sel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = mat.nombre
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = "%d / %d unidades" % [uds, necesita]
	v.add_theme_color_override("font_color", VERDE if uds >= necesita else ROJO)
	row.add_child(v)
	_content.add_child(row)

	# Si te pasas, decir lo que se gasta DE VERDAD (el resto se queda en el Hogar).
	if uds >= necesita and necesita > 0:
		var gasto: Dictionary = Game.recortar_seleccion(sel, necesita)
		var gastadas: int = Game.uds_seleccion(gasto)
		var sobra: int = gastadas - necesita
		var partes: PackedStringArray = []
		if uds > gastadas:
			partes.append("se gastan %d uds y el resto se queda en el Hogar" % gastadas)
		if sobra > 0:
			partes.append("sobran %d uds del recorte: vuelven como %d dañado(s)" % [sobra, sobra])
		if not partes.is_empty():
			_note("   " + "; ".join(partes) + ".")

	var hubo: bool = false
	for cal in CALIDADES:
		var disp: int = Game.items_calidad_en_hogar(mat, int(cal))
		if disp <= 0:
			continue
		hubo = true
		var cur: int = int(sel.get(cal, 0))
		var ci: int = int(cal)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var lab := Label.new()
		lab.text = "   %s  (tienes %d)" % [_cal_txt(ci), disp]
		lab.custom_minimum_size = Vector2(190, 0)
		r.add_child(lab)
		MenuScaffold.stepper(r, cur, 0, disp, func(n: int) -> void: _set_sel_mat(sel, ci, disp, n))
		_content.add_child(r)
	if not hubo:
		_note("   No tienes %s en el Hogar." % mat.nombre.to_lower())


# Fija (absoluto) la cantidad elegida de `cal` en `sel`, acotada a `disp`. Lo llama el stepper
# editable. No rebuildea si no cambia (evita el bucle de focus_exited al liberar el LineEdit).
func _set_sel_mat(sel: Dictionary, cal: int, disp: int, n: int) -> void:
	var nuevo: int = clampi(n, 0, disp)
	if nuevo == int(sel.get(cal, 0)):
		return
	if nuevo <= 0:
		sel.erase(cal)
	else:
		sel[cal] = nuevo
	_rebuild()


# Linea de sabor del oficio, SIN numeros (misma regla que en la forja, ver Forge_menu._estado_oficio):
# el contador es OCULTO porque es lo que decide si la habilidad te sale al subir de nivel. Bloqueada
# -> no se pinta nada, ni el separador. Los numeros, en el panel de debug.
func _estado_peleteria() -> void:
	if not Game.tiene_desarrollo("peleteria"):
		return
	_content.add_child(HSeparator.new())
	_row("Peletería", "activa")
	_note("Tira por sacar el cuero un escalón por encima de la piel que metas.")


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


func _row(etiqueta: String, valor: String) -> void:
	MenuScaffold.fila(_content, etiqueta, valor, 200)


func _note(txt: String) -> void:
	MenuScaffold.nota(_content, txt)
