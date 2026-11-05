# ============================================================
#  efecto_pixel.gd  (class_name EfectoPixel)
#  UN EFECTO EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art): una hoja de marcos, en la misma rejilla que los sprites,
#  y nada de draw_*. Lleva hasta dos capas: 's' por el suelo, debajo de los cuerpos, y 'a' encima de ellos. Las hojas las saca
#  tools/sprites_sdf/<enemigo>_efectos_pixel.py --hornear y sus medidas estan en EfectosPixelDatos.
#  'seguir' = va pegado a ese nodo (la estela del que vuela); sin el, se queda donde se puso (lo que cae en el suelo).
#  'paleta' = tine la hoja: lo pintado en rojo puro 40/80/120/160/200 (los cuatro tonos y el borde) sale de esos cinco colores, lo
#  demas tal cual. Asi la misma hoja vale para el color de cada slime (ver SlimeAire.paleta_pixel).
# ============================================================
extends Node2D
class_name EfectoPixel

const _DATOS := preload("res://scripts/fx/efectos_pixel_datos.gd")
const CARPETA := "res://assets/sprites/efectos/%s/%s_%s.png"
const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80
const _TINTE := preload("res://scripts/fx/efecto_pixel_tinte.gdshader")

var _fps: float = 12.0
var _n: int = 1
var _bucle: bool = false
# (con setter: las hojas de ataques mueven el tiempo a mano, con _process parado, como en los demas efectos)
var _t: float = 0.0:
	set(v):
		_t = v
		_poner_marco()
var _capas: Array[Sprite2D] = []
var _sigue: Node2D = null
# Empieza este rato despues que los demas de su tanda (cada estrella de la Lluvia). Aparte de _t: las hojas de prueba mueven _t a mano.
var retardo: float = 0.0
var _corte: int = 0        # desde este marco va a _fps2 (lo que se seca, sin prisa)
var _fps2: float = 0.0
var _ritmo: float = 1.0     # SueloRoto lo escala en las embestidas, como en los demas efectos
var _paleta: PackedColorArray = PackedColorArray()
# LO QUE VIAJA ANTES DE LLEGAR (el escupitajo): mientras _t < 0, una bola que va en parabola de _v_desde a la posicion del efecto,
# con la fila de la hoja segun hacia donde va en cada momento. La distancia cambia en cada pelea: por eso la mueve el codigo.
var _bola: Sprite2D = null
var _bola_medida: Array = []
var _bola_n: int = 1
var _bola_filas: int = 1
var _bola_fps: float = 12.0
var _v_desde: Vector2 = Vector2.ZERO
var _v_hasta: Vector2 = Vector2.ZERO
var _v_alto: float = 0.0
var _v_dur: float = 0.0


# 'dir' = hacia donde va, de 0 a 7 como SpriteLienzo.dir8 (0 = S, 1 = SE, 2 = E...). 'dura' > 0 la estira a ese tiempo.
# 'espera' = segundos hasta que empieza a verse. Null si no existe la hoja.
static func lanzar(padre: Node, enemigo: String, nombre: String, pos: Vector2, dir: int = 0, seguir: Node2D = null,
		espera: float = 0.0, dura: float = -1.0, ritmo: float = 1.0, paleta: PackedColorArray = PackedColorArray()) -> EfectoPixel:
	var d: Dictionary = (_DATOS.HOJAS.get(enemigo, {}) as Dictionary).get(nombre, {})
	if padre == null or d.is_empty():
		return null
	var e := EfectoPixel.new()
	e._n = int(d["n"])
	e._bucle = bool(d["bucle"])
	e._fps = float(d["fps"]) * maxf(ritmo, 0.05)
	if dura > 0.0:
		e._fps = float(e._n) / dura
	e._corte = int(d.get("corte", 0))
	e._fps2 = float(d.get("fps2", 0.0)) * maxf(ritmo, 0.05)
	e._paleta = paleta
	e._t = -maxf(espera, 0.0)
	e._sigue = seguir
	e.position = seguir.global_position if seguir != null else pos
	e.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(e)
	var filas: int = int(d["filas"])
	var espejo: bool = filas > 1 and posmod(dir, 8) > 4
	var fila: int = 0
	if filas > 1:
		fila = 8 - posmod(dir, 8) if espejo else posmod(dir, 8)
	e._capa(enemigo, nombre, "s", d.get("s"), filas, fila, espejo, SueloRoto.Z_SUELO)
	e._capa(enemigo, nombre, "a", d.get("a"), filas, fila, espejo, Z_ENCIMA)
	e._poner_marco()
	e.set_meta("hoja", nombre)
	return e


# 'desde' y 'hasta' en coordenadas de mundo: 'dur' = lo que tarda (el efecto tiene que llevar esa misma espera).
func poner_vuelo(enemigo: String, nombre: String, desde: Vector2, hasta: Vector2, alto: float, dur: float) -> void:
	var d: Dictionary = (_DATOS.HOJAS.get(enemigo, {}) as Dictionary).get(nombre, {})
	var medida = d.get("a")
	if d.is_empty() or medida == null:
		return
	var tex: Texture2D = load(CARPETA % [enemigo, nombre, "a"])
	if tex == null:
		return
	_bola_medida = medida
	_bola_n = int(d["n"])
	_bola_filas = int(d["filas"])
	_bola_fps = float(d["fps"])
	_v_desde = desde
	_v_hasta = hasta
	_v_alto = alto
	_v_dur = maxf(dur, 0.01)
	_bola = Sprite2D.new()
	_bola.texture = tex
	_bola.centered = false
	_bola.hframes = _bola_n
	_bola.vframes = _bola_filas
	_bola.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bola.scale = Vector2.ONE * SpriteLienzo.UNIDADES_POR_CELDA
	_bola.top_level = true
	_bola.z_as_relative = false
	_bola.z_index = Z_ENCIMA
	if _capas.size() > 0 and _capas[0].material != null:
		_bola.material = _capas[0].material
	elif _paleta.size() >= 5:
		var m := ShaderMaterial.new()
		m.shader = _TINTE
		for i in 5:
			m.set_shader_parameter("p%d" % i, _paleta[i])
		_bola.material = m
	add_child(_bola)
	_poner_marco()


func _poner_bola() -> void:
	var u: float = (_t + _v_dur) / _v_dur
	_bola.visible = u >= 0.0 and u < 1.0
	if not _bola.visible:
		return
	var p: Vector2 = _v_desde.lerp(_v_hasta, u) + Vector2(0.0, -_v_alto * 4.0 * u * (1.0 - u))
	var vel: Vector2 = (_v_hasta - _v_desde) + Vector2(0.0, -_v_alto * 4.0 * (1.0 - 2.0 * u))
	var dir: int = SpriteLienzo.dir8(vel) if vel.length_squared() > 0.01 else 0
	var espejo: bool = _bola_filas > 1 and dir > 4
	var fila: int = 0
	if _bola_filas > 1:
		fila = 8 - dir if espejo else dir
	_bola.flip_h = espejo
	_bola.frame_coords = Vector2i(posmod(int((_t + _v_dur) * _bola_fps), _bola_n), fila)
	var ox: float = float(_bola_medida[0]) - float(_bola_medida[2]) if espejo else float(_bola_medida[2])
	_bola.offset = -Vector2(ox, float(_bola_medida[3]))
	_bola.global_position = p


func _capa(enemigo: String, nombre: String, suf: String, medida, filas: int, fila: int, espejo: bool, z: int) -> void:
	if medida == null:
		return
	var tex: Texture2D = load(CARPETA % [enemigo, nombre, suf])
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.hframes = _n
	s.vframes = filas
	s.frame_coords = Vector2i(0, fila)
	s.flip_h = espejo
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * SpriteLienzo.UNIDADES_POR_CELDA
	var ox: float = float(medida[0]) - float(medida[2]) if espejo else float(medida[2])
	s.offset = -Vector2(ox, float(medida[3]))
	s.z_as_relative = false
	s.z_index = z
	if _paleta.size() >= 5:
		var m := ShaderMaterial.new()
		m.shader = _TINTE
		for i in 5:
			m.set_shader_parameter("p%d" % i, _paleta[i])
		s.material = m
	add_child(s)
	_capas.append(s)


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _sigue != null:
		if not is_instance_valid(_sigue):
			queue_free()
			return
		global_position = _sigue.global_position
	if not _bucle and _marco_de(_t) >= _n:
		queue_free()
		return
	_poner_marco()


func _marco_de(t_total: float) -> int:
	var t: float = t_total - retardo
	if t < 0.0:
		return -1
	if _corte > 0 and _fps2 > 0.0 and t * _fps >= float(_corte):
		return _corte + int((t - float(_corte) / _fps) * _fps2)
	return int(t * _fps)


func _poner_marco() -> void:
	if _bola != null:
		_poner_bola()
	var bruto: int = _marco_de(_t)
	var ver: bool = bruto >= 0 and _t >= 0.0 and (_bucle or bruto < _n)
	var m: int = posmod(bruto, _n) if ver else 0
	for s in _capas:
		s.visible = ver
		s.frame_coords = Vector2i(m, s.frame_coords.y)


# Para las hojas de prueba: el marco que tiene ahora, y cuantas capas lleva.
func marco_actual() -> int:
	return _capas[0].frame_coords.x if not _capas.is_empty() else -1


func num_capas() -> int:
	return _capas.size()


func avanzar_a(t: float) -> void:
	_t = t


func duracion() -> float:
	if _corte > 0 and _fps2 > 0.0:
		return retardo + float(_corte) / _fps + float(_n - _corte) / _fps2
	return retardo + float(_n) / _fps
