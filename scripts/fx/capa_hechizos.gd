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

# El ritmo al que corren los dibujos. Lo mantiene igualado CombatFX (ver su escala_tiempo).
var escala_tiempo: float = 1.0


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
		CombatFX.Estilo.AURA, CombatFX.Estilo.CAPARAZON, CombatFX.Estilo.MURALLA, \
		CombatFX.Estilo.ESCUDO:
			# No viajan: nacen y mueren sobre la misma tarjeta (el bicho se lo echa ENCIMA).
			e["a"] = b
		CombatFX.Estilo.MORDISCO, CombatFX.Estilo.COLMILLAZO, CombatFX.Estilo.YUGULAR, \
		CombatFX.Estilo.ZARPAZO, CombatFX.Estilo.PLACAJE, CombatFX.Estilo.CORNADA, \
		CombatFX.Estilo.PISOTON, CombatFX.Estilo.GOLPETAZO:
			# Tampoco viajan, pero por el motivo CONTRARIO al aura: lo que se desplaza es la tarjeta
			# del que muerde (embiste, ver CombatFX), asi que las fauces tienen que estar ya donde
			# van a cerrarse. Si salieran del atacante se veria un par de dientes cruzando la
			# pantalla por su cuenta mientras el bicho llega por detras.
			e["a"] = b
		CombatFX.Estilo.BARRIDO:
			# RECTA, NUNCA EN DIAGONAL. Un frente de agua avanza de una fila a la otra; si sale de la
			# tarjeta del que lanza y va al centro de lo barrido, cuando esos dos no estan alineados
			# la lamina cruza la pantalla torcida y se ve rarisimo -- ademas de que una ola inclinada
			# no "barre" nada. Se le hace nacer JUSTO DEBAJO del destino: conserva la distancia (o
			# sea el tiempo de viaje) y sube derecha.
			e["a"] = Vector2(b.x, a.y)
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
	# AL MISMO RITMO QUE EL RESTO. Esta capa lleva su propio reloj, asi que si no se escala aqui
	# tambien, al bajar la velocidad las tarjetas se movian despacio pero los conjuros seguian
	# volando igual de rapido, y el impacto dejaba de coincidir con el golpe. Lo pone CombatFX.
	var d: float = delta * escala_tiempo
	var i: int = _efectos.size() - 1
	while i >= 0:
		var e: Dictionary = _efectos[i]
		e["t"] = float(e["t"]) + d
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
	var es: int = int(e["estilo"])
	# Los mordiscos casi no tienen vuelo (van con la embestida), asi que TODO lo suyo pasa en la
	# coleta: cerrarse, el rebote de la mandibula y la marca quedandose un instante. Con los 0.12 de
	# siempre la dentellada era un parpadeo y no se llegaba a leer.
	if es == CombatFX.Estilo.MORDISCO:
		return float(e["dur"]) + 0.30
	if es == CombatFX.Estilo.COLMILLAZO:
		return float(e["dur"]) + 0.38   # fauces mas grandes, cierran mas despacio
	if es == CombatFX.Estilo.YUGULAR:
		return float(e["dur"]) + 0.40   # y ademas tiene que apagarse el destello
	if es == CombatFX.Estilo.CHILLIDO:
		return float(e["dur"]) + 0.34   # lo que tarda el ultimo anillo en salir de la fila
	if es == CombatFX.Estilo.ZARPAZO:
		return float(e["dur"]) + 0.34   # las cuatro garras entran escalonadas, no a la vez
	if es == CombatFX.Estilo.PLACAJE:
		return float(e["dur"]) + 0.32   # chafarse y escurrirse lleva su tiempo
	if es == CombatFX.Estilo.CORNADA:
		return float(e["dur"]) + 0.30
	if es == CombatFX.Estilo.CARGA:
		return float(e["dur"]) + 0.30   # la polvareda del choque se queda un poco
	if es == CombatFX.Estilo.PISOTON:
		return float(e["dur"]) + 0.38   # la grieta abre y la onda tiene que llegar a los lados
	if es == CombatFX.Estilo.GOLPETAZO:
		return float(e["dur"]) + 0.26   # un porrazo es seco: entra y se va
	# Los de ponerse a cubierto AGUANTAN puestos un buen rato: son un buff que dura turnos, y si se
	# cerraran y desaparecieran en tres cuartos de segundo no se leeria que el bicho se ha protegido.
	if es == CombatFX.Estilo.CAPARAZON or es == CombatFX.Estilo.MURALLA \
			or es == CombatFX.Estilo.ESCUDO:
		return float(e["dur"]) + 0.70
	if es == CombatFX.Estilo.MIRADA:
		return float(e["dur"]) + 0.30
	if es == CombatFX.Estilo.LATIGAZO:
		return float(e["dur"]) + 0.32
	if es == CombatFX.Estilo.PONZONA:
		return float(e["dur"]) + 0.34
	if es == CombatFX.Estilo.TELARANA:
		return float(e["dur"]) + 0.42   # se despliega y se queda tirante un momento
	if es == CombatFX.Estilo.ENROSQUE:
		return float(e["dur"]) + 0.42   # apretar lleva su tiempo
	if es == CombatFX.Estilo.PATAS:
		return float(e["dur"]) + 0.30
	if es == CombatFX.Estilo.RODADA:
		return float(e["dur"]) + 0.34
	if es == CombatFX.Estilo.RAICES:
		return float(e["dur"]) + 0.34   # brotan y se quedan un momento antes de ceder el relevo
			# al dibujo del estado, que ya las mantiene puestas mientras dure
	var extra: float = 0.18 if _es_rayo(es) else 0.12
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
			CombatFX.Estilo.MORDISCO: _pintar_mordisco(e)
			CombatFX.Estilo.COLMILLAZO: _pintar_colmillazo(e)
			CombatFX.Estilo.YUGULAR: _pintar_yugular(e)
			CombatFX.Estilo.CHILLIDO: _pintar_chillido(e)
			CombatFX.Estilo.ZARPAZO: _pintar_zarpazo(e)
			CombatFX.Estilo.PLACAJE: _pintar_placaje(e)
			CombatFX.Estilo.CORNADA: _pintar_cornada(e)
			CombatFX.Estilo.CARGA: _pintar_carga(e)
			CombatFX.Estilo.PISOTON: _pintar_pisoton(e)
			CombatFX.Estilo.GOLPETAZO: _pintar_golpetazo(e)
			CombatFX.Estilo.RAICES: _pintar_raices(e)
			CombatFX.Estilo.CAPARAZON: _pintar_caparazon(e)
			CombatFX.Estilo.MURALLA: _pintar_muralla(e)
			CombatFX.Estilo.ESCUDO: _pintar_escudo(e)
			CombatFX.Estilo.PONZONA: _pintar_ponzona(e)
			CombatFX.Estilo.TELARANA: _pintar_telarana(e)
			CombatFX.Estilo.ENROSQUE: _pintar_enrosque(e)
			CombatFX.Estilo.PATAS: _pintar_patas(e)
			CombatFX.Estilo.RODADA: _pintar_rodada(e)
			CombatFX.Estilo.MIRADA: _pintar_mirada(e)
			CombatFX.Estilo.LATIGAZO: _pintar_latigazo(e)


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
	# El tamaño sale de LO QUE ABARCA (ver _radio_grupo): una explosion que alcanza a tres es UNA
	# grande, no tres petardos. El 0.30 la deja algo mas chica que el vortice: una onda se lee bien
	# aunque no tape del todo, y asi no se come la pantalla en 1v1.
	var r: float = _radio_grupo(e, 0.30, 11.0)
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
		# Se encoge al despegar y se estira al caer: da el peso. Redondo por las dos mitades (aun
		# no toca nada), y se dibuja apoyado en su parte baja para que el aterrizaje no de un salto.
		var estira: float = 0.85 + 0.5 * u
		_masa(p + Vector2(0.0, r * estira), r / estira, r * estira, r * estira, col, claro, 0.95)
		return
	# APLASTADO. La clave: NO se encoge entero, SE CHAFA CONTRA EL SUELO. Primero se aplana la parte
	# de ABAJO (que es la que toca) mientras arriba sigue siendo una cupula redonda, y la masa se
	# escurre hacia los LADOS. Solo despues empieza a bajar el techo.
	var v: float = clampf((t - dur) / 0.34, 0.0, 1.0)
	# Abajo se chafa deprisa: a un tercio del golpe ya esta plano contra el suelo.
	var abajo: float = r * maxf(0.0, 1.0 - v * 3.0)
	# Arriba aguanta redondo bastante mas: es lo que lo mantiene con forma de slime y no de tortita.
	var arriba: float = r * (1.0 - 0.55 * v)
	# Y lo que no cabe a lo alto sale a lo ancho.
	var ancho: float = r * (1.0 + 0.6 * v)
	var alfa: float = 1.0 - v
	if arriba > 0.5:
		_masa(b, ancho, arriba, abajo, col, claro, 0.92 * alfa)
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


# EL RADIO DE UN EFECTO QUE CUBRE A VARIOS. 'ancho' es lo que abarca el grupo alcanzado (lo pone
# CombatFX._marcar_efectos_de_grupo en la portadora); 'k' es cuanto de eso ocupa este dibujo y
# 'suelo' el minimo para que en 1v1 siga viendose gordo.
#
# Se saca del ANCHO y no del peso del golpe a proposito: el dibujo tiene que tapar justo a quien
# pega. Si el tamaño saliera del daño, un area floja se veria pequeña aunque alcanzara a cuatro, y
# la animacion estaria mintiendo sobre a quien toca.
func _radio_grupo(e: Dictionary, k: float, suelo: float) -> float:
	return maxf(maxf(suelo, float(e["r"])), float(e["ancho"]) * k)


# UNA MASA CON LAS DOS MITADES INDEPENDIENTES: 'arriba' y 'abajo' son los radios verticales de la
# mitad de arriba y la de abajo, y 'apoyo' es el punto donde toca el suelo.
#
# Es lo que permite que un slime se aplaste COMO SE APLASTA de verdad: la parte de abajo se chafa
# contra el suelo primero (abajo -> 0) mientras la de arriba sigue siendo una cupula redonda, y solo
# despues se va bajando el techo. Con una elipse normal -las dos mitades iguales- lo unico que se
# puede hacer es encogerla entera, y eso parece una bola que se desinfla, no algo que se estampa.
#
# El punto de APOYO no se mueve en todo el aplastamiento: la masa crece hacia los lados y hacia
# arriba, nunca hacia abajo. Si se dibujara centrada, al ensancharse se hundiria en el suelo.
func _masa(apoyo: Vector2, rx: float, arriba: float, abajo: float,
		col: Color, claro: Color, alfa: float) -> void:
	var centro: Vector2 = apoyo - Vector2(0.0, abajo)
	var pts := PackedVector2Array()
	var n := 22
	for i in n:
		var ang: float = TAU * float(i) / float(n)
		var y: float = sin(ang)
		# El radio vertical cambia segun se este dibujando la mitad de arriba o la de abajo.
		pts.append(centro + Vector2(cos(ang) * rx, -y * (arriba if y > 0.0 else abajo)))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, alfa))
	# El brillo, arriba a la izquierda: es lo que le da volumen de gelatina.
	draw_circle(centro + Vector2(-rx * 0.32, -arriba * 0.42),
		maxf(1.0, minf(rx, maxf(arriba, 1.0)) * 0.3),
		Color(claro.r, claro.g, claro.b, 0.5 * alfa))


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
	# Igual que la explosion: si se traga a tres, es UN remolino ancho. Los brazos ya se abren a
	# 3 x r, asi que el factor va bajo (0.17) para que con cuatro objetivos no salga de la pantalla.
	var r: float = _radio_grupo(e, 0.17, 8.0)
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
	# CUANTO ABARCA A LO ANCHO. Es la diferencia entre la Llamarada (uno solo: una lengua estrecha
	# que va con el bicho) y la Combustion (area: el slime se pone al rojo y ARRASA de lado a lado).
	# Sale de lo alcanzado, no del daño, por lo mismo que en _radio_grupo.
	var media: float = maxf(r * 1.6, float(e["ancho"]) * 0.42)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
	var lado := Vector2(-dir.y, dir.x)
	# Mas lenguas cuanto mas ancho, o al ensanchar quedaban cuatro pelos sueltos y se veia el hueco.
	var n: int = clampi(int(media / 14.0), 7, 26)
	for i in n:
		var k: float = float(i) / float(n - 1) - 0.5
		var onda: float = sin(t * 16.0 + float(i) * 1.3 + g)
		# Las de los bordes son mas cortas: le da forma de frente de fuego y no de peine.
		var perfil: float = 1.0 - 0.45 * absf(k) * 2.0
		var largo: float = r * (1.3 + 0.6 * onda) * maxf(0.35, perfil)
		var base: Vector2 = p + lado * k * media * 2.0
		draw_line(base, base + dir * largo + lado * onda * r * 0.25,
			Color(claro.r, claro.g, claro.b, 0.7 * alfa), maxf(1.5, r * 0.26), true)
	# Nucleo caliente pegado al bicho. Se estira a lo ancho con el frente.
	var pts := PackedVector2Array()
	for i in 14:
		var ang: float = TAU * float(i) / 14.0
		pts.append(p + lado * cos(ang) * media * 0.7 + dir * sin(ang) * r * 0.75)
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.7 * alfa))


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


# ============================================================
#  MORDISCOS
# ============================================================
# DOS HILERAS DE DIENTES QUE SE CIERRAN sobre la tarjeta de la victima. Lo que distingue a un bicho
# que muerde de uno que pega es la BOCA, asi que es lo que se dibuja: no un impacto generico teñido
# de otro color, sino la dentellada concreta de ese bicho.
#
# EL COLOR DEL BICHO NO SE USA para el diente. Lo demas de la capa tiñe con 'col' (que sale de
# combat.gd._color_golpe: el elemento o, si no lo hay, el color del propio enemigo), pero una rata
# es marron y una dentellada marron sobre una tarjeta no se lee. El diente va en HUESO y la marca en
# SANGRE, que ademas es la firma de la familia entera: aqui todo lo que muerde hace sangrar.
#
# El PERFIL es la tabla de dientes de una hilera; cada diente es
#     [off_x, semiancho, largo, inclinacion, punta]
# donde off_x va de -1 a 1 sobre la MEDIA boca, 'semiancho' es lo que sobresale a CADA lado (o sea
# medio diente: dos dientes se tocan cuando sus off_x distan la suma de sus semianchos), 'largo' es
# fraccion del maximo, la inclinacion desvia la punta hacia un lado (fraccion del largo) y 'punta'
# va de 0 = punta PLANA (el paleto de un roedor) a 1 = punta afilada (el colmillo de una fiera).
#
# La irregularidad de las fauces esta ESCRITA EN LA TABLA y no sacada de randf(): _draw puede
# correr varias veces en el mismo frame (ver la cabecera del fichero), asi que un colmillo con el
# largo aleatorio no seria "irregular", seria un diente vibrando.

# ROEDOR: dos PALETOS anchos de punta recta que dominan la boca, y dientecitos parejos a los lados.
const _P_PALETOS_ARRIBA := [
	[-0.165, 0.160, 1.00, 0.0, 0.05], [0.165, 0.160, 1.00, 0.0, 0.05],
	[-0.44, 0.070, 0.34, 0.0, 0.35], [0.44, 0.070, 0.34, 0.0, 0.35],
	[-0.60, 0.065, 0.28, 0.0, 0.35], [0.60, 0.065, 0.28, 0.0, 0.35],
	[-0.75, 0.060, 0.22, 0.0, 0.40], [0.75, 0.060, 0.22, 0.0, 0.40],
]
const _P_PALETOS_ABAJO := [
	[-0.145, 0.140, 0.72, 0.0, 0.08], [0.145, 0.140, 0.72, 0.0, 0.08],
	[-0.40, 0.065, 0.28, 0.0, 0.35], [0.40, 0.065, 0.28, 0.0, 0.35],
	[-0.56, 0.060, 0.24, 0.0, 0.35], [0.56, 0.060, 0.24, 0.0, 0.35],
	[-0.71, 0.055, 0.20, 0.0, 0.40], [0.71, 0.055, 0.20, 0.0, 0.40],
]

# FIERA: colmillos largos en los extremos curvados hacia DENTRO, y dientes cortos e irregulares en
# medio. Los numeros estan desparejados a proposito (-0.84 contra 0.86, -0.19 contra 0.21): la
# simetria perfecta hacia que pareciera un peine en vez de una boca.
const _P_FAUCES_ARRIBA := [
	[-0.86, 0.095, 1.00, 0.09, 0.92], [0.88, 0.090, 0.96, -0.10, 0.92],
	[-0.63, 0.080, 0.74, 0.05, 0.88], [0.65, 0.085, 0.80, -0.06, 0.88],
	[-0.42, 0.070, 0.50, 0.02, 0.80], [0.44, 0.065, 0.46, -0.02, 0.80],
	[-0.21, 0.070, 0.62, 0.0, 0.85], [0.23, 0.075, 0.56, 0.0, 0.85],
	[0.01, 0.065, 0.44, 0.0, 0.78],
]
const _P_FAUCES_ABAJO := [
	[-0.88, 0.090, 0.92, 0.08, 0.92], [0.86, 0.095, 0.98, -0.09, 0.92],
	[-0.66, 0.080, 0.70, 0.05, 0.88], [0.63, 0.080, 0.76, -0.05, 0.88],
	[-0.33, 0.065, 0.42, 0.0, 0.80], [0.35, 0.065, 0.46, 0.0, 0.80],
	[-0.11, 0.060, 0.38, 0.0, 0.78], [0.13, 0.060, 0.40, 0.0, 0.78],
]

const _HUESO := Color(0.96, 0.94, 0.87)
const _ENCIA := Color(0.10, 0.03, 0.05)     # el contorno, para que el diente se lea sobre cualquier fondo
const _SANGRE := Color(0.72, 0.06, 0.08)


func _pintar_mordisco(e: Dictionary) -> void:
	_dentellada(e, _P_PALETOS_ARRIBA, _P_PALETOS_ABAJO, 1.0, 1.0)


func _pintar_colmillazo(e: Dictionary) -> void:
	# Fauces mas anchas y que cierran mas despacio: una mandibula grande pesa.
	_dentellada(e, _P_FAUCES_ARRIBA, _P_FAUCES_ABAJO, 1.35, 1.25)


# LA YUGULAR SIGUE SIENDO UNA RATA: muerde con paletos, no con colmillos. Lo que la separa de las
# otras dentelladas no es la boca, es que va a UN SOLO SITIO y con todo -- y eso lo dice el destello.
func _pintar_yugular(e: Dictionary) -> void:
	var v: float = _dentellada(e, _P_PALETOS_ARRIBA, _P_PALETOS_ABAJO, 1.15, 0.85)
	if v >= 0.0:
		_destello(e, v, Color(0.90, 0.10, 0.12), Color(1.0, 0.55, 0.48))


# PONZOÑA: el mordisco de la araña. Muerde con las FAUCES (quelíceros, no los paletos de un roedor)
# y el destello sale VERDE en vez de rojo: no es que te desangre, es que te ha metido veneno.
func _pintar_ponzona(e: Dictionary) -> void:
	var v: float = _dentellada(e, _P_FAUCES_ARRIBA, _P_FAUCES_ABAJO, 1.0, 0.9)
	if v >= 0.0:
		# Mas pequeño que el de la yugular (el 0.62): aquella es UN golpe y este son dos o tres
		# picaduras seguidas, asi que a tamaño completo se comia la pantalla tres veces por turno.
		_destello(e, v, Color(0.35, 0.85, 0.20), Color(0.80, 1.0, 0.55), 0.62)


# Pinta la mordida entera. Devuelve el avance DESPUES del cierre (0 = acaba de morder, 1 = se ha
# ido del todo) o -1 mientras las fauces todavia se estan abriendo, que es lo que usa la yugular
# para saber cuando soltar el destello.
func _dentellada(e: Dictionary, arriba: Array, abajo: Array, escala: float, lentitud: float) -> float:
	var b: Vector2 = e["b"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	# La boca se ajusta a la TARJETA que muerde y no al daño: un mordisco tapa una cara. (Los
	# mordiscos no son estilos de grupo, asi que 'ancho' es el ancho de esa victima, no el del grupo.)
	var boca: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0) * escala
	var media: float = boca * 0.5
	var largo_max: float = media * 0.85
	# CADA MORDISCO CAE DISTINTO. El Frenesi son seis dentelladas seguidas sobre las mismas caras: si
	# todas salieran con el mismo angulo y en el mismo sitio, las seis se leerian como un unico
	# dibujo parpadeando en vez de como seis bocados. La semilla las ladea hasta 26 grados para
	# cualquiera de los dos lados (pasando por el recto) y ademas las desplaza un poco.
	var g: float = float(e["semilla"])
	var ang: float = sin(g * 3.3) * 0.45
	var eje := Vector2(cos(ang), sin(ang))
	var lado := Vector2(-eje.y, eje.x)
	# El desvio va en el diccionario porque el destello de la yugular tiene que salir DEL MISMO
	# sitio que la mordida, no del centro de la tarjeta.
	b += Vector2(cos(g * 2.1), sin(g * 1.7)) * media * 0.18
	e["mordida_c"] = b
	var c: float = 0.0        # 0 = boca abierta de par en par, 1 = dientes tocandose
	var alfa: float = 1.0
	var v: float = -1.0
	if t < dur:
		# Abriendose mientras la tarjeta llega. Con un T_VUELO casi cero esto dura un parpadeo, pero
		# es lo que evita que las fauces aparezcan ya cerradas y el mordisco no se vea morder.
		alfa = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	else:
		v = clampf((t - dur) / (0.30 * lentitud), 0.0, 1.0)
		c = clampf(v / 0.30, 0.0, 1.0)   # cierra de golpe en el primer tercio
		# REBOTE de la mandibula: al llegar a tope afloja un pelin en vez de quedarse clavada.
		if v > 0.30 and v < 0.48:
			c = 1.0 - 0.14 * sin((v - 0.30) / 0.18 * PI)
		alfa = 1.0 if v < 0.55 else 1.0 - (v - 0.55) / 0.45
	if alfa <= 0.0:
		return v
	# Lo que separa las dos hileras: de abiertas del todo a cruzarse un poco al cerrar.
	# Abierta de par en par tiene que caber MAS DE UN DIENTE de hueco (1.75) o la boca no se ve
	# abrirse; pasado eso la mordida sale mas alta que la propia tarjeta y deja de leerse como algo
	# que le pasa AL BICHO. Al cerrar se cruzan muy poco (-0.05), o en vez de una mordida se lee
	# una cremallera.
	var sep: float = lerpf(largo_max * 1.75, -largo_max * 0.05, c)
	for d in arriba:
		_diente(b, eje, lado, media, largo_max, sep, d, true, alfa)
	for d in abajo:
		_diente(b, eje, lado, media, largo_max, sep, d, false, alfa)
	if v >= 0.0 and c > 0.85:
		_marca_mordida(b, eje, lado, media, largo_max, alfa)
	return v


func _diente(centro: Vector2, eje: Vector2, lado: Vector2, media: float, largo_max: float,
		sep: float, d: Array, es_arriba: bool, alfa: float) -> void:
	var dir: float = 1.0 if es_arriba else -1.0   # hacia donde CRECE el diente (+lado = hacia abajo)
	var x: float = float(d[0]) * media
	var w: float = float(d[1]) * media
	var largo: float = float(d[2]) * largo_max
	var incl: float = float(d[3]) * largo
	# LA MANDIBULA VA CURVADA. Una boca abre por el CENTRO: en las comisuras las dos hileras casi se
	# tocan aunque este abierta de par en par. Sin esto los dientes salian en dos lineas rectas
	# paralelas y el dibujo se leia como una reja, no como algo que muerde.
	var k: float = float(d[0])
	var y0: float = -dir * sep * 0.5 * (1.0 - 0.55 * k * k)
	var base: Vector2 = centro + eje * x + lado * y0
	var pta: Vector2 = centro + eje * (x + incl) + lado * (y0 + dir * largo)
	# Lo que convierte un paleto en un colmillo: cuanto se estrecha la punta.
	var w2: float = w * lerpf(0.78, 0.05, float(d[4]))
	var pts := PackedVector2Array([
		base - eje * w, base + eje * w, pta + eje * w2, pta - eje * w2,
	])
	draw_colored_polygon(pts, Color(_HUESO.r, _HUESO.g, _HUESO.b, alfa))
	# Contorno oscuro: sin el, un diente hueso sobre una tarjeta clara desaparece.
	pts.append(pts[0])
	draw_polyline(pts, Color(_ENCIA.r, _ENCIA.g, _ENCIA.b, 0.75 * alfa), maxf(1.0, w * 0.22), true)


# LO QUE DEJA la mordida: los dos agujeros por donde han entrado los dientes grandes y un hilo
# escurriendo de cada uno. Es lo que ata el dibujo a la mecanica -- toda esta familia sangra.
func _marca_mordida(centro: Vector2, eje: Vector2, lado: Vector2, media: float, largo_max: float,
		alfa: float) -> void:
	for s in [-1.0, 1.0]:
		var p: Vector2 = centro + eje * (0.13 * media * s)
		draw_circle(p, maxf(1.5, largo_max * 0.13),
			Color(_SANGRE.r, _SANGRE.g, _SANGRE.b, 0.9 * alfa))
		draw_line(p, p + lado * largo_max * 0.5,
			Color(_SANGRE.r, _SANGRE.g, _SANGRE.b, 0.55 * alfa), maxf(1.0, largo_max * 0.09), true)


# EL DESTELLO de la yugular: una estrella de cuatro puntas con los lados CONCAVOS, nucleo blanco
# quemado y halo rojo. Un flash redondo no valdria: lo que hay que leer es que este mordisco es EL
# golpe del Rey rata y no uno mas de una racha.
#
# EL COLOR VIENE DE FUERA. Lo llevaba escrito dentro (rojo) hasta que la araña pidio el suyo en
# verde: no es lo mismo desangrarse que envenenarse, y son la misma forma. 'tam' encoge el conjunto
# para los mordiscos que se repiten varias veces en un turno.
func _destello(e: Dictionary, v: float, fuera: Color, dentro: Color, tam: float = 1.0) -> void:
	# Del sitio EXACTO donde ha mordido (lo deja _dentellada), no del centro de la tarjeta: la
	# mordida va desplazada un poco al azar y el destello tiene que ir con ella.
	var b: Vector2 = e.get("mordida_c", e["b"])
	# Entra de golpe pasandose de tamaño y se apaga encogiendo.
	var k: float = (v / 0.14) if v < 0.14 else maxf(0.0, 1.0 - (v - 0.14) / 0.60)
	if k <= 0.0:
		return
	var pico: float = 1.0 if v >= 0.14 else 1.0 + 0.35 * (1.0 - v / 0.14)
	var r: float = clampf(float(e["ancho"]) * 0.55, 30.0, 92.0) * 1.25 * k * pico * tam
	_estrella(b, r * 1.60, r * 1.15, 0.42, Color(fuera.r, fuera.g, fuera.b, 0.80 * k))
	_estrella(b, r * 0.58, r * 0.40, 0.75, Color(dentro.r, dentro.g, dentro.b, 0.95 * k))
	_estrella(b, r * 0.28, r * 0.20, 1.30, Color(1.0, 0.97, 0.94, k))           # el nucleo quemado
	draw_circle(b, maxf(1.5, r * 0.10), Color(1.0, 1.0, 1.0, k))


# r(a) = R * (1 - |sin 2a|^p). En los cuatro ejes vale R (la punta) y en las diagonales cae a cero,
# asi que salen cuatro puntas; lo que hace el trabajo es 'p', el filo:
#   p bajo (~0.5)  cae a plomo nada mas salir del eje -> puntas larguisimas y finas, lados COMBADOS
#   p alto (~1.3)  aguanta ancho un rato antes de caer -> un cuerpo gordo con las puntas cortas
# Por eso el destello son TRES estrellas encajadas de p creciente: las agujas rojas de fuera, el
# cuerpo naranja y el nucleo blanco. Con una sola salia una cruz de brazos rectos y no brillaba.
func _estrella(c: Vector2, rx: float, ry: float, filo: float, col: Color) -> void:
	# DEMASIADO PEQUEÑA PARA DIBUJARLA. El suelo de 'f' de abajo es RELATIVO, asi que no salva este
	# caso: cuando el destello se apaga el radio tiende a cero y TODOS los vertices caen en el mismo
	# punto -> "Invalid polygon data, triangulation failed". Y a este tamaño no se ve nada igual.
	if rx < 1.0 or ry < 1.0:
		return
	var pts := PackedVector2Array()
	for i in 56:
		var a: float = TAU * float(i) / 56.0
		# SUELO en el radio. En las cuatro diagonales exactas f vale 0, y como 56 es multiplo de 8
		# esos angulos SALEN en el bucle: los cuatro vertices caian en el mismo punto (el centro) y
		# la triangulacion fallaba ("Invalid polygon data"), asi que no se pintaba nada.
		var f: float = maxf(1.0 - pow(absf(sin(a * 2.0)), filo), 0.02)
		pts.append(c + Vector2(cos(a) * rx * f, sin(a) * ry * f))
	draw_colored_polygon(pts, col)


# CHILLIDO: el unico de la familia que no muerde. Anillos que salen del que grita y BARREN la fila
# entera. Es estilo de grupo (ver _ESTILOS_DE_GRUPO): el Rey chilla UNA vez, no una por victima.
func _pintar_chillido(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = float(e["t"])
	var u: float = clampf(t / maxf(float(e["dur"]) + 0.34, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	# Hasta donde tiene que llegar: la fila alcanzada entera y un margen. Sale del ancho del grupo
	# por lo mismo que _radio_grupo -- si alcanza a cuatro, la onda tiene que pasarles por encima.
	var alcance: float = a.distance_to(b) + maxf(40.0, float(e["ancho"]) * 0.6)
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.45), minf(1.0, col.b + 0.5), 1.0)
	# CUATRO anillos desfasados: uno solo se lee como una burbuja, varios como un sonido que insiste.
	for i in 4:
		var k: float = u - float(i) * 0.16
		if k <= 0.0 or k >= 1.0:
			continue
		var rad: float = alcance * k
		# Mas anchos que altos: una onda que recorre la fila, no una esfera que se infla.
		_anillo(a, rad * 1.15, rad * 0.72,
			Color(claro.r, claro.g, claro.b, 0.55 * (1.0 - k)), maxf(1.5, 5.0 * (1.0 - k)))
	# Y el pellizco en la garganta del que grita, que es de donde sale todo.
	var p: float = 1.0 - clampf(u / 0.3, 0.0, 1.0)
	if p > 0.0:
		draw_circle(a, 9.0 * p, Color(claro.r, claro.g, claro.b, 0.5 * p))


# ZARPAZO: cuatro surcos diagonales que se abren de golpe sobre la tarjeta. Lo que hay que leer no
# es "un golpe mas fuerte", es QUE TE HAN ABIERTO: por eso los surcos van en punta por los dos
# extremos (una garra entra y sale, no se para dentro) y con el borde dentado, no como cuatro rayas
# limpias.
#
# Igual que los mordiscos, cada zarpazo cae con SU angulo y en SU sitio: dos zarpazos seguidos sobre
# la misma cara con la misma inclinacion se leen como un dibujo repitiendose.
func _pintar_zarpazo(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var g: float = float(e["semilla"])
	# Diagonal de arriba-derecha a abajo-izquierda, con hasta 30 grados de desvio a cada lado.
	var ang: float = -PI / 3.0 + sin(g * 3.3) * 0.55
	var dir := Vector2(cos(ang), sin(ang))
	var lado := Vector2(-dir.y, dir.x)
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var centro: Vector2 = e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * 0.12
	var v: float = 0.0
	var alfa: float = 1.0
	if t < dur:
		return   # la garra todavia viene con la tarjeta: aun no ha tocado
	v = clampf((t - dur) / 0.34, 0.0, 1.0)
	alfa = 1.0 if v < 0.5 else 1.0 - (v - 0.5) / 0.5
	if alfa <= 0.0:
		return
	for i in 4:
		# ESCALONADAS. Las cuatro garras no entran a la vez: entran barriendo, que es lo que hace
		# que se lea como una zarpa pasando y no como cuatro cortes que aparecen de golpe.
		var k: float = clampf((v - float(i) * 0.055) / 0.20, 0.0, 1.0)
		if k <= 0.0:
			continue
		# Las de los extremos, mas cortas y mas finas: una zarpa es un arco de dedos, no un peine.
		var perfil: float = 1.0 - 0.30 * absf(float(i) - 1.5) / 1.5
		var largo: float = caja * 1.45 * perfil
		# EN ABANICO, no en paralelo: los dedos de una zarpa se abren. Cuatro rayas exactamente
		# paralelas y a la misma distancia se leen como un rastrillo.
		var dir_i: Vector2 = dir.rotated((float(i) - 1.5) * 0.07)
		# SE TRAZA DE UNA PUNTA A LA OTRA, no crece desde el centro. Anclando el arranque y
		# alargando solo la otra punta se lee como una garra que arrastra; creciendo desde el medio
		# los surcos a medio hacer parecian munones y las cuatro salian descuadradas entre si.
		var eje: Vector2 = centro + lado * (float(i) - 1.5) * caja * 0.21 - dir_i * largo * 0.5
		_surco(eje + dir_i * largo * k * 0.5, dir_i, largo * k, caja * 0.11 * perfil,
			g + float(i) * 7.3, alfa)


# UN SURCO: un huso largo, gordo por el centro y en punta por los dos extremos, con el borde
# mordido. El dentado sale de la SEMILLA y del indice del punto, nunca de randf(): _draw puede
# correr varias veces en el mismo frame (ver la cabecera), y con azar de verdad el corte herviria.
#
# EL COLOR VIENE DE FUERA (por defecto hueso, que es el zarpazo). Un verdugon de latigo es ROJO en
# carne viva, no un tajo blanco, y es exactamente la misma forma: gordo por el medio y en punta por
# los dos extremos.
func _surco(c: Vector2, dir: Vector2, largo: float, semi: float, sem: float, alfa: float,
		col: Color = _HUESO) -> void:
	var lado := Vector2(-dir.y, dir.x)
	var n: int = 16
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n)
		# Huso: el exponente alto del interior afila las puntas y el bajo de fuera mantiene gordo
		# el centro, que es el perfil de un corte de garra.
		var w: float = semi * pow(maxf(0.0, 1.0 - pow(absf(s - 0.5) * 2.0, 1.7)), 0.62)
		# Suelo minimo: si las dos orillas se juntaran en el mismo punto exacto saldrian vertices
		# duplicados y la triangulacion se cae (le paso a la estrella del destello).
		w = maxf(w, semi * 0.03)
		var r1: float = sin(sem + float(i) * 2.7) * 0.42 + sin(sem * 1.7 + float(i) * 5.1) * 0.22
		var r2: float = sin(sem * 2.3 + float(i) * 3.1) * 0.42 + sin(sem + float(i) * 6.7) * 0.22
		izq.append(c + dir * ((s - 0.5) * largo) + lado * w * (1.0 + r1))
		der.append(c + dir * ((s - 0.5) * largo) - lado * w * (1.0 + r2))
	var pts := PackedVector2Array()
	pts.append_array(izq)
	for i in range(der.size() - 1, -1, -1):
		pts.append(der[i])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, alfa))
	# La sangre va DENTRO y fina: manda el surco blanco. Con el hilo rojo gordo el corte se leia
	# como una raya roja con reborde en vez de como algo que te han abierto.
	draw_line(c - dir * largo * 0.34, c + dir * largo * 0.34,
		Color(_SANGRE.r, _SANGRE.g, _SANGRE.b, 0.40 * alfa), maxf(1.0, semi * 0.30), true)


# ============================================================
#  CUERPO A CUERPO DE LOS BICHOS GORDOS
# ============================================================
# El desvio de angulo/sitio de cada golpe sale de la SEMILLA, igual que en los mordiscos y el
# zarpazo: dos placajes seguidos sobre la misma cara con el dibujo calcado se leen como uno solo
# parpadeando. Devuelve [avance 0..1, alfa, centro desplazado] o un avance negativo si aun no toca.
func _golpe_cuerpo(e: Dictionary, coleta: float, desvio: float) -> Array:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	if t < dur:
		return [-1.0, 0.0, Vector2.ZERO]
	var g: float = float(e["semilla"])
	var v: float = clampf((t - dur) / coleta, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.55 else 1.0 - (v - 0.55) / 0.45
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	return [v, alfa, e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * desvio]


# PLACAJE: el slime se estampa de lado y SE ESCURRE. No es el SPLAT (aquel cae de arriba y se
# chafa contra el suelo): aqui el cuerpo llega en horizontal, se aplasta contra la victima y la
# masa se le va a los lados, chorreando.
#
# Este SI va del color del bicho, al reves que los mordiscos: un slime es su color, y ademas hay
# seis distintos (verde, veneno, fuego, abisal...) que se distinguen justo por eso.
func _pintar_placaje(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.32, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.3), 1.0)
	var r: float = clampf(float(e["ancho"]) * 0.34, 20.0, 54.0)
	# Se chafa DEPRISA y se ensancha despues: primero el impacto, luego el escurrido.
	var chafa: float = clampf(v / 0.28, 0.0, 1.0)
	var ancho: float = r * (1.0 + 0.85 * chafa)
	var alto: float = r * (1.0 - 0.45 * chafa)
	# EL CUERPO, con el borde IRREGULAR. Una elipse limpia se leia como una pastilla verde; lo que
	# lo convierte en algo blando estampado son los lobulos del contorno, que ademas se marcan mas
	# segun se escurre (el 0.20 * chafa). Los bultos salen de la semilla, no de randf().
	var pts := PackedVector2Array()
	for i in 26:
		var ang: float = TAU * float(i) / 26.0
		var bulto: float = 1.0 + (0.10 + 0.20 * chafa) \
			* (sin(g * 1.7 + ang * 3.0) * 0.6 + sin(g + ang * 5.0) * 0.4)
		pts.append(b + Vector2(cos(ang) * ancho * bulto, sin(ang) * alto * bulto))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85 * alfa))
	# El brillo arriba a la izquierda: es lo que le da volumen de gelatina y no de mancha.
	draw_circle(b + Vector2(-ancho * 0.30, -alto * 0.38), maxf(1.5, minf(ancho, alto) * 0.30),
		Color(claro.r, claro.g, claro.b, 0.5 * alfa))
	# LOS GOTERONES que salpican al reventar. Salen mas hacia los lados que hacia arriba, que es
	# por donde escapa la masa cuando algo blando se estampa de frente.
	for i in 8:
		var ang: float = float(e["semilla"]) + TAU * float(i) / 8.0
		var d: Vector2 = Vector2(cos(ang) * 1.35, sin(ang) * 0.55)
		draw_circle(b + d * ancho * (0.75 + 0.7 * v), maxf(1.5, r * 0.15 * (1.0 - v)),
			Color(col.r, col.g, col.b, 0.8 * alfa))


# CORNADA: un cuerno que engancha DE ABAJO ARRIBA y levanta. Lo que la separa de un porrazo es el
# recorrido: entra bajo, sube y saca. Por eso el cuerno se dibuja como un arco que barre hacia
# arriba, y el desgarro se queda donde ha salido la punta.
func _pintar_cornada(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.30, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# El barrido: de abajo (y positivo) a arriba, con el cuerno inclinado a un lado u otro.
	var k: float = clampf(v / 0.30, 0.0, 1.0)
	var ladeo: float = sin(g * 3.3) * 0.5
	var subida: float = caja * 1.25
	var punta: Vector2 = b + Vector2(ladeo * caja * 0.30, subida * (0.45 - k * 0.9))
	# EL CUERNO: un cono GRUESO y curvado. Se dibuja como una tira de cuadrilateros porque tiene
	# que combarse; con un huso recto se leia como una estaca clavada, no como un cuerno.
	# La base es ancha de verdad (0.26 de la caja): un cuerno fino es un pincho, y lo que tiene que
	# leerse aqui es la masa del bicho detras del golpe.
	var n: int = 14
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n)          # 0 = punta, 1 = base del cuerno
		# Curvatura: cerca de la punta va casi recto y hacia la base se tuerce al lado del ladeo.
		var x: float = ladeo * caja * 0.55 * s * s
		var y: float = subida * 0.80 * s
		# Cono con la cintura llena: el (1-s^1.6) engorda el cuerpo y deja la punta afilada.
		var w: float = caja * 0.26 * (1.0 - pow(s, 1.6)) * (0.35 + 0.65 * s)
		w = maxf(w, caja * 0.008)
		izq.append(punta + Vector2(x - w, y))
		der.append(punta + Vector2(x + w, y))
	var pts := PackedVector2Array()
	pts.append_array(izq)
	for i in range(der.size() - 1, -1, -1):
		pts.append(der[i])
	draw_colored_polygon(pts, Color(_HUESO.r, _HUESO.g, _HUESO.b, alfa))
	pts.append(pts[0])
	draw_polyline(pts, Color(_ENCIA.r, _ENCIA.g, _ENCIA.b, 0.6 * alfa), maxf(1.0, caja * 0.02), true)
	# EL DESGARRO en la punta, cuando ya ha enganchado. Se reusa el huso dentado del zarpazo.
	if k > 0.5:
		_surco(punta, Vector2(ladeo, -1.0).normalized(), caja * 0.5, caja * 0.05,
			g * 1.9, alfa * 0.9)


# CARGA: la embestida. No se dibuja el bicho -se ve venir su tarjeta-, se dibuja LO QUE DEJA:
# las lineas de velocidad del trayecto y la polvareda del choque.
#
# Es el unico de los cinco que necesita el punto de ORIGEN (por eso no entra en la rama de alta()
# que hace a = b): las lineas tienen que venir de donde estaba el bicho, no de ningun sitio.
func _pintar_carga(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.UP
	var lado := Vector2(-dir.y, dir.x)
	var claro := Color(minf(1.0, col.r + 0.35), minf(1.0, col.g + 0.33), minf(1.0, col.b + 0.3), 1.0)
	# LAS LINEAS DE VELOCIDAD, que es lo que lo hace verse VENIR. Empiezan antes del golpe y
	# SOBREVIVEN un poco al choque: si se cortaran justo al impactar, la carga se perderia --
	# quedaria solo una polvareda y no se leeria de donde ha salido.
	var u_lin: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	var post: float = clampf((t - dur) / 0.16, 0.0, 1.0)   # 0 al tocar, 1 cuando ya se han ido
	if post < 1.0:
		for i in 7:
			var off: float = (float(i) - 3.0) / 3.0
			var base: Vector2 = b.lerp(a, 0.30 + 0.5 * absf(off)) + lado * off * caja * 0.42
			draw_line(base, base + dir * caja * (0.35 + 0.4 * u_lin),
				Color(claro.r, claro.g, claro.b, 0.5 * u_lin * (1.0 - post)),
				maxf(1.0, caja * 0.035), true)
	if t < dur:
		return
	var v: float = clampf((t - dur) / 0.30, 0.0, 1.0)
	var alfa: float = 1.0 - v * v
	if alfa <= 0.0:
		return
	# LA POLVAREDA: MUCHAS motas pequeñas y translucidas, no cuatro pelotas. Con circulos gordos
	# parecian bolas de barro; el polvo se lee por cantidad y por lo tenue, no por tamaño.
	for i in 18:
		var ang: float = g + TAU * float(i) / 18.0 + float(i) * 0.7
		var d := Vector2(cos(ang), sin(ang) * 0.55)
		# Cada mota con su propio alcance, o salen todas en un anillo perfecto.
		var alcance: float = 0.35 + 0.9 * v * (0.6 + 0.4 * absf(sin(g * 2.1 + float(i))))
		# Empujadas EN CONTRA de la marcha: el polvo no avanza con el bicho, se queda y se abre.
		var p: Vector2 = b + (d * alcance - dir * 0.30 * v) * caja * 0.75
		draw_circle(p, maxf(1.0, caja * 0.055 * (1.0 - v * 0.5)),
			Color(claro.r, claro.g, claro.b, 0.30 * alfa))
	# EL FRENTE del choque: un arco COMBADO perpendicular a la marcha. Va estrecho (0.55 de la
	# caja): a lo ancho que estaba antes se salia de la tarjeta y se leia como un palo cruzado.
	var arco := PackedVector2Array()
	for i in 13:
		var s: float = float(i) / 12.0 - 0.5
		# Comba EN EL SENTIDO DE LA MARCHA (+dir por el centro): es un frente empujando hacia
		# dentro. Combado al reves salia una sonrisa -- con las motas de polvo encima haciendo de
		# ojos, la tarjeta se leia literalmente como una carita.
		arco.append(b + lado * s * caja * (0.55 + 0.35 * v)
			+ dir * (1.0 - 4.0 * s * s) * caja * 0.18 * (1.0 - v))
	draw_polyline(arco, Color(claro.r, claro.g, claro.b, 0.8 * alfa),
		maxf(2.0, caja * 0.05 * (1.0 - v * 0.7)), true)


# PISOTON: la pata baja y el suelo se abre. Se lee en dos cosas: la GRIETA (lineas quebradas que
# salen del punto y se estrechan) y una onda baja de polvo que corre a ras.
#
# Es de grupo (ver _ESTILOS_DE_GRUPO): si alcanza a tres, es UN pisoton ancho.
func _pintar_pisoton(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.38, 0.06)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	# El alcance sale de lo ALCANZADO, no del daño: si pisa para tres, la grieta los cruza. El 0.5
	# es MEDIO ancho del grupo, que es el radio justo para taparlo entero -- con mas, un pisoton a
	# cuatro llenaba la pantalla de lado a lado.
	var r: float = _radio_grupo(e, 0.5, 26.0)
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.28), minf(1.0, col.b + 0.25), 1.0)
	# LA GRIETA: seis brazos quebrados que salen del pie. Los quiebros salen de la semilla, no de
	# randf(), o la grieta cambiaria de forma en cada frame.
	#
	# VAN HACIA LOS OTROS OBJETIVOS. Los brazos no se reparten por igual: los que apuntan A LO ANCHO
	# se alargan y los que suben o bajan se quedan cortos. La fila esta en horizontal, asi que asi
	# la grieta CORRE HASTA los demas alcanzados en vez de hacer una estrella bonita centrada en el
	# pie -- que es lo que dice "el suelo se ha roto hasta alli" y por tanto por que les llega.
	var k: float = clampf(v / 0.22, 0.0, 1.0)
	for i in 6:
		var ang: float = g * 1.3 + TAU * float(i) / 6.0
		# |cos| vale 1 en horizontal y 0 en vertical: el brazo que apunta a un lado llega entero y
		# el que apunta arriba se queda en un tercio.
		var reparto: float = 0.32 + 0.68 * absf(cos(ang))
		var pts := PackedVector2Array()
		for j in 5:
			var s: float = float(j) / 4.0
			# MUY aplastada en vertical: es una grieta EN EL SUELO vista de frente, asi que tiene
			# que quedarse a ras de la fila. Con poco achatamiento los brazos subian por encima de
			# las tarjetas y parecian rayos, no suelo roto.
			var desv: float = sin(g + float(i) * 2.3 + float(j) * 3.7) * 0.30
			var a2: float = ang + desv * s
			pts.append(b + Vector2(cos(a2), sin(a2) * 0.26) * r * s * k * reparto)
		# Los grosores van CAPADOS. Salen de 'r', y como 'r' crece con el numero de alcanzados, un
		# pisoton a cuatro pintaba grietas de 30 px de gruesas: parecian vigas, no grietas.
		draw_polyline(pts, Color(0.06, 0.05, 0.06, 0.8 * alfa),
			clampf(r * 0.06 * (1.0 - 0.5 * v), 1.5, 7.0), true)
	# LA ONDA de polvo, a ras: un anillo bajo que se abre justo hasta el borde de lo alcanzado.
	_anillo(b, r * (0.35 + 0.75 * v), r * (0.10 + 0.20 * v),
		Color(claro.r, claro.g, claro.b, 0.45 * alfa), clampf(r * 0.05 * (1.0 - v), 1.5, 5.0))
	# Y los cascotes que saltan del sitio.
	for i in 7:
		var ang2: float = g * 2.7 + TAU * float(i) / 7.0
		var d := Vector2(cos(ang2), -absf(sin(ang2)) * 0.8)
		draw_circle(b + d * r * (0.30 + 0.5 * v), clampf(r * 0.05 * (1.0 - v), 1.0, 5.0),
			Color(0.35, 0.31, 0.28, 0.75 * alfa))


# GOLPETAZO: un porrazo ROMO. Ni filo ni diente: un puño de piedra, una maza, una rama. Se dibuja
# como una estrella de impacto CORTA Y GORDA -lo contrario del destello de la yugular, que es de
# agujas largas- mas un anillo que se abre. Es el basico de media docena de bichos, asi que va
# corto y seco a proposito: sale muchas veces por pelea y no puede cansar.
func _pintar_golpetazo(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.26, 0.09)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var r: float = clampf(float(e["ancho"]) * 0.30, 18.0, 48.0) * (0.75 + 0.5 * clampf(v / 0.2, 0.0, 1.0))
	var claro := Color(minf(1.0, col.r + 0.42), minf(1.0, col.g + 0.4), minf(1.0, col.b + 0.35), 1.0)
	# Las puas: cortas, gordas y de largo desigual. La desigualdad sale de la semilla (fija), que
	# es lo que lo separa de una estrella de dibujo animado.
	var pts := PackedVector2Array()
	var n: int = 9
	for i in n:
		var ang: float = g + TAU * float(i) / float(n)
		var largo: float = r * (0.85 + 0.35 * sin(g * 1.7 + float(i) * 2.9))
		pts.append(b + Vector2(cos(ang), sin(ang) * 0.85) * largo)
		# El valle entre pua y pua se queda ALTO (0.52): eso es lo que lo hace romo en vez de
		# afilado. Con el valle bajo salia un sol de puntas finas.
		var med: float = ang + PI / float(n)
		pts.append(b + Vector2(cos(med), sin(med) * 0.85) * largo * 0.52)
	draw_colored_polygon(pts, Color(claro.r, claro.g, claro.b, 0.8 * alfa))
	# El anillo, APLASTADO y pegado a las puas. Redondo y ancho se leia como una burbuja alrededor
	# del golpe en vez de como la onda del porrazo.
	_anillo(b, r * (0.95 + 0.55 * v), r * (0.80 + 0.45 * v) * 0.85,
		Color(claro.r, claro.g, claro.b, 0.35 * alfa), maxf(1.5, r * 0.08 * (1.0 - v)))


# RAICES: el suelo se abre y brotan raices que suben agarrando. No las lanza nadie -- por eso este
# no embiste y si enciende la tarjeta del que las invoca.
#
# Comparte el dibujo con el estado Enraizado (CapaEstado.mata_de_raices): lo que te clava y lo que
# te tiene clavado tienen que ser LA MISMA cosa, o no se lee que sigues atado por aquello. Aqui
# CRECEN (brotan) y alli se pintan ya crecidas.
func _pintar_raices(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var caja: float = clampf(float(e["ancho"]) * 0.9, 50.0, 150.0)
	# Brotan MIENTRAS vuelan (el vuelo largo es justo eso: verlas subir) y se quedan un momento.
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	var v: float = clampf((t - dur) / 0.34, 0.0, 1.0)
	var alfa: float = 0.75 if v <= 0.0 else 0.75 * (1.0 - v * v)
	if alfa <= 0.0:
		return
	# Del BORDE DE ABAJO de la tarjeta hacia arriba: brotan del suelo, no del centro del bicho.
	var suelo: Vector2 = b + Vector2(0.0, caja * 0.36)
	CapaEstado.mata_de_raices(self, suelo, caja, caja * 0.95, float(e["semilla"]), col, alfa,
		u if v <= 0.0 else 1.0)
	# Los TERRONES que salta el suelo al abrirse, solo en el momento de brotar.
	if v <= 0.0:
		for i in 6:
			var ang: float = float(e["semilla"]) + TAU * float(i) / 6.0
			var d := Vector2(cos(ang), -absf(sin(ang)) * 0.7)
			draw_circle(suelo + d * caja * 0.35 * u, maxf(1.0, caja * 0.035 * (1.0 - u)),
				Color(0.32, 0.26, 0.18, 0.7 * alfa))


# ============================================================
#  PONERSE A CUBIERTO (Caparazon, Muralla, Endurecerse)
# ============================================================
# Los tres son la MISMA mecanica -Fortaleza sobre uno mismo, 0 de daño-, y por eso los tres pasan
# por _fx_adorno en vez de por el reparto de golpes (ver combat.gd). Lo que cambia es la FORMA,
# porque lo que se cubre no es lo mismo: un bicho con coraza, un coloso de piedra y un muñeco de
# arcilla. Con un aura para los tres, las tres habilidades se veian iguales.
#
# El ciclo lo comparten: se cierra encima (0 -> 1 durante el vuelo), aguanta puesto un rato y se
# desvanece. Devuelve [cerrado 0..1, alfa] o [-1, 0] si ya se ha ido.
func _cubrirse(e: Dictionary) -> Array:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var cierra: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	# Entra con un rebasamiento corto: cae encima y asienta, en vez de aparecer.
	if cierra < 1.0:
		cierra = 1.0 - pow(1.0 - cierra, 2.2)
	var fuera: float = clampf((t - dur) / 0.70, 0.0, 1.0)
	# Aguanta a tope media vida y despues se apaga.
	var alfa: float = 1.0 if fuera < 0.55 else 1.0 - (fuera - 0.55) / 0.45
	if alfa <= 0.0:
		return [-1.0, 0.0]
	return [cierra, alfa]


# CAPARAZON: el elitro del escarabajo. Lo que hay que leer es el ovalo ABOMBADO con la COSTURA
# central de arriba abajo, las estrias finas a los lados y el brillo -- eso es lo que lo separa de
# "una mancha negra encima del bicho".
func _pintar_caparazon(e: Dictionary) -> void:
	var r0: Array = _cubrirse(e)
	var k: float = r0[0]
	if k < 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.9, 50.0, 150.0)
	# Baja desde arriba al cerrarse: es una tapa, no algo que crece.
	var c: Vector2 = b + Vector2(0.0, -caja * 0.55 * (1.0 - k))
	var rx: float = caja * 0.44
	var ry: float = caja * 0.50
	# Negro, pero NO negro puro: sobre una tarjeta oscura desaparecia. Y translucido, porque esto va
	# encima del nombre y de la barra de vida y no puede taparlos -- mismo criterio que CapaEstado.
	var quitina := Color(0.17, 0.16, 0.19, 0.78 * alfa)
	var pts := PackedVector2Array()
	for i in 30:
		var a: float = TAU * float(i) / 30.0
		# Mas ancho por arriba que por abajo: un elitro es un huevo, no una elipse.
		var f: float = 1.0 + 0.10 * cos(a)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry * f))
	draw_colored_polygon(pts, quitina)
	# LA COSTURA, de arriba abajo por el centro. Es LO que dice "escarabajo".
	draw_line(c - Vector2(0.0, ry * 0.92), c + Vector2(0.0, ry * 0.92),
		Color(0.02, 0.02, 0.03, 0.9 * alfa), maxf(1.5, caja * 0.022), true)
	# Estrias a los dos lados, paralelas a la costura y curvandose con el cuerpo.
	for i in 8:
		var s: float = (float(i % 4) + 1.0) / 5.0 * (1.0 if i < 4 else -1.0)
		var x: float = rx * s
		var alto: float = ry * sqrt(maxf(0.0, 1.0 - s * s)) * 0.88
		draw_line(c + Vector2(x, -alto), c + Vector2(x, alto),
			Color(0.03, 0.03, 0.04, 0.55 * alfa), maxf(1.0, caja * 0.008), true)
	# EL BRILLO: dos reflejos alargados arriba a la izquierda. Es lo que lo pone brillante en vez
	# de mate, y en la referencia es la mitad de la lectura.
	for i in 2:
		var off: float = -0.42 + float(i) * 0.16
		draw_line(c + Vector2(rx * off, -ry * 0.62), c + Vector2(rx * off * 0.7, ry * 0.10),
			Color(0.85, 0.87, 0.92, (0.5 - 0.18 * float(i)) * alfa), maxf(1.5, caja * 0.02), true)
	# Reborde claro: es lo que le da el canto duro y lo despega del fondo.
	draw_polyline(pts, Color(0.55, 0.53, 0.50, 0.75 * alfa), maxf(1.5, caja * 0.016), true)


# MURALLA: un muro de LADRILLO que se levanta delante del coloso, hilada a hilada. Lo que lo lee
# como muro es el APAREJO -las hiladas desplazadas media pieza- y la junta oscura entre ellas, no
# el color; con los ladrillos alineados en rejilla parece un azulejo.
func _pintar_muralla(e: Dictionary) -> void:
	var r0: Array = _cubrirse(e)
	var k: float = r0[0]
	if k < 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.95, 50.0, 160.0)
	var ancho: float = caja * 0.96
	var alto: float = caja * 0.92
	var filas: int = 7
	var h: float = alto / float(filas)
	var abajo: float = b.y + alto * 0.5
	var g: float = float(e["semilla"])
	for f in filas:
		# SE LEVANTA de abajo arriba: cada hilada entra cuando le toca.
		var kf: float = clampf((k - float(f) * 0.09) / 0.55, 0.0, 1.0)
		if kf <= 0.0:
			continue
		var y: float = abajo - h * (float(f) + 1.0)
		# APAREJO A SOGA: las impares van desplazadas MEDIA pieza. Es el escalonado lo que lo
		# convierte en muro.
		var w: float = ancho / 3.4
		var off: float = (w * 0.5) if f % 2 == 1 else 0.0
		var x: float = b.x - ancho * 0.5 - w + off
		while x < b.x + ancho * 0.5:
			var x0: float = maxf(x, b.x - ancho * 0.5)
			var x1: float = minf(x + w, b.x + ancho * 0.5)
			if x1 - x0 > 1.0:
				# Cada pieza con su tono: un muro de ladrillos identicos parece papel pintado.
				var tono: float = 0.46 + 0.10 * sin(g + float(f) * 2.7 + x * 0.07)
				var alto_f: float = h * kf
				# TRANSLUCIDO: un muro opaco tapaba la tarjeta entera durante casi un segundo, o sea
				# el nombre y la barra de vida. Se tiene que leer el bicho DETRAS del muro.
				draw_rect(Rect2(x0 + 1.0, y + (h - alto_f) + 1.0, x1 - x0 - 2.0, alto_f - 2.0),
					Color(tono, tono * 0.97, tono * 0.94, 0.70 * alfa))
			x += w
	# La junta se lee sola por el hueco de 2 px entre piezas, pero el muro necesita SOMBRA abajo
	# para no flotar.
	draw_line(Vector2(b.x - ancho * 0.5, abajo), Vector2(b.x + ancho * 0.5, abajo),
		Color(0.05, 0.05, 0.06, 0.75 * alfa), maxf(2.0, caja * 0.03), true)


# ESCUDO (Endurecerse): placas que se cierran sobre el golem. No es un muro delante ni una coraza
# de bicho: es la propia arcilla que se acartona, asi que son PLACAS que encajan unas con otras.
func _pintar_escudo(e: Dictionary) -> void:
	var r0: Array = _cubrirse(e)
	var k: float = r0[0]
	if k < 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.9, 50.0, 150.0)
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var placas: int = 7
	for i in placas:
		var ang: float = g + TAU * float(i) / float(placas)
		# Vienen de FUERA y encajan hacia dentro: se ve el cierre.
		var d: float = caja * (0.62 - 0.16 * k)
		var c: Vector2 = b + Vector2(cos(ang) * d, sin(ang) * d * 0.72)
		var eje := Vector2(cos(ang), sin(ang) * 0.72).normalized()
		var lado := Vector2(-eje.y, eje.x)
		var largo: float = caja * 0.30
		var ancho2: float = caja * 0.19
		var tono: float = 0.55 + 0.12 * sin(g * 1.7 + float(i) * 2.1)
		draw_colored_polygon(PackedVector2Array([
			c - eje * largo * 0.35 - lado * ancho2, c - eje * largo * 0.35 + lado * ancho2,
			c + eje * largo * 0.5 + lado * ancho2 * 0.6,
			c + eje * largo * 0.5 - lado * ancho2 * 0.6,
		]), Color(col.r * tono + 0.18, col.g * tono + 0.16, col.b * tono + 0.12, 0.9 * alfa))
	# Y el nucleo endurecido: un halo apretado que dice que lo de dentro se ha vuelto piedra.
	draw_arc(b, caja * 0.40, 0.0, TAU, 26,
		Color(0.85, 0.8, 0.7, 0.35 * alfa * k), maxf(1.5, caja * 0.03), true)


# ============================================================
#  BICHOS (araña, ciempies, escarabajo)
# ============================================================

# TELARAÑA: lo unico de los insectos que VIAJA de verdad -se la lanzan a uno- y por eso llega
# volando y se despliega al tocar. Lo que la lee como red son los RADIOS mas los hilos en espiral
# entre ellos; una maraña de rayas sueltas no dice "red", dice "arañazos".
func _pintar_telarana(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.62, 34.0, 100.0)
	var hilo := Color(0.92, 0.94, 0.90)
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	if u < 1.0:
		# EN VUELO va hecha un ovillo: una red abierta cruzando la pantalla parece una cometa.
		var p: Vector2 = a.lerp(b, u * u)
		var r: float = caja * (0.16 + 0.10 * u)
		draw_arc(p, r, 0.0, TAU, 12, Color(hilo.r, hilo.g, hilo.b, 0.75), 2.0, true)
		draw_arc(p, r * 0.55, 0.0, TAU, 10, Color(hilo.r, hilo.g, hilo.b, 0.5), 1.5, true)
		return
	var v: float = clampf((t - dur) / 0.40, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.5 else 1.0 - (v - 0.5) / 0.5
	if alfa <= 0.0:
		return
	# SE DESPLIEGA de golpe y se queda TIRANTE: crece deprisa hasta su tamaño y ahi se planta.
	var k: float = clampf(v / 0.18, 0.0, 1.0)
	var radios: int = 9
	var rr: float = caja * k
	# Los radios, con el largo desigual: una red de verdad no es un abanico perfecto.
	var largos: Array = []
	for i in radios:
		largos.append(rr * (0.78 + 0.22 * absf(sin(g * 1.7 + float(i) * 2.3))))
	for i in radios:
		var ang: float = g + TAU * float(i) / float(radios)
		draw_line(b, b + Vector2(cos(ang), sin(ang) * 0.8) * float(largos[i]),
			Color(hilo.r, hilo.g, hilo.b, 0.55 * alfa), 1.5, true)
	# Y las vueltas en espiral entre radio y radio, que es lo que la convierte en RED.
	for anillo in range(1, 4):
		var f: float = float(anillo) / 3.5
		var pts := PackedVector2Array()
		for i in radios + 1:
			var idx: int = i % radios
			var ang2: float = g + TAU * float(i) / float(radios)
			# Cada tramo cuelga un poco hacia dentro: los hilos no van tensos entre radios.
			pts.append(b + Vector2(cos(ang2), sin(ang2) * 0.8) * float(largos[idx]) * f * 0.94)
		draw_polyline(pts, Color(hilo.r, hilo.g, hilo.b, 0.42 * alfa), 1.5, true)


# ENROSQUE: el ciempies se enrolla alrededor y APRIETA. La clave es que los anillos se CIERREN --
# si se quedaran del mismo tamaño seria un adorno; lo que duele es que encojan.
func _pintar_enrosque(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.40, 0.05)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.62, 34.0, 100.0)
	var claro := Color(minf(1.0, col.r + 0.28), minf(1.0, col.g + 0.22), minf(1.0, col.b + 0.2), 1.0)
	# APRIETA: de 1.15 a 0.62 del tamaño. Ese encogimiento ES la habilidad.
	var apriete: float = 1.15 - 0.53 * clampf(v / 0.45, 0.0, 1.0)
	for i in 3:
		var f: float = 1.0 - float(i) * 0.16
		var y: float = (float(i) - 1.0) * caja * 0.34
		_anillo(b + Vector2(0.0, y), caja * apriete * f, caja * 0.20 * f,
			Color(col.r, col.g, col.b, 0.85 * alfa), maxf(2.5, caja * 0.11))
		# El brillo del lomo, arriba de cada vuelta: le da bulto de cuerpo y no de aro pintado.
		_anillo(b + Vector2(0.0, y - caja * 0.04), caja * apriete * f * 0.97, caja * 0.19 * f,
			Color(claro.r, claro.g, claro.b, 0.35 * alfa), maxf(1.0, caja * 0.035))
	# Y las PATAS agarrando por fuera del anillo del medio: es un ciempies, no una serpiente.
	for i in 14:
		var s: float = float(i) / 13.0 - 0.5
		var x: float = s * caja * apriete * 1.9
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var base := Vector2(b.x + x, b.y + lado * caja * 0.18)
		draw_line(base, base + Vector2(sin(g + float(i)) * caja * 0.05, lado * caja * 0.16),
			Color(claro.r, claro.g, claro.b, 0.6 * alfa), maxf(1.0, caja * 0.03), true)


# OLEADA DE PATAS: decenas de patas finas recorriendote de arriba abajo. Cada una pincha poco -por
# eso son finas y muchas-, y lo que se lee es la CANTIDAD y el barrido, no cada pinchazo.
func _pintar_patas(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.30, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.26), minf(1.0, col.b + 0.2), 1.0)
	# El barrido BAJA por la tarjeta: la franja de patas activas recorre de arriba abajo. El
	# recorrido se queda DENTRO de la caja (-0.48 a 0.48): pasandose, la ultima mitad de las patas
	# salia por debajo de la tarjeta y parecia que pinchaban el suelo.
	var frente: float = -0.48 + 0.96 * v
	for i in 22:
		var s: float = float(i) / 21.0 - 0.5
		# Cada pata entra cuando el frente pasa por su altura, y se apaga detras.
		var y: float = sin(g * 1.3 + float(i) * 1.9) * 0.42
		var d: float = absf(y - frente)
		if d > 0.30:
			continue
		var k: float = 1.0 - d / 0.30
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var base := Vector2(b.x + s * caja * 1.5, b.y + y * caja)
		# En gancho: un tramo recto y una uña corta al final. Una raya suelta no pincha.
		var pta: Vector2 = base + Vector2(lado * caja * 0.28 * k, caja * 0.19 * k)
		draw_line(base, pta, Color(claro.r, claro.g, claro.b, 0.85 * alfa * k),
			maxf(1.5, caja * 0.032), true)
		draw_line(pta, pta + Vector2(lado * caja * 0.08, -caja * 0.09) * k,
			Color(_HUESO.r, _HUESO.g, _HUESO.b, 0.85 * alfa * k), maxf(1.0, caja * 0.026), true)


# RODADA: el escarabajo se hace una bola y ARROLLA. Es la carga con giro, asi que lo que la separa
# de una embestida normal son las estelas circulares y el polvo saliendo por debajo.
func _pintar_rodada(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.34, 0.06)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	# UNA BOLA ES DEL TAMAÑO DE UNA BOLA. Lo que crece cuando arrolla a varios no es su diametro,
	# es SU RECORRIDO: por eso el radio va CAPADO y lo que sale del ancho del grupo es el trayecto.
	# Sacando el radio de _radio_grupo a secas, un arrollamiento a cuatro pintaba una bola de 500 px
	# quieta en el centro, que no rueda ni arrolla: solo tapa.
	var r: float = clampf(_radio_grupo(e, 0.28, 22.0), 22.0, 46.0)
	var span: float = maxf(float(e["ancho"]) * 0.5 - r, 0.0)
	# CRUZA la fila mientras dura: entra por un lado y sale por el otro.
	var cx: float = b.x + lerpf(-span, span, clampf(v / 0.75, 0.0, 1.0))
	b = Vector2(cx, b.y)
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.28), minf(1.0, col.b + 0.25), 1.0)
	# LA BOLA, con el giro marcado por dentro. El angulo avanza con v: rueda de verdad.
	var giro: float = g + v * 9.0
	draw_circle(b, r, Color(col.r * 0.55 + 0.08, col.g * 0.55 + 0.08, col.b * 0.55 + 0.08,
		0.92 * alfa))
	for i in 4:
		var a2: float = giro + PI * float(i) / 4.0
		draw_line(b - Vector2(cos(a2), sin(a2)) * r * 0.85,
			b + Vector2(cos(a2), sin(a2)) * r * 0.85,
			Color(claro.r, claro.g, claro.b, 0.30 * alfa), maxf(1.5, r * 0.09), true)
	draw_arc(b, r, 0.0, TAU, 26, Color(claro.r, claro.g, claro.b, 0.8 * alfa),
		maxf(2.0, r * 0.10), true)
	# ESTELAS de rotacion: arcos cortos detras, que es lo que dice "esto viene girando".
	for i in 3:
		var off: float = float(i) * 0.55
		var ini: float = giro - 2.4 - off
		draw_arc(b, r * (1.20 + 0.22 * float(i)), ini, ini + 1.1, 12,
			Color(claro.r, claro.g, claro.b, (0.4 - 0.1 * float(i)) * alfa),
			maxf(1.0, r * 0.06), true)
	# Y el polvo que levanta por abajo.
	for i in 6:
		var ang: float = g * 2.1 + TAU * float(i) / 6.0
		draw_circle(b + Vector2(cos(ang) * r * (1.1 + 0.5 * v), absf(sin(ang)) * r * 0.55),
			maxf(1.0, r * 0.10 * (1.0 - v)), Color(claro.r, claro.g, claro.b, 0.3 * alfa))


# MIRADA: se abre un OJO en el que mira y de el sale una onda hasta el objetivo. Lo usan la Mirada
# petrea de la gargola y la Mirada del vacio de la aberracion -- las dos son lo mismo: no te tocan,
# te MIRAN, y el efecto viaja por la vista.
#
# Es de las pocas de bicho que viaja de verdad, asi que NO embiste y SI enciende la tarjeta del que
# mira mientras la onda cruza (queda fuera de _CUERPO_A_CUERPO a proposito).
func _pintar_mirada(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var caja: float = clampf(float(e["ancho"]) * 0.5, 30.0, 80.0)
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.42), minf(1.0, col.b + 0.5), 1.0)
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	var v: float = clampf((t - dur) / 0.30, 0.0, 1.0)
	var alfa: float = 1.0 if v <= 0.0 else 1.0 - v * v
	if alfa <= 0.0:
		return
	# EL OJO, en el que mira. Se abre (el parpado sube) y se queda mirando.
	var abre: float = clampf(u / 0.45, 0.0, 1.0) * (1.0 - v * 0.7)
	if abre > 0.02:
		var rx: float = caja * 0.42
		var ry: float = caja * 0.30 * abre
		# La almendra: dos arcos enfrentados. Con una elipse sale un huevo, no un ojo.
		var ojo := PackedVector2Array()
		for i in 15:
			var s: float = float(i) / 14.0 * 2.0 - 1.0
			ojo.append(a + Vector2(s * rx, -ry * (1.0 - s * s)))
		for i in 15:
			var s2: float = 1.0 - float(i) / 14.0 * 2.0
			ojo.append(a + Vector2(s2 * rx, ry * (1.0 - s2 * s2)))
		draw_colored_polygon(ojo, Color(0.95, 0.95, 0.92, 0.9 * alfa))
		# El iris mira AL OBJETIVO: se desplaza hacia el, que es lo que lo hace inquietante.
		var haz: Vector2 = (b - a).normalized()
		var iris: Vector2 = a + haz * rx * 0.35
		draw_circle(iris, maxf(2.0, ry * 0.75), Color(col.r * 0.5, col.g * 0.5, col.b * 0.6,
			0.95 * alfa))
		draw_circle(iris, maxf(1.0, ry * 0.34), Color(0.03, 0.02, 0.05, alfa))
		draw_polyline(ojo, Color(0.1, 0.09, 0.12, 0.8 * alfa), maxf(1.0, caja * 0.03), true)
	# LA ONDA que sale del ojo y llega al objetivo: anillos que viajan por el trayecto.
	for i in 3:
		var k: float = u - float(i) * 0.22
		if k <= 0.0 or k >= 1.0:
			continue
		var p: Vector2 = a.lerp(b, k)
		var rr: float = caja * (0.22 + 0.55 * k)
		_anillo(p, rr, rr * 0.82, Color(claro.r, claro.g, claro.b, 0.5 * (1.0 - k) * alfa),
			maxf(1.5, caja * 0.06 * (1.0 - k)))
	# Y al llegar, el objetivo queda envuelto un momento.
	if v > 0.0:
		_anillo(b, caja * (0.75 + 0.5 * v), caja * (0.6 + 0.4 * v),
			Color(claro.r, claro.g, claro.b, 0.45 * alfa), maxf(1.5, caja * 0.07 * (1.0 - v)))


# LATIGAZO: el tentaculo azota desde lejos y lo que se ve es LO QUE DEJA -- los verdugones cruzados
# sobre el golpeado. Se reusa el huso de borde dentado del zarpazo (_surco), que es exactamente la
# forma de una marca de azote: gorda por el medio y en punta por los dos extremos.
#
# La diferencia con el zarpazo es que aqui son POCAS marcas, largas y cruzadas en angulos distintos
# (un latigo no da cuatro surcos paralelos), y va con el tentaculo entrando de fuera.
func _pintar_latigazo(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.32, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# EL TENTACULO entrando: una linea gruesa y combada que llega de fuera y se retira. Es lo que
	# dice que el golpe viene de LEJOS, que es la gracia de la habilidad.
	var ent: float = clampf(v / 0.30, 0.0, 1.0)
	if v < 0.55:
		var lado: float = 1.0 if sin(g * 2.3) > 0.0 else -1.0
		var desde := b + Vector2(lado * caja * 2.2, -caja * 0.9)
		var pts := PackedVector2Array()
		for i in 9:
			var s: float = float(i) / 8.0
			var p: Vector2 = desde.lerp(b, s * ent)
			# Combado: un latigo no llega recto.
			p.y += sin(s * PI) * caja * 0.42 * (1.0 - ent * 0.5)
			pts.append(p)
		draw_polyline(pts, Color(col.r * 0.7, col.g * 0.6, col.b * 0.75,
			0.7 * alfa * (1.0 - v / 0.55)), maxf(2.0, caja * 0.07), true)
	# LOS VERDUGONES: dos o tres, largos y CRUZADOS en angulos distintos. Escalonados, para que se
	# lean como varios azotes seguidos y no como una equis dibujada de golpe.
	for i in 3:
		var k: float = clampf((v - float(i) * 0.10) / 0.22, 0.0, 1.0)
		if k <= 0.0:
			continue
		var ang: float = -0.9 + sin(g * 1.9 + float(i) * 2.7) * 1.1
		var dir := Vector2(cos(ang), sin(ang))
		var off: Vector2 = Vector2(-dir.y, dir.x) * (float(i) - 1.0) * caja * 0.22
		var largo: float = caja * 1.5 * (0.82 + 0.18 * absf(sin(g + float(i))))
		# Se traza de una punta a la otra, como el zarpazo: un latigo pasa, no aparece.
		var eje: Vector2 = b + off - dir * largo * 0.5
		# En CARNE VIVA, no en hueso: esto no te abre como una garra, te levanta la piel.
		_surco(eje + dir * largo * k * 0.5, dir, largo * k, caja * 0.075, g + float(i) * 5.1,
			alfa, Color(0.82, 0.22, 0.20))


func _anillo(c: Vector2, rx: float, ry: float, col: Color, grosor: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var ang: float = TAU * float(i) / 32.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_polyline(pts, col, grosor, true)
