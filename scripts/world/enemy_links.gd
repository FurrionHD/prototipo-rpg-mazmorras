# ============================================================
#  enemy_links.gd  (Node2D)
#  LINEAS DE VINCULO entre enemigos cercanos. Une con una linea a cada par de bichos que
#  esten dentro de Enemy.RADIO_REFUERZO, que es EXACTAMENTE la regla que usa
#  Enemy.vecinos() para reclutar refuerzos al empezar un combate.
#
#  Esa coincidencia es el sentido de todo esto: la linea es una PROMESA. Lo que ves unido es
#  lo que te va a caer encima si tocas a uno de ellos, ni mas ni menos. Por eso el radio sale
#  de la constante del enemigo y no de una copia local: si un dia se retoca, la linea y el
#  reclutamiento no pueden separarse, o el aviso pasaria a mentir.
#
#  Leerla es la decision tactica: ¿entro al corro de tres, o me llevo a uno lejos (con ruido o
#  dejandome ver) y lo peleo solo? Separarlos rompe la linea DE VERDAD: no hay alerta a gritos que
#  te devuelva al que acabas de apartar.
#
#  Los bichos ahora se BUSCAN entre ellos y forman corros del tamaño que pide tu grupo (ver las
#  manadas en enemy.gd), asi que estas lineas se ven crecer solas mientras merodean. Eso no rompe
#  la promesa, la hace mas util: se juntan A LA VISTA y antes de la pelea, asi que lo que lees en
#  el mapa sigue siendo exactamente lo que te va a caer encima si tocas a uno.
#
#  Cuelga del PADRE del piso, junto a los enemigos (dungeon_floor.crear_enemigo): el piso
#  tiene z_index -1, y una capa colgada de el se pintaria por debajo del suelo.
# ============================================================

extends Node2D

const Enemy = preload("res://scripts/actors/enemy/enemy.gd")

# Cada cuanto se recalculan los pares. NO cada frame: son N^2 distancias y los bichos no se
# teletransportan; a 5 veces por segundo el ojo no nota el retardo. Mismo espiritu que el
# recalculo perezoso del cono de vision (ver enemy.gd RECALCULO_ANGULO / RECALCULO_DIST).
const INTERVALO := 0.2
# Solo se miran los bichos a menos de esto del jugador: los del otro extremo del piso no se ven
# y no hace falta calcularles nada.
const RADIO_ACTIVO := 700.0

const COLOR_LINEA := Color(1.0, 0.55, 0.2, 0.55)
const GROSOR := 2.0

var _t: float = 0.0
var _lineas: Array[Line2D] = []   # pool: se reutilizan, no se crean y destruyen cada tick
var _player: Node2D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	# Con la pantalla de combate delante el mundo ni se dibuja, asi que recalcular pares (O(n^2))
	# es trabajo tirado. En un jugador el arbol esta pausado y esto ni corre; en multi si.
	if Game.hay_modal_de(Game.Modal.COMBATE):
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = INTERVALO
	_recalcular()


func _recalcular() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

	# Candidatos: vivos, no metidos ya en un combate y cerca del jugador.
	var cerca: Array = []
	for n in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n) or n._combat_triggered:
			continue
		if _player != null and _player.global_position.distance_to(n.global_position) > RADIO_ACTIVO:
			continue
		cerca.append(n)

	var usadas: int = 0
	for i in cerca.size():
		for j in range(i + 1, cerca.size()):
			var a: Node2D = cerca[i]
			var b: Node2D = cerca[j]
			if a.global_position.distance_to(b.global_position) > Enemy.RADIO_REFUERZO:
				continue
			var l: Line2D = _linea(usadas)
			# Puntos en coordenadas de ESTE nodo (no locales a ningun bicho): una linea entre
			# dos cuerpos no puede colgar de uno de ellos, o giraria y se movería con el.
			l.points = PackedVector2Array([to_local(a.global_position), to_local(b.global_position)])
			l.visible = true
			usadas += 1
	# Las que sobran se apagan (siguen en el pool para el proximo tick).
	for k in range(usadas, _lineas.size()):
		_lineas[k].visible = false


# Linea 'i' del pool, creandola si aun no existe.
func _linea(i: int) -> Line2D:
	while _lineas.size() <= i:
		var l := Line2D.new()
		l.width = GROSOR
		l.default_color = COLOR_LINEA
		l.z_index = -1   # por debajo de los cuerpos: une, no los tapa
		add_child(l)
		_lineas.append(l)
	return _lineas[i]
