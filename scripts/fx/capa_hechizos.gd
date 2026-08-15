# ============================================================
#  capa_hechizos.gd  (class_name CapaHechizos)
#  LO QUE VUELA entre las tarjetas de la pantalla de combate: el rayo que sale disparado, la bola
#  de fuego, las gotas y los rayos de la tormenta cayendo del cielo, la ola que barre la fila y
#  el rombo arcano. Y los arcos de los rebotes, que saltan de una victima a la siguiente.
#
#  Existe porque la embestida de tarjeta (CombatFX) esta bien para un tajo y fatal para un
#  conjuro: un mago no se lanza contra el bicho, se queda quieto y lo que viaja es la magia.
#
#  UN SOLO NODO CON UNA LISTA, no un nodo por proyectil. Un turno de Tormenta son ~32 impactos:
#  con un nodo cada uno serian 32 creados y liberados en dos segundos, y limpiar la pantalla tras
#  un desatasco (la tecla P) seria una caceria de huerfanos. Con una lista es _efectos.clear().
#  Ademas el orden de dibujo pasa a ser el orden de la lista -- o sea, el orden de la cola de
#  impactos -- y no el orden de los hermanos en el arbol, que es mucho mas facil de razonar.
#
#  Las FORMAS son las de scripts/actors/player/proyectil_hechizo.gd, el proyectil que ya vuela por
#  la mazmorra: se copian y no se reutiliza el nodo porque aquel es un Node2D que da por hecho que
#  vive en el mundo (z_index absoluto, y al reventar cuelga la chispa de su padre).
#
#  Dos reglas que parecen detalles y no lo son:
#   - Los puntos A y B se CONGELAN al nacer el efecto. Si se leyeran cada frame, el proyectil
#     temblaria con la sacudida de la tarjeta a la que va, y reventaria si esa tarjeta se libera
#     a mitad de vuelo.
#   - El azar (rehacer el zigzag) va en _process, NUNCA en _draw: _draw puede llamarse cero o
#     varias veces en el mismo frame, y el rayo bailaria de forma distinta cada vez.
# ============================================================

extends Control
class_name CapaHechizos

const ZIGZAG_CADA := 0.04    # cada cuanto se rehace el chisporroteo
const FUERA := -20.0         # de que altura caen los rayos y las gotas (por encima del techo)

# Cada efecto vivo. Se reciclan los diccionarios: en una tormenta se dan de alta 32 en dos
# segundos y no hace falta que el recolector se entere.
var _efectos: Array[Dictionary] = []
var _pool: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false   # un rayo que cae del cielo empieza FUERA de la capa
	# OBLIGATORIO: en solitario el arbol del juego esta pausado durante el combate (en multi no).
	# Sin esto los conjuros se ven jugando con un compañero y se congelan jugando solo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# Da de alta un efecto. 'a' = de donde sale (la tarjeta del que lanza, o de la victima anterior en
# un rebote), 'b' = donde impacta. 'dur' es el tiempo de vuelo que le ha reservado la cola, para
# que el impacto aterrice justo cuando salen el numero y el temblor.
func alta(estilo: int, a: Vector2, b: Vector2, color: Color, peso: float, dur: float,
		ancho_destino: float) -> void:
	var e: Dictionary = _pool.pop_back() if not _pool.is_empty() else {}
	e.clear()
	e["estilo"] = estilo
	e["b"] = b
	e["col"] = color
	e["t"] = 0.0
	e["dur"] = maxf(dur, 0.05)
	e["semilla"] = randf() * TAU
	# El tamaño tambien lleva informacion: el que come el golpe entero recibe una bola mas gorda
	# que el que solo se lleva la salpicadura.
	e["r"] = lerpf(7.0, 16.0, clampf(peso, 0.0, 1.5) / 1.5)
	e["ancho"] = ancho_destino
	e["zig"] = PackedVector2Array()
	e["prox"] = 0.0
	e["curva"] = false
	e["gotas"] = []

	match estilo:
		CombatFX.Estilo.CAIDA_RAYO, CombatFX.Estilo.CAIDA_GOTA:
			# Del cielo: el origen es el techo de la pantalla, justo encima del objetivo.
			e["a"] = Vector2(b.x + randf_range(-14.0, 14.0), FUERA)
		CombatFX.Estilo.ARCO:
			e["a"] = a
			# Un rebote puede caer OTRA VEZ en el mismo bicho (pasa siempre en 1v1). Entonces no hay
			# trayecto que dibujar, asi que el arco sale de la tarjeta, da la vuelta por arriba y
			# vuelve a ella. El lado alterna al azar, para que cinco rebotes seguidos sobre el mismo
			# se vean como cinco arcos distintos y se puedan contar.
			if a.distance_to(b) < 4.0:
				e["curva"] = true
				e["ctrl"] = a + Vector2(randf_range(60.0, 90.0) * (1.0 if randf() < 0.5 else -1.0), -70.0)
		_:
			# Si no hay tarjeta de origen (pasa en el espejo cuando el lanzador no esta en el
			# roster que le llego), el conjuro saldria de la esquina de la pantalla. Se le hace
			# nacer por debajo del objetivo, que es de donde viene lo tuyo: tu fila esta abajo.
			e["a"] = a if a != Vector2.ZERO else b + Vector2(0.0, 180.0)

	if estilo == CombatFX.Estilo.CAIDA_GOTA:
		# Un chaparron no es UNA gota: son varias, cada una con su desfase y su desvio.
		var n: int = 3 + (randi() % 3)
		for i in n:
			e["gotas"].append([randf_range(-e["r"] * 2.2, e["r"] * 2.2), randf() * 0.35])

	_efectos.append(e)


# Vacia la pantalla YA. La llama CombatFX.cancelar (o sea, la tecla P y el final de la pelea): sin
# esto se quedarian bolas y rayos pintados en el aire para siempre.
func limpiar() -> void:
	for e in _efectos:
		_pool.append(e)
	_efectos.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _efectos.is_empty():
		return
	var i: int = _efectos.size() - 1
	while i >= 0:
		var e: Dictionary = _efectos[i]
		e["t"] = float(e["t"]) + delta
		# El chisporroteo del rayo se rehace AQUI y no en _draw (ver cabecera).
		if _es_rayo(int(e["estilo"])) and float(e["t"]) >= float(e["prox"]):
			e["prox"] = float(e["t"]) + ZIGZAG_CADA
			e["zig"] = _nuevo_zigzag(e)
		if float(e["t"]) >= _vida(e):
			_pool.append(e)
			_efectos.remove_at(i)
		i -= 1
	queue_redraw()


# Lo que dura el efecto ENTERO: el vuelo mas la coleta de despues (el reventon, el resplandor del
# rayo apagandose, la salpicadura de la gota).
func _vida(e: Dictionary) -> float:
	var extra: float = 0.18 if _es_rayo(int(e["estilo"])) else 0.12
	return float(e["dur"]) + extra


func _es_rayo(estilo: int) -> bool:
	return estilo == CombatFX.Estilo.RAYO or estilo == CombatFX.Estilo.CAIDA_RAYO \
		or estilo == CombatFX.Estilo.ARCO


# ------------------------------------------------------------
#  DIBUJO
# ------------------------------------------------------------

func _draw() -> void:
	for e in _efectos:
		match int(e["estilo"]):
			CombatFX.Estilo.PROYECTIL: _pintar_fuego(e)
			CombatFX.Estilo.RAYO, CombatFX.Estilo.CAIDA_RAYO, CombatFX.Estilo.ARCO: _pintar_rayo(e)
			CombatFX.Estilo.CAIDA_GOTA: _pintar_gotas(e)
			CombatFX.Estilo.BARRIDO: _pintar_ola(e)
			CombatFX.Estilo.ARCANO: _pintar_arcano(e)


# BOLA DE FUEGO que vuela acelerando (u*u: sale de la mano despacio y llega lanzada), con estela
# detras, y que revienta en un anillo al llegar.
func _pintar_fuego(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	var u: float = clampf(t / float(e["dur"]), 0.0, 1.0)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.DOWN

	if u < 1.0:
		var p: Vector2 = a.lerp(b, u * u)
		# ESTELA: tres bolas cada vez mas pequeñas y transparentes por detras.
		for k in 3:
			var uk: float = maxf(0.0, u - 0.06 * float(k + 1))
			var pk: Vector2 = a.lerp(b, uk * uk)
			draw_circle(pk, r * (0.55 - 0.13 * float(k)), Color(col.r, col.g, col.b, 0.30 - 0.08 * float(k)))
		# LA BOLA: lengüetas que se estiran hacia atras (el aire se las peina), halo y nucleo claro.
		var pulso: float = 1.0 + 0.12 * sin(t * 14.0 + float(e["semilla"]))
		var rr: float = r * pulso
		var atras: Vector2 = -dir
		var puntas := PackedVector2Array()
		var n := 9
		for i in n:
			var ang: float = TAU * float(i) / float(n)
			var dirp := Vector2(cos(ang), sin(ang))
			var estira: float = 1.0 + 0.85 * maxf(0.0, dirp.dot(atras))
			var ondeo: float = 1.0 + 0.22 * sin(t * 18.0 + float(i) * 1.7 + float(e["semilla"]))
			puntas.append(p + dirp * rr * estira * ondeo)
		draw_colored_polygon(puntas, Color(col.r, col.g, col.b, 0.55))
		draw_circle(p, rr * 0.62, col)
		draw_circle(p, rr * 0.34, Color(1.0, 0.95, 0.75))
	else:
		# EL REVENTON: un anillo que se abre y se apaga.
		var v: float = clampf((t - float(e["dur"])) / 0.12, 0.0, 1.0)
		draw_arc(b, r * (1.0 + 3.0 * v), 0.0, TAU, 20, Color(col.r, col.g, col.b, 1.0 - v), 3.0, true)


# RAYO. NO viaja: EXISTE. La polilinea cubre el camino entero desde el primer frame y luego se
# apaga -- una bolita recorriendo la trayectoria no se lee como un rayo, se lee como una canica.
# Las tres pasadas (resplandor gordo translucido, color, nucleo blanco fino) son el estilo de la
# casa, copiado del proyectil de la mazmorra.
func _pintar_rayo(e: Dictionary) -> void:
	var zig: PackedVector2Array = e["zig"]
	if zig.size() < 2:
		return
	var col: Color = e["col"]
	var t: float = e["t"]
	var dur: float = e["dur"]
	# Brilla entero mientras "llega" y se apaga despues.
	var alfa: float = 1.0 if t < dur else clampf(1.0 - (t - dur) / 0.18, 0.0, 1.0)
	var g: float = maxf(2.0, float(e["r"]) * 0.75)
	if int(e["estilo"]) == CombatFX.Estilo.CAIDA_RAYO:
		# El FOGONAZO de la columna: una franja ancha y tenue por donde ha caido. Es lo que hace que
		# veinte rayos se lean como una tormenta y no como veinte garabatos sueltos.
		draw_line(e["a"], e["b"], Color(1, 1, 1, 0.25 * alfa), 14.0)
	draw_polyline(zig, Color(col.r, col.g, col.b, 0.30 * alfa), g, true)
	draw_polyline(zig, Color(col.r, col.g, col.b, alfa), maxf(1.5, g * 0.45), true)
	draw_polyline(zig, Color(1, 1, 1, 0.9 * alfa), maxf(1.0, g * 0.18), true)


# El camino del rayo, con el desvio lateral al azar. Los extremos van CLAVADOS (nacen en el
# lanzador y mueren en la victima); lo que baila es el medio.
func _nuevo_zigzag(e: Dictionary) -> PackedVector2Array:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var pts := PackedVector2Array()
	var curva: bool = bool(e.get("curva", false))
	var n: int = 9 if curva else clampi(int(a.distance_to(b) / 34.0), 5, 14)
	var amp: float = 18.0 * clampf(float(e["r"]) / 12.0, 0.5, 1.5)
	for i in n:
		var u: float = float(i) / float(n - 1)
		var p: Vector2
		var tang: Vector2
		if curva:
			# Rebote que vuelve al MISMO objetivo: Bezier cuadratica que sale, sube y vuelve.
			var c: Vector2 = e["ctrl"]
			p = a.lerp(c, u).lerp(c.lerp(b, u), u)
			tang = (c - a).normalized() if u < 0.5 else (b - c).normalized()
		else:
			p = a.lerp(b, u)
			tang = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.DOWN
		var lado := Vector2(-tang.y, tang.x)
		var desvio: float = 0.0 if i == 0 or i == n - 1 else randf_range(-0.5, 0.5) * amp
		pts.append(p + lado * desvio)
	return pts


# GOTAS que caen del cielo, cada una con su desfase, y salpican al llegar.
func _pintar_gotas(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	var dur: float = e["dur"]
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.35), minf(1.0, col.b + 0.25), 0.95)
	for g in e["gotas"]:
		var dx: float = g[0]
		var retardo: float = float(g[1]) * dur
		var u: float = clampf((t - retardo) / maxf(dur - retardo, 0.01), 0.0, 1.0)
		if t < retardo:
			continue
		var destino: Vector2 = b + Vector2(dx, 0.0)
		if u < 1.0:
			# Cae acelerando, desde el techo.
			var p: Vector2 = Vector2(destino.x, lerpf(FUERA, destino.y, u * u))
			var largo: float = r * 0.9
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0.0, -largo),
				p + Vector2(r * 0.28, 0.0),
				p + Vector2(0.0, largo * 0.45),
				p + Vector2(-r * 0.28, 0.0),
			]), Color(col.r, col.g, col.b, 0.85))
			draw_line(p + Vector2(0.0, -largo), p, claro, 2.0, true)
		else:
			# SALPICADURA: dos arcos cortos que se abren a los lados y se apagan.
			var v: float = clampf((t - retardo - (dur - retardo)) / 0.12, 0.0, 1.0)
			var rad: float = r * (0.4 + 1.6 * v)
			var c := Color(col.r, col.g, col.b, 1.0 - v)
			draw_arc(destino, rad, PI * 1.15, PI * 1.45, 8, c, 2.0, true)
			draw_arc(destino, rad, -PI * 0.45, -PI * 0.15, 8, c, 2.0, true)


# OLA: un FRENTE ancho, no una gota. Todas las magias de agua sin dispersion son de area (Rocío
# moja a todos, Torrente arrasa a todos), asi que lo que tiene que verse venir es una lamina del
# ancho de la tarjeta. Como la cola separa los impactos, con varios objetivos entran escalonadas y
# el conjunto se lee como un barrido de la fila.
func _pintar_ola(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = e["t"]
	var u: float = clampf(t / float(e["dur"]), 0.0, 1.0)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.DOWN
	var lado := Vector2(-dir.y, dir.x)
	var p: Vector2 = a.lerp(b, u)
	var ancho: float = maxf(40.0, float(e["ancho"]) * 0.55)
	var fondo: float = float(e["r"]) * 0.9
	var alfa: float = 1.0 if u < 1.0 else clampf(1.0 - (t - float(e["dur"])) / 0.12, 0.0, 1.0)

	var pts := PackedVector2Array()
	var n := 7
	for i in n:
		var k: float = float(i) / float(n - 1)
		var x: float = lerpf(-1.0, 1.0, k)
		var avance: float = (1.0 - x * x) * fondo * (1.0 + 0.18 * sin(t * 11.0 + k * 5.0 + float(e["semilla"])))
		pts.append(p + lado * x * ancho + dir * avance)
	for i in n:
		var k2: float = 1.0 - float(i) / float(n - 1)
		var x2: float = lerpf(-1.0, 1.0, k2)
		var cola: float = -fondo * (0.55 + 0.45 * (1.0 - absf(x2)))
		pts.append(p + lado * x2 * ancho * 0.82 + dir * cola)
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85 * alfa))
	# La CRESTA, mas clara y fina: es lo que la lee como agua y no como una mancha azul.
	var cresta := PackedVector2Array()
	for i in n:
		cresta.append(pts[i])
	draw_polyline(cresta, Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.35),
		minf(1.0, col.b + 0.25), 0.95 * alfa), maxf(2.0, float(e["r"]) * 0.18), true)


# SIN ELEMENTO: un rombo girando dentro de un anillo. Se lee como "magia" sin tirar de ningun
# color elemental, que es justo lo que es un Pulso.
func _pintar_arcano(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = e["t"]
	var u: float = clampf(t / float(e["dur"]), 0.0, 1.0)
	var p: Vector2 = a.lerp(b, u * u)
	var alfa: float = 1.0 if u < 1.0 else clampf(1.0 - (t - float(e["dur"])) / 0.12, 0.0, 1.0)
	var g: float = t * 3.2 + float(e["semilla"])
	var r: float = float(e["r"]) * (1.0 + 0.08 * sin(t * 7.0)) * (1.0 + 1.5 * (1.0 - alfa))
	var eje := Vector2(cos(g), sin(g))
	var lado := Vector2(-eje.y, eje.x)
	draw_colored_polygon(PackedVector2Array([
		p + eje * r, p + lado * r * 0.55, p - eje * r, p - lado * r * 0.55,
	]), Color(col.r, col.g, col.b, alfa))
	draw_arc(p, r * 1.25, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.5 * alfa), 2.0, true)
