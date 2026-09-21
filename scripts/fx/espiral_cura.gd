# ============================================================
#  espiral_cura.gd
#  EL DIBUJO DE UNA CURA: una linea verde en espiral (un «muelle») que sube girando alrededor del
#  personaje y pasa por DELANTE y por DETRAS de el, con cruces verdes que nacen del suelo, suben y se
#  difuminan. Es la referencia que dibujo el usuario el 21/09/2026.
#
#  Solo pinta, no guarda nada: la llaman el COMBATE (CapaHechizos, sobre la figura de la tarjeta) y el
#  MAPA (CuraEnCurso, sobre el muñeco). Un solo sitio a proposito: si cada uno tuviera su espiral, al
#  primer retoque dejarian de parecerse.
#
#  PORQUE PASA POR DETRAS: el trozo de espiral que queda al fondo (profundidad < 0) se pinta aparte
#  del de delante ('pase'). En el mapa cada uno va en un nodo con su z (uno debajo del muñeco y otro
#  encima); en combate no hay muñeco que tape, asi que el de atras se pinta tenue y fino y ya se lee.
# ============================================================
extends RefCounted
class_name EspiralCura

const VERDE := Color(0.45, 1.0, 0.55)
const VUELTAS := 3.2
const SEGMENTOS := 96
const CRUCES := 8

enum Pase { AMBOS, DETRAS, DELANTE }


# 'pie' = los pies del personaje; 'alto' y 'radio' = cuanto sube y cuanto se abre; 'w' = por donde va
# (0 al empezar, 1 al acabar); 'semilla' reparte las cruces para que dos curas no sean calcadas.
static func pintar(ci: CanvasItem, pie: Vector2, alto: float, radio: float, w: float, semilla: float,
		pase: int = Pase.AMBOS) -> void:
	if w <= 0.0 or w >= 1.0:
		return
	# Se apaga al final, no de golpe: una cura que parpadea no se siente.
	var vida: float = clampf((1.0 - w) / 0.22, 0.0, 1.0) * clampf(w / 0.08, 0.0, 1.0)
	# EL TROZO VISIBLE: la cabeza sube primero y la cola la sigue, asi que el muelle entero "trepa"
	# por el cuerpo y sale por arriba. s = 0 es el suelo y s = 1 la coronilla.
	var cabeza: float = clampf(w / 0.62, 0.0, 1.0)
	var cola: float = clampf((w - 0.30) / 0.70, 0.0, 1.0)
	if cabeza - cola > 0.001:
		if pase != Pase.DELANTE:
			_tramo(ci, pie, alto, radio, w, cola, cabeza, false, vida)
		if pase != Pase.DETRAS:
			_tramo(ci, pie, alto, radio, w, cola, cabeza, true, vida)
	_cruces(ci, pie, alto, radio, w, semilla, pase, vida)


# Un punto de la espiral y su PROFUNDIDAD (-1 = al fondo, 1 = de cara). La elipse se aplasta en
# vertical porque la camara mira desde arriba a 45°: un aro alrededor de la cintura se ve ovalado.
static func _punto(pie: Vector2, alto: float, radio: float, w: float, s: float) -> Array:
	var ang: float = s * VUELTAS * TAU + w * 9.0
	# Un pelin mas estrecha arriba: sube hacia la cabeza, que es mas fina que la cintura.
	var r: float = radio * (1.0 - 0.28 * s)
	var p := Vector2(cos(ang) * r, -s * alto + sin(ang) * r * 0.32)
	return [pie + p, sin(ang)]


static func _tramo(ci: CanvasItem, pie: Vector2, alto: float, radio: float, w: float,
		desde: float, hasta: float, delante: bool, vida: float) -> void:
	var prev: Array = _punto(pie, alto, radio, w, desde)
	for i in range(1, SEGMENTOS + 1):
		var s: float = lerpf(desde, hasta, float(i) / float(SEGMENTOS))
		var cur: Array = _punto(pie, alto, radio, w, s)
		var prof: float = (float(prev[1]) + float(cur[1])) * 0.5
		if (prof >= 0.0) == delante:
			# Las puntas del muelle se afinan: sin eso parece un tubo cortado a cuchillo.
			var u: float = (s - desde) / maxf(hasta - desde, 0.001)
			var punta: float = clampf(minf(u, 1.0 - u) / 0.15, 0.25, 1.0)
			if delante:
				# El resplandor debajo y la linea encima: es lo que hace que brille y no sea un alambre.
				ci.draw_line(prev[0], cur[0], Color(VERDE.r, VERDE.g, VERDE.b, 0.22 * vida * punta), 7.0 * punta)
				ci.draw_line(prev[0], cur[0], Color(0.85, 1.0, 0.88, 0.95 * vida * punta), 2.6 * punta)
			else:
				ci.draw_line(prev[0], cur[0], Color(VERDE.r, VERDE.g, VERDE.b, 0.40 * vida * punta), 1.8 * punta)
		prev = cur


# LAS CRUCES: nacen del suelo alrededor de los pies, suben y se deshacen. Cada una sale a su hora (la
# semilla) para que no suban todas en fila. La mitad van por detras y la mitad por delante.
static func _cruces(ci: CanvasItem, pie: Vector2, alto: float, radio: float, w: float, semilla: float,
		pase: int, vida: float) -> void:
	for i in CRUCES:
		var atras: bool = i % 2 == 0
		if (pase == Pase.DELANTE and atras) or (pase == Pase.DETRAS and not atras):
			continue
		var h: float = absf(sin(semilla * 12.9898 + float(i) * 78.233))
		var sale: float = 0.05 + 0.45 * h
		var u: float = (w - sale) / 0.42
		if u <= 0.0 or u >= 1.0:
			continue
		var x: float = (fmod(h * 7.31 + float(i) * 0.37, 1.0) * 2.0 - 1.0) * radio * 1.25
		var p := pie + Vector2(x, -alto * (0.05 + 0.75 * u) + (-4.0 if atras else 4.0))
		var a: float = sin(u * PI) * vida * (0.55 if atras else 0.95)
		var t: float = 2.0 + 2.5 * h
		var col := Color(VERDE.r, VERDE.g, VERDE.b, a)
		ci.draw_line(p - Vector2(t, 0), p + Vector2(t, 0), col, 1.6)
		ci.draw_line(p - Vector2(0, t), p + Vector2(0, t), col, 1.6)
