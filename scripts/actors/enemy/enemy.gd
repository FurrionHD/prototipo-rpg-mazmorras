# ============================================================
#  enemy.gd
#  Enemigo en la EXPLORACION (top-down) con SIGILO:
#   - DEAMBULA por una zona aleatoria alrededor de su sitio.
#   - VISION EN CONO hacia donde mira (su direccion de movimiento). Dibuja
#     el cono y una linea indicadora.
#   - OIDO: te detecta segun tu ruido (tu velocidad). Correr = ruidoso,
#     sigilo = silencioso.
#   - Si te ve/oye, te PERSIGUE (iniciativa del enemigo en combate).
#   - Si le tocas sin que te detecte (por la espalda) -> TU iniciativa.
#  Se engancha a un CharacterBody2D (la escena enemy.tscn).
# ============================================================

extends CharacterBody2D

@export var data: EnemyData

# Cada bicho tira una 't' (0..1) al aparecer: su POSICION dentro de la sub-franja de
# su arquetipo para el piso actual (ver EnemyData.sum_band). t=0 -> el mas flojo de
# su franja, t=1 -> el mas fuerte. Da variedad; la progresion por piso la lleva la
# franja (no un multiplicador). Tambien decide la categoria del cristal.
var current_t: float = 0.5

# 't' IMPUESTA desde fuera (>= 0). La usa la memoria de la mazmorra al restaurar un piso:
# si volviera a tirar randf(), el mismo slime reaparecería con OTRAS stats (la 't' es su
# posicion dentro de la franja de habilidades del piso). -1 = tirala tu, como siempre.
var t_forzada: float = -1.0

# Zona (sala/pasillo) a la que pertenece. La fija el piso al crearlo; sirve para devolverlo
# a SU zona al restaurar el piso.
var zona_idx: int = -1

# --- Deambular ---
@export var wander_radius: float = 90.0       # cuanto se aleja de su sitio (si no tiene zona)
@export var wander_pause_min: float = 0.4     # pausa minima al llegar a un punto
@export var wander_pause_max: float = 1.2     # pausa maxima

# ZONA por la que puede moverse: las posiciones (en mundo) de las celdas PISABLES de su
# sala o pasillo. Si la tiene, deambula ENTRE ELLAS. Si no (spawner de dev, arena), cae
# al modo viejo: puntos al azar en un circulo alrededor de su sitio.
#
# El circulo era el bug: un bicho que nace pegado a la pared (la pared es la que lo pare)
# tenia medio circulo DENTRO de la roca, chocaba, el anti-atasco lo devolvia a su sitio...
# y se quedaba clavado en la pared en vez de merodear por la sala.
var zona_puntos: Array = []

# --- Vision (cono frontal) ---
@export var vision_range: float = 130.0       # alcance del cono
@export var vision_half_angle_deg: float = 50.0  # medio angulo del cono

# --- Oido ---
# Subido de 0.55 a 0.66 al bajar walk_speed de 120 a 100: el radio sale de tu VELOCIDAD, asi que
# ralentizar al jugador lo volvia mas silencioso de rebote (correr pasaba de oirse a 112 a oirse a
# 94) y eso era un buff de sigilo que nadie habia pedido. 0.55 / (100/120) = 0.66 deja el oido
# EXACTAMENTE como estaba en los tres modos: sigilo 30, andar 66, correr 112 (y el tope sigue
# saturando al esprintar con el liston cumplido, igual que antes).
@export var hearing_factor: float = 0.66      # radio de oido = tu_velocidad * esto
@export var hearing_max: float = 130.0        # radio de oido maximo

# --- Persecucion / combate ---
# Si te alejas mas, te pierde. SUBIDO 220 -> 300: con 220 la persecucion moria tan pronto que la
# fuga apenas daba para abrir hueco (te detecta a <=130 px, asi que quedaban ~90 px de margen). Mas
# margen = persecuciones mas largas y una huida que se puede jugar (y que entrena, ver
# player._tick_huida).
@export var lose_range: float = 300.0

# --- COMBATE EN GRUPO ---
# Radio alrededor de un bicho dentro del cual sus vecinos entran CON EL a la pelea. Es tambien
# el radio con el que se pintan las lineas del mapa: lo que ves unido es lo que te va a caer
# encima, ni mas ni menos. Separarlos (atrayendo a uno) rompe el vinculo y peleas 1v1.
const RADIO_REFUERZO := 160.0
# Tope de bichos en una pelea (el tocado + 4). Mas de cinco barras no caben en pantalla y la
# pelea deja de poder leerse. Es el TECHO absoluto: cuantos se JUNTAN de verdad lo modula la
# tendencia de manada (MANADA_POR_GRUPO), que escala con TU grupo; esto solo pone el limite duro.
const MAX_COMBATIENTES := 5
# Segundos que los supervivientes se quedan quietos al acabar el combate: la ventana para huir.
const CONGELADO_TRAS_COMBATE := 3.0

# VIDA con la que quedo de un combate anterior (huiste y lo dejaste herido). -1 = intacto.
# Vive en el NODO y no en el EnemyData (que es un recurso COMPARTIDO por todos los slimes:
# guardarla ahi heriria a toda la especie de golpe).
var hp_restante: float = -1.0

# Ataque del enemigo: distancia "optima" desde la que ataca y aviso previo.
@export var attack_range: float = 44.0
@export var attack_windup: float = 0.15       # segundos de aviso antes de atacar

# ============================================================
#  EMBESTIDA: como se ENTRA en combate
#  Antes bastaba con estar a distancia de ataque el tiempo del aviso, y el aviso se CANCELABA en
#  cuanto te salias del rango. Huyendo, entrabas y salias del margen varias veces por segundo, asi
#  que el contador se reiniciaba sin parar y el bicho no llegaba a engancharte NUNCA.
#  Ahora, en cuanto te pilla a tiro, se COMPROMETE: se planta, avisa, y se lanza en una EMBESTIDA
#  en la direccion que tenias EN ESE MOMENTO. Si te alcanza, empieza el combate; si la esquivas,
#  falla y tiene que volver a montarla. Asi huir es una habilidad y no un bug.
# ============================================================
const EMBESTIDA_VEL_MULT := 2.2    # x lo que corre persiguiendo: la carga es un aceleron
const EMBESTIDA_DUR := 0.35        # segundos que dura la carga (lo que la hace esquivable)
const EMBESTIDA_ESPERA := 0.6      # descanso tras fallar, antes de poder volver a cargar
# Holgura para dar dos cuerpos por TOCANDOSE. NO puede ser 0: ahora el bicho COLISIONA con los
# companeros, y al colisionar Godot deja un margen de seguridad, asi que los cuerpos jamas llegan a
# solaparse (hueco se queda en ~0.08 y nunca baja de 0). Con 0 exacto, la carga se estampaba contra
# el companero y no "conectaba" nunca: el bicho se quedaba empotrado repitiendo aviso -> embestida
# -> fallo, sin entrar en combate.
const CONTACTO := 2.0

signal combat_started(enemy_data: EnemyData, enemy_initiated: bool)

enum State { WANDER, CHASE, RETURN, EMBESTIDA }
var _state: State = State.WANDER

var _home: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.RIGHT  # hacia donde mira (su cono)
# A QUIEN persigue. Ya no es "el jugador": es un miembro cualquiera del grupo (el lider o un
# companero, todos en el grupo "aliado"). El que va rezagado es tan cazable como el que llevas
# delante, asi que descolgarse tiene consecuencias.
var _objetivo: Node2D = null

var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _stuck_time: float = 0.0   # cuanto lleva atascado contra una pared
var _windup_timer: float = -1.0  # -1 = no esta preparando ataque
var _winding: bool = false       # true mientras hace el aviso de ataque
# EMBESTIDA: direccion COMPROMETIDA al acabar el aviso (no se recalcula: por eso se puede esquivar),
# lo que le queda de carga, y el descanso tras fallar una.
var _embiste_dir: Vector2 = Vector2.ZERO
var _embiste_t: float = 0.0
var _embiste_espera: float = 0.0
var _combat_triggered: bool = false
var current_move_speed: float = 40.0

var _dead: bool = false       # true cuando es un cadaver (combate ganado)
var extracted: bool = false   # true cuando ya le has sacado el cristal

# Indicadores visuales (creados por codigo).
var _facing_line: Line2D = null
var _vision_cone: Polygon2D = null

@onready var _color_rect: ColorRect = $ColorRect


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	# COLISION: el bicho choca con la roca (capa 1) y con los COMPANEROS (capa 4). NO con otros
	# bichos: cuando chocaban entre si, dos que se solapaban (al nacer juntos, o al converger sobre
	# ti) se des-penetraban a empujones, se apilaban en columna y alguno salia disparado ATRAVESANDO
	# la pared como un proyectil.
	# Los companeros SI le frenan (antes se los paseaba por encima como si no existieran): un
	# companero plantado en un pasillo tapa de verdad. Es asimetrico a proposito -el companero NO
	# choca con el bicho (su mascara es solo roca)-, asi que el grupo nunca se atasca a si mismo:
	# el bicho se para contra el companero, pero el companero puede seguir andando.
	collision_layer = 2      # capa "enemigos": nadie la vigila, pero los deja identificados
	collision_mask = 1 | 4   # paredes + companeros

	add_to_group("enemy")  # para que el jugador lo encuentre al atacar
	_home = global_position
	_objetivo = _aliado_mas_cercano()

	# Posicion de ESTE bicho dentro de su franja (uniforme = variedad). La progresion
	# por piso la lleva la propia franja (EnemyData.sum_band), no un multiplicador.
	# Si viene restaurado de la memoria del piso, se respeta la suya (mismas stats que tenia).
	current_t = t_forzada if t_forzada >= 0.0 else randf()

	if data != null:
		# Color base + tinte por 't' (los mas fuertes de su franja salen mas claros).
		_color_rect.color = data.color_visual(current_t)
		_aplicar_escala(data.escala_visual)   # los elites se ven mas grandes en el mapa
		current_move_speed = randf_range(data.move_speed_min, data.move_speed_max)
		var band: Vector2 = data.sum_band()
		var ab: Abilities = data.crear_abilities(current_t)
		print(data.enemy_name, " (piso ", Game.current_floor, ") -> t=", snappedf(current_t, 0.01),
			"  suma~", data.suma_habilidades(current_t),
			"  [F", ab.fuerza, " R", ab.resistencia, " D", ab.destreza,
			" A", ab.agilidad, " M", ab.magia, "]",
			"  (franja ", roundi(band.x), "-", roundi(band.y), ")")

	_crear_indicadores()
	_pick_wander_target()


# Cuanto SOBRESALE este cuerpo respecto al tamaño normal (32x32 -> radio 16). Un elite
# grande te mantiene mas lejos de su CENTRO con su propia colision, asi que el jugador
# descuenta esto al medir la distancia de interaccion (ver player._mas_cercano_en_grupo);
# si no, no llegarias a extraerle el cristal. 0 = tamaño normal.
var radio_extra: float = 0.0


# Escala el cuerpo (ColorRect) y su colision. El cuerpo base es 32x32 centrado.
# OJO: la RectangleShape2D viene del .tscn y se COMPARTE entre instancias -> hay que
# duplicarla antes de tocarla, o cambiaria el tamaño de TODOS los enemigos.
func _aplicar_escala(escala: float) -> void:
	var s: float = maxf(0.1, escala)
	if is_equal_approx(s, 1.0):
		return
	radio_extra = 16.0 * (s - 1.0)
	var medio: float = 16.0 * s
	_color_rect.offset_left = -medio
	_color_rect.offset_top = -medio
	_color_rect.offset_right = medio
	_color_rect.offset_bottom = medio
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col != null and col.shape is RectangleShape2D:
		col.shape = col.shape.duplicate()   # instancia propia: no tocar la de los demas
		(col.shape as RectangleShape2D).size = Vector2(32.0 * s, 32.0 * s)


func _physics_process(delta: float) -> void:
	if _combat_triggered or data == null:
		return

	# Aseguramos que hay a quien mirar. Persiguiendo NO se cambia de presa (o bastaria con que el
	# grupo se cruzara para que el bicho se quedara bailando entre dos objetivos).
	if _objetivo == null or not is_instance_valid(_objetivo):
		_objetivo = _aliado_mas_cercano()

	# TOCAR = COMBATE, en el estado que sea. Un bicho no puede estar empotrado contra ti (o contra un
	# companero) y seguir a lo suyo. Va ANTES que todo lo demas y no depende de que te haya visto:
	# cubre el caso de deambular y chocarse de morros en la oscuridad, que con la deteccion por vista
	# y oido no se disparaba nunca (un companero parado no hace ruido y puede estar fuera del cono).
	var pegado: Node2D = _aliado_en_contacto()
	if pegado != null:
		_objetivo = pegado
		_start_combat(true)
		return

	# Si no estamos ya persiguiendo (ni embistiendo), miramos si vemos u oimos a alguno.
	if _state != State.CHASE and _state != State.EMBESTIDA:
		_try_detect()

	match _state:
		State.WANDER: _wander(delta)
		State.CHASE: _chase(delta)
		State.EMBESTIDA: _embestida(delta)
		State.RETURN: _return()

	# El empujon de separacion se suma a lo que sea que estuviera haciendo (merodear, ir a por su
	# manada o perseguirte): vale para todo, y en la persecucion es lo que evita que los cuatro
	# lleguen apilados en el mismo pixel encima de ti.
	velocity += _separacion() * current_move_speed * SEPARACION_FUERZA

	move_and_slide()

	# La direccion de mirada = hacia donde nos movemos (si nos movemos).
	if velocity.length() > 1.0:
		_facing = velocity.normalized()
	_actualizar_indicadores()

	# Anti-atasco al deambular: si chocamos con una pared, apuntamos de vuelta
	# a nuestro sitio (nos despegamos hacia dentro). Si llevamos mucho rato
	# atascados (p. ej. nos expulso fuera en una esquina), volvemos de golpe.
	if _state == State.WANDER:
		if get_slide_collision_count() > 0:
			_stuck_time += delta
			if _stuck_time > 1.5:
				global_position = _home  # red de seguridad
				_stuck_time = 0.0
				_pick_wander_target()
			else:
				_wander_target = _home  # tira hacia casa para despegarse
		else:
			_stuck_time = 0.0



# Comprueba si VE (cono) u OYE (ruido) a ALGUIEN del grupo. Si si, va a por EL que lo delato (no
# a por el lider): cada miembro se delata por su cuenta, con su propio ruido y su propia posicion.
# Por eso mandar al que va en cabeza por un lado no protege al que se queda detras a la vista.
func _try_detect() -> void:
	for aliado in _aliados():
		if _detecta_a(aliado):
			_objetivo = aliado
			_state = State.CHASE
			return


# ¿Ve u oye a ESTE? Si lo pilla, deja ya el _facing girado hacia el.
func _detecta_a(quien: Node2D) -> bool:
	var to_p: Vector2 = quien.global_position - global_position
	var dist: float = to_p.length()
	if dist < 0.01:
		return false
	var dir: Vector2 = to_p / dist

	# Vision: alcance + angulo del cono. Los dos chequeos BARATOS van primero; el raycast
	# (que es lo caro) solo se tira si ya has pasado los dos.
	var en_cono: bool = dist <= vision_range \
		and absf(_facing.angle_to(dir)) <= deg_to_rad(vision_half_angle_deg)

	# ¿Hay roca de por medio? Se calcula UNA vez y la usan la vista y el oido.
	# Solo hace falta saberlo si estas en el cono o dentro del alcance del oido; si no, ni se
	# tira el rayo (un piso con 20 bichos son 20 rayos por frame como mucho).
	var player_speed: float = 0.0
	if "velocity" in quien:
		player_speed = (quien.velocity as Vector2).length()
	var hear_radius: float = minf(player_speed * hearing_factor, hearing_max)

	var tapado: bool = false
	if en_cono or dist <= hear_radius:
		tapado = not _linea_de_vision_libre(quien.global_position)

	# La VISTA no atraviesa la roca. Punto.
	var seen: bool = en_cono and not tapado

	# El OIDO si la atraviesa, pero AMORTIGUADO: un muro no es una cabina insonorizada, pero
	# tampoco deja pasar tus pasos igual que el aire. Sin esta amortiguacion (oir igual a
	# traves de la pared) el sigilo no serviria de nada en interiores; y cortando el sonido
	# del todo, pegarte al otro lado de un muro te volveria literalmente indetectable.
	if tapado:
		hear_radius *= OIDO_TRAS_PARED
	var heard: bool = dist <= hear_radius

	if seen or heard:
		_facing = dir  # se gira hacia el
		return true
	return false


# Todo el grupo (lider + companeros), que es a quien puede cazar. Filtra invalidos de un frame
# suelto: el sequito se rehace cuando cambias de equipo o de piso.
func _aliados() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group("aliado"):
		if is_instance_valid(n) and n is Node2D:
			out.append(n as Node2D)
	return out


# El miembro del grupo que tiene mas a mano. Es a quien va por defecto (al nacer, o si pierde de
# vista al que perseguia).
func _aliado_mas_cercano() -> Node2D:
	var best: Node2D = null
	var mejor_d: float = INF
	for n in _aliados():
		var d: float = global_position.distance_to(n.global_position)
		if d < mejor_d:
			mejor_d = d
			best = n
	return best


# Cuanto se amortigua el oido cuando hay roca de por medio.
const OIDO_TRAS_PARED := 0.5
# Capa de fisica de la ROCA (los muros del piso). El bicho ya colisiona solo con ella.
const CAPA_ROCA := 1


# ¿Se ve el punto desde aqui, sin roca de por medio? Rayo contra la capa de los muros.
#
# OJO CON EL JUGADOR: esta en la capa 1, la MISMA que la roca. Si no se le excluye del rayo,
# el rayo que lanzamos HACIA EL choca con el en cuanto llega, damos la linea por cortada, y
# ningun bicho volveria a verte en su vida. Los otros enemigos no estorban (capa 2).
func _linea_de_vision_libre(punto: Vector2) -> bool:
	var espacio: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, punto, CAPA_ROCA)
	query.exclude = _excluir_del_rayo()
	return espacio.intersect_ray(query).is_empty()


# Cuerpos que un rayo de vision NUNCA debe considerar un obstaculo: TODO el grupo (el jugador
# comparte capa con la roca, y los companeros tienen su propio cuerpo) y uno mismo. Sin esto se
# taparian unos a otros: el que va delante le haria de escudo al de detras contra el cono que lo
# esta mirando.
func _excluir_del_rayo() -> Array[RID]:
	var out: Array[RID] = [get_rid()]
	for n in _aliados():
		if n is CollisionObject2D:
			out.append((n as CollisionObject2D).get_rid())
	return out


func _wander(delta: float) -> void:
	# En pausa: quieto, contando. Al que va de mudanza NO se le hace esperar: se pone en marcha.
	if _wander_timer > 0.0 and not _migrando:
		_wander_timer -= delta
		velocity = Vector2.ZERO
		return

	var to_t: Vector2 = _wander_target - global_position
	if to_t.length() <= 5.0:
		# Llegamos: pausa y nuevo destino.
		_wander_timer = randf_range(wander_pause_min, wander_pause_max)
		_pick_wander_target()
		velocity = Vector2.ZERO
		return

	# De mudanza anda con un pelin mas de intencion (no de paseo), pero sin llegar al esprint de
	# perseguirte: no es a ti a quien va, solo se cambia de sala.
	var vel: float = current_move_speed * (MIGRAR_VEL_MULT if _migrando else 1.0)
	velocity = to_t.normalized() * vel


func _chase(delta: float) -> void:
	if _objetivo == null or not is_instance_valid(_objetivo):
		_state = State.RETURN
		return
	var to_p: Vector2 = _objetivo.global_position - global_position
	var dist: float = to_p.length()

	if dist > lose_range:
		# Antes de rendirse mira si le queda ALGUIEN del grupo cerca: el que perseguia se le ha ido,
		# pero puede tener a un companero al lado. Rendirse teniendo a uno pegado era absurdo.
		var otro: Node2D = _aliado_mas_cercano()
		if otro != null and global_position.distance_to(otro.global_position) <= lose_range:
			_objetivo = otro
			to_p = _objetivo.global_position - global_position
			dist = to_p.length()
		else:
			_state = State.RETURN  # te perdio, vuelve a su sitio
			velocity = Vector2.ZERO
			_cancelar_aviso()
			return

	if dist > 0.01:
		_facing = to_p / dist  # mira a su presa

	# INTERCEPCION: se mira a TODO el grupo, no solo a la presa fijada. Antes solo contaba _objetivo,
	# asi que un bicho que te habia fichado a TI se paseaba por encima de tus companeros sin
	# engancharse: podias tener a uno pegado al morro y no pasaba nada hasta que te alcanzaba a ti.
	# Ahora el que se cruza en su camino se lo come, que es para lo que sirve ir en grupo.
	var presa: Node2D = _aliado_a_tiro()
	if _embiste_espera > 0.0:
		_embiste_espera -= delta   # descansando tras fallar una carga: persigue pero no monta otra
	if presa != null and _embiste_espera <= 0.0:
		# A tiro: se PLANTA y avisa. Ojo: a partir de aqui NO se cancela aunque te salgas del rango
		# (eso es lo que hacia que huyendo no te enganchara nunca). El aviso va hasta el final y
		# termina en EMBESTIDA. Si el grupo va agotado, carga sin avisar (aviso = 0).
		velocity = Vector2.ZERO
		if _windup_timer < 0.0:
			_windup_timer = 0.0 if _player_exhausted() else attack_windup
		_winding = true
		_facing = (presa.global_position - global_position).normalized()
		_windup_timer -= delta
		if _windup_timer <= 0.0:
			_lanzar_embestida(presa)
	elif _winding:
		# Ya estaba comprometido con el aviso: lo termina aunque te hayas salido del rango.
		velocity = Vector2.ZERO
		_windup_timer -= delta
		if _windup_timer <= 0.0:
			_lanzar_embestida(_objetivo)
	else:
		# Aun lejos: a por ti. Perseguir NO va a la velocidad de merodear (ver chase_speed_mult).
		velocity = to_p.normalized() * _chase_speed()


# El miembro del grupo que tiene A TIRO ahora mismo (dentro del margen de ataque), o null. Mira a
# TODOS: cualquiera que se le ponga a huevo vale, no solo al que venia persiguiendo.
func _aliado_en_contacto() -> Node2D:
	for n in _aliados():
		if hueco_hasta(n) <= CONTACTO:
			return n
	return null


func _aliado_a_tiro() -> Node2D:
	var margen: float = margen_ataque()
	var best: Node2D = null
	var mejor: float = INF
	for n in _aliados():
		var h: float = hueco_hasta(n)
		if h <= margen and h < mejor:
			mejor = h
			best = n
	return best


# Arranca la carga: FIJA la direccion hacia donde esta la presa AHORA y se lanza. No se corrige por
# el camino a proposito: esa es justo la ventana para esquivarla.
func _lanzar_embestida(hacia: Node2D) -> void:
	_winding = false
	_windup_timer = -1.0
	var dir: Vector2 = _facing
	if hacia != null and is_instance_valid(hacia):
		var d: Vector2 = hacia.global_position - global_position
		if d.length() > 0.01:
			dir = d.normalized()
	_embiste_dir = dir
	_embiste_t = EMBESTIDA_DUR
	_state = State.EMBESTIDA


# La CARGA: corre recto en la direccion comprometida. Si toca a CUALQUIERA del grupo, empieza el
# combate. Si se acaba (o se estampa contra la roca) sin tocar a nadie, ha fallado: descansa un poco
# y vuelve a perseguir. Es lo que convierte "escapar" en algo que se juega y no en un parpadeo.
func _embestida(delta: float) -> void:
	velocity = _embiste_dir * _chase_speed() * EMBESTIDA_VEL_MULT
	_embiste_t -= delta
	# ¿Ha alcanzado a alguien? Contacto = cuerpos TOCANDOSE (con la holgura de CONTACTO, que los
	# cuerpos que colisionan nunca llegan a solaparse), no el margen de ataque: la carga tiene que
	# CONECTAR, no basta con pasar cerca.
	for n in _aliados():
		if hueco_hasta(n) <= CONTACTO:
			_objetivo = n
			_start_combat(true)   # iniciativa del enemigo: te ha embestido
			return
	# Se estampo contra una pared: la carga muere ahi.
	var choco: bool = get_slide_collision_count() > 0
	if _embiste_t <= 0.0 or choco:
		_embiste_espera = EMBESTIDA_ESPERA
		_state = State.CHASE
		velocity = Vector2.ZERO


# ¿Estoy persiguiendo a ESTE de ahi? Lo pregunta el jugador para saber si esta HUYENDO de verdad
# (la excelia de Agilidad, ver player._tick_huida): perseguir a su companero no le vale, tiene que
# ser a el. Tras un combate salgo en WANDER (ver _congelar_tras_combate), asi que la ventana de
# escape no cuenta como persecucion y no se puede farmear.
func persigue_a(quien: Node) -> bool:
	# EMBESTIDA cuenta como perseguir: es la MISMA persecucion, solo que en su fase de carga. Sin
	# esto, el jugador daba por terminada la huida cada vez que el bicho embestia (varias veces por
	# persecucion), se le reseteaba la marca de agua y la Agilidad no subia NADA huyendo.
	return (_state == State.CHASE or _state == State.EMBESTIDA) and _objetivo == quien


# A que velocidad persigue. Lo pregunta el jugador para saber lo que le CUESTA la fuga: huir de
# algo que casi te alcanza entrena mas que dejar atras a un lento (Game.huida_dificultad_mult).
func vel_persecucion() -> float:
	return _chase_speed()


# Velocidad de persecucion = la suya de merodeo x lo que declare su .tres.
func _chase_speed() -> float:
	var mult: float = data.chase_speed_mult if data != null else 1.0
	return current_move_speed * maxf(1.0, mult)


# ------------------------------------------------------------
#  ALCANCE: el HUECO entre los dos cuerpos, no la distancia entre centros.
#
#  Medir centro a centro tenia un agujero: dos cuerpos de 32x32 pegados POR LA ESQUINA
#  tienen los centros a raiz(32²+32²) = 45.2 px. Con attack_range = 44, el bicho estaba
#  literalmente encima de ti y creia que no llegaba: no atacaba nunca en diagonal. Con los
#  ELITES era peor (el slime de fuego mide 1.6x: la esquina son ~59 px), asi que el bicho mas
#  peligroso del juego tenia un angulo muerto en el que era inofensivo.
#
#  Midiendo el hueco entre los dos rectangulos, tocarse de esquina cuenta igual que tocarse
#  de frente, y el tamaño del bicho entra en la cuenta solo.
# ------------------------------------------------------------
const _MEDIO_CUERPO := 16.0   # el cuerpo base es 32x32 (jugador y bicho normal)


# Cuanto SEPARA a los dos cuerpos. 0 = tocandose (de lado o de esquina); < 0 = solapados.
func hueco_hasta(otro: Node2D) -> float:
	if otro == null or not is_instance_valid(otro):
		return INF
	var d: Vector2 = (otro.global_position - global_position).abs()
	var suma: float = _MEDIO_CUERPO + _MEDIO_CUERPO + radio_extra   # medio jugador + medio bicho (+ lo que sobresale el elite)
	return maxf(d.x - suma, d.y - suma)


# Margen de alcance REAL: el attack_range de siempre era "32 px de cuerpos + margen", asi que
# el margen es lo que sobra de 32. Los numeros ya afinados siguen valiendo igual.
func margen_ataque() -> float:
	return attack_range - _MEDIO_CUERPO * 2.0


func _cancelar_aviso() -> void:
	_windup_timer = -1.0
	_winding = false
	_embiste_t = 0.0
	_embiste_espera = 0.0


# El aguante es de GRUPO (correr lo pagan todos, ver player.gd), asi que se pregunta al cuerpo
# que llevas: si el grupo va sin fuelle, el bicho golpea sin avisar, persiga a quien persiga.
func _player_exhausted() -> bool:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p != null and is_instance_valid(p) and p.has_method("is_exhausted") and p.is_exhausted()


# Recoloca el bicho y fija AHI su "hogar" (el punto al que deambula/regresa). Lo
# usa el spawner de dev: _ready ya fijo _home en la posicion vieja, asi que hay
# que re-hogarlo tras moverlo (si no, intenta volver a (0,0) y cruza las paredes).
func recolocar(pos: Vector2) -> void:
	global_position = pos
	_home = pos
	_state = State.WANDER
	_stuck_time = 0.0
	_pick_wander_target()


# Lo llama el JUGADOR cuando te ataca de cerca: combate con su iniciativa.
func atacado_por_jugador() -> void:
	if _dead:
		return
	_start_combat(false)


# Nace de un BROTE: en vez de ponerse a merodear, sale directo A POR TI. Es lo que convierte el
# brote en un susto de verdad: revienta un cacho de pared y te caen encima cuatro a la vez. El
# primero que te alcance recluta a los que salieron con el (vecinos()) y la pelea es en grupo.
func nacer_embistiendo() -> void:
	_objetivo = _aliado_mas_cercano()
	if _objetivo != null:
		_state = State.CHASE


# True si este bicho es el BOSS de su piso (lo pone DungeonFloor al colocarlo). Un boss no lo
# recicla el spawner y, al morir, abre el piso: bajada, salida al pueblo y atajo desde el
# pueblo (ver Game.marcar_boss_derrotado).
var es_boss: bool = false


# Lo llama Game al GANAR el combate: el enemigo queda como CADAVER (no se
# borra), apagado e interactuable para extraerle el cristal (minijuego).
func morir() -> void:
	_dead = true
	_winding = false
	set_physics_process(false)  # detiene la IA
	velocity = Vector2.ZERO
	_color_rect.color = Color(0.4, 0.4, 0.4)  # cuerpo gris/apagado
	if _vision_cone != null:
		_vision_cone.visible = false
	if _facing_line != null:
		_facing_line.visible = false
	remove_from_group("enemy")  # ya no es un enemigo activo
	add_to_group("corpse")      # ahora es un cadaver interactuable

	# El boss cae: el piso se abre AHORA MISMO (sin salir ni volver a entrar).
	if es_boss:
		Game.marcar_boss_derrotado(Game.current_floor)
		var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
		if piso != null and piso.has_method("abrir_salidas"):
			piso.abrir_salidas()


func esta_muerto() -> bool:
	return _dead


# "t" (0..1): donde cae este bicho dentro de su franja (flojo..fuerte).
# Lo usa la categoria del cristal (t alto = cristal de mejor categoria).
func poder_normalizado() -> float:
	return clampf(current_t, 0.0, 1.0)


# Tras extraer el cristal: el cuerpo se desvanece (baja opacidad) y desaparece.
func desvanecer() -> void:
	remove_from_group("corpse")  # ya no interactuable
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)  # fundido a transparente
	t.tween_callback(queue_free)


func _return() -> void:
	var to_home: Vector2 = _home - global_position
	if to_home.length() <= 5.0:
		global_position = _home
		velocity = Vector2.ZERO
		_state = State.WANDER
		_pick_wander_target()
	else:
		velocity = to_home.normalized() * current_move_speed


# ============================================================
#  MANADAS
#  La mazmorra sabe con cuanta gente has bajado y se organiza en consecuencia: cada bicho quiere
#  una compañia (manada_objetivo) que se tira de una tabla segun el tamaño de TU equipo. Bajas
#  solo y te encuentras bichos sueltos o en pareja; bajas con cuatro y te encuentras corros de
#  cuatro y de cinco. Es lo que hace que el combate en grupo sea LA norma y no una casualidad.
#
#  El tope duro es 5 (MAX_COMBATIENTES, lo que cabe en una pelea): un corro de seis tendria a uno
#  mirando desde fuera. Pero ese es solo el TECHO; cuantos se juntan DE VERDAD lo decide la tabla de
#  abajo segun TU grupo. Yendo solo, manada_objetivo bajo => el bicho NO busca a otros y su corro se
#  queda pequeño; NO se le junta media sala encima por el mero hecho de que quepan (esa es la clave:
#  que un jugador solo no coma un corro de 5 forzado). Si de casualidad ya hay 5 pegados, entran 5.
#
#  Cuenta como "manada" lo que este dentro de RADIO_REFUERZO, la MISMA constante con la que
#  vecinos() recluta al empezar el combate. Tiene que ser la misma o la promesa se rompe: lo que
#  el bicho considera su grupo y lo que se te echa encima son la misma cosa.
# ============================================================

# Reparto del tamaño de manada que quiere un bicho, segun cuantos bajasteis. Los pesos son de
# PLAYTEST -> Excel (PROVISIONALES). Indice = tamaño de tu equipo (1..4). La tendencia a juntarse
# SUBE con tu grupo: solo => casi siempre 1-2 (el 3 raro, NUNCA forzado); cuatro => mayoria 4-5.
const MANADA_POR_GRUPO := {
	1: [[1, 55], [2, 40], [3, 5]],
	2: [[2, 50], [3, 35], [4, 15]],
	3: [[3, 40], [4, 40], [5, 20]],
	4: [[3, 20], [4, 40], [5, 40]],
}
# Hasta donde se mueve un bicho para juntarse con otro corro. Acotado a proposito: sin tope
# cruzarian el piso entero y las salas del fondo se quedarian desiertas.
const RADIO_MIGRACION := 420.0
# Mudarse a otra sala se hace a la velocidad de MERODEO de siempre (1.0): no es una urgencia, es un
# bicho que se cambia de sitio. Correr para juntarse se veia raro (de que huye, si no te ha visto).
const MIGRAR_VEL_MULT := 1.0

# ============================================================
#  SEPARACION: los cuerpos no se meten unos dentro de otros
#  Los bichos no colisionan entre si a proposito (dos que se solapan se des-penetran a empujones y
#  acaban cruzando una pared, ver _ready), pero sin colision Y con las manadas tirando de ellos al
#  mismo punto, acababan apilados: cuatro bichos donde se ve uno.
#  La solucion es un empujon SUAVE, no una colision: si te pegas demasiado a otro, te separas un
#  poco. No bloquea a nadie, no puede atascar a nadie contra la roca, y el corro se ve como cuatro
#  bichos juntos en vez de como un pegote.
# ============================================================
const SEPARACION_MIN := 40.0   # a partir de aqui se apartan (el cuerpo mide 32)
# Cuanto pesa el empujon. SUAVE a proposito: los enemigos no son tangibles entre si (no colisionan),
# asi que un solape puntual no molesta; esto solo evita que un corro entero quede clavado en un
# unico pixel. Fuerte, se ponia a orbitar el punto en vez de merodear la sala.
const SEPARACION_FUERZA := 0.6

# Cuanta compañia quiere, y con que tamaño de equipo se tiro (para re-tirarlo si cambias de
# grupo en mitad del piso, que se puede: el Hogar y las teclas 1/2/3 estan siempre a mano).
var manada_objetivo: int = 1
var _manada_tirada_con: int = -1
# True mientras se muda a la sala de un corro (no de paseo por su sala).
var _migrando: bool = false


# Empujon (vector normalizado, o casi) que lo aparta de los bichos que tenga ENCIMA. Cuanto mas
# pegado, mas fuerte empuja; a partir de SEPARACION_MIN, cero. Ver el bloque de arriba.
func _separacion() -> Vector2:
	var out: Vector2 = Vector2.ZERO
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self or not is_instance_valid(n):
			continue
		var d: Vector2 = global_position - (n as Node2D).global_position
		var dist: float = d.length()
		if dist >= SEPARACION_MIN:
			continue
		if dist < 0.01:
			# Exactamente encima (han nacido en el mismo punto): se aparta hacia donde sea, o la
			# division de abajo seria entre cero y se quedarian pegados para siempre.
			var a: float = randf() * TAU
			out += Vector2(cos(a), sin(a))
			continue
		out += (d / dist) * (1.0 - dist / SEPARACION_MIN)
	return out.limit_length(1.0)


# Los vecinos vivos que tiene a mano AHORA, sin contarse el: los que estan dentro de
# RADIO_REFUERZO, que es EXACTAMENTE lo que dibuja la linea del mapa y lo que entra al combate. Es
# lo que usa para saber si aun le falta compañia y tiene que mudarse a otra sala.
func _companeros_de_manada() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self or not is_instance_valid(n) or n.esta_muerto() or n._combat_triggered:
			continue
		if global_position.distance_to(n.global_position) <= RADIO_REFUERZO:
			out.append(n)
	return out


# Tira (o re-tira) cuanta compañia quiere este bicho. Se re-tira solo si ha cambiado el tamaño de
# tu equipo: si se tirase cada dos por tres, todos acabarian en la media y no habria variedad.
func _actualizar_manada_objetivo() -> void:
	var grupo: int = clampi(Game.party.size(), 1, 4)
	if grupo == _manada_tirada_con:
		return
	_manada_tirada_con = grupo
	var tabla: Array = MANADA_POR_GRUPO[grupo]
	var total: int = 0
	for fila in tabla:
		total += int(fila[1])
	var tirada: int = randi() % maxi(1, total)
	for fila in tabla:
		tirada -= int(fila[1])
		if tirada < 0:
			manada_objetivo = int(fila[0])
			return
	manada_objetivo = int(tabla[0][0])


# El corro incompleto mas cercano al que podria MUDARSE, o null si no hay ninguno que le convenga.
# Reglas, y cada una arregla un bug concreto:
#   - A tiro de RADIO_MIGRACION y con LINEA DE VISION libre: si no, tiraria en recta contra un muro
#     y el anti-atasco lo mandaria de vuelta a casa en bucle. Yendo solo a lo que VE, el camino
#     existe siempre.
#   - NO cuenta a los que ya tiene al lado (dentro de RADIO_REFUERZO): esos ya son su manada. Sin
#     esto, dos bichos que quieren un corro de 3 y solo se tienen el uno al otro se apuntaban
#     MUTUAMENTE para siempre y acababan orbitando pegados en un punto en vez de merodear la sala.
#   - Solo a corros que aun tienen sitio (no llenos, no mas grandes de lo que el quiere).
func _corro_al_que_unirse():
	var ya_conmigo: Array = _companeros_de_manada()   # los que ya cuentan como mi corro
	var mejor = null
	var best: float = INF
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self or not is_instance_valid(n) or n.esta_muerto() or n._combat_triggered:
			continue
		if ya_conmigo.has(n):
			continue   # ya lo tengo al lado: no hay a donde mudarse
		var d: float = global_position.distance_to(n.global_position)
		if d > RADIO_MIGRACION or d >= best:
			continue
		# No se le mete en un corro que ya esta lleno (ni en uno mas grande de lo que el quiere).
		var suyos: int = n._companeros_de_manada().size() + 1
		if suyos >= mini(manada_objetivo, MAX_COMBATIENTES):
			continue
		if not _linea_de_vision_libre(n.global_position):
			continue
		best = d
		mejor = n
	return mejor


# Se muda al corro de 'otro': adopta SU zona (por donde merodear y a donde volver). Asi el
# merodeo, el anti-atasco y el guardado del piso siguen funcionando sin ningun caso especial:
# a partir de ahora es un bicho mas de esa sala.
func unirse_a(otro) -> void:
	if otro == null or not is_instance_valid(otro):
		return
	zona_puntos = otro.zona_puntos
	_home = otro._home
	zona_idx = otro.zona_idx


# La celda PISABLE de su zona mas cercana a un punto. El punto del corro se calcula como el centro
# de la manada mas un pellizco, y ese resultado puede caer perfectamente dentro de la roca: sin
# esto, el bicho tiraria contra un muro y el anti-atasco lo mandaria de vuelta a casa, deshaciendo
# el corro que acababa de formar. Sin zona asignada (spawner de dev) se devuelve el punto tal cual.
func _celda_pisable_cerca(p: Vector2) -> Vector2:
	if zona_puntos.is_empty():
		return p
	var mejor: Vector2 = p
	var best: float = INF
	for c in zona_puntos:
		var d: float = p.distance_squared_to(c)
		if d < best:
			best = d
			mejor = c
	return mejor


# Elige el siguiente destino. La idea es simple a proposito: no hay imanes ni orbitas que hagan
# que se muevan raro. Solo dos casos:
#   1) Le falta compañia -> se MUDA a la sala del corro incompleto mas cercano que vea, y punto.
#      Una vez alli, merodea normal (caso 2): el corro se forma porque COMPARTEN sala, no porque
#      se persigan. Compartir una sala pequeña ya los deja dentro del radio de la linea del mapa.
#   2) Merodeo normal -> una celda pisable al azar de su zona. Sin zona asignada (spawner de dev,
#      arena), un punto al azar alrededor de su sitio.
func _pick_wander_target() -> void:
	_actualizar_manada_objetivo()
	_migrando = false

	if _companeros_de_manada().size() + 1 < manada_objetivo:
		var destino = _corro_al_que_unirse()
		if destino != null:
			unirse_a(destino)   # adopta SU sala; a partir de aqui es un bicho mas de esa zona
			# Entra a la sala por su celda pisable mas cercana al corro. No apunta al bicho (que se
			# mueve): apunta a un sitio FIJO de la sala nueva, y de ahi ya merodea normal.
			_wander_target = _celda_pisable_cerca(destino.global_position)
			_migrando = true
			return

	if not zona_puntos.is_empty():
		_wander_target = zona_puntos[randi() % zona_puntos.size()]
		return
	var ang: float = randf() * TAU
	var rad: float = randf_range(wander_radius * 0.3, wander_radius)
	_wander_target = _home + Vector2(cos(ang), sin(ang)) * rad


# Le asigna la zona por la que puede merodear y su "hogar" (a donde regresa si te pierde).
# El hogar va DENTRO de la sala, no en la pared por la que nacio: si no, el bicho vuelve a
# pegarse a la roca en cuanto deja de perseguirte.
func asignar_zona(puntos: Array, hogar: Vector2) -> void:
	zona_puntos = puntos
	_home = hogar
	_pick_wander_target()


# VECINOS que entran contigo a la pelea: yo + hasta MAX_COMBATIENTES-1 de los que tenga cerca,
# los MAS CERCANOS A MI (no al jugador): los que estaban en mi corro acuden, los del fondo de la
# sala ni se enteran. Es la misma regla que dibuja las lineas del mapa (ver enemy_links.gd), asi
# que lo que entra al combate es exactamente lo que la linea te avisaba de que iba a entrar.
func vecinos() -> Array:
	var out: Array = [self]
	# Las pruebas de DPS/armadura son 1v1 por defecto: el DPS se mide por turno enemigo, y con
	# cuatro muñecos pegando saldria dividido entre cuatro sin que nada avisara del error. Con
	# debug_dummy_group ON se permiten refuerzos aposta (para probar hechizos de area/dispersion).
	if Game.debug_dummy_mode > 0 and not Game.debug_dummy_group:
		return out
	var cand: Array = []
	for n in get_tree().get_nodes_in_group("enemy"):
		# Filtrar a los que YA estan en un combate es imprescindible: si no, un bicho que se
		# quedo enganchado de una pelea anterior volveria a entrar en esta.
		if n == self or not is_instance_valid(n) or n._combat_triggered:
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d <= RADIO_REFUERZO:
			cand.append([d, n])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(MAX_COMBATIENTES - 1, cand.size()):
		out.append(cand[i][1])
	return out


func _start_combat(enemy_initiated: bool) -> void:
	if _combat_triggered:
		return
	var grupo: Array = vecinos()
	# Se congela al GRUPO ENTERO, no solo a mi: los vecinos entran a la pelea, asi que no pueden
	# seguir merodeando (ni disparar su propio combate) por el mapa mientras tanto.
	for n in grupo:
		n._combat_triggered = true
		n.velocity = Vector2.ZERO
		n._cancelar_aviso()
	combat_started.emit(data, enemy_initiated)
	Game.start_combat(grupo, enemy_initiated)


# Vuelve a la vida normal tras un combate del que NO moriste (huiste, o te mato otro).
# Se queda quieto CONGELADO_TRAS_COMBATE segundos: es la ventana para escapar de verdad, si no
# huir no serviria de nada (te alcanzaria al instante y volveria a empezar la pelea).
# 'hp' son las heridas que le dejaste: se guardan y se le aplican en el proximo combate.
func reanudar_tras_combate(hp: float = -1.0) -> void:
	if _dead:
		return
	hp_restante = hp
	await get_tree().create_timer(CONGELADO_TRAS_COMBATE).timeout
	if not is_instance_valid(self) or _dead:
		return
	# Sale en WANDER (no persiguiendote): la ventana de escape no serviria si al acabar te
	# tuviera ya localizado. Si sigues cerca y te ve u oye, volvera a por ti por su cuenta.
	_combat_triggered = false
	_state = State.WANDER
	_pick_wander_target()


# --- Visual: cono de vision + linea de direccion ---
# El cono se dibuja RECORTADO por la roca: cada uno de sus rayos se para donde topa con la
# pared. Si se pintara entero (atravesando el muro) el dibujo mentiria -parece que te ve y no
# te ve-, y el sigilo se juega MIRANDO el cono: tiene que enseñar donde te pueden pillar de
# verdad. Se recalcula solo cuando el bicho se ha movido o girado lo suficiente, no cada
# frame: son SEGMENTOS_CONO rayos y no hace falta rehacerlos por medio pixel.
const SEGMENTOS_CONO := 14
const RECALCULO_ANGULO := 0.10   # rad girados que obligan a rehacer el cono
const RECALCULO_DIST := 6.0      # px movidos que obligan a rehacerlo

var _cono_hecho: bool = false    # ¿ya hay un cono pintado? (el primero se traza siempre)
var _cono_ang: float = 0.0       # angulo con el que se trazo el cono que hay pintado
var _cono_pos: Vector2 = Vector2.ZERO


func _crear_indicadores() -> void:
	# Cono (poligono translucido), por detras del enemigo.
	_vision_cone = Polygon2D.new()
	_vision_cone.color = Color(1.0, 1.0, 0.3, 0.12)
	add_child(_vision_cone)
	move_child(_vision_cone, 0)  # al fondo

	# Linea de direccion (hacia donde mira).
	_facing_line = Line2D.new()
	_facing_line.add_point(Vector2.ZERO)
	_facing_line.add_point(Vector2(26.0, 0.0))
	_facing_line.width = 3.0
	_facing_line.default_color = Color(1.0, 1.0, 0.0)
	add_child(_facing_line)


func _actualizar_indicadores() -> void:
	var ang: float = _facing.angle()
	if _facing_line != null:
		_facing_line.rotation = ang
		# Rojo/naranja mientras avisa el ataque (telegrafia el golpe).
		_facing_line.default_color = Color(1.0, 0.3, 0.1) if _winding else Color(1.0, 1.0, 0.0)
	if _vision_cone != null:
		_vision_cone.color = Color(1.0, 0.25, 0.1, 0.18) if _winding else Color(1.0, 1.0, 0.3, 0.12)
		if not _cono_hecho \
				or absf(angle_difference(ang, _cono_ang)) > RECALCULO_ANGULO \
				or global_position.distance_to(_cono_pos) > RECALCULO_DIST:
			_redibujar_cono(ang)


# Traza el cono rayo a rayo y corta cada uno donde encuentra roca. El poligono va en
# coordenadas LOCALES (es hijo del bicho), asi que los puntos se pasan a local; y por eso
# mismo el Polygon2D NO se rota: sus puntos ya vienen con el giro dentro.
func _redibujar_cono(ang: float) -> void:
	_cono_hecho = true
	_cono_ang = ang
	_cono_pos = global_position
	var espacio: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var half: float = deg_to_rad(vision_half_angle_deg)
	# Mismo motivo que en _linea_de_vision_libre: el jugador comparte capa con la roca y, sin
	# excluirlo, el cono se recortaria CONTRA TI (te taparias a ti mismo del cono que te ve).
	var fuera: Array[RID] = _excluir_del_rayo()

	var pts: PackedVector2Array = [Vector2.ZERO]
	for i in range(SEGMENTOS_CONO + 1):
		var a: float = ang - half + (2.0 * half) * float(i) / float(SEGMENTOS_CONO)
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var fin: Vector2 = global_position + dir * vision_range
		var query := PhysicsRayQueryParameters2D.create(global_position, fin, CAPA_ROCA)
		query.exclude = fuera
		var hit: Dictionary = espacio.intersect_ray(query)
		if not hit.is_empty():
			fin = hit["position"]
		pts.append(fin - global_position)   # a local
	_vision_cone.polygon = pts
