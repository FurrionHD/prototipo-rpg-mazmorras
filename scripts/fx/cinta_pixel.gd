# ============================================================
#  cinta_pixel.gd  (class_name CintaPixel)
#  UNA O VARIAS CINTAS EN PIXEL ART ENTRE DOS PUNTOS CUALESQUIERA (04/11/2026, memoria efectos-a-pixel-art): el chorro del Geiser, los hilos de
#  Chupar... Lo que miden lo dice cada pelea, asi que no caben en una hoja: se pintan por celdas, en la rejilla de los sprites y con tres tonos
#  (borde, cuerpo, luz). Crecen de 'desde' a 'hasta', aguantan y se van a trama. Con 'bolitas', unas bolas de luz corren por ellas hacia 'hasta'.
# ============================================================
extends Node2D
class_name CintaPixel

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80
const CELDA: float = SpriteLienzo.UNIDADES_POR_CELDA
const BAYER: Array = [0.03, 0.53, 0.16, 0.66, 0.78, 0.28, 0.91, 0.41, 0.22, 0.72, 0.09, 0.59, 0.97, 0.47, 0.84, 0.34]

var _a: Vector2 = Vector2.ZERO
var _b: Vector2 = Vector2.ZERO
var _n: int = 1
var _separa: float = 8.0      # (mundo) cuanto se abren entre si a mitad de camino
var _grueso: float = 2.0      # media anchura, en celdas, al salir
var _afina: float = 0.4       # lo que adelgaza al llegar (0 = nada)
var _arco: float = 0.0        # (mundo) lo que sube a mitad de camino
var _onda: float = 1.2        # (mundo) lo que se mecen
var _pal: PackedColorArray = PackedColorArray()   # [borde, cuerpo, luz]
var _luz_bola: Color = Color.WHITE
var _bolitas: bool = false
var _t_crece: float = 0.3
var _t_vive: float = 0.6
var _t_va: float = 0.4
var _ritmo: float = 1.0
# (con setter: las hojas de ataques mueven el tiempo a mano, como en los demas efectos)
var _t: float = 0.0:
	set(v):
		_t = v
		queue_redraw()


static func lanzar(padre: Node, desde: Vector2, hasta: Vector2, pal: PackedColorArray, t_crece: float, t_vive: float, t_va: float,
		espera: float = 0.0, ritmo: float = 1.0) -> CintaPixel:
	if padre == null:
		return null
	var c := CintaPixel.new()
	c._a = desde
	c._b = hasta
	c._pal = pal
	c._t_crece = maxf(t_crece, 0.01)
	c._t_vive = t_vive
	c._t_va = maxf(t_va, 0.01)
	c._ritmo = maxf(ritmo, 0.05)
	c._t = -maxf(espera, 0.0)
	c.z_as_relative = false
	c.z_index = Z_ENCIMA
	c.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(c)
	return c


# Cuantas y como: 'n' cintas abiertas 'separa' a mitad de camino; 'grueso' en celdas; 'arco' lo que suben; 'onda' lo que se mecen.
func forma(n: int, separa: float, grueso: float, afina: float, arco: float, onda: float) -> CintaPixel:
	_n = maxi(n, 1)
	_separa = separa
	_grueso = grueso
	_afina = afina
	_arco = arco
	_onda = onda
	return self


func con_bolitas(luz: Color) -> CintaPixel:
	_bolitas = true
	_luz_bola = luz
	return self


func duracion() -> float:
	return _t_crece + _t_vive + _t_va


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()


func _punto(k: int, u: float) -> Vector2:
	var eje: Vector2 = _b - _a
	var lado: Vector2 = eje.orthogonal().normalized()
	var lat: float = (float(k) - float(_n - 1) * 0.5) * _separa * sin(PI * u)
	var mece: float = sin(u * 12.0 + _t * 9.6 + float(k)) * _onda
	return _a + eje * u + lado * (lat + mece) - Vector2(0.0, _arco * sin(PI * u))


func _draw() -> void:
	if _t < 0.0 or _pal.size() < 3:
		return
	var crece: float = clampf(_t / _t_crece, 0.0, 1.0)
	var va: float = clampf((_t - _t_crece - _t_vive) / _t_va, 0.0, 1.0)
	var largo: float = _a.distance_to(_b) + _arco
	var pasos: int = maxi(4, roundi(largo / CELDA))
	var hechos: int = int(float(pasos) * crece)
	# por capas: primero todos los bordes, luego el cuerpo y luego la luz (si no, cada celda le pisa el relleno a la anterior)
	for capa in 3:
		for k in _n:
			for i in hechos + 1:
				var u: float = float(i) / float(pasos)
				var c: Vector2 = (_punto(k, u) / CELDA).floor()
				# se va a trama de 2 celdas
				if va > 0.0 and BAYER[(int(c.y / 2.0) & 3) * 4 + (int(c.x / 2.0) & 3)] < va:
					continue
				var g: int = roundi(_grueso * (1.0 - u * _afina))
				match capa:
					0: _celdas(c, g + 1, _pal[0])
					1: _celdas(c, g, _pal[1])
					2:
						if g >= 1:
							_celdas(c + Vector2(0, -1), maxi(g - 1, 0), _pal[2])
	if not _bolitas or va >= 1.0 or crece < 1.0:
		return
	for k in _n:
		for j in 2:
			var u2: float = fmod(_t * 0.9 + float(j) * 0.5 + float(k) * 0.17, 1.0)
			var c2: Vector2 = (_punto(k, u2) / CELDA).floor()
			_celdas(c2, 1, _pal[1])
			_celdas(c2, 0, _luz_bola)


func _celdas(c: Vector2, media: int, col: Color) -> void:
	draw_rect(Rect2((c.x - media) * CELDA, (c.y - media) * CELDA, float(media * 2 + 1) * CELDA, float(media * 2 + 1) * CELDA), col)
