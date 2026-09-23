# ============================================================
#  combat_formas.gd
#  LAS FORMAS DE UN ATAQUE en coordenadas de mundo: el trozo de suelo que tapa lo que lanzas. Es la
#  pieza que sustituye al "el objetivo y sus vecinos" de la fila cuando se pelea en el mapa.
#
#  CUATRO, y con estas se cubre todo lo que hay escrito hoy:
#    CIRCULO      el golpe sismico del martillo (cae donde golpeas) y el molinete del mandoble
#                 (cae alrededor TUYO). La diferencia entre los dos es un booleano: `desde_quien_ataca`.
#    CONO         el hachazo brutal, los alientos. Abanico hacia donde miras.
#    LINEA        lanza, estocada, rayos: todo lo que hay en la franja entre tu y el fondo.
#    RECTANGULO   huellas de cuerpo que cae, y la propia arena.
#  Un basico a melé es un PUNTO: un objetivo y el alcance del arma.
#
#  LA FORMA SE DERIVA, Y ADEMAS SE PUEDE DECIDIR A MANO. Las 120 habilidades escritas no traen
#  forma, asi que se les deduce de lo que ya dicen (area_modo, area_max) y siguen funcionando sin
#  tocar un solo .tres. Y quien quiera decidirla una a una -- que es lo que se va a hacer -- rellena
#  `forma` en la ficha y manda ella. La ficha gana siempre; la derivacion es solo el valor por
#  defecto.
#
#  LO QUE NO SE TOCA. area_secundario, area_secundario_decay, area_efectos_secundarios,
#  area_prob_secundario, golpes_min/max y area_escalas NO son geometricos: son funcion de A CUANTOS
#  alcanzaste, no de donde. La forma solo decide el CONJUNTO; el reparto sigue siendo el de siempre.
#  Y `area_max` se mantiene como TOPE DURO: la forma propone candidatos y area_max trunca por
#  cercania, asi que la invariante "nunca mas de N victimas" se conserva exacta.
#
#  LOS NUMEROS de aqui (R_BASE, PASO, aperturas) son PROVISIONALES: se calibran mirandolos cuando
#  haya cuerpos de verdad en una arena, no adivinando.
# ============================================================

extends RefCounted
class_name CombatFormas

# Los valores que se guardan en la ficha (AbilityData.forma / SpellData.forma). Van como ENTEROS y
# no como un enum importado a proposito: ability_data.gd es de scripts/items y no tiene por que
# saber nada de la pantalla de combate. -1 en la ficha = derivala tu.
enum Tipo { PUNTO, CIRCULO, CONO, LINEA, RECTANGULO }
# Como se APUNTA en el mapa (AbilityData.forma_apunte). Ver la ficha para lo que es cada uno.
enum Apunte { OBJETIVO, DELANTE, ALREDEDOR, LIBRE }

# Radio de un circulo que alcanza a UNO. Una celda y pico: lo justo para tapar a quien apuntas.
const R_BASE := 40.0
# Lo que crece el radio por cada objetivo mas que pide area_max.
const PASO := 28.0
# El abanico de un BARRIDO (molinete, cleave): ancho, porque barre a los que tienes delante.
const APERTURA_BARRIDO := 110.0
# El circulito de un hechizo de ADYACENTES: el objetivo y quien este pegado a el.
const RADIO_ADYACENTE := 48.0
# Ancho por defecto de una LINEA.
const ANCHO_LINEA := 36.0


# ------------------------------------------------------------
#  LA FORMA
# ------------------------------------------------------------
class Forma extends RefCounted:
	var tipo: int = 0                  # CombatFormas.Tipo
	var origen: Vector2 = Vector2.ZERO # quien lanza (manda en CONO y LINEA)
	var centro: Vector2 = Vector2.ZERO # donde cae (manda en CIRCULO y RECTANGULO)
	var dir: Vector2 = Vector2.RIGHT   # hacia donde (CONO, LINEA, RECTANGULO girado)
	var radio: float = 0.0
	var apertura: float = 0.0          # grados, el abanico ENTERO (no la mitad)
	var largo: float = 0.0
	var ancho: float = 0.0
	var tam: Vector2 = Vector2.ZERO    # RECTANGULO

	# ¿Este punto esta tapado por la forma? Es la unica pregunta que le hace la pelea.
	func contiene(p: Vector2) -> bool:
		match tipo:
			CombatFormas.Tipo.PUNTO:
				return p.distance_to(centro) <= maxf(radio, 1.0)
			CombatFormas.Tipo.CIRCULO:
				return p.distance_to(centro) <= radio
			CombatFormas.Tipo.CONO:
				var v: Vector2 = p - origen
				var d: float = v.length()
				if d > radio:
					return false
				# Quien esta ENCIMA del que lanza entra siempre: sin esto, un cono no se llevaria por
				# delante al que tiene pegado al cuerpo (el angulo de un vector casi nulo es ruido).
				if d < 1.0:
					return true
				return absf(rad_to_deg(v.angle_to(dir))) <= apertura * 0.5
			CombatFormas.Tipo.LINEA:
				var v2: Vector2 = p - origen
				var t: float = v2.dot(dir)
				if t < 0.0 or t > largo:
					return false
				return absf(v2.cross(dir)) <= ancho * 0.5
			CombatFormas.Tipo.RECTANGULO:
				var v3: Vector2 = (p - centro).rotated(-dir.angle())
				return absf(v3.x) <= tam.x * 0.5 and absf(v3.y) <= tam.y * 0.5
		return false

	# ¿La forma ROZA esta caja (el cuerpo de alguien, en mundo)? Es la pregunta del mapa: le da a quien
	# le toque el cuerpo, no solo el centro, asi un jefe grande cuenta por su borde (igual que el
	# alcance, que tambien se mide borde a borde).
	func toca(r: Rect2) -> bool:
		match tipo:
			CombatFormas.Tipo.PUNTO, CombatFormas.Tipo.CIRCULO:
				return _mas_cerca(r, centro).distance_to(centro) <= maxf(radio, 1.0)
			CombatFormas.Tipo.CONO:
				# El punto de la caja mas cercano al origen y, si ese cae fuera del abanico, el centro y las
				# esquinas: basta con que UNO este dentro.
				for p in [_mas_cerca(r, origen), r.get_center(), r.position, r.end,
						Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
					if contiene(p):
						return true
				return false
		return contiene(r.get_center())

	# ¿La forma TOCA el circulo que pisa alguien (centro en sus pies, radio lo que pisa)? Es la pregunta
	# del mapa: le da a quien la huella le toque lo que pisa.
	func toca_circulo(p: Vector2, r: float) -> bool:
		match tipo:
			CombatFormas.Tipo.PUNTO, CombatFormas.Tipo.CIRCULO:
				return p.distance_to(centro) <= maxf(radio, 1.0) + r
			CombatFormas.Tipo.CONO:
				var v: Vector2 = p - origen
				var d: float = v.length()
				if d - r > radio:
					return false
				# Pegado al que lo lanza (lo que pisa te toca los pies): dentro, mire hacia donde mire.
				if d <= r:
					return true
				# El abanico se ensancha lo que ocupa su circulo visto desde el origen.
				var holgura: float = rad_to_deg(asin(clampf(r / d, 0.0, 1.0)))
				return absf(rad_to_deg(v.angle_to(dir))) <= apertura * 0.5 + holgura
			CombatFormas.Tipo.LINEA:
				var t2: float = clampf((p - origen).dot(dir), 0.0, largo)
				return p.distance_to(origen + dir * t2) <= ancho * 0.5 + r
		return contiene(p)

	# El punto de la caja mas cercano a 'p' (p mismo si esta dentro).
	static func _mas_cerca(r: Rect2, p: Vector2) -> Vector2:
		return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))

	# El punto con el que se ordena por "cercania al centro de la huella". Para las formas que
	# salen del que ataca, el centro util es el medio del alcance, no sus pies.
	func centro_util() -> Vector2:
		match tipo:
			CombatFormas.Tipo.CONO:
				return origen + dir * radio * 0.5
			CombatFormas.Tipo.LINEA:
				return origen + dir * largo * 0.5
		return centro

	func _to_string() -> String:
		match tipo:
			CombatFormas.Tipo.PUNTO: return "PUNTO(%.0f)" % radio
			CombatFormas.Tipo.CIRCULO: return "CIRCULO(r=%.0f)" % radio
			CombatFormas.Tipo.CONO: return "CONO(r=%.0f, %.0fº)" % [radio, apertura]
			CombatFormas.Tipo.LINEA: return "LINEA(%.0fx%.0f)" % [largo, ancho]
			CombatFormas.Tipo.RECTANGULO: return "RECT(%.0fx%.0f)" % [tam.x, tam.y]
		return "?"


# ------------------------------------------------------------
#  FABRICAS
# ------------------------------------------------------------

static func punto(centro: Vector2, radio: float = 16.0) -> Forma:
	var f := Forma.new()
	f.tipo = Tipo.PUNTO
	f.centro = centro
	f.radio = radio
	return f


static func circulo(centro: Vector2, radio: float) -> Forma:
	var f := Forma.new()
	f.tipo = Tipo.CIRCULO
	f.centro = centro
	f.radio = radio
	return f


static func cono(origen: Vector2, dir: Vector2, radio: float, apertura: float) -> Forma:
	var f := Forma.new()
	f.tipo = Tipo.CONO
	f.origen = origen
	f.dir = _dir_segura(dir)
	f.radio = radio
	f.apertura = apertura
	f.centro = origen + f.dir * radio * 0.5
	return f


static func linea(origen: Vector2, dir: Vector2, largo: float,
		ancho: float = ANCHO_LINEA) -> Forma:
	var f := Forma.new()
	f.tipo = Tipo.LINEA
	f.origen = origen
	f.dir = _dir_segura(dir)
	f.largo = largo
	f.ancho = ancho
	f.centro = origen + f.dir * largo * 0.5
	return f


static func rectangulo(centro: Vector2, tam: Vector2, dir: Vector2 = Vector2.RIGHT) -> Forma:
	var f := Forma.new()
	f.tipo = Tipo.RECTANGULO
	f.centro = centro
	f.tam = tam
	f.dir = _dir_segura(dir)
	return f


# Una direccion que nunca es cero: apuntar a tus propios pies dejaria el cono sin orientacion y
# `angle_to` devolveria ruido.
static func _dir_segura(d: Vector2) -> Vector2:
	return d.normalized() if d.length_squared() > 0.000001 else Vector2.RIGHT


# ------------------------------------------------------------
#  DERIVACION desde las fichas
# ------------------------------------------------------------

# El radio de un circulo que quiere alcanzar a 'n' objetivos.
static func radio_para(n: int) -> float:
	return R_BASE + PASO * float(maxi(0, n - 1))


# LA FORMA DE UNA HABILIDAD. Si la ficha trae `forma` (>= 0) manda ella; si no, se deduce.
# 'radio_arena' es el tamaño de la arena: lo que para la fila era "toda la fila viva", aqui es un
# circulo que la tapa entera.
static func de_habilidad(ab: AbilityData, pos_atacante: Vector2, pos_objetivo: Vector2,
		radio_arena: float) -> Forma:
	if ab == null:
		return punto(pos_objetivo)

	var desde_mi: bool = bool(ab.get("forma_desde_quien_ataca"))
	var base: Vector2 = pos_atacante if desde_mi else pos_objetivo
	var dir: Vector2 = pos_objetivo - pos_atacante

	# 1) LO QUE DIGA LA FICHA.
	var t: int = int(ab.get("forma"))
	if t >= 0:
		return _de_campos(t, ab.get("forma_radio"), ab.get("forma_apertura"),
			pos_atacante, pos_objetivo, base, dir, radio_arena)

	# 2) DERIVADA. Sin area, un punto.
	if not ab.es_area() or ab.area_max <= 1:
		return punto(pos_objetivo)
	# BARRIDO = todos reciben todos los golpes: eso es barrer lo que tienes delante -> cono.
	if ab.area_modo == AbilityData.AreaModo.BARRIDO:
		return cono(pos_atacante, dir, maxf(radio_para(ab.area_max), R_BASE), APERTURA_BARRIDO)
	# SPLASH. "Toda la fila" pasa a ser un circulo que tapa la arena entera.
	if ab.area_max >= 99:
		return circulo(base, radio_arena)
	return circulo(base, radio_para(ab.area_max))


# LA FORMA DE UN HECHIZO. Mismo criterio: la ficha manda, si no se deduce del alcance.
static func de_hechizo(spell: SpellData, pos_lanzador: Vector2, pos_objetivo: Vector2,
		radio_arena: float) -> Forma:
	if spell == null:
		return punto(pos_objetivo)

	var desde_mi: bool = bool(spell.get("forma_desde_quien_ataca"))
	var base: Vector2 = pos_lanzador if desde_mi else pos_objetivo
	var dir: Vector2 = pos_objetivo - pos_lanzador

	var t: int = int(spell.get("forma"))
	if t >= 0:
		return _de_campos(t, spell.get("forma_radio"), spell.get("forma_apertura"),
			pos_lanzador, pos_objetivo, base, dir, radio_arena)

	match spell.alcance:
		SpellData.Alcance.ADYACENTES:
			return circulo(base, RADIO_ADYACENTE)
		SpellData.Alcance.TODOS:
			return circulo(base, radio_arena)
	return punto(pos_objetivo)


# LA FORMA DE UNA HABILIDAD EN EL MAPA, la que ya esta hecha a mano (forma_apunte >= 0).
#   pies     los pies del que la lanza (el centro de su cuerpo en el suelo), donde la pelea dice
#   pisa     el radio de lo que pisa
#   alcance  el de su arma: lo MAS LEJOS que puede caer el centro, contado desde el borde de lo que
#            pisa (la misma medida que el alcance del basico). Igual en todas las direcciones.
#   hacia    a donde apunta: el raton, o la posicion del enemigo pulsado
# DELANTE y LIBRE ponen el centro donde apuntas pero sin pasar de ese tope; ALREDEDOR, en ti. El CONO
# y la LINEA salen de tus pies.
static func de_habilidad_mapa(ab: AbilityData, pies: Vector2, pisa: float, alcance: float,
		hacia: Vector2) -> Forma:
	var dir: Vector2 = hacia - pies
	var centro: Vector2 = pies
	match int(ab.forma_apunte):
		Apunte.DELANTE, Apunte.LIBRE:
			centro = pies + dir.limit_length(pisa + alcance)
		Apunte.OBJETIVO:
			centro = hacia
	var r: float = ab.forma_radio if ab.forma_radio > 0.0 else R_BASE
	var ap: float = ab.forma_apertura if ab.forma_apertura > 0.0 else APERTURA_BARRIDO
	match int(ab.forma):
		Tipo.CONO:
			return cono(pies, dir, r, ap)
		Tipo.LINEA:
			return linea(pies, dir, r, ANCHO_LINEA)
		Tipo.PUNTO:
			return punto(centro, r)
	return circulo(centro, r)


# Monta la forma que pide la ficha con los radios que pida (0 = el de por defecto de esa forma).
static func _de_campos(t: int, radio_ficha: Variant, apertura_ficha: Variant,
		pos_atacante: Vector2, pos_objetivo: Vector2, base: Vector2,
		dir: Vector2, radio_arena: float) -> Forma:
	var r: float = float(radio_ficha) if float(radio_ficha) > 0.0 else R_BASE
	var ap: float = float(apertura_ficha) if float(apertura_ficha) > 0.0 else APERTURA_BARRIDO
	match t:
		Tipo.PUNTO:
			return punto(pos_objetivo, r)
		Tipo.CIRCULO:
			return circulo(base, r)
		Tipo.CONO:
			return cono(pos_atacante, dir, r, ap)
		Tipo.LINEA:
			return linea(pos_atacante, dir, r, ANCHO_LINEA)
		Tipo.RECTANGULO:
			return rectangulo(base, Vector2(r, r), dir)
	return circulo(base, minf(r, radio_arena))


# ------------------------------------------------------------
#  A QUIEN PILLA
# ------------------------------------------------------------

# Los candidatos que tapa la forma, ORDENADOS por cercania al centro de la huella y recortados a
# 'tope' (= area_max). El principal va SIEMPRE el primero: el log y los efectos dan por hecho que el
# de la posicion 0 es el objetivo.
#
# El desempate por 'orden' NO es un adorno: con distancias en float dos cuerpos pueden empatar, y el
# anfitrion y el espejo tienen que repartir identico o la pelea se descuadra en red. 'orden' es el
# indice en _enemies, que las dos maquinas comparten.
static func alcanzados(f: Forma, candidatos: Array, principal: Variant,
		tope: int, pos_de: Callable, orden_de: Callable) -> Array:
	var out: Array = []
	if f == null:
		return out
	var centro: Vector2 = f.centro_util()
	for c in candidatos:
		if c == principal or f.contiene(pos_de.call(c)):
			out.append(c)
	out.sort_custom(func(x, y):
		# El principal, siempre delante.
		if x == principal:
			return true
		if y == principal:
			return false
		var dx: float = (pos_de.call(x) as Vector2).distance_squared_to(centro)
		var dy: float = (pos_de.call(y) as Vector2).distance_squared_to(centro)
		if is_equal_approx(dx, dy):
			return int(orden_de.call(x)) < int(orden_de.call(y))
		return dx < dy)
	if tope > 0 and out.size() > tope:
		out.resize(tope)
	return out


# ------------------------------------------------------------
#  DIBUJO (la previsualizacion en el suelo)
# ------------------------------------------------------------

# Pinta la forma sobre un CanvasItem que este en coordenadas de MUNDO. Sin achatar: el suelo es una
# rejilla cuadrada aunque los cuerpos vayan proyectados a 45 grados.
static func dibujar(f: Forma, ci: CanvasItem, col: Color) -> void:
	if f == null or ci == null:
		return
	var relleno := Color(col.r, col.g, col.b, col.a * 0.22)
	match f.tipo:
		Tipo.PUNTO, Tipo.CIRCULO:
			ci.draw_circle(f.centro, maxf(f.radio, 2.0), relleno)
			ci.draw_arc(f.centro, maxf(f.radio, 2.0), 0.0, TAU, 64, col, 2.5)
		Tipo.CONO:
			var a0: float = f.dir.angle() - deg_to_rad(f.apertura * 0.5)
			var a1: float = f.dir.angle() + deg_to_rad(f.apertura * 0.5)
			var pts := PackedVector2Array([f.origen])
			for i in 33:
				var a: float = a0 + (a1 - a0) * float(i) / 32.0
				pts.append(f.origen + Vector2(cos(a), sin(a)) * f.radio)
			ci.draw_colored_polygon(pts, relleno)
			ci.draw_arc(f.origen, f.radio, a0, a1, 48, col, 2.5)
			ci.draw_line(f.origen, f.origen + Vector2(cos(a0), sin(a0)) * f.radio, col, 2.5)
			ci.draw_line(f.origen, f.origen + Vector2(cos(a1), sin(a1)) * f.radio, col, 2.5)
		Tipo.LINEA:
			var n: Vector2 = Vector2(-f.dir.y, f.dir.x) * f.ancho * 0.5
			var p0: Vector2 = f.origen
			var p1: Vector2 = f.origen + f.dir * f.largo
			ci.draw_colored_polygon(
				PackedVector2Array([p0 - n, p1 - n, p1 + n, p0 + n]), relleno)
			ci.draw_polyline(
				PackedVector2Array([p0 - n, p1 - n, p1 + n, p0 + n, p0 - n]), col, 2.5)
		Tipo.RECTANGULO:
			var h: Vector2 = f.tam * 0.5
			var ang: float = f.dir.angle()
			var esq := PackedVector2Array()
			for e in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
				esq.append(f.centro + (e as Vector2).rotated(ang))
			ci.draw_colored_polygon(esq, relleno)
			esq.append(esq[0])
			ci.draw_polyline(esq, col, 2.5)
