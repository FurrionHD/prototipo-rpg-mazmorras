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
# LA CAIDA (20/11, el jefe: "es muy epico, muy vistoso, lo suyo es que dure un poco mas"): primero SE ALZA y crece, cogiendo
# fuerza, y luego cae a plomo. Lo que tarda cada cosa y en volver a su sitio (s reales a velocidad normal; CombatFX.T_VUELO
# de LUNA_CAIDA = (T_ALZA + T_CAE) x RITMO_BASE, con un pelo de margen).
const T_ALZA := 0.5
const SUBE := 10.0      # cuanto se alza (mundo)
const CRECE := 1.25     # y cuanto crece mientras
const T_CAE := 0.6
const T_VUELVE := 2.4
# (20/11, el jefe: "es un salto muy brusco") el CAMBIO DE FASE se funde: la vieja se apaga mientras la nueva se enciende
const T_FASE := 1.2
const T_PUNTOS := 0.35

var fase: int = -1
var puntos: int = -1
var _luna: EfectoPixel = null
var _paso: EfectoPixel = null   # el paso de una fase a la siguiente, mientras dure (poner_fase)
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
	var vieja: EfectoPixel = _luna if is_instance_valid(_luna) else null
	var desde: int = fase
	fase = f
	# (20/11, el jefe: "que dibujes como se llena o se vacia, no una transparencia") A LA SIGUIENTE DEL CICLO, LA SOMBRA SE
	# CORRE: la hoja luna_paso_<desde> (16 marcos, el mismo vaiven que el bucle). Empieza cuando el bucle de la vieja vuelve a
	# su marco 0 (el paso nace en ese marco y en ese punto del vaiven: no salta nada) y al acabar sigue el bucle de la nueva.
	if vieja != null and desde >= 0 and f == (desde + 1) % 4 and not is_instance_valid(_paso):
		var dentro: float = fmod(maxf(vieja._t, 0.0) * vieja._fps, float(vieja._n))
		var falta: float = (float(vieja._n) - dentro) / vieja._fps
		_paso = EfectoPixel.lanzar(self, "acechador", "luna_paso_" + FASES[desde], Vector2.ZERO, 0, null, falta)
		if _paso != null:
			_luna = EfectoPixel.lanzar(self, "acechador", "luna_" + FASES[f], Vector2.ZERO, 0, null,
				falta + float(_paso._n) / _paso._fps)
			# la vieja se va un pelin tarde: su marco 0 y el primero del paso son el mismo dibujo, asi no parpadea
			var tw := vieja.create_tween()
			tw.tween_interval(falta + 0.05)
			tw.tween_callback(vieja.queue_free)
			return
	# Un salto que no es el siguiente (o a mitad de otro paso): se funde, como antes
	if is_instance_valid(_paso):
		_paso.queue_free()
	_paso = null
	_luna = EfectoPixel.lanzar(self, "acechador", "luna_" + FASES[f], Vector2.ZERO)
	_fundir(vieja, _luna, T_FASE)


func poner_puntos(n: int) -> void:
	n = clampi(n, 0, 3)
	if n == puntos and is_instance_valid(_puntos):
		return
	puntos = n
	var viejos: EfectoPixel = _puntos if is_instance_valid(_puntos) else null
	_puntos = EfectoPixel.lanzar(self, "acechador", "puntos_%d" % n, Vector2.ZERO)
	_fundir(viejos, _puntos, T_PUNTOS)


# La vieja se apaga y se borra; la nueva se enciende (la primera vez, sin vieja, aparece sin mas).
func _fundir(vieja: EfectoPixel, nueva: EfectoPixel, t: float) -> void:
	if vieja == null:
		return
	if nueva != null:
		nueva.modulate.a = 0.0
		nueva.create_tween().tween_property(nueva, "modulate:a", 1.0, t).set_trans(Tween.TRANS_SINE)
	var tw := vieja.create_tween()
	tw.tween_property(vieja, "modulate:a", 0.0, t).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(vieja.queue_free)


# LA CAIDA DE LA LUNA: dentro de 'espera' s se alza y crece, cae y llega a 'destino' justo cuando pega (espera + T_ALZA +
# T_CAE, partido por 'ritmo': a x2 todo al doble), suelta el golpe en el suelo y vuelve flotando despacio a su sitio.
var caidas: int = 0   # las que ha soltado (las pruebas lo miran)

# EL TEMBLOR DE ANTES DE CAER (20/11, idea del jefe: "que empiece a temblar en cuanto aulle, mas guia visual"): mientras el
# Cazador carga la Caida. A saltos de un pixel de su hoja (no un vaiven liso: es pixel art), cada vez mas fuerte. Al
# acabar la carga aun aguanta un poco (T_SIGUE_TEMBLANDO), hasta que la suelta y cae.
const T_SALTO_TEMBLOR := 0.06
const T_SIGUE_TEMBLANDO := 0.8
var temblando: bool = false
var _temblor_desde: int = 0
var _temblor_hasta: int = 0
var _t_salto: float = 0.0


func temblar(si: bool) -> void:
	var ahora: int = Time.get_ticks_msec()
	if si:
		if not temblando:
			_temblor_desde = ahora
		temblando = true
		_temblor_hasta = 0
	elif temblando and _temblor_hasta == 0:
		_temblor_hasta = ahora + int(T_SIGUE_TEMBLANDO * 1000.0)


func _parar_temblor() -> void:
	temblando = false
	_temblor_hasta = 0


func _process(delta: float) -> void:
	if not temblando:
		return
	if _temblor_hasta > 0 and Time.get_ticks_msec() >= _temblor_hasta:
		_parar_temblor()
		if _cayendo == null or not _cayendo.is_valid():
			position = _sitio
		return
	if _cayendo != null and _cayendo.is_valid() and _cayendo.is_running():
		return
	_t_salto -= delta
	if _t_salto > 0.0:
		return
	_t_salto = T_SALTO_TEMBLOR
	# de 1 a 2 pixeles de la hoja segun lleva temblando
	var px: float = SpriteLienzo.UNIDADES_POR_CELDA
	var fuerza: int = 1 if Time.get_ticks_msec() - _temblor_desde < 1500 else 2
	position = _sitio + Vector2(randi_range(-fuerza, fuerza), randi_range(-fuerza, fuerza)) * px

func caer(destino: Vector2, espera: float, ritmo: float = 1.0) -> void:
	caidas += 1
	_parar_temblor()
	var r: float = maxf(ritmo, 0.05)
	if _cayendo != null and _cayendo.is_valid():
		_cayendo.kill()
	position = _sitio
	scale = Vector2.ONE
	_cayendo = create_tween()
	_cayendo.tween_interval(maxf(espera, 0.0))
	# SE ALZA Y CRECE, frenando al final (como quien coge aire)
	_cayendo.tween_property(self, "position", _sitio - Vector2(0.0, SUBE), T_ALZA / r) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cayendo.parallel().tween_property(self, "scale", Vector2.ONE * CRECE, T_ALZA / r) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cayendo.tween_callback(_empieza_caida.bind(destino))
	_cayendo.tween_property(self, "position", destino - Vector2(0.0, 14.0), T_CAE / r) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_cayendo.parallel().tween_property(self, "scale", Vector2.ONE, T_CAE / r) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_cayendo.tween_callback(_golpe.bind(destino))
	_cayendo.tween_property(self, "position", destino - Vector2(0.0, 20.0), 0.12 / r).set_trans(Tween.TRANS_SINE)
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
