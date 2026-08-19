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
		CombatFX.Estilo.AURA:
			# No viaja: nace y muere sobre la misma tarjeta.
			e["a"] = b
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
			CombatFX.Estilo.EXPLOSION: _pintar_explosion(e)
			CombatFX.Estilo.SPLAT: _pintar_splat(e)
			CombatFX.Estilo.ESCUPITAJO: _pintar_escupitajo(e)
			CombatFX.Estilo.AURA: _pintar_aura(e)
			CombatFX.Estilo.VORTICE: _pintar_vortice(e)
			CombatFX.Estilo.ARRASTRE: _pintar_arrastre(e)


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
# moja a todos, Torrente arrasa a todos), asi que lo que tiene que verse venir es una lamina.
#
# 'ancho' es el ancho DEL FRENTE ENTERO, no el de una tarjeta: CombatFX._marcar_olas deja UNA sola
# ola por tanda y le pasa la medida de todo lo que barre (ver alli el porque). Antes se pintaba una
# ola por victima y del ancho de su tarjeta, asi que un Rocío a cuatro salian cuatro olitas en fila
# -- que es justo lo contrario de un barrido.
#
# El +10 es un poco de rebose por los lados: una ola que muere exactamente en el borde de la ultima
# tarjeta parece recortada.
func _pintar_ola(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = e["t"]
	var u: float = clampf(t / float(e["dur"]), 0.0, 1.0)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.DOWN
	var lado := Vector2(-dir.y, dir.x)
	var p: Vector2 = a.lerp(b, u)
	var ancho: float = maxf(40.0, float(e["ancho"]) * 0.5 + 10.0)
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


# EXPLOSION: no viaja, REVIENTA donde esta. Es lo que se lleva el SALPICON de las magias de fuego:
# la bola vuela hasta el objetivo principal y ahi estalla, y a los de al lado los alcanza la ONDA,
# no una segunda bola. Antes el salpicon se pintaba con el mismo estilo que el golpe principal, asi
# que Brasa y Andanada parecian tres bolas lanzadas a la vez en vez de una que revienta.
#
# Una onda que se abre y se apaga, un nucleo que se encoge y unas lenguas hacia fuera.
func _pintar_explosion(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	# La explosion vive MAS que su vuelo: el 'dur' es lo que tarda en llegar el impacto, y la onda
	# sigue abriendose despues. Se apaga sola con 'u'.
	var u: float = clampf(t / maxf(float(e["dur"]) + 0.22, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.15), 1.0)
	# ONDA: un anillo que se abre rapido al principio y se frena (1 - (1-u)^2), y que adelgaza.
	var rad: float = r * (0.5 + 2.6 * (1.0 - pow(1.0 - u, 2.0)))
	draw_arc(b, rad, 0.0, TAU, 28, Color(claro.r, claro.g, claro.b, 0.9 * (1.0 - u)),
		maxf(1.5, r * 0.30 * (1.0 - u)), true)
	# NUCLEO: empieza gordo y se consume.
	var nr: float = r * 1.15 * (1.0 - u)
	if nr > 0.5:
		draw_circle(b, nr, Color(col.r, col.g, col.b, 0.85 * (1.0 - u)))
		draw_circle(b, nr * 0.55, Color(claro.r, claro.g, claro.b, 0.9 * (1.0 - u)))
	# LENGUAS: seis chorros cortos hacia fuera, con la semilla para que dos explosiones seguidas no
	# salgan calcadas.
	var g: float = float(e["semilla"])
	for i in 6:
		var ang: float = g + TAU * float(i) / 6.0
		var dir := Vector2(cos(ang), sin(ang))
		var d0: float = rad * 0.55
		var d1: float = rad * (0.95 + 0.25 * sin(g * 3.0 + float(i)))
		draw_line(b + dir * d0, b + dir * d1,
			Color(claro.r, claro.g, claro.b, 0.75 * (1.0 - u)), maxf(1.5, r * 0.18), true)


# ============================================================
#  LOS DE LOS ENEMIGOS (ver CombatFX.Estilo, del 9 en adelante)
# ============================================================

# SPLAT: EL BICHO SALTA ENCIMA. UN SOLO cuerpo, gordo y redondo, que sale DE SU TARJETA, describe un
# salto y aterriza aplastando a todos los que pille debajo. Es el Reventon del slime y el
# Aplastamiento del Rey.
#
# DOS COSAS QUE SON EL 90% DE QUE FUNCIONE:
#  1. Es UNO, no uno por victima. De eso se encarga CombatFX._marcar_efectos_de_grupo, que deja una
#     sola portadora por tanda. Antes caian tres bolas sueltas sobre tres tarjetas, que es
#     justamente lo que no pasa cuando un bicho enorme te salta encima.
#  2. SALE DEL BICHO, no del cielo. Un salto tiene origen; una piedra que cae del techo, no. Por eso
#     'a' se queda siendo la tarjeta del atacante (no se toca en alta()) y aqui se dibuja el arco.
#
# El tamaño sale de 'ancho' (lo que abarca el grupo alcanzado), no del peso: si aplasta a cuatro
# tiene que TAPARLOS a los cuatro, o el dibujo estaria mintiendo sobre a quien pega.
func _pintar_splat(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = e["t"]
	var dur: float = float(e["dur"])
	# Radio del cuerpo: la mitad de lo que abarca, con un suelo para que en 1v1 siga siendo gordo.
	var r: float = maxf(26.0, float(e["ancho"]) * 0.5)
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.3), 1.0)
	if t < dur:
		# EL SALTO: va de su tarjeta a donde aterriza, subiendo por el camino. La altura sale de la
		# distancia, y el ARRANQUE es lento y la caida rapida (u*u), que es como cae un cuerpo.
		var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
		var p: Vector2 = a.lerp(b, u)
		p.y -= sin(u * PI) * minf(150.0, a.distance_to(b) * 0.45 + 60.0)
		# Se encoge al despegar y se estira al caer: da el peso.
		var estira: float = 0.85 + 0.5 * u
		_blob(p, r / estira, r * estira, col, claro, 0.95)
		return
	# APLASTADO: se abre a lo ancho, se aplana y se apaga.
	var v: float = clampf((t - dur) / 0.34, 0.0, 1.0)
	var ancho: float = r * (1.0 + 0.55 * v)
	var alto: float = r * (0.75 - 0.62 * v)
	var alfa: float = 1.0 - v
	if alto > 0.5:
		_blob(b, ancho, alto, col, claro, 0.92 * alfa)
	# ONDA de impacto: un anillo bajo y ancho que se abre por el suelo. Es lo que dice "esto ha
	# pegado a TODO lo de aqui debajo" mejor que la propia mancha.
	var ro: float = r * (1.0 + 1.1 * v)
	draw_arc(b, ro, 0.0, TAU, 30, Color(claro.r, claro.g, claro.b, 0.55 * alfa),
		maxf(2.0, r * 0.10 * (1.0 - v)), true)
	# Y las GOTAS que saltan al reventar, para que no sea una tortita limpia.
	for i in 7:
		var ang: float = float(e["semilla"]) + TAU * float(i) / 7.0
		var dir := Vector2(cos(ang), -absf(sin(ang)) * 0.7)
		draw_circle(b + dir * ancho * (0.8 + 0.55 * v), maxf(1.5, r * 0.11 * (1.0 - v)),
			Color(col.r, col.g, col.b, 0.8 * alfa))


# Una masa gelatinosa: elipse rellena + brillo arriba. La usan el splat y el escupitajo.
func _blob(p: Vector2, rx: float, ry: float, col: Color, claro: Color, alfa: float) -> void:
	var pts := PackedVector2Array()
	var n := 16
	for i in n:
		var k: float = TAU * float(i) / float(n)
		pts.append(p + Vector2(cos(k) * rx, sin(k) * ry))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, alfa))
	# El brillo va ARRIBA A LA IZQUIERDA siempre: es lo que le da volumen y lo separa de una mancha.
	draw_circle(p + Vector2(-rx * 0.3, -ry * 0.35), maxf(1.0, minf(rx, ry) * 0.32),
		Color(claro.r, claro.g, claro.b, 0.55 * alfa))


# ESCUPITAJO: una bola pequeña con PARABOLA. No va en linea recta como el proyectil de fuego: sube
# y cae, que es lo que hace que se lea como algo escupido y no como algo lanzado con puntería.
# Al llegar deja un goteron que se escurre.
func _pintar_escupitajo(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"] * 0.7   # pequeño a proposito: la Rociada son DOS de estos
	var t: float = e["t"]
	var dur: float = float(e["dur"])
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.3), 1.0)
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	if u < 1.0:
		# PARABOLA: interpolacion recta + una campana hacia arriba. La altura sale de la distancia,
		# asi que un escupitajo corto no hace un arco absurdo.
		var p: Vector2 = a.lerp(b, u)
		var alto: float = minf(70.0, a.distance_to(b) * 0.32)
		p.y -= sin(u * PI) * alto
		# Se aplasta un poco en la direccion de marcha (como una gota en el aire).
		_blob(p, r * 1.15, r * 0.85, col, claro, 0.92)
		# Estela de gotitas detras, que es lo que lo hace baboso.
		for i in 3:
			var ur: float = u - 0.07 * float(i + 1)
			if ur <= 0.0:
				continue
			var q: Vector2 = a.lerp(b, ur)
			q.y -= sin(ur * PI) * alto
			draw_circle(q, maxf(1.0, r * (0.4 - 0.1 * float(i))),
				Color(col.r, col.g, col.b, 0.4 - 0.1 * float(i)))
		return
	# IMPACTO: se abre y se escurre hacia abajo.
	var v: float = clampf((t - dur) / 0.22, 0.0, 1.0)
	var alfa: float = 1.0 - v
	_blob(b, r * (1.0 + 1.3 * v), r * (1.0 - 0.4 * v), col, claro, 0.85 * alfa)
	draw_line(b, b + Vector2(0.0, r * 1.8 * v), Color(col.r, col.g, col.b, 0.6 * alfa),
		maxf(1.0, r * 0.35), true)


# AURA: el bicho se enciende A SI MISMO. No viaja: se queda en su tarjeta, latiendo. Es la Ignicion
# del slime de fuego (y vale para cualquier buff: Caparazon, Muralla, Endurecerse).
func _pintar_aura(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	# Vive bastante mas que su "vuelo": un buff tiene que lucir.
	var u: float = clampf(t / maxf(float(e["dur"]) + 0.55, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	var claro := Color(minf(1.0, col.r + 0.4), minf(1.0, col.g + 0.35), minf(1.0, col.b + 0.2), 1.0)
	# Entra deprisa y se va despacio, para que se vea el estallido inicial.
	var alfa: float = (u / 0.18) if u < 0.18 else (1.0 - (u - 0.18) / 0.82)
	var g: float = float(e["semilla"])
	# LENGUAS que suben, repartidas alrededor y ondeando. Son lo que lo lee como fuego y no como
	# un circulo de color.
	for i in 10:
		var ang: float = g + TAU * float(i) / 10.0
		var onda: float = sin(t * 9.0 + float(i) * 1.7)
		var largo: float = r * (1.5 + 0.5 * onda)
		var base: Vector2 = b + Vector2(cos(ang) * r * 1.25, sin(ang) * r * 0.75)
		var punta: Vector2 = base + Vector2(onda * r * 0.35, -largo)
		draw_line(base, punta, Color(claro.r, claro.g, claro.b, 0.55 * alfa),
			maxf(1.5, r * 0.22), true)
	# Y un halo pegado al cuerpo, que late.
	draw_arc(b, r * (1.5 + 0.12 * sin(t * 7.0)), 0.0, TAU, 26,
		Color(col.r, col.g, col.b, 0.45 * alfa), maxf(2.0, r * 0.3), true)


# VORTICE: una espiral que se CIERRA sobre la victima. Es lo del abismo: no te golpea, te succiona.
# Brazos que giran hacia dentro y un nucleo negro que se traga la luz.
func _pintar_vortice(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	var u: float = clampf(t / maxf(float(e["dur"]) + 0.35, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	var alfa: float = 1.0 - u * u
	var claro := Color(minf(1.0, col.r + 0.5), minf(1.0, col.g + 0.5), minf(1.0, col.b + 0.55), 1.0)
	# Los brazos se cierran: el radio exterior encoge segun avanza.
	var rad: float = r * (3.0 - 1.9 * u)
	var giro: float = float(e["semilla"]) + t * 5.5
	# Cinco brazos, cada uno una polilinea que va enroscandose hacia el centro.
	for i in 5:
		var pts := PackedVector2Array()
		var base_ang: float = giro + TAU * float(i) / 5.0
		for j in 9:
			var k: float = float(j) / 8.0
			# El angulo crece con k: eso es lo que lo curva (una espiral, no un radio recto).
			var ang: float = base_ang + k * 2.1
			var d: float = rad * (1.0 - k * 0.85)
			pts.append(b + Vector2(cos(ang) * d, sin(ang) * d * 0.72))
		draw_polyline(pts, Color(claro.r, claro.g, claro.b, 0.5 * alfa), maxf(1.5, r * 0.16), true)
	# NUCLEO: negro de verdad, que es lo que le da el fondo de pozo.
	var nr: float = rad * 0.30
	draw_circle(b, nr, Color(0.02, 0.01, 0.05, 0.85 * alfa))
	draw_arc(b, nr, 0.0, TAU, 22, Color(col.r, col.g, col.b, 0.7 * alfa), maxf(1.5, r * 0.2), true)


# ARRASTRE: el bicho embiste (de eso se encarga CombatFX) y SE LLEVA UNA LLAMA por delante. La
# Llamarada del slime de fuego no se lanza: le sale el fuego encima y avanza con el.
#
# Se dibuja a lo largo del trayecto a->b, que es el mismo que recorre su tarjeta al embestir.
func _pintar_arrastre(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	var dur: float = float(e["dur"])
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.35), minf(1.0, col.b + 0.1), 1.0)
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	var fin: float = clampf((t - dur) / 0.20, 0.0, 1.0)
	var alfa: float = 1.0 if u < 1.0 else 1.0 - fin
	if alfa <= 0.0:
		return
	var p: Vector2 = a.lerp(b, minf(u, 1.0))
	var g: float = float(e["semilla"])
	# La llama: lenguas que salen hacia DELANTE (hacia el objetivo), no en todas direcciones. Es lo
	# que hace que se lea como algo que empuja y no como una hoguera quieta.
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
	var lado := Vector2(-dir.y, dir.x)
	for i in 7:
		var k: float = float(i) / 6.0 - 0.5
		var onda: float = sin(t * 16.0 + float(i) * 1.3 + g)
		var largo: float = r * (1.3 + 0.6 * onda)
		var base: Vector2 = p + lado * k * r * 1.6
		draw_line(base, base + dir * largo + lado * onda * r * 0.25,
			Color(claro.r, claro.g, claro.b, 0.7 * alfa), maxf(1.5, r * 0.26), true)
	# Nucleo caliente pegado al bicho.
	draw_circle(p, r * 0.75 * (1.0 + 0.1 * sin(t * 13.0)), Color(col.r, col.g, col.b, 0.75 * alfa))


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
