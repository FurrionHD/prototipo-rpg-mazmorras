# ============================================================
#  combat.gd
#  Pantalla de combate por turnos INTERACTIVA (N enemigos contra TU GRUPO, hasta MAX_ENEMIGOS
#  por bando). Recibe los combatientes reales (los tuyos y los enemigos) desde Game via setup().
#  Si se abre sola (F6), usa combatientes de PRUEBA (tres aliados y tres slimes).
#  Orden de turnos ATB (cada uno llena su barra a ritmo de su velocidad); cuando le toca a uno de
#  los tuyos se pausa y esperas a elegir SU accion; los enemigos actuan solos.
#
#  COMBATE EN GRUPO: bajan contigo hasta PARTY_MAX personas y pelean TODAS. Cada una tiene su
#  barra ATB, su equipo, sus habilidades y sus hechizos, y las controlas tu (ninguna actua sola).
#  La pieza que lo hace posible sin reescribir la pantalla entera es que `_player` dejo de ser
#  "el jugador" para ser EL ALIADO QUE ACTUA AHORA: todo el codigo de acciones, magia,
#  habilidades y objetos sigue leyendo `_player` y opera sobre quien tenga el turno.
#  Lo que era estado global del jugador (defendiendo, conjuro a medias, acciones lentas) es ahora
#  UNO POR ALIADO; se guarda en diccionarios y se lee con las mismas variables de siempre gracias
#  a que son propiedades con get/set (ver mas abajo).
#
#  Las POCIONES ya se pueden apuntar a otro aliado (submenu Objeto -> pocion -> a quien): el que
#  la usa gasta SU turno, pero la cura va a quien elijas. Fuera de alcance por ahora: apuntar un
#  HECHIZO a un aliado; los ataques siguen yendo al enemigo marcado.
#
#  La escena solo trae el esqueleto: TODO lo demas se genera por codigo (convencion del
#  proyecto), incluidos los BLOQUES de combatiente (nombre + estados + barra de vida), que
#  no pueden ser nodos fijos porque su numero depende de cuantos bichos entren.
#
#    Combat (Control)  <- este script
#    └── VBox (VBoxContainer, pantalla completa)
#        ├── _bloques_box (HBox)  <- los N enemigos, EN FILA y con ANCHO_BLOQUE fijo
#        ├── _aliados_box (HBox)  <- los tuyos, en el mismo formato y con el mismo ancho
#        ├── Log (Label)
#        ├── AttackButton (Button)   <- reutilizado como "Continuar" al terminar
#        └── barra de acciones + submenus (magia / habilidades / objetos)
# ============================================================

extends Control

const UMBRAL := 100.0          # cuanto llenar la barra para actuar
const SPEED_SCALE := 10.0      # ritmo de llenado (mas alto = combate mas rapido)
const INICIATIVA_VENTAJA := 50.0  # media barra de ventaja para quien inicia

# Si entras AGOTADO, tus primeras acciones van mas lentas.
const EXHAUSTED_SLOW_ACTIONS := 2   # cuantas acciones afectadas
const EXHAUSTED_RATE := 0.5         # a que ritmo (0.5 = la mitad)

# Huir (KAN-55): entrar agotado dificulta la huida (la probabilidad se multiplica).
const FLEE_EXHAUSTED_MULT := 0.6

# Tope de golpes esquivados que cuentan para la Agilidad dentro de UNA habilidad enemiga multi-golpe.
# Sin tope, una habilidad de cinco golpes esquivada entera rendiria cinco veces lo que un ataque
# normal esquivado; con el, esquivar un chaparron sigue valiendo mas que esquivar un golpe suelto
# (es mas dificil) pero no se dispara.
const ESQUIVA_HAB_MAX := 2.0

# Magia (KAN-56): nº de opciones del test de recitado (a/b/c/d). El maná se recupera
# PEGANDO (_ganar_mana_golpe) y GANANDO el combate (_end): ya no hay goteo por turno,
# salvo el que aporte el arma magica (mp_regen_turno).
const N_OPCIONES_TEST := 4

# Aturdir/retrasar (armas contundentes). Golpe NORMAL que aturde = retraso PARCIAL de
# barra ATB (stagger, franja de abajo). Golpe CRITICO que aturde = ESTADO Aturdido
# (pierde su proximo turno, lo gestiona el motor de estados). Ver _aplicar_aturdir.
const ATB_STUN_MIN := 0.30   # retraso parcial minimo (fraccion de barra)
const ATB_STUN_MAX := 0.60   # retraso parcial maximo

# AUTORREGENERACION (habilidad de desarrollo): vida que recuperas al empezar tu turno, en % de
# tu vida MAXIMA. En % y no plano a proposito: si fuera plano, se volveria irrelevante en cuanto
# la vida escale. PROVISIONAL -> Excel. Ver _begin_player_turn.
const AUTORREGEN_PCT := 0.04

# Energia de combate (KAN-57): Defender y HABILIDADES gastan; el ataque basico regenera.
# Asi no puedes turtlear: hay que pegar para poder defender/soltar habilidades. PROVISIONAL.
const DEFEND_ENERGY_COST := 15.0
# El basico REGENERA energia: es la "recarga" entre habilidades. Subido de 12 a 28 (KAN-57
# rebalance): las habilidades ahora gastan mucho mas, asi que pegar basico tiene que devolver
# energia de verdad -> el ritmo es habilidad -> un par de basicos para recargar -> habilidad,
# en vez de spamear habilidades. PROVISIONAL -> Excel.
const ATTACK_ENERGY_REGEN := 28.0

# PROVOCACION (taunt de escudo): cuanto MAS pesa un aliado que provoca al sortear el objetivo del
# enemigo, frente a los que no (peso 1.0). x4 => con 1 provocador entre 4, ~57% de los golpes van a
# el; el resto se reparte. No es forzado: solo inclina la balanza. PROVISIONAL -> playtest.
const PROVOCA_PESO := 4.0

@onready var _log: Label = $VBox/Log
# La escena trae un unico boton (AttackButton). Ahora las 4 acciones se crean por
# codigo (barra de acciones, KAN-55) y ESE boton se reutiliza como "Continuar" al
# terminar el combate.
@onready var _continue_button: Button = $VBox/AttackButton

# La COLUMNA del combate ($VBox de la escena, a pantalla completa).
var _col: VBoxContainer = null
# Fila de los ENEMIGOS: van uno AL LADO DEL OTRO, no apilados.
var _bloques_box: HBoxContainer = null
# Fila de los TUYOS: un bloque por miembro del grupo, con el mismo formato y el mismo ancho que
# los de enfrente. Son combatientes como los demas.
var _aliados_box: HBoxContainer = null

# ANCHO FIJO de un bloque de combatiente, tuyo o del enemigo. Es la clave del combate en grupo:
# si la barra de vida se estirase (como hacia en el 1v1, ocupando el ancho entero), cinco
# enemigos serian cinco franjas apiladas y la pelea se leeria como una lista. Con un ancho fijo
# caben los cinco EN FILA, y esa fila es la que numera la barra de accion: el nº2 de abajo es
# el 2º empezando por la izquierda. Tiene que caber el CASO PEOR: MAX_ENEMIGOS (5) bloques + sus
# separaciones dentro del viewport base (1152). 216 x 5 + 8 x 4 = 1112 < 1152: entra con un pelin
# de margen a cada lado (antes era 260, sizeado para 4, y con 5 se cortaba por los lados).
#
# Tu bloque mide LO MISMO que uno enemigo, aunque hoy este solo y le sobre sitio a los lados: es
# un combatiente como los demas, y en cuanto haya companeros seran varios repartiendose la fila.
# Que ya tenga su tamaño definitivo evita que el dia que entre el primer aliado se recoloque
# todo de golpe.
const ANCHO_BLOQUE := 216.0
# ...pero eso ya NO es el ancho de la pantalla. El log se mudo a una columna de la derecha, asi que
# los bloques viven en lo que queda (viewport - ANCHO_LOG - margenes), y ahi 5 x 216 no entran: la
# fila esta CENTRADA, asi que lo que sobraba se salia por los dos lados y el bicho nº1 se quedaba
# medio fuera de la pantalla. Cuando no caben a su ancho preferido se encogen a partes iguales,
# hasta este minimo (donde todavia se leen el numero y la barra de vida).
#
# Encogerlos y no partirlos en dos filas: la fila ES la numeracion que usa la barra de accion (el
# nº2 es el 2º empezando por la izquierda), y en dos filas eso deja de leerse de un vistazo.
const ANCHO_BLOQUE_MIN := 118.0
const SEP_BLOQUES := 8.0
# Alto RESERVADO para los estados: dos filas de chips. Se reserva SIEMPRE, haya estados o no,
# para que entrar o salir uno no mueva de sitio la barra de vida ni nada de lo que hay debajo.
# Dos filas y no una porque en un bloque de 260 px solo caben ~3 chips por fila, y un bicho
# bien castigado (veneno + quemadura + pegajoso + imbuicion) pasa de eso con facilidad.
const ALTO_CHIPS := 56.0

# Sistema de ACCIONES (KAN-55): barra con Atacar / Magia / Defender / Huir. Se
# genera por codigo (convencion: UI por codigo por ahora) y es de datos, asi
# futuras acciones (habilidades, objetos) solo añaden una entrada.
enum Action { ATTACK, HABILIDAD, MAGIC, DEFEND, OBJETO, FLEE }
var _actions_box: Container = null       # rejilla 2x3 de las seis acciones
var _panel_acciones: VBoxContainer = null  # la columna de la derecha donde viven todas
var _action_buttons: Dictionary = {}   # Action(int) -> Button
var _ability_box: VBoxContainer = null   # submenu de habilidades (KAN-57)
var _objeto_box: VBoxContainer = null    # submenu de objetos/pociones (KAN-57)

# BLOQUES de combatiente. Uno por enemigo (mismo orden e indice que _enemies) y uno por aliado
# (mismo orden e indice que _aliados). Cada bloque es un Dictionary {panel, nombre, chips, hp,
# hp_lbl, vbox} — ver _crear_bloque. Los chips llevan tooltip por estado activo: antes los estados
# iban como texto DENTRO de la etiqueta del nombre, y un Label no se puede señalar por trozos
# (veias "☠x2·3t" sin forma de saber que hacia eso ni cuanto).
var _bloques: Array[Dictionary] = []   # indice = indice en _enemies
var _bloques_aliados: Array[Dictionary] = []   # indice = indice en _aliados

# --- Casteo de hechizos (KAN-56) ---
# Submenu de hechizos (al pulsar Magia) y caja dinamica del recitado/disparo.
var _spell_box: VBoxContainer = null
var _cast_box: VBoxContainer = null

# Linea de ORDEN DE TURNOS (estilo Epic Seven), creada por codigo.
var _timeline: Control = null

# Se emite al cerrar el combate (lo escucha Game para reanudar la mazmorra).
# Los tres primeros arrays van POR ALIADO, en el mismo orden en que llegaron a setup(): la vida,
# el maná (KAN-56) y la energia = stamina de exploracion (KAN-57) con los que sale cada uno.
# 'muertos' = INDICES (en la lista que paso setup()) de los enemigos que han caido, y 'enemy_hp_left'
# la vida que le queda a cada uno, tambien por indice. Van indices y no Combatants para no
# filtrar objetos de combate a Game, que solo necesita saber a que NODO matar o dejar herido.
# OJO: los muertos son la unica fuente de verdad, y NO se deducen de player_won: si huyes tras
# matar a dos de cuatro, esos dos estan muertos igual y tienen que dejar su cadaver.
# 'enemy_estados_left' va tambien por indice: los estados con los que se queda cada superviviente
# (el veneno le sigue corriendo por el mapa, ver Enemy._tick_estados_fuera).
signal combat_finished(player_won: bool, hp_left: Array, mp_left: Array,
	energy_left: Array, muertos: Array, enemy_hp_left: Array, duenos: Array,
	enemy_estados_left: Array)

# TU GRUPO. Orden FIJO (el que mando Game: el lider primero y detras los companeros), igual que
# _enemies: es el orden de los bloques y el indice con el que vuelve todo en combat_finished.
# Los KO se quedan en la lista con su bloque apagado; quien se filtra es _gauge y _aliados_vivos().
var _aliados: Array[Combatant] = []
# EL ALIADO QUE ACTUA AHORA. Se llama _player porque ES el jugador desde el punto de vista de
# todas las acciones: cuando eliges Atacar, atacas con el que tiene el turno.
var _player: Combatant
# ENEMIGOS de la pelea (1..MAX_ENEMIGOS). Guarda a los VIVOS Y A LOS MUERTOS, y en orden FIJO:
# ese orden es la numeracion que ve el jugador (bloque nº1 arriba = marcador "1" en la barra de
# accion). Por eso un muerto no se saca de aqui: si la lista se compactara, al caer el nº2 el
# nº3 pasaria a ser el 2 y se te movaria el objetivo bajo el dedo en mitad del combate.
# Quien SI se filtra es _gauge (orden de turnos) y _vivos().
var _enemies: Array[Combatant] = []
var _target_idx: int = 0
var _gauge: Dictionary = {}   # SOLO vivos: al morir uno se le hace erase (sale del orden de turnos)
# INVOCADOS (Rey Slime): indices de _enemies que son slimes INVOCADOS a mitad de combate. No tienen
# nodo en la mazmorra (existen solo en la pelea), asi que al cerrar se reportan SIEMPRE como muertos
# (ver _on_continue_pressed): reusar el hueco de un cadaver no debe reanimar al nodo original, y un
# invocado nunca deja rastro en el mapa. Tambien se descuentan del maná-al-matar (ver _end).
var _slots_invocados: Dictionary = {}

# Tope de enemigos en una pelea. Lo aplica enemy.gd al reclutar vecinos (MAX_COMBATIENTES);
# aqui sirve de contrato para la UI (bloques y numeracion).
const MAX_ENEMIGOS := 5
# Tope de ALIADOS en pantalla (hito 5.4-C, peleas compartidas). 4 es el techo real por dos motivos
# que coinciden: el cupo de personajes en sesion ya topa a 4 EN TOTAL (Net.cupo_party), y la fila
# de bloques NO hace wrap -216 px cada uno en un viewport de 1152-, asi que un quinto se saldria.
const MAX_ALIADOS := 4
# Hay un aliado EN CAMINO (concedido por la red, todavia no dentro). Mientras este puesto, la
# pelea no se da por perdida aunque caigan todos: ver derrota().
var _espera_refuerzo := false

# --- MODO ESPEJO (hito 5.4-C): peleas COMPARTIDAS -------------------------------------------
# La pelea la EJECUTA una sola maquina (la de quien la abrio). Los demas participantes abren esta
# misma pantalla en modo ESPEJO: no simulan nada -ni ATB, ni dados, ni resolucion- y se limitan a
# pintar las instantaneas que les llegan. Es el mismo principio que remote_enemy con el mundo, pero
# aplicado a una pelea entera, y es lo que permite reusar TODA la interfaz (bloques, barras, log,
# marcador de turnos) sin tocarla.
var _espejo := false
# De quien es cada aliado que NO es mio: Combatant -> peer_id. Solo lo llena el anfitrion. Cuando
# le toca el turno a uno de estos, no se enseñan los botones aqui: se le pide la accion a su dueño,
# que es quien tiene que decidir. Los mios no estan en este diccionario.
var _dueno_aliado: Dictionary = {}
# Los que se HAN IDO por su propio pie (huida). No se sacan de _aliados -ese array se cruza por
# INDICE con Game._active_player_pjs y combat_finished devuelve por posicion-, se apartan aqui: se
# filtran en _aliados_vivos(), que es el embudo de a quien pegan, quien recibe area, cuando se
# pierde y quien cobra el mana de la victoria.
var _huidos: Dictionary = {}
# Identidad de cada combatiente dentro de ESTA pelea (ver _uid_de). En el anfitrion se asigna sola;
# en el espejo se copia del roster, para poder casar fila con maniqui sin depender del nombre.
var _uid: Dictionary = {}
var _uid_seq: int = 0
# La cara de cada maniqui del espejo (Combatant -> ShaderMaterial), montada desde el PNG que viene
# en el roster. Aqui no hay fichas locales de las que sacarla.
var _mat_espejo: Dictionary = {}
# Los ESTADOS de cada maniqui del espejo (Combatant -> [[texto, tooltip], ...]), tal cual los
# calculo el anfitrion. En el espejo no hay motor de estados que consultar: los chips llegan ya
# resueltos en la instantanea (ver _chips_de).
var _chips_espejo: Dictionary = {}
# Estoy parado esperando la accion de otro (el ATB no corre, ver _process y State.WAITING_PLAYER).
var _esperando_a: int = 0
# LO ULTIMO QUE LE PEDI a ese remoto, para poder REENVIARSELO si no contesta. Un turno remoto que
# se pierde por el camino (su _tu_turno no llego porque su pantalla aun no estaba montada, o su
# respuesta se descarto) dejaba la pelea COLGADA PARA SIEMPRE: nadie mas puede actuar porque el ATB
# esta congelado esperandole. Con el reenvio, el turno se recupera solo.
var _peticion_pendiente: Dictionary = {}
var _espera_acum: float = 0.0
# NUMERO DE PETICION. Sube con CADA cosa que se le pide a un remoto (su turno, una frase, el
# disparo) y viaja con ella; el remoto lo devuelve en su respuesta. Es lo que distingue "me
# contesta a lo que le acabo de pedir" de "me llega, tarde, la respuesta a lo de hace dos turnos".
#
# Sin esto se perdian turnos, y el camino era este: el espejo contesta y se pone en ADVANCING; si su
# respuesta tarda mas de REENVIO_TURNO el heartbeat le repite la peticion; como ya no esta en
# WAITING_PLAYER, el guardia de turno_mio no aplicaba y le volvia a pintar la barra de acciones de un
# turno YA contestado -> segunda respuesta. Esa segunda llegaba cuando el anfitrion ya esperaba a
# OTRO jugador y, como no se validaba nada, se aplicaba al turno de ese otro: le robaba el turno. Y
# encima dejaba _esperando_a a 0 con el estado en WAITING_PLAYER, que es justo la combinacion que
# apaga el heartbeat (ver _heartbeat_remoto) y deja la pelea muerta.
var _pet_seq: int = 0
# ESPEJO: el numero de lo que me han pedido y el de lo ultimo que ya conteste.
var _seq_espejo: int = 0
var _seq_contestada: int = 0
# Cada cuanto se le repite la peticion a un remoto que no contesta. Generoso a proposito: un humano
# tarda en decidir, y el reenvio NO le molesta (ver turno_mio, que lo ignora si ya esta eligiendo).
const REENVIO_TURNO := 4.0
# REVISION del roster: sube con cada ALTA de combatiente (un refuerzo enemigo, un aliado que se
# une, una invocacion). Viaja en la instantanea para que un espejo sepa si se ha perdido un alta:
# si la revision no le cuadra, pide el roster entero y se recompone (ver aplicar_roster).
var _rev: int = 0
# ESPEJO: ya he pedido el roster y estoy esperandolo (para no pedirlo en cada instantanea).
var _rev_pedida := false
# Cada cuanto se les manda a los espejos como van las barras de accion (20 Hz, ver _difundir_atb).
const ATB_TICK := 0.05
var _atb_acum := 0.0
# ESPEJO: la barra llega a 20 Hz, pero se pinta a 60. Si _gauge se escribiera de golpe con cada
# paquete (como se hacia antes), la barra iba a ESCALONES —el que entra despues la veia a saltos—.
# Ahora el paquete solo fija el OBJETIVO y _process acerca _gauge a el cada frame, igual que
# remote_player interpola su posicion (mismo lerp exponencial y una SUAVIZADO analoga).
var _gauge_objetivo: Dictionary = {}
const SUAVIZADO_ATB := 14.0

# TRAZA DEL TRAFICO DE TURNOS: las ultimas TRAZA_MAX cosas que han pasado con las peticiones y las
# respuestas, cada una con su marca de tiempo. No se pinta en pantalla: se vuelca con la tecla P
# (ver _volcado_p) para poder leer DESPUES por que se colgo un turno. Un cuelgue de estos no se
# reproduce a voluntad, asi que la unica forma de cazarlo es que la partida vaya dejando el rastro.
const TRAZA_MAX := 60
var _traza: Array[String] = []
var _t0: float = 0.0   # cuando empezo la pelea, para que los tiempos de la traza sean relativos

func _traza_add(que: String) -> void:
	var t: float = (Time.get_ticks_msec() / 1000.0) - _t0
	_traza.append("[%7.2fs] %s" % [t, que])
	while _traza.size() > TRAZA_MAX:
		_traza.pop_front()


enum State { ADVANCING, WAITING_PLAYER, PAUSED, FINISHED }
var _state: State = State.ADVANCING

# Pausa breve tras la accion del ENEMIGO para poder leer que hizo (las barras ATB
# se congelan durante la pausa). El combate corre con el arbol en pausa, pero esta
# escena tiene PROCESS_MODE_ALWAYS, asi que el tiempo (delta) sigue corriendo.
const ENEMY_TURN_PAUSE := 1.0   # segundos
var _pause_left: float = 0.0

var _injected: bool = false       # true si Game nos paso los combatientes
var _enemy_initiated: bool = false
var _player_won: bool = false

# --- MODO PRUEBA / medicion de DPS (dev) ---
var _dps_on: bool = false             # el enemigo es un muñeco de pruebas
var _dmg_dealt: Dictionary = {}       # fuente -> daño total infligido al enemigo
var _dmg_dealt_total: float = 0.0
var _dmg_taken_total: float = 0.0     # daño (que habrias) recibido (mide mitigacion)
var _dmg_taken_hits: int = 0
var _turnos_jugador: int = 0
var _turnos_enemigo: int = 0


# ============================================================
#  ESTADO POR ALIADO
#  Defender, el conjuro a medias y las acciones lentas por agotamiento son de CADA UNO: si fueran
#  globales, defender con la guerrera protegeria tambien a la maga, y recitar con una te dejaria
#  el recitado colgado de la otra.
#
#  Se guardan en diccionarios (Combatant -> valor), pero se leen y se escriben con las MISMAS
#  variables de siempre, que son propiedades enganchadas al aliado que tiene el turno. Por eso las
#  ~2700 lineas de acciones, magia y habilidades no se han tocado: siguen diciendo
#  `_cast_spell = x` y cada una escribe en la ficha de quien esta jugando.
#  Cuando hace falta el valor de OTRO (el enemigo pega a quien no tiene el turno), se consulta el
#  diccionario directamente: _defendiendo.get(victima, false).
# ============================================================
var _defendiendo: Dictionary = {}   # Combatant -> bool (dura hasta SU proximo turno)
var _casteos: Dictionary = {}       # Combatant -> {"spell": SpellData, "idx": int}
var _lentas: Dictionary = {}        # Combatant -> acciones lentas que le quedan por agotamiento

# true si elegiste Defender con el que tiene el turno (dura hasta su proxima accion)
var _player_defending: bool:
	get: return bool(_defendiendo.get(_player, false))
	set(v): _defendiendo[_player] = v

# Conjuro EN CURSO del que actua: hechizo elegido + cuantas frases lleva recitadas OK. Persiste
# entre turnos (recita una por turno). null = no esta casteando.
var _cast_spell: SpellData:
	get: return (_casteos[_player]["spell"] as SpellData) if _casteos.has(_player) else null
	set(v):
		if v == null:
			_casteos.erase(_player)
		else:
			_casteos[_player] = {"spell": v, "idx": int(_cast_index)}

var _cast_index: int:
	get: return int(_casteos[_player]["idx"]) if _casteos.has(_player) else 0
	set(v):
		if _casteos.has(_player):
			_casteos[_player]["idx"] = v

# A QUIEN va el conjuro cuando es de los que caen sobre un aliado (Filos, Mantos, Fortaleza).
# Vive en _casteos con el resto del conjuro porque el recitado dura 2-3 turnos y tiene que
# sobrevivirlos (y al traspaso de anfitrion). Si el elegido cae mientras recitas, se cae al que
# lanza: el conjuro no se pierde por eso.
# A QUIEN va una HABILIDAD de las que caen sobre un aliado (Purificar, Égida menor). No puede
# reutilizar _cast_aliado: ese vive dentro de _casteos y solo existe mientras recitas un conjuro,
# asi que para una habilidad su setter no hace nada y el getter siempre devolveria _player.
# Una habilidad se resuelve en el acto, asi que basta con guardarlo hasta que se resuelva.
var _hab_aliado: Combatant = null

# El aliado elegido para la habilidad en curso, o el que la lanza si no hay o ya no esta en pie.
func _hab_objetivo_aliado() -> Combatant:
	if _hab_aliado == null or not _hab_aliado.is_alive() or _huidos.has(_hab_aliado):
		return _player
	return _hab_aliado


var _cast_aliado: Combatant:
	get:
		if not _casteos.has(_player):
			return _player
		var a = _casteos[_player].get("aliado")
		if a == null or not (a as Combatant).is_alive() or _huidos.has(a):
			return _player
		return a
	set(v):
		if _casteos.has(_player):
			_casteos[_player]["aliado"] = v

# Acciones lentas que le quedan al que actua (entro agotado -> sus primeras acciones van a medio
# ritmo). Ver EXHAUSTED_SLOW_ACTIONS.
var _slow_actions_left: int:
	get: return int(_lentas.get(_player, 0))
	set(v): _lentas[_player] = v

# El ATAQUE DE CARGA del enemigo (habilidad telegrafiada) ya no vive aqui: es estado POR
# COMBATIENTE (Combatant.charging / charge_left), porque con varios bichos cada uno carga lo
# suyo por su cuenta.


# Lo llama Game ANTES de añadir esta escena al arbol.
# 'enemy_cs' viene ORDENADO: el [0] es el bicho que disparo el combate (el que tocaste o el que
# te emboscó) y detras sus vecinos. Ese orden es la numeracion que vera el jugador.
# 'player_cs' viene con el LIDER el primero y detras los companeros en su orden de equipo. Ese
# orden es el de los bloques y el de los arrays que devuelve combat_finished.
# 'exhausted' es un bool POR ALIADO (el que baje sin fuelle empieza lento; ver _lentas).
# QUIEN DIO EL ULTIMO GOLPE a cada enemigo. Existe por el slayer: un slayer se gana MATANDO, y al
# terminar la pelea (donde se tira el dado) ya no hay forma de saber quien remato a quien. Antes se
# lo llevaba siempre el que iba en cabeza, aunque el bicho lo hubiera matado otro.
var _ultimo_en_golpear: Dictionary = {}   # Combatant -> PersonajeData


# Un golpe del grupo a un enemigo: se lo apunta a QUIEN lo dio, no al lider. Es el mismo motivo por
# el que en el playtest habia un personaje con 44.435 de daño infligido y cero excelia: el contador
# iba al de cabeza y la excelia al que pegaba.
func _apuntar_dano(objetivo: Combatant, dmg: float, quien: Combatant) -> void:
	var pj: PersonajeData = Game.pj_de_combatant(quien)
	Game.contar_dano_infligido(dmg, pj)
	if pj != null and objetivo != null:
		_ultimo_en_golpear[objetivo] = pj


func setup(player_cs: Array, enemy_cs: Array, enemy_initiated: bool,
		exhausted: Array = [], player_overload_factor: float = 1.0) -> void:
	# El sobrepeso es POR COMBATIENTE (ver Combatant.overload_factor): estos son los del anfitrion,
	# asi que todos llevan SU factor. Los dobles de otros humanos traen el suyo (unir_aliado_al_combate).
	for c in player_cs:
		c.overload_factor = player_overload_factor
	_aliados.assign(player_cs)
	_ultimo_en_golpear.clear()
	# Dos personajes con el mismo nombre se quedaban indistinguibles (en el log y en los bloques).
	for c in _aliados:
		_desambiguar(c)
	_player = _aliados[0] if not _aliados.is_empty() else null
	_enemies.assign(enemy_cs)
	# El escudo del Rey Slime cuenta slimes vivos del roster: cada enemigo necesita ver a los
	# demas. Les paso la MISMA lista (vivos y muertos); is_alive() filtra en el instante del golpe.
	for e in _enemies:
		e.battle_enemies = _enemies
	_enemy_initiated = enemy_initiated
	# Las acciones lentas se apuntan YA, una ficha por aliado: quien llego agotado las arrastra.
	for i in _aliados.size():
		if i < exhausted.size() and bool(exhausted[i]):
			_lentas[_aliados[i]] = EXHAUSTED_SLOW_ACTIONS
	_injected = true
	# El modo muñeco (Saco/Pegador) siempre es 1v1: lo garantiza enemy.gd al no reclutar
	# vecinos con debug_dummy_mode activo (las medidas de DPS/turno se irian al traste).
	_dps_on = not _enemies.is_empty() and _enemies[0].es_dummy


# ARRANQUE EN ESPEJO (hito 5.4-C): monto la MISMA pantalla, pero sin simular. Los combatientes se
# reconstruyen "de escaparate" a partir del roster que manda quien ejecuta la pelea: solo hace
# falta lo que se PINTA (nombre, color y las tres barras). Es un Combatant normal con los campos
# puestos a mano — no necesita stats de verdad porque aqui no se tira ni un dado.
func setup_espejo(roster: Dictionary) -> void:
	_espejo = true
	_injected = true
	_aliados.assign(_combatientes_de_escaparate(roster.get("aliados", [])))
	_enemies.assign(_combatientes_de_escaparate(roster.get("enemigos", [])))
	for e in _enemies:
		e.battle_enemies = _enemies
	_player = _aliados[0] if not _aliados.is_empty() else null
	_rev = int(roster.get("rev", 0))
	_dps_on = false


func _combatientes_de_escaparate(datos: Array) -> Array:
	var out: Array = []
	for d in datos:
		out.append(_maniqui_de_fila(d))
	return out


# IDENTIDAD de un combatiente DENTRO de esta pelea. Hacia falta porque el espejo reconciliaba el
# roster comparando el NOMBRE, y los enemigos no se desambiguan: un Slime que relevaba a un Slime
# muerto -- el caso normal -- se tomaba por "el mismo de siempre" y su bloque no se reencendia
# nunca. Se quedaba gris y sin poder seleccionarlo, para siempre.
#
# Va aqui y no en Combatant porque solo tiene sentido mientras dura la pelea. Como el relevo crea un
# Combatant NUEVO, un hueco reestrenado recibe un uid distinto sin tener que contar reestrenos.
func _uid_de(c: Combatant) -> int:
	if not _uid.has(c):
		_uid_seq += 1
		_uid[c] = _uid_seq
	return int(_uid[c])


# UN maniqui a partir de su fila del roster. Suelto porque tambien lo usa aplicar_roster: los
# combatientes que se unen a MITAD de pelea llegan de uno en uno.
func _maniqui_de_fila(d: Dictionary) -> Combatant:
	# Combatant exige stats en el constructor y se calcula la vida solo. Aqui da igual: es un
	# maniqui de escaparate, asi que se crea con lo minimo y se le pisan los valores que SI se
	# pintan. Ningun dado se tira contra el (eso pasa en la maquina que ejecuta la pelea).
	var c := Combatant.new(String(d.get("nombre", "?")), 1, Abilities.new(), 1.0, 0.0, 0.0, 0.0)
	# La identidad viene del anfitrion: es lo que deja reconocer un hueco reestrenado sin fiarse del
	# nombre. El 0 de respaldo no casa con ningun uid real (empiezan en 1), asi que un roster viejo
	# sin este campo hace que todo se trate como nuevo -- que es el lado seguro del error.
	_uid[c] = int(d.get("uid", 0))
	c.level = int(d.get("nivel", 1))
	c.max_hp = float(d.get("max_hp", 1.0))
	c.current_hp = float(d.get("hp", c.max_hp))
	c.max_mp = float(d.get("max_mp", 0.0))
	c.current_mp = float(d.get("mp", 0.0))
	c.max_energy = float(d.get("max_en", 0.0))
	c.current_energy = float(d.get("en", 0.0))
	c.color_visual = d.get("color", Color.WHITE)
	# Su cara, para el marcador de turnos: se monta aqui una vez y se cachea por maniqui.
	var png: PackedByteArray = d.get("imagen", PackedByteArray())
	var metal: float = float(d.get("metal", 0.0))
	# La opacidad del color sobre la imagen viaja en el roster: sin ella se fijaba a 1.0 y el color
	# tapaba la cara. El material solo hace falta si hay imagen o brillo.
	if not png.is_empty() or metal > 0.0:
		_mat_espejo[c] = Game.material_aspecto(metal, Game.textura_de_png(png),
			float(d.get("alpha", 1.0)))
	return c


# Lo que hay que mandarle a un espejo para que MONTE la pantalla (al unirse, y otra vez cada vez que
# entra alguien nuevo en la pelea). Va con la REVISION: es lo que permite al espejo saber si se ha
# perdido un alta (ver aplicar_instantanea).
func roster_para_espejo() -> Dictionary:
	return {"aliados": _fila_de_roster(_aliados), "enemigos": _fila_de_roster(_enemies),
		"rev": _rev}


func _fila_de_roster(lista: Array) -> Array:
	var out: Array = []
	for c in lista:
		# El COLOR y la CARA salen de la ficha cuando la hay (los aliados): son los mismos con los
		# que se les ve en el mapa. Los enemigos no tienen ficha y usan su color_visual.
		var pj: PersonajeData = Game.pj_de_combatant(c)
		out.append({"nombre": c.nombre, "nivel": c.level, "uid": _uid_de(c),
			"color": pj.color if pj != null else c.color_visual,
			"metal": pj.metalico if pj != null else 0.0,
			# La OPACIDAD del color sobre la imagen (color_alpha del shader). Sin ella el marcador
			# de turnos del espejo pintaba el color plano tapando la cara.
			"alpha": pj.color_alpha if pj != null else 1.0,
			"imagen": pj.imagen if pj != null else PackedByteArray(),
			"max_hp": c.max_hp, "hp": c.current_hp,
			"max_mp": c.max_mp, "mp": c.current_mp,
			"max_en": c.max_energy, "en": c.current_energy})
	return out


# ESPEJO: llega un roster nuevo porque ALGUIEN HA ENTRADO en la pelea (un refuerzo enemigo, una
# invocacion, el compañero de otro humano). No se reconstruye la pantalla: se RECONCILIA fila por
# fila, que es mucho mas barato y ademas conserva la seleccion, el log y los marcadores que ya
# estaban. Dos casos por indice:
#   - no tengo esa fila -> combatiente nuevo (bloque + marcador de turnos);
#   - la tengo con OTRO nombre -> el anfitrion reutilizo el hueco de un cadaver (ver _meter_enemigo):
#     se sustituye el maniqui y se reenciende su bloque.
func aplicar_roster(roster: Dictionary) -> void:
	if not _espejo:
		return
	_rev_pedida = false
	_rev = int(roster.get("rev", _rev))
	# Los aliados solo crecen por el final (nunca se reordenan ni se reutilizan huecos: el cruce por
	# indice con las fichas de Game depende de ello), asi que basta con dar de alta los que faltan.
	var mios: Array = roster.get("aliados", [])
	for i in range(_aliados.size(), mios.size()):
		var c: Combatant = _maniqui_de_fila(mios[i])
		_aliados.append(c)
		_gauge[c] = 0.0
		_anadir_bloque_aliado(c)
		if _timeline != null:
			_timeline.anadir(c, _color_de(c), _material_de(c), "")
	var filas: Array = roster.get("enemigos", [])
	for i in filas.size():
		var d: Dictionary = filas[i]
		# Por UID, no por nombre: los enemigos no se desambiguan, asi que comparando el nombre un
		# Slime que relevaba a un Slime muerto pasaba por "el mismo" y su bloque se quedaba apagado
		# (gris y sin poder clicarlo) para el resto de la pelea.
		if i < _enemies.size() and int(d.get("uid", 0)) == int(_uid.get(_enemies[i], -1)):
			continue   # el mismo de siempre: sus numeros ya los trae la instantanea
		var c: Combatant = _maniqui_de_fila(d)
		if i < _enemies.size():
			# Hueco de cadaver reestrenado: fuera el viejo del marcador, y su bloque se reenciende.
			if _timeline != null:
				_timeline.quitar(_enemies[i])
			_gauge.erase(_enemies[i])
			_enemies[i] = c
			_revivir_bloque(i, c)
		else:
			_enemies.append(c)
			var b: Dictionary = _crear_bloque(c, i + 1, i)
			_bloques.append(b)
			_bloques_box.add_child(b["panel"])
		_gauge[c] = 0.0
		if _timeline != null:
			_timeline.anadir(c, c.color_visual, null, str(i + 1))
	# battle_enemies es una referencia COMPARTIDA (la usa el escudo del Rey Slime para contar
	# slimes vivos): al cambiar la lista hay que repartirla otra vez.
	for e in _enemies:
		e.battle_enemies = _enemies
	# El roster puede haber traido bichos nuevos: si ya no caben a su ancho, se encogen todos.
	_reajustar_anchos(_bloques, _enemies.size())
	_update_hp()


# LA INSTANTANEA: lo que cambia turno a turno. Va del que ejecuta la pelea a los espejos. Solo
# lleva numeros y de quien es el turno; el resto (barras, colores, orden) ya lo tienen montado.
# Solo las ultimas lineas del log viajan al espejo. El log ENTERO crecia sin tope y una pelea larga
# hacia que la instantanea pasara de la MTU (1392): ENet la descartaba y el espejo se quedaba
# congelado sin ver el combate. El espejo solo enseña las lineas recientes de todas formas.
const _LOG_COLA_ESPEJO := 12

func instantanea() -> Dictionary:
	return {"a": _valores(_aliados), "e": _valores(_enemies),
		"turno": _aliados.find(_player), "log": _cola_log(), "fin": _state == State.FINISHED,
		"rev": _rev}


func _cola_log() -> String:
	var lineas: PackedStringArray = _log.text.split("\n")
	if lineas.size() <= _LOG_COLA_ESPEJO:
		return _log.text
	return "\n".join(lineas.slice(lineas.size() - _LOG_COLA_ESPEJO))


# Lo que cambia de un combatiente entre instantaneas: sus tres barras y sus ESTADOS. Los estados van
# como pares [texto, tooltip] ya resueltos (ver _chips_de): en el espejo no hay motor de estados, y
# sin esto los debuffs de los demas eran invisibles alli.
#
# Y LOS MAXIMOS. Antes solo viajaban en el ROSTER (una vez, al montar la pelea), asi que el espejo se
# quedaba congelado con el maximo del principio: en cuanto alguien lanzaba Guardia de carne -que
# DUPLICA max_hp en vivo- uno veia "130/150" y el otro "130/75", con la barra roja desbordada. Son
# tres numeros mas por combatiente y ahorran una clase entera de desincronizacion.
func _valores(lista: Array) -> Array:
	var out: Array = []
	for c in lista:
		out.append([c.current_hp, c.current_mp, c.current_energy, _chips_de(c),
			c.max_hp, c.max_mp, c.max_energy])
	return out


# Corre en el ESPEJO: vuelca los numeros recibidos en sus combatientes de escaparate y repinta.
func aplicar_instantanea(snap: Dictionary) -> void:
	if not _espejo:
		return
	# ¿Me he perdido un ALTA? (un refuerzo enemigo, un aliado que se unio, una invocacion). La
	# instantanea solo trae numeros, asi que sin esto las filas de mas se descartaban EN SILENCIO
	# -era el bug de "no veo los enemigos que se añaden"-. La revision lo delata y pido el roster
	# entero UNA vez; mientras llega, los numeros que si cuadran se siguen pintando.
	var rev: int = int(snap.get("rev", _rev))
	if rev != _rev and not _rev_pedida:
		_rev_pedida = true
		Net.pedir_roster_pelea()
	_volcar(_aliados, snap.get("a", []))
	_volcar(_enemies, snap.get("e", []))
	_apagar_caidos()
	var t: int = int(snap.get("turno", -1))
	if t >= 0 and t < _aliados.size():
		_player = _aliados[t]
	if snap.has("log"):
		_log.text = String(snap["log"])
	if bool(snap.get("fin", false)):
		_state = State.FINISHED
		# Igual que en _end(): visible Y habilitado Y con su texto. Solo poner 'visible' no bastaba
		# si el boton venia deshabilitado de antes: se veia el "Continuar" pero no se podia pulsar.
		_continue_button.visible = true
		_continue_button.disabled = false
		_continue_button.text = "Continuar"
		_ocultar_cajas()
	_update_hp()


# --- TRASPASO DE LA PELEA (hito 5.4-C) -------------------------------------------------------
#
# La pelea la EJECUTA una maquina. Si esa se va (su jugador huye, o se le corta la conexion) la
# pelea NO se cierra: se TRASPASA a otro que este dentro y sigue donde estaba.
#
# La clave para que esto no sea un monstruo: casi todo el Combatant es DERIVADO (sale de la ficha
# y del equipo, o del EnemyData), asi que el que la recoge lo RECONSTRUYE con el camino de siempre
# —start_combat + unir_aliado_al_combate— y aqui solo viaja lo VOLATIL, lo que no se puede deducir:
# vida, mana, aguante, estados, cargas, cooldowns, imbuicion, barras de ATB y conjuros a medias.

# Lo que lleva un combatiente encima y no se puede reconstruir de su ficha.
func _volatil(c: Combatant) -> Dictionary:
	var estados: Array = []
	for e in c.statuses:
		estados.append([e.id(), e.turns, e.stacks, e.magnitude, e.mult_override, e.fresh])
	var cds: Dictionary = {}
	for ab in c.ability_cooldowns:
		if ab != null and not String(ab.resource_path).is_empty():
			cds[String(ab.resource_path)] = int(c.ability_cooldowns[ab])
	return {"hp": c.current_hp, "mp": c.current_mp, "en": c.current_energy,
		"provocar": c.provocar_turnos, "estados": estados, "cd": cds,
		"carga": [String(c.charging.resource_path) if c.charging != null else "", c.charge_left],
		"imbue": [c.imbue_elemento, c.imbue_pct, c.imbue_usos, c.imbue_cuerpo,
			c.imbue_estado, c.imbue_prob, c.imbue_prob_doble, c.imbue_por_destreza]}


func _aplicar_volatil(c: Combatant, v: Dictionary) -> void:
	if c == null or v.is_empty():
		return
	c.current_hp = float(v.get("hp", c.current_hp))
	c.current_mp = float(v.get("mp", c.current_mp))
	c.current_energy = float(v.get("en", c.current_energy))
	c.provocar_turnos = int(v.get("provocar", 0))
	c.statuses.clear()
	for e in v.get("estados", []):
		var def: Dictionary = StatusEffects.def(int(e[0]))
		if def.is_empty():
			continue
		var inst := StatusEffects.Instance.new(def, int(e[1]), int(e[2]))
		inst.magnitude = float(e[3])
		inst.mult_override = float(e[4])
		inst.fresh = bool(e[5])
		c.statuses.append(inst)
	c.ability_cooldowns.clear()
	for ruta in v.get("cd", {}):
		var ab = load(String(ruta))
		if ab != null:
			c.ability_cooldowns[ab] = int(v["cd"][ruta])
	var carga: Array = v.get("carga", ["", 0])
	c.charging = load(String(carga[0])) if String(carga[0]) != "" else null
	c.charge_left = int(carga[1])
	var imb: Array = v.get("imbue", [])
	if imb.size() >= 6:
		c.imbue_elemento = int(imb[0])
		c.imbue_pct = float(imb[1])
		c.imbue_usos = int(imb[2])
		c.imbue_cuerpo = bool(imb[3])
		c.imbue_estado = int(imb[4])
		c.imbue_prob = float(imb[5])
		# Los dos escalones y el escalado por Destreza (imbuicion de ARMA). Si no viajaran, tras un
		# traspaso de anfitrion el veneno de la daga se quedaria en un solo escalon y medido por
		# Magia -- o sea, en nada, porque un picaro no tiene Magia.
		if imb.size() >= 8:
			c.imbue_prob_doble = float(imb[6])
			c.imbue_por_destreza = bool(imb[7])
		# Y la AFINIDAD, que es la mitad de un manto (resistencias, inmunidades, aturdimiento).
		# Sin esto, quien llevara un Manto y sufriera un traspaso de anfitrion perdia todo el lado
		# defensivo aunque el chip siguiera diciendo 🛡: solo le quedaba el bonus de daño.
		if c.imbue_cuerpo and c.imbue_usos > 0:
			c.elemento = c.imbue_elemento
			c.elemento_intensidad = Elementos.INTENSIDAD_IMBUIDO
		else:
			c.elemento = Elementos.Elemento.NINGUNO
			c.elemento_intensidad = Elementos.INTENSIDAD_PURA


# LA FOTO de la pelea para el que la recoge. 'nuevo' es su peer: sus personajes los pone EL de su
# propio equipo (son suyos de verdad), asi que de esos solo viaja lo volatil, no la ficha.
# Los personajes del que SE VA no van: se retira de la pelea, es justo lo que esta haciendo.
func estado_para_traspaso(nuevo: int) -> Dictionary:
	var als: Array = []
	for c in _aliados:
		var dueno: int = int(_dueno_aliado.get(c, 0))
		if dueno == 0 or _huidos.has(c):
			continue   # los mios (me voy) y los que ya habian huido no siguen en la pelea
		var fila: Dictionary = {"dueno": dueno, "mio": dueno == nuevo, "vol": _volatil(c),
			"gauge": float(_gauge.get(c, 0.0)), "lentas": int(_lentas.get(c, 0)),
			"defendiendo": bool(_defendiendo.get(c, false)), "nombre": c.nombre}
		if dueno != nuevo:
			# De los TERCEROS hace falta la ficha entera: el que recoge tiene que montarles un
			# doble, igual que hace hoy quien recibe a alguien que se une.
			var pj: PersonajeData = Game.pj_de_combatant(c)
			if pj != null:
				Game.volcar_desgaste_en_ficha(pj)
				fila["ficha"] = Net.ficha_a_dict(pj)
		if _casteos.has(c):
			# El tercer campo es A QUIEN va (indice en _aliados; -1 = a si mismo): un conjuro de
			# los que caen sobre un aliado dura 2-3 turnos y puede pillar el traspaso a medias.
			var dest = _casteos[c].get("aliado")
			fila["casteo"] = [String((_casteos[c]["spell"] as SpellData).resource_path),
				int(_casteos[c]["idx"]), _aliados.find(dest) if dest != null else -1]
		als.append(fila)
	var ens: Array = []
	for i in _enemies.size():
		var e: Combatant = _enemies[i]
		var nodo = Game._active_enemies[i] if i < Game._active_enemies.size() else null
		if not is_instance_valid(nodo) or not nodo.has_meta("net_id"):
			continue   # sin net_id no hay forma de que el otro sepa de que bicho hablo
		ens.append({"net_id": int(nodo.get_meta("net_id")), "vivo": e.is_alive(),
			"invocado": _slots_invocados.has(i), "vol": _volatil(e),
			"gauge": float(_gauge.get(e, 0.0))})
	return {"aliados": als, "enemigos": ens, "log": _log.text}


# Corre en EL QUE RECOGE la pelea, con la pantalla ya montada por el camino de siempre: le vuelca
# encima lo volatil de la pelea vieja. 'cs' son los combatientes de esta pantalla en el MISMO orden
# que estado.aliados; 'filas_e' las filas de los enemigos que SI han venido (los vivos), en el
# orden en que se le pasaron a start_combat, o sea el de _enemies.
func retomar(estado: Dictionary, cs: Array, filas_e: Array) -> void:
	var als: Array = estado.get("aliados", [])
	for i in mini(cs.size(), als.size()):
		var c: Combatant = cs[i]
		if c == null:
			continue
		var fila: Dictionary = als[i]
		_aplicar_volatil(c, fila.get("vol", {}))
		_gauge[c] = float(fila.get("gauge", 0.0))
		if int(fila.get("lentas", 0)) > 0:
			_lentas[c] = int(fila["lentas"])
		if bool(fila.get("defendiendo", false)):
			_defendiendo[c] = true
		# Un conjuro A MEDIAS no se pierde por cambiar de maquina: se sigue por la frase que iba.
		if fila.has("casteo"):
			var sp = load(String(fila["casteo"][0]))
			if sp != null:
				var cst: Array = fila["casteo"]
				var idest: int = int(cst[2]) if cst.size() > 2 else -1
				_casteos[c] = {"spell": sp, "idx": int(cst[1]),
					"aliado": _aliados[idest] if idest >= 0 and idest < _aliados.size() else null}
	for i in mini(_enemies.size(), filas_e.size()):
		var e: Combatant = _enemies[i]
		_aplicar_volatil(e, filas_e[i].get("vol", {}))
		_gauge[e] = float(filas_e[i].get("gauge", 0.0))
		if bool(filas_e[i].get("invocado", false)):
			_slots_invocados[i] = true   # los invocados no dan kill ni maná: la marca viaja
	_rev += 1
	_set_log("Tomas el relevo de la pelea. " + String(estado.get("log", "")).split("\n")[-1])
	_update_hp()
	_update_timeline()


# --- TURNOS COMPARTIDOS (hito 5.4-C) ---------------------------------------------------------

# En que hueco de la fila esta un aliado (-1 si no esta). El indice es el idioma comun entre las dos
# maquinas: por el se dice de quien es el turno y a quien apunta un objeto.
func indice_de_aliado(c: Combatant) -> int:
	return _aliados.find(c)


# Apunta que ese aliado es de otro humano: cuando le toque, se le pedira a el la accion.
func marcar_dueno(c: Combatant, peer: int) -> void:
	if c != null and peer != 0:
		_dueno_aliado[c] = peer


# Corre en EL ESPEJO: me toca mover a mi personaje. Se enseña la barra de acciones de siempre.
func turno_mio(idx: int, seq: int = 0) -> void:
	if not _espejo or idx < 0 or idx >= _aliados.size():
		return
	# YA CONTESTE A ESTA MISMA PETICION. Es el reenvio del heartbeat cruzandose con mi respuesta:
	# el anfitrion todavia no la ha procesado y me repite lo mismo. Volver a pintar la barra de
	# acciones aqui era el origen del turno robado (ver _pet_seq): el jugador elegia por segunda vez
	# y esa segunda respuesta acababa consumiendo el turno de otro. Con el numero se reconoce el eco.
	if seq != 0 and seq == _seq_contestada:
		_traza_add("me repiten la #%d, que YA conteste: la ignoro" % seq)
		return
	if seq != 0:
		_seq_espejo = seq
	# REPETICION del anfitrion (ver _heartbeat_remoto): si YA estoy eligiendo para este mismo
	# personaje, no se toca nada — resetear los menus a media eleccion seria peor que el bug. Si en
	# cambio ya habia contestado (o nunca me llego el turno), esto lo recupera.
	if _state == State.WAITING_PLAYER and _player == _aliados[idx]:
		return
	_traza_add("ME TOCA (#%d) con %s" % [seq, _aliados[idx].nombre])
	_player = _aliados[idx]
	# El maniqui solo trae lo que se PINTA, asi que no tiene ni habilidades ni hechizos y los
	# submenus salian vacios ("solo deja hacer basicos"). Se los pongo desde MI PROPIA ficha —la de
	# ESTE hueco, que puede ser mi lider o un acompañante mio—: aqui solo sirven para ELEGIR, quien
	# lo resuelve es el anfitrion. La vida, el mana y la energia NO se tocan: manda su instantanea.
	var mio: PersonajeData = Net.mi_pj_en_pelea(idx)
	var real: Combatant = Game.crear_player_combatant(mio) if mio != null else null
	if real != null:
		_vestir_maniqui(_player, real)
	_state = State.WAITING_PLAYER
	_mostrar_acciones()


# ESPEJO: le pone al maniqui todo lo que la barra de acciones necesita para ELEGIR, copiado del
# combatiente de VERDAD (el que monta Game.crear_player_combatant con mi ficha y mi equipo).
#
# TODO LO QUE LOS MENUS CONSULTEN VA AQUI. El maniqui nace con lo minimo (ver _maniqui_de_fila) y
# cada campo que falte no da error: devuelve su valor por defecto y MIENTE en silencio. Asi se
# perdio el DUAL — sin `ability_hands`, ability_hand_indices devuelve [0] y toda la pantalla se
# calculaba a UNA mano: Rafaga a 48 EN en vez de 70, el tooltip con 2 golpes en vez de 4, y la
# puerta de energia dejando pulsar con 48 (el anfitrion la rechazaba y la pelea se quedaba colgada).
#
# La vida, el mana y la energia NO se tocan: de eso manda la instantanea del anfitrion.
func _vestir_maniqui(m: Combatant, real: Combatant) -> void:
	m.abilities_combate = real.abilities_combate
	m.spells = real.spells
	m.ability_cooldowns = real.ability_cooldowns
	m.magic_amp = real.magic_amp
	m.mana_reduccion = real.mana_reduccion
	# Las MANOS del loadout (dual): set_hands va ANTES de motion_value porque activa la mano 0 y
	# pisa motion_value/ataque_arma/etc. con los de esa mano (que es la principal: mismo valor).
	m.set_hands(real.hands)
	m.ability_hands = real.ability_hands
	m.motion_value = real.motion_value


# LE PIDO ALGO A UN REMOTO (su turno, una frase, el disparo) y me quedo esperando. Se recuerda QUE
# le pedi para poder REPETIRSELO si no contesta: ver _heartbeat_remoto. Un turno remoto perdido
# congelaba la pelea entera para todos.
func _pedir_a_remoto(dueno: int, pet: Dictionary) -> void:
	_esperando_a = dueno
	# CADA peticion lleva su numero. Es lo que permite luego distinguir su respuesta de una respuesta
	# rezagada a algo que le pedi antes (ver _pet_seq y aplicar_accion_remota).
	_pet_seq += 1
	pet["seq"] = _pet_seq
	_peticion_pendiente = pet
	_espera_acum = 0.0
	_traza_add("PIDO #%d '%s' al peer %d (para %s)" % [
		_pet_seq, String(pet.get("tipo", "?")), dueno,
		_player.nombre if _player != null else "?"])
	_enviar_peticion()


func _enviar_peticion() -> void:
	if _esperando_a == 0 or _peticion_pendiente.is_empty():
		return
	var pet: Dictionary = _peticion_pendiente
	var seq: int = int(pet.get("seq", 0))
	match String(pet.get("tipo", "")):
		"accion":
			Net.pedir_accion(_esperando_a, int(pet.get("idx", 0)), seq)
		"frase":
			Net.pedir_frase(_esperando_a, int(pet.get("idx", 0)), pet.get("opciones", []),
				String(pet.get("nombre", "")), int(pet.get("largo", 1)), seq)
		"disparo":
			Net.pedir_disparo(_esperando_a, String(pet.get("nombre", "")), seq)


# Deja de esperar (llego su respuesta, o se fue).
func _fin_de_espera() -> void:
	_esperando_a = 0
	_peticion_pendiente = {}
	_espera_acum = 0.0


# HEARTBEAT: mientras espero a un remoto, le repito la peticion cada REENVIO_TURNO. Si su pantalla
# no llego a mostrarle el turno (o su respuesta se perdio), esto lo despierta; y si ya esta
# eligiendo, el reenvio se ignora al otro lado y no le molesta. Sin esto, cualquier mensaje perdido
# dejaba la pelea muerta: el ATB esta congelado esperando a alguien que no va a contestar.
func _heartbeat_remoto(delta: float) -> void:
	if _esperando_a == 0 or _state != State.WAITING_PLAYER or _peticion_pendiente.is_empty():
		_espera_acum = 0.0
		return
	_espera_acum += delta
	if _espera_acum < REENVIO_TURNO:
		return
	_espera_acum = 0.0
	# ¿Sigue en la pelea? Si se fue, sus personajes salen y la pelea continua (no se espera a un
	# fantasma). Si sigue, se le repite lo que le pedi.
	if not Net.esta_en_mi_pelea(_esperando_a):
		var quien: int = _esperando_a
		_fin_de_espera()
		sacar_a(quien)
		return
	print("[combate] repito la peticion a %d (%s #%d): no ha contestado en %.0f s" % [
		_esperando_a, String(_peticion_pendiente.get("tipo", "?")),
		int(_peticion_pendiente.get("seq", 0)), REENVIO_TURNO])
	_traza_add("REENVIO #%d '%s' al peer %d (sin respuesta en %.0fs)" % [
		int(_peticion_pendiente.get("seq", 0)), String(_peticion_pendiente.get("tipo", "?")),
		_esperando_a, REENVIO_TURNO])
	_enviar_peticion()


# Corre en EL ANFITRION: ha llegado la accion que eligio el dueño. Se ejecuta como si la hubiera
# pulsado aqui, reusando las mismas funciones (asi el combate es UNO, sin reglas paralelas).
func aplicar_accion_remota(accion: Dictionary, emisor: int = 0) -> void:
	var tipo: String = String(accion.get("tipo", "?"))
	if _espejo or _state != State.WAITING_PLAYER or _esperando_a == 0:
		# Descartarla EN SILENCIO era lo que dejaba el turno colgado sin dejar rastro. Ahora se dice,
		# y el heartbeat volvera a pedirsela si de verdad seguimos esperando.
		print("[combate] accion remota IGNORADA (%s): espejo=%s estado=%d esperando_a=%d" % [
			tipo, str(_espejo), _state, _esperando_a])
		_traza_add("DESCARTO '%s' del peer %d: no estoy esperando (estado=%d, esperando_a=%d)" % [
			tipo, emisor, _state, _esperando_a])
		return

	# ¿ME CONTESTA A QUIEN LE PREGUNTE? Antes no se miraba, y eso es lo que convertia una respuesta
	# rezagada en un turno robado: llegaba la de un jugador cuando ya se esperaba a otro, se aplicaba
	# al _player de turno (que era del otro) y se consumia su turno sin que el hubiera elegido nada.
	if emisor != 0 and emisor != _esperando_a:
		print("[combate] accion remota IGNORADA (%s): la manda el peer %d y yo espero al %d" % [
			tipo, emisor, _esperando_a])
		_traza_add("DESCARTO '%s': viene del peer %d y espero al %d (respuesta de otro)" % [
			tipo, emisor, _esperando_a])
		return

	# ¿ME CONTESTA A LO QUE LE PREGUNTE, Y NO A LO DE ANTES? El numero de peticion lo distingue: una
	# respuesta con un numero viejo es un eco de un turno ya resuelto y hay que tirarla, no aplicarla.
	var seq_pet: int = int(_peticion_pendiente.get("seq", 0))
	var seq_res: int = int(accion.get("seq", 0))
	if seq_res != 0 and seq_pet != 0 and seq_res != seq_pet:
		print("[combate] accion remota IGNORADA (%s): responde a la #%d y la pendiente es la #%d" % [
			tipo, seq_res, seq_pet])
		_traza_add("DESCARTO '%s' del peer %d: responde a #%d y pido la #%d (rezagada)" % [
			tipo, emisor, seq_res, seq_pet])
		return

	# ¿Y ME CONTESTA LO QUE LE PREGUNTE? Un "atacar" retrasado cuando lo pendiente es una FRASE se
	# colaba por el `_:` de mas abajo y se resolvia como un ataque, saltandose el recitado.
	var pendiente: String = String(_peticion_pendiente.get("tipo", ""))
	if not _encaja_con_lo_pedido(tipo, pendiente):
		print("[combate] accion remota IGNORADA (%s): lo pendiente era '%s'" % [tipo, pendiente])
		_traza_add("DESCARTO '%s' del peer %d: lo pendiente era '%s' (no encaja)" % [
			tipo, emisor, pendiente])
		return

	_traza_add("RECIBO #%d '%s' del peer %d -> la aplico a %s" % [
		seq_res, tipo, emisor, _player.nombre if _player != null else "?"])
	_fin_de_espera()
	var obj: int = int(accion.get("obj", -1))
	if obj >= 0 and obj < _enemies.size():
		_target_idx = obj
	match String(accion.get("tipo", "atacar")):
		"defender":
			_accion_defender()
		"huir":
			_accion_huir()
		"habilidad":
			# Se busca en SU loadout (el doble lleva su mismo equipo): asi nadie puede colar una
			# habilidad que su personaje no tiene.
			var ruta: String = String(accion.get("ruta", ""))
			var elegida: AbilityData = null
			for ab in _player.abilities_combate:
				if ab != null and String(ab.resource_path) == ruta:
					elegida = ab
					break
			if elegida != null:
				_usar_habilidad(elegida)
			else:
				_accion_atacar()   # ya no la tiene: no se pierde el turno
		"magia":
			# Empieza a recitar. El hechizo se busca en SU loadout (mismo criterio que las
			# habilidades: nadie puede colar una magia que su personaje no lleva).
			var ruta_s: String = String(accion.get("ruta", ""))
			var hechizo: SpellData = null
			for sp in _player.spells:
				if sp != null and String(sp.resource_path) == ruta_s:
					hechizo = sp
					break
			if hechizo != null:
				# El destinatario viaja como indice en _aliados (igual que la pocion). -1 = a si mismo.
				var ia_m: int = int(accion.get("aliado", -1))
				var al_m: Combatant = _aliados[ia_m] if ia_m >= 0 and ia_m < _aliados.size() else null
				_elegir_hechizo(hechizo, al_m)
			else:
				_accion_atacar()   # ya no lo lleva: no se pierde el turno
		"frase":
			# Ha respondido al examen de una frase. Quien dice si acerto soy YO: la frase correcta
			# nunca sale de aqui, solo vuelve el texto que eligio.
			if _cast_spell == null or _cast_index >= _cast_spell.longitud():
				return
			_responder_frase(String(accion.get("texto", "")), _cast_spell.frases[_cast_index])
		"cancelar":
			# Se ha echado atras ANTES de recitar nada: el conjuro se cae sin coste y le devuelvo el
			# turno entero. Con una frase ya recitada NO se acepta (solo puede ser un eco: el boton
			# no existe a partir de la segunda).
			if _cast_spell == null or _cast_index > 0:
				return
			_limpiar_casteo()
			_update_hp()
			_pedir_accion_del_turno()
		"disparar":
			if _cast_spell == null:
				return
			_disparar_hechizo()
		"objeto":
			var cons = load(String(accion.get("ruta", "")))
			var ia: int = int(accion.get("aliado", -1))
			var al: Combatant = _aliados[ia] if ia >= 0 and ia < _aliados.size() else _player
			if cons != null:
				_usar_objeto(cons, al, false)   # ya la pago el de su bolsa, aqui solo se resuelve
			else:
				_accion_atacar()
		_:
			_accion_atacar()


# ¿La respuesta que llega es de la clase de lo que se pidio? Un turno ("accion") admite cualquiera de
# las acciones del menu; una FRASE solo admite la frase, y el DISPARO solo el disparo. Mezclarlos era
# lo que dejaba que un "atacar" rezagado se resolviera en mitad de un recitado.
func _encaja_con_lo_pedido(tipo: String, pendiente: String) -> bool:
	match pendiente:
		# La frase admite tambien el "cancelar": desde el examen de la PRIMERA se puede volver atras.
		"frase":   return tipo in ["frase", "cancelar"]
		"disparo": return tipo == "disparar"
		"accion":  return tipo in ["atacar", "defender", "huir", "habilidad", "magia", "objeto"]
		_:         return true   # peticion sin tipo conocido: no se bloquea nada


# El anfitrion ha cerrado la pelea: mi espejo se va con ella.
func cerrar_espejo() -> void:
	if not _espejo:
		return
	_state = State.FINISHED
	combat_finished.emit(false, [], [], [], [], [], [], [])


# Manda la foto a los espejos. Se llama tras cada cambio que se VE (un golpe, un turno nuevo, el
# final). Es barata -solo numeros- pero no se manda cada frame: solo cuando algo cambia.
func _difundir() -> void:
	if _espejo or not Net.activo:
		return
	Net.difundir_instantanea(instantanea())


# LA BARRA DE ACCION en los espejos. El ATB corre SOLO aqui, asi que alli los marcadores se
# quedaban clavados donde nacieron: el que entraba segundo veia una barra muerta. No puede ir en la
# instantanea (esa sale solo cuando cambia algo, y la barra iria a saltos), asi que va como las
# POSICIONES de los enemigos: un tick propio a ~20 Hz, sin garantia de entrega —si se pierde uno,
# el siguiente llega en 50 ms y nadie lo nota—.
func _difundir_atb(delta: float) -> void:
	if not Net.activo:
		return
	_atb_acum += delta
	if _atb_acum < ATB_TICK:
		return
	_atb_acum = 0.0
	var r: PackedFloat32Array = PackedFloat32Array()
	for c in _aliados:
		r.append(float(_gauge.get(c, 0.0)) / UMBRAL)
	for e in _enemies:
		r.append(float(_gauge.get(e, 0.0)) / UMBRAL)
	Net.difundir_atb(r)


# Corre en el ESPEJO: los avances que me manda el anfitrion, en el orden del roster (los mios
# primero y detras los de enfrente). _update_timeline ya los pinta desde _gauge en cada frame.
func aplicar_atb(ratios: PackedFloat32Array) -> void:
	if not _espejo:
		return
	var n: int = _aliados.size()
	for i in mini(n, ratios.size()):
		_fijar_objetivo_atb(_aliados[i], float(ratios[i]) * UMBRAL)
	for i in mini(_enemies.size(), ratios.size() - n):
		_fijar_objetivo_atb(_enemies[i], float(ratios[n + i]) * UMBRAL)


# Guarda el destino de la barra de un combatiente. El primer valor se pone TAL CUAL (que la barra
# aparezca ya donde va, sin subir desde 0 al entrar); a partir de ahi _interpolar_atb_espejo la
# acerca suave. Mismo espiritu que remote_player.ir_a con su primer paquete.
func _fijar_objetivo_atb(c, valor: float) -> void:
	_gauge_objetivo[c] = valor
	if not _gauge.has(c):
		_gauge[c] = valor


# ESPEJO: acerca cada barra a su objetivo, un lerp exponencial por frame (tapa el hueco entre los
# paquetes de 20 Hz). Corre en _process ANTES de pintar la linea de tiempo.
func _interpolar_atb_espejo(delta: float) -> void:
	if delta <= 0.0:
		return
	var t: float = 1.0 - exp(-SUAVIZADO_ATB * delta)
	for c in _gauge_objetivo:
		_gauge[c] = lerpf(float(_gauge.get(c, 0.0)), float(_gauge_objetivo[c]), t)


func _volcar(lista: Array, valores: Array) -> void:
	for i in mini(lista.size(), valores.size()):
		var v: Array = valores[i]
		lista[i].current_hp = float(v[0])
		lista[i].current_mp = float(v[1])
		lista[i].current_energy = float(v[2])
		if v.size() > 3:
			_chips_espejo[lista[i]] = v[3]
		# Los MAXIMOS, si el paquete los trae (un compañero con una version anterior no los manda, y
		# entonces se dejan como estaban en vez de ponerlos a cero y borrarle las barras).
		if v.size() > 6:
			lista[i].max_hp = float(v[4])
			lista[i].max_mp = float(v[5])
			lista[i].max_energy = float(v[6])


# ESPEJO: los que han caido en la instantanea se apagan aqui igual que en la pantalla que ejecuta.
# Alli lo hacen _apagar_bloque y _caer_aliado desde el motor; aqui no hay motor, solo numeros, asi
# que se mira quien esta a 0 y se le apaga el bloque y se le quita del marcador de turnos. Sin esto
# el espejo dejaba cadaveres pintados como vivos.
func _apagar_caidos() -> void:
	for i in _bloques.size():
		if i >= _enemies.size() or _enemies[i].is_alive():
			continue
		_apagar_bloque(_enemies[i])
		if _timeline != null:
			_timeline.quitar(_enemies[i])
	for i in _bloques_aliados.size():
		if i >= _aliados.size() or _aliados[i].is_alive():
			continue
		var b: Dictionary = _bloques_aliados[i]
		b["panel"].modulate = Color(0.4, 0.4, 0.4)
		b["panel"].add_theme_stylebox_override("panel", _sb_bloque(false))
		b["chips"].visible = false
		if _timeline != null:
			_timeline.quitar(_aliados[i])


# El OBJETIVO de tus acciones: el enemigo que tienes seleccionado. Si el indice apunta a un
# muerto (o a nada), cae al primer vivo, para que una accion nunca se lance al vacio.
func _objetivo() -> Combatant:
	if _target_idx >= 0 and _target_idx < _enemies.size() and _enemies[_target_idx].is_alive():
		return _enemies[_target_idx]
	for e in _enemies:
		if e.is_alive():
			return e
	return _enemies[0] if not _enemies.is_empty() else null


# Los que siguen en pie. Es la lista que manda en el orden de turnos y en la victoria.
func _vivos() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for e in _enemies:
		if e.is_alive():
			out.append(e)
	return out


# ETIQUETA de un combatiente para el LOG: "2. Slime" en los enemigos (el MISMO numero que lleva su
# bloque, ver _crear_bloque) y el nombre pelado en los tuyos. Con tres slimes delante, "Slime usa
# Aplastamiento" no dice cual de los tres: el numero es lo unico que lo ata a la tarjeta que ves.
# El numero es cosa de la UI (es la posicion en _enemies), por eso vive aqui y no en Combatant.
func _etq(c: Combatant) -> String:
	if c == null:
		return "?"
	var i: int = _enemies.find(c)
	return "%d. %s" % [i + 1, c.nombre] if i >= 0 else c.nombre


# Los TUYOS que siguen en pie. Manda en el orden de turnos y en la derrota: se pierde cuando cae
# el ultimo, no cuando cae el que llevabas delante.
func _aliados_vivos() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in _aliados:
		if c.is_alive() and not _huidos.has(c):
			out.append(c)
	return out


# A QUIEN pega el enemigo: uno de los tuyos que siga en pie, sorteado por PESO. Dos capas, y ninguna
# FUERZA nada (solo inclinan la balanza; el mago nunca esta a salvo del todo):
#   1) PASIVO: llevar ESCUDO pesa AGGRO_ESCUDO (x2). El que va tapado atrae golpes sin hacer nada.
#   2) PROVOCAR: la habilidad de escudo multiplica por PROVOCA_PESO (x4) durante unos turnos.
# Un tanque con escudo pasa de ~40% de los golpes (en un grupo de 4) a ~73% mientras provoca.
func _elegir_objetivo_enemigo(atenuado: bool = false) -> Combatant:
	var vivos: Array[Combatant] = _aliados_vivos()
	if vivos.is_empty():
		return null
	var pesos: Array[float] = []
	var total: float = 0.0
	for c in vivos:
		var w: float = _peso_aggro(c)
		# ATENUADO: para el reparto GOLPE A GOLPE de una habilidad multi-golpe. Ahi el sorteo se
		# repite 5-6 veces seguidas, y con el peso entero el tanque se comia casi la tanda completa
		# (~5 de 6). La raiz cuadrada lo suaviza SIN invertir el orden: sigue siendo el que mas come,
		# pero los demas reciben lo suyo. En la eleccion de UN objetivo (turno normal) no se toca.
		if atenuado:
			w = sqrt(w)
		pesos.append(w)
		total += w
	var r: float = randf() * total
	for i in vivos.size():
		r -= pesos[i]
		if r < 0.0:
			return vivos[i]
	return vivos[vivos.size() - 1]


# PESO DE AGGRO de un aliado: el PASIVO (x2 si lleva escudo) x el de PROVOCAR (x4 mientras dure).
# Un tanque quieto ya atrae ~el doble; provocando, se lleva la mayoria de los golpes unos turnos.
# Vive aparte porque lo leen DOS sitios: el sorteo de objetivo y el reparto de la excelia de
# Resistencia (_mult_resistencia_aggro). Si cada uno tuviera su copia, se desincronizarian.
# El SIGILO entra aqui como el espejo exacto de la Provocacion: un multiplicador mas sobre el mismo
# peso. Por eso INCLINA la balanza y no obliga -- al sigiloso le siguen pudiendo pegar, igual que
# provocar no garantiza que te peguen a ti.
func _peso_aggro(c: Combatant) -> float:
	return c.aggro_base * (PROVOCA_PESO if c.provocar_turnos > 0 else 1.0) * c.status_aggro_mult()


func _peso_aggro_total() -> float:
	var total: float = 0.0
	for c in _aliados_vivos():
		total += _peso_aggro(c)
	return total


# CUANTA Resistencia entrena 'obj' por encajar un golpe, comparado con lo que entrenaria si el
# aggro no existiera. Ver el bloque de constantes en game.gd (RESIS_COMPENSA_K y compania):
#   - Al que el tanque protege le llegan pocos golpes -> se le compensa fuerte.
#   - Al tanque le llegan muchos pero mermados -> se le compensa poco (ya gana por frecuencia).
# Con un solo aliado vivo, o sin escudo ni Provocar, devuelve 1.0: nada cambia respecto a antes.
func _mult_resistencia_aggro(obj: Combatant) -> float:
	var vivos: Array[Combatant] = _aliados_vivos()
	if vivos.size() < 2:
		return 1.0
	var total: float = _peso_aggro_total()
	if total <= 0.0:
		return 1.0
	var cuota: float = _peso_aggro(obj) / total
	var justa: float = 1.0 / float(vivos.size())
	if cuota <= 0.0:
		return 1.0
	if cuota < justa:
		# Le pegan MENOS de lo que le tocaria: el mago detras del escudo.
		var deficit: float = clampf(1.0 - cuota / justa, 0.0, 1.0)
		return 1.0 + Game.RESIS_COMPENSA_K * pow(deficit, Game.RESIS_APORTE_EXP)
	# Le pegan MAS de lo que le tocaria: el que va tapado y plantado delante.
	var exceso: float = clampf(1.0 - justa / cuota, 0.0, 1.0)
	return 1.0 + Game.RESIS_TANQUE_K * pow(exceso, Game.RESIS_APORTE_EXP)


# Los VECINOS de 'principal' a los que salpica un hechizo de area: el primer enemigo VIVO a su
# izquierda y el primero a su derecha (maximo 2, haya los cadaveres que haya en medio).
# Los muertos NO se comen el salpicon: siguen en _enemies para que la numeracion no baile bajo
# tu dedo (ver el comentario de _enemies), que es cosa de la UI, no la geometria de la pelea.
# Si el hueco muerto absorbiera el golpe, el hechizo iria a MENOS segun avanza el combate, y
# encima sin decirtelo. Es la misma regla que ya sigue _objetivo(): nada se lanza al vacio.
func _adyacentes_vivos(principal: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var centro: int = _enemies.find(principal)
	if centro < 0:
		return out
	for paso in [-1, 1]:
		var i: int = centro + paso
		while i >= 0 and i < _enemies.size():
			if _enemies[i].is_alive():
				out.append(_enemies[i])
				break
			i += paso
	return out


# A quien alcanza la fase de AREA, con el multiplicador de daño de cada uno ya puesto:
# [{c: Combatant, escala: float}]. El principal va SIEMPRE el primero (el log lo cuenta asi).
func _objetivos_area(spell: SpellData, principal: Combatant) -> Array:
	var out: Array = [{"c": principal, "escala": spell.dano_objetivo}]
	if not spell.salpica():
		return out
	var vecinos: Array[Combatant] = []
	match spell.alcance:
		SpellData.Alcance.ADYACENTES:
			vecinos = _adyacentes_vivos(principal)
		SpellData.Alcance.TODOS:
			vecinos = _vivos()
	for c in vecinos:
		if c != principal:
			out.append({"c": c, "escala": spell.dano_salpicon})
	return out


# ESPEJO de _adyacentes_vivos pero sobre TU GRUPO (_aliados): el primer aliado VIVO a la izquierda
# de 'principal' y el primero a la derecha (maximo 2). Lo usa el AREA de las habilidades ENEMIGAS
# (un slime que aplasta salpica a los aliados de al lado). Misma regla: los KO no comen el salpicon.
func _adyacentes_aliados_vivos(principal: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var centro: int = _aliados.find(principal)
	if centro < 0:
		return out
	for paso in [-1, 1]:
		var i: int = centro + paso
		while i >= 0 and i < _aliados.size():
			if _aliados[i].is_alive():
				out.append(_aliados[i])
				break
			i += paso
	return out


# A quien alcanza el AREA de una habilidad ENEMIGA sobre tu grupo, con su escala de daño ya puesta:
# [{c, escala}]. El principal SIEMPRE el primero al 100%; los secundarios a area_secundario.
# El ALCANCE lo decide area_max: >= 99 = TODA la fila (Pisotón, Chillido, Bramido); si no, solo los
# ADYACENTES (Aplastamiento, Combustión, Carga). Por eso esas ultimas fijan area_max = 3.
func _objetivos_area_aliados(ab: AbilityData, principal: Combatant) -> Array:
	var out: Array = [{"c": principal, "escala": 1.0}]
	var secundarios: Array[Combatant]
	if ab.area_max >= 99:
		secundarios = _aliados_vivos()
	else:
		secundarios = _adyacentes_aliados_vivos(principal)
	for c in secundarios:
		if c != principal:
			out.append({"c": c, "escala": ab.area_secundario})
	return out


func _ready() -> void:
	# El reloj de la traza (ver _traza_add) arranca AQUI y no en setup(): hay dos caminos de entrada
	# al combate (setup y setup_espejo) y lo que solo se escribe en uno se pierde para el otro.
	_t0 = Time.get_ticks_msec() / 1000.0
	_traza.clear()
	# Forzamos que esta pantalla ocupe toda la ventana, aunque se abra como
	# overlay encima de la mazmorra (si no, sale descentrada/pequeña).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_anadir_fondo()  # fondo opaco para tapar la mazmorra detras
	_montar_columna()  # el combate pasa a una columna de ancho fijo, centrada

	if not _injected:
		# Combatientes de PRUEBA (para abrir combat.tscn directamente con F6). Se montan TRES
		# aliados y TRES slimes de distinta velocidad: asi F6 sirve para probar el combate en grupo
		# (turnos de cada uno, numeracion, seleccion por clic) sin bajar a la mazmorra.
		for j in 3:
			var pab := Abilities.new()
			pab.fuerza = 120; pab.resistencia = 90; pab.destreza = 60
			pab.agilidad = 110 - j * 25   # velocidades distintas: los turnos se alternan
			pab.magia = 20
			var aliado := Combatant.new(["Heroe", "Bibi", "Coco"][j], 1, pab, 50, 5, 5, 5)
			aliado.max_energy = 100.0
			aliado.current_energy = 100.0
			_aliados.append(aliado)
		_player = _aliados[0]
		var colores: Array[Color] = [Color(0.9, 0.3, 0.3), Color(0.4, 0.8, 0.4), Color(0.5, 0.5, 0.95)]
		for i in 3:
			var eab := Abilities.new()
			eab.fuerza = 80; eab.resistencia = 70; eab.destreza = 30
			eab.agilidad = 40 + i * 30   # velocidades distintas: se ve el orden de turnos moverse
			eab.magia = 0
			var e := Combatant.new("Slime %d" % (i + 1), 1, eab, 40, 4, 5, 4)
			e.color_visual = colores[i]
			_enemies.append(e)

	# La barra de TODOS: los tuyos y los de enfrente, en la misma linea de salida. Nadie arranca a
	# cero pelado, sino con un pellizco al azar. No es balance, es LECTURA: sin esto, cuatro bichos
	# identicos avanzan pegados y la barra de accion es un marcador con tres escondidos detras;
	# ademas actuarian siempre en fila india. Con los aliados pasa igual entre ellos.
	_gauge = {}
	for c in _aliados:
		_gauge[c] = randf_range(0.0, INICIATIVA_VENTAJA * 0.25)
	for e in _enemies:
		_gauge[e] = randf_range(0.0, INICIATIVA_VENTAJA * 0.25)
	# Iniciativa: SOLO el bicho que disparo el combate (_enemies[0]) se lleva la media barra.
	# Los vecinos acuden a la pelea, no te han emboscado: darsela a los cuatro serian cuatro
	# acciones enemigas gratis antes de tu primer turno, o sea muerte sin jugar.
	# Y del lado de aca, solo el LIDER (_aliados[0]): es el que ha dado el espadazo, los demas
	# vienen detras.
	if _enemy_initiated:
		if not _enemies.is_empty():
			_gauge[_enemies[0]] = INICIATIVA_VENTAJA
	elif _injected:
		_gauge[_aliados[0]] = INICIATIVA_VENTAJA

	_continue_button.text = "Continuar"
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	_crear_acciones()
	_setup_ui()
	_crear_timeline()
	_crear_estados_dev()  # herramienta de test de estados (KAN-58 Fase 1)
	var primero: Combatant = _enemies[0] if not _enemies.is_empty() else null
	var intro: String
	if _enemy_initiated:
		intro = "¡" + primero.nombre + " te sorprende! Tiene la iniciativa."
	elif _injected:
		intro = "¡Ataque por la espalda! Tienes la iniciativa. 🗡️"
	else:
		intro = "¡Empieza el combate contra " + primero.nombre + "!"
	# Que no te pillen contando bloques: si acuden mas, se dice.
	if _enemies.size() > 1:
		intro += "  ¡Le acompañan %d más! ⚔️" % (_enemies.size() - 1)
	if not _lentas.is_empty():
		var cansados: PackedStringArray = []
		for c in _lentas:
			cansados.append(c.nombre)
		intro += "  (Agotados: %s empiezan más lentos)" % ", ".join(cansados)
	_set_log(intro)

	# Marca de INICIO en consola (para separar combates al montar los Excel).
	var quien: String = "enemigo" if _enemy_initiated else "jugador"
	var rivales: PackedStringArray = []
	for e in _enemies:
		rivales.append("%s (Nv.%d) HP %.2f" % [e.nombre, e.level, e.max_hp])
	var mios: PackedStringArray = []
	for c in _aliados:
		mios.append("%s HP %.2f%s" % [c.nombre, c.max_hp,
			("" if c.max_mp <= 0.0 else " MP %.2f" % c.max_mp)])
	print("[combate] ===== INICIO vs %s | %s | iniciativa: %s =====" % [
		" + ".join(rivales), " + ".join(mios), quien])


# El PANEL DE ACCIONES, a la derecha de la pantalla. Los seis botones eran una fila de texto pequeño
# abajo del todo, pegada al log: con el pulgar era una loteria.
#
# Y los SUBMENUS (habilidades, magia, objetos, recitado) viven en el mismo panel, no debajo del log.
# Encaja solo porque ya se pintaban a dos columnas (ver _rejilla_submenu): al abrir uno se sustituye
# una rejilla de 2 por otra de 2 en el MISMO sitio, asi que la pantalla no salta ni hay que
# rediseñarlos.
# La rejilla ocupa TODO el ancho que queda a la izquierda del log, en 3 columnas x 2 filas: con las
# 2x3 de antes, el panel media 360 px y dejaba media franja de abajo sin usar.
const COLUMNAS_ACCION := 3
const ANCHO_BOTON_ACCION := 168.0   # minimo; los botones se reparten el ancho sobrante
const ALTO_BOTON_ACCION := 76.0
# Las FRASES del recitado van una por fila (el texto es largo y necesita el ancho entero), asi que
# son mas bajas que un boton de accion: cuatro de 76 + el Volver no caben en pantalla. 60 px sigue
# estando por encima del minimo comodo para un pulgar, que es lo que se buscaba: fallar una frase
# duele (backfire), y se estaban fallando por el TAMAÑO del boton, no por no saberse la frase.
const ALTO_BOTON_VOLVER := 56.0
# Las FRASES del recitado van a DOS columnas (las acciones y los submenus van a tres): lo que llevan
# dentro es una frase entera, no el nombre corto de un hechizo.
const COLUMNAS_FRASES := 2
# Hasta donde puede crecer el panel hacia ARRIBA. Por encima de esto se comeria los bloques del
# grupo (que acaban hacia la mitad de la pantalla).
const ALTO_PANEL_MAX := 420.0
# La linea de accion (turn_timeline) se come los ultimos 80 px de la pantalla. Todo lo de abajo
# tiene que quedarse por encima de ella.
const HUECO_TIMELINE := 96.0


func _crear_acciones() -> void:
	# ABAJO A LA IZQUIERDA, donde antes estaba el historial. El log se ha ido al otro lado: los
	# botones son lo que se toca y van al alcance del pulgar, el texto es lo que se lee y va a la
	# columna de la derecha.
	_panel_acciones = VBoxContainer.new()
	_panel_acciones.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel_acciones.offset_left = 16.0 + Tactil.borde.x
	# Hasta donde empieza la columna del log: la franja de abajo entera es suya.
	_panel_acciones.offset_right = -ANCHO_LOG - 32.0 - Tactil.borde.x
	_panel_acciones.offset_bottom = -HUECO_TIMELINE - Tactil.borde.y
	_panel_acciones.offset_top = _panel_acciones.offset_bottom - ALTO_BOTON_ACCION * 2.0 - 20.0
	_panel_acciones.alignment = BoxContainer.ALIGNMENT_END
	_panel_acciones.add_theme_constant_override("separation", 8)
	_panel_acciones.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_panel_acciones)

	# Los seis, en rejilla de 3x2 y repartiendose el ancho.
	_actions_box = GridContainer.new()
	(_actions_box as GridContainer).columns = COLUMNAS_ACCION
	_actions_box.add_theme_constant_override("h_separation", 10)
	_actions_box.add_theme_constant_override("v_separation", 10)
	_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_acciones.add_child(_actions_box)
	var defs := [
		[Action.ATTACK, "Atacar"],
		[Action.HABILIDAD, "Habilidad"],
		[Action.MAGIC, "Magia"],
		[Action.DEFEND, "Defender"],
		[Action.OBJETO, "Objeto"],
		[Action.FLEE, "Huir"],
	]
	for d in defs:
		var b := TooltipButton.new()   # tooltip con ancho maximo (ver tooltip_button.gd)
		b.text = d[1]
		b.custom_minimum_size = Vector2(ANCHO_BOTON_ACCION, ALTO_BOTON_ACCION)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # se reparten la franja a partes iguales
		b.add_theme_font_size_override("font_size", 18)
		var id: int = d[0]
		b.pressed.connect(_on_action.bind(id))
		_actions_box.add_child(b)
		_action_buttons[id] = b
	# Cajas de magia (KAN-56): submenu de hechizos y caja del recitado/disparo.
	_spell_box = VBoxContainer.new()
	_panel_acciones.add_child(_spell_box)
	_cast_box = VBoxContainer.new()
	_panel_acciones.add_child(_cast_box)
	# Submenu de habilidades (KAN-57).
	_ability_box = VBoxContainer.new()
	_panel_acciones.add_child(_ability_box)
	# Submenu de objetos/pociones (KAN-57).
	_objeto_box = VBoxContainer.new()
	_panel_acciones.add_child(_objeto_box)

	# CONTINUAR (el del final del combate) se muda aqui abajo con los demas. Vivia arriba, pegado a
	# las barras: justo donde NO esta el pulgar despues de haber estado pulsando en esta franja toda
	# la pelea. Va el ultimo del VBox para que salga en el mismo sitio que la rejilla, que a esas
	# alturas ya esta escondida.
	_continue_button.get_parent().remove_child(_continue_button)
	_panel_acciones.add_child(_continue_button)
	_continue_button.custom_minimum_size = Vector2(0, ALTO_BOTON_ACCION)
	_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_button.add_theme_font_size_override("font_size", 20)

	_ocultar_cajas()


# Los submenus (habilidades, magia, objetos) se pintan a DOS COLUMNAS: en una sola columna cada
# boton ocupaba el ancho entero y con 4 habilidades + los hechizos la lista se salia del hueco que
# deja el log. Devuelve el GridContainer donde van los botones.
#
# El grid va DENTRO del VBox y no en su lugar: el "◄ Volver" tiene que ir debajo, a lo ancho, y un
# GridContainer no tiene colspan — metido en la rejilla se quedaria como media celda torcida.
# Quien llame a esto ya ha vaciado la caja (los hijos del VBox, grid incluido, se van de una).
func _rejilla_submenu(caja: VBoxContainer, columnas: int = COLUMNAS_ACCION) -> GridContainer:
	var grid := GridContainer.new()
	# Por defecto, las MISMAS columnas que la rejilla de acciones: los submenus comparten panel con
	# ella, y con un numero distinto la franja cambiaria de forma al abrir uno. El recitado pide
	# menos columnas a proposito (ver _pintar_test): sus botones llevan una frase entera dentro.
	grid.columns = columnas
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(grid)
	return grid


# Deja el boton listo para una celda de la rejilla: media anchura, alto fijo y el texto recortado
# en vez de estirando la columna. Lo que no cabe en el texto esta en el tooltip, que es largo y
# lleva el motivo del bloqueo (ver TooltipButton).
func _celda_submenu(b: Button) -> void:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Del mismo alto que los seis botones de accion, que ahora comparten panel: si un submenu tuviera
	# celdas mas bajas, abrirlo se sentiria como que la pantalla encoge.
	b.custom_minimum_size = Vector2(ANCHO_BOTON_ACCION, ALTO_BOTON_ACCION)
	b.clip_text = true


# El panel de acciones CRECE hacia arriba segun lo que tenga que enseñar. Antes era de alto fijo (dos
# filas), y por eso todo lo que no fuera la rejilla de seis se pintaba apretado: las cuatro frases del
# recitado y los "◄ Volver" salian del alto por defecto de un Button, pegados unos a otros. En el
# movil eso es fallar la frase sin querer.
#
# El panel esta anclado ABAJO, asi que mover offset_top solo le da sitio; los botones no se mueven de
# donde estaban. Quien abre un submenu pide su alto; _ocultar_cajas lo devuelve a las dos filas.
func _alto_panel(alto: float) -> void:
	if _panel_acciones == null:
		return
	_panel_acciones.offset_top = _panel_acciones.offset_bottom \
		- clampf(alto, ALTO_BOTON_ACCION * 2.0, ALTO_PANEL_MAX) - 20.0


# Cierra un submenu: le pone el "◄ Volver" a lo ancho, ajusta el alto del panel a lo que ocupa su
# rejilla y lo enseña. 'n' = cuantos botones lleva la rejilla (de ahi salen las filas), 'al' = a
# donde vuelve el boton. Los seis submenus repetian estas cuatro lineas a mano.
func _cerrar_submenu(caja: VBoxContainer, n: int, al: Callable) -> void:
	# Separacion entre la rejilla y el Volver: pegado a las celdas se pulsa por accidente.
	caja.add_theme_constant_override("separation", 12)
	var volver := Button.new()
	volver.text = "◄ Volver"
	volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volver.custom_minimum_size = Vector2(0, ALTO_BOTON_VOLVER)
	volver.add_theme_font_size_override("font_size", 18)
	volver.pressed.connect(al)
	caja.add_child(volver)
	var filas: int = maxi(1, ceili(n / float(COLUMNAS_ACCION)))
	_alto_panel(filas * ALTO_BOTON_ACCION + (filas - 1) * 10.0 + 12.0 + ALTO_BOTON_VOLVER)
	caja.visible = true


# Oculta las cajas del turno del jugador (acciones / submenu magia / recitado / habilidades /
# objetos). Y por defecto DEVUELVE el historial: ocultar las cajas = volver al estado "mirando el
# log". Los submenus que quieran ocupar el sitio del log (magia, frases, habilidades, objetos) se
# encargan de ocultarlo DESPUES con _ocultar_log(), asi el log solo desaparece mientras eliges y
# vuelve solo al acabar el turno (todos los cierres pasan por aqui: _fin_de_eleccion, etc.).
func _ocultar_cajas() -> void:
	if _actions_box != null: _actions_box.visible = false
	if _spell_box != null: _spell_box.visible = false
	if _cast_box != null: _cast_box.visible = false
	if _ability_box != null: _ability_box.visible = false
	if _objeto_box != null: _objeto_box.visible = false
	if _log != null: _log.visible = true
	_alto_panel(0.0)   # vuelve a las dos filas de la rejilla de acciones (el clamp lo sube al minimo)


# YA NO ESCONDE NADA, y se queda como un sitio al que llamar por si algun dia hace falta.
#
# Cuando los submenus vivian debajo del log, abrir uno le quitaba el sitio al historial: seis lineas
# de alto fijo no caben con una lista de hechizos debajo. Desde que los submenus estan en el panel de
# la derecha, ese conflicto no existe — y el historial tiene que verse SIEMPRE, que es justo lo que
# uno quiere leer mientras elige que hacer.
func _ocultar_log() -> void:
	pass


func _setup_ui() -> void:
	# Un bloque por enemigo, EN FILA y en el orden de _enemies -> ese orden es la numeracion que
	# se ve (el 1º empezando por la izquierda = marcador "1" en la barra de accion).
	for i in _enemies.size():
		var b: Dictionary = _crear_bloque(_enemies[i], i + 1, i)
		_bloques.append(b)
		_bloques_box.add_child(b["panel"])
	# Separador para que tu fila no se confunda con la de enfrente. IGNORE: un Control es STOP
	# por defecto y esta franja se comeria los clics que caigan en ella.
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 12)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(sep)
	_col.move_child(sep, 1)
	# TU FILA: un bloque por miembro del grupo, construidos igual que los enemigos (numero 0 = sin
	# numerar y sin clic: a los tuyos no hace falta apuntarles). Cada uno lleva sus tres barras
	# (vida, energia y maná), porque cada uno gasta las suyas.
	_aliados_box = _crear_fila_bloques()
	_col.move_child(_aliados_box, 2)
	for i in _aliados.size():
		_anadir_bloque_aliado(_aliados[i])
	_seleccionar(0)
	# El log lo configura _montar_log (columna derecha, con las frases partidas en varias lineas).
	# Aqui ya NO se le pone clip_text: recortar era de cuando vivia en una linea por frase.
	_update_hp()
	_continue_button.visible = false
	_ocultar_cajas()


# El bloque de UN aliado (su caja con nombre, estados y las tres barras), colgado de la fila. Se
# saco del bucle de _setup_ui para poder añadir aliados a MITAD de pelea (hito 5.4-C): un
# compañero que se une necesita exactamente esto y nada mas.
func _anadir_bloque_aliado(c: Combatant) -> void:
	var ba: Dictionary = _crear_bloque(c, 0, -1)
	_crear_barras_aliado(ba, c)
	_bloques_aliados.append(ba)
	_aliados_box.add_child(ba["panel"])
	# La fila acaba de crecer: puede que lo que cabia antes ya no quepa (ver _ancho_bloque).
	_reajustar_anchos(_bloques_aliados, _bloques_aliados.size())


# UN ALIADO MAS en la pelea en curso (hito 5.4-C): entra el personaje de otro humano que se une.
# Es el simetrico de anadir_enemigo, pero con una diferencia importante: SIEMPRE por el final
# (append), nunca insertando ni reordenando. combat_finished devuelve los resultados POR INDICE y
# Game los cruza posicionalmente con _active_player_pjs; mover a alguien de sitio le daria la vida
# y el mana de otro.
# Devuelve false si la pelea ya esta cerrandose o no cabe en pantalla.
# ¿Se ha perdido la pelea? Estaba escrito a mano en CUATRO sitios distintos; se centraliza aqui
# porque desde el hito 5.4 puede haber un refuerzo EN CAMINO (un compañero que se une, avisado por
# la red pero que aun no ha entrado). Declarar la derrota en ese hueco cerraria la pelea justo
# cuando llegaba el rescate, y encima el que llega se encontraria una pelea muerta.
func derrota() -> bool:
	if not _aliados_vivos().is_empty():
		return false
	return not _espera_refuerzo


# Lo enciende quien vaya a meter un aliado (Net, al conceder la union) para que la pelea aguante
# hasta que entre de verdad. Se apaga solo en anadir_aliado.
func esperar_refuerzo(si: bool) -> void:
	_espera_refuerzo = si


# 'agotado' = llega SIN FUELLE de correr por el mapa. Sus primeras acciones van lentas, igual que
# las del que empieza la pelea agotado (ver setup: es la misma penalizacion, y se olvidaba aqui).
func anadir_aliado(c: Combatant, agotado: bool = false) -> bool:
	if c == null or _state == State.FINISHED:
		return false
	# Los HUIDOS no ocupan plaza. _aliados NO se vacia al huir (ese array se cruza por INDICE con
	# Game._active_player_pjs, ver _retirar_aliado), asi que contarlo a pelo dejaba las plazas de quien
	# se fue pilladas PARA SIEMPRE: huias de una pelea llena y ya no podias volver a entrar nunca,
	# aunque tu compañero siguiera dentro peleandola. Su hueco tiene que quedar libre.
	if _aliados.size() - _huidos.size() >= MAX_ALIADOS:
		return false
	_desambiguar(c)
	_aliados.append(c)
	_espera_refuerzo = false   # ya ha llegado
	_gauge[c] = 0.0          # entra con la barra a cero: unirse no regala un turno inmediato
	if agotado:
		_lentas[c] = EXHAUSTED_SLOW_ACTIONS
	_anadir_bloque_aliado(c)
	if _timeline != null:
		_timeline.anadir(c, _color_de(c), _material_de(c), "")
	_alta_de_combatiente()
	_update_hp()
	_set_log("%s se une a la pelea." % c.nombre)
	return true


# Un combatiente MAS en la pelea. Sube la revision del roster y se lo manda a los espejos por canal
# FIABLE: la instantanea es solo numeros y ademas va sin garantia, asi que un alta no puede viajar
# en ella (era el bug de "los enemigos que se añaden no los ve el otro jugador").
func _alta_de_combatiente() -> void:
	_rev += 1
	if _espejo or not Net.activo:
		return
	Net.difundir_roster(roster_para_espejo())


# Dos personajes con el mismo nombre eran indistinguibles en la pelea (el log decia "Dasui ataca" y
# habia dos Dasui). Se numeran del segundo en adelante. Se toca el nombre del COMBATIENTE, que es una
# copia de esta pelea, nunca el del PersonajeData.
func _desambiguar(c: Combatant) -> void:
	if c == null:
		return
	var base: String = c.nombre
	var n: int = 1
	while _hay_aliado_llamado(c.nombre, c):
		n += 1
		c.nombre = "%s (%d)" % [base, n]


# Sirve igual antes de meter a alguien en la lista y con el ya dentro: se ignora a si mismo.
func _hay_aliado_llamado(nombre: String, salvo: Combatant) -> bool:
	for a in _aliados:
		if a != salvo and a.nombre == nombre:
			return true
	return false


# BLOQUE de un combatiente: la unidad que se ve, se señala y se clica. Junta en una caja su
# numero, su nombre, sus estados y su barra de vida, y esa caja ENTERA es la que se rodea con
# el borde blanco al seleccionarlo (por eso es un PanelContainer y no un apaño de Labels).
#   numero > 0 -> enemigo numerado y clicable;  numero <= 0 -> el jugador (ni numero ni clic).
#   idx = indice en _enemies (-1 para el jugador).
# Devuelve {panel, vbox, nombre, chips, hp, hp_lbl}.
func _crear_bloque(c: Combatant, numero: int, idx: int) -> Dictionary:
	var panel := PanelContainer.new()
	# El panel es quien recibe el clic; sus hijos van en PASS para no comerselo (ver _crear_bloque
	# de la barra: una ProgressBar es STOP por defecto y ocupa media caja).
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if numero > 0 else Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _sb_bloque(false))
	# Mismo ancho para todos los de su fila, tuyo o enemigo: es lo que les permite ir en fila.
	panel.custom_minimum_size = Vector2(_ancho_bloque(
		_enemies.size() if numero > 0 else _aliados.size()), 0)

	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_PASS
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 6)
	panel.add_child(margen)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	margen.add_child(vb)

	# Fila del nombre: [nº] nombre.
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(fila)

	if numero > 0:
		var num := Label.new()
		num.text = "%d." % numero
		num.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(num)

	var nombre := Label.new()
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# clip_text hace DOS cosas, y la segunda es la que importa aqui: ademas de recortar, pone el
	# ancho MINIMO del Label a 0. Sin eso, un bicho con nombre largo ("Slime venenoso (Nv.1)")
	# exigiria mas de ANCHO_BLOQUE, el bloque creceria (custom_minimum_size es un MINIMO, no un
	# tope) y la fila de enemigos dejaria de tener columnas iguales.
	nombre.clip_text = true
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nombre)

	# Los chips van en su PROPIA zona, bajo el nombre, con el alto SIEMPRE reservado (aunque no
	# haya ninguno): asi entrar o salir un estado no mueve nada de sitio. Antes iban al lado del
	# nombre porque la UI era una columna a lo ancho y sobraba sitio horizontal; en un bloque de
	# 260 px ya no caben al lado, y apretarlos ahi recortaria el nombre.
	#
	# El envoltorio es un Control PELADO a proposito: un Container propagaria el tamaño minimo de
	# los chips hacia arriba y 3-4 estados volverian a ensanchar el bloque, rompiendo el ancho
	# fijo. Un Control normal no agrega el minimo de sus hijos, asi que el ancho queda blindado.
	var chips_wrap := Control.new()
	chips_wrap.custom_minimum_size = Vector2(0, ALTO_CHIPS)
	chips_wrap.clip_contents = true   # lo que no entre en las dos filas se recorta, no desborda
	chips_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(chips_wrap)

	# HFlow y no HBox: reparte los chips en varias filas EL SOLO cuando no caben a lo ancho. Con
	# un HBox se saldrian en linea recta y el clip_contents se los comeria.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	chips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chips.mouse_filter = Control.MOUSE_FILTER_PASS
	chips_wrap.add_child(chips)

	# Barra de VIDA gorda y con el numero DENTRO, como las del mapa (ver player.gd).
	var hp := ProgressBar.new()
	hp.max_value = c.max_hp
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, 24)
	hp.self_modulate = Color(1.0, 0.4, 0.4)
	# PASS y no el STOP por defecto: la barra ocupa media caja, y en STOP se tragaria el clic
	# de seleccion en toda esa mitad.
	hp.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(hp)
	var hp_lbl: Label = _crear_label_barra(hp, 13)

	if numero > 0:
		panel.gui_input.connect(_on_bloque_gui_input.bind(idx))

	return {"panel": panel, "vbox": vb, "nombre": nombre, "chips": chips,
		"hp": hp, "hp_lbl": hp_lbl, "idx": idx}


# Estilo del bloque: seleccionado = borde blanco alrededor de todo, normal = borde transparente.
# El GROSOR es el mismo en los dos a proposito, y lo que cambia es el COLOR: si el borde
# apareciera y desapareciera, el bloque cambiaria de tamaño y la columna daria un brinco cada
# vez que cambias de objetivo.
func _sb_bloque(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05) if sel else Color(0, 0, 0, 0)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.95) if sel else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(4)
	return sb


# Clic en un bloque enemigo = pasa a ser tu objetivo.
func _on_bloque_gui_input(ev: InputEvent, idx: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_seleccionar(idx)


# Elige a quien van tus acciones. Ignora a los muertos (a un cadaver no se le apunta).
func _seleccionar(idx: int) -> void:
	if idx < 0 or idx >= _enemies.size() or not _enemies[idx].is_alive():
		return
	_target_idx = idx
	for i in _bloques.size():
		var vivo: bool = _enemies[i].is_alive()
		_bloques[i]["panel"].add_theme_stylebox_override("panel", _sb_bloque(vivo and i == idx))


# Apaga el bloque de un enemigo que ha caido: gris, barra a 0 y sin clic. NO se libera el nodo
# a proposito -> si desapareciera, la columna se recolocaria de golpe en mitad del combate y la
# numeracion bailaria. El muerto se queda en su sitio, con su numero, apagado.
func _apagar_bloque(e: Combatant) -> void:
	var i: int = _enemies.find(e)
	if i < 0 or i >= _bloques.size():
		return
	var b: Dictionary = _bloques[i]
	b["panel"].modulate = Color(0.4, 0.4, 0.4)
	b["panel"].mouse_filter = Control.MOUSE_FILTER_IGNORE
	b["panel"].add_theme_stylebox_override("panel", _sb_bloque(false))
	b["chips"].visible = false


# UN ALIADO CAE (KO). No es una derrota: sale del orden de turnos, se le apaga el bloque y la
# pelea sigue con los que queden. Se pierde solo cuando cae el ULTIMO (lo mira quien llama).
# Sus estados y lo que tuviera a medias (Defender, un conjuro recitandose) se van con el: el que
# vuelva a levantarse no reanuda el hechizo por el que iba.
func _caer_aliado(c: Combatant) -> void:
	if c == null:
		return
	_gauge.erase(c)
	_defendiendo.erase(c)
	_casteos.erase(c)
	c.statuses.clear()
	var i: int = _aliados.find(c)
	if i >= 0 and i < _bloques_aliados.size():
		var b: Dictionary = _bloques_aliados[i]
		b["panel"].modulate = Color(0.4, 0.4, 0.4)
		b["panel"].add_theme_stylebox_override("panel", _sb_bloque(false))
		b["chips"].visible = false
	_set_log("%s cae derrotado. 💀" % c.nombre)
	# El que actuaba era el: el puntero pasa a alguien en pie, o las acciones (y el log de "tu
	# turno") se quedarian colgadas de un KO.
	if _player == c:
		var vivos: Array[Combatant] = _aliados_vivos()
		if not vivos.is_empty():
			_player = vivos[0]
	_update_hp()


# INVOCACION (Rey Slime, Parte B): mete un slime VIVO en la pelea en curso.
# El slime nace flojo (t bajo): su papel es ser ESCUDO del Rey (reduccion de daño), no matarte.
# Va marcado como INVOCADO: no cuenta como kill ni da maná al matarlo (ver _slots_invocados).
func _invocar_slime(data: EnemyData) -> bool:
	if data == null:
		return false
	return _meter_enemigo(data.crear_combatant(0.2), true) >= 0


# REFUERZO QUE LLEGA ANDANDO (hito 5.4): un bicho del mapa alcanza a alguien que ya esta peleando y
# se mete en la pelea. A diferencia de un invocado, este es un enemigo DE VERDAD: cuenta como kill,
# da maná al morir y su cadaver es extraible, asi que NO lleva la marca de invocado.
# Devuelve el indice del slot, o -1 si no cabe (entonces el que llama lo pone en cola).
func anadir_enemigo(data: EnemyData, t: float, hp: float = -1.0, estados: Array = []) -> int:
	if data == null or _state == State.FINISHED:
		return -1   # la pelea ya acabo (o se esta cerrando): que se quede fuera
	var c: Combatant = data.crear_combatant(t)
	# Vida arrastrada: si ya venia herido de otra pelea, entra con sus heridas (igual que el arranque).
	if hp >= 0.0:
		c.current_hp = clampf(hp, 1.0, c.max_hp)
	# Y los ESTADOS que traia, tambien igual que en el arranque: el que se une a mitad no puede
	# entrar limpio del veneno que le pusiste hace un minuto.
	StatusEffects.aplicar_a(c, estados)
	return _meter_enemigo(c, false)


# El motor comun de "un enemigo mas en la pelea en curso". Prefiere REUTILIZAR el hueco de un
# cadaver (mantiene el tope y la numeracion estable, sin apilar bloques); si no hay cadaver y queda
# sitio, añade uno al final. Devuelve el slot, o -1 si no cabe.
func _meter_enemigo(c: Combatant, es_invocado: bool) -> int:
	if c == null:
		return -1
	var idx: int = -1
	for i in _enemies.size():
		if not _enemies[i].is_alive():
			idx = i   # hueco de cadaver: se reutiliza
			break
	if idx < 0 and _enemies.size() >= MAX_ENEMIGOS:
		return -1   # ni cadaver ni sitio: no cabe
	if idx >= 0:
		_enemies[idx] = c            # reemplaza al cadaver en su slot
		_revivir_bloque(idx, c)
		_slots_invocados.erase(idx)  # el slot se reestrena: hereda la marca del anterior si no
	else:
		idx = _enemies.size()        # append: slot nuevo al final
		_enemies.append(c)
		var b: Dictionary = _crear_bloque(c, idx + 1, idx)
		_bloques.append(b)
		_bloques_box.add_child(b["panel"])
		# La fila acaba de crecer (refuerzos, invocaciones): con uno mas puede que ya no quepan a su
		# ancho preferido y haya que encogerlos a todos (ver _ancho_bloque).
		_reajustar_anchos(_bloques, _enemies.size())
	# Estructuras por-combatiente (mismas que puebla el arranque): ATB, marcador y roster del escudo.
	_gauge[c] = 0.0                  # entra con la barra a cero (no regala una accion inmediata)
	if _timeline != null:
		_timeline.anadir(c, c.color_visual, null, str(idx + 1))
	c.battle_enemies = _enemies      # referencia compartida: cuenta para el escudo del Rey
	if es_invocado:
		_slots_invocados[idx] = true
	_alta_de_combatiente()   # que los espejos vean al recien llegado (roster nuevo, revision nueva)
	# Rellena YA el bloque recien creado (nombre + barra): _crear_bloque lo deja en blanco y quien lo
	# puebla es _update_hp. Sin esta llamada el refuerzo salia con el recuadro VACIO en la maquina
	# que ejecuta la pelea hasta el siguiente golpe (el espejo si lo veia, porque aplicar_roster
	# refresca). anadir_aliado ya lo hacia; aqui faltaba.
	_update_hp()
	var etiqueta: String = "invocacion" if es_invocado else "refuerzo"
	print("[%s] entra %s en el slot %d (vivos: %d)" % [etiqueta, c.nombre, idx + 1, _vivos().size()])
	return idx


# Vuelve a ENCENDER el bloque de un slot que reutiliza una invocacion: deshace _apagar_bloque y
# reajusta la barra al maximo del nuevo combatiente (el bloque nacio con el max del cadaver anterior).
# El nombre y la vida los refresca _update_hp solo (lee _enemies[i]).
func _revivir_bloque(i: int, c: Combatant) -> void:
	if i < 0 or i >= _bloques.size():
		return
	var b: Dictionary = _bloques[i]
	b["panel"].modulate = Color(1, 1, 1)
	b["panel"].mouse_filter = Control.MOUSE_FILTER_STOP
	b["panel"].add_theme_stylebox_override("panel", _sb_bloque(false))
	b["chips"].visible = true
	b["hp"].max_value = c.max_hp


# Crea las barras de ENERGIA (amarilla) y MANA (azul) de UN aliado, justo debajo de su barra de
# vida, dentro de su bloque, y las guarda en el propio bloque. Cada aliado tiene las suyas: la
# energia y el maná se gastan por persona, asi que no puede haber "la barra del jugador".
func _crear_barras_aliado(bloque: Dictionary, c: Combatant) -> void:
	var vb: VBoxContainer = bloque["vbox"]
	# OJO: self_modulate y no modulate. modulate tiñe TAMBIEN a los hijos, y estas barras
	# llevan dentro el Label con el numero: se pintaria de amarillo/azul y no se leeria.
	if c.max_energy > 0.0:
		var en := ProgressBar.new()
		en.show_percentage = false
		en.max_value = c.max_energy
		en.custom_minimum_size = Vector2(0, 16)
		en.self_modulate = Color(0.95, 0.85, 0.3)   # energia = amarillo
		en.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(en)
		bloque["en"] = en
		bloque["en_lbl"] = _crear_label_barra(en, 11)
	if c.max_mp > 0.0:
		var mp := ProgressBar.new()
		mp.show_percentage = false
		mp.max_value = c.max_mp
		mp.custom_minimum_size = Vector2(0, 16)
		mp.self_modulate = Color(0.4, 0.6, 1.0)     # mana = azul
		mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(mp)
		bloque["mp"] = mp
		bloque["mp_lbl"] = _crear_label_barra(mp, 11)


# Label centrado que cubre toda la barra, para pintar el numero DENTRO. Con borde oscuro
# para que se lea sobre cualquier color de relleno (mismo patron que las barras del mapa).
func _crear_label_barra(bar: ProgressBar, tam: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(l)
	return l


func _update_hp() -> void:
	# MULTI: repintar es exactamente "ha cambiado algo que se ve", asi que es el sitio natural para
	# mandarles la foto a los espejos. NO se llama desde _process (solo tras cambios de verdad), asi
	# que esto no inunda la red.
	_difundir()
	# Un bloque por enemigo. Los muertos se siguen refrescando (su barra a 0): su bloque no
	# desaparece, se queda apagado en su sitio.
	for i in _bloques.size():
		var e: Combatant = _enemies[i]
		var b: Dictionary = _bloques[i]
		# El MAXIMO tambien, en cada refresco. Se fijaba solo al crear el bloque, asi que cualquier
		# cosa que mueva max_hp en vivo (Guardia de carne, que lo duplica) dejaba la barra midiendo
		# contra un tope viejo: el numero decia 130/150 y la barra se pintaba llena como si fuera 75.
		b["hp"].max_value = e.max_hp
		b["hp"].value = e.current_hp
		b["hp_lbl"].text = "%.2f / %.2f" % [e.current_hp, e.max_hp]
		# La etiqueta se queda SOLO con el nombre y el nivel; los estados van en su fila de
		# chips, porque ahi cada uno se puede señalar y explicarse solo.
		b["nombre"].text = "%s  (Nv.%d)" % [e.nombre, e.level]
		if e.is_alive():
			_refrescar_chips(e, b["chips"], i)

	# Y un bloque por aliado, con SUS tres barras. Los KO se siguen refrescando (barra a 0) igual
	# que los cadaveres de enfrente: su bloque se queda apagado en su sitio, no desaparece.
	# Los NUMEROS van dentro de su barra (vida, energia y mana), no amontonados en la etiqueta del
	# nombre: cada cifra al lado de la barra a la que pertenece.
	for i in _bloques_aliados.size():
		var c: Combatant = _aliados[i]
		var b: Dictionary = _bloques_aliados[i]
		# Los tres maximos en cada refresco, por lo mismo que arriba: son numeros que se mueven en
		# mitad de la pelea y la barra tiene que medir contra el de AHORA.
		b["hp"].max_value = c.max_hp
		b["hp"].value = c.current_hp
		b["hp_lbl"].text = "%.2f / %.2f" % [c.current_hp, c.max_hp]
		if b.has("en"):
			b["en"].max_value = c.max_energy
			b["en"].value = c.current_energy
			b["en_lbl"].text = "EN  %.1f / %.1f" % [c.current_energy, c.max_energy]
		if b.has("mp"):
			b["mp"].max_value = c.max_mp
			b["mp"].value = c.current_mp
			b["mp_lbl"].text = "MP  %.2f / %.2f" % [c.current_mp, c.max_mp]
		# La coronita marca a QUIEN LE TOCA: con tres bloques iguales hace falta saber de un
		# vistazo de quien es la accion que estas eligiendo.
		b["nombre"].text = "%s%s  (Nv.%d)" % [("▶ " if c == _player else ""), c.nombre, c.level]
		if c.is_alive():
			_refrescar_chips(c, b["chips"], -1)


# Reconstruye los chips de un combatiente: uno por estado ACTIVO (mas la imbuicion, que no es
# un estado -vive en sus propios campos- pero se sufre igual y hay que poder consultarla).
# Se rehace entero en cada refresco: son 0-5 botones y asi no hay que llevar la cuenta de
# cuales han expirado.
# 'idx' = indice del enemigo dueño de los chips (-1 = jugador): los chips tambien seleccionan.
func _refrescar_chips(c: Combatant, box: Container, idx: int) -> void:
	if box == null:
		return
	for hijo in box.get_children():
		hijo.queue_free()
	for par in _chips_de(c):
		# Los chips de ESTADO traen ademas icono y color (chip_de_grupo); los de mecanica de combate
		# (cargando, recitando, provocacion, imbuicion) siguen siendo pares y se pintan en gris claro.
		# Se mira el tamaño y no el tipo para que un espejo con la instantanea vieja (pares de 2) no
		# reviente al llegar: la red manda estos mismos arrays.
		var col: Color = (par[3] as Color) if par.size() > 3 else CHIP_NEUTRO
		_chip(box, String(par[0]), String(par[1]), idx, col)
	box.visible = box.get_child_count() > 0


# QUE chips lleva un combatiente, como [[texto, tooltip], ...]. Separado de la pintura porque estos
# mismos pares VIAJAN a los espejos dentro de la instantanea: alli los combatientes son maniquis sin
# motor de estados, asi que la unica forma de que vean los debuffs de los demas es recibirlos ya
# resueltos. Un solo sitio decide, y las dos pantallas pintan lo mismo.
func _chips_de(c: Combatant) -> Array:
	if c == null:
		return []
	if _espejo:
		return _chips_espejo.get(c, [])
	var out: Array = []
	# ATAQUE CARGADO (telegrafiado): el aviso del log se lo lleva el turno siguiente, asi que sin
	# esto no hay forma de saber CUAL de los tres bichos te esta preparando el pepino. Va como chip
	# (y no como texto suelto) para heredar el tooltip y el clic-para-apuntar, y para no ensanchar
	# el bloque: la zona de chips tiene alto fijo.
	if c.charging != null:
		# Corto como el resto: el icono y los turnos que faltan. QUE esta cargando va al tooltip.
		out.append(["⚡%dt" % c.charge_left,
			"CARGANDO: %s\nSe dispara en %d turno%s.\nAturdirlo lo interrumpe." % [
				c.charging.nombre, c.charge_left, "" if c.charge_left == 1 else "s"]])
	# RECITANDO un hechizo. Hermano del chip de ataque cargado, y por el mismo motivo: un conjuro dura
	# varios turnos y sin esto no habia forma de saber QUE esta recitando cada uno ni por donde va --
	# ni de ti mismo cuando llevas grupo, ni del personaje del otro humano. Va aqui, en el sitio
	# unico, asi que sale igual en tu pantalla y en la del que espeja la pelea.
	if _casteos.has(c):
		var sp: SpellData = _casteos[c]["spell"] as SpellData
		if sp != null:
			var i: int = int(_casteos[c]["idx"])
			var total: int = sp.longitud()
			if i >= total:
				out.append(["🔮▶",
					"%s: LISTO\nEl conjuro esta recitado entero: el proximo turno se lanza." % sp.nombre])
			else:
				out.append(["🔮%d/%d" % [i + 1, total],
					("%s: recitando\nFrase %d de %d. Fallar una descontrola el conjuro"
					+ " (daño propio) y te cuesta el maná igual.") % [sp.nombre, i + 1, total]])
	# PROVOCANDO (taunt de escudo): sin esto no habia forma de saber si te quedaba taunt ni cuanto.
	# Va en los chips como todo lo demas, asi que sirve igual para ti y para un companero.
	if c.provocar_turnos > 0:
		out.append(["🎯%dt" % c.provocar_turnos,
			"Provocación (%d turno%s)\nLos enemigos centran su atención en ti: te atacan más." % [
				c.provocar_turnos, "" if c.provocar_turnos == 1 else "s"]])
	var imb: String = c.imbue_etiqueta()
	if imb != "":
		out.append([imb, c.imbue_resumen()])
	# FOCO ARCANO. Faltaba: por el mapa se pinta (Game.refrescar_cache_estados) y dentro de la pelea
	# no, que es justo donde importa — canalizabas, te quedaban dos cargas y no habia forma de saberlo
	# mas que acordandote. No lleva turnos porque no caduca: es MUNICION, la gasta lanzar.
	# POSTURA DE GUARDIA (estoque). Es un buff con duración —"hasta tu próxima acción"— que te frena
	# mucho y te sube la esquiva, y hasta ahora solo se anunciaba UNA vez en el log y desaparecia de
	# la vista. Igual que Defender y el agotamiento, aqui abajo.
	if c.en_guardia:
		out.append(["🤺", "En guardia (postura de contraataque)\nTe mueves un %d%% más lento, esquivas un %d%% más y devuelves el golpe al esquivar.\nDura hasta tu próxima acción."
			% [roundi((1.0 - c.guardia_spd_mult) * 100.0), roundi(c.evasion_bonus * 100.0)],
			"🤺", Color(0.85, 0.8, 0.5)])
	# DEFENDIENDO: reduce el daño hasta su próximo turno. Vale para ti y para los compañeros.
	if bool(_defendiendo.get(c, false)) or (c == _player and _player_defending):
		out.append(["🛡", "Defendiendo\nEl daño que te entra se recorta hasta tu próximo turno, y los críticos en tu contra se quedan a la mitad.",
			"🛡", Color(0.6, 0.75, 0.95)])
	# AGOTAMIENTO: entraste sin fuelle y tus primeras acciones van a medio ritmo. Solo salia en la
	# linea de intro del log, que a los tres turnos ya nadie recuerda.
	var lentas: int = int(_lentas.get(c, 0))
	if lentas > 0:
		out.append(["😮‍💨x%d" % lentas,
			"Sin fuelle\nEntraste agotado: tus próximas %d acción%s van a medio ritmo." % [
				lentas, "" if lentas == 1 else "es"],
			"😮‍💨", Color(0.8, 0.6, 0.45)])
	if c.foco_cargas > 0:
		out.append(["🔮x%d" % c.foco_cargas,
			"Foco arcano: %d carga%s\nCada hechizo OFENSIVO gasta una y pega un %d%% más.\nNo caduca con los turnos." % [
				c.foco_cargas, "" if c.foco_cargas == 1 else "s", roundi(Combatant.FOCO_BONUS * 100.0)],
			"🔮", Color(0.55, 0.7, 1.0)])
	# UN chip por estado, no uno por instancia: los 'independent' (Pegajoso, Sangrado) apilan
	# creando una Instance por aplicacion y salian cuatro iconos iguales en fila. Se agrupan por id
	# conservando el orden en que se aplicaron; el detalle por stack va al tooltip.
	var por_estado: Dictionary = {}
	var orden: Array = []
	for e in c.statuses:
		if not por_estado.has(e.id()):
			por_estado[e.id()] = []
			orden.append(e.id())
		(por_estado[e.id()] as Array).append(e)
	for id_est in orden:
		out.append(StatusEffects.chip_de_grupo(por_estado[id_est]))
	return out


# Un chip: el icono+numeros de siempre (etiqueta()), y al pasar el raton por encima, la ficha
# entera (resumen()). TooltipButton porque el tooltip por defecto de Godot no parte lineas.
# 'idx' = enemigo al que pertenece (-1 = jugador).
#
# El chip SI se come el clic (un tooltip necesita recibir el raton, asi que no puede ir en
# IGNORE como los demas hijos del bloque). En vez de pelearse con eso, se le hace bueno: el
# chip tambien selecciona. Asi el bloque no tiene zonas muertas -> pinches donde pinches
# dentro del borde, apuntas a ese bicho.
# Color de los chips que NO son un estado del catalogo (cargando, recitando, provocacion, imbuicion):
# no tienen color propio porque no salen de StatusEffects.
const CHIP_NEUTRO := Color(0.78, 0.80, 0.86)

# El chip se monta en StatusChip, el mismo sitio que usa el HUD del mapa: asi un veneno se ve igual
# en la pelea y andando por el pasillo. Clicar el de un enemigo lo SELECCIONA, como antes.
func _chip(box: Container, texto: String, tooltip: String, idx: int = -1,
		color: Color = CHIP_NEUTRO) -> void:
	var clic: Callable = _seleccionar.bind(idx) if idx >= 0 else Callable()
	box.add_child(StatusChip.crear(texto, color, tooltip, clic))


# Teclas de DESARROLLO DENTRO del combate. El combate corre con el arbol en PAUSA, asi
# que el _input de Game (autoload, pausable) no llega aqui; esta escena es
# PROCESS_MODE_ALWAYS, por eso reproducimos las teclas utiles sobre el combate en curso:
#   H = curacion total (vida/mana/energia al 100%)
#   K = cambiar arma principal   L = cambiar mano secundaria
# Y una que NO es de desarrollo: P = desatascar (ver _desatascar), disponible en partida normal.
func _input(event: InputEvent) -> void:
	if _state == State.FINISHED:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Se MARCA COMO CONSUMIDA la que atendemos aqui. Game escucha las suyas en _unhandled_key_input,
	# que corre DESPUES de este _input: sin esto, en multi (donde el arbol no se pausa) una P dentro
	# del combate disparaba ademas el test de spawns de Game, y una H la cura del mundo.
	match (event as InputEventKey).keycode:
		KEY_H:
			_dev_heal_full()
		KEY_K:
			_dev_swap_weapon(true)
		KEY_L:
			_dev_swap_weapon(false)
		KEY_P:
			_desatascar()
		_:
			return
	get_viewport().set_input_as_handled()


# TECLA P: el combate se queda a veces sin pasar turno y no hay forma de saber por que. Esto
# vuelca el estado ENTERO al log (y a la consola) y luego intenta reanudarlo. No es una tecla de
# desarrollo: es la salida de emergencia del jugador, y el volcado es lo que nos dira que lo causa.
# Tres pasos, en este orden: contar que pasa, intentar seguir, y solo si no hay manera, salir.
func _desatascar() -> void:
	# Se apunta ANTES del volcado: asi el propio informe muestra cuantas veces se ha pulsado P y
	# cuando, que ya dice mucho (si hay cinco P seguidas, lo que se intento no funciono).
	_traza_add("--- el jugador pulsa P ---")
	var lineas: Array = _diagnostico()
	_volcado_p()   # el informe LARGO va al log del juego (%APPDATA%/DungeonOratoria/logs/godot.log)
	# El log de combate es de una linea: se pinta el resumen y el detalle queda en la consola.
	_set_log("🔧 %s" % " · ".join(lineas))

	# ESPEJO: esta pantalla no simula nada, solo pinta la pelea de otra maquina. Tocarle el estado
	# no arregla nada (el atasco esta al otro lado) y ademas desincronizaria lo que se ve. Con el
	# volcado basta: dice si el anfitrion esta esperando a alguien, que es lo que hay que saber.
	if _espejo:
		_set_log("🔧 La pelea la lleva otra máquina: que pulse P quien la tenga. %s" % " · ".join(lineas))
		return

	# --- Intento 1: soltar la espera de un turno remoto que no va a llegar.
	if _state == State.WAITING_PLAYER and _esperando_a != 0:
		if not Net.esta_en_mi_pelea(_esperando_a):
			var quien: int = _esperando_a
			_fin_de_espera()
			sacar_a(quien)
			_set_log("🔧 %d ya no está en la pelea: fuera. La pelea sigue." % quien)
			return
		# Sigue conectado: se le repite la peticion ya, sin esperar al heartbeat.
		_espera_acum = 0.0
		_traza_add("REENVIO A MANO (P) #%d '%s' al peer %d" % [
			int(_peticion_pendiente.get("seq", 0)),
			String(_peticion_pendiente.get("tipo", "?")), _esperando_a])
		_enviar_peticion()
		_set_log("🔧 Le repito la petición a %d. Si no contesta, vuelve a pulsar P." % _esperando_a)
		return

	# --- Intento 2: estado raro (esperando a nadie, o una pausa de lectura que no baja).
	# Se devuelve el mando a quien le toque y se reanuda el ATB.
	if _state != State.ADVANCING:
		_fin_de_espera()
		_pause_left = 0.0
		if _player != null and _player.is_alive() and not _huidos.has(_player):
			# ¿DE QUIEN ES EL QUE TIENE EL TURNO? Esto no se miraba, y era el tercer camino por el que
			# se perdian turnos: si _player es el personaje de OTRO humano, pintarme aqui SUS botones
			# es jugar yo por el, y el _fin_de_espera() de arriba acababa de tirar la peticion que el
			# heartbeat estaba reenviando. O sea que el dueño se quedaba sin turno para siempre y
			# encima su personaje hacia lo que yo eligiera. Lo correcto es volver a pedirselo a el.
			var dueno_p: int = int(_dueno_aliado.get(_player, 0))
			if dueno_p != 0:
				_state = State.WAITING_PLAYER
				if not Net.esta_en_mi_pelea(dueno_p):
					sacar_a(dueno_p)
					_set_log("🔧 %s ya no está en la pelea: fuera. La pelea sigue." % dueno_p)
					return
				_ocultar_cajas()
				_pedir_a_remoto(dueno_p, {"tipo": "accion", "idx": _aliados.find(_player)})
				_set_log("🔧 El turno es de %s, que lo lleva otro jugador: se lo vuelvo a pedir."
					% _player.nombre)
				return
			_state = State.WAITING_PLAYER
			_mostrar_acciones()
			_set_log("🔧 Turno devuelto a %s. Elige una acción." % _player.nombre)
		else:
			_state = State.ADVANCING
			_set_log("🔧 Reanudado el contador de turnos.")
		return

	# --- Intento 3: dice que avanza pero nadie llega al umbral (barras a cero / todas paradas).
	# Se empuja al que mas tenga hasta el umbral para forzar el siguiente turno.
	var mejor: Combatant = null
	for c in _aliados_vivos() + _vivos():
		if mejor == null or _gauge.get(c, 0.0) > _gauge.get(mejor, 0.0):
			mejor = c
	if mejor != null:
		_gauge[mejor] = UMBRAL
		_set_log("🔧 Empujo el turno de %s." % mejor.nombre)
		return

	# --- Sin nadie a quien darle el turno: la pelea no se puede salvar. Salir como huida
	# conserva la partida (el mundo vuelve, los bichos se sueltan) en vez de dejar el juego muerto.
	_set_log("🔧 No queda nadie a quien darle el turno: salgo del combate.")
	_end(false, true)


# Todo lo que hace falta para entender un cuelgue, en lineas cortas.
func _diagnostico() -> Array:
	var nombres := ["ADVANCING", "WAITING_PLAYER", "PAUSED", "FINISHED"]
	var out: Array = []
	out.append("estado=%s" % (nombres[_state] if _state < nombres.size() else str(_state)))
	out.append("espejo=%s" % ("SI" if _espejo else "no"))
	if _state == State.PAUSED:
		out.append("pausa_lectura=%.1fs" % _pause_left)
	if _esperando_a != 0:
		out.append("esperando a peer %d (%s) desde %.1fs, ¿sigue?=%s" % [
			_esperando_a, String(_peticion_pendiente.get("tipo", "?")), _espera_acum,
			"si" if Net.esta_en_mi_pelea(_esperando_a) else "NO"])
	else:
		out.append("no espero a nadie")
	out.append("turno de=%s" % (_player.nombre if _player != null else "nadie"))
	# Las barras: si todas estan lejos del umbral, el ATB esta parado; si alguna lo pasa y aun asi
	# no actua, el atasco esta en la resolucion del turno, no en el contador.
	var barras: Array = []
	for c in _aliados_vivos():
		barras.append("%s %.0f" % [c.nombre, _gauge.get(c, 0.0)])
	for e in _vivos():
		barras.append("%s %.0f" % [e.nombre, _gauge.get(e, 0.0)])
	out.append("barras(/%d): %s" % [int(UMBRAL), ", ".join(barras)])
	out.append("vivos: %d tuyos / %d bichos, huidos %d" % [
		_aliados_vivos().size(), _vivos().size(), _huidos.size()])
	# Un submenu abierto NO es un cuelgue: es que hay algo esperando a que elijas.
	if _ability_box != null and _ability_box.visible:
		out.append("OJO: menu de habilidades abierto (elige o pulsa atras)")
	if _actions_box != null and not _actions_box.visible and _state == State.WAITING_PLAYER:
		out.append("OJO: submenu abierto sin caja de acciones")
	return out


# EL INFORME LARGO DE LA TECLA P. Va entero al log del juego, que se guarda solo en
#   %APPDATA%\DungeonOratoria\logs\godot.log
# (file_logging esta activado en project.godot), asi que despues de una partida se puede mandar ese
# fichero y leer aqui que paso de verdad.
#
# Un turno colgado en red no se reproduce a voluntad: depende de quien tarde en elegir y de que
# paquete se cruce con cual. Por eso lo importante no es la foto del momento sino la TRAZA: la lista
# de peticiones, reenvios, respuestas y descartes con sus tiempos. Ahi se ve, por ejemplo, si a
# alguien se le pidio el turno y nunca contesto, o si contesto a una peticion que ya no era la buena.
func _volcado_p() -> void:
	var nombres := ["ADVANCING", "WAITING_PLAYER", "PAUSED", "FINISHED"]
	var L: Array[String] = []
	L.append("============ VOLCADO DE COMBATE (tecla P) ============")
	L.append("cuando: %s  ·  version del juego: %s" % [
		Time.get_datetime_string_from_system(false, true), str(Game.VERSION)])

	# --- QUIEN SOY EN ESTA PELEA
	L.append("--- YO ---")
	L.append("  esta pantalla: %s" % ("ESPEJO (la pelea la lleva otra maquina)" if _espejo
		else "ANFITRION DE LA PELEA (la simulo yo)"))
	L.append("  red activa: %s · soy host de red: %s · mundo compartido: %s" % [
		str(Net.activo), str(Net.es_host), str(Net.mundo_compartido)])
	if Net.activo and Net.multiplayer.multiplayer_peer != null:
		L.append("  mi peer id: %d" % Net.multiplayer.get_unique_id())
	L.append("  mi identidad: %s (%s)" % [Identidad.nombre, Identidad.id])

	# --- LA PELEA A OJOS DE LA CAPA DE RED
	L.append("--- LA PELEA (segun Net) ---")
	for campo in ["_pelea_id", "_pelea_anfitrion", "_pelea_sigo"]:
		L.append("  %s = %s" % [campo, str(Net.get(campo))])
	var parts = Net.get("_pelea_participantes")
	L.append("  participantes: %s" % str(parts))

	# --- EL ESTADO DEL MOTOR
	L.append("--- ESTADO ---")
	L.append("  state = %s" % (nombres[_state] if _state < nombres.size() else str(_state)))
	L.append("  pausa de lectura pendiente: %.2fs" % _pause_left)
	L.append("  revision del roster: %d (pedida: %s)" % [_rev, str(_rev_pedida)])
	L.append("  numero de peticion actual: %d" % _pet_seq)
	if _espejo:
		L.append("  [espejo] me han pedido la #%d y ya conteste hasta la #%d" % [
			_seq_espejo, _seq_contestada])
	if _esperando_a != 0:
		L.append("  ESPERANDO al peer %d desde hace %.2fs" % [_esperando_a, _espera_acum])
		L.append("    lo que le pedi: %s" % str(_peticion_pendiente))
		L.append("    ¿sigue en la pelea?: %s" % ("si" if Net.esta_en_mi_pelea(_esperando_a) else "NO"))
		L.append("    proximo reenvio en: %.2fs" % maxf(0.0, REENVIO_TURNO - _espera_acum))
	else:
		L.append("  no espero respuesta de nadie")
		# Esta pareja es LA firma del cuelgue: parado esperando a alguien... a quien ya no se espera.
		if _state == State.WAITING_PLAYER:
			L.append("  >>> SOSPECHOSO: estado WAITING_PLAYER pero sin nadie a quien esperar.")
			L.append("  >>> Con esta pareja el heartbeat no reenvia nada y la pelea no avanza sola.")

	# --- DE QUIEN ES EL TURNO
	L.append("--- TURNO ---")
	if _player == null:
		L.append("  no hay nadie con el turno (_player = null)")
	else:
		var d: int = int(_dueno_aliado.get(_player, 0))
		L.append("  lo tiene: %s (indice %d)" % [_player.nombre, _aliados.find(_player)])
		L.append("  su dueño: %s" % ("YO (local)" if d == 0 else "el peer %d" % d))
		L.append("  vivo: %s · ha huido: %s" % [str(_player.is_alive()), str(_huidos.has(_player))])
	if _cast_spell != null:
		L.append("  recitando: %s, frase %d de %d" % [
			_cast_spell.nombre, _cast_index + 1, _cast_spell.longitud()])

	# --- LOS COMBATIENTES
	L.append("--- LOS TUYOS (barra / %d para actuar) ---" % int(UMBRAL))
	for i in _aliados.size():
		var c: Combatant = _aliados[i]
		var d2: int = int(_dueno_aliado.get(c, 0))
		L.append("  [%d] %-14s barra %6.1f  HP %7.2f/%7.2f  EN %6.1f  MP %6.1f  dueño=%s%s%s" % [
			i, c.nombre, _gauge.get(c, 0.0), c.current_hp, c.max_hp, c.current_energy,
			c.current_mp, ("local" if d2 == 0 else "peer %d" % d2),
			"" if c.is_alive() else "  [MUERTO]", "  [HUIDO]" if _huidos.has(c) else ""])
	L.append("--- LOS BICHOS ---")
	for i in _enemies.size():
		var e: Combatant = _enemies[i]
		L.append("  [%d] %-14s barra %6.1f  HP %7.2f/%7.2f%s%s" % [
			i, e.nombre, _gauge.get(e, 0.0), e.current_hp, e.max_hp,
			"" if e.is_alive() else "  [MUERTO]", "  [INVOCADO]" if _slots_invocados.has(i) else ""])

	# --- QUE HAY EN PANTALLA (un submenu abierto no es un cuelgue: es que esperan que elijas)
	L.append("--- PANTALLA ---")
	L.append("  acciones=%s  habilidades=%s  magia=%s  objetos=%s  recitado=%s  continuar=%s" % [
		_vis(_actions_box), _vis(_ability_box), _vis(_spell_box), _vis(_objeto_box),
		_vis(_cast_box), _vis(_continue_button)])

	# --- LA TRAZA: esto es lo que de verdad explica el cuelgue
	L.append("--- TRAZA DE TURNOS (lo ultimo primero abajo; %d apuntes) ---" % _traza.size())
	if _traza.is_empty():
		L.append("  (vacia: en esta pelea no ha habido trafico de turnos por red)")
	for t in _traza:
		L.append("  " + t)
	L.append("--- ULTIMAS LINEAS DEL COMBATE ---")
	for l in _log_lines:
		L.append("  " + l)
	L.append("======================================================")

	for l in L:
		print(l)


func _vis(n: Node) -> String:
	if n == null:
		return "(no existe)"
	return "SI" if bool(n.get("visible")) else "no"


# [dev] Cura al jugador del combate a tope (vida + mana + energia) y refresca las barras.
func _dev_heal_full() -> void:
	_player.current_hp = _player.max_hp
	if _player.max_mp > 0.0:
		_player.current_mp = _player.max_mp
	if _player.max_energy > 0.0:
		_player.current_energy = _player.max_energy
	_update_hp()
	_set_log("[dev] Curación total: vida/maná/energía al 100%")


# [dev] Cambia el arma (principal si main=true, si no la secundaria) usando el ciclador
# de Game y REAPLICA el loadout al combatiente en curso (sin perder vida/mana/energia).
# Solo con combatientes reales inyectados por Game (no en el modo prueba F6).
func _dev_swap_weapon(main: bool) -> void:
	if not _injected:
		return
	if main:
		Game._dev_cycle_weapon()
	else:
		Game._dev_cycle_off()
	Game._aplicar_loadout(_player)
	_update_hp()
	var oname := "—"
	if Game.equipped_off is WeaponData:
		oname = (Game.equipped_off as WeaponData).nombre + " (dual)"
	elif Game.equipped_off is WandData:
		oname = (Game.equipped_off as WandData).nombre + " (varita)"
	elif Game.equipped_off is ShieldData:
		oname = (Game.equipped_off as ShieldData).nombre
	var mano: String = "principal" if main else "secundaria"
	var mname: String = Game.equipped_main.nombre if Game.equipped_main != null else "— (sin arma)"
	_set_log("[dev] Cambiada %s → %s + %s" % [mano, mname, oname])


func _process(delta: float) -> void:
	# ESPEJO: acercar las barras a su objetivo ANTES de pintar, para que la linea de tiempo salga
	# suave y no a escalones de 20 Hz.
	if _espejo:
		_interpolar_atb_espejo(delta)
	_update_timeline()  # refleja el orden de turnos siempre
	# ESPEJO (hito 5.4-C): esta pantalla no SIMULA nada, solo pinta la pelea que lleva otra
	# maquina. Ni ATB, ni turnos, ni resolucion: todo eso llega por instantaneas.
	if _espejo:
		return
	_difundir_atb(delta)
	_heartbeat_remoto(delta)   # que un turno de otro no pueda quedarse colgado para siempre
	# Pausa de lectura tras la accion del enemigo: cuenta atras y reanuda el ATB.
	if _state == State.PAUSED:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_state = State.ADVANCING
		return
	if _state != State.ADVANCING:
		return

	# CADA aliado llena SU barra con SU velocidad: el grupo no actua a la vez, se van alternando
	# segun quien sea mas rapido (por eso meter a alguien agil cambia el ritmo de la pelea).
	# Al CASTEAR (KAN-95) se llena a la velocidad de casteo (la varita del mago hibrido la cambia
	# respecto al arma principal); si no, la velocidad normal. Y quien entro agotado va a medio
	# ritmo sus primeras acciones.
	for c in _aliados_vivos():
		var casteando: bool = _casteos.has(c)
		var rate: float = SPEED_SCALE
		# El SOBREPESO es de cada uno (ver Combatant.overload_factor): en multi, el que va cargado va
		# lento EL, no todo el grupo.
		#
		# Y NO frena el RECITADO, por lo mismo que no lo frena la armadura (ver loadout_mods): no
		# hablas mas despacio por ir cargado. Antes se colaba igual, porque el factor multiplicaba el
		# 'rate' de la barra ANTES de mirar si estabas casteando, asi que la exencion de la armadura
		# estaba hecha y la del peso no. Al mago cargado se le frenaba el conjuro sin que nada en la
		# ficha lo dijera (Vel. recitado nunca ha llevado el sobrepeso dentro).
		if not casteando:
			rate *= c.overload_factor
		# El AGOTAMIENTO si frena las dos cosas, y es a proposito: eso no es lo que cargas, es como
		# estas tu. Recitar sin aliento cuesta tanto como blandir sin aliento.
		if int(_lentas.get(c, 0)) > 0:
			rate *= EXHAUSTED_RATE
		var cspeed: float = c.cast_spd() if casteando else c.spd()
		_gauge[c] += cspeed * delta * rate
	for e in _vivos():
		_gauge[e] += e.spd() * delta * SPEED_SCALE

	# Actua el que tenga la barra MAS llena por encima del umbral. Se arranca por los TUYOS y se
	# compara con > estricto, asi los empates caen de tu lado (es lo mismo que hacia el
	# "if _gauge[_player] >= _gauge[_enemy]" del 1v1: el desempate no cambia de manos).
	var mejor: Combatant = null
	for c in _aliados_vivos():
		if mejor == null or _gauge[c] > _gauge[mejor]:
			mejor = c
	if mejor == null:
		return   # no queda nadie de los tuyos: el combate ya se esta cerrando
	for e in _vivos():
		if _gauge[e] > _gauge[mejor]:
			mejor = e
	if _gauge[mejor] >= UMBRAL:
		_gauge[mejor] -= UMBRAL
		if _aliados.has(mejor):
			_player = mejor   # a partir de aqui, "el jugador" es este
			_begin_player_turn()
		else:
			_enemy_turn(mejor)


func _begin_player_turn() -> void:
	_state = State.WAITING_PLAYER
	if _dps_on:
		_turnos_jugador += 1
	_player_defending = false  # la guardia solo dura hasta tu proximo turno
	_player.salir_de_guardia() # la postura de contraataque tambien dura hasta tu proxima accion
	_player.tick_cooldowns()   # habilidades (KAN-57): baja 1 turno los cooldowns activos
	# Provocacion (escudo): dura N turnos SUYOS. Baja 1 al empezar su turno (entre medias, los
	# enemigos ya la han "sentido" al elegir objetivo). Al llegar a 0 deja de atraer golpes.
	if _player.provocar_turnos > 0:
		_player.provocar_turnos -= 1
	# La IMBUICION ya NO baja aqui: dura ATAQUES, no turnos. Ver _gastar_imbue().
	# Estados alterados (KAN-58): tick al inicio del turno (DoT, expira, aturdido).
	var ev: Dictionary = _player.tick_statuses()
	_log_tick(_player, ev)
	_update_hp()
	if not _player.is_alive():
		_set_log("%s cae por el daño de sus estados. ☠" % _player.nombre)
		_caer_aliado(_player)   # el DoT (veneno...) puede tumbarlo
		if derrota():
			_end(false)
		else:
			_pausa_lectura()
		return
	# AUTORREGENERACION (habilidad de desarrollo): cura un % de tu vida MAXIMA al empezar tu
	# turno. Va DESPUES del DoT (el veneno te pega igual, esto solo lo compensa un poco) pero
	# ANTES del corte por aturdido: es pasiva, y un turno perdido no la apaga. El rango es el de
	# SU ficha: cada uno tiene sus desarrollos.
	var autoreg: float = Game.factor_desarrollo("autorregeneracion", Game.pj_de_combatant(_player))
	if autoreg > 0.0:
		var antes: float = _player.current_hp
		_player.heal(_player.max_hp * AUTORREGEN_PCT * autoreg)
		var curado: float = _player.current_hp - antes
		if curado > 0.0:
			_set_log("%s se regenera (+%.1f). ♻" % [_player.nombre, curado])
			_update_hp()
	if ev.stunned:
		# Aturdirte mientras CARGAS te interrumpe, igual que a los bichos (ver el mismo bloque en
		# _enemy_turn). La energia no se devuelve: el riesgo de comerte un aturdido es justo el precio
		# de una habilidad que se telegrafia.
		if _player.charging != null:
			var interrumpida: String = _player.charging.nombre
			_player.charging = null
			_player.charge_left = 0
			print("[habilidad] %s ATURDIDO: se le INTERRUMPE %s" % [_player.nombre, interrumpida])
			_set_log("%s está aturdido: se le interrumpe %s. 💫" % [_player.nombre, interrumpida])
		else:
			_set_log("%s está aturdido y pierde el turno. 💫" % _player.nombre)
		_pausa_lectura()
		return

	# ATAQUE DE CARGA en curso: este turno se va en seguir cargando; al llegar a 0, se suelta.
	# Espejo exacto del bloque de _enemy_turn. Va ANTES de mirar el recitado de hechizos y de sacar
	# los botones: mientras cargas no eliges nada, que es lo que hace que la carga se pague.
	if _player.charging != null:
		_player.charge_left -= 1
		if _player.charge_left > 0:
			_set_log("%s sigue cargando %s... ⚡" % [_player.nombre, _player.charging.nombre])
			_ocultar_cajas()
			_pausa_lectura()
			return
		var cargada: AbilityData = _player.charging
		_player.charging = null
		# 'soltando': ni cobra energia ni arranca cooldown otra vez, que se pagaron al empezarla.
		_usar_habilidad(cargada, true)
		return

	# Regen de maná POR TURNO: ya solo la del ARMA MAGICA (mejora Regeneración, KAN-95). La
	# base por Magia se quito: el maná se gana PEGANDO (_ganar_mana_golpe) y GANANDO, no por
	# dejar pasar turnos. Sin arma mágica, este turno no repone nada.
	if _player.mp_regen_turno > 0.0:
		_player.regen_mana(_player.mp_regen_turno * StatsMath.MP_REGEN_TURNO_MULT
			* _player.status_mp_regen_mult())
	_update_hp()
	# Si estas casteando un hechizo, el turno va al recitado / disparo, NO a las
	# acciones normales (por diseño no puedes hacer otra cosa mientras cantas).
	if _cast_spell != null:
		if _cast_index < _cast_spell.longitud():
			_mostrar_test(_cast_index)
		else:
			_mostrar_disparo()
	else:
		_pedir_accion_del_turno()


# Le da el turno a quien toca: los botones aqui si el personaje es de esta pantalla, y si no, se le
# piden a su dueño. Vive aparte porque hay DOS momentos que reparten turno: el turno normal y el
# volver atras de un conjuro cancelado (ver _cancelar_casteo), que devuelve la accion sin gastar nada.
#
# MULTI (hito 5.4-C): el ATB no corre mientras se espera (estamos en WAITING_PLAYER), asi que nadie
# pierde turnos por pensar.
func _pedir_accion_del_turno() -> void:
	var dueno: int = int(_dueno_aliado.get(_player, 0))
	if dueno != 0 and not Net.esta_en_mi_pelea(dueno):
		# Ya no esta en la pelea (se fue, o su pantalla dejo de espejarme): pedirle la accion
		# seria esperar para siempre. Sus personajes salen y la pelea sigue.
		sacar_a(dueno)
		return
	if dueno != 0:
		_ocultar_cajas()
		_set_log("Turno de %s. Esperando su acción..." % _player.nombre)
		_pedir_a_remoto(dueno, {"tipo": "accion", "idx": _aliados.find(_player)})
	else:
		_mostrar_acciones()


# Apila en el log los eventos del tick de estados: DoT sufrido (con iconos) y
# estados que se disipan. No hace nada si el turno no traia eventos.
func _log_tick(c: Combatant, ev: Dictionary) -> void:
	if float(ev.damage) > 0.0:
		_set_log("%s sufre %s (%.2f)." % [c.nombre, ", ".join(ev.dot), float(ev.damage)])
	if float(ev.get("heal", 0.0)) > 0.0:
		_set_log("%s se cura %s (%.2f). ✚" % [c.nombre, ", ".join(ev.get("heal_labels", [])), float(ev.heal)])
	if float(ev.get("mana", 0.0)) > 0.0:
		_set_log("%s recupera %.2f de maná. 🔷" % [c.nombre, float(ev.mana)])
	if not (ev.expired as Array).is_empty():
		_set_log("A %s se le disipa: %s." % [c.nombre, ", ".join(ev.expired)])


# Muestra la barra de acciones normales (Atacar/Magia/Defender/Huir).
func _mostrar_acciones() -> void:
	_ocultar_cajas()
	_actions_box.visible = true
	_refresh_actions()
	# Se nombra a QUIEN le toca: con tres bloques iguales, "tu turno" no dice de quien es la
	# accion que estas eligiendo (su bloque tambien lo marca con ▶).
	_set_log("¡Turno de %s! Elige una acción." % _player.nombre)


# Que hace cada accion. El coste de Defender NO se escribe a mano: sale de la constante.
func _ayuda_accion(id: int) -> String:
	match id:
		Action.ATTACK:
			return "Golpe básico con lo que lleves en las manos. No cuesta energía: la RECUPERA, así que es lo que te permite volver a lanzar habilidades."
		Action.HABILIDAD:
			return "Técnicas que te dan tus armas. Cuestan energía y tienen enfriamiento."
		Action.MAGIC:
			return "Recitas un hechizo, frase a frase. Cuesta maná (se paga al empezar) y fallar una frase lo malogra: cuantas más frases, más potente y más te expones."
		Action.DEFEND:
			return "Te cubres: encajas mucho menos daño en el próximo golpe y entrenas Resistencia. Cuesta %.0f de energía." % DEFEND_ENERGY_COST
		Action.OBJETO:
			return "Una poción, para ti o para quien elijas del grupo. Empieza a curar en este mismo turno, pero el resto llega poco a poco: te toca aguantar mientras hace efecto."
		Action.FLEE:
			return "Abandonas el combate. Te llevas lo que ya tengas, pero el enemigo sigue vivo."
	return ""


# Habilita/inhabilita cada accion segun disponibilidad (en tu turno). Cada boton explica QUE
# HACE; si esta bloqueado, el motivo va DELANTE (y no en lugar de) la explicacion.
func _refresh_actions() -> void:
	for id in _action_buttons:
		var disponible: bool = _accion_disponible(id)
		_action_buttons[id].disabled = not disponible
		var ayuda: String = _ayuda_accion(id)
		var motivo: String = "" if disponible else _motivo_bloqueo(id)
		_action_buttons[id].tooltip_text = ayuda if motivo == "" else "⛔ %s\n\n%s" % [motivo, ayuda]


func _motivo_bloqueo(id: int) -> String:
	# El Silencio manda sobre el otro motivo: si estas silenciado, da igual que tengas hechizos.
	if _player != null and _player.silenciado() and (id == Action.MAGIC or id == Action.HABILIDAD):
		return "Estás silenciado"
	match id:
		Action.MAGIC: return "No tienes hechizos equipados"
		Action.DEFEND: return "Sin energía (ataca para regenerar)"
		Action.HABILIDAD: return "Tu equipo no aporta habilidades"
		Action.OBJETO: return "No tienes objetos"
	return ""


func _accion_disponible(id: int) -> bool:
	match id:
		Action.ATTACK: return true
		Action.DEFEND: return _player.has_energy(DEFEND_ENERGY_COST)   # Defender cuesta energia
		Action.FLEE: return true
		# El SILENCIO corta las dos jugadas, no el turno: te quedan atacar, Defender, objeto y huir.
		Action.MAGIC: return _hay_hechizos() and not _player.silenciado()
		Action.HABILIDAD: return not _player.abilities_combate.is_empty() and not _player.silenciado()
		Action.OBJETO: return Game.consumibles_total() > 0
	return false


# ¿El jugador tiene hechizos equipados? (KAN-56)
func _hay_hechizos() -> bool:
	return _player != null and _player.spells.size() > 0


# Oculta la barra tras elegir y consume una "accion lenta" si entraste agotado.
func _fin_de_eleccion() -> void:
	_ocultar_cajas()
	if _slow_actions_left > 0:
		_slow_actions_left -= 1
	# Los CHIPS se repintan aqui, al cerrar CUALQUIER accion, y no solo cuando cambia la vida.
	# Colgaban de _update_hp, asi que todo lo que no hace daño no los tocaba: echabas un Grito de
	# aliento (Fortaleza a todo el grupo) o un Filo emponzoñado y no aparecia nada, porque nadie
	# habia perdido un solo punto de vida. Este es el sitio por el que pasan TODAS las acciones.
	_update_hp()


# Despacha la accion elegida (solo en tu turno).
func _on_action(id: int) -> void:
	if _state != State.WAITING_PLAYER:
		return
	match id:
		Action.ATTACK: _accion_atacar()
		Action.DEFEND: _accion_defender()
		Action.FLEE: _accion_huir()
		Action.MAGIC: _accion_magia()
		Action.HABILIDAD: _accion_habilidad()
		Action.OBJETO: _accion_objeto()


# El boton reutilizado (antes "Atacar") cierra la pantalla al terminar el combate.
func _on_continue_pressed() -> void:
	if _state != State.FINISHED:
		return
	# EN UN ESPEJO NO SE REPARTE NADA. Esta pantalla no simula la pelea: solo la pinta, y sus
	# combatientes son maniquies que traen lo que se ve y nada mas. Todo lo de abajo (arrastrar el
	# goteo de las pociones, tirar por las pasivas slayer de cada bicho abatido, decir con cuanta
	# vida sale cada uno) lo resuelve el ANFITRION, que es quien lleva la pelea. Ejecutarlo aqui
	# seria repartir premios dos veces y sobre datos que no son. Lo unico que hace el espejo al
	# pulsar Continuar es cerrar su pantalla; el fin de verdad llega por Net (_fin_espejo).
	if _espejo:
		_ocultar_cajas()
		_set_log("Esperando a que termine quien lleva la pelea...")
		_continue_button.disabled = true
		return
	# Si sobrevives, la cura/maná de poción que quedaba a medias se arrastra a fuera de
	# combate (no se malgasta). Si caiste, no hay nada que arrastrar. (KAN-57)
	# CADA superviviente arrastra la SUYA a su ficha: la cola de goteo del mapa es por persona.
	for c in _aliados_vivos():
		var pj_c: PersonajeData = Game.pj_de_combatant(c)
		if pj_c == null:
			continue   # combatiente de prueba (F6): no tiene ficha a la que arrastrar nada
		Game.arrastrar_regen(c.regen_pendiente(), pj_c, c.regen_turnos_pendientes())
		Game.arrastrar_regen_mana(c.regen_mana_pendiente(), pj_c, c.regen_mana_turnos_pendientes())
	# Quien cayo y con cuanta vida se queda cada superviviente (huir no los cura: te vuelves a
	# encontrar al mismo bicho herido que dejaste).
	var muertos: Array = []
	var hp_left: Array = []
	var estados_left: Array = []
	for i in _enemies.size():
		var e_muerto: bool = not _enemies[i].is_alive()
		# Los INVOCADOS (Rey Slime) van SIEMPRE como muertos: no tienen nodo en la mazmorra, asi que
		# no dejan cadaver que reanimar. Ademas, si el slot reutiliza el hueco de un enemigo real que
		# cayo, forzarlo a muerto evita que Game reanime al original (con la vida del invocado) al huir.
		if e_muerto or _slots_invocados.has(i):
			muertos.append(i)
		# Pasiva RNG slayer: cada bicho ABATIDO de verdad tira por su slayer de familia (ultra-raro).
		if e_muerto:
			Game.rodar_slayer_por_familia(int(_enemies[i].familia),
				_ultimo_en_golpear.get(_enemies[i]))
		hp_left.append(_enemies[i].current_hp)
		estados_left.append(StatusEffects.estados_que_salen(_enemies[i].statuses))
	# Como sale cada uno de los tuyos, por indice (el mismo orden que llego a setup()).
	var mi_hp: Array = []
	var mi_mp: Array = []
	var mi_en: Array = []
	# De qué HUMANO es cada aliado (0 = el anfitrion), paralelo a mi_hp. Con esto Game reparte la
	# muerte POR HUMANO: cada uno cuyo grupo entero cayo vuelve al pueblo con su castigo.
	var mi_duenos: Array = []
	for c in _aliados:
		# La vida que sale de la pelea tiene que estar en su escala DE VERDAD. Si alguien termina con
		# la Guardia de carne puesta, su max_hp y su vida estan al doble (ver Combatant), y volcarlos
		# asi le regalaba vida o se la recortaba el clamp del siguiente combate.
		c.deshacer_escalados_hp()
		mi_hp.append(c.current_hp)
		mi_mp.append(c.current_mp)
		mi_en.append(c.current_energy)
		mi_duenos.append(int(_dueno_aliado.get(c, 0)))
	combat_finished.emit(_player_won, mi_hp, mi_mp, mi_en, muertos, hp_left, mi_duenos, estados_left)
	# Si lo abrio Game, el cierra la capa; si es prueba (F6), nos cerramos solos.
	if not _injected:
		queue_free()


# ============================================================
#  MAGIA (KAN-56): submenu de hechizos + recitado por frases + disparo
# ------------------------------------------------------------
# Accion Magia: abre el submenu con los hechizos equipados y su coste de mana.
func _accion_magia() -> void:
	_ocultar_cajas()
	# Reconstruimos el submenu cada vez (el mana cambia -> disponibilidad).
	for c in _spell_box.get_children():
		c.queue_free()
	# Ordenados por coste de mana EFECTIVO descendente (los mas caros arriba).
	var spells_ord: Array = _player.spells.duplicate()
	spells_ord.sort_custom(func(a, b): return _coste_efectivo(a) > _coste_efectivo(b))
	var grid := _rejilla_submenu(_spell_box)
	for spell in spells_ord:
		var b := TooltipButton.new()
		var coste: float = _coste_efectivo(spell)
		# A media anchura no cabe el numero de frases; va en el tooltip (descripcion_mecanica).
		b.text = "%s  (%.2f MP)" % [spell.nombre, coste]
		# Tooltip: datos DERIVADOS de los campos (resumen) + el sabor de la descripcion.
		# Igual que las habilidades (ver _accion_habilidad): la magia lo tenia todo escrito
		# en SpellData.resumen() y no lo enseñaba nadie.
		# Con el daño REAL entre parentesis: en combate es justo lo que decide si este hechizo
		# remata al bicho que tienes delante o no.
		b.tooltip_text = spell.descripcion_mecanica(spell.dano_mostrado() * Game.poder_magico())
		if spell.descripcion != "":
			b.tooltip_text += "\n\n" + spell.descripcion
		# El motivo del bloqueo va DELANTE del resumen, no en su lugar: si no te llega el
		# maná es justo cuando quieres mirar lo que hace el hechizo.
		if not _player.has_mana(coste):
			b.disabled = true
			b.tooltip_text = "⛔ Maná insuficiente\n\n%s" % b.tooltip_text
		elif spell.imbue_tipo == 1 and _con_arma_vivos().is_empty():
			# Imbuir el ARMA sin llevar arma no tiene sentido: no hay filo que teñir. Las de
			# CUERPO si valen a manos vacias (te imbuyes tu, no el acero).
			# Se mira a TODO el grupo, no a Game.equipped_main (el arma del LIDER): el filo se lo
			# puedes echar a un compañero, asi que solo estorba si NADIE lleva arma.
			b.disabled = true
			b.tooltip_text = "⛔ Nadie del grupo lleva arma que imbuir\n\n%s" % b.tooltip_text
		# Los que caen sobre un ALIADO preguntan antes a quien; el resto van directos al enemigo.
		if _va_a_aliado(spell):
			b.pressed.connect(_elegir_objetivo_aliado.bind(spell))
		else:
			b.pressed.connect(_elegir_hechizo.bind(spell))
		_celda_submenu(b)
		grid.add_child(b)
	_cerrar_submenu(_spell_box, spells_ord.size(), _mostrar_acciones)
	_ocultar_log()   # el submenu ocupa el sitio del historial


# ¿Este hechizo cae sobre uno de LOS TUYOS? Los Filos y Mantos (imbuicion) y los BUFF puros
# (Fortaleza). Los de ataque y los DEBUFF van al enemigo y no preguntan nada.
func _va_a_aliado(spell: SpellData) -> bool:
	return spell != null and (spell.imbue_tipo > 0 or spell.tipo == SpellData.TipoEfecto.BUFF)


# Los tuyos en pie que llevan ARMA. Solo importa para los FILOS: un filo tiñe el acero, y a quien
# va con las manos vacias no hay nada que teñirle.
func _con_arma_vivos() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in _aliados_vivos():
		var pj: PersonajeData = Game.pj_de_combatant(c)
		if pj != null and pj.equipped_main != null:
			out.append(c)
	return out


# Segundo paso del submenu de magia: A QUIEN se lo echas. Mismo patron que las pociones
# (_elegir_objetivo_objeto): con un solo candidato no se pregunta, va directo.
func _elegir_objetivo_aliado(spell: SpellData) -> void:
	var candidatos: Array[Combatant] = _con_arma_vivos() if spell.imbue_tipo == 1 else _aliados_vivos()
	if candidatos.size() <= 1:
		_elegir_hechizo(spell, candidatos[0] if not candidatos.is_empty() else _player)
		return
	for c in _spell_box.get_children():
		c.queue_free()
	var grid := _rejilla_submenu(_spell_box)
	for al in candidatos:
		var b := TooltipButton.new()
		var actual: String = al.imbue_etiqueta()
		b.text = "%s%s" % [al.nombre, "   (%s)" % actual if actual != "" else ""]
		b.tooltip_text = "%s le echa %s a %s.%s" % [_player.nombre, spell.nombre, al.nombre,
			"\n\nOJO: ya lleva una imbuición puesta y la nueva la sustituye." if actual != "" else ""]
		b.pressed.connect(_elegir_hechizo.bind(spell, al))
		_celda_submenu(b)
		grid.add_child(b)
	_cerrar_submenu(_spell_box, candidatos.size(), _accion_magia)
	_ocultar_log()


# Coste de maná EFECTIVO tras la mejora Eficiencia del equipo (KAN-95). FLOAT (sin
# redondeo hacia arriba: así CUALQUIER % de Eficiencia se nota). Mínimo 0.5.
func _coste_efectivo(spell: SpellData) -> float:
	return maxf(0.5, float(spell.coste_mana) * (1.0 - _player.mana_reduccion)
		* _player.status_mana_coste_mult())


# Empiezas a castear: se COMPRUEBA que te llega el mana, pero NO se cobra todavia, y recitas la
# primera frase en este MISMO turno.
#
# El cobro se hace al SOLTAR el hechizo (_disparar_hechizo) o al FALLAR una frase (_backfire).
# Antes se cobraba aqui, antes de la primera frase, y eso te quitaba el mana por la cara cuando el
# conjuro se caia por algo que no era culpa tuya: si mataban al ultimo enemigo mientras recitabas, o
# si te tumbaban a ti, el mana se habia ido igual. Fallar SI sigue costandolo: eso si es tuyo.
# 'aliado' = a quien va, para los que caen sobre los tuyos (null = al que lanza).
func _elegir_hechizo(spell: SpellData, aliado: Combatant = null) -> void:
	# ESPEJO: aqui solo se ELIGE. El conjuro entero (mana, frases y disparo) lo lleva el anfitrion;
	# lo que se enruta despues, turno a turno, son las frases (ver _mostrar_test). El destinatario
	# viaja como INDICE en _aliados, igual que ya hacia la pocion.
	if _espejo and spell != null:
		_responder_al_anfitrion({"tipo": "magia", "ruta": spell.resource_path,
			"aliado": _aliados.find(aliado) if aliado != null else -1})
		return
	if not _player.has_mana(_coste_efectivo(spell)):
		return
	_cast_spell = spell
	_cast_index = 0
	_cast_aliado = aliado if aliado != null else _player
	_mostrar_test(0)


# Muestra el test tipo examen para la frase idx del hechizo en curso.
func _mostrar_test(idx: int) -> void:
	var correcta: String = _cast_spell.frases[idx]
	var opciones := SpellBook.opciones_test(correcta, _otras_frases_equipadas(), N_OPCIONES_TEST)
	# MULTI: si el que recita es el personaje de OTRO, el examen se le pone a EL. Las opciones se
	# sortean aqui (soy quien lleva la pelea) y el responde con el TEXTO que eligio; quien decide
	# si acerto sigo siendo yo, asi que la validacion no se va de esta maquina.
	var dueno: int = int(_dueno_aliado.get(_player, 0))
	if dueno != 0:
		_ocultar_cajas()
		_set_log("🔮 %s recita %s (%d/%d). Esperando..." % [
			_player.nombre, _cast_spell.nombre, idx + 1, _cast_spell.longitud()])
		_pedir_a_remoto(dueno, {"tipo": "frase", "idx": idx, "opciones": opciones,
			"nombre": _cast_spell.nombre, "largo": _cast_spell.longitud()})
		return
	_pintar_test(idx, opciones, _cast_spell.nombre, _cast_spell.longitud(), correcta)


# Pinta el examen de UNA frase. Vale igual para la pantalla que lleva la pelea y para un espejo al
# que se lo han pedido: la unica diferencia es que en el espejo no se sabe cual es la correcta (la
# valida el anfitrion), asi que se le pasa "".
func _pintar_test(idx: int, opciones: Array, nombre: String, largo: int, correcta: String) -> void:
	_ocultar_cajas()
	for c in _cast_box.get_children():
		c.queue_free()
	# En REJILLA, como los hechizos y las habilidades, y del mismo alto que ellos: cuadradas y
	# pegadas unas a otras. Una por fila dejaba cuatro tiras largas y bajas que no se parecian a
	# nada de lo demas. DOS columnas y no tres (COLUMNAS_ACCION): aqui dentro va una FRASE entera,
	# no el nombre corto de un hechizo.
	_cast_box.add_theme_constant_override("separation", 12)
	# ...y a UNA si a dos no cabe la frase mas larga: una opcion recortada no se puede leer, y sin
	# poder leerla la eliges a ciegas y te comes el backfire (ver SpellBook.columnas_para_frases).
	var cols: int = SpellBook.columnas_para_frases(opciones, _panel_acciones.size.x,
		_cast_box.get_theme_default_font(), 17, COLUMNAS_FRASES)
	var grid := _rejilla_submenu(_cast_box, cols)
	var letras := ["a", "b", "c", "d", "e", "f"]
	for i in opciones.size():
		var b := Button.new()
		b.text = "%s)  %s" % [letras[i], opciones[i]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, ALTO_BOTON_ACCION)
		b.add_theme_font_size_override("font_size", 17)
		b.clip_text = true
		b.pressed.connect(_responder_frase.bind(String(opciones[i]), correcta))
		grid.add_child(b)
	var filas: int = ceili(opciones.size() / float(cols))
	var alto: float = filas * ALTO_BOTON_ACCION + (filas - 1) * 10.0
	# ECHARSE ATRAS: solo en la PRIMERA frase. En cuanto has recitado una ya no se puede (el conjuro
	# esta en marcha), asi que el boton ni se pinta. Y aqui no se pierde nada: el maná se cobra al
	# soltar el hechizo o al fallar, nunca al empezar (ver _elegir_hechizo).
	if idx == 0:
		var volver := Button.new()
		volver.text = "◄ Volver (aún no has recitado nada)"
		volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volver.custom_minimum_size = Vector2(0, ALTO_BOTON_VOLVER)
		volver.add_theme_font_size_override("font_size", 18)
		volver.pressed.connect(_cancelar_casteo)
		_cast_box.add_child(volver)
		alto += 12.0 + ALTO_BOTON_VOLVER
	_alto_panel(alto)
	_cast_box.visible = true
	_set_log("🔮 %s — recita la frase %d/%d:" % [nombre, idx + 1, largo])
	_ocultar_log()   # las frases ocupan el sitio del historial


# ESPEJO: me toca recitar una frase de MI personaje. El examen lo ha sorteado el anfitrion.
func recitar_frase(idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0) -> void:
	if not _espejo:
		return
	if seq != 0 and seq == _seq_contestada:
		_traza_add("me repiten la frase #%d, que YA conteste: la ignoro" % seq)
		return
	if seq != 0:
		_seq_espejo = seq
	# Repeticion del anfitrion: si ya tengo el examen delante, no se re-sortea (ver turno_mio).
	if _state == State.WAITING_PLAYER and _cast_box != null and _cast_box.visible:
		return
	_traza_add("ME PIDEN LA FRASE %d (#%d) de %s" % [idx + 1, seq, nombre])
	_state = State.WAITING_PLAYER
	_pintar_test(idx, opciones, nombre, largo, "")


# Frases de los OTROS hechizos equipados (para nutrir los distractores del test).
func _otras_frases_equipadas() -> Array:
	var pool: Array = []
	for spell in _player.spells:
		if spell != _cast_spell:
			for f in spell.frases:
				pool.append(f)
	return pool


# Responde una frase del test: acierto -> avanza; fallo -> backfire.
func _responder_frase(elegida: String, correcta: String) -> void:
	if _state != State.WAITING_PLAYER:
		return
	# ESPEJO: no se si he acertado (la frase correcta no viaja: la comprueba el anfitrion).
	if _espejo:
		_responder_al_anfitrion({"tipo": "frase", "texto": elegida})
		return
	if elegida == correcta:
		# La Magia NO se entrena por frase (solo al LANZAR, en _disparar_hechizo), para
		# que la ganancia sea predecible y no se cuente doble.
		_cast_index += 1
		Game.contar_frase_recitada(Game.pj_de_combatant(_player))   # oculto de Encantamiento rapido
		if _cast_index < _cast_spell.longitud():
			_set_log("✓ Frase correcta. Continua el proximo turno...")
		else:
			_set_log("✓ ¡Encantamiento completo! El proximo turno lo lanzas.")
		_player.regen_energy(ATTACK_ENERGY_REGEN)   # recitar es un turno basico: regenera energia (KAN-57)
		# Repinta el bloque: sin esto el chip del conjuro (ver _chips_de) se quedaba una frase
		# atrasado, porque los chips solo se rehacen desde aqui.
		_update_hp()
		_fin_de_eleccion()
		_state = State.ADVANCING
	else:
		_backfire()


# ECHARSE ATRAS con el conjuro recien elegido, ANTES de recitar la primera frase. No cuesta maná (se
# cobra al soltarlo o al fallar, ver _elegir_hechizo) y NO gasta el turno: te devuelve al submenu de
# magia, por si el hechizo que has tocado no era el que querias.
#
# Con una frase ya recitada esto no se puede llamar: el boton solo se pinta con idx == 0
# (_pintar_test), y aun asi el anfitrion lo vuelve a comprobar antes de aplicarlo.
func _cancelar_casteo() -> void:
	if _state != State.WAITING_PLAYER:
		return
	# ESPEJO: la decision es mia, pero el conjuro lo lleva el anfitrion. Se ocultan las cajas ANTES de
	# contestar: el menu de acciones que me devolvera viene por el mismo camino que una repeticion, y
	# los guardias de turno_mio / recitar_frase lo descartarian si aun tuviera los botones delante.
	if _espejo:
		_ocultar_cajas()
		_set_log("Cancelando el conjuro...")
		_responder_al_anfitrion({"tipo": "cancelar"})
		return
	if _cast_spell == null or _cast_index > 0:
		return
	_limpiar_casteo()
	_update_hp()   # se va el chip 🔮 del bloque: los chips solo se rehacen desde aqui
	_accion_magia()


# Turno de DISPARO: un unico boton para lanzar el hechizo ya recitado.
func _mostrar_disparo() -> void:
	# MULTI: el conjuro es de otro -> el boton va en SU pantalla (y alli puede reapuntar antes de
	# soltarlo, que para eso tiene los mismos bloques clicables).
	var dueno: int = int(_dueno_aliado.get(_player, 0))
	if dueno != 0:
		_ocultar_cajas()
		_set_log("%s tiene el conjuro listo. Esperando..." % _player.nombre)
		_pedir_a_remoto(dueno, {"tipo": "disparo", "nombre": _cast_spell.nombre})
		return
	_pintar_disparo(_cast_spell.nombre)


func _pintar_disparo(nombre: String) -> void:
	_ocultar_cajas()
	for c in _cast_box.get_children():
		c.queue_free()
	var b := Button.new()
	b.text = "🔥 ¡Lanzar %s!" % nombre
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, ALTO_BOTON_ACCION)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(_disparar_hechizo)
	_cast_box.add_child(b)
	_alto_panel(ALTO_BOTON_ACCION)
	_cast_box.visible = true
	_set_log("El conjuro está listo. ¡Lánzalo!")
	_ocultar_log()   # el boton de disparo ocupa el sitio del historial


# ESPEJO: mi conjuro esta listo, el boton de lanzarlo va aqui.
func lanzar_conjuro(nombre: String, seq: int = 0) -> void:
	if not _espejo:
		return
	if seq != 0 and seq == _seq_contestada:
		_traza_add("me repiten el disparo #%d, que YA conteste: lo ignoro" % seq)
		return
	if seq != 0:
		_seq_espejo = seq
	if _state == State.WAITING_PLAYER and _cast_box != null and _cast_box.visible:
		return   # repeticion del anfitrion: ya tengo el boton delante
	_traza_add("ME PIDEN EL DISPARO (#%d) de %s" % [seq, nombre])
	_state = State.WAITING_PLAYER
	_pintar_disparo(nombre)


func _disparar_hechizo() -> void:
	if _state != State.WAITING_PLAYER:
		return
	# ESPEJO: el objetivo viaja como indice; lo resuelve el anfitrion con el conjuro que ya tiene
	# recitado en la ficha del doble.
	if _espejo:
		_responder_al_anfitrion({"tipo": "disparar", "obj": _target_idx})
		return
	var spell := _cast_spell
	# AQUI se paga el hechizo (ver _elegir_hechizo): al soltarlo, no al empezar a recitarlo. Se
	# vuelve a comprobar porque entre la eleccion y este momento han pasado turnos y el mana puede
	# haber bajado (otro conjuro, un drenaje futuro). Si no llega, el conjuro se disipa sin daño y
	# sin cobrar: no se puede lanzar lo que no se puede pagar.
	var coste: float = _coste_efectivo(spell)
	if not _player.has_mana(coste):
		_set_log("%s se queda sin maná y el conjuro se le deshace. 💨" % _player.nombre)
		_limpiar_casteo()
		_update_hp()
		_fin_de_eleccion()
		_tras_accion_jugador_varios([])
		return
	_player.spend_mana(coste)
	# Objetivo PRINCIPAL, capturado una vez, como en el resto de acciones (ver _usar_habilidad).
	# El area y los rebotes salen de el; y el sigue siendo el que cuenta para la Excelia y el DPS.
	var obj: Combatant = _objetivo()
	var tocados: Array = _resolver_hechizo(spell, obj)
	_player.regen_energy(ATTACK_ENERGY_REGEN)   # lanzar es un turno basico: regenera energia (KAN-57)
	_limpiar_casteo()
	_update_hp()
	_fin_de_eleccion()
	# Un hechizo de area puede tumbar a varios de golpe: hay que rematarlos a TODOS. El
	# principal va en la lista aunque el hechizo no sea de area (es el primero del area).
	_tras_accion_jugador_varios(tocados if not tocados.is_empty() else [obj])


# TODO lo que HACE un hechizo ya soltado: daño (area, dispersion, rebotes), estados, imbuicion,
# log y excelia. Devuelve los enemigos TOCADOS, para rematarlos de una vez.
#
# Esta aparte porque hay DOS sitios que sueltan un hechizo: el turno de disparo de toda la vida
# (_disparar_hechizo) y el conjuro con el que ABRES la pelea desde el mapa (hechizo_de_entrada).
# Lo que va fuera —cobrar el maná, gastar el turno, la energia— es de cada uno; esto es lo comun.
#
# OJO: da por hecho que _player ES QUIEN LANZA. Todo lo de dentro (resolve_spell, el contador de
# Cazador, el log, la excelia) tira de _player, y por eso quien llame desde fuera de un turno tiene
# que dejarlo puesto (lo hace hechizo_de_entrada).
func _resolver_hechizo(spell: SpellData, obj: Combatant) -> Array:
	# Todos los enemigos tocados (area + rebotes): hay que rematarlos AL FINAL, de una vez.
	var tocados: Array = []
	# DAÑO solo para hechizos de ATAQUE (los de BUFF/DEBUFF no pegan, solo aplican estado).
	var dano: float = 0.0
	if spell.tipo == SpellData.TipoEfecto.ATAQUE:
		# Foco arcano (Canalización): gasta 1 carga y amplifica el daño del hechizo. Solo
		# los OFENSIVOS gastan carga; el largo la gasta AL DISPARAR (respeta el canto). Se
		# consume UNA vez y multiplica TODOS los golpes (los del area y los de los rebotes).
		var foco: float = _player.consumir_foco()
		# 1) AREA: el principal y a quien salpique, cada uno con su multiplicador.
		#    DISPERSA (Tormenta, Andanada): los golpes no van al objetivo fijo, sino repartidos
		#    a vivos al azar; cada bola aplica ahi el alcance del hechizo. Ver _resolver_dispersa.
		var res_area: Array = []
		if spell.dispersa:
			res_area = _resolver_dispersa(spell, foco)
			for r in res_area:
				tocados.append(r.c)
		else:
			for t in _objetivos_area(spell, obj):
				res_area.append(_resolver_golpes_hechizo(spell, t.c, foco, float(t.escala)))
				tocados.append(t.c)
		# 2) REBOTES: DESPUES del area, cada uno a un vivo al azar. _vivos() se recalcula en
		# CADA rebote, asi que la cadena nunca cae sobre un cadaver (ni sobre el que acaba de
		# tumbar el rebote anterior).
		var res_reb: Array = []
		for i in spell.rebotes_n():
			var vivos: Array[Combatant] = _vivos()
			if vivos.is_empty():
				break   # no queda nadie a quien saltar: la cadena se apaga
			var victima: Combatant = vivos.pick_random()
			res_reb.append(_resolver_golpes_hechizo(spell, victima, foco, spell.dano_rebote,
				spell.rebote_estados))
			tocados.append(victima)
		dano = _log_hechizo(spell, res_area, res_reb, foco)
		_dps_add("Hechizo: %s" % spell.nombre, dano)   # una entrada por lanzamiento, agregada
	else:
		_set_log("✨ %s lanza %s." % [_player.nombre, spell.nombre])
		# Los estados de un hechizo sin daño (buff/debuff) se aplican aqui: no hay golpes que
		# los lleven. Los de ATAQUE ya los ha tirado cada golpe con SU elemento.
		_aplicar_estado_hechizo(spell)
	# IMBUICION (KAN-58): el hechizo no pega, tiñe tus GOLPES DE ARMA con su elemento.
	if spell.imbue_tipo > 0:
		_aplicar_imbuicion(spell)
	# Excelia (formula dedicada de Magia): entrena al LANZAR, escalado por el mana
	# gastado (hechizos caros = mas potentes = entrenan mas) x reto del enemigo.
	var mana_factor: float = float(spell.coste_mana) / Game.MAGIA_COSTE_REF
	# Reto por-stat (contra TU magia, no tu poder total): asi un cuerpo fuerte con magia baja SI
	# entrena la magia contra bichos de su piso, en vez de quedarse clavado a 0 (ver Game.reto_stat).
	var pj_lanza: PersonajeData = Game.pj_de_combatant(_player)   # entrena EL QUE LANZA
	Game.ganar("magia", Game.reto_stat(_poder_enemigo(obj), "magia", obj.level, pj_lanza),
		Game.GAIN_MAGIA_CAST * mana_factor, Game.RETO_MAX_FISICO, pj_lanza)
	Game.contar_hechizo(pj_lanza)   # contador oculto de Erudito
	print("[magia] %s lanza %s | dano:%.2f (Magia %d) | def. magica de %s: %.2f" % [
		_player.nombre, spell.nombre, dano, _player.abilities.magia, obj.nombre,
		StatsMath.magic_value(obj.abilities, obj.level, obj.base_magic)])
	return tocados


# EL CANTO QUE TE INTERRUMPIERON. Estabas recitando en el mapa y esta misma pelea te ha caido
# encima: el conjuro NO se pierde, se sigue aqui por la frase que llevabas.
#
# No hace falta ni una linea de turnos nueva: los conjuros a medias ya viven en _casteos (es de
# donde tira el espejo para restaurar el canto de otro, ver aplicar_roster), y en cuanto esta ahi
# puesto, _player_turn le saca a ese aliado el examen de SU frase en vez de las acciones normales.
#
# El maná sigue sin cobrarse hasta soltarlo, asi que la cuenta cuadra sola: te interrumpen, no pagas.
func retomar_canto(spell: SpellData, idx_frase: int, idx_lanzador: int) -> void:
	if spell == null or _espejo:
		return
	if idx_lanzador < 0 or idx_lanzador >= _aliados.size():
		return
	var quien: Combatant = _aliados[idx_lanzador]
	var frase: int = clampi(idx_frase, 0, maxi(0, spell.longitud() - 1))
	_casteos[quien] = {"spell": spell, "idx": frase}
	_set_log("🔮 %s sigue recitando %s (frase %d/%d)." % [
		quien.nombre, spell.nombre, frase + 1, spell.longitud()])
	_update_hp()   # repinta el chip del conjuro en su bloque


# EL CONJURO CON EL QUE ABRES LA PELEA. Lo has recitado en el mapa (casteo_mapa.gd), ha impactado, y
# la pelea se ha abierto por el camino de siempre: aqui se cobra el hechizo, contra el bicho al que
# le diste y ANTES del primer turno. No gasta turno ni energia — el turno no ha empezado.
#
# 'idx_enemigo' es el indice del bicho DENTRO de la pelea (el nodo del mapa no significa nada aqui) y
# 'idx_lanzador' el del que lo canto dentro del grupo. Lo llama Game._soltar_hechizo_de_entrada por
# los DOS caminos de entrada: el que abre la pelea y el que se une a una ya abierta.
func hechizo_de_entrada(spell: SpellData, idx_enemigo: int, idx_lanzador: int) -> void:
	if spell == null or _espejo:
		return
	if idx_enemigo < 0 or idx_enemigo >= _enemies.size():
		return
	if idx_lanzador < 0 or idx_lanzador >= _aliados.size():
		return
	var obj: Combatant = _enemies[idx_enemigo]
	if not obj.is_alive():
		return
	_target_idx = idx_enemigo   # al que le diste es el objetivo principal, tambien para el turno 1
	# _resolver_hechizo va por _player para TODO (daño, log, excelia, contadores). Fuera de un turno,
	# _player es quien la pantalla tenga puesto, que no tiene por que ser el que canto: se le presta
	# el sitio al lanzador y se devuelve. Es eso o pasarle el lanzador a media docena de funciones.
	var previo: Combatant = _player
	_player = _aliados[idx_lanzador]
	_set_log("✨ %s abre la pelea con %s." % [_player.nombre, spell.nombre])
	var tocados: Array = _resolver_hechizo(spell, obj)
	_player = previo
	_update_hp()
	# Si el conjuro se los ha llevado a todos, esto cierra la pelea con victoria (y su loot y su
	# excelia): matar de entrada es un desenlace legitimo, no un caso raro que haya que evitar.
	_tras_accion_jugador_varios(tocados if not tocados.is_empty() else [obj])


# IMBUICION (KAN-58): tiñe tus golpes de arma con el elemento del hechizo.
#   ARMA   -> solo el bonus de daño elemental.
#   CUERPO -> ademas te da la AFINIDAD: resistes/eres debil a lo que diga la tabla, y te
#             vuelves INMUNE a los estados de ese elemento (imbuido en agua no te queman).
func _aplicar_imbuicion(spell: SpellData) -> void:
	var cuerpo: bool = spell.imbue_tipo == 2
	# Al DESTINATARIO elegido (ver _elegir_objetivo_aliado), que puede no ser el que lanza.
	var quien: Combatant = _cast_aliado
	quien.aplicar_imbue(spell.elemento, spell.imbue_pct, spell.imbue_usos, cuerpo,
		spell.imbue_estado, spell.imbue_prob, spell.imbue_intensidad)
	var elem: String = Elementos.nombre(spell.elemento)
	var usos_txt: String = "%d carga%s" % [spell.imbue_usos, "" if spell.imbue_usos == 1 else "s"]
	print("[imbuicion] %s imbuye %s de %s a %s: +%d%% de daño %s durante %s" % [
		_player.nombre, ("el CUERPO" if cuerpo else "el ARMA"), elem, quien.nombre,
		roundi(spell.imbue_pct * 100.0), elem, usos_txt])
	var de_quien: String = "tu" if quien == _player else ("el %s de" % ("cuerpo" if cuerpo else "arma"))
	var msg: String = ("✨ Imbuyes tu %s de %s: +%d%% de daño de %s (%s)." % [
		("cuerpo" if cuerpo else "arma"), elem, roundi(spell.imbue_pct * 100.0), elem, usos_txt]
		) if quien == _player else ("✨ Imbuyes %s %s de %s: +%d%% de daño de %s (%s)." % [
		de_quien, quien.nombre, elem, roundi(spell.imbue_pct * 100.0), elem, usos_txt])
	if cuerpo:
		# Lo que ganas y lo que pierdes, DERIVADO del estado REAL del jugador (ya lleva la
		# afinidad puesta con su FRANJA de intensidad). Nada hardcodeado: si tocas la tabla o
		# la intensidad, este texto se actualiza solo y dice el % de verdad.
		var resiste: Array = []
		var debil: Array = []
		for e in Elementos.PERFIL_DEFECTO.get(spell.elemento, {}):
			var m: float = Elementos.mult_recibido(e, quien)
			# En positivo y sin restas mentales: "20% de resistencia" / "+20% de daño".
			if m < 0.99:
				resiste.append("%s (%d%%)" % [Elementos.nombre(e), roundi((1.0 - m) * 100.0)])
			elif m > 1.01:
				debil.append("%s (+%d%%)" % [Elementos.nombre(e), roundi((m - 1.0) * 100.0)])
		if not resiste.is_empty():
			msg += "  🛡 Resistes: %s." % ", ".join(resiste)
		var inm: Array = []
		for id in Elementos.inmunidades_de(spell.elemento):
			inm.append(str(StatusEffects.def(id).get("nombre", "?")))
		if not inm.is_empty():
			msg += "  Inmune a: %s." % ", ".join(inm)
		if not debil.is_empty():
			msg += "  ⚠ Débil a: %s." % ", ".join(debil)
		print("[imbuicion] afinidad %s (intensidad %.2f) -> resiste %s | inmune %s | debil a %s" % [
			elem, spell.imbue_intensidad, resiste, inm, debil])
	_set_log(msg)


# Resuelve TODOS los golpes de un hechizo de ATAQUE contra UN objetivo. NO escribe en el log:
# devuelve lo ocurrido y ya lo cuenta _log_hechizo, que es quien ve el hechizo entero (con
# area y rebotes, una linea por golpe no cabria ni de lejos en el log).
# Cada golpe elige SU elemento (aleatorio si el hechizo trae reparto), pega, y tira SUS
# estados. El orden es el que hace bonito el multi-elemento: los estados de un golpe se
# aplican DESPUES de su daño, asi que un golpe nunca se amplifica a si mismo... pero la
# lluvia que moja SI amplifica (x1.5) los rayos que caigan DETRAS.
#   escala       -> multiplicador de daño de ESTE objetivo (1.5 al principal de Brasa, 0.75 al
#                   salpicon...). Modula 'frac', y como resolve_spell es LINEAL en el ataque,
#                   escalar aqui es exactamente lo mismo que escalar el dano_base solo para el.
#   tira_estados -> false en los rebotes (ver SpellData.rebote_estados).
# Devuelve {c, dano, mult, golpes, trail, estados}.
func _resolver_golpes_hechizo(spell: SpellData, objetivo: Combatant, foco: float,
		escala: float = 1.0, tira_estados: bool = true) -> Dictionary:
	var n: int = spell.golpes()
	var frac: float = escala / float(n)
	var multi: bool = n > 1
	var total: float = 0.0
	var trail: Array = []
	# Estados ya contados en el log, FRESCO por objetivo: si se compartiera entre los enemigos
	# del area, solo se anunciaria el estado del primero y los demas entrarian en silencio.
	var anunciados: Dictionary = {}
	var aplicados: Array = []   # estados que ENTRAN, para que el log los pliegue en una linea
	var ultimo_mult: float = 1.0
	var hubo_crit: bool = false
	for i in n:
		if not objetivo.is_alive():
			break   # ya ha caido: los golpes que quedaban se pierden
		var elem: int = spell.elemento_de_golpe()
		var res: Dictionary = StatsMath.resolve_spell(_player, objetivo, spell, elem, frac)
		var dmg: float = float(res.damage) * foco
		var mult: float = float(res.get("mult_elem", 1.0))
		ultimo_mult = mult
		if bool(res.get("crit", false)):
			hubo_crit = true
		objetivo.take_damage(dmg)
		_apuntar_dano(objetivo, dmg, _player)   # contador oculto de Cazador
		total += dmg
		# CRITICO MAGICO: mismo 💥 que en el rastro del golpe fisico, para que se lea igual.
		trail.append("%s%s%.1f%s" % [Elementos.icono(elem),
			"💥" if bool(res.get("crit", false)) else "", dmg, _mult_sufijo(mult)])
		print("[magia] %s golpe %d/%d %s sobre %s: %.2f (x%.2f)%s" % [
			spell.nombre, i + 1, n, Elementos.nombre(elem), objetivo.nombre, dmg, mult,
			"  CRITICO 💥" if bool(res.get("crit", false)) else ""])
		# Este golpe GASTA lo que lo amplificaba (el rayo evapora el Mojado): el x1.5 se cobra
		# una vez y hay que volver a mojar. Va DESPUES del daño (este golpe si lo cobra).
		_gastar_amplificadores(objetivo, elem)
		# Estados de ESTE golpe (solo los que pidan su elemento). Van DESPUES de su daño.
		if tira_estados:
			# En multi-objetivo el log lo escribe _log_hechizo de una sentada: aqui callamos.
			_aplicar_estado_hechizo(spell, objetivo, elem, not multi, anunciados,
				spell.es_multiobjetivo(), aplicados)
	return {
		"c": objetivo, "dano": total, "mult": ultimo_mult, "crit": hubo_crit,
		"golpes": trail.size(), "trail": trail, "estados": aplicados,
	}


# DISPERSION (Tormenta, Andanada ignea): cada uno de los 'hits' es una BOLA que cae en un vivo
# al AZAR. Se recalculan los vivos POR BOLA, asi ninguna cae sobre un cadaver. Al reves que los
# rebotes, SI tira estados. Agrega POR objetivo y devuelve el array con la forma que consume
# _log_hechizo (una entrada {c, dano, mult, golpes, trail, estados} por enemigo tocado).
#
# SALPICON por elemento: cada bola tira UN elemento (la bola entera es esa gota o ese rayo). Solo
# las del ELEMENTO DE IDENTIDAD del hechizo (spell.elemento) salpican a los adyacentes: en la
# Tormenta el rayo arquea a los lados y la lluvia cae suelta; en la Andanada todo es fuego = todo
# salpica. En 1v1 no hay adyacentes, asi que el salpicon no cambia nada: solo mejora el multi.
func _resolver_dispersa(spell: SpellData, foco: float) -> Array:
	var n: int = spell.golpes()
	var acc: Dictionary = {}     # Combatant -> {c, dano, mult, golpes, trail, estados}
	var anun: Dictionary = {}    # Combatant -> estados ya anunciados (no repetir en el log)
	var orden: Array = []        # orden de aparicion, para un log estable
	for i in n:
		var vivos: Array[Combatant] = _vivos()
		if vivos.is_empty():
			break   # no queda nadie: los golpes que faltaban se pierden
		var principal: Combatant = vivos.pick_random()
		var elem: int = spell.elemento_de_golpe()   # UN elemento para toda la bola
		# ¿Esta bola salpica? Solo los golpes del elemento de identidad, y solo si hay salpicon.
		var objetivos: Array
		if spell.salpica() and elem == spell.elemento:
			objetivos = _objetivos_area(spell, principal)
		else:
			objetivos = [{"c": principal, "escala": spell.dano_objetivo}]
		# El dano_base se reparte entre las N bolas: escala/N.
		for t in objetivos:
			var obj: Combatant = t.c
			if not obj.is_alive():
				continue
			var res: Dictionary = StatsMath.resolve_spell(_player, obj, spell, elem, float(t.escala) / float(n))
			var dmg: float = float(res.damage) * foco
			var mult: float = float(res.get("mult_elem", 1.0))
			obj.take_damage(dmg)
			_apuntar_dano(obj, dmg, _player)   # contador oculto de Cazador
			if not acc.has(obj):
				acc[obj] = {"c": obj, "dano": 0.0, "mult": 1.0, "crit": false, "golpes": 0, "trail": [], "estados": []}
				anun[obj] = {}
				orden.append(obj)
			var a: Dictionary = acc[obj]
			a.dano = float(a.dano) + dmg
			a.mult = mult
			if bool(res.get("crit", false)):
				a.crit = true
			a.golpes = int(a.golpes) + 1
			a.trail.append("%s%s%.1f%s" % [Elementos.icono(elem),
				"💥" if bool(res.get("crit", false)) else "", dmg, _mult_sufijo(mult)])
			print("[magia] %s bola %d/%d %s sobre %s: %.2f (x%.2f)%s" % [
				spell.nombre, i + 1, n, Elementos.nombre(elem), obj.nombre, dmg, mult,
				"  CRITICO 💥" if bool(res.get("crit", false)) else ""])
			# La lluvia que moja amplifica (x1.5) los rayos que caigan DETRAS: el golpe gasta lo
			# que lo amplificaba, igual que en la ruta normal.
			_gastar_amplificadores(obj, elem)
			# Estados de ESTE golpe (solo los de su elemento). Multi-objetivo: el log lo pliega
			# _log_hechizo de una sentada, aqui solo se acumulan los que ENTRAN.
			_aplicar_estado_hechizo(spell, obj, elem, false, anun[obj], true, a.estados)
	var out: Array = []
	for obj in orden:
		out.append(acc[obj])
	return out


# CUENTA en el log un hechizo ya resuelto y devuelve el daño TOTAL.
#   res_area -> resultados de la fase de area (el principal SIEMPRE el primero).
#   res_reb  -> resultados de los rebotes, en orden.
# El log solo guarda LOG_MAX lineas, y una Descarga sobre 4 enemigos son 18 impactos: en
# multi-objetivo se cuenta UNA LINEA POR FASE (area / rebotes / estados / total), nunca una
# por golpe. El rastro golpe a golpe se ve en la consola.
func _log_hechizo(spell: SpellData, res_area: Array, res_reb: Array, foco: float) -> float:
	var total: float = 0.0
	for r in res_area + res_reb:
		total += float(r.dano)
	var foco_txt: String = "  🔮Foco arcano +%d%% (quedan %d)" % [
		roundi(Combatant.FOCO_BONUS * 100.0), _player.foco_cargas] if foco > 1.0 else ""

	# MONO-OBJETIVO: el formato de siempre, intacto (Tormenta, Bola de Fuego...).
	if not spell.es_multiobjetivo():
		var r0: Dictionary = res_area[0]
		if spell.es_multigolpe():
			_set_log("🌩 %s descarga %d golpes sobre %s: %s" % [
				spell.nombre, int(r0.golpes), _etq(r0.c), " · ".join(r0.trail)])
			_set_log("… %.2f de daño en total.%s" % [total, foco_txt])
		else:
			# El 💥 del critico: en los multigolpe ya iba dentro del rastro, pero un hechizo de UN
			# golpe no pinta rastro y el critico no se veia por ningun lado — solo intuias que habia
			# pasado algo porque el numero salia mas gordo de lo normal.
			_set_log("🔥 %s impacta a %s por %.2f de daño.%s%s%s" % [
				spell.nombre, _etq(r0.c), total,
				"  ¡CRITICO! 💥" if bool(r0.get("crit", false)) else "",
				_elem_txt(float(r0.mult)), foco_txt])
		return total

	# MULTI-OBJETIVO: "Nombre (daño)" por enemigo, en una linea.
	var partes: Array = []
	for r in res_area:
		# El 💥 por objetivo: en un area, uno puede comerse el critico y los demas no.
		partes.append("%s (%s%.1f%s)" % [_etq(r.c), "💥" if bool(r.get("crit", false)) else "",
			float(r.dano), _mult_sufijo(float(r.mult))])
	_set_log("%s %s alcanza a %s" % [Elementos.icono(spell.elemento), spell.nombre, ", ".join(partes)])
	if not res_reb.is_empty():
		var reb: Array = []
		for r in res_reb:
			# Los repetidos se listan tal cual: que se vea cuando la cadena insiste en el mismo.
			reb.append("%s (%.1f%s)" % [_etq(r.c), float(r.dano), _mult_sufijo(float(r.mult))])
		_set_log("↯ Rebota ×%d: %s" % [reb.size(), ", ".join(reb)])
	# Estados PLEGADOS: una linea por estado con todos los que lo cogieron, no una por enemigo.
	var por_estado: Dictionary = {}
	for r in res_area + res_reb:
		for id in r.estados:
			if not por_estado.has(id):
				por_estado[id] = []
			if not por_estado[id].has(_etq(r.c)):
				por_estado[id].append(_etq(r.c))
	for id in por_estado:
		_set_log("✨ %s: %s" % [
			String(StatusEffects.def(int(id)).get("nombre", "?")), ", ".join(por_estado[id])])
	_set_log("… %.2f de daño en total.%s" % [total, foco_txt])
	return total


# Desglose de una habilidad MULTI-GOLPE en dos lineas, COMPARTIDO por tus habilidades y las del
# enemigo (el problema -"6 golpes, 0 de daño" no dice nada- y la solucion son los mismos).
#   titulo    -> lo que va antes de los golpes en la linea 1 ("Rafaga → 2. Slime", "2. Rata usa Frenesi").
#   rastro    -> [{t: token, c: Combatant}] en orden de golpe; token = "4.21" / "falla" / "💥9.80".
#   tocados   -> objetivos alcanzados (para el reparto y para saber si es multi-objetivo).
#   sin_dar   -> linea 2 a devolver si no conecto NINGUN golpe (el llamante la redacta: "le has"/"te ha").
#   sufijo    -> extra que se pega al final de la linea de daño (desglose de imbuicion del jugador; "" en el enemigo).
# Emite la LINEA 1 (el rastro) y DEVUELVE la LINEA 2, que el llamante remata con sus extras
# (estados, guardia, mana...) antes de mandarla al log. _etq() numera enemigos y deja pelados a los
# aliados, asi que la misma funcion etiqueta bien en los dos sentidos.
func _log_desglose(titulo: String, rastro: Array, tocados: Array, dano_por_obj: Dictionary,
		total: float, sin_dar: String, sufijo: String = "") -> String:
	var multi: bool = tocados.size() > 1
	var aciertos: int = 0
	var toks: Array = []
	for g in rastro:
		if String(g["t"]) != "falla":
			aciertos += 1
		toks.append("%s (%s)" % [g["t"], _etq(g["c"])] if multi else String(g["t"]))
	if not toks.is_empty():
		_set_log("⚔ %s:  %s" % [titulo, " · ".join(toks)])
	if total <= 0.0:
		return sin_dar
	if multi:
		var partes: Array = []
		for c in tocados:
			partes.append("%s (%.2f)" % [_etq(c), float(dano_por_obj.get(c, 0.0))])
		return "… %.2f de daño: %s%s" % [total, ", ".join(partes), sufijo]
	return "… %.2f de daño (%d de %d golpes).%s" % [total, aciertos, rastro.size(), sufijo]


# Un golpe de 'elem' gasta los estados que lo amplificaban (Rayo sobre Mojado). Solo se
# anuncia en la consola: en el log del combate seria una linea por golpe.
func _gastar_amplificadores(objetivo: Combatant, elem: int) -> void:
	if elem == Elementos.Elemento.NINGUNO:
		return
	for nom in objetivo.consumir_amplificadores(elem):
		print("[estado] el golpe de %s GASTA el %s de %s (el x1.5 no se repite)" % [
			Elementos.nombre(elem), nom, _etq(objetivo)])


# Feedback elemental de UN golpe, compacto, para el rastro del log ("⚡4.1×1.5").
func _mult_sufijo(mult: float) -> String:
	if mult > 1.01 or mult < 0.99:
		return "×%.1f" % mult
	return ""


# DESGLOSE de un daño ya hecho: cuanto fue fisico y cuanto lo puso la IMBUICION ("" si no hay
# imbuicion). El daño elemental va DENTRO del total, no encima: por eso se resta en vez de
# sumarse. Ej con un total de 38.16:  "(27.29 físico + 💧10.87 de Agua ×1.5)".
func _desglose_imbue(total: float, dmg_imbue: float, mult_imbue: float) -> String:
	if dmg_imbue <= 0.0:
		return ""
	return "  (%.2f físico + %s%.2f de %s%s)" % [
		maxf(0.0, total - dmg_imbue), Elementos.icono(_player.imbue_elemento), dmg_imbue,
		Elementos.nombre(_player.imbue_elemento), _mult_sufijo(mult_imbue)]


# Lo mismo para UN golpe suelto, a partir del result de resolve_attack.
# 'escala' = el dano_mult de la habilidad (escala el golpe entero, y con el la porcion).
func _imbue_dmg_txt(result: Dictionary, escala: float = 1.0) -> String:
	return _desglose_imbue(float(result.damage) * escala,
		float(result.get("dmg_imbue", 0.0)) * escala,
		float(result.get("mult_imbue", 1.0)))


# Feedback elemental de un hechizo de UN solo golpe. OJO: GDScript no soporta %g.
func _elem_txt(mult: float) -> String:
	if mult > 1.01:
		return "  ¡DÉBIL! ×%.1f" % mult
	if mult < 0.99:
		return "  resiste ×%.1f" % mult
	return ""


# Gasta UN uso de la imbuicion. Lo llaman las acciones que ATACAN (basico y habilidades que
# pegan), NUNCA el paso del turno: asi recitar un conjuro largo, defenderte o beber no te funde
# el filo antes de haberlo usado. Se llama DESPUES de resolver el ataque (el golpe que la gasta
# tambien se beneficia de ella).
func _gastar_imbue() -> void:
	if _player.consumir_imbue():
		print("[imbuicion] Se agota la imbuición de %s (sin usos)." % _player.nombre)
		_set_log("Se agota tu imbuición. ✨")


# Aplica (o no) los estados del hechizo. Al ENEMIGO = con PROBABILIDAD (el enemigo puede
# resistir). A UNO MISMO (buff) = siempre.
#   elem_golpe >= 0 -> solo se tiran los efectos de ESE elemento (los que piden otro se
#                      saltan). Es lo que hace que la Tormenta moje con el agua y electrice
#                      con el rayo. < 0 = sin filtro (hechizos de buff/debuff, sin golpes).
#   verboso    -> false en multi-golpe: 20 tiradas fallidas serian 20 lineas de log. Los
#                 fallos se ven igual en la consola; en el log solo se anuncia lo que ENTRA.
#   anunciados -> estados ya nombrados en el log (no repetir "recibe Mojado" en cada golpe).
#   silencioso -> no toca el log NADA (ni inmunidades ni resistencias: van a la consola). Lo
#                 usa el multi-objetivo, donde el log lo escribe _log_hechizo de una sentada.
#   aplicados  -> se rellena con los estados que ENTRAN, para que el llamador los pliegue.
func _aplicar_estado_hechizo(spell: SpellData, objetivo_ataque: Combatant = null,
		elem_golpe: int = -1, verboso: bool = true, anunciados: Dictionary = {},
		silencioso: bool = false, aplicados: Array = []) -> void:
	var enemigo: Combatant = objetivo_ataque if objetivo_ataque != null else _objetivo()
	for a in spell.efectos:
		if a.estado < 0:
			continue
		# Filtro por elemento del golpe: elemento_req -1 = en todos los golpes.
		if elem_golpe >= 0 and int(a.elemento_req) >= 0 and int(a.elemento_req) != elem_golpe:
			continue
		var al_enemigo: bool = a.en_objetivo
		# Los buffs (en_objetivo = false) van al ALIADO ELEGIDO, que por defecto es el que lanza:
		# Fortaleza se la puedes echar al tanque, no solo a ti. Y con a_todo_el_grupo, a TODOS —
		# esta rama lo ignoraba, que es el mismo agujero que tenian las habilidades: las dos tienen
		# que contestar igual o un hechizo de grupo escrito mañana solo buffearia a uno.
		var destinos_h: Array = []
		if al_enemigo:
			destinos_h.append(enemigo)
		elif a.a_todo_el_grupo:
			for al_h in _aliados_vivos():
				destinos_h.append(al_h)
		else:
			destinos_h.append(_cast_aliado)
		var objetivo: Combatant = destinos_h[0]
		var nom: String = str(StatusEffects.def(a.estado).get("nombre", "?"))
		# Inmunidad elemental: si el objetivo no puede recibir el estado, avisar y no tirar.
		if objetivo.es_inmune(a.estado):   # incluye la inmunidad derivada de su AFINIDAD elemental
			if not anunciados.has(a.estado):
				anunciados[a.estado] = true
				if not silencioso:
					_set_log("… %s es INMUNE a %s." % [_etq(objetivo), nom])
				print("[estado] %s es INMUNE a %s" % [objetivo.nombre, nom])
			continue
		if al_enemigo:
			# La resistencia a estados del objetivo baja la probabilidad efectiva.
			var p: float = spell.efecto_prob(a) * (1.0 - objetivo.resist_estados())
			if a.estado == StatusEffects.Id.ATURDIDO:
				# El aturdir de un hechizo escala igual que el de un golpe fisico: x1.5 si el
				# objetivo esta ELECTRIZADO, x0.6 si su afinidad es Rayo. Sin esto, electrizar
				# con un golpe de rayo no serviria de nada para aturdir con los siguientes.
				p = clampf(p * objetivo.stun_taken_mult(), 0.0, StatsMath.ATURDIR_MAX)
			if randf() >= p:
				if verboso and not silencioso:   # en multi-golpe callamos los fallos: serian 20 lineas de ruido
					_set_log("… pero %s resiste el %s. (%.0f%%)" % [_etq(objetivo), nom, p * 100.0])
				print("[estado] %s RESISTE %s del hechizo (prob %.0f%%)" % [objetivo.nombre, nom, p * 100.0])
				continue
		for d_h in destinos_h:
			if d_h == null or not d_h.is_alive():
				continue
			d_h.apply_status(a.estado, a.turns, a.magnitud, 1, false, a.cap)
			print("[estado] %s recibe %s del hechizo %s (prob %.0f%%)" % [
				_etq(d_h), nom, spell.nombre, spell.efecto_prob(a) * 100.0])
		if not aplicados.has(int(a.estado)):
			aplicados.append(int(a.estado))
		if not anunciados.has(a.estado) and not silencioso:
			anunciados[a.estado] = true
			var a_quien: String = "todo el grupo" if destinos_h.size() > 1 else _etq(objetivo)
			_set_log("✨ %s: %s recibe %s." % [spell.nombre, a_quien, nom])


# Fallar una frase: el conjuro se descontrola. Daño propio (mayor cuanto mas avanzado ibas), el
# conjuro se interrumpe y AQUI se cobra el mana: el hechizo ya no se paga por adelantado (ver
# _elegir_hechizo), pero equivocarse de frase sigue costandolo. Es lo unico que se pierde por tu
# mano; que te lo tiren o que se acabe la pelea recitando ya no cobra nada.
func _backfire() -> void:
	var spell := _cast_spell
	_player.spend_mana(_coste_efectivo(spell))
	# Por TU VIDA MAXIMA, no por el daño del hechizo: asi fallar duele lo mismo el primer dia que
	# con 500 de vida (ver StatsMath.backfire_damage). Y puede tumbarte: el KO se resuelve abajo.
	var dmg := StatsMath.backfire_damage(spell, _cast_index, spell.longitud(), _player.max_hp)
	_player.take_damage(dmg)
	print("[magia] BACKFIRE %s | frase %d/%d | dano propio:%.2f" % [
		spell.nombre, _cast_index + 1, spell.longitud(), dmg])
	_set_log("💥 %s recita mal el conjuro y se descontrola: %.2f de daño. El hechizo se pierde."
		% [_player.nombre, dmg])
	_player.regen_energy(ATTACK_ENERGY_REGEN)   # aun fallando, es un turno sin gasto de energia (KAN-57)
	_limpiar_casteo()
	_update_hp()
	_fin_de_eleccion()
	if not _player.is_alive():
		_caer_aliado(_player)   # el conjuro descontrolado puede tumbar al que lo recitaba
		if derrota():
			_end(false)
			return
	_state = State.ADVANCING


func _limpiar_casteo() -> void:
	_cast_spell = null
	_cast_index = 0


# ============================================================
#  HABILIDADES (KAN-57): submenu del loadout + resolucion
# ------------------------------------------------------------
func _accion_habilidad() -> void:
	_ocultar_cajas()
	for c in _ability_box.get_children():
		c.queue_free()
	# Ordenadas por coste de energia DESCENDENTE (las mas caras arriba). El coste usa las
	# manos que aportan CADA habilidad (dual solo si ambas armas la traen).
	var abils: Array = _player.abilities_combate.duplicate()
	abils.sort_custom(func(a, b): return a.coste(_player.ability_manos(a)) > b.coste(_player.ability_manos(b)))
	var grid := _rejilla_submenu(_ability_box)
	for ab in abils:
		var manos: int = _player.ability_manos(ab)
		var es_conv: bool = ab.energia_a_mana > 0.0   # Canalizar: gasta toda la energia
		var coste: float = _player.current_energy if es_conv else ab.coste(manos)
		var cd_left: int = _player.ability_cd_left(ab)
		var b := TooltipButton.new()
		var cd_txt := "  ⏳%d" % cd_left if cd_left > 0 else ""
		var costo_txt := ("toda EN → %.1f MP" % (coste / ab.energia_a_mana)) if es_conv else ("%.0f EN" % coste)
		# A media anchura no cabe todo: en el boton van el nombre, el coste y el cooldown (que es
		# lo que decide si puedes pulsarlo AHORA), y las cargas de Foco se quedan para el tooltip.
		var foco_txt := "  🔮%d cargas" % ab.foco_cargas if ab.foco_cargas > 0 else ""
		b.text = "%s  (%s)%s" % [ab.nombre, costo_txt, cd_txt]
		# Tooltip: datos DERIVADos de los campos (resumen) + el sabor de la descripcion.
		b.tooltip_text = foco_txt.strip_edges() + "\n" + ab.resumen(manos) if foco_txt != "" else ab.resumen(manos)
		if ab.descripcion != "":
			b.tooltip_text += "\n\n" + ab.descripcion
		if cd_left > 0:
			b.disabled = true
			b.tooltip_text = "⛔ En cooldown: %d turno%s\n\n%s" % [cd_left, "" if cd_left == 1 else "s", b.tooltip_text]
		elif ab.foco_cargas > 0 and _player.foco_cargas > 0:
			b.disabled = true
			b.tooltip_text = "⛔ Aún te quedan %d cargas de Foco arcano: gástalas antes\n\n%s" % [_player.foco_cargas, b.tooltip_text]
		elif es_conv and _player.current_energy < ab.energia_a_mana:
			b.disabled = true
			b.tooltip_text = "⛔ Necesitas al menos %.0f EN\n\n%s" % [ab.energia_a_mana, b.tooltip_text]
		elif not es_conv and not _player.has_energy(coste):
			b.disabled = true
			b.tooltip_text = "⛔ Sin energía suficiente\n\n%s" % b.tooltip_text
		# Las que caen sobre un aliado preguntan A QUIEN antes de resolverse, igual que un Filo.
		if ab.objetivo_aliado == AbilityData.Objetivo.ALIADO:
			b.pressed.connect(_elegir_aliado_habilidad.bind(ab))
		else:
			b.pressed.connect(_usar_habilidad.bind(ab))
		_celda_submenu(b)
		grid.add_child(b)
	_cerrar_submenu(_ability_box, abils.size(), _mostrar_acciones)
	_ocultar_log()   # el submenu ocupa el sitio del historial


# Los OBJETIVOS de una habilidad de ÁREA: el principal SIEMPRE el primero, y detrás sus
# vecinos VIVOS más cercanos (alternando izquierda/derecha) hasta llenar area_max. Reusa la
# misma geometría que el salpicón de los hechizos: los cadáveres no cuentan ni desplazan la
# numeración (ver _adyacentes_vivos). area_max >= nº de vivos -> toca a todos.
func _objetivos_hab(ab: AbilityData, principal: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = [principal]
	if not ab.es_area() or ab.area_max <= 1:
		return out
	var centro: int = _enemies.find(principal)
	if centro < 0:
		return out
	# Punteros que se alejan del centro a cada lado; cogemos el primer vivo de cada tanda.
	var izq: int = centro - 1
	var der: int = centro + 1
	while out.size() < ab.area_max:
		var anadido := false
		# Izquierda: primer vivo hacia el borde.
		while izq >= 0:
			if _enemies[izq].is_alive():
				out.append(_enemies[izq]); izq -= 1; anadido = true
				break
			izq -= 1
		if out.size() >= ab.area_max:
			break
		# Derecha: primer vivo hacia el borde.
		while der < _enemies.size():
			if _enemies[der].is_alive():
				out.append(_enemies[der]); der += 1; anadido = true
				break
			der += 1
		if not anadido:
			break   # no quedan vivos a ningún lado
	return out


# El enemigo VIVO más cercano a 'muerto' (para redirigir los golpes que sobran de una flurry
# cuando el objetivo cae). Primero mira a los lados; si no, el primero vivo que haya. null si no
# queda nadie.
func _siguiente_vivo(muerto: Combatant) -> Combatant:
	var centro: int = _enemies.find(muerto)
	if centro >= 0:
		for paso in [-1, 1]:
			var i: int = centro + paso
			while i >= 0 and i < _enemies.size():
				if _enemies[i].is_alive():
					return _enemies[i]
				i += paso
	var vivos: Array[Combatant] = _vivos()
	return vivos[0] if not vivos.is_empty() else null


# Resuelve UN golpe de habilidad sobre 'objetivo' con 'escala' extra (área: salpicón o falloff
# del barrido; 1.0 = golpe pleno). Aplica daño, imbuición, maná por golpe y —si la habilidad es
# efectos_por_golpe— sus estados. Devuelve un dict con lo necesario para acumular y loguear.
# 'etq' etiqueta el objetivo en el log cuando hay varios ("" en single-target).
func _resolver_golpe_hab(ab: AbilityData, objetivo: Combatant, i: int, manos: int,
		escala: float, etq: String, m_golpe: float) -> Dictionary:
	# 'c' = a QUIEN fue este golpe. Lo necesita el log para decir el reparto por enemigo (mismo
	# campo que usan los resultados de hechizo, ver _log_hechizo). 'm_golpe' = el multiplicador que
	# le toca a ESTE golpe segun el plan (mano principal/segunda del dual, o arma/escudo).
	var r := {"c": objetivo, "dmg": 0.0, "imbue": 0.0, "mult_imbue": 1.0, "crit": false,
		"evaded": false, "mana": 0.0, "conecto": false, "estados": [], "linea": ""}
	# Los golpes DE ESCUDO pegan con tu DEFENSA, no con tu arma (ver AbilityData.escudo_desde_golpe).
	# En Guardia rota / Aplastamiento eso significa que el golpe 0 va con Ataque y el 1 con Defensa:
	# cada uno con su atributo.
	var atk_ov: float = _player.atk_escudo() if ab.golpe_es_de_escudo(i) else -1.0
	var result := StatsMath.resolve_attack(_player, objetivo, false, atk_ov)
	if result.evaded:
		r.evaded = true
		r.linea = "golpe %d%s: esquivado 💨" % [i + 1, etq]
		return r
	var dmg: float = result.damage * ab.dano_mult * m_golpe * escala
	r.dmg = dmg
	r.imbue = float(result.get("dmg_imbue", 0.0)) * ab.dano_mult * m_golpe * escala
	r.mult_imbue = float(result.get("mult_imbue", 1.0))
	objetivo.take_damage(dmg)
	_apuntar_dano(objetivo, dmg, _player)   # contador oculto de Cazador
	r.mana = _ganar_mana_golpe()       # cada golpe que conecta repone maná
	if float(result.get("dmg_imbue", 0.0)) > 0.0:
		_gastar_amplificadores(objetivo, _player.imbue_elemento)
	r.conecto = true
	r.crit = result.crit
	var esc_txt: String = "" if is_equal_approx(escala, 1.0) else " [%d%%]" % roundi(escala * 100.0)
	# Etiqueta de "con qué se pega": arma+escudo distingue arma/escudo; el dual, la 2ª mano.
	var mano_txt: String = ""
	if ab.escudo_desde_golpe >= 0:
		# Se dice con QUE se pega y, en el escudazo, que va con la DEFENSA: es la unica pista de
		# que subir armadura le sube el daño a ese golpe.
		mano_txt = " [escudo · DEF]" if ab.golpe_es_de_escudo(i) else " [arma]"
		if ab.golpe_es_de_escudo(i) and m_golpe < 1.0:
			mano_txt = " [escudo · DEF %d%%]" % roundi(m_golpe * 100.0)
	elif m_golpe < 1.0:
		mano_txt = " [2ª mano %d%%]" % roundi(m_golpe * 100.0)
	r.linea = "golpe %d%s%s%s: %s %.2f%s" % [i + 1, etq, mano_txt, esc_txt,
		("CRITICO 💥" if result.crit else "acierta"), dmg,
		_imbue_dmg_txt(result, ab.dano_mult * m_golpe * escala)]
	# IMBUICION: cada golpe que acierta tira su estado (multi-golpe = más tiradas).
	if ab.efectos_por_golpe and objetivo.is_alive():
		# "objetivo": los buffs propios NO se tiran aqui (un multi-golpe los aplicaria una vez por
		# tajo). Se hacen una sola vez al final de la habilidad, en _usar_habilidad.
		# 'escala' es la fraccion de daño que encaja ESTE objetivo, y con ella va la probabilidad:
		# al de al lado que se come el 40% del golpe le prende el estado un 40% de las veces.
		var ap: Array = _tirar_efectos_habilidad(ab, objetivo, result.crit, "objetivo", escala, escala)
		r.estados = ap
		if not ap.is_empty():
			r.linea += "  -> " + ", ".join(ap)
	if objetivo.is_alive():
		var imb_h: String = _player.roll_imbue(objetivo)
		if imb_h != "":
			r.estados.append(imb_h)
			r.linea += "  ⚡ " + imb_h
	return r


# Segundo paso de las habilidades que caen sobre UN ALIADO (Purificar, Égida menor): a quien.
# Mismo patron que el de los hechizos (_elegir_objetivo_aliado), pero en la caja de habilidades.
# Con un solo aliado en pie no se pregunta nada: va directa a el.
func _elegir_aliado_habilidad(ab: AbilityData) -> void:
	var vivos: Array[Combatant] = _aliados_vivos()
	if vivos.size() <= 1:
		_hab_aliado = vivos[0] if not vivos.is_empty() else _player
		_usar_habilidad(ab)
		return
	for c in _ability_box.get_children():
		c.queue_free()
	var grid := _rejilla_submenu(_ability_box)
	for al in vivos:
		var b := TooltipButton.new()
		var estados: String = al.status_summary()
		b.text = "%s  (%.0f/%.0f ♥)" % [al.nombre, al.current_hp, al.max_hp]
		b.tooltip_text = "%s usa %s sobre %s.%s" % [_player.nombre, ab.nombre, al.nombre,
			"\n\nAhora lleva: %s" % estados if estados != "" else "\n\nNo tiene ningún estado encima."]
		b.pressed.connect(func():
			_hab_aliado = al
			_usar_habilidad(ab))
		_celda_submenu(b)
		grid.add_child(b)
	_cerrar_submenu(_ability_box, vivos.size(), _accion_habilidad)
	_ocultar_log()


# EL JUGADOR EMPIEZA A CARGAR. Espejo de _enemy_begin_charge, con la misma regla: el turno se va en
# anunciarlo, y aturdirte te la interrumpe (ver _begin_player_turn).
#
# El OBJETIVO no se guarda: se vuelve a preguntar al soltar. Dos turnos son muchos en una pelea y el
# bicho al que apuntabas puede estar muerto; obligar a que el golpe caiga en un cadaver seria peor
# que dejar que busque otro (que es lo que hace _objetivo()).
func _empezar_carga_jugador(ab: AbilityData) -> void:
	_player.charging = ab
	_player.charge_left = ab.carga_turnos
	print("[habilidad] %s empieza a cargar %s (%d turno%s)" % [
		_player.nombre, ab.nombre, ab.carga_turnos, "" if ab.carga_turnos == 1 else "s"])
	_set_log("⚡ %s se prepara para %s. (si te aturden, se interrumpe)" % [_player.nombre, ab.nombre])
	_fin_de_eleccion()   # cierra la accion: oculta las cajas y repinta (aqui sale el chip ⚡)
	_tras_accion_jugador_varios([])   # pasa el turno sin rematar a nadie: no ha habido golpe


# 'soltando' = esta habilidad viene de una CARGA que acaba de llegar a cero (la dispara
# _begin_player_turn). Cuando es true no se vuelve a cobrar ni a validar nada: la energia y el
# cooldown se pagaron al EMPEZAR a cargar, hace dos turnos.
func _usar_habilidad(ab: AbilityData, soltando: bool = false) -> void:
	# En el espejo se elige, pero resuelve el anfitrion: le viaja QUE habilidad (por su ruta) y
	# contra quien. El la busca en el loadout de mi personaje, que es el mismo que tiene el.
	if _espejo and ab != null:
		_responder_al_anfitrion({"tipo": "habilidad", "ruta": ab.resource_path, "obj": _target_idx})
		return
	# OBJETIVO capturado UNA vez, al principio de la accion. No se vuelve a preguntar por el
	# dentro del bucle de golpes a proposito: si el objetivo cae al tercer tajo de una habilidad
	# de cinco, los dos que quedan tienen que caer en el vacio, no saltar solos al siguiente
	# enemigo. Una accion = un objetivo, el que elegiste al lanzarla.
	var obj: Combatant = _objetivo()
	# Manos que aportan ESTA habilidad (dual solo si son 2: daga+daga, no daga+estoque).
	var idxs: Array = _player.ability_hand_indices(ab)
	var manos: int = maxi(1, idxs.size())
	var es_conversion: bool = ab.energia_a_mana > 0.0   # Canalizar: gasta TODA la energia
	var coste: float = _player.current_energy if es_conversion else ab.coste(manos)
	# Al SOLTAR una carga no se valida ni se cobra: ya se hizo al empezarla, y volver a exigir
	# energia aqui te dejaria la habilidad a medias por haberte quedado seco entre medias.
	if not soltando:
		# Fuera de turno = ni es una eleccion ni hay turno que gastar (un click perdido, un eco de la
		# interfaz): se ignora y ya. Es el UNICO caso que sale por un return seco, ver abajo.
		if _state != State.WAITING_PLAYER:
			return
		# LA HABILIDAD NO SE PUEDE LANZAR (en cooldown, con cargas de Foco pendientes, sin energia).
		# En local no llegas aqui: el boton sale deshabilitado. Pero una eleccion REMOTA se valida en
		# esta maquina, y su pantalla puede estar mintiendole (era el caso del dual perdido: el espejo
		# le ponia Rafaga a 48 EN, la pulsaba con 50 y aqui costaba 70). Un return seco dejaba la
		# pelea COLGADA PARA TODOS: _aplicar_accion_remota ya hizo _fin_de_espera, asi que nadie
		# vuelve a pedirle el turno y el estado se queda en WAITING_PLAYER para siempre.
		# Se cae a basico, igual que cuando la habilidad ya no esta en su loadout: no se pierde el turno.
		var puede: bool = _player.ability_ready(ab) \
			and not (ab.foco_cargas > 0 and _player.foco_cargas > 0)
		if puede:
			puede = _player.current_energy >= ab.energia_a_mana if es_conversion \
				else _player.has_energy(coste)
		if not puede:
			print("[habilidad] %s no puede lanzar %s ahora: ataca de basico" % [_player.nombre, ab.nombre])
			_accion_atacar()
			return
		# ATAQUE DE CARGA: si la habilidad tarda turnos en soltarse, este turno se va en ANUNCIARLA.
		# Va DESPUES de cobrar la energia y ANTES de resolver nada: te comprometes al empezar.
		# El campo existia desde siempre (AbilityData.carga_turnos) y la ficha lo prometia, pero solo
		# lo implementaba la rama ENEMIGA: las del jugador se disparaban al instante. Ver
		# _enemy_begin_charge, que es su espejo — si se toca una, tocar la otra.
		if ab.carga_turnos > 0:
			_player.spend_energy(coste)
			_player.start_cooldown(ab)
			_empezar_carga_jugador(ab)
			return
		_player.spend_energy(coste)
		_player.start_cooldown(ab)   # entra en cooldown (si la habilidad tiene)
	# Maná recuperado: FIJO (mana_gain) + por CONVERSION de toda la energia (energia_a_mana).
	# Al SOLTAR una carga la conversion NO paga otra vez: la energia se fundio al empezarla, y aqui
	# 'coste' vale lo que tengas AHORA. Sin este guardia, una habilidad de conversion con carga te
	# daria maná gratis por energia que ya no gastas.
	var mana_ganado: float = ab.mana_gain
	if es_conversion and not soltando:
		mana_ganado += coste / ab.energia_a_mana
	if mana_ganado > 0.0:
		_player.regen_mana(mana_ganado)
	var mana_txt := "  +%.1f MP" % mana_ganado if mana_ganado > 0.0 else ""
	# Al soltar una carga el coste ya se pago hace dos turnos: decir "76 EN" aqui haria pensar que se
	# cobra dos veces cuando se lea el log buscando por que alguien se queda sin energia.
	print("[habilidad] %s usa %s  (%s, %s%s)" % [
		_player.nombre, ab.nombre, ("dual" if manos >= 2 else "1 mano"),
		"carga soltada, ya pagada" if soltando else "%.0f EN" % coste, mana_txt])
	var total: float = 0.0
	var total_imbue: float = 0.0   # cuanto del total lo ha puesto la imbuicion (va DENTRO de 'total')
	var mult_imbue: float = 1.0
	var golpes: int = 0
	var estados_log: Array = []
	var tocados: Array = [obj]      # todos los enemigos alcanzados: se rematan AL FINAL, de una vez
	# LOG: el RASTRO (un token por golpe, en orden: "4.21" / "falla" / "💥9.80") y el REPARTO
	# (Combatant -> daño acumulado). Antes el desglose golpe a golpe solo iba a la consola y en
	# pantalla salia un "0 de daño (2 golpes)" que no explicaba nada.
	var rastro: Array = []
	var dano_por_obj: Dictionary = {}
	# ¿Alguno de los golpes fue CRITICO? Se declara AQUI FUERA, y no dentro del bloque de golpes,
	# porque lo necesita la tirada de efectos, que ahora vive fuera (ver el bloque de EFECTOS mas
	# abajo). Sin golpes se queda en false, que es lo correcto: una habilidad que no pega no critea.
	var hubo_critico: bool = false
	# GOLPES de daño (rango aleatorio; cada tajo con su ESQUIVA y CRITICO propios). Si
	# efectos_por_golpe, cada tajo que acierta tira los efectos (sangrado 40%/hit).
	# Las de UTILIDAD PURA (dano_mult 0, p.ej. Canalizar) NO golpean.
	if ab.dano_mult > 0.0:
		golpes = ab.num_golpes(manos, _vivos().size())   # flurries: más golpes cuantos más enemigos
		# PLAN de golpes: mano y multiplicador de cada uno. Intercala las manos del dual (der, izq,
		# der, izq) y, en arma+escudo, alterna arma (fuerte) / escudo (flojo). Ver ab.plan_golpes.
		var plan: Array = ab.plan_golpes(golpes, manos)
		var conecto: int = 0
		# Aciertos POR OBJETIVO (combatiente -> nº de golpes que le entraron). El contador de arriba
		# es el total contra TODOS y no vale para decidir a quien se le aplican los efectos: ver el
		# bloque de efectos no-por-golpe al final del bucle.
		var conecto_por_obj: Dictionary = {}
		# FRACCION DE DAÑO que ha encajado cada objetivo (1.0 el principal, menos los secundarios de
		# un area). De aqui sale la probabilidad de que les prenda el estado: quien se come el 40%
		# del golpe tiene el 40% de la tirada. Derivarlo del daño y no de un campo aparte hace que
		# al tocar area_secundario / area_falloff esto se ajuste solo.
		var escala_por_obj: Dictionary = {}
		var mana_ganado_golpes: float = 0.0
		# Objetivos del ÁREA (el principal siempre el primero). En single-target = [obj].
		var objetivos: Array[Combatant] = _objetivos_hab(ab, obj)
		tocados = []
		for i in golpes:
			# La mano activa alterna con el dual (daga+daga); con una sola arma, siempre la misma.
			var m_golpe: float = float(plan[i]["mult"])
			_player.set_active_hand(idxs[mini(int(plan[i]["hand"]), idxs.size() - 1)])
			var golpe_res: Array = []   # resultados de ESTE golpe (varios si es área)
			match ab.area_modo:
				AbilityData.AreaModo.SPLASH:
					# Principal al 100%, cada secundario x el % que toca (baja con la multitud si la
					# habilidad tiene decay). El total CRECE con cada enemigo tocado.
					var n_vivos_s: int = 0
					for t in objetivos:
						if t.is_alive(): n_vivos_s += 1
					var esc_sec: float = ab.secundario_para(n_vivos_s)
					for t in objetivos:
						if not t.is_alive():
							continue
						var esc: float = 1.0 if t == obj else esc_sec
						var etq: String = "" if t == obj else " (%s)" % t.nombre
						golpe_res.append(_resolver_golpe_hab(ab, t, i, manos, esc, etq, m_golpe))
						escala_por_obj[t] = maxf(float(escala_por_obj.get(t, 0.0)), esc)
						if t not in tocados: tocados.append(t)
				AbilityData.AreaModo.BARRIDO:
					# Todos reciben el golpe, pero x falloff^(n-1) con n = vivos alcanzados EN ESTE
					# golpe (se recalcula): si uno cae, n baja y el resto pega más fuerte.
					var vivos_alc: Array = objetivos.filter(func(c): return c.is_alive())
					var n: int = vivos_alc.size()
					var esc_b: float = pow(ab.area_falloff, maxi(0, n - 1))
					for t in vivos_alc:
						var etq2: String = "" if t == obj else " (%s)" % t.nombre
						golpe_res.append(_resolver_golpe_hab(ab, t, i, manos, esc_b, etq2, m_golpe))
						escala_por_obj[t] = maxf(float(escala_por_obj.get(t, 0.0)), esc_b)
						if t not in tocados: tocados.append(t)
				_:
					# SIN área. Un objetivo; si cae y la habilidad REDIRIGE, salta al siguiente vivo.
					var actual: Combatant = obj
					if not actual.is_alive() and ab.redirige_al_morir:
						actual = _siguiente_vivo(actual)
					if actual == null or not actual.is_alive():
						break   # nadie a quien pegar: los golpes que quedan se pierden
					golpe_res.append(_resolver_golpe_hab(ab, actual, i, manos, 1.0,
						"" if actual == obj else " (%s)" % actual.nombre, m_golpe))
					if actual not in tocados: tocados.append(actual)
			# Acumular y loguear los golpes resueltos, en orden.
			for r in golpe_res:
				total += r.dmg
				total_imbue += r.imbue
				if r.dmg > 0.0:
					mult_imbue = r.mult_imbue
				if r.conecto:
					conecto += 1
					# Y POR OBJETIVO, que es lo que decide luego a quien se le tiran los efectos: el
					# contador de arriba suma los aciertos contra CUALQUIERA, asi que no sirve para
					# saber si a ESTE le llego algo. Ver el bloque de efectos no-por-golpe.
					conecto_por_obj[r.c] = int(conecto_por_obj.get(r.c, 0)) + 1
				if r.crit:
					hubo_critico = true
				mana_ganado_golpes += r.mana
				estados_log += r.estados
				# Token de ESTE golpe para el rastro del log (con su objetivo: si la habilidad toca a
				# varios, al final se le pega la etiqueta de a quien fue), y su daño a la cuenta
				# del objetivo para el reparto.
				rastro.append({"t": "falla" if r.evaded
					else ("💥%.2f" % r.dmg if r.crit else "%.2f" % r.dmg), "c": r.c})
				dano_por_obj[r.c] = float(dano_por_obj.get(r.c, 0.0)) + r.dmg
				print("        " + r.linea)
			# Fin de la habilidad si, sin área ni redirección, el objetivo ya cayó (los que
			# sobran no saltan solos). En área/barrido seguimos: aún puede quedar gente viva.
			if ab.area_modo == AbilityData.AreaModo.NINGUNO and not ab.redirige_al_morir \
					and not obj.is_alive():
				break
			# Si no queda NADIE vivo entre los objetivos, no hay a quién seguir pegando.
			if _vivos().is_empty():
				break
		# Efectos NO por golpe: UNA tirada al final por cada objetivo VIVO AL QUE LE ENTRO ALGUN
		# GOLPE (golpe de escudo -> stun; Onda -> aturde+ralentiza a los que alcanzo de verdad).
		#
		# EL QUE ESQUIVA NO SE COME EL DEBUFF. Esto se preguntaba con el contador GLOBAL (`conecto`),
		# que suma los aciertos contra cualquiera, y se aplicaba a todo `tocados` -- y en `tocados`
		# entra cualquier enemigo BARRIDO por el area, esquive o no (los mete _resolver_golpe_hab
		# antes de saber si esquivo). Resultado: en un area contra tres bichos, si le acertabas a uno
		# solo, los otros dos se comian el aturdido igual sin haber sido tocados. Lo mismo con
		# redirige_al_morir. Ahora se mira acierto POR OBJETIVO, que es justo lo que ya hacia la rama
		# enemiga (_enemy_resolver_golpes lleva su `conecto` de uno en uno porque se llama por bicho).
		#
		# Vale para todos sin escribirlo dos veces: las acciones de los compas y de los otros
		# jugadores las resuelve el anfitrion por esta misma funcion (ver aplicar_accion_remota).
		if not ab.efectos_por_golpe:
			for t in tocados:
				if t.is_alive() and int(conecto_por_obj.get(t, 0)) > 0:
					# "objetivo": aqui solo van los efectos que le lanzas AL RIVAL. Los buffs propios
					# se aplican una sola vez, justo debajo -- si fueran por este bucle, un area
					# contra tres bichos te daria el buff tres veces.
					estados_log += _tirar_efectos_habilidad(ab, t, hubo_critico, "objetivo",
						float(escala_por_obj.get(t, 1.0)), float(escala_por_obj.get(t, 1.0)))
		# Excelia: como el ataque, entrena Fuerza (por impacto medio, contra el principal).
		var pj_hab: PersonajeData = Game.pj_de_combatant(_player)
		Game.ganar("fuerza", _reto(obj, pj_hab) * _player.motion_value, Game.GAIN_FUERZA_ATAQUE,
			Game.RETO_MAX_FISICO, pj_hab)
		# Y si en la habilidad ha entrado algun CRITICO, entrena Agilidad igual que el basico: el
		# hueco lo encuentras igual con una habilidad que con un espadazo suelto. Antes esta rama
		# solo pagaba Fuerza, asi que a quien juega a base de habilidades —o sea, cualquiera en
		# cuanto tiene energia— la Agilidad no le subia por critear en toda la pelea.
		# Se paga UNA vez por habilidad aunque hayan criteado varios golpes (mismo criterio que la
		# esquiva de las habilidades enemigas) y con el mismo tope de peso que el basico.
		if hubo_critico:
			Game.ganar("agilidad", _reto(obj, pj_hab)
				* minf(_player.motion_value, Game.GAIN_AGILIDAD_CRIT_MV_MAX),
				Game.GAIN_AGILIDAD_CRITICO, Game.RETO_MAX_FISICO, pj_hab)
		print("        total: %.2f de daño en %d golpe%s%s | EN -%.0f -> %.1f/%.1f%s" % [
			total, golpes, "" if golpes == 1 else "s",
			_desglose_imbue(total, total_imbue, mult_imbue),
			0.0 if soltando else coste, _player.current_energy, _player.max_energy,
			"" if mana_ganado_golpes <= 0.0 else " | MP +%.1f -> %.1f/%.1f" % [
				mana_ganado_golpes, _player.current_mp, _player.max_mp]])
		# El maná que han repuesto los golpes se suma al del propio efecto de la habilidad
		# (mana_gain), que ya se aplico arriba: aqui solo se junta para el mensaje.
		mana_ganado += mana_ganado_golpes
		_dps_add(ab.nombre, total)
		# Una habilidad = UN uso de imbuicion, traiga los golpes que traiga (si no, las
		# multi-golpe la fundirian de una). Las de utilidad pura (Canalizar) no la gastan.
		_gastar_imbue()
	else:
		# UTILIDAD PURA (dano_mult 0): no hay golpes, pero SI puede llevar efectos que le lanzas al
		# rival (un debuff sin daño). Sin esta rama se perdian: no hay acierto que comprobar, asi que
		# entran directos, y su propia `prob` decide.
		for t in _objetivos_hab(ab, obj):
			if t != null and t.is_alive():
				estados_log += _tirar_efectos_habilidad(ab, t, false, "objetivo")

	# BUFFS PROPIOS (en_objetivo = false): UNA vez por uso, pegue la habilidad o no.
	#
	# ESTO ESTABA DENTRO DEL `if ab.dano_mult > 0.0` y era un agujero de los gordos: las OCHO
	# habilidades de puro apoyo del jugador (Grito de aliento, Cobertura, Muro de aliados, Voz de
	# mando, Égida menor, Chispa vinculada, Guardia de carne, Velo umbrío) no aplicaban NADA. Se
	# gastaban la energía, salían en el log y no pasaba nada. La rama enemiga siempre lo hizo bien
	# (ver _enemy_use_ability: su llamada "self" va fuera del if/else de daño) — son funciones
	# espejo y se habian desincronizado justo aqui. Si se vuelve a tocar una, tocar la otra.
	estados_log += _tirar_efectos_habilidad(ab, obj, hubo_critico, "self")

	if ab.bloqueo_turnos > 0:
		_player_defending = true   # golpe de escudo: te deja en guardia
	# Postura de contraataque del estoque (KAN-57): entras en guardia hasta tu proxima accion.
	# Bajas velocidad (data-driven), esquivas mas y devuelves los golpes que esquivas (riposte).
	if ab.postura_contraataque:
		_player.en_guardia = true
		_player.guardia_spd_mult = ab.guardia_spd_mult
		_player.evasion_bonus = ab.evasion_bonus
		_player.guardia_contra_mult = ab.contra_mult
	# Foco arcano (Canalización): concede cargas que amplifican tus proximos hechizos.
	if ab.foco_cargas > 0:
		_player.foco_cargas += ab.foco_cargas
	# Provocacion (escudo): pasas a atraer los golpes N turnos (ver _elegir_objetivo_enemigo).
	# OJO: va al MISMO nivel que el Foco, no dentro. Estuvo anidada por error y, como la
	# Provocacion no da cargas de Foco, no se aplicaba NUNCA.
	if ab.provoca_turnos > 0:
		_player.provocar_turnos = ab.provoca_turnos
	# IMBUICION DESDE EL ARMA (el veneno de la daga). Reutiliza la misma maquinaria que los Filos:
	# se gasta 1 carga por ATAQUE, aguanta entre combates y se ve en el mismo chip. OJO: aplicar_imbue
	# SUSTITUYE, asi que envenenar la daga te quita el Filo o el Manto que llevaras -- hay una sola
	# ranura de imbuicion, y es a proposito.
	if ab.es_imbuicion():
		_player.aplicar_imbue(ab.imbue_elemento, ab.imbue_pct, ab.imbue_usos, false,
			ab.imbue_estado, ab.imbue_prob, Elementos.INTENSIDAD_IMBUIDO,
			ab.imbue_prob_doble, ab.imbue_por_destreza)
		estados_log.append("%s en el arma (%d ataques)" % [
			str(StatusEffects.def(ab.imbue_estado).get("nombre", "?")), ab.imbue_usos])
	# LIMPIAR DEBUFFS: a un aliado elegido (Purificar) o a todo el grupo (el area del baston).
	if ab.limpia_debuffs > 0:
		# Sin ternario a proposito: _aliados_vivos() devuelve Array[Combatant] y la otra rama un
		# Array pelado, y GDScript avisa de que los dos lados no son del mismo tipo.
		var a_limpiar: Array = []
		if ab.objetivo_aliado == AbilityData.Objetivo.GRUPO:
			a_limpiar.assign(_aliados_vivos())
		else:
			a_limpiar.append(_hab_objetivo_aliado())
		for al in a_limpiar:
			var quitados: Array = al.limpiar_debuffs(ab.limpia_debuffs)
			if not quitados.is_empty():
				estados_log.append("%s se quita %s" % [al.nombre, ", ".join(quitados)])
	# RECORTE DE COOLDOWNS: a las OTRAS habilidades, nunca a la suya (ver AbilityData).
	if ab.reduce_cooldowns > 0:
		var destrabadas: int = _player.reducir_cooldowns(ab.reduce_cooldowns, ab)
		estados_log.append("cooldowns −%dt%s" % [ab.reduce_cooldowns,
			"" if destrabadas == 0 else " (%d lista%s)" % [destrabadas, "" if destrabadas == 1 else "s"]])

	# ---- Mensaje al jugador ----
	# Con daño van DOS lineas: el RASTRO (que hizo cada golpe) y el REPARTO (cuanto se llevo cada
	# uno y el total). Un "0 de daño (2 golpes)" no decia si habias fallado, esquivado o pegado a
	# un muerto. Mismo criterio que los hechizos (ver _log_hechizo): nunca una linea por golpe,
	# que el log solo tiene LOG_MAX.
	var msg: String
	if ab.dano_mult > 0.0:
		var titulo: String = ab.nombre if tocados.size() > 1 else "%s → %s" % [ab.nombre, _etq(obj)]
		var sin_dar: String = "… no le has dado con ninguno de los %d golpe%s." % [
			rastro.size(), "" if rastro.size() == 1 else "s"]
		msg = _log_desglose(titulo, rastro, tocados, dano_por_obj, total, sin_dar,
			_desglose_imbue(total, total_imbue, mult_imbue))
	else:
		msg = "%s usa %s." % [_player.nombre, ab.nombre]
	if mana_ganado > 0.0:
		msg += "  +%.1f MP." % mana_ganado
	if not estados_log.is_empty():
		msg += "  ✨%s." % ", ".join(estados_log)
	if ab.bloqueo_turnos > 0:
		msg += "  🛡️ En guardia."
	if ab.postura_contraataque:
		msg += "  🤺 En guardia (contraataque al esquivar)."
	if ab.foco_cargas > 0:
		msg += "  🔮 Foco arcano: %d cargas (+%d%% daño a tus próximos hechizos)." % [
			_player.foco_cargas, roundi(Combatant.FOCO_BONUS * 100.0)]
	if ab.provoca_turnos > 0:
		msg += "  🎯 Provocas %d turnos: los enemigos irán más a por ti." % ab.provoca_turnos
	_set_log(msg)
	_update_hp()
	_fin_de_eleccion()
	# A TODOS los alcanzados, no solo al objetivo principal (misma regla que la magia de area).
	# _tras_accion_jugador_varios es el UNICO camino que llama a _morir_enemigo, asi que rematando
	# solo a 'obj' un enemigo que cayera como objetivo SECUNDARIO (area) o REDIRIGIDO no se apagaba
	# nunca: se quedaba con el recuadro de vivo, los chips de sus estados congelados a la vista y su
	# marca en la barra de turnos, pero sin poder atacarlo. Como todas las habilidades que alcanzan
	# a secundarios llevan estado, parecia un bug "de los debuffs".
	_tras_accion_jugador_varios(tocados if not tocados.is_empty() else [obj])


# ============================================================
#  OBJETOS / pociones (KAN-57): submenu del inventario + uso
# ------------------------------------------------------------
func _accion_objeto() -> void:
	_ocultar_cajas()
	for c in _objeto_box.get_children():
		c.queue_free()
	# Una fila por tipo de poción del inventario, con la cantidad. Los grimorios NO salen: en
	# mitad de una pelea no te pones a estudiar (se usan desde el inventario, en el pueblo). Los
	# CEBOS tampoco: no se usan en ningun sitio que no sea la orilla de un estanque.
	var grid := _rejilla_submenu(_objeto_box)
	for cons in Game.consumables:
		var n: int = int(Game.consumables[cons])
		if n <= 0 or cons.es_grimorio() or cons.es_cebo():
			continue
		var b := TooltipButton.new()
		# El cuanto/en cuantos turnos se va al tooltip: a media anchura solo caben nombre y cantidad.
		b.text = "%s  x%d" % [cons.nombre, n]
		# Un PLATO no se reparte en turnos: su ficha ya dice lo que hace y cuanto dura.
		b.tooltip_text = cons.resumen_plato() if cons.es_plato() \
			else "%s en %d turnos" % [cons.resumen(_player.max_hp, _player.max_mp), cons.turnos]
		if cons.descripcion != "":
			b.tooltip_text += "\n\n" + cons.descripcion
		b.pressed.connect(_elegir_objetivo_objeto.bind(cons))
		_celda_submenu(b)
		grid.add_child(b)
	_cerrar_submenu(_objeto_box, grid.get_child_count(), _mostrar_acciones)
	_ocultar_log()   # el submenu ocupa el sitio del historial


# Segundo paso del submenu: A QUIEN se la das. Una poción no tiene por que ser para ti — el que
# la bebe gasta SU turno, pero la cura puede ir al tanque que esta a punto de caer. Con un solo
# aliado en pie no se pregunta nada: va directo a el.
func _elegir_objetivo_objeto(cons: ConsumableData) -> void:
	var vivos: Array[Combatant] = _aliados_vivos()
	if vivos.size() <= 1:
		_usar_objeto(cons, _player)
		return
	for c in _objeto_box.get_children():
		c.queue_free()
	var grid := _rejilla_submenu(_objeto_box)
	for al in vivos:
		var b := TooltipButton.new()
		var partes: Array = ["%.0f/%.0f ♥" % [al.current_hp, al.max_hp]]
		if cons.da_mana():
			partes.append("%.0f/%.0f 🔷" % [al.current_mp, al.max_mp])
		b.text = "%s  (%s)" % [al.nombre, "  ".join(partes)]
		b.tooltip_text = "%s le da %s a %s." % [_player.nombre, cons.nombre, al.nombre]
		b.pressed.connect(_usar_objeto.bind(cons, al))
		_celda_submenu(b)
		grid.add_child(b)
	_cerrar_submenu(_objeto_box, vivos.size(), _accion_objeto)


# Bebe una poción y se la da a 'objetivo': cura vida y/o maná YA, en este mismo turno, y deja el
# resto como Regeneración en los turnos que le queden. El primer tique es inmediato a proposito:
# los estados tiquean al INICIO del turno, asi que antes te bebias una poción y no veias subir
# nada hasta tu turno siguiente — justo cuando ya te habian rematado. El TOTAL no cambia: una
# poción de 3 turnos cura 1/3 ahora y 2/3 en tus 2 turnos siguientes.
# GASTA el turno del que la bebe (_player) y no cuesta energia.
func _usar_objeto(cons: ConsumableData, objetivo: Combatant, cobrar: bool = true) -> void:
	# Igual que las habilidades: el espejo elige y el anfitrion resuelve. El objetivo viaja como
	# INDICE dentro de los aliados, que es lo unico que significa lo mismo en las dos maquinas.
	# La POCION la pone quien la usa, no el anfitrion: las bolsas son por jugador y nunca se
	# sincronizan, asi que se gasta AQUI y el anfitrion resuelve el efecto sin cobrar nada.
	if _espejo and cons != null:
		if not Game.gastar_consumible(cons):
			return
		_responder_al_anfitrion({"tipo": "objeto", "ruta": cons.resource_path,
			"aliado": _aliados.find(objetivo)})
		return
	if _state != State.WAITING_PLAYER or objetivo == null or not objetivo.is_alive():
		return
	if cobrar and not Game.gastar_consumible(cons):
		return
	# UN PLATO DE COCINA no cura: pone un buff largo. Sale antes que el reparto de la poción porque
	# no tiene nada que repartir (turnos = 0), y va por apply_status como todo lo demas: es el que
	# sabe de la familia excluyente, o sea que comer aqui tira el plato anterior igual que comer por
	# el mapa. Gasta el turno igual que beber.
	if cons.es_plato():
		for ap in cons.efectos:
			if ap == null:
				continue
			objetivo.apply_status(int(ap.estado), int(ap.turns), float(ap.magnitud),
				maxi(1, int(ap.stacks)), false, int(ap.cap), float(ap.mult), cons.escala_efecto)
		print("[cocina] %s le da %s a %s (en combate)" % [_player.nombre, cons.nombre, objetivo.nombre])
		_set_log("%s se come %s." % [objetivo.nombre, cons.nombre] if objetivo == _player
			else "%s le da %s a %s." % [_player.nombre, cons.nombre, objetivo.nombre])
		_update_hp()
		_fin_de_eleccion()
		_state = State.ADVANCING
		return

	var restantes: int = maxi(0, cons.turnos - 1)   # el primer turno se cobra AL INSTANTE
	var partes: Array = []
	if cons.cura_hp():
		var por_turno: float = cons.cura_por_turno(objetivo.max_hp)
		var total: float = cons.cura_efectiva(objetivo.max_hp)
		objetivo.heal(por_turno)
		if restantes > 0:
			objetivo.apply_status(StatusEffects.Id.REGENERACION, restantes, por_turno)
		partes.append("✚ %.0f de vida (%.0f ya)" % [total, por_turno])
	if cons.da_mana():
		var mana_turno: float = cons.mana_por_turno(objetivo.max_mp)
		var mana_total: float = cons.mana_efectivo(objetivo.max_mp)
		objetivo.regen_mana(mana_turno)
		if restantes > 0:
			objetivo.apply_status(StatusEffects.Id.REGEN_MANA, restantes, mana_turno)
		partes.append("🔷 %.0f de maná (%.0f ya)" % [mana_total, mana_turno])
	print("[objeto] %s le da %s a %s (x%d turnos)" % [
		_player.nombre, cons.nombre, objetivo.nombre, cons.turnos])
	var quien: String = ("%s se bebe %s" % [_player.nombre, cons.nombre] if objetivo == _player
		else "%s le da %s a %s" % [_player.nombre, cons.nombre, objetivo.nombre])
	_set_log("%s. %s, repartido en %d turnos." % [quien, " y ".join(partes), cons.turnos])
	_update_hp()
	_fin_de_eleccion()
	_state = State.ADVANCING


# Tira los efectos de una habilidad sobre 'objetivo' (cada uno con su prob y la resistencia a
# estados del rival). El objetivo va por PARAMETRO, y es el que capturo la accion al lanzarse:
# asi los estados caen sobre el mismo bicho que esta recibiendo los golpes.
# Devuelve los NOMBRES de los que prenden.
# Tira los efectos de una habilidad TUYA. Espejo de _enemy_tirar_efectos, con el que tiene que
# mantenerse a la par: durante mucho tiempo esta rama ignoraba en_objetivo y mandaba TODO al
# enemigo, asi que un auto-buff en un arma se lo quedaba el bicho.
#
#   filtro: "todos" | "objetivo" (solo lo que va al rival) | "self" (solo los buffs propios).
#           Un area llama con "objetivo" por cada enemigo tocado y con "self" UNA sola vez, para
#           que el buff propio no se aplique una vez por bicho.
#   escala_prob / escala_mag: < 1.0 en los SECUNDARIOS de un area. Salen de la FRACCION DE DAÑO que
#           ha encajado ese objetivo, no de un numero a mano: si encaja el 40% del golpe, tiene el
#           40% de la probabilidad. Asi al tocar area_secundario esto se ajusta solo.
func _tirar_efectos_habilidad(ab: AbilityData, objetivo: Combatant, fue_critico: bool = false,
		filtro: String = "todos", escala_prob: float = 1.0, escala_mag: float = 1.0) -> Array:
	var out: Array = []
	for a in ab.efectos:
		if a.estado < 0:
			continue
		if a.solo_crit and not fue_critico:
			continue   # efecto reservado al critico (p.ej. 2o sangrado de la Punalada)
		var al_enemigo: bool = a.en_objetivo
		if filtro == "objetivo" and not al_enemigo:
			continue
		if filtro == "self" and al_enemigo:
			continue
		# A QUIEN cae. Los buffs propios pueden ir a todo el grupo (grito del tanque) o a UN aliado
		# que has elegido tu (Égida menor, Chispa vinculada): eso lo sabe _hab_objetivo_aliado, que
		# devuelve al que lanza cuando la habilidad no pregunta por nadie. Antes ponia `_player` a
		# pelo, asi que el escudo que le echabas al tanque te lo quedabas tu.
		var destinos: Array = []
		if al_enemigo:
			destinos.append(objetivo)
		elif a.a_todo_el_grupo:
			for al in _aliados_vivos():
				destinos.append(al)
		else:
			destinos.append(_hab_objetivo_aliado())
		var nom: String = str(StatusEffects.def(a.estado).get("nombre", "?"))
		for d in destinos:
			if d == null or not d.is_alive() or d.es_inmune(a.estado):
				continue
			# Solo lo que le LANZAS a alguien se resiste; un buff tuyo siempre prende (igual que
			# en los hechizos, ver _aplicar_estado_hechizo).
			var p: float = a.prob
			if al_enemigo:
				p = a.prob * (1.0 - d.resist_estados()) * escala_prob
				# ATURDIR: la probabilidad de la habilidad es solo la BASE; encima suma el aturdir
				# del ARMA (que ya viene con Peso y rareza aplicados, ver Game._hand_from). Antes el
				# aturdir del arma solo contaba en el golpe basico, asi que mejorar Peso no le hacia
				# nada a Golpe sismico ni a Aplastamiento. Y pasa por stun_taken_mult como el resto
				# de vias, para que cuenten su resistencia, su afinidad y el estado Rayo.
				if a.estado == StatusEffects.Id.ATURDIDO:
					p = (a.prob + _player.aturdir_base) * (1.0 - d.resist_estados()) * escala_prob
					p = clampf(p * d.stun_taken_mult(), 0.0, StatsMath.ATURDIR_MAX)
			if randf() >= p:
				continue
			var mag: float = StatusEffects.app_magnitude(a, _player.atk(), _player.motion_value) * escala_mag
			# N stacks por tirada, igual que la rama enemiga. Antes se aplicaba siempre 1 e
			# ignoraba a.stacks: la primera habilidad que lo use tiene que funcionar sin acordarse.
			for _s in maxi(1, a.stacks):
				d.apply_status(a.estado, a.turns, mag, 1, false, a.cap, a.mult)
			out.append(nom if al_enemigo else "%s (%s)" % [nom, d.nombre])
	return out


# MANÁ AL PEGAR: cada golpe de arma que ACIERTA (basico, golpe de habilidad o contraataque)
# devuelve un pellizco PLANO de maná (StatsMath.MP_BASE). Recuperarlo es CONSECUENCIA de pelear,
# no de esperar plantado. Es un pellizco pequeño a proposito: el maná de verdad lo dan el arma
# magica (goteo por turno) y los nucleos de los que matas, que tambien escalan con ella. Sin
# baston ni varita se puede castear, pero a cuentagotas.
# Devuelve lo ganado (0 si el jugador no tiene maná: un guerrero puro).
func _ganar_mana_golpe() -> float:
	if _player.max_mp <= 0.0 or _player.current_mp >= _player.max_mp:
		return 0.0
	var antes: float = _player.current_mp
	_player.regen_mana(StatsMath.mp_por_golpe())
	return _player.current_mp - antes


# En el ESPEJO las acciones no se resuelven aqui: se le mandan al anfitrion, que es quien lleva la
# pelea. Devuelve true si ya se ha enviado (y por tanto hay que salir sin hacer nada mas).
func _enviar_si_espejo(tipo: String) -> bool:
	if not _espejo:
		return false
	_responder_al_anfitrion({"tipo": tipo, "obj": _target_idx})
	return true


# LA UNICA PUERTA DE SALIDA de las respuestas del espejo. Todas pasan por aqui para que ninguna se
# olvide de dos cosas: sellar la respuesta con el numero de lo que me pidieron, y APUNTAR que ya
# conteste a ese numero. Lo segundo es lo que hace que un reenvio del anfitrion no me vuelva a poner
# los botones de un turno que ya jugue (ver turno_mio y _pet_seq).
func _responder_al_anfitrion(accion: Dictionary) -> void:
	accion["seq"] = _seq_espejo
	_seq_contestada = _seq_espejo
	_ocultar_cajas()
	_state = State.ADVANCING
	_traza_add("CONTESTO #%d '%s'" % [_seq_espejo, String(accion.get("tipo", "?"))])
	Net.enviar_accion(accion)


func _accion_atacar() -> void:
	if _enviar_si_espejo("atacar"):
		return
	# Objetivo capturado una vez (ver _usar_habilidad): el golpe va a quien elegiste.
	var obj: Combatant = _objetivo()
	# Los enemigos no defienden (de momento): defending = false.
	var result := StatsMath.resolve_attack(_player, obj, false)
	_debug_ataque(_player, obj, result)
	# Excelia: atacar sube Fuerza aunque el enemigo esquive (has practicado el
	# golpe). arma_factor = motion_value de la MANO ACTIVA (KAN-82); tope fisico (5).
	var arma_factor: float = _player.motion_value
	var pj_atacante: PersonajeData = Game.pj_de_combatant(_player)
	Game.ganar("fuerza", _reto(obj, pj_atacante) * arma_factor, Game.GAIN_FUERZA_ATAQUE,
		Game.RETO_MAX_FISICO, pj_atacante)
	var con_arma: String = _player.current_hand_name()
	if result.evaded:
		_set_log("%s esquiva tu ataque (%s). 💨" % [_etq(obj), con_arma])
	else:
		obj.take_damage(result.damage)
		_apuntar_dano(obj, result.damage, _player)   # contador oculto de Cazador
		# El filo imbuido tambien gasta lo que lo amplificaba (arma de Rayo sobre un Mojado).
		if float(result.get("dmg_imbue", 0.0)) > 0.0:
			_gastar_amplificadores(obj, _player.imbue_elemento)
		_dps_add("Básico (%s)" % con_arma, result.damage)
		var txt: String
		if result.crit:
			txt = "¡CRITICO! %s golpea con %s por %.2f de daño. 💥" % [_player.nombre, con_arma, result.damage]
			# Excelia: clavar un critico entrena Agilidad (encontraste el hueco). Escala con el
			# PESO del arma (motion_value): un arma pesada critea poco, asi que cuando SI lo clava
			# entrena mas Agilidad; una ligera critea a menudo y aporta menos por golpe. El factor
			# va CAPADO (ver GAIN_AGILIDAD_CRIT_MV_MAX): ahora que las pesadas critean de verdad,
			# sin tope entrenarian Agilidad de mas.
			var agi_factor: float = minf(arma_factor, Game.GAIN_AGILIDAD_CRIT_MV_MAX)
			Game.ganar("agilidad", _reto(obj, pj_atacante) * agi_factor, Game.GAIN_AGILIDAD_CRITICO,
				Game.RETO_MAX_FISICO, pj_atacante)
		else:
			txt = "%s golpea con %s por %.2f de daño." % [_player.nombre, con_arma, result.damage]
		# Cuanto de ese daño lo ha puesto la IMBUICION, y si el objetivo era debil/resistente
		# a ella. Sin esto el bonus elemental era invisible: el daño total no lo delata.
		txt += _imbue_dmg_txt(result)
		# Aturdir/retrasar (arma contundente): el enemigo pierde tempo (barra ATB).
		# Retraso parcial normal; si el golpe fue CRITICO, aturdimiento completo.
		if result.aturde:
			txt += _aplicar_aturdir(obj, result.crit)
		# Estados "al golpear" del jugador (arma; futuro: sangrado de cortantes).
		for nom in _player.roll_on_hit(obj):
			txt += "  Le infliges %s." % nom
		# IMBUICION (KAN-58): el elemento de tus golpes puede prender su estado.
		var imb: String = _player.roll_imbue(obj)
		if imb != "":
			txt += "  ⚡ Le infliges %s." % imb
		# El golpe que conecta REPONE maná (no los que fallan: hay que acertar).
		var mp: float = _ganar_mana_golpe()
		if mp > 0.0:
			txt += "  🔷 +%.1f MP." % mp
		_set_log(txt)
	_gastar_imbue()   # blandir el arma gasta un uso, acierte o falle
	# DURABILIDAD: blandir el arma la desgasta (acierte o falle: has dado el golpe). Los puños
	# (main vacio) no se gastan (lo filtra Game.desgastar_arma).
	Game.desgastar_arma(_player.current_hand_slot(), pj_atacante)
	# El ataque basico REGENERA energia (KAN-57): te "cargas" pegando. Las armas PESADAS reponen mas
	# por golpe (su energia_regen propia): pegan menos veces, asi que cada golpe carga mas.
	_player.regen_energy(_player.energia_regen if _player.energia_regen > 0.0 else ATTACK_ENERGY_REGEN)
	_update_hp()
	_player.advance_hand()  # dual-wield: el proximo golpe sera con la otra mano
	_fin_de_eleccion()
	_tras_accion_jugador(obj)


# Accion Defender (KAN-54): mitiga el proximo daño, suma la defensa del escudo y deja los criticos
# en tu contra a la MITAD (no los anula, ver StatsMath.DEFEND_CRIT_MULT) hasta tu siguiente turno.
# Cuesta el turno (no atacas).
func _accion_defender() -> void:
	if _enviar_si_espejo("defender"):
		return
	_player.spend_energy(DEFEND_ENERGY_COST)   # Defender consume energia (KAN-57)
	_player_defending = true
	_set_log("%s se pone en guardia. 🛡️ (menos daño hasta tu proximo turno)" % _player.nombre)
	_update_hp()
	_fin_de_eleccion()
	_state = State.ADVANCING


# El enemigo VIVO mas rapido: el que decide si te escapas. Null si no queda ninguno.
func _mas_rapido() -> Combatant:
	var best: Combatant = null
	for e in _vivos():
		if best == null or e.abilities.agilidad > best.abilities.agilidad:
			best = e
	return best


# Accion Huir (KAN-55): intento de escapar. Probabilidad = CONTEST de Agilidad
# (tu Agilidad vs la del enemigo); entrar agotado la reduce. Si funciona, sales
# del combate SIN loot y los enemigos siguen vivos; si fallas, pierdes el turno.
#
# Con varios enemigos se mide contra el MAS RAPIDO de los que siguen en pie, no contra una
# media: de un grupo escapas tanto como te deje el que mejor te alcanza. Promediar haria que
# sumarle tres slimes lentos a un lobo veloz te FACILITARA huir, que es absurdo.
func _accion_huir() -> void:
	if _enviar_si_espejo("huir"):
		return
	var perseguidor: Combatant = _mas_rapido()
	var chance := StatsMath.flee_chance(
		float(_player.abilities.agilidad), float(perseguidor.abilities.agilidad))
	if _slow_actions_left > 0:
		chance *= FLEE_EXHAUSTED_MULT
	var ok := randf() < chance
	_fin_de_eleccion()
	var dueno: int = int(_dueno_aliado.get(_player, 0))
	# Excelia: escaparse entrena Agilidad, igual que abrir hueco corriendo por el mapa
	# (player._tick_huida). Antes esta accion no pagaba NADA a nadie, y era el agujero que se notaba
	# en el playtest: el que va de acompañante no veia subir su Agilidad por mucho que huyerais.
	#
	# Se paga por INTENTARLO, salga o no: el dado decide si escapas, no lo que aprendes de intentarlo,
	# y si solo pagara al lograrlo la Agilidad dependeria de la suerte. Y lo cobra el GRUPO ENTERO,
	# mismo criterio que el mapa: huyendo corren todos, no solo el que va delante. El reto se calcula
	# para CADA UNO (al mas flojo el mismo bicho le exige mas).
	#
	# Solo si el que huye es de LOS TUYOS: si es el personaje de otro humano, su excelia es suya y
	# vive en su maquina (pj_de_combatant devuelve null para ellos, y eso acabaria sumandoselo a tu
	# lider por la puerta de atras).
	if dueno == 0:
		for pj in Game.party:
			Game.ganar("agilidad", _reto(perseguidor, pj), Game.GAIN_AGILIDAD_HUIDA_COMBATE,
				Game.RETO_MAX_FISICO, pj)
	if ok:
		# HUIR ES INDIVIDUAL (regla del usuario): si el que escapa es el personaje de OTRO humano,
		# se va EL con los suyos y la pelea sigue para los que quedan. Solo se acaba para todos si
		# con eso no queda nadie en pie.
		if dueno != 0 and _huir_solo(dueno):
			_state = State.ADVANCING
			return
		# Huyo YO, que soy quien EJECUTA la pelea: no se cierra para los demas, se TRASPASA al
		# primero que quede dentro y sigue donde estaba.
		if dueno == 0 and _traspasar():
			return
		_end(false, true)  # huida: no ganas, pero tampoco es derrota
	else:
		# Se nombra al mas rapido: es quien explica el numero que acabas de ver.
		_set_log("%s intenta huir pero %s se lo impide. (%.0f%%)" % [
			_player.nombre, perseguidor.nombre, chance * 100.0])
		_state = State.ADVANCING


# ME VOY YO, QUE LLEVO LA PELEA. En vez de cerrarla para todos, se la paso a otro que este dentro:
# el se monta la pantalla de verdad y sigue desde donde estaba. Devuelve false si no hay a quien
# pasarsela (entonces la pelea se cierra como siempre).
func _traspasar() -> bool:
	var nuevo: int = Net.heredero_de_pelea()
	if nuevo == 0:
		return false
	# Los bichos VIVOS se van con la pelea: al cerrar la mia NO hay que reanudarlos (siguen
	# peleando alli) ni devolverlos al mundo. Los muertos si, que sus cadaveres son de esta pelea.
	var siguen: Array = []
	for i in _enemies.size():
		if _enemies[i].is_alive():
			siguen.append(i)
	if not Net.traspasar_pelea(estado_para_traspaso(nuevo)):
		return false
	Game.enemigos_traspasados = siguen
	_set_log("Escapas y le dejas la pelea a tus compañeros. 🏃")
	_end(false, true)
	return true


# SE VA UN JUGADOR (y con el TODOS sus personajes: hay una pantalla por maquina, el que huye huye
# entero). Devuelve false si con eso no queda nadie de pie -> entonces la pelea acaba para todos.
func _huir_solo(peer: int) -> bool:
	var suyos: Array = []
	for c in _aliados:
		if int(_dueno_aliado.get(c, 0)) == peer:
			suyos.append(c)
	if suyos.is_empty():
		return false
	for c in suyos:
		_retirar_aliado(c)
	if _aliados_vivos().is_empty():
		return false   # no queda nadie: que se cierre como una huida normal
	var quien: String = suyos[0].nombre if suyos.size() == 1 else "%s y los suyos" % suyos[0].nombre
	_set_log("%s escapa de la pelea. 🏃  Los demás seguís peleando." % quien)
	# El turno lo tenia el que se ha ido: pasa a alguien que siga en pie, o las acciones se
	# quedarian colgadas de alguien que ya no esta.
	if _huidos.has(_player):
		_player = _aliados_vivos()[0]
	Net.sacar_de_la_pelea(peer)   # le devuelve lo suyo y le cierra el espejo (a el solo)
	_update_hp()
	return true


# SE HA CAIDO un jugador que estaba en mi pelea. Sus personajes salen de ella igual que si hubieran
# huido: si no, la pelea se quedaria esperando eternamente un turno suyo que no va a llegar.
func sacar_a(peer: int) -> void:
	if _espejo or peer == 0 or _state == State.FINISHED:
		return
	_traza_add("SACO al peer %d de la pelea (ya no esta)" % peer)
	for c in _aliados:
		if int(_dueno_aliado.get(c, 0)) == peer:
			_retirar_aliado(c)
	if _aliados_vivos().is_empty():
		_end(false, true)   # no queda nadie: la pelea se cierra
		return
	if _huidos.has(_player):
		# El turno lo tenia el que ya no esta: pasa a alguien en pie y que siga corriendo el ATB, o
		# la pelea se queda esperando eternamente una accion que no va a llegar.
		_player = _aliados_vivos()[0]
		if _esperando_a == peer:
			_fin_de_espera()
		_state = State.ADVANCING
	_set_log("Tu compañero se ha desconectado y sus personajes dejan la pelea.")
	_update_hp()


# Aparta a un aliado de la pelea SIN matarlo: se va de los turnos y del marcador y su bloque queda
# en gris. Es _caer_aliado sin la derrota — y sin borrarlo de _aliados, que es intocable.
func _retirar_aliado(c: Combatant) -> void:
	if c == null or _huidos.has(c):
		return
	_huidos[c] = true
	_gauge.erase(c)
	_defendiendo.erase(c)
	_casteos.erase(c)
	if _timeline != null:
		_timeline.quitar(c)
	var i: int = _aliados.find(c)
	if i >= 0 and i < _bloques_aliados.size():
		var b: Dictionary = _bloques_aliados[i]
		b["panel"].modulate = Color(0.4, 0.4, 0.4)
		b["panel"].add_theme_stylebox_override("panel", _sb_bloque(false))
		b["chips"].visible = false
		# Y se QUITA de la fila, no solo se apaga: la fila no hace wrap (216 px por bloque en un
		# viewport de 1152), asi que si el que huyo sigue ocupando sitio, el bloque del que vuelve a
		# entrar se saldria de la pantalla. Su entrada se queda en _bloques_aliados para no
		# descuadrar los indices, que se cruzan con _aliados.
		b["panel"].visible = false


# Empieza una accion enemiga: se abre el cupo de gasto DEFENSIVO de las imbuiciones. Cada accion
# puede costarle a los tuyos UNA carga como mucho, aunque les salve de un estado Y les recorte el
# daño elemental a la vez, y aunque traiga cinco golpes. Ver Combatant.gastar_imbue_defensiva.
func _abrir_turno_enemigo() -> void:
	for c in _aliados:
		c.imbue_def_gastada = false


# Turno de UN enemigo. 'e' es el que ACTUA (no "el enemigo" a secas): con varios en la
# pelea, cada uno gasta su barra, tiene sus cooldowns y carga lo suyo por separado.
func _enemy_turn(e: Combatant) -> void:
	if _dps_on:
		_turnos_enemigo += 1
	_abrir_turno_enemigo()
	e.tick_cooldowns()   # habilidades del enemigo (KAN-58): baja 1 turno los cooldowns
	# Estados alterados (KAN-58): tick al inicio del turno del enemigo.
	var ev: Dictionary = e.tick_statuses()
	_log_tick(e, ev)
	_dps_add("DoT (estados)", float(ev.get("damage", 0.0)))   # sangrado/veneno/quemadura que le pusiste
	_update_hp()
	if not e.is_alive():
		_set_log("%s cae por el daño de sus estados. ☠" % _etq(e))
		_morir_enemigo(e)   # el DoT lo remata: cae EL, no acaba el combate
		if _vivos().is_empty():
			_end(true)
		else:
			_pausa_lectura()
		return
	if ev.stunned:
		# Aturdir a un enemigo que se estaba CARGANDO cancela su ataque (interrupcion).
		if e.charging != null:
			var interrumpida: String = e.charging.nombre
			e.charging = null
			e.charge_left = 0
			print("[habilidad enemigo] %s ATURDIDO: se le INTERRUMPE %s" % [e.nombre, interrumpida])
			_set_log("%s está aturdido: se le interrumpe %s. 💫" % [_etq(e), interrumpida])
		else:
			_set_log("%s está aturdido y pierde el turno. 💫" % _etq(e))
		_pausa_lectura()   # ya se le resto la barra ATB en _process; pierde la accion
		return

	# ATAQUE DE CARGA en curso: consume un turno cargando; al llegar a 0, se dispara.
	if e.charging != null:
		e.charge_left -= 1
		if e.charge_left > 0:
			_set_log("%s sigue cargando %s... ⚡ (prepárate)" % [_etq(e), e.charging.nombre])
			_pausa_lectura()
			return
		var cargada: AbilityData = e.charging
		e.charging = null
		_enemy_use_ability(e, cargada)
		return

	# INVOCACION (Rey Slime): tiene PRIORIDAD sobre todo lo demas. Si el Rey trae una habilidad de
	# invocacion lista y hay sitio para meter slimes, la lanza SIEMPRE (telegrafiada). Va antes del
	# roll normal para que "siempre que la tenga sin cd" se cumpla, y el gate evita malgastarla con
	# el sequito ya lleno.
	if not _dps_on:
		var inv: AbilityData = _invocacion_lista(e)
		if inv != null:
			_enemy_begin_charge(e, inv)   # carga_turnos > 0 -> se anuncia; aturdirlo la interrumpe
			return

	# Decision: usar una HABILIDAD (si tiene alguna lista y sale la tirada) o atacar normal.
	# En modo muñeco (Saco/Pegador) NO usa habilidades: mantiene limpias las pruebas de DPS/armadura.
	var listas: Array = []
	# SILENCIADO: se queda sin habilidades, igual que tu te quedas sin el boton. Le queda pegar.
	if not _dps_on and not e.silenciado():
		for ab in e.habilidades:
			if e.ability_ready(ab) and ab.invoca_cantidad <= 0:   # la invocacion ya se decidio arriba
				listas.append(ab)
	# A QUIEN va: uno de los tuyos que siga en pie (ver _elegir_objetivo_enemigo). Se decide AQUI,
	# en el momento de pegar, y no al empezar el turno: entre medias puede haber caido alguien.
	var obj: Combatant = _elegir_objetivo_enemigo()
	if obj == null:
		# No queda nadie de los tuyos a quien pegar. Sale con _pausa_lectura (no con un return
		# pelado): el enemigo YA perdio su barra en _process, asi que sin devolver el estado a
		# ADVANCING la pelea se quedaba parada sin que nadie pasara turno.
		_pausa_lectura()
		return
	if not listas.is_empty() and randf() < e.prob_habilidad:
		var elegida: AbilityData = listas[randi() % listas.size()]
		if elegida.carga_turnos > 0:
			_enemy_begin_charge(e, elegida)
		else:
			_enemy_use_ability(e, elegida, obj)
		return

	var pj_obj: PersonajeData = Game.pj_de_combatant(obj)   # a quien se le apunta la excelia
	# La postura de guardia del estoque reduce el daño como el Defender (rama defending).
	var defendiendo: bool = bool(_defendiendo.get(obj, false)) or obj.en_guardia
	var result := StatsMath.resolve_attack(e, obj, defendiendo)
	_debug_ataque(e, obj, result, defendiendo)
	if result.evaded:
		# Excelia: esquivar un golpe entrena Agilidad (en vez de correr en circulos). La entrena
		# EL QUE ESQUIVA, no el que llevas delante.
		Game.ganar("agilidad", _reto(e), Game.GAIN_AGILIDAD_ESQUIVAR,
			Game.RETO_MAX_FISICO, pj_obj)
		Game.contar_esquiva(pj_obj)   # contador oculto de Reflejos
		# CONTRAATAQUE (estoque, KAN-57): en guardia, cada golpe esquivado lo devuelves.
		# Se lo devuelves A QUIEN TE HA ATACADO, no a tu objetivo seleccionado.
		if obj.en_guardia:
			var msg_ev := _contraatacar(e, obj)
			_update_hp()
			if not e.is_alive():
				_morir_enemigo(e)
				_set_log(msg_ev)
				if _vivos().is_empty():
					_end(true)
				else:
					_pausa_lectura()
				return
			_set_log(msg_ev)
			_pausa_lectura()
			return
		_set_log("%s esquiva el ataque de %s. 💨" % [obj.nombre, _etq(e)])
		_update_hp()
		_pausa_lectura()
		return

	var dmg: float = result.damage * e.dummy_dmg_out_mult   # Saco = 0 (no pega)
	obj.take_damage(dmg)
	# El MANTO ha recortado el golpe por su elemento: se le cobra la carga (tope de una por accion).
	if obj.resiste_por_afinidad(e.elemento_ataque):
		obj.gastar_imbue_defensiva()
	Game.desgastar_armadura(pj_obj)   # DURABILIDAD: encajar un golpe gasta un poco SU armadura
	Game.contar_dano_recibido(dmg, pj_obj)   # contador oculto de Autorregeneracion
	if _dps_on:
		_dmg_taken_total += dmg
		_dmg_taken_hits += 1
	# Excelia: la Resistencia sube por la PELIGROSIDAD del enemigo (como el
	# ataque), modulada por el DAÑO recibido (golpe gordo entrena mas). Asi
	# tambien sube bien al principio, cuando el enemigo es un gran reto.
	var dmg_mult: float = clampf(dmg / maxf(1.0, float(obj.max_hp) * 0.1), 0.5, 2.0)
	# El reparto por AGGRO va en el 'base', NO en el reto_val: el reto_val lo capa RETO_MAX_FISICO
	# dentro de ganar(), y con un enemigo duro el bono se lo comeria el techo sin dejar rastro.
	var aggro_mult: float = _mult_resistencia_aggro(obj)
	Game.ganar("resistencia", _reto(e) * dmg_mult, Game.GAIN_RESISTENCIA_GOLPE * aggro_mult,
		Game.RETO_MAX_FISICO, pj_obj)
	# Excelia: si BLOQUEAS (Defender), entrenas Resistencia EXTRA segun cuanto
	# bloquees (escudo grande entrena mas). Formaliza KAN-81 y premia el escudo.
	if bool(_defendiendo.get(obj, false)):
		Game.ganar("resistencia", _reto(e) * obj.defend_block,
			Game.GAIN_RESISTENCIA_BLOQUEO * aggro_mult, Game.RETO_MAX_FISICO, pj_obj)
	var msg: String
	if result.crit:
		msg = "%s CLAVA un critico a %s: %.2f de daño! 💥" % [_etq(e), obj.nombre, dmg]
	else:
		msg = "%s ataca a %s por %.2f de daño." % [_etq(e), obj.nombre, dmg]
	if bool(_defendiendo.get(obj, false)):
		msg += " (defendido 🛡️)"
	# Aturdir/retrasar del enemigo (si algun dia lleva arma contundente).
	if result.aturde:
		msg += _aplicar_aturdir(obj, result.crit)
	# Estados "al golpear" del enemigo (pegajoso/veneno de slimes, KAN-58 Fase 3).
	for nom in e.roll_on_hit(obj):
		msg += "  Le inflige %s." % nom
	_set_log(msg)
	_update_hp()
	e.advance_hand()  # (sin efecto ahora; los enemigos aun no llevan 2 armas)

	if not obj.is_alive():
		_caer_aliado(obj)
		if derrota():
			_end(false)
			return
	_pausa_lectura()


# ============================================================
#  HABILIDADES DEL ENEMIGO (KAN-58)
# ------------------------------------------------------------

# Empieza a cargar un ataque telegrafiado: no pega este turno, lo anuncia. El cooldown
# arranca YA (para que no reintente cargar en cuanto dispare). Aturdirlo mientras carga
# lo cancela (ver _enemy_turn). Te da tus turnos para defender/curarte/reventarlo.
# Devuelve la habilidad de INVOCACION lista de 'e' (Rey Slime) si toca lanzarla, o null. "Toca" =
# la tiene fuera de cooldown Y hay sitio para meter slimes (sequito no lleno). El Rey la prioriza.
func _invocacion_lista(e: Combatant) -> AbilityData:
	for ab in e.habilidades:
		if ab.invoca_cantidad > 0 and e.ability_ready(ab) and _hay_sitio_para_invocar(e):
			return ab
	return null


# ¿Cabe invocar mas slimes al lado de 'e'? False si el escudo ya esta al tope (MAX_ENEMIGOS-1 = 3
# slimes vivos aparte del Rey) o si no hay hueco (ni cadaver reutilizable ni sitio para uno nuevo).
func _hay_sitio_para_invocar(e: Combatant) -> bool:
	var escolta_viva: int = 0
	var hay_hueco: bool = _enemies.size() < MAX_ENEMIGOS
	for c in _enemies:
		if c == e:
			continue
		if not c.is_alive():
			hay_hueco = true   # cadaver: se puede reutilizar su slot
		elif c.es_slime:
			escolta_viva += 1
	return escolta_viva < MAX_ENEMIGOS - 1 and hay_hueco


func _enemy_begin_charge(e: Combatant, ab: AbilityData) -> void:
	e.charging = ab
	e.charge_left = ab.carga_turnos
	e.start_cooldown(ab)
	print("[habilidad enemigo] %s empieza a cargar %s (%d turno%s)" % [
		e.nombre, ab.nombre, ab.carga_turnos, "" if ab.carga_turnos == 1 else "s"])
	_set_log("⚡ %s se prepara para %s. ¡Prepárate! (aturdirlo lo interrumpe)" % [_etq(e), ab.nombre])
	_update_hp()   # pinta YA el chip ⚡ en SU tarjeta (si no, no saldria hasta el proximo refresco)
	_pausa_lectura()


# Ejecuta una habilidad del enemigo: multi-golpe con dano_mult + sus estados (StatusApplication).
# Espejo compacto de _usar_habilidad del jugador (sin energia/dual/excelia de ataque).
# 'victima' = el aliado que se la come. Viene por parametro (no se lee de un global) porque con
# varios de los tuyos en pie cada accion enemiga elige a quien va, y una habilidad CARGADA se
# resuelve turnos despues de anunciarse: para entonces su presa puede haber cambiado.
func _enemy_use_ability(e: Combatant, ab: AbilityData, victima: Combatant = null) -> void:
	var obj: Combatant = victima if victima != null and victima.is_alive() else _elegir_objetivo_enemigo()
	if obj == null:
		_pausa_lectura()   # mismo motivo que en _enemy_turn: su barra ya se gasto, hay que reanudar
		return
	e.start_cooldown(ab)   # instantaneas: cooldown al usar (las cargadas ya lo arrancaron)
	print("[habilidad enemigo] %s usa %s contra %s" % [e.nombre, ab.nombre, obj.nombre])
	var total: float = 0.0
	var golpes: int = 0
	var estados_log: Array = []
	# CONTRAATAQUE del estoque (postura "En guardia"): responde a las habilidades UNA vez (no por
	# golpe). Con varios objetivos, el primero en guardia que esquive es quien contesta.
	var contra_txt: String = ""
	# Aliados que han recibido ALGO (para procesar caidas al final, sean uno o varios).
	var tocados: Array[Combatant] = []
	# Quien encajo la habilidad EN GUARDIA: se dice en el log (si no, con multi-golpe parece que
	# defender no sirvio de nada, cuando en realidad ha tapado todos los golpes).
	var defendieron: Array[Combatant] = []
	# Desglose para el log (como en tus habilidades): rastro golpe a golpe y reparto por aliado.
	var rastro: Array = []
	var dano_por_obj: Dictionary = {}
	if ab.dano_mult > 0.0:
		golpes = ab.num_golpes(1)   # los enemigos usan una sola "mano"
		if ab.es_area():
			# AREA (SPLASH sobre tu grupo): el principal encaja los golpes al 100%; los adyacentes,
			# a area_secundario. Los estados llegan a los lados solo si area_efectos_secundarios.
			for o in _objetivos_area_aliados(ab, obj):
				var t: Combatant = o["c"]
				var esc: float = float(o["escala"])
				var es_princ: bool = t == obj
				var esc_prob: float = 1.0 if es_princ else ab.area_prob_secundario
				var sub := _enemy_resolver_golpes(e, ab, t, golpes, esc, contra_txt == "",
					es_princ or ab.area_efectos_secundarios, esc_prob)
				total += float(sub["total"]); estados_log += sub["estados"]
				rastro += sub["rastro"]; dano_por_obj[t] = float(dano_por_obj.get(t, 0.0)) + float(sub["total"])
				if not tocados.has(t): tocados.append(t)
				if bool(sub["defendio"]) and not defendieron.has(t): defendieron.append(t)
				if String(sub["contra"]) != "": contra_txt = String(sub["contra"])
				if not e.is_alive(): break
		elif ab.reparto_por_golpe:
			# REPARTO POR GOLPE: cada golpe elige un aliado vivo al azar (pueden repetir objetivo).
			# El PRIMER golpe es el principal y va con el peso ENTERO (el aggro y la provocacion
			# mandan igual que en un turno normal: ~80% al que provoca). Los golpes ADICIONALES son
			# metralla: van con el peso ATENUADO, asi que tienden al tanque pero solo un poco. Sin
			# esto, el tanque se comia la tanda entera (~5 de 6) por acumulacion de tiradas.
			# OJO con 'aplicar_efectos': aqui hay UNA llamada a _enemy_resolver_golpes POR GOLPE, asi
			# que su rama de "efectos NO por golpe" (la que debe tirarse una sola vez por habilidad)
			# se disparaba una vez por golpe. Con el Doble Embate del slime (2 golpes x stacks 2)
			# salian 4 stacks de Pegajoso de un solo ataque en vez de 2. Aqui solo se dejan pasar los
			# efectos POR GOLPE; los de la habilidad se tiran una vez, fuera del bucle.
			var principal: Combatant = null
			var conecto_algo: int = 0
			for i in golpes:
				var t: Combatant = _elegir_objetivo_enemigo(i > 0)
				if t == null: break
				if principal == null: principal = t
				var sub := _enemy_resolver_golpes(e, ab, t, 1, 1.0, contra_txt == "",
					ab.efectos_por_golpe)
				total += float(sub["total"]); estados_log += sub["estados"]
				conecto_algo += int(sub["conecto"])
				rastro += sub["rastro"]; dano_por_obj[t] = float(dano_por_obj.get(t, 0.0)) + float(sub["total"])
				if not tocados.has(t): tocados.append(t)
				if bool(sub["defendio"]) and not defendieron.has(t): defendieron.append(t)
				if String(sub["contra"]) != "": contra_txt = String(sub["contra"])
				if not e.is_alive(): break
			# Efectos de la HABILIDAD (no por golpe): una sola tirada, sobre el objetivo PRINCIPAL (el
			# del primer golpe, el que eligio el aggro con peso entero). Mismas condiciones que dentro
			# de _enemy_resolver_golpes: hay que haber conectado algo y seguir vivos los dos.
			if not ab.efectos_por_golpe and conecto_algo > 0 and principal != null \
					and principal.is_alive() and e.is_alive():
				estados_log += _enemy_tirar_efectos(e, ab, principal, 1.0, "objetivo")
		else:
			# SINGLE (de siempre): todos los golpes al mismo objetivo.
			var sub := _enemy_resolver_golpes(e, ab, obj, golpes, 1.0, true, true)
			total = float(sub["total"]); estados_log = sub["estados"]; contra_txt = String(sub["contra"])
			rastro = sub["rastro"]; dano_por_obj[obj] = float(sub["total"])
			tocados.append(obj)
			if bool(sub["defendio"]): defendieron.append(obj)
		print("        total: %.2f de daño en %d golpe%s (%d objetivo%s)" % [
			total, golpes, "" if golpes == 1 else "s", tocados.size(), "" if tocados.size() == 1 else "s"])
	else:
		# Habilidad de PURO ESTADO (sin daño): tira sus efectos a-objetivo. Si es de area (Bramido,
		# Alarido), el debuff cae sobre TODA la fila alcanzada; si no, solo sobre el objetivo.
		if ab.es_area():
			for o in _objetivos_area_aliados(ab, obj):
				var t: Combatant = o["c"]
				estados_log += _enemy_tirar_efectos(e, ab, t, 1.0, "objetivo")
				if not tocados.has(t): tocados.append(t)
		else:
			estados_log += _enemy_tirar_efectos(e, ab, obj, 1.0, "objetivo")
			tocados.append(obj)

	# BUFFS PROPIOS (en_objetivo=false: Furia del minotauro, Fortaleza...): UNA vez por uso, no por
	# objetivo ni por golpe. Van aparte para que un area no los aplique varias veces.
	estados_log += _enemy_tirar_efectos(e, ab, e, 1.0, "self")

	# INVOCACION (Rey Slime): saca hasta invoca_cantidad slimes al azar del pool. Para si se queda
	# sin hueco (sequito lleno / tope de 4). Va aparte del daño/estados: una habilidad podria pegar
	# Y invocar, aunque la del Rey es de pura invocacion (dano_mult 0).
	var invocados: int = 0
	if ab.invoca_cantidad > 0 and not ab.invoca_pool.is_empty():
		for _k in range(ab.invoca_cantidad):
			var pick: EnemyData = ab.invoca_pool[randi() % ab.invoca_pool.size()]
			if not _invocar_slime(pick):
				break   # no cabe ninguno mas
			invocados += 1
		_update_hp()   # refresca los bloques revividos/nuevos (nombre + barra)

	# Mensaje: con daño va el DESGLOSE de dos lineas (mismo helper que tus habilidades: rastro golpe
	# a golpe + reparto por aliado); de puro estado, la cabecera simple (no hay golpes que contar).
	var msg: String
	if ab.dano_mult > 0.0:
		var titulo: String = "%s usa %s" % [_etq(e), ab.nombre]
		if tocados.size() <= 1:
			titulo += " → %s" % _etq(obj)
		var sin_dar: String = "… no te ha dado con ninguno de los %d golpe%s." % [
			rastro.size(), "" if rastro.size() == 1 else "s"]
		msg = _log_desglose(titulo, rastro, tocados, dano_por_obj, total, sin_dar)
	else:
		msg = "%s usa %s" % [_etq(e), ab.nombre]
		msg += " y alcanza a %d de los tuyos." % tocados.size() if tocados.size() > 1 \
			else " contra %s." % _etq(obj)
	if not defendieron.is_empty():
		# La guardia tapa TODOS los golpes del turno; si no se dice, con una habilidad multi-golpe
		# parece que defender no ha servido de nada.
		var nombres_def: Array = []
		for c in defendieron:
			nombres_def.append(c.nombre)
		msg += "  🛡️ %s aguanta%s en guardia (menos daño)." % [
			", ".join(nombres_def), "" if defendieron.size() == 1 else "n"]
	if not estados_log.is_empty():
		# Neutro: las entradas ya dicen "(a sí mismo)" cuando el estado es un buff propio.
		msg += "  Aplica: %s." % ", ".join(estados_log)
	if invocados > 0:
		msg += "  ¡Brotan %d slime%s a su lado! 🟢" % [invocados, "" if invocados == 1 else "s"]
	if contra_txt != "":
		msg += "  " + contra_txt
	_set_log(msg)
	_update_hp()

	if not e.is_alive():
		# El contraataque de la postura lo ha matado en mitad de su propia habilidad: cae EL,
		# el combate solo acaba si era el ultimo que quedaba en pie.
		_morir_enemigo(e)
		if _vivos().is_empty():
			_end(true)
		else:
			_pausa_lectura()
		return
	# Caidas de TODOS los aliados tocados (el area puede tumbar a varios de golpe).
	var alguno_cayo: bool = false
	for t in tocados:
		if not t.is_alive():
			_caer_aliado(t)
			alguno_cayo = true
	if alguno_cayo and derrota():
		_end(false)
		return
	_pausa_lectura()


# Resuelve 'n_golpes' de la habilidad 'ab' del enemigo 'e' sobre UN aliado 't', con 'escala' de daño
# (1.0 = pleno; area_secundario en los adyacentes). 'permitir_contra' deja que t (en guardia)
# devuelva UN golpe. 'aplicar_efectos' decide si t recibe los estados (el principal siempre; los
# adyacentes solo si la habilidad lo pide). Devuelve {total, conecto, estados, contra}.
func _enemy_resolver_golpes(e: Combatant, ab: AbilityData, t: Combatant, n_golpes: int,
		escala: float, permitir_contra: bool, aplicar_efectos: bool, escala_prob: float = 1.0) -> Dictionary:
	var pj_t: PersonajeData = Game.pj_de_combatant(t)
	var defendiendo: bool = bool(_defendiendo.get(t, false)) or t.en_guardia
	var total: float = 0.0
	var conecto: int = 0
	var estados: Array = []
	var contra: String = ""
	var rastro: Array = []   # un token por golpe para el desglose del log (mismo formato que el jugador)
	var esquivados: int = 0  # para la excelia de Agilidad, que se paga UNA vez al final
	for i in n_golpes:
		var result := StatsMath.resolve_attack(e, t, defendiendo)
		if result.evaded:
			print("        [%s] golpe %d: esquivado 💨" % [t.nombre, i + 1])
			Game.contar_esquiva(pj_t)   # contador oculto de Reflejos
			esquivados += 1
			rastro.append({"t": "falla", "c": t})
			if t.en_guardia and permitir_contra and contra == "":
				contra = _contraatacar(e, t)
				if not e.is_alive():
					break
		else:
			var dmg: float = result.damage * ab.dano_mult * escala * e.dummy_dmg_out_mult
			t.take_damage(dmg)
			# Igual que en el golpe basico: si el manto ha recortado el daño, se cobra la carga.
			# El tope por accion hace que una habilidad de cinco golpes cueste una, no cinco.
			if t.resiste_por_afinidad(e.elemento_ataque):
				t.gastar_imbue_defensiva()
			Game.desgastar_armadura(pj_t)   # DURABILIDAD: cada golpe encajado gasta las piezas
			Game.contar_dano_recibido(dmg, pj_t)   # contador oculto de Autorregeneracion
			total += dmg
			conecto += 1
			rastro.append({"t": "💥%.2f" % dmg if result.crit else "%.2f" % dmg, "c": t})
			var et := "[%s] golpe %d: %s %.2f" % [t.nombre, i + 1, ("CRITICO 💥" if result.crit else "acierta"), dmg]
			if ab.efectos_por_golpe and aplicar_efectos:
				var ap: Array = _enemy_tirar_efectos(e, ab, t, escala, "objetivo", escala_prob)
				estados += ap
				if not ap.is_empty():
					et += "  -> " + ", ".join(ap)
			print("        " + et)
		if not t.is_alive():
			break
	# Efectos NO por golpe: una tirada si conecto algo y siguen vivos ambos (un contraataque puede
	# haber matado al enemigo a mitad de su propia habilidad: un muerto no te envenena).
	if aplicar_efectos and not ab.efectos_por_golpe and conecto > 0 and t.is_alive() and e.is_alive():
		estados += _enemy_tirar_efectos(e, ab, t, escala, "objetivo", escala_prob)
	# Excelia: encajar el golpe entrena la Resistencia de QUIEN lo encaja, modulada por el daño.
	# Mismo trato que el ataque BASICO (ver _enemy_turn): que el enemigo use una habilidad en vez de
	# pegar de frente no puede cambiar lo que aprendes de comertelo. Antes esta rama solo pagaba la
	# parte del GOLPE, asi que defender contra las habilidades —justo cuando mas falta hace— no
	# entrenaba nada, y con lo aficionados que son los bichos a las habilidades eso era un agujero
	# gordo en la Resistencia del que hace de tanque.
	var aggro_mult: float = _mult_resistencia_aggro(t)
	if total > 0.0:
		var dmg_mult: float = clampf(total / maxf(1.0, float(t.max_hp) * 0.1), 0.5, 2.0)
		Game.ganar("resistencia", _reto(e) * dmg_mult,
			Game.GAIN_RESISTENCIA_GOLPE * aggro_mult, Game.RETO_MAX_FISICO, pj_t)
		if bool(_defendiendo.get(t, false)):
			Game.ganar("resistencia", _reto(e) * t.defend_block,
				Game.GAIN_RESISTENCIA_BLOQUEO * aggro_mult, Game.RETO_MAX_FISICO, pj_t)
	# Y esquivar entrena Agilidad, igual que en el basico. Se paga UNA sola vez por habilidad y no
	# por golpe esquivado: una de cinco golpes no puede rendir cinco veces mas que un ataque normal.
	# Los golpes de mas suben el reto (aguantar un chaparron es mas dificil que un golpe suelto) pero
	# con tope, para que la habilidad larga sea mejor que la corta sin ser cinco veces mejor.
	if esquivados > 0:
		Game.ganar("agilidad", _reto(e) * minf(float(esquivados), ESQUIVA_HAB_MAX),
			Game.GAIN_AGILIDAD_ESQUIVAR, Game.RETO_MAX_FISICO, pj_t)
	# 'defendio' sube al log: la guardia dura TODO el turno y tapa todos los golpes, pero si no se
	# dice, con una habilidad multi-golpe parece que el escudo no ha hecho nada.
	return {"total": total, "conecto": conecto, "estados": estados, "contra": contra,
		"defendio": defendiendo, "rastro": rastro}


# Tira los estados (StatusApplication) de una habilidad del enemigo 'e'. Respeta 'en_objetivo':
#   true  = al JUGADOR (debuff/DoT; tu resistencia a estados baja la probabilidad).
#   false = A SI MISMO (buff, p.ej. Fortaleza del slime de fuego): siempre prende.
# "A si mismo" es el ENEMIGO QUE LANZA, de ahi que 'e' venga por parametro: con varios bichos,
# leer un campo global haria que un slime se buffease a otro slime.
# N stacks por tirada (a.stacks). Devuelve los nombres aplicados para el log.
# filtro: "todos" = self + a-objetivo; "objetivo" = solo los que van a QUIEN encaja (debuff/DoT, se
# aplican por objetivo del area); "self" = solo los buffs propios (en_objetivo=false), UNA vez por uso.
func _enemy_tirar_efectos(e: Combatant, ab: AbilityData, victima: Combatant, escala_mag: float = 1.0,
		filtro: String = "todos", escala_prob: float = 1.0) -> Array:
	var out: Array = []
	for a in ab.efectos:
		if a.estado < 0:
			continue
		var al_jugador: bool = a.en_objetivo
		if filtro == "objetivo" and not al_jugador:
			continue   # los buffs propios no se reparten por objetivo (se aplican una vez aparte)
		if filtro == "self" and al_jugador:
			continue   # aqui solo van los buffs a si mismo
		# A QUIEN cae. Los buffs propios pueden ir a TODO SU BANDO (a_todo_el_grupo), igual que en la
		# rama del jugador: hoy ningun bicho lo usa, pero las dos ramas tienen que contestar lo mismo
		# — desincronizarlas es exactamente lo que dejo ocho habilidades del jugador sin funcionar.
		var destinos_e: Array = []
		if al_jugador:
			destinos_e.append(victima)
		elif bool(a.a_todo_el_grupo):
			for otro in _vivos():
				destinos_e.append(otro)
		else:
			destinos_e.append(e)
		var objetivo: Combatant = destinos_e[0]
		var nom: String = str(StatusEffects.def(a.estado).get("nombre", "?"))
		if objetivo.es_inmune(a.estado):   # incluye la inmunidad derivada de su AFINIDAD elemental
			# Si lo que te ha librado es el MANTO, se le cobra una carga (no te queman, no te mojan,
			# no te electrizan). Las otras vias de es_inmune no son suyas y no le gastan nada.
			if al_jugador and objetivo.inmune_por_afinidad(a.estado):
				objetivo.gastar_imbue_defensiva()
			continue   # apply_status ya lo avisaria, pero asi no ensucia el log de aplicados
		# Solo los estados que te LANZAN a ti se resisten; los buffs propios siempre prenden.
		# escala_prob < 1.0 en los SECUNDARIOS del area cuando la habilidad lo pide (el lento pilla
		# menos a los lados). No toca a los buffs propios (siempre prenden).
		var p: float = a.prob * (1.0 - victima.resist_estados()) * escala_prob if al_jugador else a.prob
		# ATURDIR: escala igual que el de un golpe fisico o el de un hechizo (ver
		# _aplicar_estado_hechizo). Faltaba SOLO aqui, que es justamente la unica via por la que los
		# enemigos te aturden -- asi que ni la afinidad de Rayo ni stun_resist hacian nada en defensa.
		var p_pelada: float = p   # la misma probabilidad SIN el descuento del manto
		if al_jugador and a.estado == StatusEffects.Id.ATURDIDO:
			p = clampf(p * victima.stun_taken_mult(), 0.0, StatsMath.ATURDIR_MAX)
			p_pelada = clampf(p_pelada * victima.stun_taken_mult(false), 0.0, StatsMath.ATURDIR_MAX)
		var tirada: float = randf()
		if tirada >= p:
			# ¿Te ha salvado el manto? Solo si esta tirada HABRIA entrado sin su descuento.
			if al_jugador and tirada < p_pelada:
				victima.gastar_imbue_defensiva()
			continue
		# escala_mag < 1.0 en los SECUNDARIOS del area: el fuego/veneno que salpica a los lados es
		# de la mitad (misma prob). 1.0 en el principal y en single/reparto.
		var mag: float = StatusEffects.app_magnitude(a, e.atk(), e.motion_value) * escala_mag
		# Aplica los stacks de uno en uno (los independientes/merge suben stack por llamada).
		for d_e in destinos_e:
			if d_e == null or not d_e.is_alive():
				continue
			for _s in maxi(1, a.stacks):
				d_e.apply_status(a.estado, a.turns, mag, 1, false, a.cap, a.mult)
		out.append(nom if al_jugador else "%s (a sí mismo)" % nom)
	return out


# CONTRAATAQUE del estoque (KAN-57): al esquivar en guardia, devuelves el golpe con el arma
# principal (el estoque). Aplica el daño al enemigo y devuelve el texto para el log.
# 'atacante' es QUIEN TE HA GOLPEADO, y no tu objetivo seleccionado: el riposte responde al
# que se te ha echado encima. Si pegase a tu objetivo, con varios enemigos estarias hiriendo
# a uno que no te ha tocado, y a la vez dejando ileso al que si.
# 'quien' es EL QUE ESTABA EN GUARDIA (el que ha esquivado), no necesariamente el que tiene el
# turno: el enemigo pega a cualquiera de los tuyos y el riposte es de quien encaja el golpe.
func _contraatacar(atacante: Combatant, quien: Combatant) -> String:
	quien.set_active_hand(0)   # el estoque va en la mano principal
	var result := StatsMath.resolve_attack(quien, atacante, false)
	_debug_ataque(quien, atacante, result, false)
	if result.evaded:
		return "%s esquiva y contraataca, pero %s lo esquiva. 💨" % [quien.nombre, atacante.nombre]
	var dmg: float = result.damage * quien.guardia_contra_mult
	atacante.take_damage(dmg)
	_apuntar_dano(atacante, dmg, quien)   # contador oculto de Cazador
	_dps_add("Contraataque", dmg)
	_ganar_mana_golpe()   # el riposte es un golpe de arma que conecta: repone maná como los demas
	# Excelia: el contraataque golpea, entrena Fuerza como un ataque normal.
	var pj_contra: PersonajeData = Game.pj_de_combatant(quien)
	Game.ganar("fuerza", _reto(atacante, pj_contra) * quien.motion_value, Game.GAIN_FUERZA_ATAQUE,
		Game.RETO_MAX_FISICO, pj_contra)
	var extra := "un CRITICO 💥 " if result.crit else ""
	return "%s esquiva y CONTRAATACA con el estoque: %s%.2f de daño! 🤺" % [quien.nombre, extra, dmg]


# Congela el ATB una fraccion de segundo tras la accion del enemigo, para poder
# leer el log antes de que sigan llenandose las barras.
func _pausa_lectura() -> void:
	# Espejo de _fin_de_eleccion, para el otro bando: por aqui pasan TODAS las acciones enemigas, asi
	# que es donde se repintan sus chips. Sin esto, un bicho que solo te pone un debuff (sin quitarte
	# vida) no actualizaba nada y el estado no aparecia hasta el siguiente golpe.
	_update_hp()
	_pause_left = ENEMY_TURN_PAUSE
	_state = State.PAUSED


# Acumula daño INFLIGIDO al muñeco por FUENTE y loguea el DPS en vivo (solo modo prueba).
func _dps_add(fuente: String, dmg: float) -> void:
	if not _dps_on or dmg <= 0.0:
		return
	_dmg_dealt[fuente] = float(_dmg_dealt.get(fuente, 0.0)) + dmg
	_dmg_dealt_total += dmg
	var tj: int = maxi(1, _turnos_jugador)
	var te: int = maxi(1, _turnos_enemigo)
	print("[dps] +%.2f (%s) | total %.2f | turnos %d tuyos / %d enemigo | DPS %.2f/tuyo · %.2f/enemigo" % [
		dmg, fuente, _dmg_dealt_total, _turnos_jugador, _turnos_enemigo,
		_dmg_dealt_total / tj, _dmg_dealt_total / te])


# Resumen final de la prueba: DPS medio + desglose por fuente + daño recibido medio.
func _dps_resumen() -> void:
	if not _dps_on:
		return
	var tj: int = maxi(1, _turnos_jugador)
	var te: int = maxi(1, _turnos_enemigo)
	# El modo prueba siempre es 1v1 (ver setup): el muñeco es _enemies[0].
	print("[dps] ===== RESUMEN DE PRUEBA vs %s =====" % _enemies[0].nombre)
	print("[dps] INFLIGIDO: %.2f total | %d turnos tuyos, %d del enemigo | DPS %.2f/tuyo · %.2f/enemigo" % [
		_dmg_dealt_total, _turnos_jugador, _turnos_enemigo, _dmg_dealt_total / tj, _dmg_dealt_total / te])
	var fuentes: Array = _dmg_dealt.keys()
	fuentes.sort_custom(func(a, b): return float(_dmg_dealt[a]) > float(_dmg_dealt[b]))
	for f in fuentes:
		var d: float = float(_dmg_dealt[f])
		print("[dps]    · %s: %.2f (%.1f%%)" % [f, d, 100.0 * d / maxf(1.0, _dmg_dealt_total)])
	if _dmg_taken_hits > 0:
		print("[dps] RECIBIDO: %.2f total en %d golpes | media %.2f/golpe (mitigacion de tu armadura)" % [
			_dmg_taken_total, _dmg_taken_hits, _dmg_taken_total / float(_dmg_taken_hits)])


# CAE UN ENEMIGO. Ojo: esto NO termina el combate (de eso se encargan quienes llaman, mirando
# si quedan vivos). Lo saca del orden de turnos y de la barra de accion, apaga su bloque y, si
# era tu objetivo, te pasa a otro para que la proxima accion no se lance al vacio.
func _morir_enemigo(e: Combatant) -> void:
	if e == null:
		return
	_gauge.erase(e)   # fuera del orden de turnos: ya no acumula barra ni puede actuar
	if _timeline != null:
		_timeline.quitar(e)
	_apagar_bloque(e)
	print("[combate] %s cae (quedan %d en pie)" % [e.nombre, _vivos().size()])
	# Si el que ha caido era tu objetivo, salta al siguiente vivo. _objetivo() ya lo haria
	# solo, pero hay que mover _target_idx para que el borde blanco se pinte donde toca.
	if _target_idx >= 0 and _target_idx < _enemies.size() and _enemies[_target_idx] == e:
		_reseleccionar()


# Pasa el objetivo al siguiente enemigo VIVO (buscando hacia abajo y dando la vuelta desde el
# actual: el de al lado es el candidato mas natural). Si no queda ninguno da igual: el
# llamador esta a punto de terminar el combate.
func _reseleccionar() -> void:
	for i in _enemies.size():
		var idx: int = (_target_idx + 1 + i) % _enemies.size()
		if _enemies[idx].is_alive():
			_seleccionar(idx)
			return


# Cierre COMUN de una accion tuya contra 'obj': lo remata si ha caido y decide si esto se ha
# acabado. Existe para que atacar, usar habilidad y lanzar hechizo no repitan (y desincronicen)
# la misma secuencia de "¿ha muerto? ¿queda alguno? ¿sigo?".
func _tras_accion_jugador(obj: Combatant) -> void:
	_tras_accion_jugador_varios([obj])


# Lo mismo, pero para una accion que ha tocado a VARIOS enemigos (un hechizo de area puede
# tumbar a los 4 de golpe). El remate va SIEMPRE aqui, al final, y nunca en mitad de la
# resolucion: _morir_enemigo mueve _target_idx (_reseleccionar) y te desplazaria el objetivo
# bajo los pies con los golpes a medias. Los cadaveres sin rematar tampoco estorban: _vivos()
# y el salpicon miran is_alive() (los PG), no si la muerte ya esta procesada.
# ATAQUES DE SEGUIMIENTO (estado Escolta): cada vez que uno de los tuyos ATACA, los OTROS aliados
# que lleven Escolta meten un golpe extra al mismo objetivo, a una fraccion del daño.
#
# El golpe usa el atk() del que ESCOLTA (su arma, su critico), no el del que abrio: es su golpe,
# solo que llega detras del de otro.
#
# CORTAFUEGOS: un golpe de seguimiento NO dispara mas seguimientos. Sin la bandera, dos personajes
# con Escolta se rebotarian el uno al otro hasta colgar el juego.
var _en_seguimiento: bool = false

func _disparar_seguimientos(obj: Combatant) -> void:
	if _en_seguimiento or obj == null or not obj.is_alive():
		return
	var escoltas: Array = []
	for al in _aliados_vivos():
		if al != _player and al.has_status(StatusEffects.Id.ESCOLTA):
			escoltas.append(al)
	if escoltas.is_empty():
		return
	_en_seguimiento = true
	var quien_actuaba: Combatant = _player
	for esc in escoltas:
		if not obj.is_alive():
			break
		var pct: float = 0.0
		for e in esc.statuses:
			if e.id() == StatusEffects.Id.ESCOLTA:
				pct = maxf(pct, float(e.d.get("seguimiento_pct", 0.0)))
		if pct <= 0.0:
			continue
		# _player es "quien tiene el turno" en todo el motor de golpes, asi que se le presta un
		# momento al escolta para que el golpe salga con SUS numeros, y se devuelve al acabar.
		_player = esc
		var r := StatsMath.resolve_attack(esc, obj, false)
		if r.evaded:
			_log_extra("%s entra detrás pero %s lo esquiva. 💨" % [esc.nombre, obj.nombre])
		else:
			var dmg: float = float(r.damage) * pct
			obj.take_damage(dmg)
			_apuntar_dano(obj, dmg, esc)
			_log_extra("%s entra detrás: %.2f%s" % [esc.nombre, dmg, " 💥" if r.crit else ""])
		_player = quien_actuaba
	_player = quien_actuaba
	_en_seguimiento = false
	_update_hp()


# Una linea suelta al log sin tocar el mensaje principal de la accion.
func _log_extra(txt: String) -> void:
	print("        [escolta] " + txt)
	_set_log(txt)


func _tras_accion_jugador_varios(objs: Array) -> void:
	# Los seguimientos van ANTES de rematar a los caidos: si el golpe del escolta es el que lo mata,
	# tiene que contar como muerto en esta misma accion y no quedarse "vivo con 0".
	if not objs.is_empty() and objs[0] is Combatant:
		_disparar_seguimientos(objs[0])
	var vistos: Dictionary = {}   # el mismo enemigo puede venir por el area Y por un rebote
	for o in objs:
		if o != null and not o.is_alive() and not vistos.has(o):
			vistos[o] = true
			_morir_enemigo(o)
	if _vivos().is_empty():
		_end(true)
	else:
		_state = State.ADVANCING


func _end(player_won: bool, fled: bool = false) -> void:
	_dps_resumen()
	_player_won = player_won
	_state = State.FINISHED
	_limpiar_casteo()
	_casteos.clear()   # y los conjuros a medias de los demas: la pelea ha terminado para todos
	_ocultar_cajas()
	_continue_button.visible = true
	_continue_button.disabled = false
	_continue_button.text = "Continuar"
	if player_won:
		# MANÁ AL MATAR: el nucleo de CADA enemigo se disuelve en ti, asi que va POR BICHO caido
		# (si ganaste, han caido todos: _enemies los guarda a todos, vivos y muertos) y escala con
		# tu ARMA MAGICA, que es la que sabe sacarle jugo al nucleo. Es la otra mitad del modelo
		# (la primera es el maná por golpe): recuperar magia sale de PELEAR, no de esperar. Huir
		# no lo da: hay que rematar. Va antes de combat_finished, que arrastra el maná.
		var mp_vic: float = 0.0
		# Solo cuentan los enemigos con NUCLEO real (los del mundo): los slimes INVOCADOS por el Rey
		# no dan maná, o el Rey seria un grifo infinito de maná para un mago (invoca -> matas -> maná).
		var kills_reales: int = _enemies.size() - _slots_invocados.size()
		# Lo absorbe CADA UNO de los que siguen en pie, con su propia arma magica: el nucleo se
		# disuelve en el grupo, no solo en el que llevabas delante. Al que cayo no le llega nada.
		for c in _aliados_vivos():
			if c.max_mp <= 0.0 or c.current_mp >= c.max_mp or kills_reales <= 0:
				continue
			var antes: float = c.current_mp
			# El plato de Maná multiplica lo que le saca CADA UNO a los nucleos, asi que va por
			# combatiente y no sobre el total: si solo uno ha comido, solo a el le cunde mas.
			c.regen_mana(StatsMath.mp_por_kill(c.mp_regen_turno, kills_reales) * c.status_mp_kill_mult())
			mp_vic += c.current_mp - antes
			print("[combate] maná de los nucleos para %s: +%.2f (%d enemigo%s, regen del arma %.2f) -> %.2f/%.2f" % [
				c.nombre, c.current_mp - antes, kills_reales, "" if kills_reales == 1 else "s",
				c.mp_regen_turno, c.current_mp, c.max_mp])
		if mp_vic > 0.0:
			_update_hp()
		var caidos: String = _enemies[0].nombre if _enemies.size() == 1 \
			else "%d enemigos" % _enemies.size()
		_set_log("¡GANASTE el combate contra " + caidos + "! 🎉"
			+ ("" if mp_vic <= 0.0 else "  🔷 +%.1f MP." % mp_vic))
	elif fled:
		# Al huir se dice a cuantos dejas atras: si te llevaste a alguno por delante, cuenta.
		var quedan: int = _vivos().size()
		_set_log("Habéis escapado. 🏃  (Dejáis atrás %d enemigo%s en pie)" % [
			quedan, "" if quedan == 1 else "s"])
	else:
		_set_log("Todo el grupo ha caído en combate... 💀")

	# Marca de FIN en consola (cierra el bloque del combate para los Excel).
	var desenlace: String = "huye el grupo" if fled else \
		("gana el grupo" if player_won else "ganan los enemigos")
	var estado_rivales: PackedStringArray = []
	for e in _enemies:
		estado_rivales.append("%s HP %.2f%s" % [e.nombre, e.current_hp, "" if e.is_alive() else " ☠"])
	var estado_mios: PackedStringArray = []
	for c in _aliados:
		estado_mios.append("%s HP %.2f%s" % [c.nombre, c.current_hp, "" if c.is_alive() else " 💀"])
	print("[combate] ===== FIN: %s | %s | %s =====" % [
		desenlace, " | ".join(estado_mios), " | ".join(estado_rivales)])

	# Y SE AVISA A LOS ESPEJOS DE QUE ESTO SE HA ACABADO. Va aqui, al final y SIN condicion: el flag
	# "fin" viaja dentro de la instantanea y es lo unico que enciende el boton Continuar al otro lado.
	# Antes la unica instantanea que salia de _end era la del `if mp_vic > 0.0: _update_hp()` de mas
	# arriba, o sea que el aviso solo llegaba cuando alguien ganaba mana. Si el combate acababa por
	# HUIDA, por DERROTA, o por victoria sin mana (nadie con arma magica, o todos a tope), el espejo
	# no se enteraba y "Continuar" le salia solo al que llevaba la pelea. Al ir despues del reparto de
	# mana, la foto que se manda ya lleva las vidas y el mana definitivos.
	_difundir()


# Log-HISTORIAL: cada evento se apila como una frase nueva (antes era una sola linea que se
# sobrescribia y no daba tiempo a leer los DoT / lo que aplicabas). Evita duplicar la misma
# consecutiva.
#
# LOG_MAX son FRASES guardadas, no lineas pintadas: desde que el log vive en su columna, cada frase
# ocupa las lineas que necesite y lo que sobra por arriba lo recorta la caja (ver _montar_log). Se
# guardan de sobra —el limite de verdad es el sitio— y ya no hace falta rellenar con lineas vacias
# para cuadrar un alto fijo.
const LOG_MAX := 20
var _log_lines: Array[String] = []

func _set_log(texto: String) -> void:
	if _log_lines.size() > 0 and _log_lines[_log_lines.size() - 1] == texto:
		return
	_log_lines.append(texto)
	while _log_lines.size() > LOG_MAX:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)
	_recolocar_log()


# Aplica el aturdir a un objetivo y devuelve el texto para el log. Dos niveles (KAN-58):
#  - CRITICO -> aplica el ESTADO Aturdido (pierde su proximo turno, via el motor de
#    estados; se ve el 💫 en su etiqueta y lo gestiona el tick del turno).
#  - normal  -> retraso PARCIAL de barra ATB (stagger; pierde tempo, no el turno).
func _aplicar_aturdir(objetivo: Combatant, es_crit: bool) -> String:
	if es_crit:
		objetivo.apply_status(StatusEffects.Id.ATURDIDO)
		return "  ¡ATURDIDO! 💫 (pierde el turno)"
	var f: float = randf_range(ATB_STUN_MIN, ATB_STUN_MAX)
	# Sin recorte a 0: si la barra ya estaba baja, el retraso debe notarse igual
	# (recortar a 0 lo dejaba igual que si no hubiera aturdido nada).
	# El has() NO es defensivo de adorno: a un muerto se le ha hecho erase de _gauge, y tocar
	# una clave que no existe la CREARIA -> volveria al orden de turnos y su marcador
	# reaparecia en la barra de accion. Un mazazo al cadaver no lo devuelve a la pelea.
	if _gauge.has(objetivo):
		_gauge[objetivo] -= UMBRAL * f
	return "  ¡Retrasado! 💫"


# Log de DESARROLLO (consola): probabilidades reales de esquiva/crit/aturdir de
# CADA ataque, con las stats implicadas, para afinar la curva en cada situacion.
func _debug_ataque(atacante: Combatant, defensor: Combatant, r: Dictionary, bloqueando: bool = false) -> void:
	var outcome: String = "esquivado" if r.evaded else ("CRITICO" if r.crit else "golpe")
	if r.aturde:
		outcome += "+ATURDE"
	if bloqueando and not r.evaded:
		outcome += "+BLOQUEO"
	var mano: String = atacante.current_hand_name()
	var quien: String = atacante.nombre + ("[" + mano + "]" if mano != "" else "")
	# Desglose de la IMBUICION: cuanto del dmg es la porcion elemental y con que multiplicador
	# (x1.5 contra un debil, x0.5 contra un resistente). Sin esto el bonus era invisible.
	var imb: String = ""
	var d_imb: float = float(r.get("dmg_imbue", 0.0))
	if d_imb > 0.0:
		# El daño elemental va DENTRO del dmg, no encima: por eso se resta para sacar el fisico.
		imb = " (%.2f fis + %.2f %s x%.2f)" % [
			maxf(0.0, float(r.damage) - d_imb), d_imb,
			Elementos.nombre(atacante.imbue_elemento), float(r.get("mult_imbue", 1.0))]
	print("[combate] %s(Dex %d) -> %s(Agi %d) | esquiva:%.1f%% crit:%.1f%% aturdir:%.1f%% | ATK:%.2f dmg:%.2f%s | %s" % [
		quien, atacante.abilities.destreza,
		defensor.nombre, defensor.abilities.agilidad,
		r.evade_p * 100.0, r.crit_p * 100.0, r.aturde_p * 100.0,
		atacante.atk(), r.damage, imb, outcome])


# Poder de UN enemigo (suma de sus habilidades) para la dificultad relativa de la excelia.
# El enemigo va por PARAMETRO y no leyendo un campo: con varios a la vez, "el enemigo" no es
# uno solo, y quien entrena la stat es el bicho CONCRETO con el que acabas de medirte (al que
# has pegado, o el que te ha pegado a ti). Sin esto, entrenarias con el reto del que no era.
func _poder_enemigo(c: Combatant) -> float:
	if c == null or c.abilities == null:
		return 0.0
	var a: Abilities = c.abilities
	return float(a.fuerza + a.resistencia + a.destreza + a.agilidad + a.magia)


# Dificultad relativa contra ESTE bicho. Pasa su NIVEL (el tier del contenido, de EnemyData.level)
# ademas de su poder: Game.reto() lo necesita para saber contra que medirte (tu progreso de este
# nivel si el bicho es de tu nivel o superior, tu acumulado de por vida si es de uno anterior).
# 'pj' = contra QUIEN se mide el reto (null = el lider). Cada aliado tiene su propio poder
# acumulado, asi que el mismo slime es un reto distinto para la veterana que para el novato: al
# que va flojo le entrena mas, que es justo lo que hace que un companero nuevo se ponga al dia.
func _reto(c: Combatant, pj: PersonajeData = null) -> float:
	if c == null:
		return 0.0
	return Game.reto(_poder_enemigo(c), c.level, pj)


# Crea la linea de orden de turnos (banda horizontal en la zona media).
# EL ASPECTO de un aliado en el marcador de turnos: su color y su cara, los mismos con los que lo
# llevas por la mazmorra. Sale de su ficha si la tengo; si no la tengo -en el ESPEJO no hay fichas
# locales-, del aspecto que vino en el roster. Sin esto, en el espejo TODOS salian de un gris casi
# blanco (el caso de "prueba F6, sin ficha detras") y no se distinguia a nadie.
func _color_de(c: Combatant) -> Color:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj != null:
		return pj.color
	return c.color_visual


func _material_de(c: Combatant) -> ShaderMaterial:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj != null:
		return Game.material_de(pj)
	# En el espejo la cara viaja en el roster (bytes PNG) y se cachea en el propio maniqui.
	return _mat_espejo.get(c, null)


func _crear_timeline() -> void:
	_timeline = preload("res://scripts/ui/turn_timeline.gd").new()
	# Anclada ABAJO DEL TODO (full width, ultimos 80 px) para no pisar la zona de botones.
	_timeline.anchor_left = 0.0
	_timeline.anchor_right = 1.0
	_timeline.anchor_top = 1.0
	_timeline.anchor_bottom = 1.0
	_timeline.offset_top = -80.0
	_timeline.offset_bottom = 0.0
	# Solo dibuja -> IGNORE (que no robe clics a lo que quede por encima).
	_timeline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timeline)
	# Un marcador por cada uno de los tuyos, con el aspecto de SU cubo: el mismo color, la misma
	# imagen y el mismo metal que en el mapa (material_de() puede devolver null, y es correcto: un
	# cuerpo mate sin imagen se pinta solo con su color). Sin texto: se reconocen por la pinta,
	# que es la misma con la que los llevas por la mazmorra.
	for c in _aliados:
		_timeline.anadir(c, _color_de(c), _material_de(c), "")
	# Cada enemigo con su color del mapa y su NUMERO, el mismo que lleva su bloque arriba.
	for i in _enemies.size():
		_timeline.anadir(_enemies[i], _enemies[i].color_visual, null, str(i + 1))


func _update_timeline() -> void:
	if _timeline == null:
		return
	var ratios: Dictionary = {}
	for c in _gauge:
		ratios[c] = _gauge[c] / UMBRAL
	_timeline.set_ratios(ratios)


# ============================================================
#  DEV/TEST de estados (KAN-58 Fase 1): panel abajo-dcha (cerrable con su toggle)
#  para aplicar estados a mano al enemigo o al jugador y ver el motor funcionando
#  (tick, stacks, stat, aturdido). Se retirara cuando esten enganchados a todo.
# ============================================================
var _dev_target_enemy: bool = true
var _estados_panel: PanelContainer = null

func _crear_estados_dev() -> void:
	# Boton toggle (abajo-dcha, siempre visible) para cerrar/abrir el panel dev.
	var toggle := Button.new()
	toggle.text = "ESTADOS (dev)"
	toggle.toggle_mode = true
	toggle.button_pressed = false   # arranca CERRADO (el tester lo abre si lo necesita)
	toggle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle.offset_right = -8
	toggle.offset_bottom = -88   # por ENCIMA de la barra ATB del fondo (80 px + 8 de margen)
	toggle.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toggle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toggle.toggled.connect(func(on: bool): _estados_panel.visible = on)
	add_child(toggle)

	# Panel anclado ABAJO-dcha; crece hacia ARRIBA (encima del toggle). No tapa el HP.
	_estados_panel = PanelContainer.new()
	_estados_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_estados_panel.offset_right = -8
	_estados_panel.offset_bottom = -120   # justo encima del boton toggle (que ahora esta a -88)
	_estados_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_estados_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_estados_panel.custom_minimum_size = Vector2(260, 0)
	_estados_panel.visible = false   # cerrado de base (coincide con el toggle sin pulsar)
	add_child(_estados_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_estados_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "ESTADOS (dev/test)"
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(title)

	# "Enemigo" = el que tengas SELECCIONADO. Asi el panel hereda gratis la seleccion por clic
	# y no hace falta un segundo selector de 4 entradas aqui dentro.
	var tgt := CheckButton.new()
	tgt.text = "Objetivo: Enemigo sel."
	tgt.button_pressed = true
	tgt.toggled.connect(func(on: bool):
		_dev_target_enemy = on
		tgt.text = "Objetivo: Enemigo sel." if on else "Objetivo: Jugador")
	vb.add_child(tgt)

	var flow := HFlowContainer.new()
	vb.add_child(flow)
	# Veneno: un solo boton; cada pulsacion = +1 stack (y cada stack DUPLICA el daño).
	var bv := Button.new()
	bv.text = "☠ Veneno +stack"
	bv.pressed.connect(_dev_veneno)
	flow.add_child(bv)
	# Sangrado: magnitud = escala con el ATAQUE del aplicador (el bando contrario al objetivo).
	var bs := Button.new()
	bs.text = "🩸 Sangrado"
	bs.pressed.connect(_dev_sangrado)
	flow.add_child(bs)
	# Resto de estados: magnitud/duracion por defecto del catalogo.
	for id in StatusEffects.all_ids():
		if int(id) == StatusEffects.Id.VENENO or int(id) == StatusEffects.Id.SANGRADO:
			continue
		var d: Dictionary = StatusEffects.def(id)
		var b := Button.new()
		b.text = "%s %s" % [d.get("icono", "?"), d.get("nombre", "?")]
		b.pressed.connect(_dev_aplicar_estado.bind(int(id)))
		flow.add_child(b)
	var clr := Button.new()
	clr.text = "Limpiar"
	clr.pressed.connect(_dev_limpiar_estados)
	flow.add_child(clr)


func _dev_target() -> Combatant:
	return _objetivo() if _dev_target_enemy else _player

# Aplicador para estados que escalan con quien los lanza: el bando CONTRARIO al objetivo.
func _dev_aplicador() -> Combatant:
	return _player if _dev_target_enemy else _objetivo()

func _dev_aplicar_estado(id: int) -> void:
	_dev_target().apply_status(id)
	_update_hp()
	var d: Dictionary = StatusEffects.def(id)
	_set_log("[dev] Aplicado %s a %s." % [d.get("nombre", "?"), _dev_target().nombre])

func _dev_veneno() -> void:
	_dev_target().apply_status(StatusEffects.Id.VENENO)   # +1 stack (dev: sin cap)
	_update_hp()
	_set_log("[dev] Veneno +1 stack a %s." % _dev_target().nombre)

func _dev_sangrado() -> void:
	var ap: Combatant = _dev_aplicador()
	var mag: float = StatusEffects.sangrado_magnitude(ap.atk(), ap.motion_value)
	_dev_target().apply_status(StatusEffects.Id.SANGRADO, -1, mag)
	_update_hp()
	_set_log("[dev] Sangrado +1 stack (%.1f/stack · escala con %s) a %s." % [
		mag, ap.nombre, _dev_target().nombre])

func _dev_limpiar_estados() -> void:
	_dev_target().statuses.clear()
	_update_hp()


# Crea un fondo opaco a pantalla completa, por DETRAS de la interfaz.
func _anadir_fondo() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # que no robe los clics al boton
	add_child(bg)
	move_child(bg, 0)  # al fondo (los hermanos siguientes se dibujan encima)


# Prepara la columna: la fila de enemigos va arriba del todo, antes del log y de los botones.
# La columna sigue ocupando la pantalla ENTERA (como siempre): lo que tiene ancho fijo son los
# BLOQUES de enemigo, no el escenario.
func _montar_columna() -> void:
	_col = $VBox
	_col.mouse_filter = Control.MOUSE_FILTER_PASS
	# Se le deja libre a la derecha el ancho de la columna del log. El borde seguro del aparato va
	# aparte (ver Tactil.borde).
	_col.offset_right = -ANCHO_LOG - 32.0 - Tactil.borde.x
	_col.offset_left = Tactil.borde.x
	_col.offset_top = Tactil.borde.y
	# Dos filas simetricas, ellos arriba y los tuyos debajo. Centradas: con 1 o 2 bloques la fila
	# queda en medio de la pantalla en vez de pegada a la izquierda con un hueco raro al lado.
	_bloques_box = _crear_fila_bloques()
	_col.move_child(_bloques_box, 0)
	_montar_log()


# EL HISTORIAL, en una columna a la derecha. Antes vivia abajo a la izquierda, en una linea por
# frase recortada a lo que cupiera, y con un alto fijo de LOG_MAX lineas para que los botones no
# bailaran debajo. Ahora que los botones estan en la otra esquina, nada de eso hace falta:
#
#   - Cada frase se PARTE en las lineas que necesite (autowrap) en vez de recortarse. Lo que decia
#     un golpe entero se lee entero.
#   - El limite ya no son 6 lineas, es EL SITIO: la columna llega desde arriba hasta un poco por
#     encima de la linea de accion.
#   - El texto se pega ABAJO y crece hacia arriba, con la caja recortando por el techo: lo ultimo
#     que ha pasado esta siempre a la vista, y lo viejo se va por arriba solo.
const ANCHO_LOG := 460.0
var _log_caja: Control = null


func _montar_log() -> void:
	_log_caja = Control.new()
	_log_caja.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_log_caja.offset_left = -ANCHO_LOG - 16.0 - Tactil.borde.x
	_log_caja.offset_right = -16.0 - Tactil.borde.x
	_log_caja.offset_top = 16.0 + Tactil.borde.y
	_log_caja.offset_bottom = -HUECO_TIMELINE - Tactil.borde.y
	# Lo que se sale por arriba se CORTA (no se dibuja encima de los bloques): es lo que deja que el
	# texto crezca hacia arriba sin limite aparente y que lo viejo se pierda solo.
	_log_caja.clip_contents = true
	_log_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_caja)

	_log.get_parent().remove_child(_log)
	_log_caja.add_child(_log)
	_log.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_log.offset_left = 0.0
	_log.offset_right = 0.0
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.clip_text = false
	_log.add_theme_font_size_override("font_size", 18)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Al cambiar el tamaño de la ventana el ancho cambia, y con el las lineas que ocupa cada frase.
	_log_caja.resized.connect(_recolocar_log)


# Pega el texto al SUELO de su caja y lo deja crecer hacia arriba. Se hace a mano y no con anclajes
# porque un Label con autowrap calcula su alto a partir de su ANCHO, y con los anclajes de abajo el
# ancho todavia no estaba resuelto cuando Godot pedia la altura: salia un alto absurdo (medido:
# 22907 px con ocho frases) y el texto se iba de la pantalla.
func _recolocar_log() -> void:
	if _log == null or _log_caja == null or _log_caja.size.x < 10.0:
		return
	var alto: float = _log.get_combined_minimum_size().y
	_log.offset_top = _log_caja.size.y - alto
	_log.offset_bottom = _log_caja.size.y


# Una fila de bloques de combatiente (enemigos o tuyos), colgada de la columna.
# Lo que mide cada bloque cuando hay 'n' en su fila. A su ancho preferido mientras quepan, y
# encogiendose a partes iguales cuando no. El sitio disponible se calcula igual que los offsets de
# la columna (ver _montar_columna): la pantalla menos la columna del log y los margenes.
func _ancho_bloque(n: int) -> float:
	if n <= 1:
		return ANCHO_BLOQUE
	var disponible: float = get_viewport_rect().size.x - ANCHO_LOG - 32.0 \
		- Tactil.borde.x * 2.0 - 16.0
	return clampf((disponible - SEP_BLOQUES * float(n - 1)) / float(n),
		ANCHO_BLOQUE_MIN, ANCHO_BLOQUE)


# Reajusta el ancho de los bloques de una fila. Hace falta porque la fila CRECE a mitad de pelea:
# entran refuerzos, se une el compañero... y lo que cabia con tres deja de caber con cinco.
func _reajustar_anchos(bloques: Array, n: int) -> void:
	var ancho: float = _ancho_bloque(n)
	for b in bloques:
		var panel: Control = b.get("panel")
		if panel != null and is_instance_valid(panel):
			panel.custom_minimum_size = Vector2(ancho, 0)


func _crear_fila_bloques() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", SEP_BLOQUES)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.mouse_filter = Control.MOUSE_FILTER_PASS
	_col.add_child(fila)
	return fila
