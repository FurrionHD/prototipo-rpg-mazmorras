# ============================================================
#  tentaculos_pixel.gd  (class_name TentaculosPixel)
#  LOS TENTACULOS DE LA ANEMONA DEL ARRECIFE EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art): de quien le pegaba dependen el
#  sitio y lo que miden, asi que no caben en una hoja. Se pintan por celdas, en la rejilla de los sprites: se estiran ondulando hasta
#  el que le ha pegado, pican y se recogen. Verdes, con la punta rosa, como la anemona de su sprite.
# ============================================================
extends Node2D
class_name TentaculosPixel

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80
const CELDA: float = SpriteLienzo.UNIDADES_POR_CELDA
const BORDE := Color8(16, 44, 24)
const VERDE := Color8(68, 156, 80)
const CLARO := Color8(150, 220, 140)
const PUNTA := Color8(255, 140, 190)
const N := 3

var _o: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _t_estira: float = 0.12
var _t_queda: float = 0.1
var _t_recoge: float = 0.16
var _ritmo: float = 1.0
var _pica: EfectoPixel = null    # lo de donde pican: sale al llegar y se va con ellos
# (con setter: las hojas de ataques mueven el tiempo a mano, como en los demas efectos)
var _t: float = 0.0:
	set(v):
		_t = v
		queue_redraw()
		if is_instance_valid(_pica):
			_pica._t = _t - _t_estira


static func lanzar(padre: Node, desde: Vector2, hasta: Vector2, t_estira: float, t_queda: float, t_recoge: float, espera: float, ritmo: float) -> TentaculosPixel:
	if padre == null:
		return null
	var e := TentaculosPixel.new()
	e._o = desde
	e._hasta = hasta
	e._t_estira = t_estira
	e._t_queda = t_queda
	e._t_recoge = t_recoge
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(e)
	e._pica = EfectoPixel.lanzar(e, "slime", "pica", hasta, 0, null, 0.0, -1.0, e._ritmo)
	if e._pica != null:
		e._pica.set_process(false)   # (lo mueve este nodo: ver _t)
		e._pica._t = e._t - t_estira
	return e


func duracion() -> float:
	var total: float = _t_estira + _t_queda + _t_recoge
	if _pica != null:
		total = maxf(total, _t_estira + _pica.duracion())
	return total


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()


func _draw() -> void:
	if _t < 0.0:
		return
	var sale: float = clampf(_t / maxf(_t_estira, 0.001), 0.0, 1.0)
	if _t >= _t_estira + _t_queda + _t_recoge:
		return
	if _t > _t_estira + _t_queda:
		sale = 1.0 - clampf((_t - _t_estira - _t_queda) / maxf(_t_recoge, 0.001), 0.0, 1.0)
	var eje: Vector2 = _hasta - _o
	var largo: float = eje.length()
	if largo < 1.0 or sale <= 0.0:
		return
	var lado: Vector2 = eje.orthogonal() / largo
	var pasos: int = maxi(2, roundi(largo / CELDA))
	var hechos: int = int(float(pasos) * sale)
	var onda_t: float = _t * 22.0
	# de atras a delante: primero todos los bordes, encima el verde y su luz; asi no se cortan unos a otros
	for capa in 3:
		for k in N:
			var lat: float = float(k - 1)
			for i in hechos + 1:
				var u: float = float(i) / float(pasos)
				var onda: float = sin(u * 9.0 - onda_t + float(k) * 2.0) * 4.0 * CELDA * sin(u * PI)
				var p: Vector2 = _o + eje * u + lado * (onda + lat * 5.0 * CELDA * (1.0 - u))
				var g: int = roundi(2.0 * (1.0 - u * 0.55))
				var c: Vector2 = (p / CELDA).floor()
				if capa == 0:
					_celdas(c, g + 1, BORDE)
				elif capa == 1:
					_celdas(c, g, PUNTA if i == hechos else VERDE)
				elif i != hechos:
					_celdas(c + Vector2(0, -1), 0, CLARO)


func _celdas(c: Vector2, media: int, col: Color) -> void:
	draw_rect(Rect2((c.x - media) * CELDA, (c.y - media) * CELDA, float(media * 2 + 1) * CELDA, float(media * 2 + 1) * CELDA), col)
