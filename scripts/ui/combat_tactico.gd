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
#  PENDIENTE (fases siguientes, no de esta): a quien alcanzas segun donde estas (fase 5, la
#  geometria de mapa), las cargas que clavan y la reposicion entre frases (fase 6), y la RED (fase 7:
#  hoy solo se mueven los personajes de ESTA maquina).
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

enum Fase { NADA, MOVIENDO, ACERCANDO }
var _fase: int = Fase.NADA

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

func cuerpo_de(c: Combatant) -> Node2D:
	var i: int = _pantalla._enemies.find(c)
	if i >= 0:
		return _pantalla.figuras_mapa._cuerpo_enemigo(i)
	i = _pantalla._aliados.find(c)
	if i >= 0:
		return _pantalla.figuras_mapa._cuerpo_aliado(i)
	return null


# Donde esta. Lo que diga su cuerpo, y si no tiene (un invocado), lo ultimo apuntado.
func pos_de(c: Combatant) -> Vector2:
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

# Empieza el turno de uno de los tuyos. Lo llama _begin_player_turn cuando ya se sabe que el turno
# se juega (ni aturdido ni cargando).
func empezar_turno(c: Combatant) -> void:
	_terminar()
	# Solo los personajes de ESTA maquina andan por ahora: el de otro humano manda su accion por red y
	# la red todavia no lleva posiciones (fase 7).
	if int(_pantalla._dueno_aliado.get(c, 0)) != 0:
		return
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return
	_quien = c
	_cuerpo = cuerpo
	_inicio = cuerpo.global_position
	# Recitando (entre frases) no se anda todavia: la reposicion entre frases es la fase 6.
	_radio = 0.0 if _pantalla._cast_spell != null else radio_de(c)
	_fase = Fase.MOVIENDO
	_andando = false
	_animar(cuerpo, _mirada_de(cuerpo), false)
	var arena: ArenaCombate = _arena()
	if arena != null and _radio > 0.0:
		arena.poner_circulo(_inicio, _radio)


# Cada fotograma, desde _process. Devuelve true si el turno lo tiene ESTE tema (un enemigo
# acercandose) y la pantalla no debe hacer nada mas este fotograma.
func tick(delta: float) -> bool:
	match _fase:
		Fase.MOVIENDO:
			_tick_moviendo(delta)
			return false
		Fase.ACERCANDO:
			_tick_acercando(delta)
			return true
	return false


func _tick_moviendo(delta: float) -> void:
	# EL TURNO SE HA IDO: has elegido accion, o se lo ha llevado otra cosa (huiste, caiste).
	if _pantalla._state != _pantalla.State.WAITING_PLAYER or _pantalla._player != _quien \
			or not is_instance_valid(_cuerpo):
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
	_terminar()
	# La cuenta a cero: si su turno no la vuelve a poner (casi todos acaban en _pausa_lectura, que
	# si), el siguiente fotograma la pelea sigue sola en vez de quedarse en pausa para siempre.
	_pantalla._pause_left = 0.0
	if e != null and e.is_alive() and _pantalla._state != _pantalla.State.FINISHED:
		_pantalla.enemigos._enemy_turn(e)


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
	if cuerpo.has_method("_actualizar_animacion") and cuerpo.get("_sprite") != null:
		cuerpo.call("_actualizar_animacion", vel if moviendose else Vector2.ZERO)
