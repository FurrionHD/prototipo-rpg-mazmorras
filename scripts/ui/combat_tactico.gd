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
#  EL ALCANCE Y LA HUELLA (fase 5): para pegar hay que llegar (llega / alcanzables), y las habilidades
#  ya hechas para el mapa se APUNTAN con el raton (apuntar / reparto_habilidad): pegan a todo lo que la
#  huella roce, sin tope. Mientras se recita NO se anda (decision del usuario: no hay reposicion entre
#  frases). Las huellas las ven TODOS (estado_huellas / aplicar_huellas). PENDIENTE: la magia con su rango.
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
# EL ALCANCE, en px de HUECO entre cuerpos (Cuerpos.hueco, la cuenta del golpe por el mapa). Lo de
# cada uno viene en Combatant.alcance (su arma, o su ficha de enemigo); esto es el suelo para quien
# no lo diga.
const ALCANCE_MINIMO := 6.0
# El enemigo se arrima hasta esta fraccion de su alcance, no hasta el limite justo: parado en el
# borde exacto, el redondeo de la red podia dejarle a medio pixel de no llegar.
const ARRIMARSE := 0.75
# Lo que se le perdona a la posicion de OTRO humano al mirar si llega: su cuerpo llega interpolado y
# su posicion sellada puede no cuadrar al pixel con la de su pantalla. Nunca se rechaza por eso.
const HOLGURA_ALCANCE := 6.0
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
var _presa: Combatant = null
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
		_preparar(c)


# Deja listo el cuerpo de UN combatiente (su sitio y sus dibujos animandose en pausa). Vale tambien
# para los que entran A MEDIA PELEA (refuerzos, aliados que se unen): los busca _preparar_altas en
# cada tick, porque montar() solo ve a los que estaban al empezar. false = aun no tiene cuerpo aqui.
var _preparados: Dictionary = {}

func _preparar(c: Combatant) -> bool:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return false
	_pos[c] = cuerpo.global_position
	for hijo in cuerpo.get_children():
		if hijo is AnimatedSprite2D or hijo is MunecoJugador:
			if (hijo as Node).process_mode != Node.PROCESS_MODE_ALWAYS:
				_modos_guardados.append([hijo, (hijo as Node).process_mode])
				(hijo as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	_preparados[c] = true
	return true


func _preparar_altas() -> void:
	for c in _pantalla._aliados + _pantalla._enemies:
		if not _preparados.has(c):
			_preparar(c)


# ------------------------------------------------------------
#  LO QUE ESTA DENTRO DE LA ARENA, PELEA
# ------------------------------------------------------------
# Un enemigo DENTRO del rectangulo que no esta en ninguna pelea entra en esta como refuerzo (lo vio el
# usuario el 23/09: uno se quedaba congelado dentro, sin barra, porque el grupo del arranque lo elige
# el que dispara la pelea -- el y sus vecinos cercanos -- y la arena, que se calcula despues, es mas
# grande). Cubre tambien al que aparece dentro y al que entra andando: es la regla del borde "un
# enemigo de fuera se mete en la pelea", que estaba escrita en la arena y nunca se enchufo.
#
# Lo mira SOLO quien lleva la pelea, cada RECOGER_CADA segundos, y entra por los caminos de siempre:
#   - un cuerpo DE VERDAD (solitario, o soy el dueño del piso): Game.unir_enemigo_al_combate, igual
#     que cuando un enemigo te alcanza andando (enemy._start_combat);
#   - un ESPEJO (el dueño es otro): se le pide a su dueño con Net.peleas.solicitar_pelea, la misma
#     peticion que al atacarle; como ya estoy peleando, al llegar se une a esta (_llega_pelea). No se
#     repite la peticion mientras se espera la respuesta (PEDIDO_OTRA_VEZ).
const RECOGER_CADA := 0.5
const PEDIDO_OTRA_VEZ := 3000   # ms
var _t_recoger: float = 0.0
var _pedidos: Dictionary = {}   # net_id -> ms en que se pidio

func _recoger_de_la_arena(delta: float) -> void:
	if _pantalla._espejo:
		return
	_t_recoger += delta
	if _t_recoger < RECOGER_CADA:
		return
	_t_recoger = 0.0
	var arena: ArenaCombate = _arena()
	if arena == null or _pantalla._state == _pantalla.State.FINISHED:
		return
	var ahora: int = Time.get_ticks_msec()
	for n in _pantalla.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n) or not (n is Node2D) or not arena.contiene((n as Node2D).global_position):
			continue
		if Game.esta_en_combate(n) or (n.has_method("esta_muerto") and n.esta_muerto()):
			continue
		if n.has_meta("es_espejo"):
			if not Net.activo or not n.has_meta("net_id") or Net.peleas.pelea_de_enemigo(n) != 0:
				continue
			var id: int = int(n.get_meta("net_id"))
			if ahora - int(_pedidos.get(id, -PEDIDO_OTRA_VEZ)) < PEDIDO_OTRA_VEZ:
				continue
			_pedidos[id] = ahora
			print("[arena] %s esta dentro de la arena: lo pido a su dueño" % n.name)
			Net.peleas.solicitar_pelea(id)
			continue
		if bool(n.get("_combat_triggered")):
			continue
		# Como en enemy._start_combat: quieto y sin su aviso de embestida, y si la pelea no le admite (se
		# esta cerrando), suelto para que no se quede de estatua.
		n.set("_combat_triggered", true)
		n.set("velocity", Vector2.ZERO)
		if n.has_method("_cancelar_aviso"):
			n.call("_cancelar_aviso")
		if Game.unir_enemigo_al_combate(n):
			print("[arena] %s estaba dentro de la arena: entra a la pelea" % n.name)
		else:
			n.set("_combat_triggered", false)


func desmontar() -> void:
	for par in _modos_guardados:
		if is_instance_valid(par[0]):
			(par[0] as Node).process_mode = par[1]
	_modos_guardados.clear()
	_tirones.clear()
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
#  EL ALCANCE: ¿llega el golpe de 'a' a 'b'?
# ------------------------------------------------------------

# ------------------------------------------------------------
#  LOS PIES: cada cuerpo es un CIRCULO en el suelo
# ------------------------------------------------------------
# QUIEN GOLPEA mide desde SUS PIES (el centro de su cuerpo en el suelo), igual en todas las
# direcciones; QUIEN RECIBE, por su cuerpo tal como se ve (bulto_de). Lo usan a la vez el basico
# (hueco_entre), la punta del arma de las habilidades (forma_de) y a quien pilla cada huella
# (reparto_habilidad): una sola cuenta.
#
# POR QUE ASI Y NO CON CAJAS (23/09, mirando la pelea con el usuario): con cajas salian dos cosas
# que no cuadraban con lo que se ve.
#   - Hacia ARRIBA llegaba mas: el cuerpo del personaje era una caja alta (22x42), y la punta del arma
#     se contaba desde su borde, que por arriba queda 10 px mas lejos. Parecia que pegaba "desde la
#     cabeza". Un circulo mide lo mismo en todas las direcciones.
#   - A la Aberracion le daba cualquier cosa: se media con un cuadrado del ANCHO de su dibujo (53 px,
#     tentaculos incluidos) puesto en el suelo, y el dibujo es el bicho DE PIE visto a 45 grados, no
#     lo que pisa. Tres pegadas se solapaban entre ellas y contigo, y un cono que tapaba a una
#     "pillaba a 3".
# El radio es una fraccion del ancho que se VE (el dibujo en los enemigos, la caja de siempre en los
# tuyos): lo que pisa un cuerpo es bastante menos que lo que abulta.
const PISA := 0.33


# Donde tiene los pies, con el cuerpo donde la PELEA dice que esta (pos_de: la posicion sellada si es
# de otro humano). Los tuyos: bajo el nodo (PoseJugador.PIES_BAJO_NODO). Los enemigos: a la altura de su
# dibujo que diga su ficha (centro_suelo_de); sin ficha, un pelo por encima del borde de abajo.
const PIES_SOBRE_EL_BORDE := 0.1

func pies_de(c: Combatant) -> Vector2:
	var p: Vector2 = pos_de(c)
	if not _pantalla._enemies.has(c):
		return p + Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
	var r: Rect2 = bulto_de(c)
	return Vector2(r.get_center().x, r.position.y + r.size.y * centro_suelo_de(cuerpo_de(c)))


# A que altura de su dibujo tiene cada enemigo su centro en el suelo: lo dice SU FICHA
# (EnemyData.centro_suelo), porque un bipedo lo tiene en los pies y uno a cuatro patas en medio del
# cuerpo. Vale el bicho de esta maquina y la copia de red: los dos llevan su 'data'.
static func centro_suelo_de(cuerpo: Node2D) -> float:
	var d = cuerpo.get("data") if cuerpo != null else null
	if d is EnemyData:
		return (d as EnemyData).centro_suelo_real()
	return 1.0 - PIES_SOBRE_EL_BORDE


# El radio de lo que PISA quien golpea: la punta de su arma se cuenta desde el borde de esto.
func radio_pisa(c: Combatant) -> float:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return 32.0 * PISA
	var ancho: float = 0.0
	if _pantalla._enemies.has(c):
		ancho = rect_dibujo(cuerpo).size.x
	if ancho <= 0.0:
		ancho = Cuerpos.caja_de(cuerpo).size.x
	return ancho * PISA


# LA HITBOX de quien RECIBE: su cuerpo tal como se ve (lo marco el usuario sobre una captura, una caja
# alrededor del dibujo de la Aberracion: "eso es lo que hay que tener en cuenta para golpearlo").
#   Los enemigos: la caja de lo que tienen PINTADO, donde se pinta (ver rect_dibujo).
#   Los tuyos: la caja de su cuerpo (PoseJugador.CAJA_CUERPO), la misma contra la que te pegan por el mapa.
# Con el cuerpo donde la PELEA dice que esta (pos_de).
func bulto_de(c: Combatant) -> Rect2:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return Rect2(pos_de(c) - Vector2(16, 16), Vector2(32, 32))
	var r: Rect2 = Rect2()
	if _pantalla._enemies.has(c):
		r = rect_dibujo(cuerpo)
	if not r.has_area():
		r = Cuerpos.caja_de(cuerpo)
	r.position += pos_de(c) - cuerpo.global_position
	return r


# EL CUERPO DE UN BLOQUE EN PANTALLA: lo que CombatFX usa para colocar los numeros y los dibujos de los
# golpes en el mapa (CombatFX.rect_en_mapa). El bulto de su combatiente, pasado por la camara. Rect2()
# = ese bloque no tiene cuerpo ahora mismo, y entonces manda la tarjeta de siempre.
func rect_pantalla_de_bloque(bloque: Dictionary) -> Rect2:
	var c: Combatant = null
	for lista in [_pantalla._enemies, _pantalla._aliados]:
		for x in lista:
			if is_same(_pantalla._bloque_de(x), bloque):
				c = x
				break
		if c != null:
			break
	if c == null or cuerpo_de(c) == null:
		return Rect2()
	var r: Rect2 = bulto_de(c)
	var xf: Transform2D = _pantalla.get_viewport().get_canvas_transform()
	return Rect2(xf * r.position, r.size * xf.get_scale().abs())


# El hueco para GOLPEAR: de los pies de quien golpea (menos lo que pisa) al cuerpo de quien recibe.
# No es simetrico, y es a proposito: "a llega a b" y "b llega a a" miden desde pies distintos.
func hueco_entre(a: Combatant, b: Combatant) -> float:
	if cuerpo_de(a) == null or cuerpo_de(b) == null:
		return INF
	var p: Vector2 = pies_de(a)
	var r: Rect2 = bulto_de(b)
	var cerca := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(cerca) - radio_pisa(a)


func alcance_de(c: Combatant) -> float:
	return maxf(c.alcance, ALCANCE_MINIMO) if c != null else ALCANCE_MINIMO


# ¿Llega? En quien lleva la pelea, al personaje de OTRO humano se le perdona HOLGURA_ALCANCE: su
# pantalla le dijo que llegaba con las posiciones que el veia, y un rechazo por dos pixeles de red
# le dejaria sin el turno que eligio.
func llega(a: Combatant, b: Combatant) -> bool:
	if a == null or b == null:
		return false
	var tope: float = alcance_de(a)
	if not _pantalla._espejo and _pantalla._aliados.has(a) and not _es_mio(a):
		tope += HOLGURA_ALCANCE
	return hueco_entre(a, b) <= tope


# De 'candidatos', los que 'a' alcanza desde donde esta.
func alcanzables(a: Combatant, candidatos: Array) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in candidatos:
		if llega(a, c):
			out.append(c)
	return out


# ¿Tiene a alguien a tiro? Es lo que decide si el boton de Atacar pega o te deja ESPERAR.
func llega_a_alguno(a: Combatant) -> bool:
	for e in _pantalla._vivos():
		if llega(a, e):
			return true
	return false


# EL ENEMIGO QUE ESTA ACTUANDO, mientras resuelve su turno. Lo mira el sorteo de a quien pega
# (objetivos._elegir_objetivo_enemigo), que se llama desde ocho sitios y no sabe de quien es el
# turno. Solo vive durante la llamada a _enemy_turn (ver _turno_enemigo_de_siempre).
var atacante: Combatant = null


# El turno de siempre del enemigo, pero sabiendo quien pega para que su sorteo se quede con los que
# alcanza. Si no alcanza a nadie, el sorteo sale vacio y _enemy_turn lo cuenta como que no llega.
func _turno_enemigo_de_siempre(e: Combatant) -> void:
	atacante = e
	_pantalla.enemigos._enemy_turn(e)
	atacante = null


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
	_tick_huellas(delta)
	_tick_gestos(delta)
	_tick_tirones(delta)
	_tick_saltos(delta)
	_preparar_altas()
	_recoger_de_la_arena(delta)
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


# ------------------------------------------------------------
#  APUNTAR una habilidad en el mapa
# ------------------------------------------------------------
# Las habilidades YA HECHAS para el mapa (forma_apunte >= 0 en su ficha) no salen al pulsarlas: se
# apuntan. La huella sigue al raton, el personaje mira hacia ella, y el clic izquierdo confirma (el
# derecho, o Esc, vuelve al menu). Lo que se elige es un PUNTO, y ese punto es lo que viaja por red
# sellado con la accion: quien lleva la pelea rehace la huella desde la posicion sellada del que la
# lanza y su alcance, y pega a quien le toque. Las que aun no se han hecho siguen como en la fila.

var _apuntando: AbilityData = null
# El punto elegido (mundo) de la accion que se va a resolver. Lo pone el clic en esta maquina, o
# llega sellado por red (anotar_apunte). Lo lee reparto_habilidad.
var apunte: Vector2 = Vector2.ZERO
var _hay_apunte: bool = false
var _pillados_vistos: int = -1
const CLAVE_APUNTE := &"apuntando"


# ¿Esta habilidad se resuelve con su huella del mapa?
func usa_huella(ab: AbilityData) -> bool:
	return _pantalla.tactico and ab != null and int(ab.forma_apunte) >= 0 and int(ab.forma) >= 0


# La forma de 'ab' lanzada por 'c' hacia 'hacia', desde SUS PIES y con 'c' donde la PELEA dice.
func forma_de(ab: AbilityData, c: Combatant, hacia: Vector2) -> RefCounted:
	return CombatFormas.de_habilidad_mapa(ab, pies_de(c), radio_pisa(c), alcance_de(c), hacia)


# A QUIEN PEGA y con cuanto: [{c, escala}], sin tope (en el mapa le da a todo lo que la huella toque:
# el cuerpo de cada uno tal como se ve, ver bulto_de). Con NUCLEO, los que el nucleo toca van al daño entero y
# el resto a area_secundario; un cono con TRAMOS baja forma_tramo_baja por tramo; si no, todos a
# forma_escala (1.0 = entero). Ordenados por cercania
# al centro y, a igualdad, por indice en _enemies: el mismo orden en todas las maquinas. Vacio =
# golpea el suelo.
func reparto_habilidad(ab: AbilityData, c: Combatant) -> Array:
	var out: Array = []
	if not _hay_apunte:
		return out
	var f = forma_de(ab, c, apunte)
	var nucleo = CombatFormas.circulo(f.centro, ab.forma_nucleo) if ab.forma_nucleo > 0.0 else null
	var lista: Array = []
	for e in _pantalla._vivos():
		var r: Rect2 = bulto_de(e)
		if not f.toca(r):
			continue
		var esc: float = ab.forma_escala
		if nucleo != null:
			esc = 1.0 if nucleo.toca(r) else ab.area_secundario
		elif f.tramos > 1:
			# El cono a TROZOS (la Onda): cada tramo mas lejos, forma_tramo_baja menos.
			esc = maxf(0.0, ab.forma_escala - ab.forma_tramo_baja * float(f.tramo_de(r)))
		lista.append({"c": e, "escala": esc, "d": r.get_center().distance_squared_to(f.centro_util()),
			"i": _pantalla._enemies.find(e)})
	lista.sort_custom(func(x, y):
		if is_equal_approx(float(x["d"]), float(y["d"])):
			return int(x["i"]) < int(y["i"])
		return float(x["d"]) < float(y["d"]))
	for d in lista:
		out.append({"c": d["c"], "escala": d["escala"]})
	return out


# LO QUE TIENE PINTADO un enemigo, en MUNDO: la caja que abraza su dibujo EN EL FOTOGRAMA QUE SE VE.
# Rect2() = no tiene dibujo que medir.
#
# EL FOTOGRAMA DE AHORA, no la pose entera: uniendo todos los de la animacion, un slime que bota o un
# golem que sube y baja al andar se quedaban con una caja bastante mas grande que lo que se ve (lo vio
# el usuario el 23/09). Para golpear manda lo que ves en el momento del golpe.
#
# DOS COSAS que hay que sumar y que la primera version no sumaba (la caja salia caida hacia abajo en
# el Rey Slime, el Coloso y el Miconido):
#   - el SPRITE no esta en el punto del enemigo: va subido (su propia position), asi que se mide desde
#     el sprite, no desde el nodo;
#   - cada fotograma es un AtlasTexture RECORTADO: lo pintado (su region) va dentro de un lienzo mas
#     grande, y su sitio dentro de el lo dice su MARGIN.
static var _cache_dibujo := {}

static func rect_dibujo(cuerpo: Node2D) -> Rect2:
	if cuerpo == null:
		return Rect2()
	for hijo in cuerpo.get_children():
		if hijo is AnimatedSprite2D and (hijo as CanvasItem).visible \
				and (hijo as AnimatedSprite2D).sprite_frames != null:
			var spr: AnimatedSprite2D = hijo
			var local: Rect2 = _pintado_local(spr)
			if not local.has_area():
				return Rect2()
			var t: Transform2D = spr.get_global_transform()
			var esc: Vector2 = t.get_scale().abs()
			return Rect2(t.origin + local.position * esc, local.size * esc)
		if hijo is ColorRect and (hijo as CanvasItem).visible:
			var cr: ColorRect = hijo
			var tc: Transform2D = cr.get_global_transform()
			return Rect2(tc.origin, cr.size * tc.get_scale().abs())
	return Rect2()


# Lo pintado del fotograma que se ve, en px de la textura y relativo al ORIGEN del sprite (su punto de
# dibujo, con 'centered' y 'offset' ya dentro). Cacheado por textura: las de una especie se generan una
# vez y son las mismas para todos los suyos, asi que get_image solo se paga la primera vez.
static func _pintado_local(spr: AnimatedSprite2D) -> Rect2:
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return Rect2()
	var clave: int = tex.get_instance_id()
	var r: Rect2
	if _cache_dibujo.has(clave):
		r = _cache_dibujo[clave]
	else:
		r = Rect2(Vector2.ZERO, tex.get_size())   # sin recorte: el lienzo entero
		if tex is AtlasTexture:
			var at: AtlasTexture = tex
			r = Rect2(at.margin.position, at.region.size)
		var img: Image = tex.get_image()
		if img != null:
			var usado: Rect2i = img.get_used_rect()
			if usado.size.x > 0 and usado.size.y > 0:
				r = Rect2(r.position + Vector2(usado.position), Vector2(usado.size))
		r.position -= tex.get_size() * 0.5   # relativo al centro del lienzo
		_cache_dibujo[clave] = r
	if not spr.centered:
		r.position += tex.get_size() * 0.5
	r.position += spr.offset
	return r


# Pulsaste una habilidad con huella: a apuntar.
func apuntar(ab: AbilityData) -> void:
	if _pantalla._state != _pantalla.State.WAITING_PLAYER or not is_instance_valid(_cuerpo):
		return
	_apuntando = ab
	_pillados_vistos = -1
	_andando = false
	_pantalla._ocultar_cajas()
	_mostrar_volver()
	_refrescar_apunte(_raton_en_mundo())


func esta_apuntando() -> bool:
	return _apuntando != null


func _refrescar_apunte(raton: Vector2) -> void:
	if _apuntando == null or not is_instance_valid(_cuerpo):
		return
	var f = forma_de(_apuntando, _quien, raton)
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.poner_huella(CLAVE_APUNTE, f, _apuntando.forma_nucleo)
	# Y a los demas: si llevo la pelea la apunto en la lista que reparto; si soy espejo, se la mando.
	_anotar_huella_red(_quien, CLASE_APUNTANDO, f, _apuntando.forma_nucleo)
	_enviar_mi_huella(f, _apuntando.forma_nucleo)
	# MIRA HACIA DONDE APUNTA (lo pidio el usuario), pero solo QUIETO: andando manda la pose de andar
	# (ver _tick_moviendo). Su cuerpo es el de esta maquina, y su cara viaja con el, por el canal del
	# jugador.
	if not _andando:
		_animar(_cuerpo, raton - _cuerpo.global_position, false)
	# Cuantos pilla, en un letrero junto al boton de volver y NO en el registro: el registro viaja a
	# los demas jugadores, y cada movimiento del raton seria una linea en su pantalla.
	apunte = raton
	_hay_apunte = true
	var n: int = reparto_habilidad(_apuntando, _quien).size()
	# Andando no se puede soltar (ver _confirmar_apunte): el letrero lo dice. -2 = "estoy andando".
	var visto: int = -2 if _andando else n
	if visto != _pillados_vistos and is_instance_valid(_letrero):
		_pillados_vistos = visto
		var pilla: String = "no pilla a nadie" if n == 0 else ("pilla a 1" if n == 1 else "pilla a %d" % n)
		_letrero.text = ("%s: párate para lanzarla" % _apuntando.nombre) if _andando \
			else "%s: %s.  Clic para lanzarla · clic derecho para volver" % [_apuntando.nombre, pilla]


func _confirmar_apunte() -> void:
	# HAY QUE ESTAR QUIETO para lanzarla (lo pidio el usuario): asi el personaje ya se ha girado hacia
	# donde golpea. Andando, el clic no hace nada (el letrero lo avisa).
	if _andando:
		return
	var ab: AbilityData = _apuntando
	_dejar_de_apuntar()
	apunte = _raton_en_mundo()
	_hay_apunte = true
	_pantalla.habilidades._usar_habilidad(ab)


func _cancelar_apunte() -> void:
	_dejar_de_apuntar()
	_pantalla.habilidades._accion_habilidad()   # de vuelta al menu de habilidades


func _dejar_de_apuntar() -> void:
	if _apuntando != null and _quien != null:
		_anotar_huella_red(_quien, CLASE_APUNTANDO, null, 0.0)
		_enviar_mi_huella(null, 0.0)
	_apuntando = null
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.quitar_huella(CLAVE_APUNTE)
	if is_instance_valid(_boton_volver):
		_boton_volver.queue_free()
	_boton_volver = null
	if is_instance_valid(_letrero):
		_letrero.queue_free()
	_letrero = null


# Lo llama la pantalla desde su _input, ANTES que nada. true = el evento era del apuntado.
func input_apuntando(event: InputEvent) -> bool:
	if _apuntando == null:
		return false
	if event is InputEventMouseMotion:
		_refrescar_apunte(_raton_en_mundo())
		return false   # el movimiento no se come: la ficha del que tienes debajo sigue funcionando
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		# Un clic sobre un BOTON (el de volver) es del boton, no del suelo.
		var bajo: Control = _pantalla.get_viewport().gui_get_hovered_control()
		if bajo is BaseButton:
			return false
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_confirmar_apunte()
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancelar_apunte()
			return true
	if event.is_action_pressed(&"cancelar"):
		_cancelar_apunte()
		return true
	return false


# El boton de volver: en tactil no hay clic derecho. UI provisional, como la pregunta de huir.
var _boton_volver: Button = null
var _letrero: Label = null

func _mostrar_volver() -> void:
	if is_instance_valid(_boton_volver):
		return
	_boton_volver = Button.new()
	_boton_volver.text = "↩ Volver"
	_boton_volver.focus_mode = Control.FOCUS_NONE
	_boton_volver.pressed.connect(_cancelar_apunte)
	_pantalla.add_child(_boton_volver)
	var util: Rect2 = Game._rect_util_tactico()
	_boton_volver.position = Vector2(util.get_center().x - 60.0, util.end.y - 56.0)
	_boton_volver.custom_minimum_size = Vector2(120, 44)
	_letrero = Label.new()
	_letrero.add_theme_font_size_override("font_size", 18)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 6)
	_letrero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letrero.size = Vector2(util.size.x, 28)
	_letrero.position = Vector2(util.position.x, util.end.y - 88.0)
	_pantalla.add_child(_letrero)


# Donde esta el raton EN EL MUNDO: la pantalla va en una capa aparte, pero el suelo lo pinta la
# camara, asi que se deshace su transformacion.
func _raton_en_mundo() -> Vector2:
	var vp: Viewport = _pantalla.get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


# EN EL ESPEJO, al contestar una habilidad: el punto al que apunte. [] si no hay.
func apunte_para_red() -> Array:
	return [apunte.x, apunte.y] if _hay_apunte else []


# EN QUIEN LLEVA LA PELEA: el punto sellado con la habilidad de otro humano. No se valida contra
# nada: la huella se rehace aqui con SU posicion sellada y SU alcance, asi que un punto lejisimos
# solo pone el centro en la punta de su arma, que es lo mas lejos que puede caer.
func anotar_apunte(p: Array) -> void:
	_hay_apunte = p.size() >= 2
	apunte = Vector2(float(p[0]), float(p[1])) if _hay_apunte else Vector2.ZERO


# LAS CARGAS: el sitio se elige al EMPEZAR a cargar y se queda (combatiente -> [ab, punto]). Mientras
# carga, su huella se queda pintada en el suelo: es el aviso, y lo que deja salir de ella andando.
# Vive en quien lleva la pelea, que es quien suelta la carga (ver _begin_player_turn).
var _cargas: Dictionary = {}

func guardar_carga(c: Combatant, ab: AbilityData) -> void:
	if c == null or not _hay_apunte:
		return
	_cargas[c] = [ab, apunte]
	var f = forma_de(ab, c, apunte)
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.poner_huella(c, f, ab.forma_nucleo, COLOR_CARGA)
	_anotar_huella_red(c, CLASE_CARGA, f, ab.forma_nucleo)
	# Y se queda con el arma en alto mientras carga (ver _animar).
	var cu: Node2D = cuerpo_de(c)
	if cu != null:
		_animar(cu, _mirada_de(cu), false)


func tiene_carga(c: Combatant) -> bool:
	return _cargas.has(c)


# Pone el sitio guardado como el apunte de la accion y borra la huella: lo que queda es soltarla.
func recuperar_carga(c: Combatant) -> void:
	var d: Array = _cargas.get(c, [])
	_cargas.erase(c)
	_anotar_huella_red(c, CLASE_CARGA, null, 0.0)
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.quitar_huella(c)
	if d.size() >= 2:
		apunte = d[1]
		_hay_apunte = true


# Si le interrumpen la carga (aturdido) o cae, la huella se va con ella.
func olvidar_carga(c: Combatant) -> void:
	if not _cargas.has(c):
		return
	_cargas.erase(c)
	_anotar_huella_red(c, CLASE_CARGA, null, 0.0)
	var arena: ArenaCombate = _arena()
	if arena != null:
		arena.quitar_huella(c)


# ------------------------------------------------------------
#  QUE LOS DEMAS VEAN LAS HUELLAS
# ------------------------------------------------------------
# Quien lleva la pelea guarda TODAS las huellas vivas (la que se apunta, sea de aqui o de un espejo, y
# las de las cargas) y las reparte juntas unas veces por segundo. Cada maquina pinta las de los demas;
# la suya, mientras apunta, la pinta ella misma sin esperar a la red.
#
# UNA HUELLA = 15 floats: [cod, clase, tipo, cx, cy, ox, oy, dx, dy, radio, apertura, nucleo, tramos,
# ancho, ancho_fin]. cod = el codigo de siempre del combatiente (espejo._cod_combatiente). clase 0 =
# apuntando, 1 = carga. En la LINEA el radio es su largo; ancho y ancho_fin solo los mira ella.
const FLOATS_HUELLA := 15
const CLASE_APUNTANDO := 0
const CLASE_CARGA := 1
const ENVIO_HUELLAS := 1.0 / 12.0
const REPETIR_HUELLAS := 0.5   # aunque no cambie nada: un paquete perdido no deja una huella fantasma
var _huellas_red: Dictionary = {}          # cod -> PackedFloat32Array (en quien lleva la pelea)
var _huellas_cambiadas: bool = false
var _t_huellas: float = 0.0
var _t_repetir: float = 0.0
var _mi_huella_enviada: PackedFloat32Array = PackedFloat32Array()
var _claves_red: Array = []                # las que pinte llegadas por red, para quitarlas luego


static func _empaquetar(cod: int, clase: int, f, nucleo: float) -> PackedFloat32Array:
	return PackedFloat32Array([float(cod), float(clase), float(f.tipo), f.centro.x, f.centro.y,
		f.origen.x, f.origen.y, f.dir.x, f.dir.y, f.radio, f.apertura, nucleo, float(f.tramos),
		f.ancho, f.ancho_fin])


static func _desempaquetar(d: PackedFloat32Array, i: int) -> Array:
	var f := CombatFormas.Forma.new()
	f.tipo = int(d[i + 2])
	f.centro = Vector2(d[i + 3], d[i + 4])
	f.origen = Vector2(d[i + 5], d[i + 6])
	f.dir = Vector2(d[i + 7], d[i + 8])
	f.radio = d[i + 9]
	f.apertura = d[i + 10]
	f.tramos = int(d[i + 12])
	f.ancho = d[i + 13]
	f.ancho_fin = d[i + 14]
	if f.tipo == CombatFormas.Tipo.LINEA:
		f.largo = f.radio
	return [int(d[i]), int(d[i + 1]), f, d[i + 11]]


func _cod(c: Combatant) -> int:
	return _pantalla.espejo._cod_combatiente(c)


# Apunta (o borra, con f = null) una huella en la lista que se reparte. Solo en quien lleva la pelea.
func _anotar_huella_red(c: Combatant, clase: int, f, nucleo: float) -> void:
	if _pantalla._espejo:
		return
	var cod: int = _cod(c) * 2 + clase   # la de apuntar y la de cargar del mismo no se pisan
	if f == null:
		if _huellas_red.erase(cod):
			_huellas_cambiadas = true
		return
	_huellas_red[cod] = _empaquetar(_cod(c), clase, f, nucleo)
	_huellas_cambiadas = true


# EN EL ESPEJO que apunta: su huella, a quien lleva la pelea (solo si ha cambiado). Vacia = ya no apunto.
func _enviar_mi_huella(f, nucleo: float) -> void:
	if not _pantalla._espejo:
		return
	var d: PackedFloat32Array = PackedFloat32Array() if f == null \
		else _empaquetar(_cod(_quien), CLASE_APUNTANDO, f, nucleo)
	if d == _mi_huella_enviada:
		return
	_mi_huella_enviada = d
	if d.is_empty():
		d = PackedFloat32Array([float(_cod(_quien)), -1.0])   # "la mia, fuera"
	Net.peleas.enviar_mi_huella(d)


# EN QUIEN LLEVA LA PELEA: llega la huella del espejo que apunta. Solo se acepta la de un personaje
# de ESE humano, y solo mientras le toca: una rezagada de un turno ya jugado no se pinta.
func huella_de_espejo(d: PackedFloat32Array, emisor: int) -> void:
	if _pantalla._espejo or d.size() < 2:
		return
	var c: Combatant = _pantalla.espejo._de_codigo(int(d[0]))
	if c == null or c != _pantalla._player or int(_pantalla._dueno_aliado.get(c, 0)) != emisor:
		return
	if int(d[1]) < 0 or d.size() < FLOATS_HUELLA:
		_anotar_huella_red(c, CLASE_APUNTANDO, null, 0.0)
		return
	var x: Array = _desempaquetar(d, 0)
	_anotar_huella_red(c, CLASE_APUNTANDO, x[2], x[3])


# Cada fotograma en quien lleva la pelea: reparte si algo cambio (o cada medio segundo, por si se
# perdio un paquete). La de un turno que ya se fue, fuera.
func _tick_huellas(delta: float) -> void:
	if _pantalla._espejo or not Net.activo:
		return
	# La de apuntar solo vive mientras es el turno de ese: si se fue sin avisar, se borra aqui.
	for cod in _huellas_red.keys():
		var d: PackedFloat32Array = _huellas_red[cod]
		if int(d[1]) == CLASE_APUNTANDO and (_pantalla._state != _pantalla.State.WAITING_PLAYER
				or _pantalla.espejo._de_codigo(int(d[0])) != _pantalla._player):
			_huellas_red.erase(cod)
			_huellas_cambiadas = true
	_t_huellas += delta
	_t_repetir += delta
	if _t_huellas < ENVIO_HUELLAS or (not _huellas_cambiadas and _t_repetir < REPETIR_HUELLAS):
		return
	_t_huellas = 0.0
	_t_repetir = 0.0
	_huellas_cambiadas = false
	Net.peleas.difundir_huellas(estado_huellas())


func estado_huellas() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for cod in _huellas_red:
		out.append_array(_huellas_red[cod])
	return out


# EN EL ESPEJO: llegan todas las huellas vivas. Se quitan las que pinte antes y se ponen estas, menos
# la MIA mientras apunto (esa la pinto yo, al momento).
func aplicar_huellas(d: PackedFloat32Array) -> void:
	if not _pantalla._espejo:
		return
	var arena: ArenaCombate = _arena()
	if arena == null:
		return
	for k in _claves_red:
		arena.quitar_huella(k)
	_claves_red.clear()
	var i: int = 0
	while i + FLOATS_HUELLA <= d.size():
		var x: Array = _desempaquetar(d, i)
		i += FLOATS_HUELLA
		var c: Combatant = _pantalla.espejo._de_codigo(int(x[0]))
		if int(x[1]) == CLASE_APUNTANDO and _apuntando != null and c == _quien:
			continue
		var clave: String = "red_%d_%d" % [int(x[0]), int(x[1])]
		arena.poner_huella(clave, x[2], x[3],
			COLOR_CARGA if int(x[1]) == CLASE_CARGA else COLOR_APUNTE)
		_claves_red.append(clave)


const COLOR_APUNTE := Color(1.0, 0.75, 0.3)
const COLOR_CARGA := Color(1.0, 0.45, 0.25)


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
	_vigilar_alcance()
	# SE ANDA con la barra de acciones delante, en el menu de habilidades y APUNTANDO una: recolocarse
	# mientras eliges como golpear es justo lo que hace falta (lo pidio el usuario: tener que volver
	# atras del todo para dar dos pasos y volver a elegir la habilidad era un engorro). No en los
	# demas submenus (hechizos, objetos) ni con la pregunta de huir delante.
	var en_menu: bool = (_pantalla._actions_box != null and _pantalla._actions_box.visible) \
		or (_pantalla._ability_box != null and _pantalla._ability_box.visible) or _apuntando != null
	var puede: bool = _radio > 0.0 and en_menu and not _preguntando()
	var dir: Vector2 = Vector2.ZERO
	if puede:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# El joystick de la pantalla manda cuando hay un dedo puesto (igual que en player.gd).
		if Tactil.activo and Tactil.eje != Vector2.ZERO:
			dir = Tactil.eje
	if dir == Vector2.ZERO:
		if _andando:
			_andando = false
			# Apuntando, al pararte te GIRAS hacia el raton (lo pidio el usuario): es lo que vas a golpear.
			if _apuntando != null:
				_animar(_cuerpo, _raton_en_mundo() - _cuerpo.global_position, false)
				_pillados_vistos = -1   # que el letrero vuelva a decir a cuantos pilla
				_refrescar_apunte(_raton_en_mundo())
			else:
				_animar(_cuerpo, _mirada_de(_cuerpo), false)
		return
	var antes: Vector2 = _cuerpo.global_position
	var nueva: Vector2 = paso(antes, dir.limit_length(1.0) * VEL_PASEO * delta, _inicio, _radio,
		_dentro(arena), _puede_estar.bind(_cuerpo))
	_colocar(_quien, _cuerpo, nueva)
	_andando = true
	# Apuntando, la huella viene contigo, pero el personaje ANDA de verdad, mirando hacia donde va (lo pidio
	# el usuario: antes miraba al raton y se le pedian dos poses por fotograma, quieto y andando, y la de
	# andar volvia a empezar cada vez: se quedaba tieso). Al pararse se gira hacia el raton.
	if _apuntando != null:
		_refrescar_apunte(_raton_en_mundo())
	_animar(_cuerpo, dir, true)


# LOS BOTONES CAMBIAN SEGUN ANDAS: al entrar en el alcance de alguien, Atacar se enciende; al salir
# de todos, pasa a Esperar. Solo se repintan cuando algo cambia (tambien si pulsas a otro enemigo),
# no cada fotograma: _refresh_actions reescribe los tooltips de toda la barra.
var _alcance_visto: Array = []

func _vigilar_alcance() -> void:
	var ahora: Array = [_pantalla._target_idx, llega(_quien, _pantalla._objetivo()), llega_a_alguno(_quien)]
	if ahora != _alcance_visto:
		_alcance_visto = ahora
		if _pantalla._actions_box != null and _pantalla._actions_box.visible:
			_pantalla._refresh_actions()


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
	var presa: Combatant = _presa_de(e)
	# Aturdido pierde el turno de todas formas: andar y luego no hacer nada seria contarlo mal. Y el
	# que ya tiene a alguien a tiro no se mueve: pega desde donde esta.
	if cuerpo == null or presa == null or radio <= 0.0 or e.aturdido() \
			or hueco_entre(e, presa) <= alcance_de(e) * ARRIMARSE:
		_turno_enemigo_de_siempre(e)
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
	if not is_instance_valid(_cuerpo) or _presa == null or not _presa.is_alive():
		_actuar()
		return
	var falta: float = hueco_entre(_quien, _presa) - alcance_de(_quien) * ARRIMARSE
	if falta <= 0.0 or _t_acercar >= TOPE_ACERCARSE:
		_actuar()
		return
	var hacia: Vector2 = pos_de(_presa) - _cuerpo.global_position
	var antes: Vector2 = _cuerpo.global_position
	var quiere: float = minf(VEL_ACERCARSE * dt, falta)
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
		var mira: Vector2 = pos_de(_presa) - _cuerpo.global_position \
			if _presa != null else _mirada_de(_cuerpo)
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
		_turno_enemigo_de_siempre(e)


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


# A QUIEN SE ACERCA: al de los tuyos que tenga mas cerca (por el hueco, como se mide el alcance). No
# es necesariamente a quien pega: eso lo sortea _enemy_turn por amenaza ENTRE LOS QUE ALCANZA al
# acabar de andar (ver objetivos._elegir_objetivo_enemigo). Si no alcanza a nadie, pierde el ataque.
func _presa_de(e: Combatant) -> Combatant:
	var mejor: Combatant = null
	var d_mejor: float = INF
	for c in _pantalla._aliados_vivos():
		var d: float = hueco_entre(e, c)
		if d < d_mejor:
			d_mejor = d
			mejor = c
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
	_alcance_visto = []
	_dejar_de_apuntar()
	_hay_apunte = false
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
	if not _sobre_suelo(p, cuerpo):
		return false
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
	# LOS TUYOS TAMBIEN CHOCAN ENTRE SI (lo pidio el usuario: se le montaban uno encima de otro), pero
	# con una excepcion: el que ya ESTA encima de un compañero lo atraviesa hasta despegarse. El grupo
	# entra a la pelea en fila, y sin esto el que va el ultimo no podia ni salir de detras de los suyos.
	# Los enemigos entre ellos siguen sin chocar: su acercamiento no sabe rodear a los suyos.
	if not soy_enemigo:
		for c in _pantalla._aliados:
			if not c.is_alive():
				continue
			var comp: Node2D = cuerpo_de(c)
			if not is_instance_valid(comp) or comp == cuerpo:
				continue
			var oc: Vector2 = comp.global_position
			if antes.distance_to(oc) >= SEPARACION and p.distance_to(oc) < SEPARACION:
				return false
	return true


# ¿Toda la huella de ESTE cuerpo en 'p' cae sobre suelo que se pisa?
func _sobre_suelo(p: Vector2, cuerpo: Node2D) -> bool:
	var piso: Node = Game.get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("_pisable_px"):
		var h: Rect2 = _huella(cuerpo)
		for esquina in [h.position, Vector2(h.end.x, h.position.y),
				Vector2(h.position.x, h.end.y), h.end]:
			if not piso._pisable_px(p + esquina):
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


# ------------------------------------------------------------
#  EL TIRON (Desgarro, 24/09)
# ------------------------------------------------------------
# Lo pide quien RESUELVE la habilidad (AbilityData.tiron) y se hace cuando la cola ENSEÑA el golpe
# (CombatFX.golpe_encajado): el hacha entra y se lo trae. Solo en quien lleva la pelea; las demas
# pantallas lo ven por el mismo canal que el paso de un bicho (_apuntar_bicho / _enviar_bichos). Si el
# golpe no llega a verse (sin capa de efectos), se hace igual al cabo de T_TIRON_ESPERA.
# Nunca hasta meterselo encima: se para a ALCANCE_MINIMO de quien tira, en una pared o en el borde.
const T_TIRON := 0.18
const T_TIRON_ESPERA := 3.0
var _tirones: Array = []   # {c, de, px, espera, t, desde, hasta}

func pedir_tiron(c: Combatant, de: Combatant, px: float) -> void:
	if _pantalla._espejo or c == null or de == null or px <= 0.0:
		return
	_tirones.append({"c": c, "de": de, "px": px, "espera": 0.0, "t": -1.0})


func _on_golpe_encajado(b: Dictionary, _dur: float) -> void:
	for tr in _tirones:
		if float(tr["t"]) < 0.0 and is_same(_pantalla._bloque_de(tr["c"]), b):
			_arrancar_tiron(tr)


# LA SANGRE DEL HACHA (24/09): cada golpe de hacha que ENTRA salpica desde el cuerpo que lo encaja, hacia
# donde va el tajo: los barridos de lado (el Brutal hacia su giro, la Carniceria alternando), la Hendedura
# hacia fuera y el Desgarro hacia quien tira, dejando ademas el surco del arrastre. En todas las maquinas.
const _SANGRA := [CombatFX.Estilo.HACHA_TAJO, CombatFX.Estilo.HENDEDURA, CombatFX.Estilo.HACHAZO_BRUTAL,
	CombatFX.Estilo.CARNICERIA, CombatFX.Estilo.DESGARRO,
	# La DAGA (24/09): poca, de los tajos; la Puñalada, un chorro por detras (por donde asoma la punta).
	CombatFX.Estilo.DAGA_CORTE, CombatFX.Estilo.DAGA_RAFAGA, CombatFX.Estilo.PUNALADA]

func _on_impacto(ev: Dictionary) -> void:
	var estilo: int = int(ev.get("estilo", 0))
	if not _pantalla.tactico or estilo not in _SANGRA:
		return
	var v: Combatant = _de_bloque(ev["bv"])
	var cuerpo: Node2D = cuerpo_de(v)
	var arena: ArenaCombate = _arena()
	if cuerpo == null or arena == null:
		return
	var a: Combatant = _de_bloque(ev["ba"])
	var r: Rect2 = bulto_de(v)
	var pies_v: Vector2 = pies_de(v)
	var desde: Vector2 = r.get_center() if r.has_area() else pies_v + Vector2(0.0, -12.0)
	var radial: Vector2 = (pies_v - pies_de(a)).normalized() if a != null and cuerpo_de(a) != null else Vector2.RIGHT
	var dir: Vector2 = radial.rotated(PI * 0.5) * 0.85 + radial * 0.45
	var fuerza: float = clampf(float(ev.get("peso", 1.0)), 0.3, 1.5) * (1.35 if bool(ev.get("crit", false)) else 1.0)
	match estilo:
		CombatFX.Estilo.HACHAZO_BRUTAL:
			fuerza *= 1.4
		CombatFX.Estilo.CARNICERIA:
			var lado: float = 1.0 if int(ev.get("pos_tanda", 0)) % 2 == 0 else -1.0
			dir = radial.rotated(PI * 0.5 * lado) * 0.85 + radial * 0.45
			fuerza *= 0.8
		CombatFX.Estilo.HENDEDURA:
			dir = radial
		CombatFX.Estilo.DESGARRO:
			dir = -radial
			SangreMapa.surco(arena, cuerpo, pies_v - cuerpo.global_position)
		CombatFX.Estilo.HACHA_TAJO:
			fuerza *= 0.6
		CombatFX.Estilo.DAGA_CORTE, CombatFX.Estilo.DAGA_RAFAGA:
			fuerza *= 0.35
		CombatFX.Estilo.PUNALADA:
			dir = radial
			fuerza *= 0.8
	SangreMapa.salpicar(arena, desde, pies_v, dir, fuerza, int(ev.get("semilla", 1)))


# EL DIBUJO DE UN GOLPE DE DAGA, sobre el cuerpo de verdad (CombatFX.dibujo_en_mapa). En todas las
# maquinas, esquivado o no. 'vuelo' = lo que falta para el golpe, en tiempo de la pelea.
func _on_dibujo_mapa(ev: Dictionary, vuelo: float) -> void:
	var arena: ArenaCombate = _arena()
	if arena == null or not _pantalla.tactico:
		return
	var v: Combatant = _de_bloque(ev["bv"])
	var a: Combatant = _de_bloque(ev["ba"])
	if v == null or cuerpo_de(v) == null:
		return
	var estilo: int = int(ev.get("estilo", 0))
	var ritmo: float = _pantalla._fx.escala_tiempo if _pantalla._fx != null else 1.0
	var semilla: int = (int(ev.get("semilla", 1)) ^ (int(ev.get("pos_tanda", 0)) * 7919)) | 1
	if estilo == CombatFX.Estilo.IMBUIR_FILO:
		DagaAire.ponzona(arena, cuerpo_de(v).get("_muneco"), semilla, vuelo, ritmo)
		return
	var modo: int = DagaAire.Modo.TAJO
	if estilo == CombatFX.Estilo.DAGA_RAFAGA:
		modo = DagaAire.Modo.RAFAGA
	elif estilo == CombatFX.Estilo.PUNALADA:
		modo = DagaAire.Modo.PUNALADA
	var caja: Rect2 = bulto_de(v)
	# De donde viene: la altura del pecho del que pega (sin el, desde su lado del cuerpo).
	var desde: Vector2 = pies_de(a) + Vector2(0.0, -DagaAire.ALTO_TORSO) if a != null and cuerpo_de(a) != null \
		else caja.get_center() - Vector2(20.0, 0.0)
	DagaAire.golpe(arena, modo, desde, caja, bool(ev.get("evadido", false)), bool(ev.get("crit", false)),
		int(ev.get("pos_tanda", 0)), semilla, vuelo, ritmo)


# El combatiente de un bloque de la pelea (aliado o enemigo). null si no es de nadie.
func _de_bloque(b) -> Combatant:
	if not b is Dictionary:
		return null
	for c in _pantalla._enemies:
		if is_same(_pantalla._bloque_de(c), b):
			return c
	for c in _pantalla._aliados:
		if is_same(_pantalla._bloque_de(c), b):
			return c
	return null


func _arrancar_tiron(tr: Dictionary) -> void:
	var c: Combatant = tr["c"]
	var cuerpo: Node2D = cuerpo_de(c)
	tr["t"] = 0.0
	tr["desde"] = Vector2.ZERO
	tr["hasta"] = Vector2.ZERO
	if cuerpo == null or not c.is_alive() or cuerpo_de(tr["de"]) == null:
		return
	var desde: Vector2 = cuerpo.global_position
	var largo: float = minf(float(tr["px"]), maxf(0.0, hueco_entre(tr["de"], c) - ALCANCE_MINIMO))
	tr["desde"] = desde
	tr["hasta"] = desde + (pos_de(tr["de"]) - desde).normalized() * largo


func _tick_tirones(delta: float) -> void:
	if _tirones.is_empty():
		return
	var dentro: Rect2 = _dentro(_arena())
	for tr in _tirones.duplicate():
		if float(tr["t"]) < 0.0:
			tr["espera"] = float(tr["espera"]) + delta
			if float(tr["espera"]) >= T_TIRON_ESPERA:
				_arrancar_tiron(tr)
			continue
		var c: Combatant = tr["c"]
		var cuerpo: Node2D = cuerpo_de(c)
		var desde: Vector2 = tr["desde"]
		var hasta: Vector2 = tr["hasta"]
		if cuerpo == null or not c.is_alive() or desde.is_equal_approx(hasta):
			_tirones.erase(tr)
			continue
		tr["t"] = float(tr["t"]) + delta * _pantalla._vel_pelea
		var u: float = clampf(float(tr["t"]) / T_TIRON, 0.0, 1.0)
		# Arranca de golpe y frena al llegar: es un tiron, no un paseo.
		var p: Vector2 = desde.lerp(hasta, 1.0 - (1.0 - u) * (1.0 - u))
		if not _sobre_suelo(p, cuerpo) or (dentro.has_area() and not dentro.has_point(p)):
			_tirones.erase(tr)
			continue
		_colocar(c, cuerpo, p)
		_apuntar_bicho(cuerpo, false)
		if u >= 1.0:
			_tirones.erase(tr)
	_enviar_bichos()


# ------------------------------------------------------------
#  EL SALTO A LA ESPALDA (Oportunista de la daga, 24/09)
# ------------------------------------------------------------
# El que lo hace APARECE detras del enemigo, del otro lado de 'desde' (el mismo, con la habilidad; el
# compañero que acaba de pegarle, al entrar detras). El SITIO lo decide quien lleva la pelea con sus
# posiciones y viaja al espejo en el paquete de impactos, delante de los golpes (espejo._apuntar_salto_red).
# Cada maquina lo hace cuando ARRANCA su gesto de golpear (CombatFX.gesto_iniciado): primero aparece,
# despues apuñala. Solo mueve el cuerpo quien lo mueve siempre (_es_mio); quien lleva la pelea apunta
# ademas el sitio en _pos, que es donde la pelea cuenta que esta el personaje de otro humano.
const T_SALTO_ESPERA := 3.0   # si el gesto no llega a verse (sin capa de efectos), se hace igual
const HUECO_ESPALDA := 2.0
var _saltos: Array = []   # {c, hasta (el nodo), hacia (los pies del enemigo), espera}

func pedir_salto(c: Combatant, victima: Combatant, desde: Combatant) -> void:
	if _pantalla._espejo or not _pantalla.tactico or c == null or victima == null:
		return
	var p = sitio_a_la_espalda(c, victima, desde)
	if p == null:
		return
	var hacia: Vector2 = pies_de(victima)
	if not _es_mio(c):
		_pos[c] = p
	_pantalla.espejo._apuntar_salto_red(c, p, victima)
	anotar_salto(c, p, hacia)


# Tambien en el espejo, al leer el paquete de impactos.
func anotar_salto(c: Combatant, hasta: Vector2, hacia: Vector2) -> void:
	if c == null:
		return
	_saltos.append({"c": c, "hasta": hasta, "hacia": hacia, "espera": 0.0})


# DONDE SE PONE (el nodo, no los pies), o null si no hay sitio. Pegado al enemigo por detras: sus pies, mas
# lo que pisa el enemigo y medio de lo que pisa el que salta. Si detras hay pared o se sale de la arena,
# prueba a los lados, cada vez mas abiertos hacia el frente.
func sitio_a_la_espalda(c: Combatant, victima: Combatant, desde: Combatant):
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null or cuerpo_de(victima) == null:
		return null
	var pv: Vector2 = pies_de(victima)
	var dir: Vector2 = pv - pies_de(desde if desde != null else c)
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var largo: float = maxf(radio_pisa(victima), 8.0) + radio_pisa(c) * 0.5 + HUECO_ESPALDA
	var dentro: Rect2 = _dentro(_arena())
	for giro in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.0, -2.0]:
		var nodo: Vector2 = pv + dir.rotated(float(giro) * PI * 0.25) * largo \
			- Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
		if _sobre_suelo(nodo, cuerpo) and (not dentro.has_area() or dentro.has_point(nodo)):
			return nodo
	return null


func _on_gesto_salto(b: Dictionary, _dir: int, _dur: float, _anim: StringName) -> void:
	if _saltos.is_empty():
		return
	var c: Combatant = _de_bloque(b)
	for s in _saltos:
		if s["c"] == c:
			_hacer_salto(s)
			return


func _hacer_salto(s: Dictionary) -> void:
	_saltos.erase(s)
	var c: Combatant = s["c"]
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null or not c.is_alive():
		return
	# LA SOMBRA se ve en todas las pantallas; el cuerpo solo lo mueve quien lo mueve siempre.
	var arena: ArenaCombate = _arena()
	if arena != null:
		var bajo := Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
		DagaAire.sombra(arena, cuerpo.global_position + bajo, Vector2(s["hasta"]) + bajo,
			int(Vector2(s["hasta"]).x * 31.0) | 1, _pantalla._fx.escala_tiempo if _pantalla._fx != null else 1.0)
	if not _es_mio(c):
		return
	_colocar(c, cuerpo, s["hasta"])
	# Mirando al enemigo: el gesto que arranca ahora mismo lee esta mirada (ver gesto_en_mapa).
	_animar(cuerpo, Vector2(s["hacia"]) - Vector2(s["hasta"]) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO), false)
	# El circulo de andar de su turno ya no vale: se quedaria pintado donde estaba.
	if _quien == c and _fase == Fase.MOVIENDO:
		_inicio = cuerpo.global_position


func _tick_saltos(delta: float) -> void:
	for s in _saltos.duplicate():
		s["espera"] = float(s["espera"]) + delta
		if float(s["espera"]) >= T_SALTO_ESPERA:
			_hacer_salto(s)


# ------------------------------------------------------------
#  EL GESTO DEL CUERPO en el mapa (24/09)
# ------------------------------------------------------------
# Cuando la pelea avisa de que uno de los tuyos hace su gesto (CombatFX.gesto_iniciado), lo hace SU
# CUERPO DEL MAPA, mirando hacia donde golpea (su _facing: apuntando ya se giro hacia el raton). La
# animacion la dice el estilo de la habilidad (CombatFX.ANIM_CUERPO_MAPA); sin ella, el golpe de su
# arma. Al acabar vuelve a la guardia (o a la pose de carga, si esta cargando).
# El MOLINETE no es una animacion sino un GIRO: la pose de espada extendida pasando por las ocho
# direcciones, dos vueltas en el sentido de las agujas como su estela (BarridoAire.GIRO).
const T_VUELTA_MOLINETE := 0.2    # = BarridoAire.T_ENTRE: una vuelta por golpe
var _gestos_mapa: Dictionary = {}   # cuerpo -> {t, dur, anim, d0, m}

func gesto_en_mapa(c: Combatant, anim: String, dur: float) -> bool:
	var cuerpo: Node2D = cuerpo_de(c)
	if cuerpo == null:
		return false
	var m = cuerpo.get("_muneco")
	if not (m is MunecoJugador) or not (m as MunecoJugador).hay_dibujo():
		return false
	if anim == "":
		anim = _pantalla.figuras._anim_golpe_de(c)
	# UN GESTO POR ACCION: la pelea vuelve a avisar en cada impacto (uno por golpe y victima), y con su
	# animacion entera ya cubriendo todos los golpes, reiniciarla la cortaba a medias.
	if _gestos_mapa.has(cuerpo) and String(_gestos_mapa[cuerpo]["anim"]) == anim:
		return true
	var d: int = SpriteLienzo.dir8(_mirada_de(cuerpo))
	var escala: float = _pantalla._fx.escala_tiempo if _pantalla._fx != null else 1.0
	(m as MunecoJugador).velocidad = escala
	(m as MunecoJugador).animar("%s_%d" % [anim, d])
	_gestos_mapa[cuerpo] = {"t": 0.0, "dur": maxf(dur, 0.3), "anim": anim, "d0": d, "m": m,
		"escala": escala}
	return true


func _tick_gestos(delta: float) -> void:
	for cuerpo in _gestos_mapa.keys():
		var g: Dictionary = _gestos_mapa[cuerpo]
		# El reloj del gesto va en tiempo REAL (su 'dur' viene asi); el giro del Molinete, en el de la pelea.
		g["t"] = float(g["t"]) + delta
		if not is_instance_valid(cuerpo) or not is_instance_valid(g["m"]):
			_gestos_mapa.erase(cuerpo)
			continue
		var t: float = float(g["t"])
		if String(g["anim"]) == "molinete":
			# Las direcciones van 0 = S, 1 = SE, 2 = E...: al reves de las agujas en pantalla. Restar es girar
			# como la estela. 8 pasos por vuelta, dos vueltas, y se queda mirando a donde empezo.
			var paso: int = mini(int(t * float(g["escala"]) / (T_VUELTA_MOLINETE / 8.0)), 16)
			(g["m"] as MunecoJugador).animar("molinete_%d" % posmod(int(g["d0"]) - paso, 8))
		if t >= float(g["dur"]) and (String(g["anim"]) != "molinete"
				or t * float(g["escala"]) >= 2.0 * T_VUELTA_MOLINETE):
			_gestos_mapa.erase(cuerpo)
			(g["m"] as MunecoJugador).velocidad = 1.0
			_animar(cuerpo, _mirada_de(cuerpo), false)


# EL CORTE DEL BASICO DEL MANDOBLE sobre 'obj' (BarridoAire.TAJO): centrado en su cuerpo tal como se ve,
# de su tamaño (sin pasarse: "no tan grande") y en diagonal hacia abajo, hacia el lado al que golpeas.
# 'fallo' (esquivado): el corte pasa AL LADO, tenue. Viaja en la apertura (1 = fallo), que la red ya lleva.
func forma_corte(a: Combatant, obj: Combatant, fallo: bool = false) -> CombatFormas.Forma:
	var r: Rect2 = bulto_de(obj)
	var centro: Vector2 = r.get_center() if r.has_area() else pos_de(obj)
	var largo: float = clampf(r.size.y * 0.95, 18.0, 32.0) if r.has_area() else 26.0
	var cu: Node2D = cuerpo_de(a)
	var lado: float = -1.0 if cu != null and _mirada_de(cu).x < 0.0 else 1.0
	if fallo:
		centro += Vector2(-lado * r.size.x * 0.75, 0.0) if r.has_area() else Vector2(-lado * 14.0, 0.0)
	return CombatFormas.cono(centro, Vector2(0.45 * lado, 1.0), largo, 1.0 if fallo else 0.0)


# El combatiente de uno de los cuerpos de los tuyos (null si no es de ninguno).
func _aliado_de_cuerpo(cuerpo: Node2D) -> Combatant:
	for c in _pantalla._aliados:
		if cuerpo_de(c) == cuerpo:
			return c
	return null


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
		# En pleno gesto (el Molinete girando, un tajo bajando) no se le pisa con la guardia.
		if _gestos_mapa.has(cuerpo):
			return
		# CARGANDO, quieto: el arma en alto hasta soltarla (lo pidio el jefe: "que mantenga el martillo en
		# alto hasta que golpea el suelo").
		var c: Combatant = _aliado_de_cuerpo(cuerpo)
		if not moviendose and c != null and (_cargas.has(c) or c.charging != null):
			(muneco as MunecoJugador).animar("en_alto_%d" % SpriteLienzo.dir8(dir))
			return
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
