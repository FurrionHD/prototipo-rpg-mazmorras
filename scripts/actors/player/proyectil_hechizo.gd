# ============================================================
#  proyectil_hechizo.gd
#  El conjuro que sale disparado cuando terminas de recitar en el mapa (ver casteo_mapa.gd). Va del
#  que lo lanza al bicho y, al llegar, avisa por su señal: quien la escucha es el que abre el
#  combate (player._impacto_conjuro).
#
#  PERSIGUE AL NODO, no a un punto: entre que sale y llega, el bicho se ha movido. Y si el bicho
#  desaparece por el camino (lo mata un DoT, lo recicla el piso), el conjuro se disipa sin avisar a
#  nadie -- el maná ya se gasto al soltarlo, igual que en combate.
# ============================================================

extends Node2D

signal impacto(objetivo: Node)

# Lo que tarda en recorrer la distancia. Va por VELOCIDAD y no por tiempo fijo: a bocajarro tiene
# que sentirse instantaneo y desde lejos tiene que verse volar.
const VELOCIDAD := 520.0
# Si el objetivo huye mas rapido de lo que vuela el conjuro, esto evita que lo persiga eternamente.
const VIDA_MAX := 3.0
const LADO := 14.0

var _objetivo: Node = null
var _color: Color = Color.WHITE
var _vida: float = 0.0
var _cuerpo: ColorRect = null


func setup(objetivo: Node, color: Color) -> void:
	_objetivo = objetivo
	_color = color


func _ready() -> void:
	z_as_relative = false
	z_index = 5   # por encima de los cuerpos: el conjuro pasa POR DELANTE
	_cuerpo = ColorRect.new()
	_cuerpo.color = _color
	_cuerpo.size = Vector2(LADO, LADO)
	_cuerpo.position = Vector2(-LADO * 0.5, -LADO * 0.5)
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cuerpo)
	# La estela: las mismas particulas que llevan los bichos elementales, con el color del hechizo.
	# local_coords = false, asi que se quedan por donde ha pasado y dibujan el rastro solas.
	Particulas.ascendentes(self, _color, 1.0, LADO * 1.6)


func _process(delta: float) -> void:
	_vida += delta
	if not is_instance_valid(_objetivo) or _vida > VIDA_MAX:
		queue_free()   # se ha quedado sin a quien ir: se disipa y no avisa a nadie
		return
	var destino: Vector2 = (_objetivo as Node2D).global_position
	var paso: float = VELOCIDAD * delta
	# El cuadrado gira mientras vuela: sin esto parece un pixel muerto arrastrandose.
	rotation += delta * 8.0
	if global_position.distance_to(destino) <= paso:
		global_position = destino
		var obj := _objetivo
		_objetivo = null   # que un segundo frame no vuelva a emitir
		impacto.emit(obj)
		queue_free()
		return
	global_position += (destino - global_position).normalized() * paso
