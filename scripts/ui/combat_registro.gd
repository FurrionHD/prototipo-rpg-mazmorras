# ============================================================
#  combat_registro.gd  (tema de la pantalla de combate: combat.registro)
#  EL REGISTRO DE LA PELEA (rework del 06/11: "el log es un poco mierdon, se hincha"). Lo acordado con el jefe:
#   1. UNA FILA POR ACCION: todo lo que pasa dentro de una accion (el corte del Filo de aire, el rebote, el sangrado
#      nuevo, las frases del conjuro...) va DENTRO de su fila, no en una fila suelta por cosa.
#   2. LA FICHA AL PASAR EL RATON (o al tocar la fila en el movil): el desglose de esa accion, linea a linea.
#   3. FILTROS POCOS Y DE COLOR FIJO: Todo / Aliados / Enemigos / Estados (07/11: antes "Lo mio" / "Me hacen", que en multi no valian).
#
#  EL TEXTO NO CAMBIA: _pantalla._log_lines sigue siendo la lista plana de frases de siempre (la leen las pruebas y las
#  huellas, que la comparan letra a letra). Lo nuevo va APARTE, en 'meta' (paralela a _log_lines): de que GRUPO
#  (accion) es cada frase, de que TIPO y de que BANDO.
#   tipo  "p" la frase principal de su accion (la que da nombre a la fila)   "x" un extra de esa accion
#         "s" un estado (lo que hace el tick: sangra, se cura, se le pasa...)  "a" un aviso de ahora ("Turno de X")
#   bando "a" lo hace alguien del grupo   "e" lo hace un enemigo   "-" no es de nadie (empieza la pelea, ganas...)
#  POR RED (el espejo) y en la pelea guardada las frases viajan CODIFICADAS con su meta delante (codificar); una frase
#  sin meta (una pelea guardada de antes) sale como fila suelta.
# ============================================================
extends RefCounted
const HudEstilo = preload("res://scripts/ui/hud_estilo.gd")

const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null

const SEP := "\u001e"   # separador de la meta en la frase codificada (no sale nunca en un texto del juego)

enum Filtro { TODO, ALIADOS, ENEMIGOS, ESTADOS }
const NOMBRE_FILTRO := ["Todo", "Aliados", "Enemigos", "Estados"]
# Colores FIJOS por bando (lo pidio asi: pocos y siempre los mismos).
const COLOR_MIO := Color(0.93, 0.90, 0.84)
const COLOR_ENEMIGO := Color(0.95, 0.62, 0.55)
const COLOR_ESTADO := Color(0.74, 0.66, 0.95)
const COLOR_AVISO := Color(0.62, 0.62, 0.66)
const COLOR_MAS := Color(0.62, 0.60, 0.56)

var meta: Array = []            # paralela a _pantalla._log_lines: [grupo, tipo, bando]
var filtro: int = Filtro.TODO

# El grupo ABIERTO: la accion que esta pasando ahora (abrir / cerrar).
var _abierto: bool = false
var _g_abierto: String = ""
var _bando: String = "-"
var _tiene_principal: bool = false
var _x_principal: bool = false   # fila aparte (abrir_aparte): la primera frase "x" es la principal
# Los ids de grupo llevan una marca de ESTA pantalla: el espejo mezcla los grupos del anfitrion con sus propios avisos
# y no se pueden pisar.
var _marca: String = ""
var _n: int = 0

var _grupos: Dictionary = {}    # grupo -> {"lineas": [indices], "p": indice de la principal o -1, "b": bando, "t": tipo}
var _orden: Array = []          # los grupos, en el orden en que aparecieron
var _filas: Array = []          # los que estan pintados ahora (con el filtro)
var _sucio: bool = false        # hay que rehacer el panel (se hace al final del fotograma)

var _ficha: PanelContainer = null
var _ficha_vb: VBoxContainer = null
var _ficha_grupo: String = ""
var _botones_filtro: Array = []


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla
	# SIN randi(): tocar el azar global cambiaba todas las tiradas de la pelea (lo cazo prueba_huella_combate).
	_marca = "%x" % ((Time.get_ticks_usec() ^ get_instance_id()) & 0xffffff)


# ------------------------------------------------------------
#  LOS GRUPOS
# ------------------------------------------------------------
# Empieza la accion de 'actor': lo que se escriba hasta la siguiente va en su fila.
func abrir(actor: Combatant) -> void:
	_g_abierto = _nuevo_id()
	_abierto = true
	_bando = "e" if (actor != null and _pantalla._enemies.has(actor)) else "a"
	_tiene_principal = false
	_x_principal = false


func cerrar() -> void:
	_abierto = false


# UNA FILA APARTE DENTRO DE LA ACCION DE OTRO (07/11, playtest del .exe): el golpe de Escolta / Oportunista salta en
# mitad del turno de un aliado y caia en SU fila ("me sale el golpe de mi maza dentro de la habilidad de mi compa").
# Abre una fila para 'actor' y devuelve lo que habia abierto, para volver a ello con volver_a().
func abrir_aparte(actor: Combatant) -> Array:
	var antes: Array = [_abierto, _g_abierto, _bando, _tiene_principal, _x_principal]
	abrir(actor)
	_x_principal = true   # su primera frase (un _log_extra) da nombre a la fila
	return antes


func volver_a(antes: Array) -> void:
	_abierto = bool(antes[0])
	_g_abierto = String(antes[1])
	_bando = String(antes[2])
	_tiene_principal = bool(antes[3])
	_x_principal = bool(antes[4])


func _nuevo_id() -> String:
	_n += 1
	return "%s.%d" % [_marca, _n]


# La meta de una frase nueva escrita AQUI. tipo "" = la de siempre (_set_log): principal si es la primera de su accion.
func meta_nueva(tipo: String) -> Array:
	if tipo == "f":
		return [_nuevo_id(), "p", "-"]
	if tipo == "s" or tipo == "a" or not _abierto:
		return [_nuevo_id(), "p" if tipo == "" or tipo == "x" else tipo, "s" if tipo == "s" else "-"]
	if (tipo == "" or (tipo == "x" and _x_principal)) and not _tiene_principal:
		_tiene_principal = true
		return [_g_abierto, "p", _bando]
	return [_g_abierto, "x", _bando]


func codificar(i: int) -> String:
	var m: Array = meta[i] if i < meta.size() else []
	var t: String = String(_pantalla._log_lines[i])
	if m.size() < 3:
		return t
	return SEP + "%s,%s,%s" % [m[0], m[1], m[2]] + SEP + t


# [texto, meta] de una frase codificada; sin meta (una pelea guardada vieja), fila suelta.
func decodificar(s: String) -> Array:
	if s.begins_with(SEP):
		var fin: int = s.find(SEP, 1)
		if fin > 0:
			var m: PackedStringArray = s.substr(1, fin - 1).split(",")
			if m.size() == 3:
				return [s.substr(fin + 1), [m[0], m[1], m[2]]]
	return [s, [_nuevo_id(), "p", "-"]]


func entero_codificado() -> Array:
	var out: Array = []
	for i in _pantalla._log_lines.size():
		out.append(codificar(i))
	return out


func trozo_codificado(desde: int, hasta: int) -> Array:
	var out: Array = []
	for i in range(desde, hasta):
		out.append(codificar(i))
	return out


# ------------------------------------------------------------
#  APUNTAR Y PINTAR
# ------------------------------------------------------------
# Apunta la frase 'texto' con su meta y la pinta. Es el unico sitio por donde entra una frase al registro.
func apuntar(texto: String, m: Array) -> void:
	var i: int = _pantalla._log_lines.size()
	_pantalla._log_lines.append(texto)
	meta.append(m)
	var g: String = String(m[0])
	if not _grupos.has(g):
		_grupos[g] = {"lineas": [], "p": -1, "b": String(m[2]), "t": String(m[1])}
		_orden.append(g)
	var gr: Dictionary = _grupos[g]
	(gr["lineas"] as Array).append(i)
	if String(m[1]) != "x" and int(gr["p"]) < 0:
		gr["p"] = i
	if String(m[2]) != "-" and String(gr["b"]) == "-":
		gr["b"] = String(m[2])
	_pintar_grupo(g)
	if _ficha != null and _ficha.visible and _ficha_grupo == g:
		_llenar_ficha(g)


func _log() -> RichTextLabel:
	return _pantalla._log


func _pasa(g: String) -> bool:
	var gr: Dictionary = _grupos[g]
	var t: String = gr["t"]
	match filtro:
		Filtro.ALIADOS: return String(gr["b"]) == "a" and t != "s" and t != "a"
		Filtro.ENEMIGOS: return String(gr["b"]) == "e" and t != "s" and t != "a"
		Filtro.ESTADOS: return t == "s"
	return true


# (06/11) EL PANEL SE REHACE ENTERO, una vez por fotograma como mucho: quitar y volver a poner el ultimo parrafo de un
# RichTextLabel le descuadra la cuenta de parrafos (medido: tras quitar uno, la fila siguiente se pegaba a la de antes).
# Rehacerlo de una pasada con su BBCode es una sola maquetacion, y una accion en area con veinte frases se pinta una vez.
func _pintar_grupo(g: String) -> void:
	if _log() == null or not _pasa(g):
		return
	if not _sucio:
		_sucio = true
		_repintar_diferido.call_deferred()


func _repintar_diferido() -> void:
	if _sucio:
		repintar()


func _color_de(gr: Dictionary) -> Color:
	match String(gr["t"]):
		"s": return COLOR_ESTADO
		"a": return COLOR_AVISO
	return COLOR_ENEMIGO if String(gr["b"]) == "e" else COLOR_MIO


# Un texto del juego dentro del BBCode: los corchetes, como [lb] y [rb] (sin esto "[Fuego]" se comeria la etiqueta).
static func _escapar(t: String) -> String:
	var trozos: PackedStringArray = t.split("[")
	for k in trozos.size():
		trozos[k] = trozos[k].replace("]", "[rb]")
	return "[lb]".join(trozos)


# Todo de nuevo, ya (las pruebas lo llaman directamente para leer las filas sin esperar un fotograma).
func repintar() -> void:
	_sucio = false
	var r: RichTextLabel = _log()
	if r == null:
		return
	var filas := PackedStringArray()
	_filas.clear()
	var ultimo: String = String(_orden.back()) if not _orden.is_empty() else ""
	for g in _orden:
		if not _pasa(g):
			continue
		var gr: Dictionary = _grupos[g]
		# Un aviso ("Turno de X") solo vale el de AHORA: si ya ha pasado algo despues, no se pinta.
		if String(gr["t"]) == "a" and g != ultimo:
			continue
		var lineas: Array = gr["lineas"]
		var p: int = int(gr["p"]) if int(gr["p"]) >= 0 else int(lineas[0])
		var fila: String = "[url=%s][color=#%s]%s[/color]" % [g, _color_de(gr).to_html(false),
			_escapar(String(_pantalla._log_lines[p]))]
		if lineas.size() > 1:
			fila += "[color=#%s]  +%d[/color]" % [COLOR_MAS.to_html(false), lineas.size() - 1]
		filas.append(fila + "[/url]")
		_filas.append(g)
	r.bbcode_enabled = true
	r.text = "\n".join(filas)
	_pantalla._log_al_final()


# Todo el registro de golpe, con frases codificadas (el espejo que pide el entero, una pelea guardada).
func rehacer(lineas: Array) -> void:
	_pantalla._log_lines.clear()
	meta.clear()
	_grupos.clear()
	_orden.clear()
	var r: RichTextLabel = _log()
	for l in lineas:
		var d: Array = decodificar(String(l))
		var i: int = _pantalla._log_lines.size()
		_pantalla._log_lines.append(String(d[0]))
		meta.append(d[1])
		var g: String = String(d[1][0])
		if not _grupos.has(g):
			_grupos[g] = {"lineas": [], "p": -1, "b": String(d[1][2]), "t": String(d[1][1])}
			_orden.append(g)
		(_grupos[g]["lineas"] as Array).append(i)
		if String(d[1][1]) != "x" and int(_grupos[g]["p"]) < 0:
			_grupos[g]["p"] = i
	if r != null:
		repintar()


# ------------------------------------------------------------
#  LA FILA DE FILTROS Y LA FICHA
# ------------------------------------------------------------
# La monta CombatMontaje._montar_log debajo de la fila del boton Registro.
func montar(caja: VBoxContainer) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	caja.add_child(fila)
	var grupo := ButtonGroup.new()
	for f in NOMBRE_FILTRO.size():
		var b := Button.new()
		b.text = NOMBRE_FILTRO[f]
		b.toggle_mode = true
		b.button_group = grupo
		b.button_pressed = f == filtro
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 24)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", [COLOR_MIO, COLOR_MIO, COLOR_ENEMIGO, COLOR_ESTADO][f])
		b.pressed.connect(_elegir_filtro.bind(f))
		fila.add_child(b)
		_botones_filtro.append(b)
	var r: RichTextLabel = _log()
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.meta_underlined = false
	r.meta_hover_started.connect(_al_entrar)
	r.meta_hover_ended.connect(_al_salir)
	r.meta_clicked.connect(_al_tocar)
	_ficha = PanelContainer.new()
	_ficha.top_level = true
	_ficha.visible = false
	_ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ficha.z_index = 50
	_ficha.add_theme_stylebox_override("panel", HudEstilo.caja_panel())
	_ficha_vb = VBoxContainer.new()
	_ficha_vb.add_theme_constant_override("separation", 2)
	_ficha.add_child(_ficha_vb)
	_pantalla.add_child(_ficha)


func _elegir_filtro(f: int) -> void:
	filtro = f
	_ocultar_ficha()
	repintar()


func _al_entrar(m) -> void:
	_mostrar_ficha(String(m))


func _al_salir(_m) -> void:
	_ocultar_ficha()


# En el movil no hay "pasar por encima": tocar la fila la abre y volver a tocarla la cierra.
func _al_tocar(m) -> void:
	if _ficha != null and _ficha.visible and _ficha_grupo == String(m):
		_ocultar_ficha()
	else:
		_mostrar_ficha(String(m))


func _ocultar_ficha() -> void:
	if _ficha != null:
		_ficha.visible = false
	_ficha_grupo = ""


func _mostrar_ficha(g: String) -> void:
	if _ficha == null or not _grupos.has(g):
		return
	# Una accion de una sola frase no tiene desglose: la fila ya lo dice todo.
	if (_grupos[g]["lineas"] as Array).size() <= 1:
		_ocultar_ficha()
		return
	_ficha_grupo = g
	_llenar_ficha(g)
	_ficha.visible = true
	_colocar_ficha()


func _llenar_ficha(g: String) -> void:
	# Fuera YA (no queue_free): las de antes seguirian midiendo hasta el final del fotograma y la ficha saldria alta.
	for h in _ficha_vb.get_children():
		_ficha_vb.remove_child(h)
		h.free()
	var gr: Dictionary = _grupos[g]
	var p: int = int(gr["p"])
	var lineas: Array = gr["lineas"]
	var primero: bool = true
	# La principal arriba, como titulo; debajo, el resto en el orden en que pasaron.
	var orden: Array = ([p] if p >= 0 else []) + lineas.filter(func(i): return int(i) != p)
	for i in orden:
		var l := Label.new()
		l.text = String(_pantalla._log_lines[int(i)])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 340.0
		l.add_theme_font_size_override("font_size", 16 if primero else 14)
		l.add_theme_color_override("font_color", _color_de(gr) if primero else COLOR_MIO.darkened(0.08))
		_ficha_vb.add_child(l)
		primero = false
	_ficha.size = Vector2.ZERO
	_ficha.reset_size()


# A la IZQUIERDA del registro (que va pegado a la derecha de la pantalla), a la altura del raton, sin salirse.
func _colocar_ficha() -> void:
	var vp: Vector2 = _pantalla.get_viewport_rect().size
	var raton: Vector2 = _pantalla.get_global_mouse_position()
	var caja: Control = _pantalla.montaje._log_caja
	var tam: Vector2 = _ficha.get_combined_minimum_size()
	var x: float = (caja.global_position.x if caja != null else raton.x) - tam.x - 8.0
	var y: float = clampf(raton.y - 12.0, 8.0, vp.y - tam.y - 8.0)
	_ficha.global_position = Vector2(maxf(8.0, x), y).round()
