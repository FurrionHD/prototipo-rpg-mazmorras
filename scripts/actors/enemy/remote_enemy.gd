# ============================================================
#  remote_enemy.gd
#  EL CUERPO de un enemigo del HOST visto en MI mundo (multijugador, hito 5.1).
#
#  Gemelo de remote_player.gd pero para bichos: en multi los enemigos los SIMULA el host
#  (IA, spawns, aforo) y aqui solo se PINTAN. Deliberadamente LIGERO: un ColorRect con el
#  color y el tamaño que el host calculo (data.color_visual / escala_visual), sin IA, sin
#  colision, sin vision, sin combate. NO entra en el grupo "enemy" ni "corpse": es un
#  fantasma visual que se mueve donde diga la red.
#
#  La posicion llega por RPC (Net._tick_enemigos) a ritmo de red; entre paquete y paquete se
#  INTERPOLA hacia el ultimo objetivo, igual que remote_player.
#
#  5.1 = SOLO ver los mismos bichos en las mismas posiciones. El combate replicado (barras,
#  turnos, muerte, extraccion) son sub-fases posteriores (ver docs/MULTIJUGADOR.md).
# ============================================================

extends Node2D

const SUAVIZADO := 14.0   # rapidez del lerp hacia el objetivo (igual que remote_player)
const SALTO := 200.0      # salto grande = teletransporte, no cruzar el mapa deslizandose

var _objetivo := Vector2.INF   # ultimo destino recibido; INF = aun no ha llegado ninguno
var _cuerpo: ColorRect = null
var muerto := false            # ya es cadaver (lo dice quien simula el piso)

# --- Lo que lo hace PELEABLE y EXTRAIBLE (hito 5.3) -------------------------------------------
# Con solo un ColorRect no se podia ni pulsar F encima: player._mas_cercano_en_grupo busca por
# grupo, y Game.start_extraction aborta sin 'data'. Ahora el alta de red trae la RUTA del .tres y
# la 't', que es TODO lo que hace falta para reconstruir sus stats (load() cachea, asi que sale la
# misma instancia de EnemyData que en la maquina que lo simula).
var data: EnemyData = null
var current_t: float = 0.5
var extracted: bool = false    # lo mira player._mas_cercano_en_grupo para no ofrecerlo dos veces
var radio_extra: float = 0.0   # los elites son mas gordos: se descuenta al medir la distancia
# Vida arrastrada y bandera de jefe: Game.start_combat las lee con "in", asi que un espejo con
# estos campos se puede pasar TAL CUAL a start_combat como si fuera un enemigo real.
var hp_restante: float = -1.0
var es_boss: bool = false

# --- CONO DE VISION Y DIRECCION (hito 5.4) ----------------------------------------------------
# Mismos numeros y colores que enemy.gd: lo que ve el que simula el piso y lo que ve el que solo
# lo espeja tiene que ser LO MISMO, o uno de los dos juega a ciegas.
const SEGMENTOS_CONO := 14
const CAPA_ROCA := 1
const RECALCULO_ANGULO := 0.10
const RECALCULO_DIST := 6.0
const COLOR_CONO := Color(1.0, 1.0, 0.3, 0.12)
const COLOR_CONO_AVISO := Color(1.0, 0.25, 0.1, 0.18)
const COLOR_LINEA := Color(1.0, 1.0, 0.0)
const COLOR_LINEA_AVISO := Color(1.0, 0.3, 0.1)

var _cono: Polygon2D = null
var _linea: Line2D = null
var _vision: float = 130.0        # alcance del cono (llega en el alta)
var _medio_angulo: float = 50.0   # apertura (llega en el alta)
var _mira: float = 0.0            # ultimo angulo recibido
var _avisando: bool = false       # esta telegrafiando el golpe
var _cono_hecho := false
var _cono_ang: float = 0.0
var _cono_pos := Vector2.ZERO
# --- EL CONTRATO DEL GRUPO "enemy" -----------------------------------------------------------
# Todo esto se llama igual que en enemy.gd A PROPOSITO. Al entrar en el grupo "enemy" hay que
# cumplir su contrato ENTERO, porque varios sistemas recorren el grupo y leen estos campos a pelo:
#   _combat_triggered -> enemy_links, el culling y vecinos() del piso
#   zona_idx          -> dungeon_floor.enemigos_en_zona (aforo por sala)
#   es_boss           -> el reciclador, para no borrar al jefe
#   esta_muerto()     -> vecinos() y las manadas
# Si falta alguno, el juego revienta con "Invalid access to property" en cuanto alguien lo mire.
var _combat_triggered: bool = false    # se la reservo el dueño y la estoy peleando yo
var zona_idx: int = -1                 # no soy de ninguna sala: la ocupacion la lleva el dueño


func _ready() -> void:
	z_as_relative = false
	z_index = 0   # a la altura del jugador y los bichos reales (ver companion.gd)
	# Marca para que el piso NO me meta en su foto y para que la IA de los bichos DE VERDAD me
	# ignore (no soy compañero suyo, soy el dibujo de otra maquina). Estoy en los grupos
	# enemy/corpse solo para que se me pueda atacar y extraer.
	set_meta("es_espejo", true)

	# Cono de vision (poligono translucido), por detras del cuerpo. MISMO aspecto que el bicho real
	# (ver enemy._crear_indicadores): es la unica pista de por donde mira, y sin el no se puede
	# jugar al sigilo.
	_cono = Polygon2D.new()
	_cono.color = COLOR_CONO
	add_child(_cono)

	_cuerpo = ColorRect.new()
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cuerpo)
	_redimensionar(32.0)

	# Linea de direccion (hacia donde mira), delante del cuerpo.
	_linea = Line2D.new()
	_linea.add_point(Vector2.ZERO)
	_linea.add_point(Vector2(26.0, 0.0))
	_linea.width = 3.0
	_linea.default_color = COLOR_LINEA
	add_child(_linea)


# Aspecto que ya calculo quien simula el piso: color base+tinte por 't' y lado del cuerpo (los
# elites son mas grandes). Asi se ve IGUAL en las dos maquinas sin tirar otra 't'.
func configurar(color: Color, lado: float) -> void:
	if _cuerpo != null:
		_cuerpo.color = color
		_redimensionar(lado)
	radio_extra = maxf(0.0, (lado - 32.0) * 0.5)


# Los datos con los que se puede pelear/extraer. 'ruta' es el .tres del EnemyData.
func aplicar_datos(ruta: String, t: float, ya_muerto: bool, vision: float = 130.0,
		medio_angulo: float = 50.0) -> void:
	if not ruta.is_empty():
		data = load(ruta) as EnemyData
	current_t = t
	_vision = vision
	_medio_angulo = medio_angulo
	if ya_muerto:
		marcar_cadaver()
	else:
		add_to_group("enemy")


# Hacia donde mira y si esta avisando el golpe. Llega en cada tick de posiciones.
func aplicar_estado_visual(ang: float, avisando: bool) -> void:
	_mira = ang
	_avisando = avisando
	if muerto:
		return
	if _linea != null:
		_linea.rotation = ang
		_linea.default_color = COLOR_LINEA_AVISO if avisando else COLOR_LINEA
	if _cono != null:
		_cono.color = COLOR_CONO_AVISO if avisando else COLOR_CONO
		# Rehacer el cono cuesta 14 rayos: solo si ha girado o se ha movido lo suficiente.
		if not _cono_hecho \
				or absf(angle_difference(ang, _cono_ang)) > RECALCULO_ANGULO \
				or global_position.distance_to(_cono_pos) > RECALCULO_DIST:
			_redibujar_cono(ang)


# Traza el cono rayo a rayo y corta cada uno donde encuentra roca, igual que el bicho real. La
# geometria del piso es la MISMA en las dos maquinas (misma semilla), asi que el cono sale igual
# sin mandar nada por la red. Los puntos van en LOCAL (el poligono es hijo y por eso no se rota).
func _redibujar_cono(ang: float) -> void:
	if _cono == null or not is_inside_tree():
		return
	_cono_hecho = true
	_cono_ang = ang
	_cono_pos = global_position
	var espacio: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var half: float = deg_to_rad(_medio_angulo)
	# Los aliados comparten capa con la roca: sin excluirlos, el cono se recortaria contra TI (te
	# taparias a ti mismo del cono que te ve).
	var fuera: Array[RID] = []
	for n in get_tree().get_nodes_in_group("aliado"):
		if n is CollisionObject2D:
			fuera.append((n as CollisionObject2D).get_rid())

	var pts: PackedVector2Array = [Vector2.ZERO]
	for i in range(SEGMENTOS_CONO + 1):
		var a: float = ang - half + (2.0 * half) * float(i) / float(SEGMENTOS_CONO)
		var dir := Vector2(cos(a), sin(a))
		var fin: Vector2 = global_position + dir * _vision
		var query := PhysicsRayQueryParameters2D.create(global_position, fin, CAPA_ROCA)
		query.exclude = fuera
		var hit: Dictionary = espacio.intersect_ray(query)
		if not hit.is_empty():
			fin = hit["position"]
		pts.append(fin - global_position)
	_cono.polygon = pts


# Lo mismo que enemy.poder_normalizado(): donde cae dentro de su franja. Lo pide la extraccion
# para decidir la categoria del cristal.
func poder_normalizado() -> float:
	return clampf(current_t, 0.0, 1.0)


func esta_muerto() -> bool:
	return muerto


# Me quito de en medio. Salgo de los grupos AL INSTANTE y no en el queue_free, que no surte efecto
# hasta el final del frame: si no, un enemigo de verdad recien creado (p. ej. al heredar el piso)
# me encontraria todavia en el grupo "enemy" y me preguntaria cosas de su IA que yo no tengo.
func retirar() -> void:
	remove_from_group("enemy")
	remove_from_group("corpse")
	queue_free()


# --- PELEAR CONTRA UN ESPEJO (hito 5.3) -------------------------------------------------------
# Yo no simulo este piso, asi que el bicho de verdad esta en otra maquina. Al atacarlo se le PIDE
# la pelea a su dueño, que reserva el grupo entero (nadie mas puede cogerlo) y me contesta. La
# pelea se juega AQUI, contra estos espejos, y al acabar se le devuelve el resultado para que la
# aplique sobre los bichos reales. Mismo espiritu que el candado de las vetas.
func atacado_por_jugador() -> void:
	if muerto or _combat_triggered or not has_meta("net_id"):
		return
	Net.solicitar_pelea(get_meta("net_id"))


# Lo llama Net cuando el dueño concede la pelea: a partir de aqui soy un combatiente.
func entrar_en_pelea() -> void:
	_combat_triggered = true


# Me reservaron para una pelea donde al final NO cabia. Se le devuelve al dueño para que lo suelte:
# si no, se quedaria reservado y congelado para siempre (el bug de las estatuas, por red).
func salir_de_pelea() -> void:
	_combat_triggered = false
	if has_meta("net_id"):
		Net.resultado_bicho(get_meta("net_id"), false, -1.0)


# Ya le han sacado el cristal: se desvanece aqui. El cuerpo DE VERDAD lo desvanece su dueño
# (Net.notificar_extraido), y su baja acabara despawnando este espejo de todas formas.
func desvanecer() -> void:
	remove_from_group("corpse")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)


# Game._on_combat_finished llama a esto sobre los que CAYERON. Se pinta el cadaver aqui y se le
# dice al dueño, que es quien lo mata de verdad (y quien lo difunde a los demas).
func morir() -> void:
	_combat_triggered = false
	marcar_cadaver()
	# Si HEREDE el piso a media pelea, ya no hay dueño a quien contarselo: yo soy la autoridad
	# ahora, asi que se queda como cadaver aqui y punto (sin esto se mandaria un resultado a nadie).
	if has_meta("net_id") and not Net._soy_dueno:
		Net.resultado_bicho(get_meta("net_id"), true, 0.0)


# ...y a esto sobre los SUPERVIVIENTES, con las heridas que les dejaste. El dueño se las guarda
# para la proxima pelea (vida arrastrada) y lo descongela.
func reanudar_tras_combate(hp: float = -1.0) -> void:
	_combat_triggered = false
	hp_restante = hp
	if has_meta("net_id") and not Net._soy_dueno:
		Net.resultado_bicho(get_meta("net_id"), false, hp)


# Ha caido en la maquina que simula el piso: aqui pasa a verse como cadaver. Mismo gris apagado
# que enemy.morir(), para que los dos jugadores vean lo mismo.
func marcar_cadaver() -> void:
	if muerto:
		return
	muerto = true
	if _cuerpo != null:
		_cuerpo.color = Color(0.4, 0.4, 0.4)
	# Un cadaver no ve ni avisa: fuera cono y linea (igual que enemy.morir).
	if _cono != null:
		_cono.visible = false
	if _linea != null:
		_linea.visible = false
	remove_from_group("enemy")
	add_to_group("corpse")   # ahora se le puede pulsar F para extraerle el cristal


func _redimensionar(lado: float) -> void:
	if _cuerpo == null:
		return
	var medio: float = maxf(1.0, lado) * 0.5
	_cuerpo.offset_left = -medio
	_cuerpo.offset_top = -medio
	_cuerpo.offset_right = medio
	_cuerpo.offset_bottom = medio


# Nuevo destino recibido de la red (lo llama Net al llegar cada paquete de posicion).
func ir_a(pos: Vector2) -> void:
	if _objetivo == Vector2.INF or global_position.distance_to(pos) > SALTO:
		global_position = pos   # primer paquete o salto grande: aparecer alli, sin deslizarse
	_objetivo = pos


func _physics_process(delta: float) -> void:
	if _objetivo == Vector2.INF:
		return
	global_position = global_position.lerp(_objetivo, 1.0 - exp(-SUAVIZADO * delta))
