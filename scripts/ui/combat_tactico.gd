# ============================================================
#  combat_tactico.gd  (tema de la pantalla de combate: combat.turno_mapa)
#  EL TURNO CUANDO SE PELEA EN EL MAPA: quien anda, cuanto, y hasta donde.
#
#  Lo que añade al combate de siempre es SOLO el movimiento. El turno sigue siendo el mismo -- lo
#  reparte el ATB, lo resuelven _accion_atacar / habilidades / magia -- y esto se mete en dos huecos:
#
#    TU TURNO        mientras la barra de acciones esta a la vista, el personaje que tiene el turno
#                    anda libre dentro de su circulo. Elegir accion cierra el turno (el tacto de
#                    Trails): moverte + 1 accion, y el ATB no corre mientras piensas, porque
#                    WAITING_PLAYER ya lo congela.
#    SU TURNO        antes de decidir que hace, el enemigo se ACERCA a su presa con la misma regla de
#                    radio que tu. Con TOPE DURO DE TIEMPO: no hay NavigationAgent en el proyecto y la
#                    IA es de rayos, asi que un bicho atascado contra una pared colgaria la pelea -- y
#                    en multi, a todos. Llegue o no, al acabar el tope actua desde donde este.
#
#  EL BORDE PROPONE HUIR. Acercarte al muro de la arena te pregunta si quieres irte; si dices que si,
#  pasa por _accion_huir de siempre, con su tirada de Agilidad y su excelia. El boton "Huir" se
#  esconde: esta ES la forma de huir en el mapa.
#
#  LA REGLA DE SIEMPRE: aqui no se resuelve daño. Si alguna vez hace falta un if de "tactico" dentro
#  de una funcion que pega, la costura esta mal puesta.
#
#  EN MULTI, DESDE EL PRINCIPIO. Quien mueve cada cuerpo:
#    TUS PERSONAJES   los mueve TU maquina, siempre -- tambien si la pelea la lleva otro y tu la ves
#                     en espejo. Es la que tiene sus cuerpos de verdad, y su posicion ya viaja por el
#                     canal del jugador (Net.jugadores.enviar_estado, con el sequito). El radio te lo
#                     manda quien lleva la pelea con la peticion de turno, y tu posicion le vuelve
#                     sellada con tu accion (pos_para_red / anotar_pos_remota).
#    LOS BICHOS       los mueve quien lleva la pelea, y se lo cuenta a su DUEÑO (el del piso) para
#                     que los ponga en su sitio y los reparta por su tick de siempre
#                     (Net.peleas.mover_bichos_en_pelea).
#    EL CIRCULO       de quien tiene el turno viaja con la barra de turnos (estado_red), para que todos
#                     vean quien anda y hasta donde.
#  Y CADA MAQUINA ENCUENTRA LOS CUERPOS EN SU MUNDO por una direccion que viaja en el roster: un
#  aliado es "el personaje k del jugador tal" y un bicho es su id de red (direccion_red / cuerpo_de).
#
#  PENDIENTE (fases siguientes): a quien alcanzas segun donde estas (fase 5, la geometria de mapa) y
#  las cargas que clavan y la reposicion entre frases (fase 6).
# ============================================================
extends RefCounted

const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# A que paso anda tu personaje en su turno, en px de mundo por segundo. Es el andar del mapa: el
# turno no se juega a la carrera, y a este ritmo se ve bien hasta donde llegas.
const VEL_PASEO := 110.0
# A que paso se acerca el enemigo. Algo mas vivo que tu, porque este lo miras sin tocar nada.
const VEL_ACERCARSE := 150.0
# EL TOPE del acercamiento, en segundos DE PELEA (a x2 dura la mitad). Llegue o no, actua.
const TOPE_ACERCARSE := 1.6
# Se da por atascado al que no avanza ni esto en ATASCO_T segundos: no tiene sentido agotar el tope
# empujando una pared.
const ATASCO_PX := 0.5
const ATASCO_T := 0.25
# Hasta donde se arrima a su presa, de centro a centro. Todavia no es el alcance DE VERDAD (eso es la
# fase 5, con la forma de cada golpe): de momento, pegado a ella sin montarse encima.
const ALCANCE_MELE := 34.0
# Un cuerpo no se monta encima de uno del OTRO bando: no puede meterse a menos de esto. Solo frena al
# que se ACERCA, asi que dos que empiezan solapados se pueden separar.
const SEPARACION := 22.0
# Cuanto se deja el paso por dentro del borde de la arena. Por DEBAJO del margen con el que el borde
# avisa (ArenaCombate.MARGEN): si no, nunca llegarias a tocarlo y no se te podria preguntar si huyes.
const DENTRO_DEL_BORDE := 4.0
# La huella de pies de quien no declara ninguna forma de colision.
const HUELLA_POR_DEFECTO := Vector2(16.0, 12.0)

# MOVIENDO  anda uno de los mios, en esta maquina.
# ACERCANDO se acerca un bicho (solo en la maquina que lleva la pelea).
# AJENO     tiene el turno uno que se mueve en OTRA maquina: aqui solo se pinta su circulo; su cuerpo
#           lo trae la red.
enum Fase { NADA, MOVIENDO, ACERCANDO, AJENO }
var _fase: int = Fase.NADA

# EN EL ESPEJO: el roster que mando quien lleva la pelea. De ahi sale la direccion de cada cuerpo.
var roster_red: Dictionary = {}

# LOS BICHOS MOVIDOS que aun no se le han contado a su dueño: id -> [pos, angulo, andando].
var _bichos_movidos: Dictionary = {}
var _t_envio: float = 0.0
const ENVIO_BICHOS := 1.0 / 20.0   # el mismo ritmo que el tick de enemigos de su dueño

# EL QUE TIENE EL TURNO y su cuerpo del mapa.
var _quien: Combatant = null
var _cuerpo: Node2D = null
var _inicio: Vector2 = Vector2.ZERO   # donde estaba al empezar el turno: el centro del circulo
var _radio: float = 0.0
var _andando: bool = false

# EL ACERCAMIENTO del enemigo.
var _presa: Node2D = null
var _t_acercar: float = 0.0
var _t_atasco: float = 0.0

# LAS POSICIONES, por combatiente. La verdad es el cuerpo del mapa; esto es lo que se apunta cada vez
# que alguien se mueve, para que la geometria (fase 5) y la red (fase 7) lo lean de un sitio sin
# tener que ir buscando nodos. Mismo patron que _defendiendo o _casteos: en el tema, no en Combatant.
var _pos: Dictionary = {}

# Lo que se le cambio a cada nodo visual para que se animara con el arbol en pausa, para devolverlo.
var _modos_guardados: Array = []

var _pregunta: PanelContainer = null
var _conectado_al_borde: bool = false


# ------------------------------------------------------------
#  MONTAR / DESMONTAR
# ------------------------------------------------------------

# Se llama al acabar de montar la pantalla. Deja los cuerpos listos para andar.
func montar() -> void:
	# EL BOTON DE HUIR SE VA: en el mapa se huye acercandose al borde (decision del usuario).
	var b: Button = _pantalla._action_buttons.get(_pantalla.Action.FLEE)
	if is_instance_valid(b):
		b.visible = false
	# LOS DIBUJOS SE ANIMAN AUNQUE EL ARBOL ESTE EN PAUSA. En solitario, abrir la pelea pausa el
	# piso entero, y con el los sprites: un bicho que se acerca se deslizaria como una estatua. Se le
	# da PROCESS_MODE_ALWAYS solo a lo que PINTA (el sprite, el muñeco), no al cuerpo: el cuerpo
	# llevaria dentro su IA y su lectura del teclado, y eso tiene que seguir parado.
	for c in _pantalla._aliados + _pantalla._enemies:
		var cuerpo: Node2D = cuerpo_de(c)
		if cuerpo == null:
			continue
		_pos[c] = cuerpo.global_position
		for hijo in cuerpo.get_children():
			if hijo is AnimatedSprite2D or hijo is MunecoJugador:
				_modos_guardados.append([hijo, (hijo as Node).process_mode])
				(hijo as Node).process_mode = Node.PROCESS_MODE_ALWAYS


func desmontar() -> void:
	for par in _modos_guardados:
		if is_instance_valid(par[0]):
			(par[0] as Node).process_mode = par[1]
	_modos_guardados.clear()
	_quitar_circulo()


# ------------------------------------------------------------
#  DE COMBATIENTE A CUERPO
# ------------------------------------------------------------

# EL UNICO SITIO que responde "donde esta el cuerpo de este combatiente", en cualquier maquina. Lo
# usan tambien las fichas del mapa (combat_figuras_mapa): si cada uno lo buscara por su cuenta, el
# dia que se arregla uno el otro sigue buscando en el sitio viejo.
func cuerpo_de(c: Combatant) -> Node2D:
	if c == null:
		return null
	if _pantalla._espejo:
		return _cuerpo_en_espejo(c)
	var i: int = _pantalla._enemies.find(c)
	if i >= 0:
		# El orden es el mismo por construccion: Game._abrir_pelea crea un Combatant por nodo, en el
		# orden de _active_enemies. Los invocados no tienen nodo y se quedan en null.
		var nodos: Array = Game._active_enemies
		var n = nodos[i] if i < nodos.size() else null
		return n as Node2D if n != null and is_instance_valid(n) else null
	if not _pantalla._aliados.has(c):
		return null
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj == null:
		return null
	var dueno: int = int(_pantalla._dueno_aliado.get(c, 0))
	if dueno == 0:
		return Game.cuerpo_de(pj)
	# El DOBLE de otro humano: su cuerpo es el que me pinta la red, el personaje k de ese jugador.
	return Game.cuerpo_de_red(dueno, int(pj.get_meta("cuerpo_red", -1)))


func _cuerpo_en_espejo(c: Combatant) -> Node2D:
	var i: int = _pantalla._enemies.find(c)
	if i >= 0:
		var filas: Array = roster_red.get("enemigos", [])
		return _nodo_de_bicho(int((filas[i] as Dictionary).get("nid", 0))) if i < filas.size() else null
	i = _pantalla._aliados.find(c)
	if i >= 0:
		var filas: Array = roster_red.get("aliados", [])
		if i >= filas.size():
			return null
		var d: Dictionary = filas[i]
		return Game.cuerpo_de_red(int(d.get("peer", 0)), int(d.get("cuerpo", -1)))
	return null


# El cuerpo de un bicho por su id de red: el de verdad si es mio, o el espejo que me pinta su dueño.
func _nodo_de_bicho(id: int) -> Node2D:
	if id == 0:
		return null
	var n = Net.enemigos._enem_nodos.get(id)   # SIN tipar: puede estar liberado
	if n == null or not is_instance_valid(n):
		n = Net.enemigos._enemigos.get(id, {}).get("nodo")
	return n as Node2D if n != null and is_instance_valid(n) else null


# LA DIRECCION DE RED de un combatiente, para el roster: con ella el espejo encuentra su cuerpo en
# SU mundo. Aliado = {peer, cuerpo}; bicho = {nid}. Solo la pide quien lleva la pelea.
func direccion_red(c: Combatant) -> Dictionary:
	var i: int = _pantalla._enemies.find(c)
	if i >= 0:
		var cuerpo: Node2D = cuerpo_de(c)
		return {"nid": int(cuerpo.get_meta("net_id", 0)) if cuerpo != null else 0}
	var pj: PersonajeData = Game.pj_de_combatant(c)
	var dueno: int = int(_pantalla._dueno_aliado.get(c, 0))
	if dueno == 0:
		return {"peer": _mi_id(), "cuerpo": Game.indice_de_cuerpo(pj)}
	return {"peer": dueno, "cuerpo": int(pj.get_meta("cuerpo_red", -1)) if pj != null else -1}


static func _mi_id() -> int:
	if Net.activo and Net.multiplayer.multiplayer_peer != null:
		return Net.multiplayer.get_unique_id()
	return 0


# ¿Este personaje lo muevo YO, en esta maquina? En la que lleva la pelea, los que no son de otro
# humano; en el espejo, los que el roster dice que son mios.
func _es_mio(c: Combatant) -> bool:
	if not _pantalla._espejo:
		return int(_pantalla._dueno_aliado.get(c, 0)) == 0
	var i: int = _pantalla._aliados.find(c)
	var filas: Array = roster_red.get("aliados", [])
	return i >= 0 and i < filas.size() and int((filas[i] as Dictionary).get("peer", -1)) == _mi_id()


# Donde esta. Lo que diga su cuerpo, y si no tiene (un invocado), lo ultimo apuntado.
# El personaje de OTRO humano, en quien lleva la pelea, esta donde dijo al elegir su accion (la
# posicion sellada, ver anotar_pos_remota), no donde lo tenga ahora mismo su cuerpo interpolado.
func pos_de(c: Combatant) -> Vector2:
	if not _pantalla._espejo and _pos.has(c) and _pantalla._aliados.has(c) and not _es_mio(c):
		return _pos[c]
	var cuerpo: Node2D = cuerpo_de(c)
	if is_instance_valid(cuerpo):
		return cuerpo.global_position
	return _pos.get(c, Vector2.ZERO)


# Cuanto anda en SU turno. Sale de su Agilidad contra el liston del piso, y cero si algo le clava.
func radio_de(c: Combatant) -> float:
	if c == null or c.abilities == null:
		return 0.0
	# CLAVADO: enraizado no anda (el mismo estado que le quita el basico), y quien esta cargando un
	# golpe tampoco -- es lo que hace que la carga se pague (decision del usuario).
	if c.enraizado() or c.charging != null:
		return 0.0
	return StatsMath.radio_movimiento(float(c.abilities.agilidad),
		Game.agilidad_esperada_piso(), c.overload_factor)


# ------------------------------------------------------------
#  TU TURNO
# ------------------------------------------------------------

# Empieza el turno de uno de los tuyos. Dos sitios lo llaman:
#   - quien lleva la pelea, desde _begin_player_turn (ya se sabe que el turno se juega: ni aturdido ni
#     cargando). Calcula el radio el, que tiene la Agilidad de verdad.
#   - el ESPEJO, desde turno_mio, cuando le piden la accion de uno de los suyos. El radio le llega con
#     la peticion ('radio'): su maniqui no tiene stats de las que sacarlo.
# Si el personaje lo mueve OTRA maquina, aqui solo se pinta su circulo (fase AJENO).
func empezar_turno(c: Combatant, radio: float = -1.0) -> void:
	_terminar()
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return
	_quien = c
	_cuerpo = cuerpo
	_inicio = cuerpo.global_position
	if radio >= 0.0:
		_radio = radio
	else:
		# Recitando (entre frases) no se anda todavia: la reposicion entre frases es la fase 6.
		_radio = 0.0 if _pantalla._cast_spell != null else radio_de(c)
	_fase = Fase.MOVIENDO if _es_mio(c) else Fase.AJENO
	_andando = false
	if _fase == Fase.MOVIENDO:
		_animar(cuerpo, _mirada_de(cuerpo), false)
	var arena: ArenaCombate = _arena()
	if arena != null and _radio > 0.0:
		arena.poner_circulo(_inicio, _radio)


# El radio del turno que se esta jugando, para mandarselo al dueño con la peticion de accion.
func radio_del_turno() -> float:
	return _radio if _fase != Fase.NADA else 0.0


# Cada fotograma, desde _process (tambien en el espejo). Devuelve true si el turno lo tiene ESTE tema
# (un enemigo acercandose) y la pantalla no debe hacer nada mas este fotograma.
func tick(delta: float) -> bool:
	match _fase:
		Fase.MOVIENDO:
			_tick_moviendo(delta)
			return false
		Fase.AJENO:
			if _turno_acabado():
				_terminar()
			return false
		Fase.ACERCANDO:
			_tick_acercando(delta)
			return true
	return false


# EL TURNO SE HA IDO: se eligio accion, o se lo ha llevado otra cosa (huyo, cayo).
func _turno_acabado() -> bool:
	return _pantalla._state != _pantalla.State.WAITING_PLAYER or _pantalla._player != _quien \
		or not is_instance_valid(_cuerpo)


func _tick_moviendo(delta: float) -> void:
	if _turno_acabado():
		_terminar()
		return
	var arena: ArenaCombate = _arena()
	if arena != null:
		_vigilar_borde(arena)
	# Solo se anda con la barra de acciones delante: dentro de un submenu estas eligiendo QUE hacer,
	# y con la pregunta de huir a la vista estas eligiendo si te vas.
	var puede: bool = _radio > 0.0 and _pantalla._actions_box != null \
		and _pantalla._actions_box.visible and not _preguntando()
	var dir: Vector2 = Vector2.ZERO
	if puede:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# El joystick de la pantalla manda cuando hay un dedo puesto (igual que en player.gd).
		if Tactil.activo and Tactil.eje != Vector2.ZERO:
			dir = Tactil.eje
	if dir == Vector2.ZERO:
		if _andando:
			_andando = false
			_animar(_cuerpo, _mirada_de(_cuerpo), false)
		return
	var antes: Vector2 = _cuerpo.global_position
	var nueva: Vector2 = paso(antes, dir.limit_length(1.0) * VEL_PASEO * delta, _inicio, _radio,
		_dentro(arena), _puede_estar.bind(_cuerpo))
	_colocar(_quien, _cuerpo, nueva)
	_andando = true
	_animar(_cuerpo, dir, true)


# EL PASO, puro y sin nodos, para poder probarlo solo (tools/prueba_tactico_turno).
#
#   desde    donde esta           mov      lo que quiere andar este fotograma
#   inicio   el centro del circulo radio   hasta donde puede alejarse de el
#   dentro   el rectangulo por el que se puede andar (la arena menos su borde)
#   puede    Callable(p) -> bool: si ese punto se pisa (suelo, y nadie encima)
#
# LAS DOS PAREDES SON BLANDAS: ni el circulo ni la arena te frenan en seco, te DEVUELVEN a su borde,
# asi que empujar contra ellos te hace resbalar a lo largo en vez de pararte. La roca si es dura: si
# el punto no se pisa se prueba cada eje por separado (deslizar por la pared), y si ninguno vale, no
# se mueve.
static func paso(desde: Vector2, mov: Vector2, inicio: Vector2, radio: float, dentro: Rect2,
		puede: Callable) -> Vector2:
	for intento in [mov, Vector2(mov.x, 0.0), Vector2(0.0, mov.y)]:
		if (intento as Vector2).is_zero_approx():
			continue
		var p: Vector2 = _acotar(desde + intento, inicio, radio, dentro)
		if p.distance_squared_to(desde) < 0.0001:
			continue
		if puede.call(p):
			return p
	return desde


static func _acotar(p: Vector2, inicio: Vector2, radio: float, dentro: Rect2) -> Vector2:
	if p.distance_to(inicio) > radio:
		p = inicio + (p - inicio).limit_length(radio)
	if dentro.has_area():
		p = Vector2(clampf(p.x, dentro.position.x, dentro.end.x),
			clampf(p.y, dentro.position.y, dentro.end.y))
	return p


# ------------------------------------------------------------
#  SU TURNO: el enemigo se acerca y luego actua
# ------------------------------------------------------------

# Lo llama _process en lugar de enemigos._enemy_turn. Si el bicho no tiene por que andar, actua ya.
func turno_enemigo(e: Combatant) -> void:
	_terminar()
	var cuerpo: Node2D = cuerpo_de(e)
	var radio: float = radio_de(e)
	var presa: Node2D = _presa_de(cuerpo)
	# Aturdido pierde el turno de todas formas: andar y luego no hacer nada seria contarlo mal.
	if cuerpo == null or presa == null or radio <= 0.0 or e.aturdido() \
			or cuerpo.global_position.distance_to(presa.global_position) <= ALCANCE_MELE:
		_pantalla.enemigos._enemy_turn(e)
		return
	_quien = e
	_cuerpo = cuerpo
	_presa = presa
	_inicio = cuerpo.global_position
	_radio = radio
	_t_acercar = 0.0
	_t_atasco = 0.0
	_fase = Fase.ACERCANDO
	# El ATB se para mientras anda: es su turno, aunque todavia no haya decidido nada. PAUSED con la
	# cuenta en infinito, y la cuenta no se toca porque este tema se queda el fotograma (ver tick).
	_pantalla._state = _pantalla.State.PAUSED
	_pantalla._pause_left = INF
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.poner_circulo(_inicio, _radio, true)


func _tick_acercando(delta: float) -> void:
	var dt: float = delta * _pantalla._vel_pelea
	_t_acercar += dt
	if not is_instance_valid(_cuerpo) or not is_instance_valid(_presa):
		_actuar()
		return
	var hacia: Vector2 = _presa.global_position - _cuerpo.global_position
	if hacia.length() <= ALCANCE_MELE or _t_acercar >= TOPE_ACERCARSE:
		_actuar()
		return
	var antes: Vector2 = _cuerpo.global_position
	var quiere: float = minf(VEL_ACERCARSE * dt, hacia.length() - ALCANCE_MELE)
	var nueva: Vector2 = paso(antes, hacia.normalized() * quiere, _inicio, _radio,
		_dentro(_arena()), _puede_estar.bind(_cuerpo))
	_colocar(_quien, _cuerpo, nueva)
	_animar(_cuerpo, hacia, true, (nueva - antes) / maxf(delta, 0.0001))
	_apuntar_bicho(_cuerpo, true)
	_t_envio += delta
	if _t_envio >= ENVIO_BICHOS:
		_t_envio = 0.0
		_enviar_bichos()
	# ATASCADO (contra roca, o en el borde de su circulo): no se agota el tope empujando.
	if nueva.distance_to(antes) < ATASCO_PX:
		_t_atasco += dt
		if _t_atasco >= ATASCO_T:
			_actuar()
	else:
		_t_atasco = 0.0


func _actuar() -> void:
	var e: Combatant = _quien
	if is_instance_valid(_cuerpo):
		var mira: Vector2 = _presa.global_position - _cuerpo.global_position \
			if is_instance_valid(_presa) else _mirada_de(_cuerpo)
		_animar(_cuerpo, mira, false)
		# EL ULTIMO AVISO AL DUEÑO: "se ha parado aqui, mirando alli". Sin el, en las demas pantallas
		# el bicho se quedaba con la pose de andar o unos pixeles antes de donde se paro de verdad.
		_apuntar_bicho(_cuerpo, false)
		_enviar_bichos()
	_terminar()
	# La cuenta a cero: si su turno no la vuelve a poner (casi todos acaban en _pausa_lectura, que
	# si), el siguiente fotograma la pelea sigue sola en vez de quedarse en pausa para siempre.
	_pantalla._pause_left = 0.0
	if e != null and e.is_alive() and _pantalla._state != _pantalla.State.FINISHED:
		_pantalla.enemigos._enemy_turn(e)


# Apunta donde esta un bicho para contarselo a su dueño. Solo si su dueño es OTRA maquina (lo que
# tengo es su espejo, remote_enemy): si el bicho de verdad es mio, mi propio tick de red ya lo lee
# de su nodo y no hay nada que contar.
func _apuntar_bicho(cuerpo: Node2D, andando: bool) -> void:
	if not Net.activo or not is_instance_valid(cuerpo) or not cuerpo.has_meta("net_id") \
			or not cuerpo.get("_objetivo") is Vector2:
		return
	_bichos_movidos[int(cuerpo.get_meta("net_id"))] = [cuerpo.global_position,
		_mirada_de(cuerpo).angle(), andando]


func _enviar_bichos() -> void:
	if _bichos_movidos.is_empty():
		return
	var lote: Array = []
	for id in _bichos_movidos:
		var d: Array = _bichos_movidos[id]
		lote.append([id, d[0], d[1], d[2]])
	_bichos_movidos.clear()
	Net.peleas.mover_bichos_en_pelea(lote)


# A QUIEN SE ACERCA: al de los tuyos que tenga mas cerca. Todavia no es a quien va a pegar (eso lo
# sortea _enemy_turn por amenaza, y en la fase 5 lo acotara el alcance), pero es lo que haria
# cualquier bicho: ir a por lo que tiene delante.
func _presa_de(cuerpo: Node2D) -> Node2D:
	if cuerpo == null:
		return null
	var mejor: Node2D = null
	var d_mejor: float = INF
	for c in _pantalla._aliados_vivos():
		var otro: Node2D = cuerpo_de(c)
		if not is_instance_valid(otro):
			continue
		var d: float = otro.global_position.distance_to(cuerpo.global_position)
		if d < d_mejor:
			d_mejor = d
			mejor = otro
	return mejor


# ------------------------------------------------------------
#  EL BORDE: acercarse propone huir
# ------------------------------------------------------------

func _vigilar_borde(arena: ArenaCombate) -> void:
	if not _conectado_al_borde:
		arena.borde_desde_dentro.connect(_on_borde)
		_conectado_al_borde = true
	# Solo vigila al que se mueve: a los demas no se les pregunta nada, estan quietos.
	arena.en_pelea.assign([_cuerpo])
	arena.vigilar([])


func _on_borde(cuerpo: Node2D) -> void:
	if _fase != Fase.MOVIENDO or cuerpo != _cuerpo or _preguntando():
		return
	# Solo si ha llegado ANDANDO: si su turno empieza ya pegado al borde, no se le pregunta nada
	# hasta que se mueva. Si no, al que acaba de decir que no se le volveria a preguntar en su turno
	# siguiente sin haber hecho nada.
	if not _andando:
		return
	_preguntar_huir()


func _preguntando() -> bool:
	return is_instance_valid(_pregunta) and _pregunta.visible


# LA PREGUNTA. UI provisional por codigo: el pase visual va al final, con todo lo demas.
func _preguntar_huir() -> void:
	if not is_instance_valid(_pregunta):
		_pregunta = PanelContainer.new()
		_pregunta.mouse_filter = Control.MOUSE_FILTER_STOP
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		_pregunta.add_child(vb)
		var lbl := Label.new()
		lbl.name = "Texto"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lbl)
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 12)
		vb.add_child(fila)
		var si := Button.new()
		si.text = "Huir"
		si.focus_mode = Control.FOCUS_NONE
		si.pressed.connect(_responder_huir.bind(true))
		fila.add_child(si)
		var no := Button.new()
		no.text = "Seguir peleando"
		no.focus_mode = Control.FOCUS_NONE
		no.pressed.connect(_responder_huir.bind(false))
		fila.add_child(no)
		_pantalla.add_child(_pregunta)
	var texto: Label = _pregunta.find_child("Texto", true, false) as Label
	if texto != null:
		texto.text = "¿%s intenta huir de la pelea?" % _quien.nombre
	_pregunta.visible = true
	_pregunta.reset_size()
	# Arriba y al centro del hueco del tablero: no tapa ni la barra de acciones ni al que pregunta.
	var util: Rect2 = Game._rect_util_tactico()
	_pregunta.position = Vector2(util.get_center().x - _pregunta.size.x * 0.5, util.position.y + 12.0)
	if _andando:
		_andando = false
		_animar(_cuerpo, _mirada_de(_cuerpo), false)


func _responder_huir(huir: bool) -> void:
	if is_instance_valid(_pregunta):
		_pregunta.visible = false
	if not huir or _fase != Fase.MOVIENDO:
		return
	# Por la accion de siempre: su tirada de Agilidad, su excelia y, si falla, pierde el turno.
	_pantalla._on_action(_pantalla.Action.FLEE)


# ------------------------------------------------------------
#  AYUDANTES
# ------------------------------------------------------------

func _terminar() -> void:
	if _fase == Fase.MOVIENDO and is_instance_valid(_cuerpo) and _andando:
		_animar(_cuerpo, _mirada_de(_cuerpo), false)
	_fase = Fase.NADA
	_quien = null
	_cuerpo = null
	_presa = null
	_andando = false
	if is_instance_valid(_pregunta):
		_pregunta.visible = false
	_quitar_circulo()


# ------------------------------------------------------------
#  LA RED
# ------------------------------------------------------------

# EL CIRCULO QUE SE ESTA VIENDO, para que los espejos pinten el mismo: [quien, x, y, radio]. 'quien'
# es el codigo de siempre del combatiente (aliados tal cual, enemigos desde 100; ver
# espejo._cod_combatiente), -1 si no anda nadie. Viaja al final del paquete de la barra de turnos.
func estado_red() -> PackedFloat32Array:
	if _fase == Fase.NADA or _quien == null or _radio <= 0.0:
		return PackedFloat32Array([-1.0, 0.0, 0.0, 0.0])
	return PackedFloat32Array([float(_pantalla.espejo._cod_combatiente(_quien)),
		_inicio.x, _inicio.y, _radio])


# EN EL ESPEJO: llega el circulo de quien lleva la pelea. Si el turno es mio y ya estoy andando, el
# que manda es el mio (lo pinte yo al empezar), no el que viene con retraso por la red.
func aplicar_red(d: PackedFloat32Array) -> void:
	if not _pantalla._espejo or d.size() < 4 or _fase == Fase.MOVIENDO:
		return
	var arena: ArenaCombate = _arena()
	if arena == null:
		return
	var cod: int = int(d[0])
	if cod < 0 or d[3] <= 0.0:
		arena.quitar_circulo()
	else:
		arena.poner_circulo(Vector2(d[1], d[2]), d[3], cod >= 100)


# EN EL ESPEJO, al contestar mi accion: donde he dejado a mi personaje. Viaja SELLADA con la accion
# (el mismo seq), asi quien lleva la pelea resuelve el golpe con la posicion con la que lo elegi y no
# con la que le haya llegado a medias por el canal del jugador.
func pos_para_red() -> Array:
	if _fase != Fase.MOVIENDO or not is_instance_valid(_cuerpo):
		return []
	return [_cuerpo.global_position.x, _cuerpo.global_position.y]


# EN QUIEN LLEVA LA PELEA: llega la posicion sellada con la accion de otro humano. NO SE RECHAZA
# NUNCA -- un rechazo seco congela la pelea entera --: si se sale de su circulo o de la arena se
# recorta al punto valido mas cercano y se apunta en la traza. Con un poco de holgura, porque su
# cuerpo aqui llega interpolado y el centro del circulo puede ir unos pixeles por detras.
const HOLGURA_RED := 8.0

func anotar_pos_remota(c: Combatant, pos: Array) -> void:
	if c == null or pos.size() < 2:
		return
	var p := Vector2(float(pos[0]), float(pos[1]))
	var valida: Vector2 = p
	if _quien == c and _radio > 0.0 and p.distance_to(_inicio) > _radio + HOLGURA_RED:
		valida = _inicio + (p - _inicio).limit_length(_radio)
	var arena: ArenaCombate = _arena()
	if arena != null:
		valida = arena.recortar_dentro(valida, 0.0)
	if not valida.is_equal_approx(p):
		_pantalla._traza_add("POS de %s recortada: %s -> %s" % [c.nombre, str(p.round()), str(valida.round())])
	_pos[c] = valida


func _quitar_circulo() -> void:
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.quitar_circulo()


func _arena() -> ArenaCombate:
	var a = Game.get("_arena_nodo")
	return a as ArenaCombate if is_instance_valid(a) else null


# Por donde se puede andar: la arena menos un pelo de borde (por debajo de lo que dispara la
# pregunta de huir, ver DENTRO_DEL_BORDE). Sin arena, sin limite.
func _dentro(arena: ArenaCombate) -> Rect2:
	if arena == null:
		return Rect2()
	return arena.rect.grow(-DENTRO_DEL_BORDE)


func _colocar(c: Combatant, cuerpo: Node2D, p: Vector2) -> void:
	cuerpo.global_position = p
	_pos[c] = p
	# LA COPIA DE RED de un bicho (remote_enemy) se arrastra cada fotograma hacia el ultimo sitio que
	# le mando su dueño: sin moverle tambien el destino, volvia andando a donde estaba. (Lo que le
	# siga llegando de su dueño durante la pelea ya no se le aplica, ver net_enemigos._tick_enemigos, y
	# el dueño se entera de donde lo dejo por _enviar_bichos.)
	if cuerpo.get("_objetivo") is Vector2:
		cuerpo.set("_objetivo", p)
		# Y el reloj con el que deduce si anda (remote_enemy._physics_process): sin ponerlo a cero, se
		# daba por quieto y le quitaba la pose de andar en cada fotograma.
		if cuerpo.get("_t_sin_avanzar") != null:
			cuerpo.set("_t_sin_avanzar", 0.0)
	# El orden de dibujo de los bichos lo recalcula su _physics_process, que con el arbol en pausa no
	# corre: sin esto, uno que pasa por delante de otro se quedaria pintado detras.
	# (Solo los bichos: son los que llevan _sprite y se lo recalculan asi, ver enemy._physics_process.)
	if cuerpo.get("_sprite") != null:
		cuerpo.z_index = Game.z_frente_a_personajes(cuerpo)


# ¿Puede estar ESTE cuerpo en 'p'? Toda su huella sobre suelo, y sin meterse encima de otro.
func _puede_estar(p: Vector2, cuerpo: Node2D) -> bool:
	var piso: Node = Game.get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("_pisable_px"):
		var h: Rect2 = _huella(cuerpo)
		for esquina in [h.position, Vector2(h.end.x, h.position.y),
				Vector2(h.position.x, h.end.y), h.end]:
			if not piso._pisable_px(p + esquina):
				return false
	# SOLO CONTRA EL OTRO BANDO. Los tuyos se atraviesan entre si, igual que por el mapa (ver
	# companion.gd): el grupo entra a la pelea en fila, y con la regla contra todos, el que va el
	# ultimo no podia ni salir de detras de los suyos.
	var antes: Vector2 = cuerpo.global_position
	var soy_enemigo: bool = _quien != null and _pantalla._enemies.has(_quien)
	var rivales: Array = _pantalla._aliados if soy_enemigo else _pantalla._enemies
	for c in rivales:
		if not c.is_alive():
			continue
		var otro: Node2D = cuerpo_de(c)
		if not is_instance_valid(otro) or otro == cuerpo:
			continue
		var o: Vector2 = otro.global_position
		if p.distance_to(o) < SEPARACION and p.distance_to(o) < antes.distance_to(o):
			return false
	return true


# La huella del cuerpo en el suelo, relativa a su origen: su forma de colision, que es con lo que
# choca por el mapa. Asi un cuerpo pasa por la arena por los mismos sitios que por la mazmorra.
func _huella(cuerpo: Node2D) -> Rect2:
	for hijo in cuerpo.get_children():
		if hijo is CollisionShape2D and (hijo as CollisionShape2D).shape != null:
			var cs: CollisionShape2D = hijo
			var r: Rect2 = cs.shape.get_rect()
			return Rect2(cs.position + r.position * cs.scale, r.size * cs.scale)
	return Rect2(-HUELLA_POR_DEFECTO * 0.5, HUELLA_POR_DEFECTO)


func _mirada_de(cuerpo: Node2D) -> Vector2:
	var f = cuerpo.get("_facing")
	return f if f is Vector2 and f != Vector2.ZERO else Vector2.DOWN


# Pone la pose de andar o de quieto. Con el arbol en pausa el cuerpo no se anima solo (su
# _physics_process no corre), asi que hay que decirselo aqui.
#   Los tuyos: el muñeco, en GUARDIA (andar con el arma en alto: es una pelea).
#   Los bichos: su propio _actualizar_animacion, que ya sabe elegir walk/idle por velocidad.
func _animar(cuerpo: Node2D, dir: Vector2, moviendose: bool, vel: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(cuerpo) or dir == Vector2.ZERO:
		return
	if cuerpo.get("_facing") != null:
		cuerpo.set("_facing", dir.normalized())
	var muneco = cuerpo.get("_muneco")
	if muneco is MunecoJugador and (muneco as MunecoJugador).hay_dibujo():
		(muneco as MunecoJugador).animar(PoseJugador.animacion(dir, 1, moviendose, false, true, 0))
		return
	# LA COPIA DE RED de un bicho no lleva _facing ni velocidad: su pose sale de un ANGULO y de un "se
	# mueve", que normalmente le llegan por la red, y su _actualizar_animacion no tiene argumentos.
	if cuerpo.get("_mira") != null and cuerpo.get("_mov") != null:
		cuerpo.set("_mira", dir.angle())
		cuerpo.set("_mov", moviendose)
		cuerpo.call("_actualizar_animacion")
		return
	if cuerpo.has_method("_actualizar_animacion") and cuerpo.get("_sprite") != null:
		cuerpo.call("_actualizar_animacion", vel if moviendose else Vector2.ZERO)
