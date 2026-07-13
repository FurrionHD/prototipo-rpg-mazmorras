# ============================================================
#  dungeon_generator.gd
#  Traza el PISO sobre una rejilla de celdas: salas rectangulares sin solaparse,
#  unidas por pasillos en L. Trabaja con DATOS puros (no crea ni un nodo): quien
#  levanta la geometria es dungeon_floor.gd.
#
#  La SEMILLA lo hace determinista: el mismo piso da siempre el mismo mapa (y al
#  bajar por la escalera sale otro). Este es el esqueleto del generador procedural
#  de verdad: cuando toque, se cambia el trazado y todo lo demas sigue igual.
#
#  ZONAS: cada sala y cada pasillo es una zona. Cada celda de suelo pertenece a UNA
#  sola zona (si un pasillo cruza una sala, esas celdas siguen siendo de la sala).
#  Las zonas son las que paren monstruos: de sus paredes salen los bichos.
# ============================================================

extends RefCounted
class_name DungeonGenerator

const CELDA := 32  # px de lado de una celda (= el tamaño del jugador)

# --- Resultado de la generacion ---
var ancho: int = 0
var alto: int = 0
var solido: PackedByteArray = PackedByteArray()      # 1 = roca, 0 = suelo pisable
var zona_de: PackedInt32Array = PackedInt32Array()   # zona de cada celda; -1 = roca
var zonas: Array[Dictionary] = []                    # {tipo, rect, celdas}
var salas: Array[Rect2i] = []                        # solo las salas (para colocar puerta/escalera)
var semilla: int = 0

var _rng := RandomNumberGenerator.new()


# Traza el piso entero. Los tamaños van en CELDAS.
func generar(ancho_celdas: int, alto_celdas: int, semilla_: int,
		max_salas: int = 14, sala_min: Vector2i = Vector2i(8, 6),
		sala_max: Vector2i = Vector2i(18, 12), ancho_pasillo: int = 3) -> void:
	ancho = maxi(16, ancho_celdas)
	alto = maxi(16, alto_celdas)
	semilla = semilla_
	_rng.seed = semilla

	solido = PackedByteArray()
	solido.resize(ancho * alto)
	solido.fill(1)  # todo roca; luego se excava
	zona_de = PackedInt32Array()
	zona_de.resize(ancho * alto)
	zona_de.fill(-1)
	zonas.clear()
	salas.clear()

	_trazar_salas(max_salas, sala_min, sala_max)
	_trazar_pasillos(ancho_pasillo)
	_calcular_rects_de_zona()


# --- SALAS: se tiran al azar y se descartan las que se solapan (con margen) ---
func _trazar_salas(max_salas: int, sala_min: Vector2i, sala_max: Vector2i) -> void:
	var intentos: int = max_salas * 30
	for _i in range(intentos):
		if salas.size() >= max_salas:
			break
		var w: int = _rng.randi_range(sala_min.x, sala_max.x)
		var h: int = _rng.randi_range(sala_min.y, sala_max.y)
		# Margen de 2 celdas contra el borde: el piso queda siempre cerrado por roca.
		if ancho - w - 4 < 2 or alto - h - 4 < 2:
			continue
		var r := Rect2i(_rng.randi_range(2, ancho - w - 3), _rng.randi_range(2, alto - h - 3), w, h)
		# Separacion minima entre salas: si se tocan, no hay pared entre ellas (y sin
		# pared no hay parto). grow(2) = deja al menos 2 celdas de roca de por medio.
		var choca: bool = false
		for otra in salas:
			if otra.grow(2).intersects(r):
				choca = true
				break
		if choca:
			continue
		salas.append(r)
		var idx: int = _nueva_zona("sala", r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_excavar(Vector2i(x, y), idx)


# --- PASILLOS: unen cada sala con la siguiente en L (primero un eje, luego el otro) ---
func _trazar_pasillos(ancho_pasillo: int) -> void:
	if salas.size() < 2:
		return
	# Ordenadas de izquierda a derecha: el recorrido del piso queda legible y no hay
	# salas huerfanas (todas quedan encadenadas).
	var orden: Array[Rect2i] = salas.duplicate()
	orden.sort_custom(func(a: Rect2i, b: Rect2i): return a.get_center().x < b.get_center().x)

	for i in range(1, orden.size()):
		var a: Vector2i = orden[i - 1].get_center()
		var b: Vector2i = orden[i].get_center()
		var idx: int = _nueva_zona("pasillo", Rect2i())
		if _rng.randf() < 0.5:
			_cavar_h(a.x, b.x, a.y, ancho_pasillo, idx)
			_cavar_v(a.y, b.y, b.x, ancho_pasillo, idx)
		else:
			_cavar_v(a.y, b.y, a.x, ancho_pasillo, idx)
			_cavar_h(a.x, b.x, b.y, ancho_pasillo, idx)


# Tramo horizontal de 'grosor' celdas centrado en la fila y.
func _cavar_h(x0: int, x1: int, y: int, grosor: int, zona: int) -> void:
	var medio: int = grosor / 2
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for d in range(-medio, grosor - medio):
			_excavar(Vector2i(x, y + d), zona)


# Tramo vertical de 'grosor' celdas centrado en la columna x.
func _cavar_v(y0: int, y1: int, x: int, grosor: int, zona: int) -> void:
	var medio: int = grosor / 2
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for d in range(-medio, grosor - medio):
			_excavar(Vector2i(x + d, y), zona)


# Convierte una celda en suelo y la asigna a una zona. Respeta el borde de roca del
# mapa y NO roba celdas: la primera zona que excava una celda se la queda (por eso un
# pasillo que cruza una sala no le quita sus celdas).
func _excavar(c: Vector2i, zona: int) -> void:
	if c.x < 1 or c.y < 1 or c.x >= ancho - 1 or c.y >= alto - 1:
		return
	var i: int = c.y * ancho + c.x
	solido[i] = 0
	if zona_de[i] == -1:
		zona_de[i] = zona
		(zonas[zona]["celdas"] as Array).append(c)


func _nueva_zona(tipo: String, rect: Rect2i) -> int:
	zonas.append({"tipo": tipo, "rect": rect, "celdas": [] as Array})
	return zonas.size() - 1


# Los pasillos no nacen con rect (se sabe al acabar de cavar): se lo calculamos aqui.
# Tambien recorta el rect de las salas por si un pasillo les robo alguna celda.
func _calcular_rects_de_zona() -> void:
	for z in zonas:
		var celdas: Array = z["celdas"]
		if celdas.is_empty():
			z["rect"] = Rect2i()
			continue
		var r := Rect2i(celdas[0], Vector2i.ONE)
		for c in celdas:
			r = r.expand(c).expand(c + Vector2i.ONE)
		z["rect"] = r


# ------------------------------------------------------------
#  CONSULTAS (las usa dungeon_floor para levantar el piso)
# ------------------------------------------------------------

func es_solido(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= ancho or c.y >= alto:
		return true  # fuera del mapa = roca
	return solido[c.y * ancho + c.x] == 1


func es_suelo(c: Vector2i) -> bool:
	return not es_solido(c)


# A que zona pertenece una celda (-1 = roca o fuera del mapa).
func zona_en(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= ancho or c.y >= alto:
		return -1
	return zona_de[c.y * ancho + c.x]


# Centro de la celda en pixeles (donde se planta un bicho o el jugador).
func centro_px(c: Vector2i) -> Vector2:
	return Vector2(float(c.x) + 0.5, float(c.y) + 0.5) * float(CELDA)


func tam_px() -> Vector2:
	return Vector2(float(ancho), float(alto)) * float(CELDA)


# CELDAS DE PARTO de una zona: pares {pared, suelo} donde 'pared' es roca pegada a una
# celda de suelo de la zona. De ahi salen los monstruos (la pared los engendra y caen
# en la celda de suelo contigua).
func celdas_de_parto(zona: int) -> Array:
	var out: Array = []
	if zona < 0 or zona >= zonas.size():
		return out
	var vistas: Dictionary = {}  # una misma pared puede tocar 2 celdas de suelo: no la repetimos
	for c in (zonas[zona]["celdas"] as Array):
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var pared: Vector2i = c + d
			if es_solido(pared) and not vistas.has(pared):
				vistas[pared] = true
				out.append({"pared": pared, "suelo": c})
	return out


# --- Fusion en TRAMOS horizontales (para no crear un nodo por celda) ---

# Roca VISIBLE: la que toca suelo (en 8 direcciones). El resto de la roca es relleno
# que el jugador no puede alcanzar nunca, asi que ni se dibuja ni tiene colision.
func muros_fusionados() -> Array[Rect2i]:
	var mapa := func(c: Vector2i) -> bool:
		return es_solido(c) and _toca_suelo(c)
	return _fusionar(mapa)


func suelos_fusionados() -> Array[Rect2i]:
	return _fusionar(func(c: Vector2i) -> bool: return es_suelo(c))


func _toca_suelo(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and es_suelo(c + Vector2i(dx, dy)):
				return true
	return false


# Recorre la rejilla por filas y junta las celdas contiguas que cumplen 'cumple' en un
# solo Rect2i. Un piso de 6000 celdas baja asi a unos cientos de nodos.
func _fusionar(cumple: Callable) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for y in range(alto):
		var x: int = 0
		while x < ancho:
			if not cumple.call(Vector2i(x, y)):
				x += 1
				continue
			var x0: int = x
			while x < ancho and cumple.call(Vector2i(x, y)):
				x += 1
			out.append(Rect2i(x0, y, x - x0, 1))
	return out
