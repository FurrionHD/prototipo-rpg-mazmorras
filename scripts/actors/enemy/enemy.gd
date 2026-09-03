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

# MUTANTE (el "mini-jefe"): el mismo bicho de siempre, mas grande y mucho mas bruto. Lo decide un
# dado en _ready con EnemyData.MUTANTE_PROB. Ver la cabecera de MUTANTE_PROB para el porque.
var mutante: bool = false

# Mutacion IMPUESTA desde fuera: -1 = tirala tu (lo normal), 0 = no, 1 = si. Existe por dos
# motivos, y los dos son bugs si falta:
#   - el JEFE del piso la trae a 0: si no, el dado podria ascender al boss y volverlo imposible.
#   - al RESTAURAR un piso hay que devolver la que tenia, igual que la 't': si no, el mutante del
#     que te escapaste se convierte en un bicho normal (o al reves) por volver a bajar.
# Se pone ANTES de add_child porque quien la lee es _ready.
var mut_forzada: int = -1

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

# ESTADOS con los que quedo de ese combate (el veneno que le dejaste al huir). Espejo exacto de
# hp_restante, y por lo mismo en el NODO y no en el EnemyData: son de ESTE bicho, no de su especie.
# Formato: la lista de dicts de StatusEffects.dict_de_instancia. Siguen corriendo por el mapa a
# Game.SEG_POR_TURNO_FUERA segundos por turno (ver _tick_estados_fuera), asi que un bicho al que
# huyes envenenado puede morirse solo: escapar con el veneno puesto es una forma legitima de matar.
var estados_restantes: Array = []
var _reloj_estados: float = 0.0

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
# EL INSTANTE DEL IMPACTO. Antes, en cuanto la embestida (o un espadazo tuyo) conectaba, se llamaba
# a _start_combat EN EL MISMO FOTOGRAMA -- la pantalla de combate se llevaba la escena a mitad del
# lunge y no daba tiempo a ver nada, la misma trampa que ya tenia el golpe del jugador (ver
# player._tick_ataque). Ahora conectar arma _impacto_t (ver _iniciar_impacto) y el bicho se queda
# PARALIZADO en el sitio ese rato antes de cortar -- lo que dura verse el golpe.
#
# MISMA DURACION que el espadazo del jugador (player.DUR_GOLPE = 8 fotogramas a 12 fps), a
# proposito: que el bicho parezca mas brusco o mas lento que tu al entrar en combate se nota en
# seguida, aunque las dos animaciones no compartan nada de codigo (no hay class_name en player.gd
# para referenciar la constante de verdad, asi que el numero va duplicado -- si se toca uno, tocar
# el otro).
const EMBESTIDA_IMPACTO := 8.0 / 12.0
# DESCANSO TRAS UN REBOTE: la embestida conecto pero la pelea NO se abrio (el piso no es mio, el
# empuje al otro humano no colo). Es mucho mas largo que EMBESTIDA_ESPERA a proposito -- ese es el
# descanso de FALLAR el golpe, y aqui el golpe acerto: reintentarlo cada 0.6 s es lo que llenaba la
# mazmorra de porrazos mientras el dueño estaba metido en su pantalla de combate.
const REBOTE_ESPERA := 3.0
# Y un suelo para la ventana del impacto: aunque la carga se haya comido el reloj entero, el porrazo
# tiene que oirse y verse antes de que la pantalla se lleve la escena. Cortar a cero seria volver al
# bug de "entro directo, sin animacion".
const IMPACTO_MINIMO := 0.22

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
var _lado_desvio: int = 0            # por que lado viene esquivando la pared (0 = sin decidir)
var _dir_desvio: Vector2 = Vector2.ZERO   # la ultima direccion desviada, para no cambiar de idea
var _desvio_t: float = 0.0           # lo que le queda de compromiso con ese lado
# ANTI-ORBITA (ver _vigilar_orbita): lo mas cerca que ha llegado a estar de su presa en ESTA
# persecucion, y cuanto lleva sin mejorarlo.
var _orbita_record: float = 99999.0
var _orbita_t: float = 0.0
var _orbita_cambios: int = 0
# DESATASCO: mientras dura, en vez de empujar la roca la BORDEA (ver _desatascar_bordeando).
var _bordeo: Vector2 = Vector2.ZERO       # la tangente elegida; ZERO = no esta desatascandose
var _bordeo_t: float = 0.0                # lo que le queda de rodeo
var _bordeos: int = 0                     # rodeos seguidos sin llegar a despegarse
var _windup_timer: float = -1.0  # -1 = no esta preparando ataque
var _winding: bool = false       # true mientras hace el aviso de ataque
# EMBESTIDA: direccion COMPROMETIDA al acabar el aviso (no se recalcula: por eso se puede esquivar),
# lo que le queda de carga, y el descanso tras fallar una.
var _embiste_dir: Vector2 = Vector2.ZERO
var _embiste_t: float = 0.0
var _embiste_espera: float = 0.0
# EL IMPACTO (ver _iniciar_impacto): -1 = nada pendiente. Mientras cuenta, el bicho esta parado y
# _start_combat todavia NO se ha llamado -- se llama solo (con 'enemy_initiated' ya decidido) al
# llegar a 0.
var _impacto_t: float = -1.0
var _impacto_enemy_initiated: bool = false
var _combat_triggered: bool = false
# ESPERANDO HUECO (hito 5.4): alcance a alguien que ya peleaba pero la pelea estaba llena. Me quedo
# plantado al lado y lo reintento; en cuanto muera uno de los que pelean, entro en su hueco. Asi
# matar no te alivia del todo: sabes que hay mas esperando fuera.
var _esperando_hueco: bool = false
var _t_reintento: float = 0.0
const REINTENTO_HUECO := 0.4   # cada cuanto vuelvo a llamar a la puerta
var current_move_speed: float = 40.0

var _dead: bool = false       # true cuando es un cadaver (combate ganado)
var extracted: bool = false   # true cuando ya le has sacado el cristal

# Indicadores visuales (creados por codigo). Solo la linea de "hacia donde mira": el cono de vision
# ya no se dibuja (ver _crear_indicadores).
var _facing_line: Line2D = null
# Rastro del elemento del bicho (null si no es elemental). Ver _crear_fx_elemental.
var _fx_elem: CPUParticles2D = null

@onready var _color_rect: ColorRect = $ColorRect
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite

# RASTRO DE BABA (solo slimes, ver data.es_slime): cada cuanto deja una marca mientras anda.
const RASTRO_INTERVALO := 0.35
var _rastro_timer: float = 0.0
var _anim_actual: String = ""
var _sprite_base_scale: float = 1.0   # ver _ready: la textura generada no es 1px = 1 unidad
# true = a este sprite hay que aplicarle escala_visual desde aqui (arte de verdad, que viene a un
# tamaño fijo). false = el generador ya lo dibujo del tamaño que toca, con mas celdas.
var _sprite_escala_propia: bool = false
# El cuerpo real de este bicho en planta (ancho, largo), o ZERO si no lo declara y hay que usar la
# caja de 32x32 de siempre. Ver _aplicar_colision.
var _tam_cuerpo: Vector2 = Vector2.ZERO
# true = su colision es alargada y tiene que girar con el (ver _aplicar_colision).
var _colision_gira: bool = false


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
	mutante = (mut_forzada == 1) if mut_forzada >= 0 else (randf() < EnemyData.MUTANTE_PROB)

	if data != null:
		# Color base + tinte por 't' (los mas fuertes de su franja salen mas claros).
		_color_rect.color = data.color_visual(current_t)
		# SPRITE ANIMADO: quien lo dibuja lo decide SpritesEnemigo (el arte de verdad manda; si no,
		# el generador de su familia; si no hay ninguno, se queda el ColorRect de siempre). La regla
		# vive alli y no aqui porque el visor de animaciones tiene que usar EXACTAMENTE la misma.
		var frames: SpriteFrames = SpritesEnemigo.frames_de(data, current_t)
		if frames != null:
			_color_rect.visible = false
			_sprite.visible = true
			_sprite.sprite_frames = frames
			# La textura generada NO es 1 pixel = 1 unidad de mundo: cada generador tiene su propia
			# rejilla y dice cuanto hay que escalarla.
			_sprite_base_scale = SpritesEnemigo.escala_de(data)
			_sprite_escala_propia = SpritesEnemigo.hay_que_estirar(data)
			_sprite.scale = Vector2.ONE * _sprite_base_scale
			# El sprite generado va a 1 celda = 1 pixel y lo AMPLIA este nodo: sin filtro NEAREST el
			# escalado lo interpola y el pixel-art sale borroso.
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_anim_actual = "idle_0"
			_sprite.play(_anim_actual)
		# La forma de su cuerpo, para que la colision sea a su medida y no una caja de 32x32. Va
		# ANTES de _aplicar_escala, que es quien la monta.
		_tam_cuerpo = SpritesEnemigo.tam_cuerpo(data)
		# Un MUTANTE se ve mas grande, y eso no es un adorno: es el aviso. Tienes que poder decidir
		# si lo peleas o lo rodeas ANTES de tocarlo, y la unica informacion que hay a distancia es su
		# silueta. Por eso la escala va aqui, en la misma linea que la de los elites de siempre.
		_aplicar_escala(data.escala_visual * (EnemyData.MUT_ESCALA if mutante else 1.0))
		# Un bicho ELEMENTAL emana lo mismo que tu cuando te imbuyes de ese elemento: el slime de
		# fuego echa los mismos cuadraditos naranjas que un Manto de Brasas. Es a proposito -- el
		# mismo color quiere decir la misma cosa, la vengas tu de echar o la traiga el bicho puesta.
		_crear_fx_elemental()
		_marcar_mutante()
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


# El rastro del elemento del bicho. Va DESPUES de _aplicar_escala porque el alto de las particulas
# se saca del tamaño real del cuerpo: un elite del doble de grande con particulas de enano se veria
# raro. La 'intensidad' es su elemento_intensidad, asi que uno solo TOCADO por el elemento (0.5)
# humea la mitad que uno hecho de fuego (1.0).
#
# El VENENO no entra aqui, y no es un olvido: no es un elemento sino un estado (ver elements.gd), y
# el slime venenoso no tiene campo 'elemento'. Sale sin rastro a proposito.
func _crear_fx_elemental() -> void:
	if not Elementos.tiene_color(data.elemento):
		return
	_fx_elem = Particulas.ascendentes(self, Elementos.color(data.elemento),
		clampf(data.elemento_intensidad, 0.0, 1.0), 32.0 * maxf(0.1, data.escala_visual))


# El tinte y los destellos del MUTANTE. El tamaño ya lo dice de lejos, pero dos bichos de la misma
# familia pueden tener escalas distintas de fabrica (el rey rata ya es 1.68), asi que hace falta una
# marca que no se pueda confundir con "es que este es de los grandes".
#
# El carmesi va como MODULATE y no cambiando su color base: asi funciona igual con el ColorRect de
# los que no tienen sprite y con el arte de los que si, sin que cada familia tenga que saber nada.
const MUT_TINTE := Color(1.35, 0.62, 0.66)
const MUT_AURA := Color(0.95, 0.18, 0.22)

func _marcar_mutante() -> void:
	if not mutante:
		return
	_color_rect.modulate = MUT_TINTE
	_sprite.modulate = MUT_TINTE
	# EL TAMAÑO DEL SPRITE. _aplicar_escala ya recibio la escala con el x1.2 dentro, pero solo estira
	# el sprite de los que declaran `hay_que_estirar` (arte de verdad): a los generados NO los toca,
	# porque su generador dibuja al bicho grande con MAS CELDAS y estirarlos deforma el pixel.
	#
	# Para el mutante hay que estirarlos igualmente, y es una excepcion decidida: la alternativa era
	# una version "mutante" del generador de cada uno de los veinte enemigos para decir exactamente lo
	# mismo que ya dicen el tinte y el aura. El pixel sale un 20% mas gordo y se nota si lo buscas;
	# a cambio, un mini-jefe se distingue de su especie a simple vista desde el otro lado de la sala.
	if _sprite.visible and not _sprite_escala_propia:
		_sprite.scale = Vector2.ONE * _sprite_base_scale * EnemyData.MUT_ESCALA
	# EL AURA. Las mismas particulas ASCENDENTES que emana un bicho elemental (el slime de fuego
	# humea naranja), aqui en rojo y a intensidad maxima: el mutante "arde" de rabia. Se usa ese
	# sistema y no los destellos del botin a proposito -- los destellos dicen "cogeme" y esto tiene
	# que decir "cuidado".
	#
	# Va DESPUES de _crear_fx_elemental, asi que un slime de fuego mutante lleva las dos: su humo
	# naranja de siempre Y el aura roja. Es correcto y se lee bien: sigue siendo de fuego, y ademas
	# esta mutado.
	Particulas.ascendentes(self, MUT_AURA, 1.0,
		32.0 * maxf(0.1, data.escala_visual * EnemyData.MUT_ESCALA))


# EL LATIDO. El tinte carmesi funciona en un golem pardo o en un jabali marron, pero hay bichos que
# YA son rojos -- el slime, sin ir mas lejos -- y sobre esos no dice nada: al lado del normal se ve
# el mismo rojo un poco mas vivo, y eso no es un aviso. Un PULSO si: el ojo caza el movimiento
# aunque el color sea el mismo, y ademas se lee como "esto esta acelerado", que es justo lo que es.
#
# El color de reposo de un mutante SALE DE AQUI y no de una asignacion suelta, y eso no es un
# capricho: _actualizar_indicadores reescribe el modulate del sprite EN CADA FRAME (es donde vive el
# aviso del golpe), asi que pintar el bicho de rojo una vez en _ready no dura ni un fotograma. Tiene
# que haber una sola autoridad sobre el modulate, y es esa.
const MUT_LATIDO_SEG := 0.55
const MUT_TINTE_PICO := Color(1.75, 0.80, 0.84)

func _tinte_reposo() -> Color:
	if not mutante:
		return Color.WHITE
	var f: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.001 * TAU / MUT_LATIDO_SEG)
	return MUT_TINTE.lerp(MUT_TINTE_PICO, f)


# Escala el cuerpo (ColorRect) y su colision. El cuerpo base es 32x32 centrado.
func _aplicar_escala(escala: float) -> void:
	var s: float = maxf(0.1, escala)
	_aplicar_colision(s)     # SIEMPRE, aunque la escala sea 1: la FORMA puede no ser la de siempre
	if is_equal_approx(s, 1.0):
		return
	# radio_extra se queda midiendose con escala_visual y NO con la forma de abajo, a proposito: no
	# es el tamaño del cuerpo sino cuanto hay que descontar en los ALCANCES (atacar, extraerle el
	# cristal). Atarlo a una forma alargada daria un alcance distinto segun por donde te pongas.
	radio_extra = 16.0 * (s - 1.0)
	var medio: float = 16.0 * s
	_color_rect.offset_left = -medio
	_color_rect.offset_top = -medio
	_color_rect.offset_right = medio
	_color_rect.offset_bottom = medio
	# El SPRITE no se estira: los generadores ya dibujan al bicho grande con MAS CELDAS, para que el
	# pixel mida siempre lo mismo (ver SpriteLienzo.UNIDADES_POR_CELDA). Estirarlo aqui es lo que
	# hacia que el Rey Slime y el Rey Rata salieran con unos pixelotes enormes.
	if _sprite.visible and _sprite_escala_propia:
		_sprite.scale = Vector2.ONE * _sprite_base_scale * s


# La colision, a la medida DEL BICHO y no una caja de 32x32 para todos.
#
# Antes era siempre cuadrada, y eso solo le queda bien a un bicho macizo y redondo como el slime.
# La rata mide 8,7 unidades de ancho vista de frente y chocaba con las paredes por un cuerpo que no
# tiene. Los que todavia son un ColorRect no declaran forma (tam_cuerpo devuelve ZERO) y se quedan
# con la caja de siempre.
#
# OJO: la RectangleShape2D viene del .tscn y se COMPARTE entre instancias -> hay que duplicarla
# antes de tocarla, o cambiaria el tamaño de TODOS los enemigos.
func _aplicar_colision(s: float) -> void:
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col == null or not (col.shape is RectangleShape2D):
		return
	col.shape = col.shape.duplicate()   # instancia propia: no tocar la de los demas
	var tam: Vector2 = _tam_cuerpo if _tam_cuerpo != Vector2.ZERO else Vector2(32.0 * s, 32.0 * s)
	(col.shape as RectangleShape2D).size = tam
	# ALARGADO = la colision GIRA con el bicho. Una rata de lado ocupa el triple que de frente, y sin
	# esto un cuerpo largo y fijo la haria chocar de costado por donde de verdad cabe. Los redondos
	# no giran: no serviria de nada y girar una forma pegada a una pared la empuja.
	_colision_gira = maxf(tam.x, tam.y) / maxf(1.0, minf(tam.x, tam.y)) >= 1.3
	# El largo va en +Y local, que es hacia donde mira con _facing = abajo (dir 0 = S).
	col.rotation = (_facing.angle() - PI * 0.5) if _colision_gira else 0.0


# Traduce estado + movimiento a la animacion que toca y la reproduce (solo si cambia: reiniciarla
# cada frame le cortaria el ciclo antes de que se llegue a ver).
#
# QUE animacion toca lo decide SpritesEnemigo, no esto: la misma regla la necesita el espejo de la
# otra maquina (remote_enemy.gd), y dos copias acaban divergiendo -- con lo que cada jugador veria
# al mismo bicho haciendo cosas distintas.
func _actualizar_animacion() -> void:
	if not _sprite.visible:
		return
	var nombre: String = SpritesEnemigo.animacion(
		_facing, _state == State.EMBESTIDA, velocity.length() > 2.0)
	if nombre != _anim_actual:
		_anim_actual = nombre
		_sprite.play(nombre)


# Deja una gota de baba cada RASTRO_INTERVALO mientras el slime esta EN MARCHA. Va en el arbol
# actual (no en el propio bicho) para que se quede clavada en el suelo, ver Particulas.marca_en_suelo.
func _actualizar_rastro(delta: float) -> void:
	if data == null or not data.es_slime or velocity.length() <= 1.0:
		_rastro_timer = 0.0
		return
	_rastro_timer -= delta
	if _rastro_timer > 0.0:
		return
	_rastro_timer = RASTRO_INTERVALO
	Particulas.marca_en_suelo(get_tree().current_scene, global_position, data.color_visual(current_t))


func _physics_process(delta: float) -> void:
	if _combat_triggered or data == null:
		return

	# Los estados que se llevo de la ultima pelea siguen corriendo. Va aqui dentro y no en un timer
	# aparte para heredar gratis las dos cosas que ya cumple este _process: no corre con el bicho
	# metido en una pelea (el guard de arriba) ni cuando ya es un cadaver (set_physics_process(false)
	# en morir), y se congela con la pausa del arbol igual que el reloj del jugador.
	if not estados_restantes.is_empty():
		_tick_estados_fuera(delta)
		if _dead:
			return   # se le fue la vida con el veneno: ya es un cadaver, no hay IA que correr

	# ESPERANDO HUECO en una pelea llena: quieto al lado, llamando a la puerta cada poco. Si la
	# pelea termina sin que entrara, vuelvo a la vida normal (y como sigo pegado, el contacto de
	# abajo abrira una pelea nueva).
	if _esperando_hueco:
		# Vale igual si la pelea es MIA o la esta espejando el jugador: mientras haya pantalla
		# delante, sigo llamando a la puerta.
		if not Game.hay_pelea_en_pantalla():
			_esperando_hueco = false
		else:
			velocity = Vector2.ZERO
			_t_reintento -= delta
			if _t_reintento <= 0.0:
				_t_reintento = REINTENTO_HUECO
				if Game.unir_enemigo_al_combate(self):
					_esperando_hueco = false
					_combat_triggered = true
			return

	# Aseguramos que hay a quien mirar. Persiguiendo NO se cambia de presa (o bastaria con que el
	# grupo se cruzara para que el bicho se quedara bailando entre dos objetivos).
	if _objetivo == null or not is_instance_valid(_objetivo):
		_objetivo = _aliado_mas_cercano()

	# EL IMPACTO: ya he conectado (mi embestida o tu espadazo) y estoy parado viendose el golpe.
	# _start_combat NO se ha llamado todavia -- se llama solo, con el 'enemy_initiated' que se
	# decidio al conectar, cuando el reloj llega a 0 (ver _iniciar_impacto). Va ANTES que el toque
	# de mas abajo: mientras esto cuenta no hay que mirar nada mas.
	if _impacto_t >= 0.0:
		if _dead:
			_impacto_t = -1.0
			return
		velocity = Vector2.ZERO
		_impacto_t -= delta
		if _impacto_t <= 0.0:
			_impacto_t = -1.0
			_start_combat(_impacto_enemy_initiated)
		return

	# TOCAR = ENGANCHARSE, en el estado que sea. Un bicho no puede estar empotrado contra ti (o
	# contra un companero) y seguir a lo suyo. Va ANTES que todo lo demas y no depende de que te
	# haya visto: cubre el caso de deambular y chocarse de morros en la oscuridad, que con la
	# deteccion por vista y oido no se disparaba nunca (un companero parado no hace ruido y puede
	# estar fuera del cono).
	#
	# YA NO ES COMBATE INSTANTANEO: pasa a perseguir/plantarse como si te hubiera visto, y el
	# windup+embestida que ya existen en _chase/_embestida hacen el resto solos (el contacto, que ya
	# es cierto -- estan tocandose --, dispara el impacto de arriba casi al instante). Asi CUALQUIER
	# enganche pasa por la misma embestida telegrafiada, sin atajos instantaneos.
	#
	# SIN 'return': si ya estaba en CHASE/EMBESTIDA (el toque se repite fotograma a fotograma
	# mientras los cuerpos siguen tocandose -- la colision no los separa) hay que dejar que el
	# despacho de mas abajo siga llamando a _chase()/_embestida(), o el windup no avanza NUNCA y el
	# bicho se queda parado en el sitio para siempre sin llegar a atacar. Volvia aqui cada
	# fotograma y cortaba el paso antes del 'match' -- por eso los enemigos habian dejado de poder
	# entrar en combate ellos primero.
	var pegado: Node2D = _aliado_en_contacto()
	if pegado != null and _state != State.CHASE and _state != State.EMBESTIDA:
		_objetivo = pegado
		_olvidar_orbita()   # mismo alta que _try_detect al entrar en CHASE
		_state = State.CHASE

	# Si no estamos ya persiguiendo (ni embistiendo), miramos si vemos u oimos a alguno.
	if _state != State.CHASE and _state != State.EMBESTIDA:
		_try_detect()

	# La memoria del lado por el que viene rodeando se gasta sola. Cada frame que la sonda vuelve a
	# encontrar pared la recarga (ver _direccion_esquivando), asi que solo caduca cuando de verdad
	# lleva un rato con el camino despejado: entonces ya puede volver a elegir de cero.
	if _desvio_t > 0.0:
		_desvio_t -= delta
		if _desvio_t <= 0.0:
			_lado_desvio = 0
			_dir_desvio = Vector2.ZERO

	match _state:
		State.WANDER: _wander(delta)
		State.CHASE: _chase(delta)
		State.EMBESTIDA: _embestida(delta)
		State.RETURN: _return()

	# BORDEAR la pared en vez de empujarla. Va DESPUES del estado (le pisa la direccion) y ANTES de
	# la separacion, porque durante el rodeo la separacion es justo lo que lo prensaba contra la
	# roca. Solo actua si hay un rodeo en marcha; ver _vigilar_atasco.
	var separando: float = 1.0
	if _bordeo != Vector2.ZERO:
		_bordeo_t -= delta
		if _bordeo_t <= 0.0:
			_bordeo = Vector2.ZERO
		else:
			velocity = _bordeo * current_move_speed
			separando = 0.25

	# El empujon de separacion se suma a lo que sea que estuviera haciendo (merodear, ir a por su
	# manada o perseguirte): vale para todo, y en la persecucion es lo que evita que los cuatro
	# lleguen apilados en el mismo pixel encima de ti.
	velocity += _separacion() * current_move_speed * SEPARACION_FUERZA * separando

	var antes: Vector2 = global_position
	move_and_slide()

	# La direccion de mirada = hacia donde nos movemos (si nos movemos).
	if velocity.length() > 1.0:
		_facing = velocity.normalized()
	_actualizar_indicadores()
	_actualizar_animacion()
	_actualizar_rastro(delta)

	_vigilar_atasco(delta, antes)


# ANTI-ATASCO, en TODOS los estados que se mueven. Antes solo existia en WANDER, asi que un bicho
# que te tuviera fichado podia pasarse minutos empujando un rincon (lose_range son 300 px): en
# CHASE no habia nada que lo despegara. Y se medía por get_slide_collision_count(), que se resetea
# con un solo frame sin rozar, de modo que un roce intermitente en esquina no llegaba nunca al
# tiempo de corte.
#
# Aqui se mide LO QUE DE VERDAD IMPORTA: si pide moverse y NO se mueve, esta atascado, dé o no dé
# la colision ese frame.
#
# ES LA RED DE SEGURIDAD, NO EL PLAN. Las esquinas las resuelve _direccion_esquivando antes de
# tocarlas y sin frenar; esto solo salta donde aquello no tiene salida que ofrecer (un fondo de
# saco). Por eso los tiempos son cortos: cuando este bloque actua, el bicho YA esta parado, y cada
# decima que aguante es una decima que te regala para largarte.
const ATASCO_AVANCE := 0.35    # fraccion del avance esperado por debajo de la cual "no avanza"
const ATASCO_T := 0.18         # cuanto aguanta asi antes de intentar salir
const BORDEO_T := 0.3          # lo que dura un rodeo
const BORDEOS_MAX := 3         # rodeos seguidos antes de rendirse y volverse a su sitio
func _vigilar_atasco(delta: float, antes: Vector2) -> void:
	# Si no pide moverse (esta plantado haciendo el aviso, o esperando) no hay atasco que valer.
	var pedido: float = velocity.length() * delta
	if pedido < 0.5 or _bordeo != Vector2.ZERO:
		if _bordeo == Vector2.ZERO:
			_stuck_time = 0.0
		return
	var avance: float = global_position.distance_to(antes)
	if avance >= pedido * ATASCO_AVANCE:
		_stuck_time = 0.0
		_bordeos = 0
		return
	_stuck_time += delta
	if _stuck_time < ATASCO_T:
		return
	_stuck_time = 0.0
	_bordeos += 1
	if _bordeos > BORDEOS_MAX:
		# No hay manera. Merodeando, la red de seguridad de siempre: de vuelta a casa de golpe. Pero
		# a un bicho que te esta persiguiendo NO se le teletransporta delante de las narices: suelta
		# la presa y se vuelve andando, que ademas te da la salida.
		_bordeos = 0
		if _state == State.WANDER:
			global_position = _home
			_pick_wander_target()
		else:
			_cancelar_aviso()
			_objetivo = null
			_state = State.RETURN
		return
	_desatascar_bordeando()


# Sigue la pared en vez de empujarla. De la normal del choque salen las dos tangentes; se coge la
# que mas acerca a donde quiere ir. Es wall-following de andar por casa, pero es lo que saca de un
# rincon concavo, y no hace falta navegacion para eso (en el proyecto no hay ninguna).
func _desatascar_bordeando() -> void:
	var destino: Vector2 = _wander_target
	if _state == State.CHASE and _objetivo != null and is_instance_valid(_objetivo):
		destino = _objetivo.global_position
	elif _state == State.RETURN:
		destino = _home
	var hacia: Vector2 = (destino - global_position)
	hacia = hacia.normalized() if hacia.length() > 0.01 else _facing
	# La normal de la roca contra la que empuja. Sin colision este frame (roce intermitente), se
	# usa la propia direccion de marcha como si fuera de frente.
	var normal: Vector2 = -hacia
	if get_slide_collision_count() > 0:
		normal = get_slide_collision(0).get_normal()
	var t1: Vector2 = Vector2(-normal.y, normal.x)
	var t2: Vector2 = -t1
	# POR EL LADO QUE YA VENIA. Elegir "la tangente que mas acerca a la presa" es lo natural y es
	# justo lo que no vale en una esquina: si el hueco esta arriba y la presa abajo, esa cuenta
	# manda para abajo, deshace lo que la esquiva llevaba ganado, y el bicho se queda subiendo y
	# bajando delante del hueco sin entrar nunca. Si _direccion_esquivando ya se habia decidido por
	# un lado, se respeta; solo sin nada decidido se mira hacia donde esta la presa.
	# Se compara contra la ULTIMA direccion que dio la esquiva, no contra un signo de giro: son dos
	# sistemas distintos (uno gira sobre la marcha, el otro sobre la normal de la roca) y traducir
	# de uno a otro era pedir un error de signo.
	var referencia: Vector2 = _dir_desvio if _dir_desvio != Vector2.ZERO else hacia
	_bordeo = t1 if t1.dot(referencia) >= t2.dot(referencia) else t2
	_bordeo_t = BORDEO_T



# Comprueba si VE (cono) u OYE (ruido) a ALGUIEN del grupo. Si si, va a por EL que lo delato (no
# a por el lider): cada miembro se delata por su cuenta, con su propio ruido y su propia posicion.
# Por eso mandar al que va en cabeza por un lado no protege al que se queda detras a la vista.
func _try_detect() -> void:
	for aliado in _aliados():
		if _detecta_a(aliado):
			_objetivo = aliado
			_olvidar_orbita()
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
	# El RUIDO que hace. Normalmente es su velocidad, pero el lider puede estar haciendo ruido sin
	# moverse (cantando un hechizo, o con un conjuro estallandole en la cara): quien tenga
	# ruido_oido() manda, y quien no (un companero, el avatar de otro humano) se mide por su
	# velocidad como toda la vida.
	var player_speed: float = 0.0
	if quien.has_method("ruido_oido"):
		player_speed = float(quien.ruido_oido())
	elif "velocity" in quien:
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


# ============================================================
#  ESQUIVAR LA PARED ANTES DE TOCARLA
# ============================================================
#
# El desatasco de mas abajo (_vigilar_atasco) es REACTIVO: choca, se queda un rato empujando, y
# solo entonces bordea. Eso son casi tres cuartos de segundo parado contra la roca, tiempo de
# sobra para irte andando. Esto es lo contrario: MIRA HACIA DONDE VA y, si ahi hay pared, se
# desvia YA, sin frenar y sin dejar de venir hacia ti. Solo lo cambia si de verdad hay algo: con
# el camino libre devuelve la direccion tal cual.
#
# SOLO SE USA PERSIGUIENDO. Ni al merodear ni al volver a casa: ahi el destino se elige a boleo y
# muchas veces cae detras de una roca, asi que el bicho se ponia a bordearla eternamente sin
# llegar -- y como no llega, tampoco elige destino nuevo, que es justo lo que lo desatascaba. En
# esos dos estados va derecho y, si choca, ya se encarga el desatasco reactivo. Perseguir es lo
# unico donde importa llegar rapido, y ademas ahi si hay un final: tocarte abre la pelea.
#
# Nada de navegacion ni de mallas: tres rayos (el del medio y los dos costados del cuerpo) contra
# la capa de la roca, y si no cabe se van abriendo angulos hasta encontrar por donde, del desvio
# mas pequeño al mas grande -- asi bordea la esquina pegado a ella en vez de dar un rodeo.
#
# Y UNA VEZ ELIGE LADO, SE COMPROMETE. Es lo que separa "rodear" de "bailar": mirando solo el
# frame de ahora, el desvio mas corto siempre apunta de vuelta al centro del muro, asi que el
# bicho se aparta, se despeja, vuelve a encarar, se vuelve a bloquear y se aparta por el otro
# lado... eternamente. Mientras le dure la memoria solo se consideran angulos de SU lado, aunque
# haya uno mas corto por el otro. Asi llega al borde y lo dobla.
const DESVIOS := [22.5, 45.0, 67.5, 90.0, 112.5, 135.0]   # grados que se prueban, de menos a mas
const SONDA_MIN := 34.0        # lo que mira por delante como minimo (poco mas de un cuerpo)
const SONDA_SEG := 0.45        # ...o lo que recorreria en este tiempo, si va mas rapido
const DESVIO_MEMORIA := 1.0    # cuanto dura el compromiso con un lado tras despejarse el camino

func _direccion_esquivando(hacia: Vector2) -> Vector2:
	if hacia.length_squared() < 0.0001:
		return hacia
	var dir: Vector2 = hacia.normalized()
	var sonda: float = maxf(SONDA_MIN, current_move_speed * SONDA_SEG)
	if _cabe_por(dir, sonda):
		return dir
	# Bloqueado: se recarga la memoria (mientras haya pared delante, el compromiso no caduca).
	var comprometido: bool = _lado_desvio != 0 and _desvio_t > 0.0
	_desvio_t = DESVIO_MEMORIA
	var salida: Vector2 = _buscar_hueco(dir, sonda, [_lado_desvio]) if comprometido \
		else _elegir_lado(dir, sonda, hacia)
	# Si por su lado no hay nada (ha llegado al fondo yendo por ahi), suelta el compromiso y mira
	# tambien por el otro: mas vale desdecirse que empotrarse.
	if salida == Vector2.ZERO and comprometido:
		salida = _buscar_hueco(dir, sonda, [-_lado_desvio])
	if salida != Vector2.ZERO:
		_dir_desvio = salida
		return salida
	# Sin salida por delante (fondo de saco): que siga empujando, y de eso ya se encarga el
	# desatasco reactivo, que es justo el caso para el que sirve.
	return dir


# FRENO ANTI-ORBITA. Bordear es dar vueltas por definicion, asi que con un pilar de por medio un
# bicho comprometido con un lado puede girar alrededor eternamente sin acercarse un palmo. Aqui se
# mira lo unico que dice si el rodeo SIRVE: si esta llegando a estar mas cerca que nunca.
#
#   * Si no mejora su record en un rato -> prueba por el otro lado.
#   * Si tampoco -> deja de perseguir y se vuelve a su sitio. Es un bicho, no un sabueso: darse por
#     vencido es mejor que quedarse de adorno girando alrededor de una piedra.
const ORBITA_MARGEN := 8.0     # cuanto tiene que recortar para que cuente como progreso
# Generoso a proposito: rodear de verdad NO acerca mientras dura. Un bicho que le da la vuelta
# entera a un muro largo se pasa varios segundos igual de lejos o mas, y es un rodeo legitimo --
# con el listón bajo lo matabamos a mitad de camino y se volvia a casa habiendo hecho medio
# trabajo, que se ve mucho peor que tardar un poco.
const ORBITA_T := 4.0          # cuanto le damos sin progresar antes de cambiar de lado
func _vigilar_orbita(delta: float, dist: float) -> void:
	if _orbita_record >= 99998.0:
		_orbita_record = dist   # primera vuelta de esta persecucion: el record es donde empieza
	if dist < _orbita_record - ORBITA_MARGEN:
		_orbita_record = dist
		_orbita_t = 0.0
		_orbita_cambios = 0
		return
	_orbita_t += delta
	if _orbita_t < ORBITA_T:
		return
	_orbita_t = 0.0
	_orbita_cambios += 1
	if _orbita_cambios == 1 and _lado_desvio != 0:
		# Por aqui no era: al otro lado, y con la cuenta A CERO. Si se le dejara el record de la
		# primera mitad, la segunda nace ya "sin progresar" desde donde acabo la primera (que suele
		# ser el punto mas lejano del rodeo) y se rinde antes de haber tenido opcion.
		_lado_desvio = -_lado_desvio
		_desvio_t = DESVIO_MEMORIA
		_orbita_record = 99999.0
		return
	# Ni por un lado ni por el otro. Lo deja estar.
	_olvidar_orbita()
	_cancelar_aviso()
	_objetivo = null
	_state = State.RETURN
	velocity = Vector2.ZERO


# Persecucion nueva, cuenta nueva. Sin esto el record de la anterior (que pudo acabar pegado a ti)
# haria que la siguiente naciera ya "sin progresar" y se rindiera a los dos segundos.
func _olvidar_orbita() -> void:
	_orbita_record = 99999.0
	_orbita_t = 0.0
	_orbita_cambios = 0
	_lado_desvio = 0
	_dir_desvio = Vector2.ZERO
	_desvio_t = 0.0


# LA PRIMERA VEZ que hay que elegir lado se miran los DOS, y esa eleccion pesa muchisimo: mientras
# siga habiendo pared delante el compromiso se renueva solo, asi que equivocarse aqui es irse por
# donde no era hasta que salte el freno anti-orbita.
#
# LA PREGUNTA BUENA NO ES "¿por donde hay mas sitio?" sino "¿por donde acabo MAS CERCA DE EL?".
# Comparando hueco libre, dos lados que llegan al tope de la ojeada EMPATAN, y en el empate ganaba
# otra vez el primero de la lista -- o sea el mismo sesgo de antes, solo que mas disimulado: en un
# pasillo o en campo abierto los dos lados se ven despejados y el bicho tiraba igual hacia la
# pared larga.
#
# Asi que cada lado se puntua yendo hasta donde llegaria por ahi (lo que le deje la roca, con un
# tope) y midiendo cuanto le faltaria DESDE ALLI. Eso no empata casi nunca, y ademas dice lo que
# de verdad importa: el lado que doble la esquina hacia ti gana, aunque por el otro haya mas hueco.
#
# El criterio principal sigue siendo el desvio MAS PEQUEÑO: se para en el primer angulo que sirva
# por algun lado, y la puntuacion solo decide entre los dos lados de ESE angulo.
const OJEADA_MIN := 3.0    # lo menos que se mira hacia delante para comparar, en veces la sonda
const OJEADA_MAX := 12.0   # ...y lo mas, para no medir media mazmorra en cada frame
func _elegir_lado(dir: Vector2, sonda: float, hacia: Vector2) -> Vector2:
	var objetivo: Vector2 = global_position + hacia
	# Se ojea, como mucho, lo que hay hasta el: mirar mas lejos que la presa no dice nada util.
	var ojeada: float = clampf(hacia.length(), sonda * OJEADA_MIN, sonda * OJEADA_MAX)
	for g in DESVIOS:
		var rad: float = deg_to_rad(g)
		var mejor: Vector2 = Vector2.ZERO
		var mejor_lado: int = 0
		var mejor_falta: float = INF
		for s in [1, -1]:
			var cand: Vector2 = dir.rotated(rad * float(s))
			if not _cabe_por(cand, sonda):
				continue
			var corrida: float = _recorrido_libre(cand, ojeada)
			var falta: float = (global_position + cand * corrida).distance_to(objetivo)
			if falta < mejor_falta:
				mejor = cand
				mejor_lado = s
				mejor_falta = falta
		if mejor != Vector2.ZERO:
			_lado_desvio = mejor_lado
			return mejor
	return Vector2.ZERO


# Cuanto se puede andar en esa direccion antes de comerse la roca (tope: 'largo'). Es solo para
# comparar un lado con el otro, asi que con el rayo del centro basta -- que quepa el cuerpo ya lo
# ha comprobado _cabe_por.
func _recorrido_libre(dir: Vector2, largo: float) -> float:
	var espacio: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + dir * largo, CAPA_ROCA)
	query.exclude = _excluir_del_rayo()
	var hit: Dictionary = espacio.intersect_ray(query)
	if hit.is_empty():
		return largo
	return global_position.distance_to(hit["position"])


# El desvio mas pequeño que deja pasar el cuerpo, probando solo los lados que se le pidan.
# Vector2.ZERO = por ahi no hay nada.
func _buscar_hueco(dir: Vector2, sonda: float, lados: Array) -> Vector2:
	for g in DESVIOS:
		var rad: float = deg_to_rad(g)
		for s in lados:
			if int(s) == 0:
				continue
			var cand: Vector2 = dir.rotated(rad * float(s))
			if _cabe_por(cand, sonda):
				_lado_desvio = int(s)
				return cand
	return Vector2.ZERO


# ¿Cabe el cuerpo yendo por ahi? El rayo del medio no basta: con uno solo el bicho corta las
# esquinas y se empotra de hombro, porque el punto pasa por donde el cuerpo no pasa.
#
# Las antenas van un pelin POR FUERA del cuerpo, no por dentro. Parece un detalle y no lo es: con
# ellas a ras (o peor, dos pixeles adentro) el bicho daba por bueno un hueco al que le faltaban
# esos mismos dos pixeles, se metia, y se quedaba empujando la esquina para siempre. Pasarse de
# ancho solo cuesta que rodee un poquito antes; quedarse corto cuesta que se atasque.
const MARGEN_CUERPO := 2.0

func _cabe_por(dir: Vector2, sonda: float) -> bool:
	var espacio: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var excluir: Array[RID] = _excluir_del_rayo()
	var media: float = _MEDIO_CUERPO + radio_extra + MARGEN_CUERPO
	var lado: Vector2 = Vector2(-dir.y, dir.x) * media
	for off in [Vector2.ZERO, lado, -lado]:
		var desde: Vector2 = global_position + off
		var query := PhysicsRayQueryParameters2D.create(desde, desde + dir * sonda, CAPA_ROCA)
		query.exclude = excluir
		if not espacio.intersect_ray(query).is_empty():
			return false
	return true


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
	# MERODEANDO NO SE ESQUIVA NADA: va derecho y punto. La esquiva es SOLO para perseguirte (ver
	# _direccion_esquivando). Aqui hacia mas mal que bien: el destino de paseo se elige a boleo y
	# muchas veces cae detras de una roca, asi que el bicho se ponia a bordearla sin llegar nunca
	# -- y como no llega, tampoco elige destino nuevo, que es lo que normalmente lo desatasca. Se
	# quedaban dando vueltas alrededor de las piedras para siempre. Chocando, en cambio, el
	# desatasco reactivo le cambia el destino y a otra cosa.
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
		# Y si hay pared en el camino, la BORDEA sin frenar (ver _direccion_esquivando): antes iba
		# derecho, se empotraba, y solo se despegaba tras casi un segundo pegado a la roca.
		_vigilar_orbita(delta, dist)
		velocity = _direccion_esquivando(to_p) * _chase_speed()


# El miembro del grupo que tiene A TIRO ahora mismo (dentro del margen de ataque), o null. Mira a
# TODOS: cualquiera que se le ponga a huevo vale, no solo al que venia persiguiendo.
func _aliado_en_contacto() -> Node2D:
	for n in _aliados():
		if hueco_hasta(n) <= CONTACTO:
			return n
	return null


# ¿La pelea que estoy a punto de abrir es en realidad un CONTRA suyo? Lo es si 'quien' tenia la
# intencion de atacarme puesta (su buffer de ESPACIO) y me estaba mirando.
#
# Existe porque quien inicia se lleva media barra de ATB (combat.INICIATIVA_VENTAJA), y sin esto eso
# se decidia por el ORDEN DE FRAME: si mi _physics_process corria antes que el suyo, la iniciativa era
# mia aunque el hubiera pulsado a tiempo. Golpear una embestida tiene que premiar leer el
# telegrafiado, no ganar una carrera invisible. Solo el jugador contesta a esto: un companero (NPC)
# no tiene intencion propia y devuelve false por no tener el metodo.
func _es_contra(quien: Node2D) -> bool:
	if quien == null or not is_instance_valid(quien):
		return false
	if not quien.has_method("quiere_atacarme"):
		return false
	return bool(quien.quiere_atacarme(self))


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
			# Iniciativa del enemigo: te ha embestido... SALVO que tu ya tuvieras el golpe puesto y le
			# estuvieras mirando. Entonces es un CONTRA y la media barra de ATB es tuya (ver _es_contra).
			_iniciar_impacto(not _es_contra(n))
			return
	# Se estampo contra una pared: la carga muere ahi.
	var choco: bool = get_slide_collision_count() > 0
	if _embiste_t <= 0.0 or choco:
		_embiste_espera = EMBESTIDA_ESPERA
		_state = State.CHASE
		velocity = Vector2.ZERO


# EL IMPACTO: arma el reloj de EMBESTIDA_IMPACTO (o la duracion que se le pase -- el jugador manda
# la de SU espadazo) y deja al bicho parado donde ha conectado. NO llama a _start_combat: eso lo
# hace el bloque de _physics_process cuando el reloj llega a 0, para que la pantalla de combate no
# se lleve la escena a mitad del golpe/la carga.
#
# ⚠️ LA VENTANA SE MIDE DESDE QUE ARRANCA LA CARGA, no desde que conecta. Es lo que la descuadraba de
# la animacion: la embestida ya se ha visto entera (EMBESTIDA_DUR) y encima el bicho se quedaba
# QUIETO, en idle y sin pasar nada, los 0,667 s enteros de EMBESTIDA_IMPACTO -- el "termina la
# embestida y tarda un segundo mas en entrarte" del playtest. Ahora se descuenta lo que la carga ya
# ha durado, asi que lo que se ve es: carga -> porrazo -> pantalla, seguido.
#
# Lo que manda el JUGADOR (su espadazo) NO se descuenta: ese golpe empieza en el momento en que se
# llama aqui, no antes.
func _iniciar_impacto(enemy_initiated: bool, dur: float = -1.0) -> void:
	velocity = Vector2.ZERO
	if dur > 0.0:
		_impacto_t = dur
	else:
		# Lo que lleva corriendo la carga = lo que le falta a _embiste_t para EMBESTIDA_DUR. Si esto no
		# viene de una embestida (_embiste_t a 0), consumido = EMBESTIDA_DUR y queda el resto.
		var consumido: float = clampf(EMBESTIDA_DUR - maxf(_embiste_t, 0.0), 0.0, EMBESTIDA_DUR)
		_impacto_t = maxf(EMBESTIDA_IMPACTO - consumido, IMPACTO_MINIMO)
	_impacto_enemy_initiated = enemy_initiated
	# EL BICHO SUENA AL EMBESTIR, en el mapa y antes de que se abra la pelea. Suena con su golpe de
	# siempre (EnemyData.fx_basico), el mismo que dentro del combate, asi que el minotauro embiste
	# con su cornada y la rata con su mordisco.
	#
	# Solo cuando embiste EL: si el impacto lo abriste tu (atacado_por_jugador), el que suena es tu
	# arma, y ya lo hace player._tick_ataque. Sonarian los dos y seria un ruido.
	if enemy_initiated and data != null:
		Sonido.golpe("", data.fx_basico if data.fx_basico >= 0 else CombatFX.Estilo.MELEE)


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
const _MEDIO_CUERPO := 16.0   # el cuerpo base es 32x32 (bicho normal)


# Cuanto SEPARA a los dos cuerpos. 0 = tocandose (de lado o de esquina); < 0 = solapados.
#
# LA CUENTA VIVE EN Cuerpos, no aqui. El otro puede no ser un cuadrado ni estar centrado en su nodo:
# el jugador tiene el cuerpo mas alto que ancho Y desplazado hacia arriba, porque su dibujo cae casi
# entero por encima del nodo (ver PoseJugador.CAJA_CUERPO). Con eso la cuenta pasa a ser un AABB
# contra AABB, y tenerla en dos sitios -- aqui y en Player._hueco_hasta -- garantizaba que se
# separaran; de hecho ya lo estaban.
#
# Esto es lo que hace que "los enemigos peguen al cuerpo entero": no hay ningun Area2D ni ninguna
# hitbox de mas, es esta cuenta la que decide si te alcanzan. La caja fisica de player.tscn solo
# sirve para chocar con las paredes.
func hueco_hasta(otro: Node2D) -> float:
	return Cuerpos.hueco(self, otro)


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


# Lo llama el JUGADOR cuando te ataca de cerca: combate con su iniciativa. 'golpe_dur' es lo que
# le queda de espadazo en el mapa (player._golpe_t) -- el bicho se paraliza ESE rato antes de que
# la pantalla de combate se lleve la escena, para que de tiempo a verlo (ver _iniciar_impacto).
# Devuelve si la pulsacion ha SERVIDO de algo: se ha abierto pelea, o se ha pedido entrar en una. El
# jugador lo necesita para no dar por gastado el espacio cuando aqui no pasa nada (ver
# player._try_attack): antes esto no devolvia nada y la pulsacion se perdia igual.
func atacado_por_jugador(golpe_dur: float = -1.0) -> bool:
	if _dead:
		return false
	# Ya hay un golpe en curso con este bicho (esta en el impacto). La pulsacion CUENTA -- no hay
	# que decirle al jugador que no ha pasado nada -- pero no reinicia el reloj: si no, machacar el
	# boton contra el mismo bicho alargaria la espera para siempre y nunca se cortaria a combate.
	if _impacto_t >= 0.0:
		return true
	# Ya esta metido en una pelea. Antes esto era un callejon sin salida: le dabas y no pasaba
	# NADA. Ahora es la via para ECHAR UNA MANO: se pide entrar en esa pelea (hito 5.4-C).
	if _combat_triggered:
		if Net.activo and has_meta("net_id"):
			Net.unirme_a_la_pelea_de(get_meta("net_id"))
			return true
		# En solitario no hay pelea de otro a la que unirse: la pulsacion NO cuenta, para que el
		# jugador pueda probar con el siguiente bicho en vez de perderla aqui.
		return false
	# La pelea es de QUIEN ME ATACA, aunque yo viniera persiguiendo a otro. Sin esto, si venia
	# detras del compañero (_objetivo = su avatar), el empuje del hito 5.4-B mandaba la pelea a EL
	# y al que me ataco no se le abria nada: "no me deja pelear".
	var yo: Node = get_tree().get_first_node_in_group("player")
	if yo != null:
		_objetivo = yo
	_iniciar_impacto(false, golpe_dur)
	return true


# Nace de un BROTE: en vez de ponerse a merodear, sale directo A POR TI. Es lo que convierte el
# brote en un susto de verdad: revienta un cacho de pared y te caen encima cuatro a la vez. El
# primero que te alcance recluta a los que salieron con el (vecinos()) y la pelea es en grupo.
func nacer_embistiendo() -> void:
	_objetivo = _aliado_mas_cercano()
	if _objetivo != null:
		_olvidar_orbita()
		_state = State.CHASE


# True si este bicho es el BOSS de su piso (lo pone DungeonFloor al colocarlo). Un boss no lo
# recicla el spawner y, al morir, abre el piso: bajada, salida al pueblo y atajo desde el
# pueblo (ver Game.marcar_boss_derrotado).
var es_boss: bool = false


# Lo que tarda un cadaver en pudrirse si no le sacas el cristal. Va contra Game.tiempo_mazmorra (el
# reloj de expedicion) y no contra un Timer del nodo: asi respeta el desfase de dev (+10 min con una
# tecla) y sobrevive al guardado, igual que el respawn de las vetas.
#
# Por que existe: sin esto los cuerpos no se iban NUNCA. Un piso que llevas media hora limpiando
# acaba siendo un campo de cadaveres que te roba la F (el cadaver va antes que el loot y la veta) y
# que se guarda entero en la memoria del piso. Cinco minutos es tiempo de sobra para volver a por tu
# cristal, y poco para que se acumulen.
const CADAVER_SEGUNDOS := 300.0

# Momento (en Game.tiempo_mazmorra) en el que este cuerpo se desvanece. -1 = no es un cadaver todavia.
var sello_pudre: float = -1.0


# Lo llama Game al GANAR el combate: el enemigo queda como CADAVER (no se
# borra), apagado e interactuable para extraerle el cristal (minijuego).
func morir() -> void:
	_dead = true
	_winding = false
	set_physics_process(false)  # detiene la IA
	velocity = Vector2.ZERO
	_color_rect.color = Color(0.4, 0.4, 0.4)  # cuerpo gris/apagado
	# EL SPRITE PASA A SU POSE DE CADAVER: tirado en el suelo y MIRANDO ADONDE ESTABA. Es un solo
	# fotograma por direccion (ver SpritesEnemigo.cadaver) porque aqui nadie ve morir a nadie: se
	# entra a la sala y el bicho ya esta ahi.
	#
	# EL MODULATE SE PONE A BLANCO A MANO, y hace falta: aqui se para el _physics_process, o sea que
	# _actualizar_indicadores ya no vuelve a correr -- un bicho que muriera justo mientras avisaba el
	# golpe se quedaba de cadaver con el tinte ROJO del aviso puesto para siempre.
	#
	# Y el gris solo se le echa a quien NO tiene pose de cadaver (los enemigos que siguen siendo un
	# cuadrado de color): teniendola, ya se ve que esta muerto por como esta, y ademas el gris se
	# comeria el dibujo que se acaba de hacer para eso.
	if _sprite.visible:
		var pose: String = SpritesEnemigo.cadaver(_facing)
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(pose):
			_sprite.modulate = Color.WHITE
			_anim_actual = pose
			_sprite.play(pose)
		else:
			_sprite.modulate = Color(0.45, 0.45, 0.45)
	if _facing_line != null:
		_facing_line.visible = false   # un cadaver ya no mira a ningun sitio
	remove_from_group("enemy")  # ya no es un enemigo activo
	add_to_group("corpse")      # ahora es un cadaver interactuable
	# Arranca su cuenta atras. Solo si no la traia ya puesta: _restaurar_estado revive los cadaveres
	# llamando a morir(), y sin esto volver al piso les reiniciaria el reloj una y otra vez.
	if sello_pudre < 0.0:
		sello_pudre = Game.tiempo_mazmorra + CADAVER_SEGUNDOS
	# MULTIJUGADOR: que los demas lo vean caer. Sin esto seguirian viendo un bicho VIVO donde ya
	# solo hay un cadaver (el nodo no se libera al morir, asi que baja_enemigo no salta).
	Net.enemigo_muerto(self)

	# El boss cae: el piso se abre AHORA MISMO (sin salir ni volver a entrar).
	if es_boss:
		Game.marcar_boss_derrotado(Game.current_floor)
		# Y arranca su cuenta atras: el jefe ya no vuelve por que la mazmorra se olvide al pasar por el
		# pueblo (ya no se olvida), vuelve por reloj (ver Game.BOSS_RESPAWN).
		Game.sellar_boss_caido(Game.current_floor)
		var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
		if piso != null and piso.has_method("abrir_salidas"):
			piso.abrir_salidas()
		# MULTIJUGADOR: el atajo y la tienda se abren para TODA la sesion, y a quien este en este
		# piso se le abren las salidas tambien (si no, no veria aparecer la bajada).
		Net.avisar_boss_caido(Game.current_floor)


func esta_muerto() -> bool:
	return _dead


# UN turno de estados cada Game.SEG_POR_TURNO_FUERA segundos: cobra el DoT, baja las duraciones y
# expira lo que se acabe. Al bicho SI lo mata (a diferencia del jugador, que se queda a 1): huir con
# el veneno puesto y que se muera solo por el pasillo es justo lo que hace que envenenar sirva para
# algo cuando la pelea se te va de las manos. Al caer queda como CADAVER normal, con su cristal
# extraible; lo que no da es excelia, porque la excelia se reparte en la pantalla de combate y aqui
# no hay pantalla.
func _tick_estados_fuera(delta: float) -> void:
	_reloj_estados += delta
	if _reloj_estados < Game.SEG_POR_TURNO_FUERA:
		return
	_reloj_estados -= Game.SEG_POR_TURNO_FUERA
	var dano: float = 0.0
	var quedan: Array = []
	for d in estados_restantes:
		var inst = StatusEffects.instancia_de_dict(d)
		if inst == null:
			continue
		dano += inst.dot_damage()
		inst.turns -= 1
		if inst.turns > 0:
			quedan.append(StatusEffects.dict_de_instancia(inst))
	estados_restantes = quedan
	if dano <= 0.0:
		return
	# Sin vida arrastrada (nunca peleo) el DoT no tiene de donde morder: se le pone su vida entera y
	# se le resta de ahi.
	if hp_restante < 0.0:
		hp_restante = float(data.crear_combatant(current_t, mutante).max_hp)
	hp_restante -= dano
	print("[estado] %s sufre %.1f por el mapa | HP %.1f" % [data.enemy_name, dano, hp_restante])
	if hp_restante <= 0.0:
		hp_restante = 0.0
		print("[estado] %s se muere de lo que llevaba encima" % data.enemy_name)
		morir()


# MULTIJUGADOR (hito 5.1): lo que el host manda al cliente para PINTAR este bicho igual sin
# conocer EnemyData: su color (ya con el tinte de su 't') y el lado de su cuerpo (los elites son
# mas grandes). Se lee del propio ColorRect, que es la verdad tras _aplicar_escala.
#
# Van tambien el ELEMENTO y su intensidad: sin ellos el invitado no ve arder al slime de fuego, y
# ese bicho es 1/50 y te revienta -- no verlo venir es perder informacion de juego, no un adorno.
# Aqui NO se manda el color del elemento, solo el id: el cliente lo saca de Elementos.COLOR igual
# que el host, asi que la paleta no se puede desincronizar por el cable.
func aspecto_red() -> Dictionary:
	var elem: int = data.elemento if data != null else Elementos.Elemento.NINGUNO
	var inten: float = data.elemento_intensidad if data != null else 1.0
	if _color_rect != null:
		return {
			"color": _color_rect.color,
			"lado": _color_rect.offset_right - _color_rect.offset_left,
			"elem": elem, "einten": inten,
		}
	return {"color": Color.WHITE, "lado": 32.0, "elem": elem, "einten": inten}


# MULTIJUGADOR: hacia donde MIRO y si estoy avisando el golpe. Va en el tick de posiciones para que
# el que solo me ve espejado pueda pintar mi cono de vision y mi linea de direccion: sin eso NO
# PUEDE JUGAR AL SIGILO, que es medio juego (no sabe por donde miro ni cuando voy a atacar).
func estado_visual_red() -> Array:
	return [_facing.angle(), _winding]


# MULTIJUGADOR (hito 5.1): al salir del arbol (reciclado por aforo, piso desmontado al viajar) el
# host da de baja el bicho para que su cuerpo remoto desaparezca en los clientes. En solitario /
# de cliente no hace nada (Net.baja_enemigo corta).
func _exit_tree() -> void:
	Net.baja_enemigo(self)


# "t" (0..1): donde cae este bicho dentro de su franja (flojo..fuerte).
# Lo usa la categoria del cristal (t alto = cristal de mejor categoria).
func poder_normalizado() -> float:
	return clampf(current_t, 0.0, 1.0)


# Tras extraer el cristal: el cuerpo se desvanece (baja opacidad) y desaparece.
func desvanecer() -> void:
	remove_from_group("corpse")  # ya no interactuable
	# Que deje de emanar antes del fundido: si no, sigue soltando cuadraditos mientras se va.
	Particulas.apagar(_fx_elem)
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
		# Volviendo a casa tampoco se esquiva, por lo mismo que al merodear: nadie mira si vuelve
		# rapido o lento, y bordear sin llegar es peor que chocar y que el desatasco lo resuelva.
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
	1: [[1, 60], [2, 35], [3, 5]],
	2: [[1, 20], [2, 50], [3, 25], [4, 5]],
	3: [[2, 30], [3, 40], [4, 25], [5, 5]],
	4: [[2, 15], [3, 40], [4, 35], [5, 10]],
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
		# Los ESPEJOS no cuentan para NADA de la IA (separacion, manadas, refuerzos): son el dibujo
		# de la simulacion de otra maquina, no compañeros mios. Ademas no cumplen medio contrato del
		# grupo, asi que preguntarles revienta (ver remote_enemy).
		if n == self or not is_instance_valid(n) or n.has_meta("es_espejo"):
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
		if n == self or not is_instance_valid(n) or n.has_meta("es_espejo"):
			continue
		if n.esta_muerto() or n._combat_triggered:
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
	# El piso lleva el aforo de cada sala: no me mudo a una que ya este llena (asi el tope por
	# tamaño de sala se respeta tambien migrando, no solo pariendo). Sin piso (arena/dev) no filtra.
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var mejor = null
	var best: float = INF
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self or not is_instance_valid(n) or n.has_meta("es_espejo"):
			continue
		if n.esta_muerto() or n._combat_triggered:
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
		# Ni en una SALA que ya este a tope de aforo (aunque el corro concreto tenga hueco): dos
		# corros pequeños en la misma sala grande sumaban un amontonamiento igual de feo.
		if piso != null and n.zona_idx >= 0:
			var aforo: int = piso.aforo_de_zona(n.zona_idx)
			if aforo > 0 and piso.enemigos_en_zona(n.zona_idx) >= aforo:
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
	# (Aqui habia un 1v1 forzado cuando estaba puesto el modo muñeco. Se quito: en la arena se
	# entra en grupo como en cualquier pelea normal, que es lo que se queria probar. Si lo que
	# quieres es medir DPS limpio, pon un solo bicho.)
	var cand: Array = []
	for n in get_tree().get_nodes_in_group("enemy"):
		# Filtrar a los que YA estan en un combate es imprescindible: si no, un bicho que se
		# quedo enganchado de una pelea anterior volveria a entrar en esta. Los ESPEJOS tampoco:
		# no son mios, son el dibujo de lo que simula otra maquina.
		if n == self or not is_instance_valid(n) or n.has_meta("es_espejo"):
			continue
		if n._combat_triggered:
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d <= RADIO_REFUERZO:
			cand.append([d, n])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(MAX_COMBATIENTES - 1, cand.size()):
		out.append(cand[i][1])
	return out


# LA EMBESTIDA CONECTO PERO NO HAY PELEA. Se deja al bicho suelto (no esta en ninguna pelea, asi que
# no se le puede marcar) pero SIN poder volver a cargar durante REBOTE_ESPERA. Sin esto reintentaba
# al frame siguiente, y cada intento arrastra su porrazo (ver _iniciar_impacto): con el dueño del
# piso metido en su pantalla de combate, eso son golpes sonando solos indefinidamente.
func _rebotar() -> void:
	velocity = Vector2.ZERO
	_state = State.CHASE
	# El descanso se pone DESPUES de cancelar: _cancelar_aviso pone _embiste_espera a 0 (deshace el
	# aviso entero), asi que al reves se anulaba a si mismo y el rebote no servia de nada.
	_cancelar_aviso()
	_embiste_espera = REBOTE_ESPERA


func _start_combat(enemy_initiated: bool) -> void:
	if _combat_triggered:
		return
	# Solo monta peleas quien SIMULA este piso: los bichos espejados no tienen IA ni son autoridad
	# de nada (ver Net y remote_enemy.gd).
	if not Net.simulo_mi_piso():
		_rebotar()
		return
	# He alcanzado el cuerpo de OTRO JUGADOR (hito 5.4): la pelea es SUYA, no mia — yo solo simulo
	# el piso. Se le empuja con emboscada (le he saltado encima) y aqui no se abre nada.
	if _objetivo != null and is_instance_valid(_objetivo) and _objetivo.has_meta("peer_id"):
		# OJO: el congelado lo pone la RESERVA (Net._reservar_grupo), que ademas rechaza a los que
		# ya lo tengan puesto. Marcarlo aqui antes haria que la reserva se rechazara a si misma.
		if not Net.empujar_pelea(self, _objetivo.get_meta("peer_id")):
			_rebotar()   # no ha colado (ya lo pelea alguien, o el otro esta ocupado): no insistir
		return
	# Ya hay una pelea en marcha: en vez de rebotar, ME UNO a ella (hito 5.4). Si no cabe (tope de
	# MAX_COMBATIENTES), me quedo ESPERANDO PEGADO y lo reintento: en cuanto muera uno, entro en su
	# hueco. Ojo: NUNCA congelar al grupo antes de saber si la pelea arranca de verdad; hacerlo era
	# lo que dejaba bichos de ESTATUA para siempre (sin IA, ocupando aforo y sin dar loot).
	if Game.combate_activo():
		if Game.unir_enemigo_al_combate(self):
			_combat_triggered = true   # ya estoy dentro; el fin del combate me libera
			velocity = Vector2.ZERO
			_cancelar_aviso()
		else:
			_esperando_hueco = true    # la pelea esta llena: espero al lado a que caiga alguien
			velocity = Vector2.ZERO
			_cancelar_aviso()
		return
	# Al que ESPEJA la pelea de otro no se le abre una pelea nueva (le robaria la pantalla y dejaria
	# al anfitrion esperando su turno para siempre): me uno a LA SUYA, que es donde esta peleando.
	if Net.espejando():
		if Net.refuerzo_a_mi_pelea(self):
			_combat_triggered = true
		else:
			_esperando_hueco = true    # no cabia: espero pegado como en cualquier pelea llena
		velocity = Vector2.ZERO
		_cancelar_aviso()
		return
	# EL JUGADOR ACABA DE SALIRSE de una pelea (Continuar en el espejo) y el anfitrion aun le debe lo
	# que vivieron sus personajes. Abrir otra pelea ahora es perderlo: el lote que viene de camino
	# ASIGNA sobre la ficha y le pisaria lo que hiciera en esta.
	#
	# Quieto y sin marcar nada: esto son milisegundos (el lote sale en cuanto el anfitrion recibe el
	# aviso, ver Net.salir_del_espejo) y el contacto vuelve a llamar aqui al frame siguiente. NO se
	# usa _esperando_hueco, que es para una pelea LLENA y ademas se suelta solo en cuanto no hay
	# pantalla delante -y aqui justo acaba de cerrarse-, asi que solo haria que parpadeara.
	if Net.ocupado_en_pelea():
		velocity = Vector2.ZERO
		return
	# Hay una PANTALLA delante que NO es una pelea: un minijuego de recoleccion (extraer un cristal,
	# picar, recolectar, talar). Game.start_combat la rechaza en seco (`if _active_layer != null:
	# return`), asi que seguir adelante congelaba al grupo entero SIN abrir pelea: se quedaban de
	# estatua para siempre, sin IA, sin loot y ocupando aforo. Se espera pegado, igual que en una
	# pelea llena: al cerrarse el minijuego se suelta _esperando_hueco y, como seguimos en contacto,
	# _aliado_en_contacto vuelve a llamar aqui y la pelea se abre de verdad. En solitario no se veia
	# porque el arbol esta en pausa con el minijuego delante y esto no llega a correr.
	if Game.hay_pelea_en_pantalla():
		_esperando_hueco = true
		velocity = Vector2.ZERO
		_cancelar_aviso()
		return
	var grupo: Array = vecinos()
	# Se congela al GRUPO ENTERO, no solo a mi: los vecinos entran a la pelea, asi que no pueden
	# seguir merodeando (ni disparar su propio combate) por el mapa mientras tanto.
	for n in grupo:
		n._combat_triggered = true
		n.velocity = Vector2.ZERO
		n._cancelar_aviso()
	combat_started.emit(data, enemy_initiated)
	# RED DE SEGURIDAD: el grupo ya esta congelado, asi que si start_combat rechaza (aforo, nodos
	# sin data, una carrera con otra pelea que se abrio en el mismo frame) hay que DESCONGELARLO.
	# La guarda de hay_pelea_en_pantalla de arriba tapa el caso conocido, pero no los demas, y sin
	# esto cualquier rechazo deja al grupo de estatua para siempre. Se les deja en _esperando_hueco,
	# que se auto-recupera y reintenta la pelea sola en cuanto se despeje la pantalla.
	if not Game.start_combat(grupo, enemy_initiated):
		for n in grupo:
			if is_instance_valid(n):
				n._combat_triggered = false
				n._esperando_hueco = true
		return
	# LA PELEA ARRANCO, pero puede no haberse llevado a TODO el grupo: start_combat descarta a los
	# que no traigan EnemyData. A ese lo hemos congelado nosotros ahi arriba y ya no lo va a
	# descongelar nadie -- no esta en la pelea, asi que su final no le llega. Estatua muda para
	# siempre: sin IA, sin loot y ocupando aforo. Se le suelta aqui.
	for n in grupo:
		if is_instance_valid(n) and not Game.esta_en_combate(n):
			n._combat_triggered = false


# Vuelve a la vida normal tras un combate del que NO moriste (huiste, o te mato otro).
# Se queda quieto CONGELADO_TRAS_COMBATE segundos: es la ventana para escapar de verdad, si no
# huir no serviria de nada (te alcanzaria al instante y volveria a empezar la pelea).
# 'hp' son las heridas que le dejaste: se guardan y se le aplican en el proximo combate. 'estados'
# igual: el veneno que le pusiste sigue corriendo por el mapa (ver _tick_estados_fuera).
func reanudar_tras_combate(hp: float = -1.0, estados: Array = []) -> void:
	if _dead:
		return
	hp_restante = hp
	estados_restantes = estados.duplicate()
	_reloj_estados = 0.0
	await get_tree().create_timer(CONGELADO_TRAS_COMBATE).timeout
	if not is_instance_valid(self) or _dead:
		return
	# Sale en WANDER (no persiguiendote): la ventana de escape no serviria si al acabar te
	# tuviera ya localizado. Si sigues cerca y te ve u oye, volvera a por ti por su cuenta.
	_combat_triggered = false
	_state = State.WANDER
	_pick_wander_target()


# --- Visual: linea de direccion ---
# El CONO DE VISION ya no se pinta (ni en PC ni en movil). Se dibujaba como un poligono translucido
# recortado por la roca, rayo a rayo; era util para ver el sigilo por dentro, pero llena la pantalla
# de manchas amarillas con varios bichos y tapa lo que pasa debajo.
#
# Lo que SI se queda es la LINEA de direccion: hacia donde mira cada bicho hace falta saberlo (es lo
# que dice si te ha fichado o si puedes rodearlo), y una raya no estorba.
#
# OJO: esto es solo el DIBUJO. La deteccion no se ha tocado — el cono sigue existiendo en
# vision_range / vision_half_angle_deg y en _ve_u_oye_a, con su linea de vision contra la roca.
# El palo amarillo de "hacia donde miro" es un APAÑO PARA LOS CUADRADOS: un ColorRect no tiene cara,
# asi que sin el no habria forma de jugar al sigilo. En cuanto un bicho tiene sprite sobra -- se le
# ven los ojos, y ademas el palo mide 26 unidades FIJAS, con lo que en una rata parecia un mastil
# (mas largo que ella) y dentro del Rey Slime no se veia.
#
# Pero el palo hacia DOS cosas, y la segunda no la cuenta el sprite: se ponia ROJO para telegrafiar
# el golpe. Eso no se puede perder -- un bicho que ataca sin avisar es injusto --, asi que los que
# tienen sprite lo avisan TIÑENDOSE (ver _actualizar_indicadores).
func _crear_indicadores() -> void:
	if _sprite.visible:
		return
	_facing_line = Line2D.new()
	_facing_line.add_point(Vector2.ZERO)
	_facing_line.add_point(Vector2(26.0, 0.0))
	_facing_line.width = 3.0
	_facing_line.default_color = Color(1.0, 1.0, 0.0)
	add_child(_facing_line)


# Color del bicho mientras avisa el golpe. Es el rojo/naranja que tenia la linea, para que el aviso
# se lea igual lo dibuje quien lo dibuje.
const _AVISO_TINTE := Color(1.0, 0.45, 0.30)


func _actualizar_indicadores() -> void:
	# La colision alargada gira con el (una rata de lado ocupa el triple que de frente).
	if _colision_gira:
		var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
		if col != null:
			col.rotation = _facing.angle() - PI * 0.5
	if _facing_line == null:
		# Tiene sprite: el aviso del golpe va por el tinte, que es lo que sustituye al palo rojo.
		# En reposo NO es blanco sino lo que diga _tinte_reposo: un mutante late en carmesi. El aviso
		# sigue mandando por encima, que es lo que tiene que pasar -- que sea un mini-jefe no puede
		# tapar la telegrafia de su golpe.
		if _sprite.visible:
			_sprite.modulate = _AVISO_TINTE if _winding else _tinte_reposo()
		return
	# Sin sprite (los que aun son un ColorRect): el latido va sobre el cuerpo, que aqui no lo pisa
	# nadie. El aviso de esos sigue siendo el palo rojo de abajo.
	if mutante:
		_color_rect.modulate = _tinte_reposo()
	_facing_line.rotation = _facing.angle()
	# Rojo/naranja mientras avisa el ataque (telegrafia el golpe).
	_facing_line.default_color = Color(1.0, 0.3, 0.1) if _winding else Color(1.0, 1.0, 0.0)
