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
@export var hearing_factor: float = 0.55      # radio de oido = tu_velocidad * esto
@export var hearing_max: float = 130.0        # radio de oido maximo

# --- Persecucion / combate ---
@export var lose_range: float = 220.0         # si te alejas mas, te pierde

# --- COMBATE EN GRUPO ---
# Radio alrededor de un bicho dentro del cual sus vecinos entran CON EL a la pelea. Es tambien
# el radio con el que se pintan las lineas del mapa: lo que ves unido es lo que te va a caer
# encima, ni mas ni menos. Separarlos (atrayendo a uno) rompe el vinculo y peleas 1v1.
const RADIO_REFUERZO := 160.0
# Tope de bichos en una pelea (el tocado + 3). Mas de cuatro barras no caben en pantalla y la
# pelea deja de poder leerse.
const MAX_COMBATIENTES := 4
# Segundos que los supervivientes se quedan quietos al acabar el combate: la ventana para huir.
const CONGELADO_TRAS_COMBATE := 3.0

# VIDA con la que quedo de un combate anterior (huiste y lo dejaste herido). -1 = intacto.
# Vive en el NODO y no en el EnemyData (que es un recurso COMPARTIDO por todos los slimes:
# guardarla ahi heriria a toda la especie de golpe).
var hp_restante: float = -1.0

# Ataque del enemigo: distancia "optima" desde la que ataca y aviso previo.
@export var attack_range: float = 44.0
@export var attack_windup: float = 0.15       # segundos de aviso antes de atacar

signal combat_started(enemy_data: EnemyData, enemy_initiated: bool)

enum State { WANDER, CHASE, RETURN }
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

	# COLISION: el bicho choca SOLO con la roca (capa 1). Ni con otros bichos ni contigo.
	# Cuando chocaban entre si, dos que se solapaban (al nacer juntos, o al converger sobre
	# ti) se des-penetraban a empujones: se apilaban en columna y, con el empujon, alguno
	# salia disparado ATRAVESANDO la pared como un proyectil. Sin colision entre ellos, ese
	# problema no existe. Tocarte tampoco hace falta: el combate lo dispara la DISTANCIA
	# (ver _chase), no el contacto fisico.
	collision_layer = 2   # capa "enemigos": nadie la vigila, pero los deja identificados
	collision_mask = 1    # solo el mundo (paredes)

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

	# Si no estamos ya persiguiendo, miramos si vemos u oimos a alguno.
	if _state != State.CHASE:
		_try_detect()

	match _state:
		State.WANDER: _wander(delta)
		State.CHASE: _chase(delta)
		State.RETURN: _return()

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
	# En pausa: quieto, contando.
	if _wander_timer > 0.0:
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

	velocity = to_t.normalized() * current_move_speed


func _chase(delta: float) -> void:
	if _objetivo == null or not is_instance_valid(_objetivo):
		_state = State.RETURN
		return
	var to_p: Vector2 = _objetivo.global_position - global_position
	var dist: float = to_p.length()

	if dist > lose_range:
		_state = State.RETURN  # te perdio, vuelve a su sitio
		velocity = Vector2.ZERO
		_cancelar_aviso()
		return

	if dist > 0.01:
		_facing = to_p / dist  # mira a su presa

	if hueco_hasta(_objetivo) <= margen_ataque():
		# A distancia de ataque: se para y hace el AVISO antes de golpear.
		# Si el jugador esta agotado, ataca al instante (aviso = 0).
		velocity = Vector2.ZERO
		if _windup_timer < 0.0:
			_windup_timer = 0.0 if _player_exhausted() else attack_windup
		_winding = true
		_windup_timer -= delta
		if _windup_timer <= 0.0:
			_start_combat(true)  # iniciativa del enemigo
	else:
		# Aun lejos: a por ti. Perseguir NO va a la velocidad de merodear (ver chase_speed_mult).
		velocity = to_p.normalized() * _chase_speed()
		_cancelar_aviso()


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


# Elige el siguiente destino: una celda pisable AL AZAR de su zona (sala/pasillo). Sin
# zona asignada, el modo viejo: un punto al azar en un circulo alrededor de su sitio.
func _pick_wander_target() -> void:
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
