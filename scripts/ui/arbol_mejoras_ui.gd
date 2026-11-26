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
const BasicoArbol = preload("res://scripts/core/basico_arbol.gd")
const NodoMejora = preload("res://scripts/items/nodo_mejora.gd")

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)
const OSCURO := Color(0.32, 0.34, 0.4)


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

# EL ANTES -> DESPUES de la ficha de un nodo (24/11, el jefe: "nada de +40 %: el numero REAL que se le va a sumar").
# Cada fila: campo, como se llama en la ficha y como se escribe su valor. Lo que no este aqui lo cuenta la propia
# habilidad (AbilityData.frase_mejora) o, si no, sale con su nombre de NOMBRE_CAMPO.
#   pct = porcentaje · pct_atk = % del Ataque · num = numero · dec = con decimales · dist = distancia · grados
const FILAS_ANTES_DESPUES := [
	["dano_mult", "Daño de cada golpe", "pct_atk"],
	["golpes", "Golpes", "golpes"],
	["golpes_extra_por_enemigo", "Golpes con 3 enemigos en el combate", "golpes_3"],
	["golpes_extra_max", "Tope de golpes de más por enemigos", "num"],
	["dual_golpe_mult", "Con dos armas, daño de los golpes de la segunda frente a los de la primera", "pct"],
	["coste_energia", "Coste de energía", "coste"],
	["coste_mana", "Coste de maná", "num"],
	["cooldown", "Turnos de enfriamiento", "num"],
	["forma_radio", "Alcance", "dist"],
	["forma_apertura", "Ángulo", "grados"],
	["forma_rango", "Distancia hasta donde se apunta", "dist"],
	["forma_ancho", "Ancho de su línea", "dist"],
	["penetracion_extra", "Defensa que ignora de más", "pct"],
	["crit_extra", "Probabilidad de crítico de más", "pct"],
	["extra_espalda", "Daño de más si golpea por la espalda", "pct"],
	["imbue_prob", "Probabilidad base de que prenda", "pct"],
	["imbue_usos", "Ataques que dura la impregnación", "num"],
	["imbue_fuerza", "Daño por turno de su veneno, frente al de siempre", "pct"],
	["se_aparta", "Distancia que se aparta tras golpear", "dist"],
]

var _menu = null          # maestro_menu: para repintar y dar avisos
var nodo_sel: StringName = &""   # que nodo de su arbol ("" = la habilidad misma)


func _init(menu) -> void:
	_menu = menu


# ------------------------------------------------------------
#  LO QUE SE PINTA: EL ARBOL ENTERO, UNA FILA POR COSA (23/11, el jefe con el arbol de Diablo delante)
#  De arriba abajo: en el maestro, primero el BASICO del arma y debajo cada habilidad; en la torre, cada magia (las
#  magias no tienen basico). Cada fila: el ICONO de la habilidad a la izquierda (cuadrado) y sus mejoras saliendo hacia
#  la DERECHA, abriendose en ramas y juntandose (24/11: CUADROS, son todos principales; ROMBOS la linea del 6 al 16). El
#  basico NO es una puerta: es una fila mas, ninguna cuelga de el. Sin nombres: el nombre, al pasar el raton; al
#  clicar, su ficha a la derecha. Las mejoras llevan el icono de su habilidad hasta que tengan el suyo.
# ------------------------------------------------------------
const P := 3.0            # EL PIXEL GORDO: nodos, lineas e iconos, todo a la misma rejilla (los iconos, 12 px x3)
const ICONO := 66.0       # el cuadro de la habilidad (22 pixeles)
const NODO := 48.0        # el circulo (o rombo) de una mejora (16 pixeles)
const PASO_X_MIN := 70.0  # de una columna de mejoras a la siguiente: lo justo...
const PASO_X_MAX := 160.0 # ...y lo mas que se separan para LLENAR EL ANCHO (23/11, el jefe: "el espacio no esta bien
                          # aprovechado"): las mejoras se reparten por todo el ancho de la columna, como en Diablo.
const PASO_Y := 57.0      # entre dos mejoras de la misma columna
# (26/11, el jefe: "que queden mas claras las lineas, separar mas los nodos horizontalmente") EL ARBOL de una habilidad (sus
# columnas de nodos que se ramifican) va con al menos esto entre columna y columna; la linea fija de rombos del 6 al 16, que
# es recta, se queda con el paso de siempre (si no, el arbol no cabria y todo iria con scroll).
const PASO_X_ARBOL := 120.0
# (26/11, el jefe: "que nunca se vean solapadas las lineas en las zonas de aglomeracion") Y MAS cuantas mas lineas cruzan
# el hueco entre dos columnas: tantos px por linea, hasta el tope.
const PASO_X_POR_LINEA := 6.0
const PASO_X_ARBOL_MAX := 200.0
const FILA_MIN := 96.0
const SEP_FILAS := 42.0   # el hueco entre una habilidad y la siguiente (la raya va en medio)
const SEP_PLEGADAS := 6.0 # entre dos plegadas
const MARGEN := 18.0
const LibrosPixel = preload("res://scripts/ui/libros_pixel.gd")

var fila_sel: String = ""   # la RUTA de la habilidad elegida ("basico" = el basico del arma)
var _paso_x: float = PASO_X_MIN
var _x_ultimo: float = -1.0   # donde queda lo ultimo que has mejorado de la fila abierta (para centrar el scroll de lado)
var _fijos: Array = []        # [Control, x de partida]: los iconos de las filas y sus contadores, quietos al deslizar
const FONDO := Color(0.047, 0.059, 0.078)   # el fondo del panel: tapa el arbol que pasa por debajo de los iconos
var ancho_pintado: float = 0.0   # el ancho con el que se pinto (maestro_menu repinta si la ventana cambia)


# 'fichas': las habilidades (o magias) de las filas; 'sabida': Callable(ficha) -> bool (si no la sabe, se ve su arbol
# pero no se coge nada); 'arma': la del maestro (su basico va en la primera fila y da el icono de sus habilidades), o
# null en la torre.
func pintar(lista: VBoxContainer, content: VBoxContainer, pj: PersonajeData, fichas: Array, sabida: Callable,
		que: String, arma: Resource = null) -> void:
	if fichas.is_empty() and arma == null:
		MenuScaffold.nota(lista, que)   # el aviso lo da quien llama (la torre: aun no conoce ninguna magia)
		return
	var filas: Array = []   # [clave, ficha o null (el basico)]
	if arma != null:
		filas.append(["basico", null])
	for f in fichas:
		filas.append([String(f.resource_path), f])
	if not filas.any(func(x): return x[0] == fila_sel):
		fila_sel = String(filas[0][0])
		nodo_sel = &""
	# EL ANCHO QUE HAY y la fila mas larga: las columnas de mejoras se separan para llenarlo.
	var hueco: Control = lista.get_parent() as Control
	var disponible: float = (hueco.size.x if hueco != null and hueco.size.x > 100.0 else 820.0) - 16.0
	ancho_pintado = disponible
	var max_col: int = 1
	for par in filas:
		if par[1] != null:
			max_col = maxi(max_col, _columnas(par[1]))
		elif arma != null:
			max_col = maxi(max_col, _columnas_basico(pj))
	_paso_x = clampf((disponible - MARGEN * 2.0 - ICONO - 44.0 - NODO) / float(maxi(1, max_col - 1)), PASO_X_MIN, PASO_X_MAX)
	# (23/11, el jefe) SCROLL DE LADO: si un arbol no cabe (el del basico tiene 12 columnas), se desliza en horizontal, sin
	# empujar la ficha de la derecha; y se abre CENTRADO en lo ultimo que has mejorado de la fila abierta (_x_ultimo).
	var lado := ScrollContainer.new()
	lado.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	lado.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_child(lado)
	var lienzo := Lienzo.new()
	lienzo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lado.add_child(lienzo)
	_x_ultimo = -1.0
	_fijos.clear()
	var y: float = 6.0
	var ancho: float = 0.0
	var elegida: Resource = null
	for i_f in filas.size():
		var clave: String = filas[i_f][0]
		var f: Resource = filas[i_f][1]
		var alto_f: float = _pintar_fila(lienzo, pj, clave, f, f == null or bool(sabida.call(f)), arma, y)
		if clave == fila_sel:
			elegida = f
		# ENTRE FILA Y FILA, la raya en medio del hueco: AIRE alrededor de la abierta (23/11, el jefe: los arboles crecen
		# mucho y todo se leia como un bloque) y poco entre las plegadas (que quepan todas de un vistazo).
		var junto_a_abierta: bool = clave == fila_sel or (i_f + 1 < filas.size() and String(filas[i_f + 1][0]) == fila_sel)
		var hueco_f: float = SEP_FILAS if junto_a_abierta else SEP_PLEGADAS
		lienzo.rayas.append(y + alto_f + hueco_f * 0.5)
		y += alto_f + hueco_f
		ancho = maxf(ancho, lienzo.ancho_fila)
	lienzo.custom_minimum_size = Vector2(maxf(ancho + MARGEN, disponible), y + 6.0)
	lado.custom_minimum_size = Vector2(0.0, y + 6.0 + (14.0 if ancho + MARGEN > disponible else 0.0))
	lienzo.queue_redraw()
	# (23/11, el jefe) LOS ICONOS QUIETOS: al deslizar, solo se mueve el arbol; la columna de los iconos (y sus contadores)
	# se queda en su sitio, con el fondo del panel detras para que el arbol pase por debajo y no se vean cortados.
	if ancho + MARGEN > disponible:
		var fondo := ColorRect.new()
		fondo.color = FONDO
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fondo.position = Vector2.ZERO
		fondo.size = Vector2(MARGEN + ICONO + 12.0, y + 6.0)
		fondo.visible = false
		lienzo.add_child(fondo)
		for fi in _fijos:
			lienzo.move_child(fi[0], -1)
		var fijos: Array = _fijos.duplicate()
		lado.get_h_scroll_bar().value_changed.connect(func(v: float) -> void:
			if not is_instance_valid(fondo):
				return
			fondo.position.x = v
			fondo.visible = v > 0.0
			for fi in fijos:
				if is_instance_valid(fi[0]):
					(fi[0] as Control).position.x = float(fi[1]) + v)
	if _x_ultimo > 0.0 and ancho + MARGEN > disponible:
		var objetivo: int = int(maxf(0.0, _x_ultimo - disponible * 0.5))
		(func() -> void:
			if is_instance_valid(lado):
				lado.scroll_horizontal = objetivo).call_deferred()
	if fila_sel == "basico":
		_pintar_ficha_basico(content, pj, arma)
	elif elegida != null:
		_pintar_ficha(content, pj, elegida, bool(sabida.call(elegida)))


# UNA FILA: el icono y, a su derecha, sus mejoras por columnas (la columna de cada una es su profundidad: 1 + la de su
# padre mas hondo). Devuelve lo alto que ocupa.
#
# LAS LINEAS LARGAS NO PASAN POR ENCIMA DE NADIE (23/11, el jefe: "se hacen confusas"): una que salta columnas (de la
# columna 3 a la 5, por ejemplo) reserva un HUECO en cada columna que cruza y pasa por el, entre los nodos, como en los
# arboles bien dibujados. Los huecos se ordenan con los nodos de su columna (por la altura de lo que tienen detras).
func _pintar_fila(lienzo: Lienzo, pj: PersonajeData, clave: String, f: Resource, sabida: bool, arma: Resource,
		y0: float) -> float:
	# EL BASICO (23/11): su arbol se arma aqui con nodos de mentira (la linea y las facultades, ver _nodos_basico).
	var basico: Dictionary = _nodos_basico(pj, arma) if f == null else {}
	var todos: Array = basico.get("nodos", []) if f == null else (f.arbol as Array).filter(func(n): return n != null)
	# PLEGADA (23/11, idea del jefe): solo la elegida despliega su arbol; las demas, su icono y su contador. Asi cada
	# arbol tiene todo el sitio y la pantalla no se llena de arboles a la vez.
	var plegada: bool = clave != fila_sel
	var nodos: Array = [] if plegada else todos
	var hondo: Dictionary = {&"": 0}
	for _vuelta in nodos.size() + 1:
		for n in nodos:
			var dd: int = 1
			for pa in n.padres:
				if hondo.has(StringName(pa)):
					dd = maxi(dd, int(hondo[StringName(pa)]) + 1)
			hondo[StringName(n.id)] = dd
	# LO QUE VA EN CADA COLUMNA: los nodos y los huecos de las lineas largas. Cada uno con lo que tiene justo detras.
	var cols: Dictionary = {}
	var detras: Dictionary = {}    # id -> [ids de la columna de antes de los que sale una linea hasta el]
	var cadenas: Array = []        # [[ids del padre al hijo, pasando por sus huecos], tuya]
	var cogidos: Array = basico.get("tuyos", []) if f == null else (pj.nodos_elegidos as Dictionary).get(clave, [])
	var max_col: int = 0
	for n in nodos:
		var d: int = int(hondo[StringName(n.id)])
		if not cols.has(d):
			cols[d] = []
		(cols[d] as Array).append(StringName(n.id))
		detras[StringName(n.id)] = []
		max_col = maxi(max_col, d)
	for n in nodos:
		var d2: int = int(hondo[StringName(n.id)])
		for pa in (n.padres if not (n.padres as Array).is_empty() else [&""]):
			if not hondo.has(StringName(pa)):
				continue
			var previo: StringName = StringName(pa)
			var cadena: Array = [previo]
			for c in range(int(hondo[StringName(pa)]) + 1, d2):
				var hueco: StringName = StringName("~%s>%s@%d" % [pa, n.id, c])
				if not cols.has(c):
					cols[c] = []
				(cols[c] as Array).append(hueco)
				detras[hueco] = [previo]
				cadena.append(hueco)
				previo = hueco
			(detras[StringName(n.id)] as Array).append(previo)
			cadena.append(StringName(n.id))
			var tuya: bool = cogidos.has(String(n.id)) and (StringName(pa) == &"" or cogidos.has(String(pa)))
			cadenas.append([cadena, tuya])
	# DONDE VA CADA COSA, en relativo (la fila en 0): A LA ALTURA DE LO QUE TIENE DETRAS (si no, las lineas se cruzan
	# y una punta sola se iba al centro de la fila, lejos de su padre); si choca con la de encima, lo justo por debajo,
	# y luego la columna entera se recoloca para que, de media, quede donde queria.
	var rel: Dictionary = {&"": 0.0}
	for c in range(1, max_col + 1):
		if not cols.has(c):
			continue
		var col: Array = cols[c]
		col.sort_custom(func(a, b2) -> bool: return _altura_detras(a, detras, rel) < _altura_detras(b2, detras, rel))
		var quiere: Array = col.map(func(id): return _altura_detras(id, detras, rel))
		var ys: Array = []
		for i in col.size():
			var yy: float = float(quiere[i])
			if i > 0:
				yy = maxf(yy, float(ys[i - 1]) + PASO_Y)
			ys.append(yy)
		var desvio: float = 0.0
		for i in col.size():
			desvio += float(quiere[i]) - float(ys[i])
		desvio /= float(col.size())
		for i in col.size():
			rel[col[i]] = float(ys[i]) + desvio
	var arriba: float = 0.0
	var abajo: float = 0.0
	for k in rel:
		arriba = minf(arriba, float(rel[k]))
		abajo = maxf(abajo, float(rel[k]))
	var alto: float = (ICONO + 12.0) if plegada else maxf(FILA_MIN + 24.0, abajo - arriba + NODO + 24.0)
	var cy: float = _px_g(y0 + alto * 0.5 - (arriba + abajo) * 0.5)
	var icono: Callable = _dibujo_icono(f, arma)
	# EL ICONO de la fila.
	var cab := NodoUI.new()
	cab.forma = NodoUI.Forma.CUADRO
	cab.dibujo = icono
	cab.estado = "puedes" if sabida else "falta"
	cab.elegido = (clave == fila_sel and nodo_sel == &"")
	cab.tooltip_text = ("Ataque básico" if f == null else String(f.nombre)) + ("" if sabida else "\nAún no la sabes")
	cab.position = Vector2(MARGEN, _px_g(cy - ICONO * 0.5))
	cab.size = Vector2(ICONO, ICONO)
	cab.custom_minimum_size = cab.size
	cab.pulsado.connect(func() -> void:
		fila_sel = clave
		nodo_sel = &""
		_menu._rebuild())
	lienzo.add_child(cab)
	# EL CONTADOR, al lado del icono (como el "4/12" de Diablo): cuantas mejoras llevas de las que tiene.
	var cuenta := Label.new()
	var llevas: int = int(basico.get("llevas", 0)) if f == null else ((pj.nodos_elegidos as Dictionary).get(clave, []) as Array).size()
	var total: int = int(basico.get("total", 0)) if f == null else todos.size()
	cuenta.text = ("%d / %d" % [llevas, total]) if total > 0 else "sin mejoras todavía"
	cuenta.add_theme_font_size_override("font_size", 14)
	cuenta.add_theme_color_override("font_color", VERDE if llevas > 0 else GRIS)
	# Plegada, a su derecha; desplegada, debajo del icono (a la derecha salen sus mejoras).
	cuenta.position = Vector2(MARGEN, cy + ICONO * 0.5 + 4.0) if not plegada else Vector2(MARGEN + ICONO + 16.0, cy - 10.0)
	cuenta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.add_child(cuenta)
	_fijos.append([cab, cab.position.x])
	_fijos.append([cuenta, cuenta.position.x])
	var centro: Dictionary = {&"": Vector2(MARGEN + ICONO, cy)}   # de donde salen las raices: el lado derecho del icono
	var por_id: Dictionary = {}
	for n in nodos:
		por_id[StringName(n.id)] = n
	# LA X DE CADA COLUMNA: entre columnas del arbol (las que no son rombos de la linea fija), PASO_X_ARBOL como poco.
	var x_col: Dictionary = {1: MARGEN + ICONO + 48.0}
	for c in range(2, max_col + 1):
		var de_arbol: bool = f != null and cols.has(c) and (cols[c] as Array).any(func(id): return not String(id).begins_with("linea_") 			and not String(id).begins_with("~"))
		var lineas: int = 0
		if de_arbol:
			for id in cols[c]:
				lineas += (detras.get(id, []) as Array).size()
		var paso_arbol: float = clampf(maxf(PASO_X_ARBOL, 80.0 + PASO_X_POR_LINEA * float(lineas)), PASO_X_ARBOL, PASO_X_ARBOL_MAX)
		x_col[c] = float(x_col[c - 1]) + (maxf(_paso_x, paso_arbol) if de_arbol else _paso_x)
	for c in range(1, max_col + 1):
		if not cols.has(c):
			continue
		for id in cols[c]:
			var pos := Vector2(_px_g(float(x_col[c])), _px_g(cy + float(rel[id])))
			centro[id] = pos
			if not plegada and cogidos.has(String(id)):
				_x_ultimo = maxf(_x_ultimo, pos.x)
			if not por_id.has(id):
				continue   # un hueco de una linea larga: no se pinta nada
			var n = por_id[id]
			var b := NodoUI.new()
			# (24/11, el jefe) LA FORMA DICE LO IMPORTANTE QUE ES: en las habilidades, todo el arbol (niveles 2-5) son
			# PRINCIPALES (cuadro); los ROMBOS seran la linea recta del nivel 6 al 16, la que solo sube el daño.
			b.forma = NodoUI.Forma.ROMBO if String(n.id).begins_with("linea_") else NodoUI.Forma.CUADRO
			if f == null:
				b.forma = int((basico["formas"] as Dictionary).get(String(n.id), b.forma))
			# (24/11) SU ICONO PROPIO si lo tiene (assets/ui/habilidades/<habilidad>__<nodo>.png); si no, el de su habilidad.
			b.dibujo = _dibujo_png(_png_nodo(f, StringName(n.id)), icono) if f != null else icono
			# (24/11, el jefe) LA LINEA DEL 6 AL 16: el icono de su habilidad con un "+" arriba a la derecha.
			if String(n.id).begins_with("linea_"):
				b.dibujo = _con_mas(b.dibujo)
			b.estado = (String((basico["estados"] as Dictionary).get(String(n.id), "falta")) if f == null
				else (_estado(pj, f, n, cogidos) if sabida else "falta"))
			b.elegido = (clave == fila_sel and id == nodo_sel)
			b.tooltip_text = String(n.nombre)
			if f == null and String(n.descripcion) != "":
				b.tooltip_text += "
" + String(n.descripcion)
			b.position = pos - Vector2(NODO, NODO) * 0.5
			b.size = Vector2(NODO, NODO)
			b.custom_minimum_size = b.size
			b.pulsado.connect(func() -> void:
				fila_sel = clave
				nodo_sel = id
				_menu._rebuild())
			lienzo.add_child(b)
	# LAS LINEAS: del padre (o del icono) al hijo, pasando por sus huecos, UNA POR CADA PAR (24/11, el jefe: el punto de union
	# hacia creer que desde el de arriba solo se llegaba al de abajo; con cada linea se entiende a cual va cada una). Verde
	# si las dos puntas son tuyas; las verdes, las ultimas, encima de las oscuras cuando se cruzan.
	var verdes: Array = []
	# (25/11, el jefe) LA DEL NODO ELEGIDO, en AMBAR (el color de su marco) y encima de todas: la que llega a el desde el
	# padre que ya tienes; si no tienes ninguno de sus padres, todas las que llegan a el.
	var ambar: Array = []
	var sel_aqui: bool = clave == fila_sel and nodo_sel != &""
	var sel_con_padre: bool = sel_aqui and cadenas.any(func(pc): return StringName((pc[0] as Array).back()) == nodo_sel 		and (StringName((pc[0] as Array)[0]) == &"" or cogidos.has(String((pc[0] as Array)[0]))))
	for par in cadenas:
		var cad: Array = par[0]
		var pts := PackedVector2Array()
		for k in cad.size():
			var p: Vector2 = centro[cad[k]]
			if k == 0 and StringName(cad[k]) != &"":
				p.x += NODO * 0.5     # sale del borde derecho del padre
			if k == cad.size() - 1:
				p.x -= NODO * 0.5     # entra por el borde izquierdo del hijo
			pts.append(p)
		var al_sel: bool = sel_aqui and StringName(cad.back()) == nodo_sel and (not sel_con_padre 			or StringName(cad[0]) == &"" or cogidos.has(String(cad[0])))
		if al_sel:
			ambar.append([pts, AMBAR])
		elif par[1]:
			verdes.append([pts, VERDE])
		else:
			lienzo.lineas.append([pts, OSCURO])
	lienzo.lineas.append_array(verdes)
	lienzo.lineas.append_array(ambar)
	lienzo.ancho_fila = maxf(lienzo.ancho_fila, float(x_col.get(max_col, MARGEN + ICONO + 48.0)) + NODO)
	return alto


# EL ARBOL DEL BASICO como nodos de mentira (23/11, el dibujo del jefe), para dibujarlo con lo mismo que los de las
# habilidades. Por cada nivel: los pisos 4 y 8 en CIRCULOS, en linea; en el piso 12 se abre en dos (en el primero las dos
# PRINCIPALES en CUADRO, despues las dos SECUNDARIAS en ROMBO) y vuelve a juntarse en el piso 4 del nivel siguiente.
# Ids: "l<paso>" los de la linea, "c<columna>_<facultad>" los del piso 12. Todo se compra clicando el nodo (la ficha).
# Devuelve {"nodos", "tuyos", "estados" {id: tuyo|puedes|falta|cerrado}, "formas" {id: NodoUI.Forma}, "llevas", "total"}.
func _nodos_basico(pj: PersonajeData, arma: Resource) -> Dictionary:
	if not (arma is WeaponData) or int(arma.tipo) == WeaponData.Tipo.PUNOS:
		return {}
	var tipo: int = int(arma.tipo)
	var d: Dictionary = Game.basico_de(tipo, pj)
	var pasos: int = int(d.get("pasos", 0))
	var elec: Array = d.get("elec", [])
	var nodos: Array = []
	var tuyos: Array = []
	var estados: Dictionary = {}
	var formas: Dictionary = {}
	var antes: Array[StringName] = []
	var motivo_linea: String = BasicoArbol.motivo_no_paso(pasos, int(pj.level), int(pj.piso_hondo), Game.money)
	for col in BasicoArbol.COLUMNAS:
		# los pisos 4 y 8 de este nivel
		for k in [col * 3, col * 3 + 1]:
			var n := NodoMejora.new()
			n.id = StringName("l%d" % k)
			n.nombre = "Nivel %d, piso %d" % [col + 1, BasicoArbol.piso_de_paso(k)]
			n.descripcion = _que_da_paso(tipo, k)
			n.padres = antes.duplicate()
			nodos.append(n)
			formas[String(n.id)] = NodoUI.Forma.CIRCULO
			if k < pasos:
				estados[String(n.id)] = "tuyo"
				tuyos.append(String(n.id))
			else:
				estados[String(n.id)] = "puedes" if k == pasos and motivo_linea == "" else "falta"
			var solo: Array[StringName] = [n.id]
			antes = solo
		# el piso 12: se abre en dos
		var aqui: Array[StringName] = []
		for id in BasicoArbol.opciones_columna(tipo, col, elec):
			var fd: Dictionary = BasicoArbol.facultad(tipo, id)
			var n := NodoMejora.new()
			n.id = StringName("c%d_%s" % [col, id])
			n.nombre = String(fd.get("nombre", id))
			n.descripcion = BasicoArbol.frase(tipo, id, 1)
			n.padres = antes.duplicate()
			nodos.append(n)
			aqui.append(n.id)
			formas[String(n.id)] = NodoUI.Forma.CUADRO if (col == 0 or col == BasicoArbol.COLUMNAS - 1) else NodoUI.Forma.ROMBO
			if col < elec.size():
				var mia: bool = String(elec[col]) == id
				estados[String(n.id)] = "tuyo" if mia else "cerrado"
				if mia:
					tuyos.append(String(n.id))
			else:
				var m: String = BasicoArbol.motivo_no_nodo(tipo, d, col, id, int(pj.level), int(pj.piso_hondo), Game.money)
				estados[String(n.id)] = "puedes" if m == "" else "falta"
		antes = aqui
	return {"nodos": nodos, "tuyos": tuyos, "estados": estados, "formas": formas, "llevas": pasos,
		"total": BasicoArbol.COLUMNAS * 3}


# Lo que da un paso de los pisos 4 u 8 (la frase de su nodo).
static func _que_da_paso(tipo: int, k: int) -> String:
	if tipo == WeaponData.Tipo.BASTON:
		return "Maná al acertar el básico: +%s del máximo." % BasicoArbol._pct(BasicoArbol.MANA_PISO_4) if k % 3 == 0 			else "Energía que repone el básico: +%s." % BasicoArbol._pct(BasicoArbol.ENERGIA_PISO_8)
	var antes: float = BasicoArbol.mult_dano(k)
	var luego: float = BasicoArbol.mult_dano(k + 1)
	var txt: String = "Daño del básico: %s → %s." % [BasicoArbol._pct(antes), BasicoArbol._pct(luego)]
	if k % 3 == 1:
		txt += " Energía que repone: +%s." % BasicoArbol._pct(BasicoArbol.ENERGIA_PISO_8)
	return txt


func _columnas_basico(_pj: PersonajeData) -> int:
	return BasicoArbol.COLUMNAS * 3


# La altura media (relativa) de lo que tiene justo detras (la del icono, 0, si cuelga de el).
func _altura_detras(id: StringName, detras: Dictionary, rel: Dictionary) -> float:
	var suma: float = 0.0
	var k: int = 0
	for x in detras.get(id, []):
		if rel.has(StringName(x)):
			suma += float(rel[StringName(x)])
			k += 1
	return suma / float(k) if k > 0 else 0.0


# A la rejilla de pixel (P): asi los nodos y las lineas caen en el mismo pixel gordo que los iconos.
static func _px_g(v: float) -> float:
	return floorf(v / P) * P


# Cuantas columnas de mejoras tiene el arbol de una ficha (su profundidad).
func _columnas(f: Resource) -> int:
	var nodos: Array = (f.arbol as Array).filter(func(n): return n != null)
	var hondo: Dictionary = {}
	for _vuelta in nodos.size() + 1:
		for n in nodos:
			var dd: int = 1
			for pa in n.padres:
				if hondo.has(StringName(pa)):
					dd = maxi(dd, int(hondo[StringName(pa)]) + 1)
			hondo[StringName(n.id)] = dd
	var m: int = 0
	for k in hondo:
		m = maxi(m, int(hondo[k]))
	return m


# (24/11) LOS ICONOS PROPIOS de las habilidades y de sus nodos (tools/iconos_habilidades_pixel.py --hornear).
const CARPETA_ICONOS := "res://assets/ui/habilidades/"


static func _png_nodo(f: Resource, id: StringName) -> String:
	return CARPETA_ICONOS + "%s__%s.png" % [String(f.resource_path).get_file().get_basename(), String(id)]


# Un PNG de 12 x 12 pintado a su tamaño, o el dibujo de respaldo si no existe.
static func _dibujo_png(ruta: String, respaldo: Callable) -> Callable:
	if not ResourceLoader.exists(ruta):
		return respaldo
	var tex: Texture2D = load(ruta)
	return func(ci: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
		ci.draw_texture_rect(tex, Rect2(pos, Vector2(lado, lado)), false, Color(1, 1, 1, col.a))


# El dibujo de siempre con un "+" de pixel arriba a la derecha (los rombos de la linea del 6 al 16): cruz de 3 x 3
# pixeles del icono, clara, con su borde oscuro para que se lea encima de cualquier dibujo.
const MAS_CLARO := Color(1.0, 0.86, 0.35)
const MAS_BORDE := Color(0.05, 0.04, 0.03)


static func _con_mas(base: Callable) -> Callable:
	return func(ci: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
		if base.is_valid():
			base.call(ci, pos, lado, col)
		var u: float = lado / 12.0
		var cruz: Array[Vector2i] = [Vector2i(10, 0), Vector2i(9, 1), Vector2i(10, 1), Vector2i(11, 1), Vector2i(10, 2)]
		var borde := Color(MAS_BORDE, col.a)
		for c in cruz:   # el borde: los vecinos de la cruz (dentro del icono), luego la cruz encima
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var v: Vector2i = c + d
				if v.x <= 11 and v.y >= 0 and not cruz.has(v):
					ci.draw_rect(Rect2(pos + Vector2(v) * u, Vector2(u, u)), borde)
		var claro := Color(MAS_CLARO, col.a)
		for c in cruz:
			ci.draw_rect(Rect2(pos + Vector2(c) * u, Vector2(u, u)), claro)


# EL DIBUJO del icono de una fila: el grimorio de la magia, o el de la habilidad (su PNG; si no tiene, el arma).
func _dibujo_icono(f: Resource, arma: Resource) -> Callable:
	if f is AbilityData:
		var propio: Callable = _dibujo_png(CARPETA_ICONOS + String(f.resource_path).get_file().get_basename() + ".png", Callable())
		if propio.is_valid():
			return propio
	if f is SpellData:
		var tex: Texture2D = LibrosPixel.textura(LibrosPixel.id_de_magia(f))
		if tex != null:
			return func(ci: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
				ci.draw_texture_rect(tex, Rect2(pos, Vector2(lado, lado)), false, Color(1, 1, 1, col.a))
		return Callable(Iconos, "libro")
	# El mismo icono que el arma en la fila de armas (MenuScaffold.icono_de_arma: siempre uno que existe en Iconos).
	return Callable(Iconos, MenuScaffold.icono_de_arma(arma) if arma != null else "habilidades")


# LA FICHA DEL BASICO (23/11, basico_arbol.gd). Sin nodo elegido: la LINEA (daño, energia, sus pasos) y el boton de los
# pisos 4 y 8, y lo que llevas. Con un nodo del arbol elegido: lo que hace, lo que pide y pagarlo (es el paso del piso 12).
func _pintar_ficha_basico(content: VBoxContainer, pj: PersonajeData, arma: Resource) -> void:
	MenuScaffold.titulo(content, "Ataque básico", 18)
	if not (arma is WeaponData) or int(arma.tipo) == WeaponData.Tipo.PUNOS:
		MenuScaffold.nota(content, "Los puños no tienen árbol.")
		return
	var tipo: int = int(arma.tipo)
	var d: Dictionary = Game.basico_de(tipo, pj)
	var pasos: int = int(d.get("pasos", 0))
	var elec: Array = d.get("elec", [])
	MenuScaffold.nota(content, "Con %s. Lo que mejoras aquí vale para el básico de cualquier %s." % [String(arma.nombre),
		String(arma.nombre).to_lower()])
	MenuScaffold.separador(content)
	# LA LINEA, siempre arriba
	if tipo == WeaponData.Tipo.BASTON:
		var arb: Dictionary = BasicoArbol.de_mano(d, tipo)
		MenuScaffold.fila(content, "Maná al acertar", "+%s del máximo" % BasicoArbol._pct(float(arb["mana_extra"])))
		MenuScaffold.fila(content, "Marca", ("+%s al siguiente hechizo (hasta %d)" % [BasicoArbol._pct(float(arb["marca"])),
			BasicoArbol.MARCA_TOPE]) if float(arb["marca"]) > 0.0 else "todavía no")
	else:
		MenuScaffold.fila(content, "Daño del básico", BasicoArbol._pct(BasicoArbol.mult_dano(pasos)))
	MenuScaffold.fila(content, "Energía que repone", "x%s" % String.num(BasicoArbol.mult_energia(pasos), 2).replace(".", ","))
	var sel: String = String(nodo_sel)
	if sel == "":
		MenuScaffold.nota(content, "Clica un nodo del árbol para ver qué da y mejorarlo: los círculos son los pisos 4 y 8 de cada nivel; en el 12 eliges una de dos.")
		if not elec.is_empty():
			MenuScaffold.separador(content)
			MenuScaffold.titulo(content, "Lo que llevas", 14, VERDE)
			var fac: Dictionary = d.get("fac", {})
			for id in fac:
				MenuScaffold.nota(content, "· %s (rango %d): %s" % [String(BasicoArbol.facultad(tipo, String(id)).get("nombre", id)),
					int(fac[id]), BasicoArbol.frase(tipo, String(id), int(fac[id]))])
		return
	# UN PASO DE LA LINEA ELEGIDO (pisos 4 y 8)
	if sel.begins_with("l"):
		var k: int = int(sel.substr(1))
		MenuScaffold.separador(content)
		MenuScaffold.titulo(content, "Nivel %d, piso %d" % [BasicoArbol.nivel_de_paso(k), BasicoArbol.piso_de_paso(k)], 16, AMBAR)
		MenuScaffold.nota(content, _que_da_paso(tipo, k))
		if k < pasos:
			MenuScaffold.titulo(content, "Ya lo tienes", 14, VERDE)
			return
		MenuScaffold.titulo(content, "Pide", 14)
		_req(content, "Haber llegado al piso %d" % BasicoArbol.piso_de_paso(k), int(pj.piso_hondo) >= BasicoArbol.piso_de_paso(k))
		if k > pasos:
			_req(content, "Lo anterior del árbol", false)
		_req(content, "%d monedas" % BasicoArbol.oro_paso(k), Game.money >= BasicoArbol.oro_paso(k))
		var ml: String = BasicoArbol.motivo_no_paso(pasos, int(pj.level), int(pj.piso_hondo), Game.money) if k == pasos else "falta lo anterior"
		MenuScaffold.boton(content, "Mejorar (%d monedas)" % BasicoArbol.oro_paso(k), func() -> void:
			var r: String = Game.comprar_paso_basico(tipo, pj)
			_menu._aviso = "Básico mejorado." if r == "" else ("No se puede: " + r)
			_menu._aviso_ok = (r == "")
			_menu._rebuild(), ml == "")
		return
	# UN NODO DEL PISO 12 ELEGIDO
	var col: int = int(sel.get_slice("_", 0).substr(1))
	var id: String = sel.substr(sel.find("_") + 1)
	var fd: Dictionary = BasicoArbol.facultad(tipo, id)
	MenuScaffold.separador(content)
	var rango_ahora: int = int((d.get("fac", {}) as Dictionary).get(id, 0))
	var tuyo: bool = col < elec.size() and String(elec[col]) == id
	var rango: int = rango_ahora if tuyo else mini(rango_ahora + 1, BasicoArbol.RANGO_MAX)
	MenuScaffold.titulo(content, "%s (rango %d)" % [String(fd.get("nombre", id)), rango], 16, AMBAR)
	MenuScaffold.nota(content, BasicoArbol.frase(tipo, id, rango))
	if bool(fd.get("excl", false)):
		MenuScaffold.nota(content, "Principal: elegirla cierra la otra para siempre.")
	if tuyo:
		MenuScaffold.titulo(content, "Ya la tienes", 14, VERDE)
		return
	if col < elec.size():
		MenuScaffold.nota(content, "En este nivel elegiste %s." % String(BasicoArbol.facultad(tipo, String(elec[col])).get("nombre", "")))
		return
	MenuScaffold.titulo(content, "Pide", 14)
	var paso_12: int = col * 3 + 2
	_req(content, "Nivel %d" % (col + 2), int(pj.level) >= col + 2)
	_req(content, "Haber llegado al piso %d" % BasicoArbol.piso_de_paso(paso_12), int(pj.piso_hondo) >= BasicoArbol.piso_de_paso(paso_12))
	_req(content, "Los pisos 4 y 8 de este nivel", pasos >= paso_12)
	if col > elec.size():
		_req(content, "Lo del nivel anterior", false)
	_req(content, "%d monedas" % BasicoArbol.oro_paso(paso_12), Game.money >= BasicoArbol.oro_paso(paso_12))
	MenuScaffold.nota(content, "Trae también el paso del piso %d: más daño y energía." % BasicoArbol.piso_de_paso(paso_12))
	var m: String = BasicoArbol.motivo_no_nodo(tipo, d, col, id, int(pj.level), int(pj.piso_hondo), Game.money)
	MenuScaffold.boton(content, "Mejorar (%d monedas)" % BasicoArbol.oro_paso(paso_12), func() -> void:
		var r: String = Game.comprar_nodo_basico(tipo, col, id, pj)
		_menu._aviso = ("%s conseguida." % String(fd.get("nombre", id))) if r == "" else ("No se puede: " + r)
		_menu._aviso_ok = (r == "")
		_menu._rebuild(), m == "")


# El estado de un nodo: "tuyo", "puedes", "falta" (le falta algo) o "cerrado" (otra rama lo cierra).
func _estado(pj: PersonajeData, base: Resource, n: Resource, cogidos: Array) -> String:
	if cogidos.has(String(n.id)):
		return "tuyo"
	for x in n.excluye:
		if cogidos.has(String(x)):
			return "cerrado"
	return "puedes" if Mejoras.motivo_no(pj, base, StringName(n.id), int(pj.level), Game.money) == "" else "falta"


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
	_pintar_dominio(content, pj, base)
	MenuScaffold.separador(content)
	var n: Resource = Mejoras.nodo(base, nodo_sel) if nodo_sel != &"" else null
	if n == null:
		if String(base.get("descripcion")) != "":
			MenuScaffold.nota(content, String(base.get("descripcion")))
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
	for linea in texto_cambios(base, n, (pj.nodos_elegidos as Dictionary).get(ruta, [])):
		MenuScaffold.nota(content, "· " + linea)
	MenuScaffold.titulo(content, "Pide", 14)
	var cogidos2: Array = (pj.nodos_elegidos as Dictionary).get(ruta, [])
	var padres_ok: bool = (n.padres as Array).is_empty() or (n.padres as Array).any(func(pa): return cogidos2.has(String(pa)))
	if not (n.padres as Array).is_empty():
		var nombres: Array = (n.padres as Array).map(func(pa):
			var x: Resource = Mejoras.nodo(base, StringName(pa))
			return String(x.nombre) if x != null else String(pa))
		# (24/11) con muchos (los que se cogen desde cualquiera del nivel anterior), sin la lista: ensanchaba el panel
		if nombres.size() >= 3:
			var p0: Resource = Mejoras.nodo(base, StringName(n.padres[0]))
			_req(content, "Antes: cualquiera de los %d del nivel %d" % [nombres.size(), int(p0.nivel_min) if p0 != null else 0],
				padres_ok)
		else:
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
	MenuScaffold.boton(content, "Mejorar (%d monedas)" % int(n.oro), func() -> void:
		var r: String = Game.coger_nodo(base, StringName(n.id), pj)
		_menu._aviso = ("Mejora conseguida: %s" % n.nombre) if r == "" else ("No se puede: " + r)
		_menu._aviso_ok = (r == "")
		_menu._rebuild(), motivo == "")


# EL DOMINIO (24/11, el jefe): "Dominio 137 / 300" (lo que llevas y lo siguiente que pide su arbol), una barra hasta
# ahi y, en el COLOR de como sube, a que ritmo sube en el piso (Mejoras.prob_dominio): en la mazmorra el de ahora; en el
# pueblo, el mas hondo al que has llegado (es donde la entrenarias).
const NOMBRE_RITMO := {
	Mejoras.Ritmo.NARANJA: "sube siempre",
	Mejoras.Ritmo.AMARILLO: "sube bien",
	Mejoras.Ritmo.VERDE: "sube poco",
	Mejoras.Ritmo.GRIS: "ya no sube: baja más hondo",
}

func _pintar_dominio(content: VBoxContainer, pj: PersonajeData, base: Resource) -> void:
	var d: int = int((pj.dominio as Dictionary).get(String(base.resource_path), 0))
	var meta: int = Mejoras.dominio_siguiente(pj, base)
	var en_mazmorra: bool = _en_mazmorra()
	var piso: int = Mejoras.piso_de_ahora() if en_mazmorra else maxi(1, int(pj.piso_hondo))
	var ritmo: int = Mejoras.ritmo_dominio(d, piso)
	var col: Color = Mejoras.COLOR_RITMO[ritmo]
	MenuScaffold.fila(content, "Dominio", ("%d / %d" % [d, meta]) if meta > 0 else str(d), 200, col)
	# La barra: hasta lo siguiente que pide (sin nada mas que pedir, llena).
	var fondo := ColorRect.new()
	fondo.color = OSCURO
	fondo.custom_minimum_size = Vector2(0, 3.0 * P)
	fondo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lleno := ColorRect.new()
	lleno.color = col
	lleno.anchor_bottom = 1.0
	lleno.anchor_right = clampf(float(d) / float(meta), 0.0, 1.0) if meta > 0 else 1.0
	fondo.add_child(lleno)
	content.add_child(fondo)
	var l := Label.new()
	var donde: String = ("en este piso (%d)" % piso) if en_mazmorra 		else "en el piso %d (el más hondo al que has llegado)" % piso
	var prob: int = roundi(Mejoras.prob_dominio(d, piso) * 100.0)
	l.text = "%s: %s" % [donde[0].to_upper() + donde.substr(1), NOMBRE_RITMO[ritmo]] 		+ ((", un %d %% de los usos" % prob) if prob > 0 else "")
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)


# ¿En la mazmorra (la escena de los pisos)? Fuera de ella (el pueblo, una herramienta) manda tu piso mas hondo.
func _en_mazmorra() -> bool:
	var s: Node = (Engine.get_main_loop() as SceneTree).current_scene
	return s != null and s.scene_file_path.ends_with("levels/main.tscn")


func _req(content: VBoxContainer, txt: String, ok: bool) -> void:
	var l := Label.new()
	l.text = ("✓ " if ok else "· ") + txt
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", VERDE if ok else GRIS)
	content.add_child(l)


# LO QUE CAMBIA UN NODO, con los numeros REALES: la habilidad montada con el camino que lleva el personaje (o el mas
# corto hasta este nodo, si aun no lo tiene) SIN el nodo, contra la misma CON el. «Daño de cada golpe: 90 % -> 88 % del
# Ataque de quien la usa», «Coste de energía: 48 -> 67 (con dos armas: 70 -> 98)».
static func texto_cambios(base: Resource, n: Resource, cogidos: Array = []) -> Array:
	if not (base is AbilityData):
		return texto_cambios_viejo(base, n)
	var camino: Array = camino_hasta(base, n, cogidos)
	var antes: AbilityData = Mejoras.montar_sin_nombre(base, _en_orden(base, camino)) as AbilityData
	var despues: AbilityData = Mejoras.montar_sin_nombre(base, _en_orden(base, camino + [n])) as AbilityData
	var out: Array = []
	for fila in FILAS_ANTES_DESPUES:
		var nombre_f: String = String(fila[1])
		if String(fila[0]) == "dano_mult" and base.golpe_txt != "":
			nombre_f = "Daño " + base.golpe_txt   # «Daño del salto», «Daño de cada tajo»
		var l: String = _fila_antes_despues(antes, despues, String(fila[0]), nombre_f, String(fila[2]))
		if l != "":
			out.append(l)
	# Lo PROPIO de cada mecanica (remates, cargas, lo que se pone al saltar...): lo escribe la habilidad.
	for c in (n.cambios as Dictionary):
		for frase in despues.frase_mejora(String(c), antes).split("\n", false):
			if not out.has(frase):
				out.append(frase)
	return out


# Los nodos que lleva el personaje en esta ficha (menos este) y, si le falta el anterior, el camino mas corto hasta el:
# siempre el PRIMER padre que no cierre nada de lo que ya lleva.
static func camino_hasta(base: Resource, n: Resource, cogidos: Array) -> Array:
	var out: Array = []
	for id in cogidos:
		var x: Resource = Mejoras.nodo(base, StringName(id))
		if x != null and x != n:
			out.append(x)
	var actual: Resource = n
	var vueltas: int = 0
	while actual != null and not (actual.padres as Array).is_empty() and vueltas < 32:
		vueltas += 1
		if (actual.padres as Array).any(func(pa): return out.any(func(x): return StringName(x.id) == StringName(pa))):
			break
		var siguiente: Resource = null
		for pa in actual.padres:
			var cand: Resource = Mejoras.nodo(base, StringName(pa))
			if cand != null and not out.any(func(x): return (x.excluye as Array).has(cand.id) or (cand.excluye as Array).has(x.id)):
				siguiente = cand
				break
		if siguiente == null:
			break
		out.append(siguiente)
		actual = siguiente
	return out


static func _en_orden(base: Resource, nodos: Array) -> Array:
	return (base.arbol as Array).filter(func(x): return nodos.has(x))


static func _fila_antes_despues(a: AbilityData, d: AbilityData, campo: String, nombre: String, como: String) -> String:
	match como:
		"golpes_3":
			# Lo que mete DE VERDAD con 3 enemigos (los golpes extra se redondean hacia abajo): «1,44 golpes» no se entiende.
			if is_equal_approx(a.golpes_extra_por_enemigo, d.golpes_extra_por_enemigo) \
					and is_equal_approx(a.golpes_extra_por_enemigo_dual, d.golpes_extra_por_enemigo_dual):
				return ""
			var l3: String = "%s: %d → %d" % [nombre, a.num_golpes(1, 3), d.num_golpes(1, 3)]
			if d.golpes_dual_max > 0:
				l3 += " (con dos armas: %d → %d)" % [a.num_golpes(2, 3), d.num_golpes(2, 3)]
			return l3
		"golpes":
			var g_a: String = a._golpes_txt(1)
			var g_d: String = d._golpes_txt(1)
			var dual_a: String = a._golpes_txt(2) if a.golpes_dual_max > 0 else ""
			var dual_d: String = d._golpes_txt(2) if d.golpes_dual_max > 0 else ""
			if g_a == g_d and dual_a == dual_d:
				return ""
			var l: String = "%s: %s → %s" % [nombre, g_a, g_d]
			if dual_d != "" and dual_a != dual_d:
				l += " (con dos armas: %s → %s)" % [dual_a, dual_d]
			return l
		"coste":
			var e_a: float = a.coste_energia
			var e_d: float = d.coste_energia
			var du_a: float = a.coste_energia_dual
			var du_d: float = d.coste_energia_dual
			if is_equal_approx(e_a, e_d) and is_equal_approx(du_a, du_d):
				return ""
			var l2: String = "%s: %d → %d" % [nombre, roundi(e_a), roundi(e_d)]
			if du_d > 0.0:
				l2 += " (con dos armas: %d → %d)" % [roundi(du_a), roundi(du_d)]
			return l2
	if not (campo in a):
		return ""
	var va = a.get(campo)
	var vd = d.get(campo)
	if (va is float or va is int) and is_equal_approx(float(va), float(vd)):
		return ""
	if not (va is float or va is int) and va == vd:
		return ""
	return "%s: %s → %s%s" % [nombre, _valor(va, como), _valor(vd, como),
		" del Ataque de quien la usa" if como == "pct_atk" else ""]


static func _valor(v, como: String) -> String:
	match como:
		"pct", "pct_atk":
			return AbilityData._pct_entero(float(v))
		"dec":
			return MenuScaffold.valor_es(str(snappedf(float(v), 0.01)))
		"dist":
			return "nada" if float(v) <= 0.0 else AbilityData.casillas_txt(float(v))
		"grados":
			return "%d°" % roundi(float(v))
	return str(roundi(float(v))) if (v is float or v is int) else str(v)


# Lo de antes (las magias, hasta que tengan su antes -> despues): una linea por cambio ("+10 % de daño").
static func texto_cambios_viejo(base: Resource, n: Resource) -> Array:
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


# EL LIENZO del arbol: los nodos van encima; debajo, las lineas y las rayas tenues entre fila y fila. TODO EN PIXEL
# (23/11, el jefe: "no son pixel art"): las lineas van en escalera de pixeles gordos (P x P), con su sombra debajo.
class Lienzo extends Control:
	var lineas: Array = []   # [PackedVector2Array de puntos, color]
	var rayas: Array = []    # 'y' de la raya bajo cada fila
	var ancho_fila: float = 0.0

	func _draw() -> void:
		for y in rayas:
			var yy: float = floorf(float(y) / P) * P
			for x in range(3, int(size.x / P) - 3):
				if x % 2 == 0:
					draw_rect(Rect2(Vector2(x * P, yy), Vector2(P, P)), Color(1, 1, 1, 0.10))
		for l in lineas:
			var pts: PackedVector2Array = l[0]
			var col: Color = l[1]
			var celdas: Dictionary = {}
			for i in pts.size() - 1:
				for c in _bresenham(Vector2i((pts[i] / P).floor()), Vector2i((pts[i + 1] / P).floor())):
					celdas[c] = true
			for c in celdas:   # la sombra, un pixel por debajo
				draw_rect(Rect2(Vector2(c) * P + Vector2(0, P), Vector2(P, P)), Color(0, 0, 0, 0.55))
			for c in celdas:
				draw_rect(Rect2(Vector2(c) * P, Vector2(P, P)), col)

	static func _bresenham(a: Vector2i, b: Vector2i) -> Array:
		var out: Array = []
		var dx: int = absi(b.x - a.x)
		var dy: int = -absi(b.y - a.y)
		var sx: int = 1 if a.x < b.x else -1
		var sy: int = 1 if a.y < b.y else -1
		var err: int = dx + dy
		var p := a
		while true:
			out.append(p)
			if p == b:
				break
			var e2: int = 2 * err
			if e2 >= dy:
				err += dy
				p.x += sx
			if e2 <= dx:
				err += dx
				p.y += sy
		return out


# UN NODO: el cuadro de la habilidad, o una mejora en circulo o en rombo, EN PIXEL: contorno oscuro, el aro del color de
# su estado (verde tuyo, ambar lo puedes coger, gris te falta algo, oscuro cerrado) con su brillo arriba a la izquierda,
# y el fondo; el elegido, con un aro ambar por fuera. Se dibuja a la rejilla P y se cachea por forma, estado y tamaño.
class NodoUI extends Control:
	enum Forma { CUADRO, CIRCULO, ROMBO }
	signal pulsado
	const AMBAR := Color(0.95, 0.72, 0.36)
	const NEGRO := Color(0.04, 0.04, 0.06)
	const COLORES := {"tuyo": Color(0.55, 0.85, 0.55), "puedes": Color(0.95, 0.72, 0.36),
		"falta": Color(0.6, 0.63, 0.7), "cerrado": Color(0.32, 0.34, 0.4)}
	const MARCO := 3   # pixeles de margen alrededor (para el aro del elegido)
	static var _cache: Dictionary = {}
	var forma: int = Forma.CIRCULO
	var dibujo: Callable
	var estado: String = "falta"
	var elegido: bool = false
	var _encima: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_entered.connect(func() -> void:
			_encima = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_encima = false
			queue_redraw())

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pulsado.emit()
			accept_event()

	func _draw() -> void:
		var n: int = int(size.x / P)
		var tex: Texture2D = _textura(forma, estado, elegido, _encima, n)
		var lado: float = float(n + MARCO * 2) * P
		draw_texture_rect(tex, Rect2(Vector2(-MARCO * P, -MARCO * P), Vector2(lado, lado)), false)
		# EL ICONO, dentro: en pixeles del mismo tamaño (12 px de dibujo x3); apagado si esta cerrado.
		if dibujo.is_valid():
			var lado_i: float = 12.0 * P
			var col: Color = COLORES.get(estado, COLORES["falta"])
			var tinte: Color = col if estado != "cerrado" else Color(col, 0.6)
			var c: Vector2 = (size * 0.5 - Vector2(lado_i, lado_i) * 0.5).floor()
			dibujo.call(self, c, lado_i, tinte)

	static func _textura(forma_: int, estado_: String, eleg: bool, encima: bool, n: int) -> Texture2D:
		var k: String = "%d_%s_%d_%d_%d" % [forma_, estado_, int(eleg), int(encima), n]
		if _cache.has(k):
			return _cache[k]
		var t: int = n + MARCO * 2
		var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
		var col: Color = COLORES.get(estado_, COLORES["falta"])
		var fondo: Color = Color(0.09, 0.09, 0.12) if not encima else Color(0.16, 0.16, 0.21)
		var r: float = float(n) * 0.5
		var cc: float = float(t) * 0.5
		var grueso: float = 2.0 if estado_ == "tuyo" else 1.0
		for y in t:
			for x in t:
				var dx: float = float(x) + 0.5 - cc
				var dy: float = float(y) + 0.5 - cc
				var d: float
				match forma_:
					Forma.CUADRO: d = maxf(absf(dx), absf(dy))
					Forma.ROMBO: d = (absf(dx) + absf(dy)) * 0.78
					_: d = sqrt(dx * dx + dy * dy)
				var c := Color(0, 0, 0, 0)
				if d <= r:
					if d > r - 1.0:
						c = NEGRO
					elif d > r - 1.0 - grueso:
						c = col.lightened(0.3) if dx + dy < -1.0 else col
					elif d > r - 2.0 - grueso:
						c = col.darkened(0.55)
					else:
						c = fondo
				elif eleg and d > r + 1.0 and d <= r + 2.0:
					c = AMBAR
				elif eleg and d > r + 2.0 and d <= r + 3.0:
					c = NEGRO
				img.set_pixel(x, y, c)
		var tex := ImageTexture.create_from_image(img)
		_cache[k] = tex
		return tex
