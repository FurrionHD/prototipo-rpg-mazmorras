# ============================================================
#  luna_cielo.gd  (class_name LunaCielo)
#  LA LUNA DEL CIELO DEL CAZADOR LUNAR (20/11/2026, memoria acechador-mutante; la A mejorada, aprobada: "muy loco, se ve muy
#  god"). Mientras haya un Cazador lunar vivo en la pelea, flota sobre el centro de la pelea:
#    - su FASE (nueva, creciente, llena, menguante) es la de su turno (la magnitud de su pasiva FASES_LUNA, que viaja);
#    - encima, LOS PUNTOS DE LA PACIENCIA (como los contadores de las tejedoras);
#    - es LA LUZ DE LA PELEA: los farolillos se apagan (Game.radio_lampara) y ella alumbra, tenue (Niebla._focos), y lo
#      tiñe todo de azul (un CanvasModulate mientras esta);
#    - la CAIDA DE LA LUNA: cae sobre ellos, golpea y vuelve flotando despacio a su sitio (caer()).
#  Las hojas: tools/sprites_sdf/acechador_efectos_pixel.py --hornear (assets/sprites/efectos/acechador/luna_*, puntos_*).
#  La pone y la quita CombatTactico._tick_luna. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name LunaCielo

const GRUPO := &"luna_pelea"
const FASES := ["nueva", "creciente", "llena", "menguante"]
# LA LUZ: hasta donde alumbra (celdas de mapa) y cuanto (1 = un farolillo): "no ilumina un monton, pero ilumina".
const RADIO_LUZ := 9.0
const INTENSIDAD_LUZ := 0.55
const TINTE := Color(0.72, 0.8, 1.0)   # el azul de la luz de luna sobre todo lo del mundo
const T_TINTE := 1.2
# LA CAIDA: lo que tarda en caer y en volver a su sitio (s)
const T_CAE := 0.45
const T_VUELVE := 2.4

var fase: int = -1
var puntos: int = -1
var _luna: EfectoPixel = null
var _puntos: EfectoPixel = null
var _estela: EfectoPixel = null
var _tinte: CanvasModulate = null
var _sitio: Vector2 = Vector2.ZERO   # su sitio en el cielo (a donde vuelve tras caer)
var _cayendo: Tween = null


static func crear(padre: Node, sitio: Vector2) -> LunaCielo:
	var l := LunaCielo.new()
	l._sitio = sitio
	l.position = sitio
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	l.add_to_group(GRUPO)
	padre.add_child(l)
	l._tinte = CanvasModulate.new()
	l._tinte.color = Color.WHITE
	padre.add_child(l._tinte)
	l.create_tween().tween_property(l._tinte, "color", TINTE, T_TINTE)
	return l


# La luz que da, para Niebla._focos: {pos, radio, intensidad}. Alumbra donde ESTA (si cae, la luz baja con ella).
func foco() -> Dictionary:
	return {"pos": global_position, "radio": RADIO_LUZ, "intensidad": INTENSIDAD_LUZ}


# ¿Hay una luna en la pelea? (Game.radio_lampara: entonces los farolillos no alumbran.)
static func hay(arbol: SceneTree) -> bool:
	return arbol != null and arbol.get_first_node_in_group(GRUPO) != null


func poner_fase(f: int) -> void:
	f = clampi(f, 0, 3)
	if f == fase and is_instance_valid(_luna):
		return
	fase = f
	if is_instance_valid(_luna):
		_luna.queue_free()
	_luna = EfectoPixel.lanzar(self, "acechador", "luna_" + FASES[f], Vector2.ZERO)


func poner_puntos(n: int) -> void:
	n = clampi(n, 0, 3)
	if n == puntos and is_instance_valid(_puntos):
		return
	puntos = n
	if is_instance_valid(_puntos):
		_puntos.queue_free()
	_puntos = EfectoPixel.lanzar(self, "acechador", "puntos_%d" % n, Vector2.ZERO)


# LA CAIDA DE LA LUNA: dentro de 'espera' s empieza a caer, llega a 'destino' justo cuando pega (espera + T_CAE), suelta el
# golpe en el suelo y vuelve flotando despacio a su sitio.
func caer(destino: Vector2, espera: float) -> void:
	if _cayendo != null and _cayendo.is_valid():
		_cayendo.kill()
	position = _sitio
	_cayendo = create_tween()
	_cayendo.tween_interval(maxf(espera, 0.0))
	_cayendo.tween_callback(_empieza_caida.bind(destino))
	_cayendo.tween_property(self, "position", destino - Vector2(0.0, 14.0), T_CAE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_cayendo.tween_callback(_golpe.bind(destino))
	_cayendo.tween_property(self, "position", destino - Vector2(0.0, 20.0), 0.12).set_trans(Tween.TRANS_SINE)
	_cayendo.tween_property(self, "position", _sitio, T_VUELVE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _empieza_caida(destino: Vector2) -> void:
	if is_instance_valid(_estela):
		_estela.queue_free()
	_estela = EfectoPixel.lanzar(self, "acechador", "luna_estela", Vector2.ZERO)
	if _estela != null:
		# la estela apunta a de donde viene (arriba = su hoja); se gira hacia el cielo
		_estela.rotation = (_sitio - destino).angle() + PI * 0.5


func _golpe(destino: Vector2) -> void:
	if is_instance_valid(_estela):
		_estela.queue_free()
	if get_parent() != null:
		EfectoPixel.lanzar(get_parent(), "acechador", "luna_golpe", destino)


# Se va (el Cazador ha caido o acaba la pelea): la luz vuelve poco a poco y la luna se apaga.
func irse() -> void:
	remove_from_group(GRUPO)
	if _cayendo != null and _cayendo.is_valid():
		_cayendo.kill()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, T_TINTE)
	if is_instance_valid(_tinte):
		t.tween_property(_tinte, "color", Color.WHITE, T_TINTE)
	t.chain().tween_callback(_borrar)


func _borrar() -> void:
	if is_instance_valid(_tinte):
		_tinte.queue_free()
	queue_free()
