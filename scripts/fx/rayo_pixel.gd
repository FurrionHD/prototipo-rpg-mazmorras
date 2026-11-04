# ============================================================
#  rayo_pixel.gd  (class_name RayoPixel)
#  UN RAYO EN PIXEL ART ENTRE DOS PUNTOS CUALESQUIERA (04/11/2026, memoria efectos-a-pixel-art): lo que mide lo dice cada pelea, asi
#  que no cabe en una hoja. Se pinta por celdas, en la misma rejilla que los sprites y con su paleta cerrada: se traza de un extremo
#  al otro, se enciende, se adelgaza y se va, con un destello macizo en cada punta. Los bordes (cian y magenta en la Mirada estelar)
#  son opcionales. Vale para lo que une dos puntos que cambian (Constelacion, Mirada; luego hilos, arcos...).
# ============================================================
extends Node2D
class_name RayoPixel

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80
const CELDA: float = SpriteLienzo.UNIDADES_POR_CELDA

var _a: Vector2 = Vector2.ZERO
var _b: Vector2 = Vector2.ZERO
var _grueso: float = 2.6          # media anchura, en celdas
var _pal: PackedColorArray = PackedColorArray()   # [cuerpo, medio, nucleo]
var _borde_1: Color = Color(0, 0, 0, 0)
var _borde_2: Color = Color(0, 0, 0, 0)
var _t_traza: float = 0.14
var _t_vive: float = 0.35
var _t_apaga: float = 0.3
var _ritmo: float = 1.0
# (con setter: las hojas de ataques mueven el tiempo a mano, como en los demas efectos)
var _t: float = 0.0:
	set(v):
		_t = v
		queue_redraw()


# 'desde' y 'hasta' en coordenadas de mundo. 'pal' = los tres tonos de fuera a dentro.
static func lanzar(padre: Node, desde: Vector2, hasta: Vector2, grueso: float, pal: PackedColorArray, t_traza: float, t_vive: float,
		t_apaga: float, espera: float = 0.0, ritmo: float = 1.0, borde_1: Color = Color(0, 0, 0, 0), borde_2: Color = Color(0, 0, 0, 0)) -> RayoPixel:
	if padre == null:
		return null
	var r := RayoPixel.new()
	r._a = desde
	r._b = hasta
	r._grueso = grueso
	r._pal = pal
	r._t_traza = t_traza
	r._t_vive = t_vive
	r._t_apaga = t_apaga
	r._ritmo = maxf(ritmo, 0.05)
	r._borde_1 = borde_1
	r._borde_2 = borde_2
	r._t = -maxf(espera, 0.0)
	r.z_as_relative = false
	r.z_index = Z_ENCIMA
	r.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(r)
	return r


func duracion() -> float:
	return _t_traza + _t_vive + _t_apaga


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()


func _draw() -> void:
	if _t < 0.0:
		return
	var traza: float = clampf(_t / maxf(_t_traza, 0.001), 0.0, 1.0)
	var apaga: float = clampf((_t - _t_traza - _t_vive) / maxf(_t_apaga, 0.001), 0.0, 1.0)
	# fino mientras se traza; se enciende entero y se adelgaza al apagarse
	var g: float = _grueso * (0.45 + 0.55 * traza) * (1.0 - apaga)
	if g < 0.4:
		return
	_tira(traza, g)
	var d: float = (_grueso + 3.0) * (1.0 - apaga)
	_destello(_a, d)
	if traza >= 1.0:
		_destello(_b, d + 2.0)


# El rayo, celda a celda por su eje mayor: en cada paso, una columna (o fila) con sus tonos de fuera a dentro.
func _tira(traza: float, g: float) -> void:
	var de: Vector2 = _celda_de(_a)
	var a: Vector2 = _celda_de(_a.lerp(_b, traza))
	var v: Vector2 = a - de
	var pasos: int = maxi(1, roundi(maxf(absf(v.x), absf(v.y))))
	var eje_x: bool = absf(v.x) >= absf(v.y)
	# un rayo en diagonal mide mas celdas de lado que de verdad: se abre lo que toca para que no adelgace
	var abre: float = v.length() / float(pasos)
	var m: float = g * abre
	# [desde, hasta, color]: celdas a cada lado del eje, de fuera a dentro (los bordes de color asoman uno a cada lado)
	var capas: Array = [[-floori(m), floori(m), _pal[0]]]
	if _borde_1.a > 0.0:
		capas.append([ceili(m * 0.5), floori(m), _borde_1])
		capas.append([-floori(m), -ceili(m * 0.5), _borde_2])
	capas.append([-floori(m * 0.55), floori(m * 0.55), _pal[1]])
	capas.append([-floori(m * 0.25), floori(m * 0.25), _pal[2]])
	for capa in capas:
		var desde: int = capa[0]
		var hasta: int = capa[1]
		var col: Color = capa[2]
		if hasta < desde:
			continue
		for i in pasos + 1:
			var p: Vector2 = (de + v * float(i) / float(pasos)).round()
			var r := Rect2(p.x * CELDA, (p.y + desde) * CELDA, CELDA, float(hasta - desde + 1) * CELDA) if eje_x \
				else Rect2((p.x + desde) * CELDA, p.y * CELDA, float(hasta - desde + 1) * CELDA, CELDA)
			draw_rect(r, col)


# Una estrella maciza de cuatro puntas (destello = estrella, ver la receta): brazos que se afilan y corazon blanco.
func _destello(pos: Vector2, r: float) -> void:
	var c: Vector2 = _celda_de(pos)
	var n: int = roundi(r)
	for k in range(-n, n + 1):
		var media: int = maxi(0, roundi((1.0 - absf(float(k)) / maxf(r, 1.0)) * 2.0))
		var col: Color = _pal[2] if absi(k) <= n / 2 else _pal[1]
		draw_rect(Rect2((c.x + k) * CELDA, (c.y - media) * CELDA, CELDA, float(media * 2 + 1) * CELDA), col)
		draw_rect(Rect2((c.x - media) * CELDA, (c.y + k) * CELDA, float(media * 2 + 1) * CELDA, CELDA), col)


# La celda de la rejilla del mundo en la que cae un punto (siempre la misma: el rayo no tiembla al moverse la camara).
func _celda_de(p: Vector2) -> Vector2:
	return (p / CELDA).floor()
