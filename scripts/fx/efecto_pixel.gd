# ============================================================
#  efecto_pixel.gd  (class_name EfectoPixel)
#  UN EFECTO EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art): una hoja de marcos, en la misma rejilla que los sprites,
#  y nada de draw_*. Lleva hasta dos capas: 's' por el suelo, debajo de los cuerpos, y 'a' encima de ellos. Las hojas las saca
#  tools/sprites_sdf/<enemigo>_efectos_pixel.py --hornear y sus medidas estan en EfectosPixelDatos.
#  'seguir' = va pegado a ese nodo (la estela del que vuela); sin el, se queda donde se puso (lo que cae en el suelo).
# ============================================================
extends Node2D
class_name EfectoPixel

const _DATOS := preload("res://scripts/fx/efectos_pixel_datos.gd")
const CARPETA := "res://assets/sprites/efectos/%s/%s_%s.png"
const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80

var _fps: float = 12.0
var _n: int = 1
var _bucle: bool = false
var _t: float = 0.0
var _capas: Array[Sprite2D] = []
var _sigue: Node2D = null


# 'dir' = hacia donde va, de 0 a 7 como SpriteLienzo.dir8 (0 = S, 1 = SE, 2 = E...). 'dura' > 0 la estira a ese tiempo.
# 'espera' = segundos hasta que empieza a verse. Null si no existe la hoja.
static func lanzar(padre: Node, enemigo: String, nombre: String, pos: Vector2, dir: int = 0, seguir: Node2D = null,
		espera: float = 0.0, dura: float = -1.0, ritmo: float = 1.0) -> EfectoPixel:
	var d: Dictionary = (_DATOS.HOJAS.get(enemigo, {}) as Dictionary).get(nombre, {})
	if padre == null or d.is_empty():
		return null
	var e := EfectoPixel.new()
	e._n = int(d["n"])
	e._bucle = bool(d["bucle"])
	e._fps = float(d["fps"]) * maxf(ritmo, 0.05)
	if dura > 0.0:
		e._fps = float(e._n) / dura
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
	return e


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
	add_child(s)
	_capas.append(s)


func _process(delta: float) -> void:
	_t += delta
	if _sigue != null:
		if not is_instance_valid(_sigue):
			queue_free()
			return
		global_position = _sigue.global_position
	if not _bucle and _t * _fps >= float(_n):
		queue_free()
		return
	_poner_marco()


func _poner_marco() -> void:
	var ver: bool = _t >= 0.0
	var m: int = posmod(int(_t * _fps), _n) if ver else 0
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
	_poner_marco()
