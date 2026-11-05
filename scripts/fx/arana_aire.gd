# ============================================================
#  arana_aire.gd  (class_name AranaAire)
#  LO DE LAS ARANAS MUTANTES en el mapa (03/11/2026: la Tejedora y la Tormentosa; memoria arana-mutante), EN PIXEL ART (04/11/2026, memoria
#  efectos-a-pixel-art): sus hojas salen de tools/sprites_sdf/arana_efectos_horno.py.
#    RAYOS     la Descarga (y su climax): rayos a todos lados que saltan por el suelo.
#    FOGONAZO  la Explosion de brasas (y su climax): fogonazo, aro de fuego y chispas.
#    CARGA     (se queda) chispazos o ascuas alrededor del cuerpo, mas cuantas mas cargas, y el CONTADOR encima.
#    puntos()  el contador solo, en ambar (la capa de ambar del Tocon y del set Ambar: TacticoTrent).
#    arco()    el rebote y el hilo al rojo: un rayo en zigzag entre dos cuerpos (RayoPixel).
# ============================================================
extends Node2D
class_name AranaAire

enum Modo { RAYOS, FOGONAZO, CARGA }

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80
const CIAN := Color(0.35, 0.85, 1.0)
const NARANJA := Color(1.0, 0.55, 0.15)
const PAL_RAYO: PackedColorArray = [Color8(40, 92, 214), Color8(96, 204, 236), Color8(236, 250, 255)]
const PAL_BRASA: PackedColorArray = [Color8(226, 90, 20), Color8(255, 164, 56), Color8(255, 236, 170)]
const T_RAYOS := 0.75
const T_FOGONAZO := 0.8
const CLIMAX_TORMENTOSA := 0.9
const CLIMAX_TEJEDORA := 0.9

var _tipo: String = "rayo"     # el del contador: rayo, brasa o ambar
var _alrededor: String = ""     # chispas o ascuas ("" = solo el contador)
var _caja: Rect2 = Rect2()
var _nivel: int = -1
var _tope: int = -1
var _cont: EfectoPixel = null
var _aura: EfectoPixel = null


static func rayos(padre: Node, c: Vector2, _r: float, _semilla: int) -> Node2D:
	return EfectoPixel.lanzar(padre, "arana", "descarga", c, 0, null, 0.0, -1.0, maxf(BarridoAire.ritmo, 0.05))


static func fogonazo(padre: Node, c: Vector2, _r: float, _semilla: int) -> Node2D:
	return EfectoPixel.lanzar(padre, "arana", "explosion", c, 0, null, 0.0, -1.0, maxf(BarridoAire.ritmo, 0.05))


# El rebote (rayo, azul) o el hilo al rojo (brasa): de 'desde' a 'hasta', saltando en zigzag. 'espera' = lo que falta para el golpe.
static func arco(padre: Node, desde: Vector2, hasta: Vector2, brasa: bool, espera: float, ritmo: float) -> RayoPixel:
	var r: RayoPixel = RayoPixel.lanzar(padre, desde, hasta, 2.0, PAL_BRASA if brasa else PAL_RAYO, maxf(espera, 0.06), 0.2, 0.2, 0.0, ritmo)
	if r != null:
		r.quiebros = maxi(3, roundi(desde.distance_to(hasta) / (8.0 * SpriteLienzo.UNIDADES_POR_CELDA)))
	return r


# Lo que se queda pegado al cuerpo: lo sigue con seguir() y se va con secar().
static func pegado(padre: Node, caja: Rect2, fuego_: bool, _semilla: int) -> AranaAire:
	var e := AranaAire.new()
	e._tipo = "brasa" if fuego_ else "rayo"
	e._alrededor = "ascuas" if fuego_ else "chispas"
	e._caja = caja
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	return e


# EL CONTADOR SOLO, en ambar (04/11, la capa de ambar: lo que le falta para volver).
static func puntos(padre: Node, caja: Rect2, semilla: int) -> AranaAire:
	var e := pegado(padre, caja, true, semilla)
	e._tipo = "ambar"
	e._alrededor = ""
	return e


# EL CLIMAX DE LA EVOLUCION (su peticion, 03/11): lo llama gesto_transformacion, asi que sale igual en el mapa y en el espejo.
static func climax(nodo: Node2D, spr: AnimatedSprite2D) -> void:
	if not spr.sprite_frames.has_animation(&"descarga_0") and not spr.sprite_frames.has_animation(&"explosion_0"):
		return
	var es_rayo: bool = spr.sprite_frames.has_animation(&"descarga_0")
	var t := nodo.create_tween()
	t.tween_interval(CLIMAX_TORMENTOSA if es_rayo else CLIMAX_TEJEDORA)
	t.tween_callback(func() -> void:
		if not is_instance_valid(nodo):
			return
		if es_rayo:
			AranaAire.rayos(nodo, Vector2.ZERO, 85.0, randi())
		else:
			AranaAire.fogonazo(nodo, Vector2.ZERO, 60.0, randi()))


func seguir(caja: Rect2) -> void:
	_caja = caja
	if is_instance_valid(_cont):
		_cont.position = Vector2(caja.get_center().x, caja.position.y)
	if is_instance_valid(_aura):
		_aura.position = Vector2(caja.get_center().x, caja.end.y)


func poner_nivel(n: int, t: int) -> void:
	var tope: int = clampi(t, 1, 5)
	var nivel: int = clampi(n, 0, tope)
	if nivel == _nivel and tope == _tope:
		return
	_nivel = nivel
	_tope = tope
	if is_instance_valid(_cont):
		_cont.queue_free()
	_cont = EfectoPixel.lanzar(self, "arana", "cont_%s_%d_%d" % [_tipo, tope, nivel], Vector2.ZERO)
	if is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	if _alrededor != "" and nivel > 0:
		_aura = EfectoPixel.lanzar(self, "arana", "%s_%d" % [_alrededor, nivel], Vector2.ZERO)
	seguir(_caja)


func secar() -> void:
	queue_free()
