# ============================================================
#  arbol_mejoras_ui.gd
#  LA PESTAÑA DEL ARBOL (22/11, memoria rangos-magias-y-habilidades): la del maestro (las habilidades del arma) y la
#  del mago (las magias). La pinta maestro_menu.gd en sus dos columnas:
#    - EL CENTRO: arriba, las habilidades (o magias) entre las que eliges; debajo, su ARBOL de arriba abajo, como en
#      Diablo 4: la habilidad tal cual arriba del todo, y cada fila los nodos que cuelgan de la anterior, con su linea.
#    - LA DERECHA: la ficha del nodo elegido (que cambia, que pide) y el boton de cogerlo; y el interruptor de llevarla
#      SIN MEJORAS.
#  PROVISIONAL (memoria ui-placeholder-codigo): todo por codigo, sin arte. El pase visual va al final.
# ============================================================
extends RefCounted

const Mejoras = preload("res://scripts/core/mejoras.gd")

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)
const OSCURO := Color(0.32, 0.34, 0.4)

const NODO_ANCHO := 150.0
const NODO_ALTO := 46.0
const FILA_ALTO := 92.0
const HUECO_X := 24.0
const ANCHO_SELECTOR := 158.0

# Como se llama cada campo de la ficha en la pantalla (lo que cambia un nodo). Uno que no este sale con su nombre.
const NOMBRE_CAMPO := {
	"dano_mult": "daño", "dano_base": "daño", "golpes_min": "golpes", "golpes_max": "golpes",
	"forma_radio": "alcance", "forma_apertura": "ángulo", "forma_ancho": "ancho", "forma_rango": "distancia",
	"coste_energia": "energía que cuesta", "coste_mana": "maná que cuesta", "cooldown": "turnos de recarga",
	"area_max": "enemigos que pilla", "area_secundario": "daño a los de alrededor", "dano_salpicon": "daño a los de alrededor",
	"dano_objetivo": "daño al objetivo", "elemento": "elemento", "imbue_prob": "probabilidad del efecto",
	"rebotes": "rebotes", "robo_vida": "vida que roba",
}
# Los que se leen mejor en porcentaje cuando se multiplican (los demas, "x1,2").
const SIEMPRE_PCT := ["dano_mult", "dano_base", "dano_objetivo", "dano_salpicon", "area_secundario"]

var _menu = null          # maestro_menu: para repintar y dar avisos
var hab_idx: int = 0      # que habilidad (o magia) de la lista
var nodo_sel: StringName = &""   # que nodo de su arbol ("" = la habilidad misma)


func _init(menu) -> void:
	_menu = menu


# ------------------------------------------------------------
#  LO QUE SE PINTA
# ------------------------------------------------------------
# 'fichas': las habilidades o magias entre las que se elige; 'sabida': Callable(ficha) -> bool (si no la sabe, se
# enseña el arbol pero no se puede coger nada).
func pintar(lista: VBoxContainer, content: VBoxContainer, pj: PersonajeData, fichas: Array, sabida: Callable,
		que: String) -> void:
	if fichas.is_empty():
		MenuScaffold.nota(lista, "Aún no tienes %s que mejorar." % que)
		return
	hab_idx = clampi(hab_idx, 0, fichas.size() - 1)
	var base: Resource = fichas[hab_idx]
	_pintar_selector(lista, fichas)
	_pintar_arbol(lista, pj, base, bool(sabida.call(base)))
	_pintar_ficha(content, pj, base, bool(sabida.call(base)))


func _pintar_selector(lista: VBoxContainer, fichas: Array) -> void:
	var flujo := HFlowContainer.new()
	flujo.add_theme_constant_override("h_separation", 6)
	flujo.add_theme_constant_override("v_separation", 6)
	lista.add_child(flujo)
	for i in fichas.size():
		var f: Resource = fichas[i]
		var con_arbol: bool = not (f.arbol as Array).is_empty()
		var b := Button.new()
		# TODOS DEL MISMO TAMAÑO (lo pidio el jefe): el nombre recortado si no cabe, y la que no tiene arbol solo va en gris.
		b.text = String(f.nombre)
		b.custom_minimum_size = Vector2(ANCHO_SELECTOR, 34)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = String(f.nombre) + ("" if con_arbol else "\nTodavía no tiene árbol")
		b.toggle_mode = true
		b.button_pressed = (i == hab_idx)
		b.add_theme_font_size_override("font_size", 13)
		if not con_arbol:
			b.add_theme_color_override("font_color", GRIS)
		b.pressed.connect(func() -> void:
			hab_idx = i
			nodo_sel = &""
			_menu._rebuild())
		flujo.add_child(b)
	MenuScaffold.separador(lista)


# EL ARBOL: la fila de cada nodo es su PROFUNDIDAD (1 + la del padre mas hondo; sin padres, la primera), y dentro de
# la fila van en el orden en que estan en la ficha.
func _pintar_arbol(lista: VBoxContainer, pj: PersonajeData, base: Resource, sabida: bool) -> void:
	var nodos: Array = (base.arbol as Array).filter(func(n): return n != null)
	var hondo: Dictionary = {}
	for _vuelta in nodos.size() + 1:
		for n in nodos:
			var d: int = 1
			for pa in n.padres:
				if hondo.has(StringName(pa)):
					d = maxi(d, int(hondo[StringName(pa)]) + 1)
			hondo[StringName(n.id)] = d
	var filas: Dictionary = {0: [null]}   # la fila 0 es la habilidad tal cual
	var max_fila: int = 0
	for n in nodos:
		var f: int = int(hondo[StringName(n.id)])
		if not filas.has(f):
			filas[f] = []
		(filas[f] as Array).append(n)
		max_fila = maxi(max_fila, f)
	var ancho_max: int = 1
	for f in filas:
		ancho_max = maxi(ancho_max, (filas[f] as Array).size())
	var ancho: float = maxf(ancho_max * (NODO_ANCHO + HUECO_X), 560.0)
	var lienzo := Lienzo.new()
	lienzo.custom_minimum_size = Vector2(ancho, (max_fila + 1) * FILA_ALTO + 10.0)
	lienzo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # el arbol, centrado en su columna
	lista.add_child(lienzo)
	var centro: Dictionary = {}   # id -> centro del nodo, para las lineas
	var cogidos: Array = (pj.nodos_elegidos as Dictionary).get(String(base.resource_path), [])
	for f in range(max_fila + 1):
		if not filas.has(f):
			continue
		var fila: Array = filas[f]
		var total: float = fila.size() * NODO_ANCHO + (fila.size() - 1) * HUECO_X
		var x0: float = (ancho - total) * 0.5
		for i in fila.size():
			var n = fila[i]
			var pos := Vector2(x0 + i * (NODO_ANCHO + HUECO_X), f * FILA_ALTO + 8.0)
			var id: StringName = &"" if n == null else StringName(n.id)
			centro[id] = pos + Vector2(NODO_ANCHO * 0.5, NODO_ALTO * 0.5)
			lienzo.add_child(_boton_nodo(pj, base, n, pos, sabida, cogidos))
	# LAS LINEAS: de cada padre a su hijo (la primera fila cuelga de la habilidad). Verde si las dos puntas son tuyas.
	for n in nodos:
		var hijo: Vector2 = centro[StringName(n.id)]
		var padres: Array = n.padres if not (n.padres as Array).is_empty() else [&""]
		for pa in padres:
			if not centro.has(StringName(pa)):
				continue
			var tuyo: bool = cogidos.has(String(n.id)) and (StringName(pa) == &"" or cogidos.has(String(pa)))
			lienzo.lineas.append([centro[StringName(pa)] + Vector2(0, NODO_ALTO * 0.5), hijo - Vector2(0, NODO_ALTO * 0.5),
				VERDE if tuyo else OSCURO])
	lienzo.queue_redraw()


# El estado de un nodo: "tuyo", "puedes", "falta" (le falta algo) o "cerrado" (otra rama lo cierra).
func _estado(pj: PersonajeData, base: Resource, n: Resource, cogidos: Array) -> String:
	if cogidos.has(String(n.id)):
		return "tuyo"
	for x in n.excluye:
		if cogidos.has(String(x)):
			return "cerrado"
	return "puedes" if Mejoras.motivo_no(pj, base, StringName(n.id), int(pj.level), Game.money) == "" else "falta"


func _boton_nodo(pj: PersonajeData, base: Resource, n, pos: Vector2, sabida: bool, cogidos: Array) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(NODO_ANCHO, NODO_ALTO)
	b.custom_minimum_size = b.size
	b.toggle_mode = true
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 12)
	var id: StringName = &"" if n == null else StringName(n.id)
	b.button_pressed = (id == nodo_sel)
	var col: Color = AMBAR
	if n == null:
		b.text = String(base.nombre)
	else:
		var est: String = _estado(pj, base, n, cogidos) if sabida else "falta"
		b.text = String(n.nombre)
		col = {"tuyo": VERDE, "puedes": AMBAR, "falta": GRIS, "cerrado": OSCURO}[est]
		b.tooltip_text = {"tuyo": "Ya lo tienes", "puedes": "Lo puedes coger", "falta": "Te falta algo",
			"cerrado": "Elegiste la otra rama"}[est]
	# EL COLOR DE SU ESTADO tambien elegido y con el raton encima (si no, el elegido salia en blanco y no se sabia si era
	# tuyo, si lo podias coger o si te faltaba algo).
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, col)
	b.pressed.connect(func() -> void:
		nodo_sel = id
		_menu._rebuild())
	return b


# LA FICHA de la derecha: el nodo elegido (o la habilidad, si no hay ninguno).
func _pintar_ficha(content: VBoxContainer, pj: PersonajeData, base: Resource, sabida: bool) -> void:
	var ruta: String = String(base.resource_path)
	MenuScaffold.titulo(content, String(base.nombre), 18)
	# EL INTERRUPTOR: llevarla a la pelea sin sus mejoras (la de sin mejorar sigue existiendo).
	var sin := CheckButton.new()
	sin.text = "Llevarla sin mejoras"
	sin.button_pressed = bool((pj.sin_mejoras as Dictionary).get(ruta, false))
	sin.add_theme_font_size_override("font_size", 13)
	sin.toggled.connect(func(on: bool) -> void:
		Game.poner_sin_mejoras(base, on, pj)
		_menu._rebuild())
	content.add_child(sin)
	MenuScaffold.fila(content, "Dominio", "%d usos" % int((pj.dominio as Dictionary).get(ruta, 0)))
	MenuScaffold.separador(content)
	var n: Resource = Mejoras.nodo(base, nodo_sel) if nodo_sel != &"" else null
	if n == null:
		var cogidos: Array = (pj.nodos_elegidos as Dictionary).get(ruta, [])
		MenuScaffold.nota(content, "Elige un nodo del árbol para ver qué cambia y qué pide." if not (base.arbol as Array).is_empty()
			else "Esta todavía no tiene árbol.")
		if not cogidos.is_empty():
			MenuScaffold.titulo(content, "Lo que llevas", 14, VERDE)
			for id in cogidos:
				var nn: Resource = Mejoras.nodo(base, StringName(id))
				if nn != null:
					MenuScaffold.nota(content, "· " + String(nn.nombre))
		return
	MenuScaffold.titulo(content, String(n.nombre), 16, AMBAR)
	if String(n.descripcion) != "":
		MenuScaffold.nota(content, String(n.descripcion))
	MenuScaffold.titulo(content, "Cambia", 14)
	for linea in texto_cambios(base, n):
		MenuScaffold.nota(content, "· " + linea)
	MenuScaffold.titulo(content, "Pide", 14)
	var cogidos2: Array = (pj.nodos_elegidos as Dictionary).get(ruta, [])
	var padres_ok: bool = (n.padres as Array).is_empty() or (n.padres as Array).any(func(pa): return cogidos2.has(String(pa)))
	if not (n.padres as Array).is_empty():
		var nombres: Array = (n.padres as Array).map(func(pa):
			var x: Resource = Mejoras.nodo(base, StringName(pa))
			return String(x.nombre) if x != null else String(pa))
		_req(content, "Antes: " + " o ".join(PackedStringArray(nombres)), padres_ok)
	_req(content, "Nivel %d" % int(n.nivel_min), int(pj.level) >= int(n.nivel_min))
	_req(content, "Dominio %d (llevas %d)" % [int(n.dominio), int((pj.dominio as Dictionary).get(ruta, 0))],
		int((pj.dominio as Dictionary).get(ruta, 0)) >= int(n.dominio))
	_req(content, "%d monedas" % int(n.oro), Game.money >= int(n.oro))
	if not (n.excluye as Array).is_empty():
		var cierra: Array = (n.excluye as Array).map(func(x):
			var y: Resource = Mejoras.nodo(base, StringName(x))
			return String(y.nombre) if y != null else String(x))
		MenuScaffold.nota(content, "Cierra la otra rama: " + ", ".join(PackedStringArray(cierra)))
	MenuScaffold.separador(content)
	if cogidos2.has(String(n.id)):
		MenuScaffold.titulo(content, "Ya lo tienes", 14, VERDE)
		return
	if not sabida:
		MenuScaffold.nota(content, "Primero tienes que aprender la habilidad.")
		return
	var motivo: String = Mejoras.motivo_no(pj, base, StringName(n.id), int(pj.level), Game.money)
	MenuScaffold.boton(content, "Coger (%d monedas)" % int(n.oro), func() -> void:
		var r: String = Game.coger_nodo(base, StringName(n.id), pj)
		_menu._aviso = ("%s: %s" % [n.nombre, "¡hecho!"]) if r == "" else ("No se puede: " + r)
		_menu._aviso_ok = (r == "")
		_menu._rebuild(), motivo == "")


func _req(content: VBoxContainer, txt: String, ok: bool) -> void:
	var l := Label.new()
	l.text = ("✓ " if ok else "· ") + txt
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", VERDE if ok else GRIS)
	content.add_child(l)


# Lo que cambia un nodo, en una linea por cambio ("+10 % de daño", "+20 de alcance", "elemento: Rayo").
static func texto_cambios(base: Resource, n: Resource) -> Array:
	var out: Array = []
	var vistos: Array = []
	for campo in (n.cambios as Dictionary):
		var c: String = String(campo)
		var par = n.cambios[campo]
		if not (par is Array) or (par as Array).size() != 2:
			continue
		var nombre: String = String(NOMBRE_CAMPO.get(c, c))
		if (c == "golpes_min" or c == "golpes_max"):
			if vistos.has("golpes"):
				continue
			vistos.append("golpes")
		var op: String = String(par[0])
		var v = par[1]
		match op:
			"mult":
				var pct: float = (float(v) - 1.0) * 100.0
				out.append("%s%.0f %% de %s" % ["+" if pct >= 0.0 else "", pct, nombre])
			"add":
				if v is float or v is int:
					out.append("%s%s de %s" % ["+" if float(v) >= 0.0 else "", MenuScaffold.valor_es(str(snappedf(float(v), 0.01))), nombre])
				else:
					out.append("añade a %s" % nombre)
			"set":
				if c == "elemento":
					out.append("pasa a ser de %s" % Elementos.nombre(int(v)))
				else:
					out.append("%s pasa a %s" % [nombre, str(v)])
	return out


# EL LIENZO del arbol: los botones van encima y las lineas se pintan debajo.
class Lienzo extends Control:
	var lineas: Array = []   # [desde, hasta, color]

	func _draw() -> void:
		for l in lineas:
			var a: Vector2 = l[0]
			var b: Vector2 = l[1]
			var medio: float = (a.y + b.y) * 0.5
			# En escuadra (baja, cruza y baja), que se lee mejor que en diagonal con muchas ramas.
			draw_polyline(PackedVector2Array([a, Vector2(a.x, medio), Vector2(b.x, medio), b]), l[2], 3.0)
