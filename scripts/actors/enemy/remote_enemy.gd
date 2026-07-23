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
# Mismo nombre que en enemy.gd A PROPOSITO: al estar en el grupo "enemy", varios sistemas
# (enemy_links, el culling del piso) preguntan por este campo. Duck-typing: si vas a entrar en el
# grupo, cumple su contrato.
var _combat_triggered: bool = false    # se la reservo el dueño y la estoy peleando yo


func _ready() -> void:
	z_as_relative = false
	z_index = 0   # a la altura del jugador y los bichos reales (ver companion.gd)
	# Marca para que el piso NO me meta en su foto: estoy en los grupos enemy/corpse para poder
	# pelearme y extraerme, pero el dueño del piso es quien guarda a los bichos de verdad.
	set_meta("es_espejo", true)

	_cuerpo = ColorRect.new()
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cuerpo)
	_redimensionar(32.0)


# Aspecto que ya calculo quien simula el piso: color base+tinte por 't' y lado del cuerpo (los
# elites son mas grandes). Asi se ve IGUAL en las dos maquinas sin tirar otra 't'.
func configurar(color: Color, lado: float) -> void:
	if _cuerpo != null:
		_cuerpo.color = color
		_redimensionar(lado)
	radio_extra = maxf(0.0, (lado - 32.0) * 0.5)


# Los datos con los que se puede pelear/extraer. 'ruta' es el .tres del EnemyData.
func aplicar_datos(ruta: String, t: float, ya_muerto: bool) -> void:
	if not ruta.is_empty():
		data = load(ruta) as EnemyData
	current_t = t
	if ya_muerto:
		marcar_cadaver()
	else:
		add_to_group("enemy")


# Lo mismo que enemy.poder_normalizado(): donde cae dentro de su franja. Lo pide la extraccion
# para decidir la categoria del cristal.
func poder_normalizado() -> float:
	return clampf(current_t, 0.0, 1.0)


func esta_muerto() -> bool:
	return muerto


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


# Game._on_combat_finished llama a esto sobre los que CAYERON. Se pinta el cadaver aqui y se le
# dice al dueño, que es quien lo mata de verdad (y quien lo difunde a los demas).
func morir() -> void:
	_combat_triggered = false
	marcar_cadaver()
	if has_meta("net_id"):
		Net.resultado_bicho(get_meta("net_id"), true, 0.0)


# ...y a esto sobre los SUPERVIVIENTES, con las heridas que les dejaste. El dueño se las guarda
# para la proxima pelea (vida arrastrada) y lo descongela.
func reanudar_tras_combate(hp: float = -1.0) -> void:
	_combat_triggered = false
	hp_restante = hp
	if has_meta("net_id"):
		Net.resultado_bicho(get_meta("net_id"), false, hp)


# Ha caido en la maquina que simula el piso: aqui pasa a verse como cadaver. Mismo gris apagado
# que enemy.morir(), para que los dos jugadores vean lo mismo.
func marcar_cadaver() -> void:
	if muerto:
		return
	muerto = true
	if _cuerpo != null:
		_cuerpo.color = Color(0.4, 0.4, 0.4)
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
