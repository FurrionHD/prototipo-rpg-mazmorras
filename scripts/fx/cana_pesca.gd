# ============================================================
#  cana_pesca.gd  (class_name CanaPesca)
#  LA CAÑA DEL JUGADOR al pescar: en la mano, apuntando a donde tiras, con su sedal y su corcho.
#
#  Mismo dibujo que las cañas del muelle (PuebloSprites._cana, le encantaron): pixel a pixel, mango
#  oscuro y grueso, vara clara y fina hacia la punta con una comba hacia arriba, carrete gris, sedal
#  blanquecino semitransparente con su comba y corcho rojo sobre blanco con la onda en el agua. Los
#  mismos colores, copiados a proposito: si se toca uno, tocar el otro.
#
#  No se hornea: la caña gira con la mira (angulo continuo) y el sedal va de la punta al corcho, asi
#  que se pinta en _draw con rectangulos de 1 px, que a la escala del mundo son los pixeles del muelle.
#
#  DOS NODOS, porque van a alturas distintas: la CAÑA ('parte' = VARA) se ordena contra el cuerpo
#  (delante, o detras si miras hacia arriba), y el SEDAL con el corcho ('parte' = SEDAL) va con el agua.
# ============================================================
extends Node2D
class_name CanaPesca

enum Parte { VARA, SEDAL }

const MANGO := Color(0.20, 0.13, 0.08)
const VARA := Color(0.66, 0.54, 0.32)
const CARRETE := Color(0.55, 0.55, 0.58)
const CARRETE_EJE := Color(0.20, 0.20, 0.22)
const HILO := Color(0.88, 0.88, 0.85, 0.65)
const ONDA := Color(0.80, 0.90, 0.95, 0.45)
const CORCHO_ROJO := Color(0.85, 0.15, 0.12)
const CORCHO_BLANCO := Color(0.95, 0.95, 0.92)

# Lo que la caña AVANZA y SUBE en pantalla desde la mano. Del muelle: 30 hacia fuera y 22 arriba.
const AVANCE := 26.0
const SUBIDA := 20.0

var parte: int = Parte.VARA
var base: Vector2 = Vector2.ZERO        # la mano, en coordenadas locales del padre
var dir: Vector2 = Vector2.DOWN         # hacia donde apunta (la mira), en el suelo
var corcho: Vector2 = Vector2.INF       # donde esta el corcho; INF = sin lanzar (solo la caña)
var vuelo: float = 1.0                  # < 1: el sedal va por el aire (el lanzamiento)
var arco_alto: float = 40.0             # lo alto del arco del lanzamiento
var color_hilo: Color = HILO


# DONDE ACABA LA CAÑA. Lo necesita tambien el charco, para sacar el sedal de ahi.
static func punta(p_base: Vector2, p_dir: Vector2) -> Vector2:
	var d: Vector2 = p_dir.normalized() if p_dir != Vector2.ZERO else Vector2.DOWN
	var t: Vector2 = p_base + Vector2(d.x * AVANCE, d.y * AVANCE) + Vector2(0.0, -SUBIDA)
	# Hacia la camara la caña apenas avanza en pantalla (sale hacia ti y sube a la vez) y se quedaria en
	# un muñon: como en el muelle, se abre de lado. Hacia el lado de la mano que la lleva.
	if d.y > 0.0:
		t.x += 12.0 * d.y * (1.0 if d.x >= 0.0 else -1.0)
		t.y += 6.0 * d.y
	return t


# Detras del cuerpo cuando miras hacia arriba (N, NE, NO): la punta asoma por encima de la cabeza.
static func va_detras(p_dir: Vector2) -> bool:
	return SpriteLienzo.dir8(p_dir) in [3, 4, 5]


# La mano con la que se sujeta: la que queda del lado de la camara, para que la caña no nazca de
# dentro del cuerpo. Mirando al oeste es la izquierda.
static func mano_izquierda(p_dir: Vector2) -> bool:
	return SpriteLienzo.dir8(p_dir) in [5, 6, 7]


func actualizar() -> void:
	if parte == Parte.VARA:
		z_as_relative = false
		z_index = Game.Z_PERSONAJES + (-1 if va_detras(dir) else 2600)
	queue_redraw()


func _draw() -> void:
	if parte == Parte.VARA:
		_pintar_vara()
	elif corcho != Vector2.INF:
		_pintar_sedal()


# Un pixel del mundo. Los del hilo se apuntan para no pisar dos veces el mismo: con alfa, un pixel
# repetido sale mas opaco y el sedal se veria a trozos.
var _hechos: Dictionary = {}

func _px(p: Vector2, c: Color) -> void:
	var k := Vector2i(floori(p.x), floori(p.y))
	if c.a < 1.0:
		if _hechos.has(k):
			return
		_hechos[k] = true
	draw_rect(Rect2(Vector2(k), Vector2.ONE), c)


func _pintar_vara() -> void:
	_hechos.clear()
	var b: Vector2 = base.round()
	var p: Vector2 = punta(b, dir)
	var m: int = 60
	for i in m + 1:
		var t: float = float(i) / float(m)
		var q: Vector2 = b.lerp(p, t) + Vector2(0, -1) * sin(t * PI) * 3.0
		var col: Color = MANGO if t < 0.25 else VARA
		_px(q, col)
		if t < 0.55:
			_px(q + Vector2(1, 0), col.darkened(0.3))
	var c: Vector2 = b.lerp(p, 0.12)
	draw_rect(Rect2(Vector2(floori(c.x) - 1, floori(c.y) - 1), Vector2(3, 3)), CARRETE)
	_px(c, CARRETE_EJE)


func _pintar_sedal() -> void:
	_hechos.clear()
	var ini: Vector2 = punta(base.round(), dir)
	var fin: Vector2 = ini.lerp(corcho, clampf(vuelo, 0.0, 1.0))
	var largo: float = ini.distance_to(fin)
	var n: int = maxi(8, int(largo * 1.5))
	if vuelo < 1.0:
		# Por el aire: el arco de siempre (parabola de tres puntos), subiendo con el vuelo.
		var alto: Vector2 = (ini + fin) * 0.5 + Vector2(0.0, -arco_alto * clampf(vuelo, 0.2, 1.0))
		for i in n + 1:
			var u: float = float(i) / float(n)
			_px(ini.lerp(alto, u).lerp(alto.lerp(fin, u), u), color_hilo)
	else:
		# En el agua: recto con su comba, como en el muelle, y la onda alrededor del corcho.
		for i in n + 1:
			var t: float = float(i) / float(n)
			_px(ini.lerp(fin, t) + Vector2(0.0, sin(t * PI) * 3.0), color_hilo)
		for yy in range(-3, 4):
			for xx in range(-7, 8):
				var e: float = pow(float(xx) / 6.5, 2.0) + pow(float(yy) / 2.6, 2.0)
				if e <= 1.0 and e >= 0.55:
					_px(Vector2(floori(fin.x) + xx, floori(fin.y) + 1 + yy), ONDA)
	var fx: int = floori(fin.x)
	var fy: int = floori(fin.y)
	draw_rect(Rect2(Vector2(fx - 1, fy - 2), Vector2(3, 2)), CORCHO_ROJO)
	draw_rect(Rect2(Vector2(fx - 1, fy), Vector2(3, 1)), CORCHO_BLANCO)
