# ============================================================
#  pieza_pixel.gd  (class_name PiezaPixel)
#  LO QUE SE QUEDA, EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art): la nube, la burbuja, la baba, la telaraña... Tres hojas:
#  la que SALE, la que se repite MIENTRAS DURA y la de cuando SE VA. Habla como los charcos de CombatTactico: le ponen 'queda' cada
#  poco y le llaman secar() al acabar. Con 'tiembla', vibra cuando le queda poco (se ve venir que va a reventar).
# ============================================================
extends Node2D
class_name PiezaPixel

enum Fase { SALE, DURA, SE_VA }

var queda: float = 1.0
var tiembla: bool = false
var _enemigo: String = ""
var _dura: String = ""
var _vete: String = ""
var _paleta: PackedColorArray = PackedColorArray()
var _dir: int = 0
var _ritmo: float = 1.0
var _fase: int = Fase.SALE
var _actual: EfectoPixel = null
var _reloj: float = 0.0
var _vuelve_de: Vector2 = Vector2.ZERO
var _vuelve_a: Vector2 = Vector2.ZERO
var _vuelve_t: float = -1.0
var _vuelve_dur: float = 0.4


static func crear(padre: Node, enemigo: String, sale: String, dura: String, vete: String, pos: Vector2, dir: int = 0,
		paleta: PackedColorArray = PackedColorArray(), espera: float = 0.0, ritmo: float = 1.0) -> PiezaPixel:
	if padre == null:
		return null
	var p := PiezaPixel.new()
	p._enemigo = enemigo
	p._dura = dura
	p._vete = vete
	p._paleta = paleta
	p._dir = dir
	p._ritmo = maxf(ritmo, 0.05)
	p.position = pos
	p.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(p)
	if sale != "":
		p._actual = EfectoPixel.lanzar(p, enemigo, sale, Vector2.ZERO, dir, null, espera, -1.0, p._ritmo, paleta)
	else:
		p._poner_dura()
	return p


# LO QUE VA PEGADO A ALGUIEN (el cepo, el humo, las ronchas...): a sus pies ('caja' = su cuerpo).
func seguir(caja: Rect2, pies: Vector2 = Vector2.INF) -> void:
	position = pies if pies != Vector2.INF else Vector2(caja.get_center().x, caja.end.y)


# Una hoja de lo que dura por nivel (las cargas del humo): 'por_nivel' = sus nombres, del 1 en adelante.
var _por_nivel: Array = []
var _nivel: int = 1


func con_niveles(nombres: Array, n: int) -> PiezaPixel:
	_por_nivel = nombres
	poner_nivel(n)
	return self


func poner_nivel(n: int) -> void:
	if _por_nivel.is_empty():
		return
	var i: int = clampi(n, 1, _por_nivel.size())
	if i == _nivel and _dura == _por_nivel[i - 1]:
		return
	_nivel = i
	_dura = _por_nivel[i - 1]
	if _fase == Fase.DURA:
		if is_instance_valid(_actual):
			_actual.queue_free()
		_poner_dura()


# Cambia el color despues de crearlo (el charco de savia que es de savia negra, o la baba de un slime).
func tenir(paleta: PackedColorArray) -> void:
	_paleta = paleta
	if is_instance_valid(_actual):
		var t_ahora: float = _actual._t
		var hoja: String = _actual.get_meta("hoja", "")
		if hoja != "":
			_actual.queue_free()
			_actual = EfectoPixel.lanzar(self, _enemigo, hoja, Vector2.ZERO, _dir, null, 0.0, -1.0, _ritmo, _paleta)
			if _actual != null:
				_actual._t = t_ahora


func _poner_dura() -> void:
	_fase = Fase.DURA
	_actual = EfectoPixel.lanzar(self, _enemigo, _dura, Vector2.ZERO, _dir, null, 0.0, -1.0, _ritmo, _paleta)


func _process(delta: float) -> void:
	_reloj += delta
	var hay: bool = is_instance_valid(_actual)
	match _fase:
		Fase.SALE:
			if not hay:
				_poner_dura()
		Fase.DURA:
			if tiembla and hay:
				# Cuanto menos le queda, mas: a saltos de una celda, sin mezclas.
				var fuerte: bool = queda < 0.5
				_actual.position.x = (SpriteLienzo.UNIDADES_POR_CELDA if fuerte and int(_reloj * 16.0) % 2 == 0 else 0.0)
		Fase.SE_VA:
			if _vuelve_t >= 0.0:
				_vuelve_t = minf(_vuelve_t + delta * _ritmo, _vuelve_dur)
				position = _vuelve_de.lerp(_vuelve_a, _vuelve_t / _vuelve_dur)
			if not hay and (_vuelve_t < 0.0 or _vuelve_t >= _vuelve_dur):
				queue_free()


# El que vuelve a quien lo solto (el pedazo del Rey destronado): se desliza hasta 'p' mientras se va.
func volver_a(p: Vector2, dur: float = 0.4) -> void:
	secar()
	_vuelve_de = position
	_vuelve_a = p
	_vuelve_t = 0.0
	_vuelve_dur = maxf(dur, 0.01)


func secar() -> void:
	if _fase == Fase.SE_VA:
		return
	_fase = Fase.SE_VA
	if is_instance_valid(_actual):
		_actual.queue_free()
	_actual = EfectoPixel.lanzar(self, _enemigo, _vete, Vector2.ZERO, _dir, null, 0.0, -1.0, _ritmo, _paleta)


# El que sale volando hasta su sitio (la burbuja): se le pone a la hoja de salida.
func poner_vuelo(hoja: String, desde: Vector2, alto: float, dur: float) -> void:
	if is_instance_valid(_actual):
		_actual.poner_vuelo(_enemigo, hoja, desde, global_position, alto, dur)


func fase() -> int:
	return _fase
