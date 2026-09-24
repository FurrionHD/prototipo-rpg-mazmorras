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

# --- LOS TEMAS de esta pantalla, cada uno en su archivo (ver su cabecera) ---
# Aqui se queda el MOTOR: preparar la pelea (setup), el estado por aliado, el ATB y los turnos
# (_process, _begin_player_turn), las acciones basicas (atacar, defender, huir), cerrar la pelea (_end)
# y los ayudantes que usa todo lo demas (_update_hp, _vivos, _set_log...). Cada tema es un RefCounted
# con esta pantalla en _pantalla, y se llama como <tema>.<funcion>:
#   objetos      pociones y a quien se las das          habilidades  submenu, cargas y resolucion
#   magia        hechizos, recitado y disparo            enemigos     su turno, habilidades y contraataques
#   objetivos    a quien se pega (amenaza, cobertura)    figuras      tarjetas, sprites y poses
#   geo          a quien MAS alcanza (la geometria)
#   altas        quien entra y sale a media pelea        efectos      barras, golpes y chips de estado
#   diagnostico  tecla P y herramientas de dev           montaje      construir la pantalla una vez
#   espejo       la pelea compartida en multi
# Lo que la red o Game llaman por su nombre queda como PUENTE al final de este archivo. Comprobar tras
# tocar: tools/verificar_pantalla.py y la huella del combate (tools/prueba_huella_combate.tscn).
const CombatObjetos = preload("res://scripts/ui/combat_objetos.gd")
var objetos = CombatObjetos.new(self)
const CombatHabilidades = preload("res://scripts/ui/combat_habilidades.gd")
var habilidades = CombatHabilidades.new(self)
const CombatMagia = preload("res://scripts/ui/combat_magia.gd")
var magia = CombatMagia.new(self)
const CombatEnemigos = preload("res://scripts/ui/combat_enemigos.gd")
var enemigos = CombatEnemigos.new(self)
const CombatObjetivos = preload("res://scripts/ui/combat_objetivos.gd")
var objetivos = CombatObjetivos.new(self)
const CombatGeometria = preload("res://scripts/ui/combat_geometria.gd")
var geo = CombatGeometria.new(self)
const CombatFiguras = preload("res://scripts/ui/combat_figuras.gd")
var figuras = CombatFiguras.new(self)
const CombatAltas = preload("res://scripts/ui/combat_altas.gd")
var altas = CombatAltas.new(self)
const CombatEfectos = preload("res://scripts/ui/combat_efectos.gd")
var efectos = CombatEfectos.new(self)
const CombatDiagnostico = preload("res://scripts/ui/combat_diagnostico.gd")
var diagnostico = CombatDiagnostico.new(self)
const CombatMontaje = preload("res://scripts/ui/combat_montaje.gd")
var montaje = CombatMontaje.new(self)
# EL MONTAJE ALTERNATIVO: la misma pelea, puesta en escena sobre el mapa en vez de en dos filas de
# tarjetas. Hereda del de arriba y solo cambia tres funciones (ver su cabecera). Se enchufa en
# _ready cuando la pelea es TACTICA.
const CombatMontajeMapa = preload("res://scripts/ui/combat_montaje_mapa.gd")
const CombatFigurasMapa = preload("res://scripts/ui/combat_figuras_mapa.gd")
var figuras_mapa = CombatFigurasMapa.new(self)
const CombatFichaObjetivo = preload("res://scripts/ui/combat_ficha_objetivo.gd")
var ficha_objetivo = CombatFichaObjetivo.new(self)
# EL TURNO EN EL MAPA: quien anda y cuanto (tu circulo de movimiento, el acercamiento del enemigo y
# el borde que propone huir). Solo lo miran _process y el reparto de turno; no resuelve daño.
const CombatTactico = preload("res://scripts/ui/combat_tactico.gd")
var turno_mapa = CombatTactico.new(self)

# ¿Esta pelea se juega EN EL MAPA? Lo pone Game antes de setup(). Es lo unico que distingue los dos
# combates, y solo puede mirarlo la GEOMETRIA y la PUESTA EN ESCENA: si acaba dentro de una funcion
# que resuelve daño, la costura esta en el sitio equivocado.
var tactico: bool = false
# La arena de la pelea tactica, en CELDAS. La pone quien la calcula (Game._abrir_pelea) y viaja a los
# espejos en el roster: la calcula UNA maquina, nunca cada una la suya.
var arena_celdas: Rect2i = Rect2i()
const CombatEspejo = preload("res://scripts/ui/combat_espejo.gd")
var espejo = CombatEspejo.new(self)

const UMBRAL := 100.0          # cuanto llenar la barra para actuar
# EL MAS RAPIDO DE LA PELEA llena la barra en este tiempo (a x1), y los demas en proporcion a su
# velocidad. Antes el ritmo era fijo (velocidad x 10) y en los primeros pisos, con todos lentos, una
# barra tardaba casi 4 s: lo pidio el usuario.
const SEGUNDOS_BARRA_MAS_RAPIDO := 1.0
const INICIATIVA_VENTAJA := 50.0  # media barra de ventaja para quien inicia

# Si entras AGOTADO, tus primeras acciones van mas lentas.
const EXHAUSTED_SLOW_ACTIONS := 2   # cuantas acciones afectadas
const EXHAUSTED_RATE := 0.5         # a que ritmo (0.5 = la mitad)

# Huir (KAN-55): entrar agotado dificulta la huida (la probabilidad se multiplica).
const FLEE_EXHAUSTED_MULT := 0.6


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
# PASAR el turno en el mapa tambien repone energia (lo pidio el usuario el 24/09), pero MENOS que
# pegar: si repusiera lo mismo, quedarse quieto saldria gratis. Fraccion de lo que da tu basico.
const PASAR_ENERGIA_FRAC := 0.5


@onready var _log: RichTextLabel = $VBox/Log
# La escena trae un unico boton (AttackButton). Ahora las 4 acciones se crean por
# codigo (barra de acciones, KAN-55) y ESE boton se reutiliza como "Continuar" al
# terminar el combate.
@onready var _continue_button: Button = $VBox/AttackButton

# Fila de los ENEMIGOS: van uno AL LADO DEL OTRO, no apilados.
var _bloques_box: HBoxContainer = null


# --- EL REPARTO DE LA PANTALLA ---------------------------------------------------------------
const MARGEN_UI := 16.0
# El SITIO del sprite dentro de la columna. Solo fija el ALTO: el ancho lo hereda de la columna,
# que lo marca la tarjeta.
#
# Y tiene que ser asi. Con un ancho minimo propio, la columna no podia encoger por debajo de el:
# al tope de cinco enemigos la tarjeta se aprieta a 130 px, el hueco del sprite seguia exigiendo
# 136, y las cinco columnas ya no cabian entre la barra de accion y el registro -- la quinta se
# metia por debajo del panel de la derecha.
const ALTO_ACTOR := 208.0
# EL PRESUPUESTO VERTICAL, que va justo y hay que cuadrarlo a mano. Cada banda se ancla a SU borde
# con una altura fija; si se dejara que la marcara el contenido, un Container anclado por un solo
# lado se queda con altura cero y se va de la pantalla (la banda de abajo desaparecia entera).
#
#   16 + 306 (ellos) + ... 44 de aire ... + 338 (los tuyos) + 16 = 720
#
# Las tarjetas: la enemiga son ~94 px (nombre + una fila de estados + vida) y la tuya ~126, que
# lleva ademas las barras de energia y maná. Si alguna crece, lo que se come es el aire del medio.
const ALTO_TARJETA_ENE := 94.0
const ALTO_TARJETA_ALI := 126.0
const SEP_COLUMNA := 4.0

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

# TODO lo que se mueve y brilla (particulas de estado, tinte, embestidas, numeros de daño).
# Es una capa PASIVA: no decide nada de la pelea, solo pinta lo que le cuentan desde aqui. Ver
# scripts/fx/combat_fx.gd.
var _fx: CombatFX = null

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

# FICHA DE DETALLE (estilo HSR): se crea a la primera y se reusa. Y el contador del "mantener
# pulsado" que la abre sobre un combatiente (1 s quieto, como ficha_tactil pero con mas margen).
var _detalle: CombateDetalle = null
var _boton_detalle: Button = null
# El panel de volumen que abre la ESC (ver _alternar_ajustes). Se monta la primera vez que se pide.
var _ajustes: Control = null

var _hold_c: Combatant = null
var _hold_t: float = 0.0
var _hold_pos: Vector2 = Vector2.ZERO
const HOLD_MOV_MAX := 14.0
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

# --- MODO ESPEJO (hito 5.4-C): peleas COMPARTIDAS -------------------------------------------
# La pelea la EJECUTA una sola maquina (la de quien la abrio). Los demas participantes abren esta
# misma pantalla en modo ESPEJO: no simulan nada -ni ATB, ni dados, ni resolucion- y se limitan a
# pintar las instantaneas que les llegan. Es el mismo principio que remote_enemy con el mundo, pero
# aplicado a una pelea entera, y es lo que permite reusar TODA la interfaz (bloques, barras, log,
# marcador de turnos) sin tocarla.
var _espejo := false

# --- VELOCIDAD DE ESTA PELEA -----------------------------------------------------------------
# 1.0 o 2.0. Manda SIEMPRE el DUEÑO de la pelea: el que la simula. Si te unes a la de un compañero
# que juega a x2, la ves a x2 para ir a su ritmo; cuando el se une a la tuya, la ve a la tuya.
#
# Por eso el espejo NO la elige (su boton va deshabilitado) y la recibe en cada instantanea: si el
# dueño la cambia a mitad de pelea, al otro le cambia sola. Guardarla por tu lado y aplicarla en la
# pelea de otro descuadraria las dos pantallas -- uno veria el turno resuelto y el otro aun
# animando-, que es justo la clase de desincronizacion que cuesta horas de encontrar.
var _vel_pelea: float = 1.0
var _boton_vel: Control = null
# De quien es cada aliado que NO es mio: Combatant -> peer_id. Solo lo llena el anfitrion. Cuando
# le toca el turno a uno de estos, no se enseñan los botones aqui: se le pide la accion a su dueño,
# que es quien tiene que decidir. Los mios no estan en este diccionario.
var _dueno_aliado: Dictionary = {}
# Los que se HAN IDO por su propio pie (huida). No se sacan de _aliados -ese array se cruza por
# INDICE con Game._active_player_pjs y combat_finished devuelve por posicion-, se apartan aqui: se
# filtran en _aliados_vivos(), que es el embudo de a quien pegan, quien recibe area, cuando se
# pierde y quien cobra el mana de la victoria.
var _huidos: Dictionary = {}
# COBERTURAS que llegaron por red y todavia son un INDICE, no un puntero (Combatant -> int). Vive
# entre _aplicar_volatil y _reenlazar_coberturas, y se vacia ahi mismo. Solo se llena en el traspaso
# de anfitrion: en una pelea normal esta siempre vacio.
var _cobertura_pendiente: Dictionary = {}
# La cara de cada maniqui del espejo (Combatant -> ShaderMaterial), montada desde el PNG que viene
# en el roster. Aqui no hay fichas locales de las que sacarla.
var _mat_espejo: Dictionary = {}
# Estoy parado esperando la accion de otro (el ATB no corre, ver _process y State.WAITING_PLAYER).
var _esperando_a: int = 0

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

# CUANTO DURA UN TURNO cuando ya se ha resuelto. Las barras ATB se congelan mientras tanto (ver
# _process). El combate corre con el arbol en pausa, pero esta escena tiene PROCESS_MODE_ALWAYS,
# asi que el tiempo (delta) sigue corriendo.
#
# MANDA LA ANIMACION: si la accion ha tenido golpes, el turno dura EXACTAMENTE lo que dure la
# embestida (0.55 s un golpe suelto, hasta 1.4 s una racha larga) y detras no queda tiempo muerto.
# Antes habia un segundo fijo de "para que te de tiempo a leer" que era eso: un segundo parado.
#
# La constante de abajo es solo para los turnos en los que NO hay nada que animar -- estas
# aturdido, el bicho invoca, o te mete un debuff sin quitarte vida. Ahi si hace falta un respiro,
# o el log pasa volando y no te enteras de lo que te acaban de hacer.
const PAUSA_SIN_GOLPE := 0.5   # segundos
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
		altas._desambiguar(c)
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
	# ¿Es una prueba de muñeco? Basta con que lo sea el primero: la conversion es de la pelea
	# entera (ver Game.volver_muneco), refuerzos incluidos. Ya NO es 1v1 -- en la arena se entra en
	# grupo como en cualquier combate --, asi que con varios el DPS por turno enemigo va repartido
	# entre todos los que peguen (el resumen final lo avisa).
	_dps_on = not _enemies.is_empty() and _enemies[0].es_dummy


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
# Lo que se multiplica por la velocidad de cada uno para llenar su barra: el mas rapido de los que
# siguen en pie la llena en SEGUNDOS_BARRA_MAS_RAPIDO. Se mira cada fotograma, asi que si cae el mas
# rapido (o entra uno nuevo) el ritmo se reajusta solo.
#
# El mas rapido se mide con la velocidad de REFERENCIA (sin estados, guardia ni imbuicion; ver
# Combatant.spd_referencia): si contara el Ralentizado, frenar al mas rapido no lo frenaria a el,
# aceleraria a todos los demas.
func _escala_barra() -> float:
	var vmax: float = 0.0
	for c in _aliados_vivos():
		vmax = maxf(vmax, c.spd_referencia())
	for e in _vivos():
		vmax = maxf(vmax, e.spd_referencia())
	return UMBRAL / (SEGUNDOS_BARRA_MAS_RAPIDO * maxf(vmax, 0.01))


# Al cerrarse la pantalla, los cuerpos del mapa vuelven a animarse como antes de la pelea (ver
# combat_tactico.montar, que les dio permiso para animarse con el arbol en pausa).
func _exit_tree() -> void:
	if tactico:
		turno_mapa.desmontar()


func _ready() -> void:
	# El reloj de la traza (ver _traza_add) arranca AQUI y no en setup(): hay dos caminos de entrada
	# al combate (setup y setup_espejo) y lo que solo se escribe en uno se pierde para el otro.
	_t0 = Time.get_ticks_msec() / 1000.0
	_traza.clear()
	# Forzamos que esta pantalla ocupe toda la ventana, aunque se abra como
	# overlay encima de la mazmorra (si no, sale descentrada/pequeña).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Y que siga ocupandola si la ventana cambia a mitad de pelea (ver _on_viewport_cambia).
	get_viewport().size_changed.connect(_on_viewport_cambia)

	# ANTES que nada: _crear_bloque le cuelga a cada tarjeta su capa de efectos, asi que el nodo
	# de FX tiene que existir antes de que se monte la primera.
	_fx = CombatFX.new()
	add_child(_fx)
	_fx.tinte_cambiado.connect(figuras._on_tinte_cambiado)
	# EL SPRITE SE MUEVE CON EL CUERPO. CombatFX lleva el reloj y avisa; el dueño de los sprites es
	# esta pantalla, asi que el cambio de animacion se hace aqui.
	# El salto del Oportunista va ANTES que el gesto: aparece a la espalda y el gesto sale ya mirandole.
	_fx.gesto_iniciado.connect(turno_mapa._on_gesto_salto)
	_fx.gesto_iniciado.connect(turno_mapa._on_gesto_desliz)   # el paso y el avance del estoque
	_fx.suelo_lanzado.connect(turno_mapa._on_suelo_lanzado)
	_fx.gesto_iniciado.connect(figuras._on_gesto_iniciado)
	_fx.gesto_terminado.connect(figuras._on_gesto_terminado)
	_fx.golpe_encajado.connect(figuras._on_golpe_encajado)
	# El tiron del Desgarro arrastra al enemigo justo cuando se ve el golpe (ver turno_mapa.pedir_tiron).
	_fx.golpe_encajado.connect(turno_mapa._on_golpe_encajado)
	# La sangre del hacha sale sobre el cuerpo que encaja el golpe (ver turno_mapa._on_impacto).
	_fx.impacto_visto.connect(turno_mapa._on_impacto)
	# Los golpes de la daga se pintan sobre el cuerpo de verdad (ver turno_mapa._on_dibujo_mapa).
	_fx.dibujo_en_mapa.connect(turno_mapa._on_dibujo_mapa)
	# Y quien esquiva se aparta de lado (ver turno_mapa._on_esquiva).
	_fx.esquiva_vista.connect(turno_mapa._on_esquiva)
	# El gris del cadaver espera a que se vea el golpe que lo mata (ver _apagar_diferido).
	_fx.apagar_ahora.connect(func(b: Dictionary) -> void:
		altas._apagar_visual(b, bool(b.get("fx_apagar_aliado", false))))

	# LA VELOCIDAD, antes de montar nada: si la pelea es MIA vale la mia; si estoy espejando la de
	# otro, la suya llegara en la primera instantanea (ver aplicar_instantanea).
	_aplicar_velocidad(1.0 if _espejo else Game.velocidad_combate)

	# EN EL MAPA se monta otra puesta en escena. Se cambia AQUI, antes de construir nada y despues de
	# que setup() haya dejado la pelea preparada: de aqui en adelante todo el montaje pasa por el
	# tema que toque sin que el resto de la pantalla sepa cual es.
	if tactico:
		montaje = CombatMontajeMapa.new(self)

	montaje._anadir_fondo()  # fondo opaco para tapar la mazmorra detras (en el mapa, no pinta nada)
	montaje._montar_columna()  # el combate pasa a una columna de ancho fijo, centrada

	if not _injected:
		# Combatientes de PRUEBA (para abrir combat.tscn directamente con F6). Se monta EL CASO
		# PEOR: MAX_ALIADOS contra MAX_ENEMIGOS, con velocidades distintas. Al tope es cuando la
		# pantalla aprieta -las tarjetas se encogen, la barra de accion se llena de marcadores-,
		# asi que es el caso que hay que poder mirar de un vistazo.
		var nombres: Array[String] = ["Heroe", "Bibi", "Coco", "Dado"]
		for j in MAX_ALIADOS:
			var pab := Abilities.new()
			pab.fuerza = 120; pab.resistencia = 90; pab.destreza = 60
			pab.agilidad = 110 - j * 20   # velocidades distintas: los turnos se alternan
			pab.magia = 20
			var aliado := Combatant.new(nombres[j], 1, pab, 50, 5, 5, 5)
			aliado.max_energy = 100.0
			aliado.current_energy = 100.0
			# CON ARMA, cada uno la suya. Sin esto pegan a puño limpio, que es MELEE, y MELEE tiene
			# T_VUELO 0 -> no dibuja NADA: la prueba enseñaba los golpes de los bichos pero del lado
			# de aca solo salia el numero, como si los gestos del jugador no existieran.
			aliado.fx_basico = [CombatFX.Estilo.ESPADA_TAJO, CombatFX.Estilo.DAGA_CORTE,
				CombatFX.Estilo.MANDOBLE_TAJO, CombatFX.Estilo.MAZA_GOLPE][j]
			_aliados.append(aliado)
		_player = _aliados[0]
		var colores: Array[Color] = [Color(0.9, 0.3, 0.3), Color(0.4, 0.8, 0.4),
			Color(0.5, 0.5, 0.95), Color(0.9, 0.8, 0.35), Color(0.7, 0.45, 0.9)]
		# Uno de cada de los que ya tienen sprite, para que la prueba enseñe el escenario de verdad
		# y no cinco cuadrados. Los .tres son los de siempre: de ahi salen el aspecto y el nombre.
		var muestras: Array[String] = ["res://scenes/actors/enemy/slime.tres",
			"res://scenes/actors/enemy/rata.tres", "res://scenes/actors/enemy/jabali.tres",
			"res://scenes/actors/enemy/trent.tres", "res://scenes/actors/enemy/slime_veneno.tres"]
		for i in MAX_ENEMIGOS:
			var ed: EnemyData = load(muestras[i]) as EnemyData
			var e: Combatant = null
			if ed != null:
				# EL BICHO DE VERDAD, con su fabrica de siempre: asi sale con SUS habilidades, su
				# elemento y su fx_basico. Construyendolo a mano se quedaba sin nada de eso y pegaba
				# como MELEE, que tiene T_VUELO 0 y por tanto NO DIBUJA: la prueba enseñaba enemigos
				# que golpeaban sin que se viera un solo efecto.
				e = ed.crear_combatant(0.5)
			if e == null:
				var eab := Abilities.new()
				eab.fuerza = 80; eab.resistencia = 70; eab.destreza = 30
				eab.magia = 0
				e = Combatant.new("Slime", 1, eab, 40, 4, 5, 4)
			# Velocidades distintas, para que se vea moverse el orden de turnos.
			e.abilities.agilidad = 40 + i * 20
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
	montaje._crear_acciones()
	montaje._setup_ui()
	montaje._crear_timeline()
	montaje._crear_boton_velocidad()   # x1 / x2, arriba a la derecha
	diagnostico._crear_estados_dev()  # herramienta de test de estados (KAN-58 Fase 1)
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
# La rejilla va a DOS columnas x tres filas, dentro de la columna de la derecha. Antes eran tres
# columnas, porque los botones ocupaban la franja de abajo a lo ancho de la pantalla; en 460 px
# esas tres NO CABEN y, lo que es peor, un GridContainer no encoge por debajo del minimo de sus
# hijos: 3 x 168 + separaciones son 524 px de minimo, o sea que se saldrian por la derecha.
const COLUMNAS_ACCION := 2
const FILAS_ACCION := 3.0           # las que ocupan las seis acciones a COLUMNAS_ACCION columnas
const ANCHO_BOTON_ACCION := 200.0   # minimo; los botones se reparten el ancho sobrante
const ALTO_BOTON_ACCION := 76.0
# Las FRASES del recitado van una por fila (el texto es largo y necesita el ancho entero), asi que
# son mas bajas que un boton de accion: cuatro de 76 + el Volver no caben en pantalla. 60 px sigue
# estando por encima del minimo comodo para un pulgar, que es lo que se buscaba: fallar una frase
# duele (backfire), y se estaban fallando por el TAMAÑO del boton, no por no saberse la frase.
const ALTO_BOTON_VOLVER := 56.0
# Hasta donde puede crecer el panel hacia ARRIBA. Con las acciones a tres filas y los submenus
# largos (diez hechizos a dos columnas son cinco filas: 5 x 76 + separaciones + el Volver, casi
# 490 px) el tope de 420 de antes recortaba la lista por abajo.
const ALTO_PANEL_MAX := 520.0


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
# donde estaban. Quien abre un submenu pide su alto; _ocultar_cajas lo devuelve a la rejilla pelada.
#
# El SUELO del clamp son las FILAS_ACCION que ocupa la rejilla de seis. Tiene que seguir a
# COLUMNAS_ACCION: con el 2.0 fijo que habia aqui, pasar la rejilla a dos columnas dejaba el panel
# a la altura de dos filas y la tercera (Defender / Objeto / Huir) quedaba cortada por abajo.
func _alto_panel(alto: float) -> void:
	if _panel_acciones == null:
		return
	_panel_acciones.offset_top = _panel_acciones.offset_bottom \
		- clampf(alto, ALTO_BOTON_ACCION * FILAS_ACCION, ALTO_PANEL_MAX) - 20.0


# Cierra un submenu: le pone el "◄ Volver" a lo ancho, ajusta el alto del panel a lo que ocupa su
# rejilla y lo enseña. 'n' = cuantos botones lleva la rejilla, 'cols' = a cuantas columnas se pinto
# (de esos dos salen las filas), 'al' = a donde vuelve el boton.
#
# 'cols' viene por parametro y no de COLUMNAS_ACCION porque no todas las rejillas usan esa: el
# recitado se pinta a las suyas (ver _pintar_test). Leyendo la constante, un submenu con otro
# numero de columnas pedia un alto que no era el suyo y se cortaba solo.
func _cerrar_submenu(caja: VBoxContainer, n: int, al: Callable,
		cols: int = COLUMNAS_ACCION) -> void:
	# Separacion entre la rejilla y el Volver: pegado a las celdas se pulsa por accidente.
	caja.add_theme_constant_override("separation", 12)
	var volver := Button.new()
	volver.text = "◄ Volver"
	volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volver.custom_minimum_size = Vector2(0, ALTO_BOTON_VOLVER)
	volver.add_theme_font_size_override("font_size", 18)
	volver.pressed.connect(al)
	caja.add_child(volver)
	var filas: int = maxi(1, ceili(n / float(maxi(1, cols))))
	_alto_panel(filas * ALTO_BOTON_ACCION + (filas - 1) * 10.0 + 12.0 + ALTO_BOTON_VOLVER)
	caja.visible = true


# Oculta las cajas del turno del jugador (acciones / submenu magia / recitado / habilidades /
# objetos). Todos los cierres pasan por aqui (_fin_de_eleccion, etc.).
#
# YA NO toca la visibilidad del registro. Cuando el log era un Label suelto, esto lo devolvia a la
# vista con `_log.visible = true`; ahora el registro es un panel propio con su boton, y forzarlo
# desde aqui significaba ESTIRARLO solo cada vez que se cerraba un submenu.
func _ocultar_cajas() -> void:
	if _actions_box != null: _actions_box.visible = false
	if _spell_box != null: _spell_box.visible = false
	if _cast_box != null: _cast_box.visible = false
	if _ability_box != null: _ability_box.visible = false
	if _objeto_box != null: _objeto_box.visible = false
	_alto_panel(0.0)   # vuelve a la rejilla de acciones pelada (el clamp lo sube al minimo)
	# El boton "i" y el mantener pulsado solo valen en tu turno: al ocultar la barra de acciones
	# (animacion, turno de otro) se apaga el boton y se corta cualquier hold a medias.
	_hold_c = null
	if _boton_detalle != null and is_instance_valid(_boton_detalle):
		_boton_detalle.disabled = true
	if _detalle != null and is_instance_valid(_detalle) and _detalle.abierta():
		_detalle.cerrar()


# RECOGE el registro si estaba estirado. Lo llaman los submenus altos (magia, frases, habilidades,
# objetos) antes de abrirse: un registro a pantalla completa les taparia la lista justo cuando hay
# que elegir. Recogido a sus LOG_LINEAS no estorba a nadie, asi que no hace falta cerrarlo del todo.
#
# Antes esto era un no-op (el log vivia en su columna y no le quitaba sitio a nada). Se ha quedado
# con el nombre y con sus mismas llamadas, que siguen queriendo decir exactamente lo mismo.
func _ocultar_log() -> void:
	if montaje._log_abierto:
		_alternar_log()


# LA VENTANA HA CAMBIADO DE TAMAÑO (maximizar, restaurar, que Windows la recoloque...). Las bandas se
# estiran solas por sus anclajes, pero el ancho de cada tarjeta es un MINIMO que se calculo al montar la
# pelea con el viewport de entonces (ver _ancho_bloque). Con la ventana mas estrecha despues, las
# columnas seguian midiendo lo de antes y la fila se salia por la derecha: el quinto bicho y el cuarto
# del grupo acababan debajo del registro y de los botones (captura del jefe, 11/09/2026, a 1920x1017
# de area util). El ancho logico SI cambia con la PROPORCION de la ventana (ver la nota de las
# unidades logicas: nunca baja de 1280, pero sube por encima en ventanas mas apaisadas que 16:9).
func _on_viewport_cambia() -> void:
	if not is_inside_tree():
		return
	var ene: Array = []
	for b in _bloques:
		var col: Control = b.get("columna")
		if col != null and is_instance_valid(col) and col.visible:
			ene.append(b)
	montaje._reajustar_anchos(ene, ene.size())
	var ali: Array = []
	for ba in _bloques_aliados:
		var cola: Control = ba.get("columna")
		if cola != null and is_instance_valid(cola) and cola.visible:
			ali.append(ba)
	montaje._reajustar_anchos(ali, ali.size())
	figuras._ajustar_zoom_sprites()
func _update_hp() -> void:
	# MULTI: repintar es exactamente "ha cambiado algo que se ve", asi que es el sitio natural para
	# mandarles la foto a los espejos. NO se llama desde _process (solo tras cambios de verdad), asi
	# que esto no inunda la red.
	espejo._difundir()
	# Un bloque por enemigo. Los muertos se siguen refrescando (su barra a 0): su bloque no
	# desaparece, se queda apagado en su sitio.
	for i in _bloques.size():
		var e: Combatant = _enemies[i]
		var b: Dictionary = _bloques[i]
		# El MAXIMO se refresca en cada vuelta (lo hace _fijar_barra_num). Se fijaba solo al crear el
		# bloque, asi que cualquier cosa que mueva max_hp en vivo (Guardia de carne, que lo duplica)
		# dejaba la barra midiendo contra un tope viejo: el numero decia 130/150 y la barra se
		# pintaba llena como si fuera 75.
		# La barra se DESLIZA hasta la vida nueva (lo mueve CombatFX) y EL NUMERO VIAJA CON ELLA.
		efectos._fijar_barra_num(b, "hp", e.current_hp, e.max_hp, "%.2f / %.2f")
		# La etiqueta se queda SOLO con el nombre; los estados van en su fila de chips, porque ahi
		# cada uno se puede señalar y explicarse solo. El nivel se cayo de aqui: en una tarjeta que
		# al tope se aprieta a 130 px se comia el sitio del nombre, que es lo unico que hay que
		# poder leer de un vistazo para saber a quien estas apuntando.
		b["nombre"].text = e.nombre
		if e.is_alive():
			efectos._refrescar_chips(e, b, i)

	# Y un bloque por aliado, con SUS tres barras. Los KO se siguen refrescando (barra a 0) igual
	# que los cadaveres de enfrente: su bloque se queda apagado en su sitio, no desaparece.
	# Los NUMEROS van dentro de su barra (vida, energia y mana), no amontonados en la etiqueta del
	# nombre: cada cifra al lado de la barra a la que pertenece.
	for i in _bloques_aliados.size():
		var c: Combatant = _aliados[i]
		var b: Dictionary = _bloques_aliados[i]
		# Los tres maximos en cada refresco, por lo mismo que arriba: son numeros que se mueven en
		# mitad de la pelea y la barra tiene que medir contra el de AHORA.
		efectos._fijar_barra_num(b, "hp", c.current_hp, c.max_hp, "%.2f / %.2f")
		efectos._fijar_barra_num(b, "en", c.current_energy, c.max_energy, "EN  %.1f / %.1f")
		efectos._fijar_barra_num(b, "mp", c.current_mp, c.max_mp, "MP  %.2f / %.2f")
		# La coronita marca a QUIEN LE TOCA: con tres bloques iguales hace falta saber de un
		# vistazo de quien es la accion que estas eligiendo.
		b["nombre"].text = "%s%s" % [("▶ " if c == _player else ""), c.nombre]
		if c.is_alive():
			efectos._refrescar_chips(c, b, -1)
	# EN EL MAPA estas tarjetas no se ven: las de tu grupo son las barras de ARRIBA, del jugador.
	if tactico:
		turno_mapa.refrescar_barras_grupo()
# La tarjeta de un combatiente, sea de los tuyos o de enfrente. Vacia si no tiene (un invitado a
# medio entrar, o alguien que ya no esta en la pelea).
func _bloque_de(c: Combatant) -> Dictionary:
	if c == null:
		return {}
	var i: int = _aliados.find(c)
	if i >= 0 and i < _bloques_aliados.size():
		return _bloques_aliados[i]
	i = _enemies.find(c)
	if i >= 0 and i < _bloques.size():
		return _bloques[i]
	return {}
# Teclas de DESARROLLO DENTRO del combate. El combate corre con el arbol en PAUSA, asi
# que el _input de Game (autoload, pausable) no llega aqui; esta escena es
# PROCESS_MODE_ALWAYS, por eso reproducimos las teclas utiles sobre el combate en curso:
#   H = curacion total (vida/mana/energia al 100%)
#   K = cambiar arma principal   L = cambiar mano secundaria
# Y una que NO es de desarrollo: P = desatascar (ver _desatascar), disponible en partida normal.
func _input(event: InputEvent) -> void:
	if _state == State.FINISHED:
		return
	# EN EL MAPA, apuntando una habilidad: el clic es del suelo (confirmar) y el derecho vuelve.
	if tactico and turno_mapa.input_apuntando(event):
		get_viewport().set_input_as_handled()
		return
	# MANTENER PULSADO sobre un combatiente -> ficha de detalle (solo en tu turno). El contador
	# lo lleva _process; aqui solo se arma, se cancela si el puntero se va, y se suelta al levantar.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed and figuras._puedo_inspeccionar():
			_hold_c = figuras._combatiente_bajo(mb.position)
			_hold_t = 0.0
			_hold_pos = mb.position
		elif not mb.pressed:
			_hold_c = null
		return
	if event is InputEventMouseMotion:
		if _hold_c != null and (event as InputEventMouseMotion).position.distance_to(_hold_pos) > HOLD_MOV_MAX:
			_hold_c = null
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# ESC = LOS AJUSTES. El menu de pausa no se abre con una pelea delante (ahi no se guarda: ver
	# pause_menu.alternar), y eso dejaba el volumen sin tocar justo donde mas se nota, que es donde
	# suenan los golpes. Asi que aqui se abre el MISMO panel de ajustes, el solo, sin guardar ni
	# salir: es el unico trozo de la pausa que tiene sentido en mitad de un combate.
	if event.is_action_pressed(&"cancelar"):
		_alternar_ajustes()
		get_viewport().set_input_as_handled()
		return
	# Se MARCA COMO CONSUMIDA la que atendemos aqui. Game escucha las suyas en _unhandled_key_input,
	# que corre DESPUES de este _input: sin esto, en multi (donde el arbol no se pausa) una P dentro
	# del combate disparaba ademas el test de spawns de Game, y una H la cura del mundo.
	match (event as InputEventKey).keycode:
		KEY_H:
			diagnostico._dev_heal_full()
		KEY_K:
			diagnostico._dev_swap_weapon(true)
		KEY_L:
			diagnostico._dev_swap_weapon(false)
		KEY_P:
			diagnostico._desatascar()
		_:
			return
	get_viewport().set_input_as_handled()


# Abre o cierra el panel de volumen. Se monta la primera vez que hace falta y se queda: es un
# Control con tres mandos, no cuesta nada tenerlo ahi.
#
# EN SU PROPIA CanvasLayer y por encima de la del combate (100), o saldria por debajo del tablero y
# no se veria. Y con PROCESS_MODE_ALWAYS, como todo lo que tiene que responder con el arbol parado.
func _alternar_ajustes() -> void:
	if _ajustes == null:
		var capa := CanvasLayer.new()
		capa.layer = 110
		capa.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(capa)
		_ajustes = preload("res://scripts/ui/settings_menu.gd").new()
		# EL PANEL NACE VISIBLE (settings_menu no lo esconde en su _ready: de eso se encarga quien
		# lo cuelga). Sin esta linea, la primera ESC lo encontraba ya abierto y lo CERRABA -- o sea
		# que la tecla no hacia nada la primera vez.
		_ajustes.visible = false
		# El mismo velo oscuro que el menu de pausa. El panel es opaco y se leeria igual, pero sin
		# el velo no queda claro que el resto de la pantalla esta esperando.
		var velo := ColorRect.new()
		velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		velo.color = Color(0.0, 0.0, 0.0, 0.65)
		velo.mouse_filter = Control.MOUSE_FILTER_STOP
		_ajustes.add_child(velo)
		_ajustes.move_child(velo, 0)   # por DEBAJO de los mandos, o los tapa
		capa.add_child(_ajustes)
	if _ajustes.visible:
		_ajustes.cerrar()   # es quien escribe en disco lo que hayas movido
	else:
		_ajustes.abrir()


# LOS PLATOS SE GASTAN POR RELOJ, tambien dentro de la pelea. Un plato se vende como "20 minutos" y
# su duracion esta escrita como los turnos que caben en 20 min al ritmo de FUERA (5 s por turno,
# Game.SEG_POR_TURNO_FUERA). Bajarselos por turno de combate rompia eso por partida doble:
#   - un turno de pelea dura uno o dos segundos, no cinco: la comida se evaporaba;
#   - y cada combatiente tiene los SUYOS, mas o menos seguidos segun su velocidad, asi que dos que
#     comieron a la vez acababan con tiempos MUY distintos (medido en el playtest: a uno le quedaban
#     6 minutos cuando al otro ya se le habia pasado).
# Encima la velocidad de pelea x2 dobla los turnos, o sea que el ajuste del menu te comia la comida.
#
# Aqui va el reloj de VERDAD (delta pelado, sin _vel_pelea): un minuto de pelea gasta un minuto de
# plato, igual que un minuto andando. Ver Combatant.tick_statuses, que ahora se los salta.
var _t_plato: float = 0.0

func _tick_platos(delta: float) -> void:
	_t_plato += delta
	if _t_plato < Game.SEG_POR_TURNO_FUERA:
		return
	_t_plato -= Game.SEG_POR_TURNO_FUERA
	for c in _aliados + _enemies:
		if not c.is_alive():
			continue
		# Sobre una COPIA: retirar_status toca el array de verdad, y recorrer el que se esta
		# modificando se salta entradas.
		for e in c.statuses.duplicate():
			if not e.es_tiempo_real():
				continue
			e.turns -= 1
			if e.turns > 0:
				continue
			c.retirar_status(e)
			_set_log("A %s se le pasa el efecto de %s." % [_etq(c), str(e.d.get("nombre", "?"))])
	_update_hp()


func _process(delta: float) -> void:
	# ESPEJO: acercar las barras a su objetivo ANTES de pintar, para que la linea de tiempo salga
	# suave y no a escalones de 20 Hz.
	if _espejo:
		espejo._interpolar_atb_espejo(delta)
	_update_timeline()  # refleja el orden de turnos siempre
	# EN EL MAPA las fichas van pegadas a su cuerpo: hay que recolocarlas cada fotograma. Va aqui
	# arriba, antes del return del espejo, porque en el espejo los cuerpos tambien se mueven.
	if tactico:
		figuras_mapa.seguir()
		ficha_objetivo.refrescar()   # la pestaña del apuntado, en la columna derecha
	figuras._tick_hold_detalle(delta)   # el "mantener pulsado" que abre la ficha de detalle
	# Los cadaveres de enfrente que se estan yendo. VA AQUI ARRIBA, antes del return del espejo y de
	# los de PAUSED/ADVANCING: en el espejo tambien se muere gente, y una tarjeta a medio desvanecer
	# durante la pausa de lectura se quedaria congelada a medio alpha.
	altas._avanzar_retiradas(delta)
	# ESPEJO (hito 5.4-C): esta pantalla no SIMULA nada, solo pinta la pelea que lleva otra
	# maquina. Ni ATB, ni turnos, ni resolucion: todo eso llega por instantaneas.
	if _espejo:
		# ...salvo ANDAR: en el mapa, mis personajes los muevo yo aunque la pelea la lleve otro (su
		# posicion le llega por el canal del jugador y sellada con mi accion).
		if tactico:
			turno_mapa.tick(delta)
		return
	_tick_platos(delta)   # los buffs de comida se gastan por RELOJ, no por turnos (ver mas abajo)
	espejo._difundir_atb(delta)
	espejo._heartbeat_remoto(delta)   # que un turno de otro no pueda quedarse colgado para siempre
	# EN EL MAPA: el que tiene el turno anda. Si es un enemigo acercandose, el fotograma es suyo (el
	# ATB esta parado y la pausa de lectura no cuenta hasta que actue).
	if tactico and turno_mapa.tick(delta):
		return
	# Pausa de lectura tras la accion del enemigo: cuenta atras y reanuda el ATB.
	if _state == State.PAUSED:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_state = State.ADVANCING
		return
	if _state != State.ADVANCING:
		return

	# LA BARRA DE ACCION TAMBIEN VA A LA VELOCIDAD ELEGIDA: acelerar la pelea es acelerarla ENTERA,
	# no solo los dibujos. A x2 las barras se llenan al doble y los turnos llegan al doble.
	#
	# Ojo: aqui va _vel_pelea PELADA, sin el RITMO_BASE que llevan los efectos. Lo que se pidio
	# lento son las ANIMACIONES (no daba tiempo a leer el golpe); frenar ademas los turnos haria la
	# pelea mas lenta de JUGAR, que es lo contrario de lo que se busca. La pausa de lectura tampoco
	# se escala aqui: ya sale acortada de arrancar_cola, que devuelve segundos de verdad.
	var datb: float = delta * _vel_pelea
	var escala: float = _escala_barra()

	# CADA aliado llena SU barra con SU velocidad: el grupo no actua a la vez, se van alternando
	# segun quien sea mas rapido (por eso meter a alguien agil cambia el ritmo de la pelea).
	# Al CASTEAR (KAN-95) se llena a la velocidad de casteo (la varita del mago hibrido la cambia
	# respecto al arma principal); si no, la velocidad normal. Y quien entro agotado va a medio
	# ritmo sus primeras acciones.
	for c in _aliados_vivos():
		var casteando: bool = _casteos.has(c)
		var rate: float = escala
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
		_gauge[c] += cspeed * datb * rate
	for e in _vivos():
		_gauge[e] += e.spd() * datb * escala

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
		elif tactico:
			turno_mapa.turno_enemigo(mejor)   # se acerca a su presa y DESPUES hace su turno de siempre
		else:
			enemigos._enemy_turn(mejor)


func _begin_player_turn() -> void:
	_state = State.WAITING_PLAYER
	golpeados_en_la_accion.clear()   # un contraataque de antes no abre hueco para esta accion
	if _dps_on:
		_turnos_jugador += 1
	_player_defending = false  # la guardia solo dura hasta tu proximo turno
	_player.salir_de_guardia() # la postura de contraataque tambien dura hasta tu proxima accion
	_player.tick_cooldowns()   # habilidades (KAN-57): baja 1 turno los cooldowns activos
	# Provocacion (escudo): dura N turnos SUYOS. Baja 1 al empezar su turno (entre medias, los
	# enemigos ya la han "sentido" al elegir objetivo). Al llegar a 0 deja de atraer golpes.
	if _player.provocar_turnos > 0:
		_player.provocar_turnos -= 1
	# COBERTURA (escudo grande): igual que la Provocacion, dura N turnos SUYOS y baja al empezarlos.
	# Al llegar a 0 se rompe la pareja por los dos lados, o el protegido se queda con un protector
	# que ya no le tapa nada y la redireccion tendria que estar comprobandolo en cada sorteo.
	# La guardia sigue arriba mientras cubres: ver mas abajo, donde se marca _defendiendo.
	if _player.proteger_turnos > 0:
		_player.proteger_turnos -= 1
		if _player.proteger_turnos <= 0:
			objetivos._romper_cobertura(_player)
	# Mientras CUBRES, cuentas como que estas defendiendo. Si no, "los recibes con tu escudo" seria
	# mentira salvo que ademas gastaras el turno en Defender -- y el turno ya te lo ha costado poner
	# la cobertura. Va sobre el DICT y no sobre _player_defending, que solo vale dentro del turno
	# del que actua (con grupo, ese flag es del que le toca, no del que encaja el golpe).
	if _player.proteger_turnos > 0:
		_defendiendo[_player] = true
	# La IMBUICION ya NO baja aqui: dura ATAQUES, no turnos. Ver _gastar_imbue().
	# Estados alterados (KAN-58): tick al inicio del turno (DoT, expira, aturdido).
	var ev: Dictionary = _player.tick_statuses()
	_log_tick(_player, ev)
	_update_hp()
	if not _player.is_alive():
		_set_log("%s cae por el daño de sus estados. ☠" % _player.nombre)
		altas._caer_aliado(_player)   # el DoT (veneno...) puede tumbarlo
		if altas.derrota():
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
			if tactico:
				turno_mapa.olvidar_carga(_player)
			print("[habilidad] %s ATURDIDO: se le INTERRUMPE %s" % [_player.nombre, interrumpida])
			_set_log("%s está aturdido: se le interrumpe %s. 💫" % [_player.nombre, interrumpida])
		else:
			_set_log("%s está aturdido y pierde el turno. 💫" % _player.nombre)
		_pausa_lectura()
		return

	# ATAQUE DE CARGA en curso: este turno se va en seguir cargando; al llegar a 0, LA SUELTA SU DUEÑO.
	# Va ANTES de mirar el recitado de hechizos y de sacar los botones: mientras cargas no eliges nada,
	# que es lo que hace que la carga se pague.
	#
	# YA NO SE DISPARA SOLA. Antes, al llegar a 0, se llamaba a _usar_habilidad y el objetivo salia de
	# _target_idx, que es una variable DE PANTALLA: en multi eso era el ultimo clic del ANFITRION, no
	# el del dueño del personaje, asi que el martillazo caia donde le tocara. Ahora se pide la orden,
	# con su objetivo, igual que el disparo de un conjuro.
	#
	# El descuento y la comprobacion van SEPARADOS para que esto sea idempotente: tras un traspaso de
	# anfitrion la carga viaja en _volatil con charge_left ya a 0, y el nuevo no debe restar otra vez.
	if _player.charging != null:
		if _player.charge_left > 0:
			_player.charge_left -= 1
		if _player.charge_left > 0:
			_set_log("%s sigue cargando %s... ⚡" % [_player.nombre, _player.charging.nombre])
			_ocultar_cajas()
			_pausa_lectura()
			return
		# LISTA. 'charging' se queda puesto hasta que de verdad se suelte: es lo que hace que el estado
		# sobreviva a un traspaso, a un reenvio del heartbeat y a que su dueño se vaya de la pelea.
		# EN EL MAPA no se pregunta nada: el sitio se eligio al empezar a cargar y cae ahi, este quien
		# este (lo que se haya ido, se ha librado). Lo suelta esta maquina aunque el personaje sea de
		# otro humano: el sitio ya viajo sellado con la accion que empezo la carga.
		if tactico and turno_mapa.tiene_carga(_player):
			turno_mapa.recuperar_carga(_player)
			habilidades._soltar_la_carga()
			return
		habilidades._pedir_soltar_carga(_player.charging)
		return

	# Regen de maná POR TURNO: ya solo la del ARMA MAGICA (mejora Regeneración, KAN-95). La
	# base por Magia se quito: el maná se gana PEGANDO (_ganar_mana_golpe) y GANANDO, no por
	# dejar pasar turnos. Sin arma mágica, este turno no repone nada.
	if _player.mp_regen_turno > 0.0:
		_player.regen_mana(_player.mp_regen_turno * StatsMath.MP_REGEN_TURNO_MULT
			* _player.status_mp_regen_mult())
	_update_hp()
	# EN EL MAPA, aqui empieza a poder andar: el turno ya se juega (ni aturdido ni cargando).
	if tactico:
		turno_mapa.empezar_turno(_player)
	# Si estas casteando un hechizo, el turno va al recitado / disparo, NO a las
	# acciones normales (por diseño no puedes hacer otra cosa mientras cantas).
	if _cast_spell != null:
		if _cast_index < _cast_spell.longitud():
			magia._mostrar_test(_cast_index)
		else:
			magia._mostrar_disparo()
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
	if dueno != 0 and not Net.peleas.esta_en_mi_pelea(dueno):
		# Ya no esta en la pelea (se fue, o su pantalla dejo de espejarme): pedirle la accion
		# seria esperar para siempre. Sus personajes salen y la pelea sigue.
		sacar_a(dueno)
		return
	if dueno != 0:
		_ocultar_cajas()
		_set_log("Turno de %s. Esperando su acción..." % _player.nombre)
		# Con el RADIO que puede andar en el mapa: lo calculo yo, que tengo su Agilidad (ver
		# turno_mapa.empezar_turno, que ya lo ha dejado puesto). En la pelea de fila va a 0.
		espejo._pedir_a_remoto(dueno, {"tipo": "accion", "idx": _aliados.find(_player),
			"radio": turno_mapa.radio_del_turno() if tactico else 0.0})
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
			if _pasa_el_turno() and not tactico:
				return "Estás enraizado y no llegas a golpear: cedes el turno. Los hechizos, Defender, los objetos y huir sí te quedan."
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
			if _huir_es_pasar():
				return "Te quedas donde has andado y cedes el turno. Recuperas algo de energía, menos que atacando. Pegado al borde de la arena, este botón se convierte en Huir."
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
	# EL BASICO SE CONVIERTE EN "PASAR" MIENTRAS ESTES ENRAIZADO. No es un adorno: es lo que evita
	# que te quedes SIN NINGUNA JUGADA. Antes del Enraizado, Atacar estaba siempre disponible y hacia
	# de suelo; en cuanto se lo quitas, un personaje sin hechizos, sin objetos y sin energia se queda
	# solo con Huir. Y es peor de lo que parece, porque la energia se recupera ATACANDO: enraizado te
	# corta justo lo que necesitas para poder Defender, asi que no puedes ni salir del apuro solo.
	# EN EL MAPA NO: ahi el sexto boton ya es "Pasar" siempre (ver _huir_es_pasar), asi que Atacar solo
	# pega o se apaga. Que Atacar se convirtiera en ceder el turno hacia que lo perdieras sin querer.
	if _action_buttons.has(Action.ATTACK):
		_action_buttons[Action.ATTACK].text = "Pasar" if _pasa_el_turno() and not tactico else "Atacar"
	if _action_buttons.has(Action.FLEE):
		_action_buttons[Action.FLEE].text = "Pasar" if _huir_es_pasar() else "Huir"
	if _boton_detalle != null and is_instance_valid(_boton_detalle):
		_boton_detalle.disabled = not figuras._puedo_inspeccionar()


func _motivo_bloqueo(id: int) -> String:
	# El Silencio manda sobre el otro motivo: si estas silenciado, da igual que tengas hechizos.
	if _player != null and _player.silenciado() and (id == Action.MAGIC or id == Action.HABILIDAD):
		return "Estás silenciado"
	# Y el Enraizado igual, pero al reves: te corta el brazo, no la boca. El BASICO no se bloquea
	# nunca -- se convierte en "Pasar" (ver _refresh_actions), que es lo que garantiza que siempre
	# tengas una jugada.
	if _player != null and _player.enraizado() and id == Action.HABILIDAD:
		return "Estás enraizado (puedes lanzar hechizos)"
	if id == Action.ATTACK and tactico and _pasa_el_turno():
		return "Estás enraizado y no llegas a golpear"
	if id == Action.ATTACK and _objetivo_fuera_de_alcance():
		if not turno_mapa.llega_a_alguno(_player):
			return "No tienes a ningún enemigo a tu alcance: acércate andando"
		return "Fuera de alcance: acércate o elige a otro"
	match id:
		Action.MAGIC: return "No tienes hechizos equipados"
		Action.DEFEND: return "Sin energía (ataca para regenerar)"
		Action.HABILIDAD: return "Tu equipo no aporta habilidades"
		Action.OBJETO: return "No tienes objetos"
	return ""


# ¿El boton de Atacar es ahora mismo un "Pasar"? UN SOLO SITIO lo decide, y lo miran los tres que
# tienen que estar de acuerdo: el rotulo del boton, su tooltip y lo que hace al pulsarlo. Con la
# condicion escrita tres veces, cambiarla en dos de los tres deja un boton que dice una cosa y hace
# otra -- y eso no da ningun error.
func _pasa_el_turno() -> bool:
	return _player != null and _player.enraizado()


# EN EL MAPA, ¿el sexto boton (el de Huir) es ahora un "Pasar"? Lo es salvo pegado al muro de la
# arena, que es donde se huye. Es el SUELO del menu en el mapa: sin el, un personaje sin energia ni
# hechizos lejos de todos se quedaria sin ninguna jugada. Antes hacia de suelo Atacar convertido en
# "Esperar", y se perdian turnos sin querer (lo pidio cambiar el usuario el 24/09). Lo miran los
# mismos tres que _pasa_el_turno: el rotulo, su tooltip y lo que hace al pulsarlo.
func _huir_es_pasar() -> bool:
	return tactico and _player != null and not turno_mapa.en_el_borde()


# EN EL MAPA, ¿tu objetivo elegido esta fuera de tu alcance? (con nadie a tiro, tambien)
func _objetivo_fuera_de_alcance() -> bool:
	return tactico and _player != null and not _pasa_el_turno() \
		and not turno_mapa.llega(_player, _objetivo())


func _accion_disponible(id: int) -> bool:
	match id:
		# En la fila, SIEMPRE disponible: es el suelo del menu. Enraizado no lo desactiva, lo convierte
		# en "Pasar" (ver _refresh_actions y _accion_atacar). En el mapa el suelo es el sexto boton
		# (_huir_es_pasar), asi que Atacar se apaga enraizado o sin llegar a tu objetivo.
		Action.ATTACK: return not _objetivo_fuera_de_alcance() and not (tactico and _pasa_el_turno())
		Action.DEFEND: return _player.has_energy(DEFEND_ENERGY_COST)   # Defender cuesta energia
		Action.FLEE: return true
		# El SILENCIO corta las dos jugadas, no el turno: te quedan atacar, Defender, objeto y huir.
		Action.MAGIC: return _hay_hechizos() and not _player.silenciado()
		# is_empty() ya NO sirve: abilities_combate mide siempre MAX_HABILIDADES y los huecos vacios
		# van como null, asi que un array de cuatro nulls "no esta vacio" y el boton se habilitaba
		# para abrir un submenu sin nada dentro.
		Action.HABILIDAD: return _tiene_alguna_habilidad() \
			and not _player.silenciado() and not _player.enraizado()
		Action.OBJETO: return Game.consumibles_total() > 0
	return false


# ¿Lleva puesta alguna habilidad? Los huecos vacios de abilities_combate son null (ver
# Game.habilidades_con_huecos), asi que hay que mirar el contenido, no el tamaño.
func _tiene_alguna_habilidad() -> bool:
	for ab in _player.abilities_combate:
		if ab != null:
			return true
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
		Action.ATTACK:
			if _accion_disponible(Action.ATTACK):
				_accion_atacar()
		Action.DEFEND: _accion_defender()
		Action.FLEE:
			if _huir_es_pasar():
				_accion_esperar()
			else:
				_accion_huir()
		Action.MAGIC: magia._accion_magia()
		Action.HABILIDAD: habilidades._accion_habilidad()
		Action.OBJETO: objetos._accion_objeto()


# El boton reutilizado (antes "Atacar") cierra la pantalla al terminar el combate.
func _on_continue_pressed() -> void:
	if _state != State.FINISHED:
		return
	# EN UN ESPEJO NO SE REPARTE NADA. Esta pantalla no simula la pelea: solo la pinta, y sus
	# combatientes son maniquies que traen lo que se ve y nada mas. Todo lo de abajo (arrastrar el
	# goteo de las pociones, tirar por las pasivas slayer de cada bicho abatido, decir con cuanta
	# vida sale cada uno) lo resuelve el ANFITRION, que es quien lleva la pelea. Ejecutarlo aqui
	# seria repartir premios dos veces y sobre datos que no son.
	#
	# Lo unico que hace el espejo al pulsar Continuar es CERRAR SU PANTALLA, y cerrarla de verdad:
	# antes se quedaba con un "esperando..." y el boton apagado hasta que el anfitrion pulsaba el
	# suyo, o sea que el final de la pelea lo decidia otro por ti. Lo que vivieron tus personajes
	# viene igual, por el camino de siempre (Net.peleas.salir_del_espejo se lo pide al anfitrion y llega en
	# _devolver_desgaste); no hace falta seguir mirando la pantalla para cobrarlo.
	if _espejo:
		combat_finished.emit(false, [], [], [], [], [], [], [])
		if not _injected:
			queue_free()
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
		# (La pasiva slayer de cada abatido se tira en _end, no aqui: ver alli.)
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


func _accion_atacar() -> void:
	if espejo._enviar_si_espejo("atacar"):
		return
	# ENRAIZADO: el basico se convierte en CEDER EL TURNO. Va aqui abajo, DESPUES del envio al
	# espejo, y no en el boton: el anfitrion despacha por esta misma funcion el "atacar" que le
	# manda el invitado (ver aplicar_accion_remota), asi que atajando arriba el invitado pasaria
	# turno en su pantalla y el anfitrion le resolveria un ataque. Una sola autoridad, un solo sitio.
	if _pasa_el_turno():
		_set_log("🌱 %s está enraizado y no llega a golpear: cede el turno." % _player.nombre)
		_fin_de_eleccion()
		_state = State.ADVANCING
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
	# EL GESTO DEL ARMA. Sale por el mismo camino que el basico de un bicho: sin habilidad, manda
	# como pega el que pega (Combatant.fx_basico), que en el jugador lo pone la MANO ACTIVA. Por eso
	# en dual cada golpe se ve con su arma sin tener que preguntarlo aqui.
	var estilo_bas: int = efectos._estilo_de_habilidad(null, _player)
	# EN EL MAPA, el basico del MANDOBLE es un corte SOBRE el enemigo (BarridoAire.TAJO): va por el camino
	# del suelo que se rompe (red, instante del golpe), y ese camino apaga su dibujo viejo.
	# Tambien si lo ESQUIVA: el corte sale al lado, al aire y tenue (con el dibujo viejo salia la raya de antes).
	var corte_mapa: bool = tactico and estilo_bas == CombatFX.Estilo.MANDOBLE_TAJO
	if corte_mapa:
		var fc: CombatFormas.Forma = turno_mapa.forma_corte(_player, obj, bool(result.evaded))
		efectos.fijar_suelo(SueloRoto.Tipo.TAJO, fc, (randi() & 0x3FFFFFFF) | 1, 0.0)
	if result.evaded:
		_set_log("%s esquiva tu ataque (%s). 💨" % [_etq(obj), con_arma])
		efectos._fx_golpe(_player, obj, 0.0, false, true, Elementos.Elemento.NINGUNO, estilo_bas)
		if corte_mapa:
			efectos.soltar_suelo()
	else:
		obj.take_damage(result.damage)
		efectos._fx_golpe(_player, obj, result.damage, result.crit, false,
			_player.imbue_elemento if float(result.get("dmg_imbue", 0.0)) > 0.0 \
			else Elementos.Elemento.NINGUNO, estilo_bas)
		_apuntar_dano(obj, result.damage, _player)   # contador oculto de Cazador
		# El filo imbuido tambien gasta lo que lo amplificaba (arma de Rayo sobre un Mojado).
		if float(result.get("dmg_imbue", 0.0)) > 0.0:
			magia._gastar_amplificadores(obj, _player.imbue_elemento)
		if corte_mapa:
			efectos.soltar_suelo()
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
		txt += magia._imbue_dmg_txt(result)
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
	magia._gastar_imbue()   # blandir el arma gasta un uso, acierte o falle
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


# EN EL MAPA, PASAR: te quedas donde has andado y cedes el turno, recuperando algo de energia. Es un
# tipo de accion PROPIO en la red ("esperar") y no un "atacar" o un "huir" que el anfitrion convierta:
# si lo decidiera el con sus posiciones, dos pixeles de diferencia harian que tu pantalla dijera
# Pasar y la suya huyera. Lo que eliges es lo que viaja.
func _accion_esperar() -> void:
	if espejo._enviar_si_espejo("esperar"):
		return
	var basico: float = _player.energia_regen if _player.energia_regen > 0.0 else ATTACK_ENERGY_REGEN
	_player.regen_energy(basico * PASAR_ENERGIA_FRAC)
	_set_log("%s pasa el turno y recupera el aliento. ⏳" % _player.nombre)
	_update_hp()
	_fin_de_eleccion()
	_state = State.ADVANCING


# Accion Defender (KAN-54): mitiga el proximo daño, suma la defensa del escudo y deja los criticos
# en tu contra a la MITAD (no los anula, ver StatsMath.DEFEND_CRIT_MULT) hasta tu siguiente turno.
# Cuesta el turno (no atacas).
func _accion_defender() -> void:
	if espejo._enviar_si_espejo("defender"):
		return
	_player.spend_energy(DEFEND_ENERGY_COST)   # Defender consume energia (KAN-57)
	_player_defending = true
	# EN EL MAPA SE VE: el gesto de defenderse sobre uno mismo (CombatFX.Estilo.DEFENSA), por el camino de
	# los golpes para que lo vean todas las maquinas; el muñeco se queda en su postura hasta su turno.
	if tactico:
		efectos._fx_golpe(_player, _player, 0.0, false, false, Elementos.Elemento.NINGUNO,
			CombatFX.Estilo.DEFENSA, 1.0, true)
		if _fx != null:
			_fx.arrancar_cola()
		espejo._soltar_impactos_red()
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
	if espejo._enviar_si_espejo("huir"):
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
	# Lo cobra el GRUPO DE QUIEN HUYE. Si es de otro humano, a sus DOBLES (nunca a mi party ni a mi lider):
	# su ficha le vuelve en el lote. Antes solo pagaba a los mios, y en la pelea de un trabajador -donde
	# todos son de otros- nadie ganaba nada por huir.
	if dueno != 0:
		for c in _aliados:
			var pj_d: PersonajeData = Game.pj_de_combatant(c) if int(_dueno_aliado.get(c, 0)) == dueno else null
			if pj_d != null:
				Game.ganar("agilidad", _reto(perseguidor, pj_d), Game.GAIN_AGILIDAD_HUIDA_COMBATE,
					Game.RETO_MAX_FISICO, pj_d)
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
	var nuevo: int = Net.peleas.heredero_de_pelea()
	if nuevo == 0:
		return false
	# Los bichos VIVOS se van con la pelea: al cerrar la mia NO hay que reanudarlos (siguen
	# peleando alli) ni devolverlos al mundo. Los muertos si, que sus cadaveres son de esta pelea.
	var siguen: Array = []
	for i in _enemies.size():
		if _enemies[i].is_alive():
			siguen.append(i)
	if not Net.peleas.traspasar_pelea(espejo.estado_para_traspaso(nuevo)):
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
	Net.peleas.sacar_de_la_pelea(peer)   # le devuelve lo suyo y le cierra el espejo (a el solo)
	_update_hp()
	return true


# SE HA CAIDO un jugador que estaba en mi pelea. Sus personajes salen de ella igual que si hubieran
# huido: si no, la pelea se quedaria esperando eternamente un turno suyo que no va a llegar.
func sacar_a(peer: int, motivo: String = "Tu compañero se ha desconectado y sus personajes dejan la pelea.") -> void:
	if _espejo or peer == 0 or _state == State.FINISHED:
		return
	_traza_add("SACO al peer %d de la pelea (ya no esta)" % peer)
	for c in _aliados:
		if int(_dueno_aliado.get(c, 0)) == peer:
			_retirar_aliado(c)
	if _aliados_vivos().is_empty():
		_end(false, true)   # no queda nadie: la pelea se cierra
		return
	# EL TURNO NO PUEDE QUEDARSE CON EL QUE SE VA. Antes esto miraba solo si _player era de los
	# retirados, pero la espera es lo que cuelga la pelea: si le estaba pidiendo algo a EL (su accion,
	# la frase de un conjuro), hay que soltarla igual, o el ATB se queda congelado esperando una
	# respuesta de alguien que ya no tiene pantalla.
	if _esperando_a == peer:
		espejo._fin_de_espera()
		_state = State.ADVANCING
	if _huidos.has(_player):
		# El turno lo tenia el que ya no esta: pasa a alguien en pie y que siga corriendo el ATB, o
		# la pelea se queda esperando eternamente una accion que no va a llegar.
		_player = _aliados_vivos()[0]
		_state = State.ADVANCING
	_set_log(motivo)
	_update_hp()


# ¿QUEDA ALGUIEN DE ESE PEER peleando en mi pantalla? (sus personajes, sin contar a los que ya se
# retiraron). Lo pregunta la red antes de sacarle: la huida individual los retira ella misma, y sin
# esto se repetiria el aviso y se pisaria su mensaje ("escapa de la pelea") con otro.
func tiene_en_pie_a(peer: int) -> bool:
	if _espejo or peer == 0:
		return false
	for c in _aliados:
		if int(_dueno_aliado.get(c, 0)) == peer and not _huidos.has(c):
			return true
	return false


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
		b["panel"].add_theme_stylebox_override("panel", figuras._sb_bloque(false))
		b["chips"].visible = false
		if _fx != null:
			_fx.pintar_estados(b, [], false)   # ver _apagar_bloque
		# Y se QUITA de la fila, no solo se apaga: la fila no hace wrap (216 px por bloque en un
		# viewport de 1152), asi que si el que huyo sigue ocupando sitio, el bloque del que vuelve a
		# entrar se saldria de la pantalla. Su entrada se queda en _bloques_aliados para no
		# descuadrar los indices, que se cruzan con _aliados.
		#
		# Se esconde LA COLUMNA y no el panel: la columna es quien ocupa el hueco en la banda (y
		# lleva dentro la tarjeta y el sprite), asi que ocultando solo el panel el sitio seguia
		# pillado y el sprite se quedaba plantado ahi.
		b["columna"].visible = false


# CIERRA la accion del enemigo y congela el ATB mientras se ve. Es el unico sitio que decide
# cuanto dura un turno enemigo, y por eso los 16 puntos que lo llaman no han tenido que cambiar:
# los que traen golpes se llevan la animacion, y los que no (aturdido, invocacion, un debuff a
# secas) se llevan su pausa corta de lectura.
func _pausa_lectura() -> void:
	# LOS CONTRAATAQUES, LOS ULTIMOS. Se encolan aqui, con todos los golpes del bicho ya dentro, para
	# que se vean DESPUES de su ataque y no encima. Ver _soltar_contraataques.
	enemigos._soltar_contraataques()
	# La cola se suelta ANTES del _update_hp: asi lo primero que se ve es la embestida, y la vida
	# baja detras, mientras la tarjeta vuelve a su sitio.
	var dur: float = _fx.arrancar_cola() if _fx != null else 0.0
	espejo._soltar_impactos_red()
	# Espejo de _fin_de_eleccion, para el otro bando: por aqui pasan TODAS las acciones enemigas, asi
	# que es donde se repintan sus chips. Sin esto, un bicho que solo te pone un debuff (sin quitarte
	# vida) no actualizaba nada y el estado no aparecia hasta el siguiente golpe.
	_update_hp()
	_pause_left = dur if dur > 0.0 else PAUSA_SIN_GOLPE
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
	# El modo prueba YA NO es 1v1 (se entra en grupo como en cualquier pelea), asi que el titulo va
	# con el primero y, si habia mas, se dice: el DPS por turno enemigo se reparte entre todos los
	# que peguen, y sin este aviso el numero se lee mal.
	var contra: String = _enemies[0].nombre if not _enemies.is_empty() else "?"
	if _enemies.size() > 1:
		contra += " (+%d mas: el DPS por turno enemigo va repartido)" % (_enemies.size() - 1)
	print("[dps] ===== RESUMEN DE PRUEBA vs %s =====" % contra)
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
	altas._apagar_bloque(e)
	print("[combate] %s cae (quedan %d en pie)" % [e.nombre, _vivos().size()])
	# Si el que ha caido era tu objetivo, salta al siguiente vivo. _objetivo() ya lo haria
	# solo, pero hay que mover _target_idx para que el borde blanco se pinte donde toca.
	if _target_idx >= 0 and _target_idx < _enemies.size() and _enemies[_target_idx] == e:
		_reseleccionar()
	# LA COLA: el que esperaba entra en este hueco. Va aqui, en el embudo de todas las muertes, y no
	# delante de cada "¿quedan vivos?": asi, cuando se pregunta, el que entra ya cuenta y la pelea no
	# se da por ganada con gente esperando. El espejo no simula: lo hace quien ejecuta la pelea.
	if not _espejo:
		var hueco: int = _enemies.find(e)
		Game.meter_de_la_cola(hueco)
		if hueco >= 0 and hueco < _enemies.size() and _enemies[hueco] != e \
				and _target_idx == hueco:
			figuras._seleccionar(hueco)   # el nuevo ocupa el sitio de tu objetivo: que se vea marcado


# Pasa el objetivo al siguiente enemigo VIVO (buscando hacia abajo y dando la vuelta desde el
# actual: el de al lado es el candidato mas natural). Si no queda ninguno da igual: el
# llamador esta a punto de terminar el combate.
func _reseleccionar() -> void:
	for i in _enemies.size():
		var idx: int = (_target_idx + 1 + i) % _enemies.size()
		if _enemies[idx].is_alive():
			figuras._seleccionar(idx)
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

# Lo que pega la SEGUNDA mano al entrar detras, con dos armas. Es el mismo 0.6 que llevan por defecto
# las habilidades en su mano mala (AbilityData.dual_golpe_mult): entrar con dos armas tiene que valer
# mas que con una, pero no el doble.
const DUAL_SEGUIMIENTO_MULT := 0.6

# Los enemigos a los que un golpe de los tuyos ha hecho daño en la accion que se esta cerrando (lo apunta
# efectos._fx_golpe). Se vacia al cerrar cada accion.
var golpeados_en_la_accion: Array = []

func _disparar_seguimientos(obj: Combatant) -> void:
	if _en_seguimiento or obj == null or not obj.is_alive():
		return
	# Solo si de verdad le ha pegado alguien de los tuyos: una accion que no golpea (Filo emponzoñado, una
	# cura, un buff) no abre ningun hueco, aunque ese enemigo este seleccionado.
	if not golpeados_en_la_accion.has(obj):
		return
	var escoltas: Array = []
	for al in _aliados_vivos():
		if al != _player and (al.has_status(StatusEffects.Id.ESCOLTA)
				or al.has_status(StatusEffects.Id.OPORTUNISTA)):
			escoltas.append(al)
	if escoltas.is_empty():
		return
	_en_seguimiento = true
	var quien_actuaba: Combatant = _player
	for esc in escoltas:
		if not obj.is_alive():
			break
		var pct: float = 0.0
		var inst = null
		# EL OPORTUNISTA (daga) manda sobre la Escolta si lleva los dos y le pilla a tiro: entra a la
		# espalda. En el mapa, fuera de su alcance no entra por el (y si no hay Escolta, no entra).
		var oport = null
		for e in esc.statuses:
			if e.id() == StatusEffects.Id.OPORTUNISTA:
				var alc: float = float(e.d.get("alcance_mapa", 0.0))
				if not tactico or alc <= 0.0 \
						or turno_mapa.pies_de(esc).distance_to(turno_mapa.pies_de(obj)) <= alc:
					oport = e
		for e in esc.statuses:
			if e.id() == StatusEffects.Id.ESCOLTA:
				pct = maxf(pct, float(e.d.get("seguimiento_pct", 0.0)))
				inst = e
		if oport != null:
			inst = oport
			pct = float(oport.d.get("seguimiento_pct", 0.0))
		if pct <= 0.0:
			continue
		# NO ENTRA EL QUE NO PUEDE PEGAR. Este golpe salta FUERA de tu turno, asi que no pasa por
		# ningun tick de estados y se colaba con lo que hiciera falta: aturdido, muerto de miedo o
		# clavado al suelo, entraba igual. Y NO GASTA CARGA, que es lo importante: no ha llegado a
		# entrar, asi que no se le cobra la entrada.
		if not esc.puede_atacar():
			_log_extra("%s no llega a entrar detrás." % esc.nombre)
			continue
		# SE PAGA UNA CARGA POR ENTRADA. La Escolta se mide en veces que entras, no en turnos: cada
		# entrada gasta una y, cuando se acaban, el estado se va aunque le sobren turnos. Se cobra
		# ANTES de resolver: entrar y fallar tambien es haber entrado. Y es UNA por entrada aunque
		# lleve dos armas y pegue dos veces -- lo que se cobra es meterse en el hueco, no el numero
		# de tajos que quepan.
		if inst != null and inst.gastar_uso():
			esc.quitar_estado(inst.id())
			_log_extra("%s se queda sin huecos que aprovechar." % esc.nombre)
		# EL OPORTUNISTA APARECE A LA ESPALDA: del otro lado del que acaba de pegar. Se pide antes de sus
		# golpes, que es el orden en que viaja al espejo.
		var crit_extra: float = 0.0
		if oport != null:
			crit_extra = float(oport.d.get("crit_extra", 0.0))
			if tactico:
				turno_mapa.pedir_salto(esc, obj, quien_actuaba)
		# _player es "quien tiene el turno" en todo el motor de golpes, asi que se le presta un
		# momento al escolta para que el golpe salga con SUS numeros, y se devuelve al acabar. TODO
		# lo que lea _player (la imbuicion, la excelia, el mana) tiene que quedar dentro del prestamo.
		_player = esc
		var pj_esc: PersonajeData = Game.pj_de_combatant(esc)
		# CON DOS ARMAS SE ENTRA DOS VECES, una por mano. Antes pegaba un solo golpe con la mano que
		# le hubiera quedado puesta del turno anterior, asi que el dual no se notaba en absoluto.
		# El segundo va al DUAL_SEGUIMIENTO_MULT, igual que la mano mala de cualquier habilidad.
		var manos: int = 2 if esc.hands.size() >= 2 else 1
		var conecto: bool = false
		var imbuido: bool = false
		for i in manos:
			if not obj.is_alive():
				break
			esc.set_active_hand(i)
			# El estilo se lee DESPUES de fijar la mano: en dual, cada golpe se ve con SU arma.
			var estilo: int = efectos._estilo_de_habilidad(null, esc)
			# El del Oportunista es una puñalada, no su basico.
			if oport != null:
				estilo = CombatFX.Estilo.PUNALADA
			var arma: String = esc.current_hand_name()
			var m_mano: float = 1.0 if i == 0 else DUAL_SEGUIMIENTO_MULT
			efectos._fx_tanda(i)   # los dos golpes son dos, no uno: cada uno con su tanda
			var r := StatsMath.resolve_attack(esc, obj, false, -1.0, crit_extra)
			if r.evaded:
				_log_extra("%s entra detrás pero %s lo esquiva. 💨" % [esc.nombre, obj.nombre])
				efectos._fx_golpe(esc, obj, 0.0, false, true, Elementos.Elemento.NINGUNO, estilo)
				continue
			var dmg: float = float(r.damage) * pct * m_mano
			var elem_dmg: float = float(r.get("dmg_imbue", 0.0))
			obj.take_damage(dmg)
			efectos._fx_golpe(esc, obj, dmg, r.crit, false,
				esc.imbue_elemento if elem_dmg > 0.0 else Elementos.Elemento.NINGUNO, estilo)
			_apuntar_dano(obj, dmg, esc)
			_dps_add("Seguimiento (%s)" % arma, dmg)
			conecto = true
			# EXCELIA. Es un golpe de verdad y entrena como tal, con el mismo reto y el mismo peso de
			# arma que el basico (ver _accion_atacar).
			var mv: float = esc.motion_value
			Game.ganar("fuerza", _reto(obj, pj_esc) * mv, Game.GAIN_FUERZA_ATAQUE,
				Game.RETO_MAX_FISICO, pj_esc)
			var linea: String = "%s entra detrás con %s: %.2f%s" % [
				esc.nombre, arma, dmg, " 💥" if r.crit else ""]
			if r.crit:
				var agi: float = minf(mv, Game.GAIN_AGILIDAD_CRIT_MV_MAX)
				Game.ganar("agilidad", _reto(obj, pj_esc) * agi, Game.GAIN_AGILIDAD_CRITICO,
					Game.RETO_MAX_FISICO, pj_esc)
			# LA IMBUICION, COMPLETA. El daño elemental ya venia dentro de 'damage' -- o sea que
			# entraba gratis --, pero lo demas no estaba: ni se gastaban los amplificadores, ni se
			# tiraban los estados, asi que el veneno del Filo emponzoñado NO PRENDIA NUNCA por aqui.
			if elem_dmg > 0.0:
				magia._gastar_amplificadores(obj, esc.imbue_elemento)
				imbuido = true
			for nom in esc.roll_on_hit(obj):
				linea += "  Le inflige %s." % nom
			var imb: String = esc.roll_imbue(obj)
			if imb != "":
				linea += "  ⚡ Le inflige %s." % imb
				imbuido = true
			_log_extra(linea)
			# DURABILIDAD: el arma que entra se gasta, como en cualquier golpe.
			Game.desgastar_arma(esc.current_hand_slot(), pj_esc)
		# UNA carga de imbuicion por ENTRADA, no por golpe: la misma regla que las habilidades ("una
		# habilidad = un uso, traiga los golpes que traiga"). Solo si de verdad ha entrado algo.
		if conecto and imbuido:
			magia._gastar_imbue()
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
	# Detras del primero que de verdad ha encajado un golpe tuyo (en un area el principal puede no ser
	# uno de ellos). Y la lista se vacia aqui: es de ESTA accion.
	for o in objs:
		if o is Combatant and golpeados_en_la_accion.has(o):
			_disparar_seguimientos(o)
			break
	golpeados_en_la_accion.clear()
	var vistos: Dictionary = {}   # el mismo enemigo puede venir por el area Y por un rebote
	for o in objs:
		if o != null and not o.is_alive() and not vistos.has(o):
			vistos[o] = true
			_morir_enemigo(o)
	if _vivos().is_empty():
		_end(true)
	else:
		# El turno TUYO tambien dura lo que dure su animacion. Antes volvia a ADVANCING en el acto,
		# y con la embestida puesta eso significaba que un combo de ocho golpes se quedaba a medias
		# porque el bicho de al lado ya tenia la barra llena y le montaba su turno encima.
		# Se reutiliza PAUSED (que es lo que congela el ATB); si no hubo golpes, todo sigue igual
		# que siempre y no se añade ni un frame de espera.
		var dur: float = _fx.arrancar_cola() if _fx != null else 0.0
		espejo._soltar_impactos_red()
		if dur > 0.0:
			_pause_left = dur
			_state = State.PAUSED
		else:
			_state = State.ADVANCING


func _end(player_won: bool, fled: bool = false) -> void:
	# El GOLPE MORTAL tambien se ve: la cola se suelta igual aunque la pelea acabe aqui. No se
	# cancela nada -- la animacion se queda corriendo sobre la pantalla de resultado, que es
	# justo lo que se quiere ver. Lo unico que no puede pasar es que se quede sin mandar a los
	# espejos, de ahi el volcado de impactos.
	# EL RIPOSTE QUE REMATA tambien se ve. Los contraataques se guardan para soltarlos al final de la
	# accion enemiga (ver _soltar_contraataques), y si el que mata al ultimo bicho es uno de ellos, la
	# pelea se cierra por aqui sin pasar por _pausa_lectura: sin esta linea, el golpe que gana el
	# combate era justo el unico que no se veia.
	enemigos._soltar_contraataques()
	if _fx != null:
		_fx.arrancar_cola()
	espejo._soltar_impactos_red()
	_dps_resumen()
	_player_won = player_won
	# PASIVA RNG SLAYER: cada bicho ABATIDO de verdad tira por su slayer de familia (ultra-raro), a nombre
	# de quien le dio el ultimo golpe. Va AL ACABAR y no al pulsar Continuar: en multi, quien sale de su
	# espejo antes se lleva su lote en ese momento (y en la pelea de un trabajador, que no pulsa nada, se
	# van todos antes), asi que tirada despues se quedaba en la copia de su personaje.
	if not _espejo and _state != State.FINISHED:
		for e in _enemies:
			if not e.is_alive():
				Game.rodar_slayer_por_familia(int(e.familia), _ultimo_en_golpear.get(e))
	_state = State.FINISHED
	magia._limpiar_casteo()
	_casteos.clear()   # y los conjuros a medias de los demas: la pelea ha terminado para todos
	_ocultar_cajas()
	_continue_button.visible = true
	_continue_button.disabled = false
	_continue_button.text = "Continuar"
	# EL REMATE SUENA AQUI, con el "Continuar" en pantalla, que es cuando el jugador esta leyendo el
	# resultado. Estaba en Game._on_combat_finished, o sea al PULSAR el boton: la fanfarria empezaba
	# justo cuando te ibas y se quedaba sonando encima del mapa. Al pulsar se corta (Musica.desapilar).
	#
	# HUIR NO LLEVA REMATE: no has ganado, pero tampoco es para tocar la marcha funebre.
	if player_won:
		Musica.remate("victoria")
	elif not fled:
		Musica.remate("derrota")
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
	espejo._difundir()


# Log-HISTORIAL: cada evento se apila como una frase nueva (antes era una sola linea que se
# sobrescribia y no daba tiempo a leer los DoT / lo que aplicabas). Evita duplicar la misma
# consecutiva.
#
# SIN TOPE: la pelea ENTERA se puede leer, dure lo que dure (decision del usuario del 15/09: hay
# peleas mucho mas largas que 200 frases). Vive lo que la pantalla: al cerrar la pelea se va con ella.
#
# Y POR ESO SE AÑADE, NO SE RECOMPONE. Antes era un Label al que se le hacia "\n".join de todo en
# cada frase; medido con 3000 frases, cada una nueva costaba 70 ms (un tiron por golpe). Con un
# RichTextLabel y add_text cuesta 1,3 ms a esa altura.
#
# En el ESPEJO las frases de la pelea llegan con la instantanea (ver espejo.aplicar_instantanea) y
# entran por _pintar_linea_log, sin pasar por el filtro de repetidas: ese filtro ya lo paso el
# anfitrion, y aqui se comeria dos golpes iguales seguidos.
var _log_lines: Array[String] = []

func _set_log(texto: String) -> void:
	if _log_lines.size() > 0 and _log_lines[_log_lines.size() - 1] == texto:
		return
	_pintar_linea_log(texto)


func _pintar_linea_log(texto: String) -> void:
	if not _log_lines.is_empty():
		_log.newline()
	_log_lines.append(texto)
	_log.add_text(texto)
	# A lo ultimo que ha pasado, que es lo que hay que estar viendo. Quien quiera mirar atras sube
	# con la rueda; el siguiente golpe le devolvera al final, que es donde esta la pelea.
	_log_al_final()


# El registro entero de golpe: al recoger una pelea en un relevo, o cuando el espejo pide el log
# completo porque le falta un trozo (ver espejo.aplicar_log_entero).
func _rehacer_log(lineas: Array) -> void:
	_log.clear()
	_log_lines.clear()
	for l in lineas:
		if not _log_lines.is_empty():
			_log.newline()
		_log_lines.append(String(l))
		_log.add_text(String(l))
	_log_al_final()


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
	var suma: float = float(a.fuerza + a.resistencia + a.destreza + a.agilidad + a.magia)
	# UN MUTANTE entrena mas, y hay que decirlo aqui porque sus habilidades son las MISMAS que las
	# del bicho corriente: sus multiplicadores viven en la vida, el ataque y la defensa (ver
	# EnemyData.MUT_*), asi que la suma de stats no se entera de que acabas de tumbar a un mini-jefe.
	# Subirle las habilidades en su lugar no vale: el daño ya se calcula con ellas y se cobraria dos
	# veces. El factor es lo que cuesta MATARLO, no lo que dice su ficha.
	if not c.mutante:
		return suma
	return suma * float(EnemyData.mult_mutante(c.es_jefe)["poder"])


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


# LA FICHA DEL QUE HACE MAGIA, con la lupa puesta. Los contadores de hechizo/frase son los UNICOS
# que sacan su personaje de `_player` -estado de PANTALLA, que se presta y se devuelve en
# hechizo_de_entrada y en Escolta-, mientras que los que funcionan bien (esquiva, daño) lo sacan del
# combatiente del evento. Ese es el unico sospechoso que queda del tanque con hechizos_exp = 140 sin
# haber llevado un conjuro en su vida.
#
# INSTRUMENTACION TEMPORAL (16/08/2026): escribe en el log a QUIEN se le apunta cada cosa, y si la
# ficha no aparece, todo lo que hace falta para saber por que. Se quita cuando el log conteste.
func _pj_de_magia(c: Combatant, que: String) -> PersonajeData:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj == null:
		var nom: String = c.nombre if c != null else "(nadie)"
		push_warning("[magia] '%s' sin ficha: %s no esta en la pelea de Game" % [que, nom])
		print("[magia] SIN FICHA al %s | combatiente='%s' | espejo=%s | es_aliado=%s | huido=%s | aliados=%d" % [
			que, nom, str(_espejo), str(_aliados.has(c)), str(_huidos.has(c)), _aliados.size()])
	else:
		print("[magia] %s -> se le apunta a %s" % [que, pj.nombre])
	return pj


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


func _update_timeline() -> void:
	if _timeline == null:
		return
	var ratios: Dictionary = {}
	for c in _gauge:
		ratios[c] = _gauge[c] / UMBRAL
	_timeline.set_ratios(ratios)
# Deja la pelea corriendo a 'v'. Un solo sitio: lo llaman el arranque, el boton y las instantaneas
# que llegan del dueño, y los tres tienen que tocar exactamente lo mismo.
func _aplicar_velocidad(v: float) -> void:
	_vel_pelea = clampf(v, 0.5, 4.0)
	if _fx != null:
		# Los EFECTOS llevan ademas el ritmo base (mas lentos de lo que dicen sus constantes); la
		# barra de accion no (ver _process). Por eso se multiplican aqui y no en el ATB.
		_fx.escala_tiempo = CombatFX.RITMO_BASE * _vel_pelea
	if _boton_vel != null and is_instance_valid(_boton_vel):
		_boton_vel.queue_redraw()
# Estirar / recoger el registro. Estirado llega hasta donde empiezan los botones, que es todo el
# sitio que hay sin taparlos: leer la pelea entera no puede costarte el turno.
func _alternar_log() -> void:
	montaje._log_abierto = not montaje._log_abierto
	montaje._log_boton.text = "📜 Registro  ▲" if montaje._log_abierto else "📜 Registro  ▼"
	var alto: float = montaje.ALTO_LINEA_LOG * float(montaje.LOG_LINEAS)
	if montaje._log_abierto:
		var tope: float = get_viewport_rect().size.y - montaje._alto_zona_botones() \
			- MARGEN_UI * 3.0 - Tactil.borde.y * 2.0 - 28.0
		alto = maxf(alto, tope)
	montaje._log_scroll.custom_minimum_size.y = alto
	# El alto acaba de cambiar: hay que volver a pegarse al final o se queda mirando a media pelea.
	_log_al_final()
# Pega la vista al ULTIMO renglon. Se llama tras cada linea nueva: lo que acaba de pasar es lo que
# hay que estar viendo. Con un frame de espera porque el ScrollContainer no conoce su alto nuevo
# hasta que el Label se ha vuelto a medir.
func _log_al_final() -> void:
	if montaje._log_scroll == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(montaje._log_scroll):
		return
	montaje._log_scroll.scroll_vertical = int(montaje._log_scroll.get_v_scroll_bar().max_value)
# --- PUENTES a habilidades: lo llaman desde fuera por su nombre (ver combat_habilidades.gd) ---
func soltar_carga(nombre: String, seq: int = 0) -> void:
	habilidades.soltar_carga(nombre, seq)


# --- PUENTES a magia: lo llaman desde fuera por su nombre (ver combat_magia.gd) ---
func aplicar_casteo_entrante(idx_aliado: int, d: Dictionary) -> void:
	magia.aplicar_casteo_entrante(idx_aliado, d)

func hechizo_de_entrada(spell: SpellData, idx_enemigo: int, idx_lanzador: int) -> void:
	magia.hechizo_de_entrada(spell, idx_enemigo, idx_lanzador)

func lanzar_conjuro(nombre: String, seq: int = 0) -> void:
	magia.lanzar_conjuro(nombre, seq)

func recitar_frase(idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0) -> void:
	magia.recitar_frase(idx, opciones, nombre, largo, seq)

func retomar_canto(spell: SpellData, idx_frase: int, idx_lanzador: int) -> void:
	magia.retomar_canto(spell, idx_frase, idx_lanzador)


# --- PUENTES a altas: lo llaman desde fuera por su nombre (ver combat_altas.gd) ---
func acabada() -> bool:
	return altas.acabada()

func anadir_aliado(c: Combatant, agotado: bool = false) -> bool:
	return altas.anadir_aliado(c, agotado)

func anadir_enemigo(data: EnemyData, t: float, hp: float = -1.0, estados: Array = [], es_jefe: bool = false, mutante: bool = false, hueco: int = -1, muneco: Dictionary = {}) -> int:
	return altas.anadir_enemigo(data, t, hp, estados, es_jefe, mutante, hueco, muneco)

func esperar_refuerzo(si: bool) -> void:
	altas.esperar_refuerzo(si)

func fijar_cola(n: int) -> void:
	altas.fijar_cola(n)

func hueco_huido_de(uid: String) -> int:
	return altas.hueco_huido_de(uid)

func readmitir_aliado(idx: int, c: Combatant, agotado: bool = false) -> bool:
	return altas.readmitir_aliado(idx, c, agotado)


# --- PUENTES a efectos: lo llaman desde fuera por su nombre (ver combat_efectos.gd) ---
func _chips_de(c: Combatant) -> Array:
	return efectos._chips_de(c)



# --- PUENTES a espejo: lo llaman desde fuera por su nombre (ver combat_espejo.gd) ---
func aplicar_accion_remota(accion: Dictionary, emisor: int = 0) -> void:
	espejo.aplicar_accion_remota(accion, emisor)

func aplicar_atb(ratios: PackedFloat32Array) -> void:
	espejo.aplicar_atb(ratios)

# Las huellas del mapa (lo que se apunta y lo que se carga): ver turno_mapa.estado_huellas.
func aplicar_huellas(datos: PackedFloat32Array) -> void:
	turno_mapa.aplicar_huellas(datos)

func huella_de_espejo(datos: PackedFloat32Array, emisor: int = 0) -> void:
	turno_mapa.huella_de_espejo(datos, emisor)

func aplicar_impactos(datos: PackedInt32Array) -> void:
	espejo.aplicar_impactos(datos)

func aplicar_instantanea(snap: Dictionary) -> void:
	espejo.aplicar_instantanea(snap)

func log_entero() -> Array:
	return _log_lines.duplicate()

func aplicar_log_entero(lineas: Array) -> void:
	espejo.aplicar_log_entero(lineas)

func aplicar_roster(roster: Dictionary) -> void:
	espejo.aplicar_roster(roster)

func cerrar_espejo() -> void:
	espejo.cerrar_espejo()

func indice_de_aliado(c: Combatant) -> int:
	return espejo.indice_de_aliado(c)

func marcar_dueno(c: Combatant, peer: int) -> void:
	espejo.marcar_dueno(c, peer)

func retomar(estado: Dictionary, cs: Array, filas_e: Array) -> void:
	espejo.retomar(estado, cs, filas_e)

func roster_para_espejo() -> Dictionary:
	return espejo.roster_para_espejo()

func setup_espejo(roster: Dictionary) -> void:
	espejo.setup_espejo(roster)

func turno_mio(idx: int, seq: int = 0, radio: float = 0.0) -> void:
	espejo.turno_mio(idx, seq, radio)
