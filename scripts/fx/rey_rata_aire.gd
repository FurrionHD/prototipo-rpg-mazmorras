# ============================================================
#  rey_rata_aire.gd  (class_name ReyRataAire)
#  LOS EFECTOS DE LOS MUTANTES DEL REY RATA en el mapa (31/10/2026: el Rey de las cloacas y el Rey del desguace; memoria rey-rata-mutante), EN PIXEL
#  ART (04/11/2026, memoria efectos-a-pixel-art): sus hojas salen de tools/sprites_sdf/rey_rata_efectos_horno.py; aqui, que hoja sale y donde.
#    AGUJERO   la LLAMADA: el suelo se raja junto al rey, revienta en un boquete del que salen sus ratas y se cierra (las grietas de los brotes).
#    CAMPANAZO el TAPAZO al tocar: un aro de metal que se abre desde la tapa, con chispas naranjas.
#    CHATARRA  y del mismo golpe saltan tornillos y oxido hacia donde empuja, caen, se quedan un momento y se van.
#    CHISPAS   el FRENTE BLINDADO: le has pegado por delante y la chatarra se lo ha comido.
#    FURIA     la FURIA DE REY (nivel 1-3): le brillan los ojos y le sale vaho por el hocico. Sigue al sprite mientras dura (este nodo).
# ============================================================
extends Node2D
class_name ReyRataAire

enum Modo { AGUJERO, CAMPANAZO, CHATARRA, CHISPAS, FURIA }
enum Version { GRIETA }

const T_RAJA := 0.35
const T_ABRE := 0.2
const T_ABIERTO := 0.75
const T_CIERRA := 0.55

var _sigue: Node2D = null     # (la furia) el sprite al que va pegada
var nivel: int = 0
var _dir: int = -1
var _hoja: EfectoPixel = null


static func agujero(padre: Node, centro: Vector2, _v: int, _semilla: int) -> Node2D:
	var e: EfectoPixel = EfectoPixel.lanzar(padre, "rey_rata", "grieta", centro, 0, null, 0.0, -1.0, maxf(BarridoAire.ritmo, 0.05))
	if e != null:
		e.set_meta("grieta", true)
	return e


# Lo de sobre un cuerpo: el CAMPANAZO y las CHISPAS ('c' = donde toca, 'dir' = hacia donde empuja / hacia quien pega) y la CHATARRA.
static func golpe(padre: Node, m: int, c: Vector2, dir: Vector2, _r: float, _semilla: int, espera: float = 0.0) -> Node2D:
	var nombre: String = "campanazo"
	if m == Modo.CHATARRA:
		nombre = "chatarra"
	elif m == Modo.CHISPAS:
		nombre = "chispas"
	var e: EfectoPixel = EfectoPixel.lanzar(padre, "rey_rata", nombre, c, SpriteLienzo.dir8(dir) if dir.length_squared() > 0.0001 else 0, null, maxf(espera, 0.0), -1.0,
		maxf(BarridoAire.ritmo, 0.05))
	if e != null:
		e.set_meta("golpe_rey", m)
	return e


# LA FURIA sobre 'spr' (el sprite del rey): nivel 1-3, 'dir' = hacia donde mira. Se queda hasta que la quiten (parar()).
static func furia(padre: Node, spr: Node2D, lvl: int, dir: Vector2, _semilla: int) -> ReyRataAire:
	if padre == null:
		return null
	var e := ReyRataAire.new()
	e._sigue = spr
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e.poner_nivel(lvl, dir)
	return e


static func agujero_dur() -> float:
	return T_RAJA + T_ABRE + T_ABIERTO + T_CIERRA


static func t_abierto() -> float:
	return T_RAJA + T_ABRE


func poner_nivel(lvl: int, dir: Vector2) -> void:
	var n: int = clampi(lvl, 1, 3)
	var d: int = SpriteLienzo.dir8(dir) if dir.length_squared() > 0.0001 else 0
	if n == nivel and d == _dir and is_instance_valid(_hoja):
		return
	nivel = n
	_dir = d
	if is_instance_valid(_hoja):
		_hoja.queue_free()
	_hoja = EfectoPixel.lanzar(self, "rey_rata", "furia_%d" % n, Vector2.ZERO, d, _sigue)


func parar() -> void:
	queue_free()


func _process(_delta: float) -> void:
	if not is_instance_valid(_sigue):
		queue_free()
		return
	visible = _sigue.is_visible_in_tree()
