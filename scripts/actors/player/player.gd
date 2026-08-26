# ============================================================
#  player.gd
#  Movimiento del jugador en la exploracion (top-down), con TRES velocidades:
#    - Ctrl  : sigilo (despacio y silencioso)
#    - normal: andar
#    - Shift : correr (rapido y ruidoso) -> gasta AGUANTE
#  El aguante maximo depende de Resistencia y Agilidad (stats del jugador,
#  guardadas en el autoload Game). Se vacia al correr y se recupera al parar.
# ============================================================

extends CharacterBody2D

# Velocidad base (andar) y multiplicadores de los otros modos.
# Bajada de 120 a 100 junto con el techo del bonus de Agilidad (Game.AGILIDAD_VEL_MAX, de +50% a
# +30%): la banda de correr era 163-306 px/s y se habia quedado muy ancha por arriba, con lo que
# huir de casi todo salia gratis. Ahora es 136-221 contra perseguidores de 56-220: la fuga se
# aprieta por los dos lados y la dificultad de huir (Game.huida_dificultad_mult) se nota.
@export var walk_speed: float = 100.0
@export var sneak_multiplier: float = 0.45  # sigilo: ~45 px/s
@export var run_multiplier: float = 1.7     # correr: ~170 px/s antes de Agilidad/armadura/peso

# --- Aguante (stamina) ---
@export var base_stamina: float = 100.0
@export var stamina_per_resistencia: float = 0.075  # extra por Resistencia (bajado: la energia ya la gastan habilidades)
@export var stamina_per_agilidad: float = 0.025     # extra por Agilidad
@export var run_drain: float = 35.0       # aguante/seg al correr
# Recuperacion: base + extra FIJO por nivel (NO escala con stats, a proposito,
# para no desequilibrar: si subiera con Resistencia/Agilidad daria doble ventaja).
@export var stamina_regen: float = 20.0            # aguante/seg a nivel 1
@export var stamina_regen_per_level: float = 2.0   # +/seg por cada nivel extra
var _regen_actual: float = 20.0  # se calcula en _ready segun el nivel

var max_stamina: float = 100.0
var current_stamina: float = 100.0

# Cuando el aguante llega a 0 entras en "agotado": no puedes correr y vas a
# velocidad de sigilo hasta recuperar esta fraccion del aguante (la mitad).
@export var exhausted_recover_ratio: float = 0.5
var _exhausted: bool = false

# Modo de movimiento actual (lo usa el enemigo para el "ruido"):
# 0 = sigilo, 1 = andar, 2 = correr.
var movement_mode: int = 1

# --- RUIDO QUE NO ES ANDAR ---------------------------------------------------------------------
# El oido de los bichos sale de tu VELOCIDAD (enemy._detecta_a), asi que quieto eres MUDO. Cantar un
# hechizo en mitad de un pasillo tiene que oirse, y un conjuro que te estalla en la cara, mas: estos
# dos campos se suman a la velocidad cuando el bicho calcula su radio de oido (ver ruido_oido).
#
# Van en "px/s equivalentes" y no en un invento nuevo a proposito: asi el ruido del canto se puede
# comparar de un vistazo con andar (100) y correr (~170), y las paredes lo amortiguan solas.
var ruido_extra: float = 0.0     # sostenido mientras dure algo (cantar): lo pone y lo quita quien canta
var _ruido_pico: float = 0.0     # de golpe (un estallido) y se desinfla solo
var _ruido_pico_t: float = 0.0   # lo que le queda al pico
var _ruido_pico_dur: float = 0.0

# Direccion a la que "mira" el jugador (ultimo movimiento), para atacar.
var _facing: Vector2 = Vector2.DOWN

# El cuerpo dibujado: la pila de capas (ver muneco_jugador.gd). Null hasta _pintar_cuerpo.
var _muneco: MunecoJugador = null
# Lo que le queda al espadazo del mapa. Mientras corre, manda sobre andar y sobre estar quieto.
# Los 8 fotogramas de 'golpe' a 12 fps duran esto exacto: si se acortara, la animacion se cortaria a
# medio tajo, y si se alargara, el personaje se quedaria clavado en el ultimo fotograma.
const DUR_GOLPE := 8.0 / 12.0
var _golpe_t: float = 0.0

# Ataque para INICIAR combate, hacia delante. El numero es de CENTRO A CENTRO, pero lo que se filtra
# es el HUECO entre los dos cuerpos (ver _enemigos_a_tiro): attack_range - 32 = 12 px de hueco.
#
# ESTO NO SE TOCA PARA ARREGLAR "EL BOTON SE ENCIENDE TARDE". Ya se probo: subirlo a 100 (68 px de
# hueco) hacia que entraras en combate con el bicho a dos cuerpos, que no es lo que se pedia — y de
# paso se comia el mantenido del mago, porque la pulsacion se gastaba en el espadazo antes de que te
# diera tiempo a nada. Lo que tenia que encenderse antes era el BOTON, no el alcance: eso lo lleva
# hay_algo_que_atacar(), que mira tambien si puedes CANTARLE desde lejos.
@export var attack_range: float = 44.0
@export var attack_half_angle_deg: float = 70.0
# Hueco a partir del cual se considera que ya NO es cuerpo a cuerpo: es el alcance de antes
# (44 - 32). Por debajo de esto el bicho esta literalmente encima y no se le pide linea de vision.
const HUECO_CUERPO_A_CUERPO := 12.0

# Interaccion (F) con cadaveres para extraer el cristal.
@export var interact_range: float = 40.0
var _interact_was: bool = false
var _attack_was: bool = false   # antirrebote de ESPACIO (atacar)
# Cuanto llevas MANTENIENDO el boton de atacar. -1 = este mantenido ya se gasto (o ya entraste en
# combate con el flanco), asi que hay que soltar y volver a pulsar. Ver _tick_ataque.
var _atk_hold: float = 0.0
# El panel de recitar en el mapa mientras esta abierto (null = no estas cantando).
var _casteo: Node = null

# BUFFER DE ATAQUE: cuanto se recuerda un ESPACIO que no encontro a nadie a tiro.
#
# Sin esto, atacar era un flanco de UN SOLO FRAME: si pulsabas con el bicho todavia a 20 px, la
# pulsacion se gastaba en balde y mantener el espacio no reintentaba nada (_attack_was se queda en
# true) — habia que soltar y volver a pulsar. Con las EMBESTIDAS eso se volvio injugable: el bicho
# cubre el ultimo tramo en un estallido de 0.35 s a x2.2, asi que el "pulso cuando le veo venir"
# natural cae justo en la ventana que se tiraba a la basura, y para cuando podias repulsar ya te
# habia embestido y la iniciativa (media barra de ATB) era suya.
#
# NO es un auto-ataque: son 0.25 s contados desde UNA pulsacion tuya, el patron de siempre de los
# juegos de accion. Al caducar no pasa nada.
const ATK_BUFFER := 0.25
var _atk_buffer: float = 0.0

# El SEQUITO (los companeros que te siguen por el mapa). Ver party_trail.gd.
var _sequito: Node2D = null
# Quien esta llevando este cuerpo ahora mismo. Se guarda para saber a QUIEN devolverle el aguante
# cuando cambias de lider: cada personaje lleva el suyo, y el que se va atras no puede perderlo.
var _pj_actual: PersonajeData = null
# La CAPA de las barras (la crea _crear_capa_barras): aqui cuelgan todas las columnas.
var _barras_layer: CanvasLayer = null
# UNA columna por miembro del grupo, en su ORDEN FIJO de party (no reordenadas por quien manda):
# {"pj", "raiz", "corona", "nombre", "punto", "hp", "hp_lbl", "en", "en_lbl", "mp", "mp_lbl"}. Se
# rehacen cuando cambia el grupo. La columna del lider lleva una coronita; las teclas 1/2/3 solo
# mueven la corona (y el cuerpo del mapa), las columnas no se tocan.
var _barras: Array = []
# Copia del equipo tal y como se pinto la ultima vez. Sirve para darse cuenta de que ha cambiado
# (has contratado a alguien, o lo has movido en el Hogar) sin que nadie tenga que avisar: los
# menus son muchos y cualquiera que se olvidara de llamar dejaria el sequito o las barras a medias.
var _grupo_visto: Array = []

# Alto del cuerpo DIBUJADO en px (ver PoseJugador.ALTO_MUNDO). Lo usa el rastro de la imbuicion para
# saber hasta donde suben los cuadraditos: iba en 32 cuando el personaje era un ColorRect de 32x32, y
# con el dibujo al doble el rastro le llegaba por la cintura.
const LADO_CUERPO := 74.0
# Emisor del rastro de imbuicion del LIDER (null = no lleva ninguna).
var _fx_imbue: CPUParticles2D = null
# Los elementos imbuidos de TODO el grupo, en orden, tal y como estaban en el ultimo repintado. Es
# la firma que _comprobar_grupo compara cada frame.
#
# Va el grupo entero y no solo el lider a proposito: puedes echarle el manto a UN COMPANERO sin
# tocarte a ti, y mirando solo tu elemento ese rastro no aparecia hasta que cambiaba otra cosa.
var _imbue_visto: Array = []

var _drink_was: bool = false   # antirebote de la tecla Q (beber pocion)
# Antirebote de las teclas 1/2/3 (cambiar de lider), una por posicion del equipo. La 0 no se usa:
# la tecla 1 es "el que ya va en cabeza" y no hace nada, pero se deja el hueco para que el indice
# del array sea el mismo que el de Game.party y no haya que restar 1 en ningun sitio.
var _lider_was: Array[bool] = [false, false, false, false]
# Las acciones que corresponden a cada hueco. Antes esto era KEY_1 + i, que solo funcionaba porque
# los codigos de las teclas 1-4 son consecutivos; con acciones hay que nombrarlas. El tamaño de esta
# lista y el de _lider_was tienen que ir a la par.
const ACCIONES_LIDER: Array[StringName] = [&"lider_1", &"lider_2", &"lider_3", &"lider_4"]

# Excelia de AGILIDAD: HUIR de un enemigo que te persigue (ver _tick_huida).
#   _huida_perseguidor = el bicho que nos persigue AHORA (null = no estamos huyendo).
#   _huida_record      = la mayor distancia que le hemos sacado en ESTA persecucion (marca de
#                        agua). Solo se cobra lo que la supera: es lo que impide farmear dandole
#                        vueltas alrededor o dejandose alcanzar para volver a huir (yo-yo).
#   _huida_acum        = hueco nuevo acumulado, pendiente de convertirse en ticks.
var _huida_perseguidor: Node2D = null
# A QUIEN persigue: tu o un companero. La distancia (y por tanto el hueco que se paga) se mide entre
# el bicho y ESTE, no siempre desde el lider.
var _huida_presa: Node2D = null
var _huida_record: float = 0.0
var _huida_acum: float = 0.0
# Px de hueco NUEVO por cada "tick" de ganancia. Se probo a 35 y pagaba de sobra (4 ticks en una sola
# fuga), asi que vuelve a 55: con lose_range en 300 la ventana ya da para 2-3 ticks por fuga, que es
# el ritmo que se busca. Ver tambien Enemy.lose_range, que es lo que abre la ventana.
const _HUIDA_TICK := 55.0
const _AGILIDAD_RANGE := 220.0  # correr solo cuenta con un enemigo a este rango

# Radio de PELIGRO: correr solo cuesta aguante si hay un bicho a menos de esto. Correr por el
# pueblo o por un pasillo vacio no tiene riesgo, asi que tampoco debe cansar. Va APARTE de
# _AGILIDAD_RANGE a proposito: aquella es la regla de la Excelia y tiene su propia semantica.
const _PELIGRO_RANGE := 300.0
# Máscara de colisión de las PAREDES (roca), la misma que usa el enemigo para su línea de visión
# (Enemy.CAPA_ROCA). Con ella el rayo de _vision_libre solo choca con muros, no con bichos.
const CAPA_ROCA := 1


func _ready() -> void:
	# "aliado" = la lista de objetivos que mira el enemigo. El lider entra en ella igual que los
	# companeros (companion.gd), asi que el bicho no tiene que distinguir quien lleva la corona:
	# va a por el que tenga mas a mano.
	add_to_group("aliado")
	_crear_capa_barras()
	add_child(preload("res://scripts/ui/hud.gd").new())  # HUD (barras, peso, piso, ayudas)
	if Tactil.activo:
		add_child(preload("res://scripts/ui/touch_controls.gd").new())  # joystick y botones (movil)
		# Mantener pulsado = leer la ficha de lo que sea. Sin esto, en el movil las descripciones
		# (que viven en tooltip_text, o sea en el tooltip del RATON) no se pueden ver de ninguna
		# manera. Ver ficha_tactil.gd.
		add_child(preload("res://scripts/ui/ficha_tactil.gd").new())
	add_child(preload("res://scripts/ui/inventory_menu.gd").new())  # inventario (I)
	add_child(preload("res://scripts/ui/craft_menu.gd").new())      # boticaria (F sobre el NPC)
	var _cocina_menu := preload("res://scripts/ui/craft_menu.gd").new()  # cocinero: mismo menu, modo distinto
	_cocina_menu.modo = _cocina_menu.Modo.COCINA                   # fijar ANTES de add_child: _ready ya lo lee
	add_child(_cocina_menu)                                        # cocinero (F sobre el NPC)
	add_child(preload("res://scripts/ui/shop_menu.gd").new())       # tienda (F sobre el tendero)
	add_child(preload("res://scripts/ui/forge_menu.gd").new())      # herrero (F sobre el NPC)
	var _carpinteria_menu := preload("res://scripts/ui/forge_menu.gd").new()  # carpintero: mismo menu, modo distinto
	_carpinteria_menu.modo = "carpintero"                          # fijar ANTES de add_child: _ready ya lo lee
	add_child(_carpinteria_menu)                                   # carpintero (F sobre el NPC)
	add_child(preload("res://scripts/ui/tannery_menu.gd").new())    # peletero (F sobre el NPC)
	add_child(preload("res://scripts/ui/tavern_menu.gd").new())     # taberna: contratar (F sobre el NPC)
	add_child(preload("res://scripts/ui/maestro_menu.gd").new())    # maestro: habilidades de arma (F sobre el NPC)
	add_child(preload("res://scripts/ui/fishing_book_menu.gd").new())  # pescador: libro + cebos (F sobre el NPC)
	add_child(preload("res://scripts/ui/fishing_menu.gd").new())    # estanque: cebo y tirar (F sobre el agua)
	add_child(preload("res://scripts/ui/home_menu.gd").new())       # hogar: equipo + almacen (F sobre el NPC)
	add_child(preload("res://scripts/ui/floor_select_menu.gd").new())  # elegir piso (puerta de la mazmorra)
	add_child(preload("res://scripts/ui/character_menu.gd").new())  # menu de personaje (C)
	add_child(preload("res://scripts/ui/map_menu.gd").new())        # mapa del piso (M)
	add_child(preload("res://scripts/ui/altar_menu.gd").new())      # menu del altar (F sobre el altar)
	add_child(preload("res://scripts/ui/retorno_menu.gd").new())    # oferta de subirse a la piedra de otro (multi)
	add_child(preload("res://scripts/ui/desarrollo_menu.gd").new()) # selector de desarrollo (subir de nivel)
	add_child(preload("res://scripts/ui/debug_panel.gd").new())  # panel de debug (cualquier sala)
	# El visor de cajas (dev). Cuelga del jugador como el panel -- muere y renace con la escena --,
	# pero va en top_level, o sea en coordenadas de MUNDO: colgado de verdad, todo lo que dibuja
	# saldria girado y desplazado con el jugador. El interruptor vive en Game.dev_hitboxes, que es
	# lo unico que tiene que sobrevivir al cambio de piso.
	add_child(preload("res://scripts/fx/visor_hitboxes.gd").new())
	add_child(preload("res://scripts/ui/spawner.gd").new())      # spawner de enemigos (dev/test)
	add_child(preload("res://scripts/ui/material_spawner.gd").new())  # spawner de vetas/plantas (dev/test)
	add_child(preload("res://scripts/ui/keys_help.gd").new())    # ayuda de teclas en pantalla (F1)
	add_child(preload("res://scripts/ui/pause_menu.gd").new())   # menu de pausa (ESC): guardar / salir
	add_child(preload("res://scripts/ui/multiplayer_panel.gd").new())  # conexion LAN (desde el menu de pausa)

	# El aguante VIAJA en la ficha del lider (pj.stamina), igual que el de los companeros: por eso
	# cambiar de piso o de escena ya no rellena la barra (sigues como estabas). -1 = a tope (partida
	# nueva). _refrescar_barras lo mantiene sincronizado en la ficha frame a frame.
	#
	# Va ANTES de refrescar_grupo() a proposito: ese refresca las barras, y refrescar las barras
	# VUELCA current_stamina en la ficha del lider. Si se hiciera primero, volcaria el 100 por
	# defecto de la variable y machacaria justo el aguante que veniamos a recuperar.
	_pj_actual = Game.lider()
	max_stamina = _calc_max_aguante()
	current_stamina = _aguante_de(_pj_actual)
	_exhausted = bool(_pj_actual.get_meta("sin_fuelle", false))

	# ASPECTO del personaje: el color y el acabado que eligio al crear la partida (van en el
	# SaveData). El cuerpo es un ColorRect mientras no haya arte; el brillo metalico lo pinta
	# un shader por encima de ese color (null = mate).
	_pintar_cuerpo()

	# EL SEQUITO: los companeros van detras por un rastro (ver party_trail.gd). Se crea siempre,
	# aunque hoy vayas solo: si no hay companeros no pinta nada y no cuesta nada.
	_sequito = preload("res://scripts/actors/player/party_trail.gd").new()
	add_child(_sequito)
	refrescar_grupo()   # sequito y barras del grupo, ya en el primer frame

	# Si llegamos a esta escena con F/Q ya pulsadas (p. ej. justo despues de viajar
	# por una puerta), las marcamos como "ya pulsadas" para NO dispararlas de nuevo
	# hasta que el jugador las suelte y las vuelva a pulsar. Esto evita el rebote
	# entre escenas al mantener F pulsada.
	_interact_was = Input.is_action_pressed(&"interactuar")
	_attack_was = Input.is_action_pressed(&"atacar")
	_drink_was = Input.is_action_pressed(&"curar")

	# Recuperacion segun el nivel (fija, no depende de stats).
	_regen_actual = stamina_regen + stamina_regen_per_level * (Game.player_level - 1)


func _physics_process(delta: float) -> void:
	# Con el inventario abierto: no te mueves ni interactuas (F/ataque). El
	# enemigo sigue su IA aparte, asi que puede emboscarte igualmente. Pero el
	# TIEMPO pasa, asi que el aguante se sigue recuperando.
	_comprobar_grupo()            # ¿ha entrado o salido alguien del equipo? (taberna, Hogar, 1/2/3)
	# La cura/maná de poción gotea FUERA de combate. Con una pelea delante NO: dentro la cola ya se
	# ha convertido en Regeneración por turnos, y dejarla goteando aqui la cobraria dos veces.
	# En solitario esto no llegaba a correr (el árbol se pausa con el combate delante), pero en MULTI
	# el árbol sigue vivo: al que espejaba la pelea de otro se le quemaba la poción al vacío mientras
	# peleaba, y al salir le machacaban la vida con la del doble. Ahí se perdía entera.
	if not Game.hay_modal_de(Game.Modal.COMBATE):
		Game.tick_heal(delta)
		Game.tick_mana_pocion(delta)
		# Y los ESTADOS que salieron de la ultima pelea: el veneno sigue corriendo por el mapa, a
		# Game.SEG_POR_TURNO_FUERA segundos por turno. Con una pelea delante NO, por lo mismo que la
		# cola de poción: ahi los estados ya viven en el combatiente y los tiquea el combate.
		Game.tick_estados(delta)
	_actualizar_max_aguante()     # el maximo escala con Resistencia/Agilidad (refresca si cambian las stats)
	# hay_modal() cubre TODOS los menus de la pila (personaje, ayuda, pausa, panel multi...),
	# no solo el inventario. En solitario esta rama casi no corria (la pausa congelaba el arbol
	# entero); en MULTI el arbol sigue vivo con menus abiertos y esta rama es la que evita que
	# camines o ataques mientras compras. Solo te corta A TI: tu companero sigue a lo suyo.
	if Game.inventory_open or Game.debug_panel_open or Game.hay_modal():
		velocity = Vector2.ZERO
		_atk_buffer = 0.0   # el golpe pendiente no sobrevive a una pantalla: se pulso para OTRO momento
		# EN COMBATE NO se regenera aguante. La energia con la que entras a la pelea es la stamina
		# de exploracion ("correr antes de pelear se paga", ver Game.start_combat): en un jugador
		# esto se congelaba con el arbol, pero en multi el arbol sigue vivo y quedarse en una pelea
		# larga te curaria el aguante gratis, incluido salir de _exhausted. Con un menu abierto si
		# regenera, como siempre.
		if not Game.hay_modal_de(Game.Modal.COMBATE):
			current_stamina = minf(max_stamina, current_stamina + _regen_actual * delta)
			_tick_aguante_companeros(delta, false)   # el tiempo pasa para todos, no solo para ti
			if _exhausted and current_stamina >= max_stamina * exhausted_recover_ratio:
				_exhausted = false
		_refrescar_barras()
		if Net.activo:
			# Que el otro te vea QUIETO, no congelado. Con tu sequito: sus cuerpos tambien viajan.
			Net.enviar_estado(global_position, _facing, _sequito.posiciones_red())
		return

	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")
	# Con los dedos manda el joystick de la pantalla, que es ANALOGICO: las cuatro acciones de
	# movimiento son de dentro/fuera y con ellas no habria medias velocidades. Solo pisa al teclado
	# cuando hay un dedo puesto (eje != ZERO), asi que un mando o un teclado enchufado al movil
	# siguen funcionando.
	if Tactil.activo and Tactil.eje != Vector2.ZERO:
		direction = Tactil.eje
	var moving: bool = direction != Vector2.ZERO
	if moving:
		_facing = direction.normalized()  # recordamos hacia donde miramos

	# Modo segun teclas (Ctrl = sigilo tiene prioridad sobre Shift = correr).
	# Si estamos AGOTADOS, no se puede correr (hasta recuperar la mitad).
	var sneaking: bool = Input.is_action_pressed(&"sigilo")
	# El grupo va al paso del MAS CANSADO: basta con que UNO este sin fuelle para que el grupo entero
	# se arrastre, sea el lider o un companero. Antes, si el agotado era un companero, solo se perdia
	# el correr (seguias andando normal) y el que no podia mas te seguia el paso como si nada.
	var agotado: PersonajeData = _pj_agotado()
	var running: bool = Input.is_action_pressed(&"correr") and not sneaking \
		and moving and agotado == null

	var speed: float = walk_speed
	if agotado != null:
		# Alguien sin fuelle: el grupo se arrastra a velocidad de sigilo, corras o no.
		speed = walk_speed * sneak_multiplier
		movement_mode = 0
	elif sneaking:
		speed = walk_speed * sneak_multiplier
		movement_mode = 0
	elif running:
		speed = walk_speed * run_multiplier
		movement_mode = 2
	else:
		movement_mode = 1

	# Enemigo mas cercano. Solo hace falta si corremos: es lo unico que mira los radios. Se calcula
	# UNA vez y lo reaprovecha tambien la Excelia de Agilidad, mas abajo.
	var enemigo_cerca: Node = null
	var dist_enemigo: float = INF
	if running:
		var cercano: Array = _enemigo_mas_cercano()
		enemigo_cerca = cercano[0]
		dist_enemigo = float(cercano[1])

	# Aguante: baja al correr, pero SOLO con un enemigo dentro del radio de peligro. Correr por el
	# pueblo o por un pasillo vacio ya no cansa (y encima regenera). Ir a por un bicho sigue
	# costando: cruzas los 300 px mucho antes de alcanzarlo, asi que "correr antes de pelear se
	# paga" se mantiene. Los companeros pagan exactamente lo mismo (ver _tick_aguante_companeros).
	var gastando: bool = false
	if running:
		# (A) Te persigue alguien (a ti o a un companero): pagas AUNQUE metas una pared de por medio.
		# Huir es correr con uno pegado a los talones, y cortar la esquina no te libra del esfuerzo.
		var persiguiendo: bool = _perseguidor()[0] != null
		# (B) O un enemigo dentro del radio de peligro al que VES (sin pared en medio). Correr a la
		# vista de un bicho cuesta; al otro lado de un muro que no te ve, correr es gratis.
		var cerca_visible: bool = enemigo_cerca != null and dist_enemigo <= _PELIGRO_RANGE and _vision_libre((enemigo_cerca as Node2D).global_position)
		gastando = persiguiendo or cerca_visible
	if gastando:
		current_stamina -= run_drain * delta
		if current_stamina <= 0.0:
			current_stamina = 0.0
			_exhausted = true  # nos quedamos sin fuelle
	else:
		current_stamina = minf(max_stamina, current_stamina + _regen_actual * delta)
		# Salimos de agotado al recuperar la mitad del aguante.
		if _exhausted and current_stamina >= max_stamina * exhausted_recover_ratio:
			_exhausted = false
	_tick_aguante_companeros(delta, gastando)

	_refrescar_barras()

	# Sobrecarga (loot): cuanto mas peso en la mochila, mas lento (gradual).
	speed *= Game.overload_speed_factor()
	# Armadura: la categoria modula la velocidad de movimiento (placas te frenan,
	# ir ligero/sin armadura te acelera un pelin). Igual que en el ATB de combate.
	speed *= Game.armor_speed_mult()
	# La AGILIDAD del que marca el paso: normalmente el que va en cabeza (por eso cambiar de lider
	# con 1/2/3 se nota tambien fuera del combate), pero si alguien va sin fuelle manda EL, que es
	# quien se arrastra. Con dos agotados, el de menos Agilidad (ver _pj_agotado).
	speed *= Game.agilidad_speed_mult(agotado)
	# Y lo que FRENAN los estados (Lento, Pegajoso; Presteza acelera). Manda el PEOR del grupo, como
	# con el que se queda sin fuelle: bajais juntos y en fila, asi que la baba que se ha comido el que
	# va detras os frena a todos. Va al final de la cadena, como un multiplicador mas: los modos de
	# movimiento (sigilo/correr) se calculan arriba y NO se tocan, que es lo que mantiene en pie la
	# invariante de que correr es siempre mas rapido que andar, lleves lo que lleves encima.
	speed *= Game.estados_speed_mult_grupo()

	velocity = direction * speed
	move_and_slide()

	# La animacion va DESPUES de mover, con lo que de verdad ha pasado. Puesta antes, un personaje
	# empotrado contra una pared seguiria haciendo el paso: se mueve el que EMPUJA, no el que avanza.
	_actualizar_animacion(velocity.length() > 2.0, delta)

	# ALBOROTO: la mazmorra te oye. Correr mete ruido (llena el medidor de los brotes), ir en
	# sigilo lo baja. El modo ya esta calculado arriba (0 sigilo, 1 andar, 2 correr).
	Game.tick_alboroto(delta, movement_mode)
	_tick_ruido(delta)   # desinfla el estallido de un conjuro fallido (ver hacer_ruido)
	Game.tick_hechizo_de_entrada(delta)   # devuelve el maná si la pelea del conjuro no llego a abrirse

	# --- Excelia: subida de habilidades por uso (interno; se aplica en el hogar) ---
	# Agilidad: HUIR de verdad. Ver _tick_huida. No le pasamos la velocidad del grupo: cada
	# personaje se mide con la SUYA (_vel_carrera_de), que es lo que de verdad le cuesta la fuga.
	_tick_huida()

	# DOS teclas, y no una: ATACAR y TOCAR COSAS son intenciones distintas y no se pueden
	# confundir. Con una sola tecla, ir a extraer un cristal con un bicho cerca podia
	# lanzarte al combate sin querer.
	#   ESPACIO = atacar al enemigo que tengas ENFRENTE (entra en combate). Va en el pulgar,
	#             que es lo comodo teniendo el WASD ocupado.
	#   F       = interactuar: puerta, escalera, altar, tienda, cadaver, objeto del suelo.
	# El ESPACIO no se tira si no habia nadie a tiro: se RECUERDA (ver ATK_BUFFER) y se reintenta cada
	# frame mientras dure. Es lo que hace que "pulsar cuando le ves venir" funcione contra una embestida
	# en vez de gastarse en balde a 20 px del bicho.
	_tick_ataque(delta)

	var inter: bool = Input.is_action_pressed(&"interactuar")
	if inter and not _interact_was:
		_try_interact()
	_interact_was = inter

	# Beber una pocion (Q): cura por el tiempo fuera de combate.
	var drink: bool = Input.is_action_pressed(&"curar")
	if drink and not _drink_was:
		_beber_pocion()
	_drink_was = drink

	# 1/2/3: quien va EN CABEZA. Cambia el cuerpo que mueves, su aguante y su velocidad, y en
	# combate sera el suyo el combatiente que entra. Es la jugada tactica de fuera de combate:
	# entrar tu primero, o mandar delante al que aguanta.
	# Ahora cada hueco es fijo, asi que la tecla 1 (hueco 0) tambien sirve: pone en cabeza al
	# primero. cambiar_lider no hace nada si ya es el lider.
	for i in range(mini(Game.party.size(), _lider_was.size())):
		var pulsada: bool = Input.is_action_pressed(ACCIONES_LIDER[i])
		if pulsada and not _lider_was[i]:
			if Game.cambiar_lider(i):
				refrescar_lider()
		_lider_was[i] = pulsada

	# MULTIJUGADOR (hito 1): si hay sesion de red, difunde donde estoy para que el otro me vea
	# moverme. En un jugador (Net.activo == false) esto no hace nada.
	if Net.activo:
		Net.enviar_estado(global_position, _facing, _sequito.posiciones_red())


# Aguante maximo segun la Resistencia y la Agilidad. Usa lo CONSOLIDADO (lo del ultimo altar), no
# el total oculto: ese crece con CADA golpe (Game.ganar escribe en ability_internal), asi que el
# aguante maximo subia en vivo mientras el resto de stats esperaba al altar —una incoherencia que
# se veia jugando—. El consolidado tampoco se desploma al subir de nivel (a diferencia del visible),
# asi que crece solo al descansar sin caer a base_stamina en cada ascenso. Ver Game.stat_consolidado.
func _calc_max_aguante(pj: PersonajeData = null) -> float:
	return base_stamina \
		+ Game.stat_consolidado("resistencia", pj) * stamina_per_resistencia \
		+ Game.stat_consolidado("agilidad", pj) * stamina_per_agilidad


# El aguante ACTUAL de un companero, concretando el -1 (= "nunca ha corrido" -> lleno).
func _aguante_de(pj: PersonajeData) -> float:
	var maxi_: float = _calc_max_aguante(pj)
	return maxi_ if pj.stamina < 0.0 else clampf(pj.stamina, 0.0, maxi_)


# ============================================================
#  AGUANTE DEL GRUPO
#  Correr lo pagan TODOS: el grupo corre junto, asi que el aguante baja en las tres barras a la
#  vez. Y el grupo va al paso del MAS CANSADO: si CUALQUIERA se agota, nadie corre hasta que se
#  recupere (ver _pj_agotado). Eso hace que la Resistencia de todo el mundo importe y que
#  meter en el equipo a uno que no aguanta tenga un coste de verdad.
#
#  Este aguante es la MISMA barra que la energia con la que entras al combate (el que llega
#  agotado actua lento las primeras acciones). Correr antes de pelear se paga: es la decision.
# ============================================================

# Gasta o repone aguante a los COMPANEROS (el del lider lo lleva current_stamina, aparte, porque
# es el que pinta la barra grande y el que ya existia).
func _tick_aguante_companeros(delta: float, corriendo: bool) -> void:
	for pj in Game.companeros():
		var maxi_: float = _calc_max_aguante(pj)
		var actual: float = _aguante_de(pj)
		if corriendo:
			actual = maxf(0.0, actual - run_drain * delta)
		else:
			actual = minf(maxi_, actual + _regen_actual * delta)
		pj.stamina = actual


# QUIEN del equipo (tu incluido) esta sin fuelle y MAS frena al grupo; null si nadie lo esta. Un
# companero se considera agotado por debajo del mismo umbral de recuperacion que tu: se queda tirado
# hasta recuperar la mitad, o si no bastaria con soltar Shift un instante para volver a correr con
# el a cero.
# Devuelve al agotado de MENOS Agilidad porque el grupo va al paso del mas lento: si se arrastran
# dos, manda el peor. Y devuelve la FICHA (no un bool) porque el que frena decide tambien CUANTO se
# frena el grupo: su Agilidad es la que multiplica la velocidad (ver _physics_process).
func _pj_agotado() -> PersonajeData:
	var peor: PersonajeData = null
	# Con la CONSOLIDADA (y su plato), que es la misma que luego decide CUANTO se frena el grupo en
	# Game.agilidad_speed_mult. Con la interna, el que mandaba aqui no era siempre el que mas frena.
	var peor_agi: float = 0.0
	if _exhausted:
		peor = _pj_actual
		peor_agi = Game.stat_consolidado_eff("agilidad", _pj_actual)
	for pj in Game.companeros():
		var maxi_: float = _calc_max_aguante(pj)
		if _aguante_de(pj) <= 0.0:
			pj.set_meta("sin_fuelle", true)
		elif _aguante_de(pj) >= maxi_ * exhausted_recover_ratio:
			pj.set_meta("sin_fuelle", false)
		if not bool(pj.get_meta("sin_fuelle", false)):
			continue
		var agi: float = Game.stat_consolidado_eff("agilidad", pj)
		if peor == null or agi < peor_agi:
			peor = pj
			peor_agi = agi
	return peor

# Recalcula el aguante maximo por si las stats cambiaron (panel DEBUG, tecla U, subida en
# el hogar...). Si la barra estaba llena, la mantiene llena; si no, respeta lo que quede.
func _actualizar_max_aguante() -> void:
	var nuevo: float = _calc_max_aguante()
	if is_equal_approx(nuevo, max_stamina):
		return
	var estaba_llena: bool = current_stamina >= max_stamina - 0.01
	max_stamina = nuevo
	current_stamina = max_stamina if estaba_llena else minf(current_stamina, max_stamina)


# ============================================================
#  CAMBIAR DE LIDER (teclas 1/2/3, o el gestor de equipo del Hogar)
#  El cuerpo del mapa es UNO solo: al cambiar de lider no se cambia de nodo, se le cambia la
#  CARA y las stats de las que tira. Lo unico que hay que tener cuidado de no perder es el
#  AGUANTE, que es de cada persona: el que se va atras se lleva el suyo tal y como lo dejo.
#
#  Y NADIE SE MUEVE DE SITIO. Antes el elegido "aparecia" en cabeza (te lo plantaba delante) y se
#  leia como si la fila se reordenara sola: una interaccion forzada. Ahora el cuerpo que llevas se
#  planta DONDE ESTABA EL ELEGIDO, el que deja la cabeza hereda el sitio que tenias tu, y los
#  demas se quedan clavados donde estaban y empiezan a seguir al nuevo desde ahi.
#
#  El viaje lo cuenta la CAMARA: va suavizada (position_smoothing en player.tscn), asi que al NO
#  llamar a reset_smoothing() -al reves que recolocar()- se desplaza sola hasta el nuevo cuerpo.
#  Ese paneo es toda la explicacion que necesita el cambio: la camara te lleva hasta el que has
#  elegido, en vez de traertelo a ti.
# ============================================================
func refrescar_lider() -> void:
	var nuevo: PersonajeData = Game.lider()
	# Donde esta cada uno JUSTO ANTES de tocar nada: los companeros por su cuerpo del sequito, y
	# el que hasta ahora iba en cabeza, aqui mismo.
	var previas: Dictionary = {}
	if _sequito != null and _sequito.has_method("posiciones"):
		previas = _sequito.posiciones()   # Dictionary por PersonajeData; NO es posiciones_red()
	if _pj_actual != null:
		previas[_pj_actual] = global_position
	# El cuerpo que mueves se va a donde estaba el elegido (la camara hace el viaje detras).
	if previas.has(nuevo):
		global_position = previas[nuevo]
		# Cambiar de lider NO es huir: el cuerpo salta al sitio del que iba delante, y sin esto ese
		# salto contaria como hueco abierto al perseguidor y regalaria excelia de Agilidad.
		_reset_huida()

	# El aguante del que hasta ahora iba delante se queda en SU ficha, incluido si estaba sin
	# fuelle: mandarlo atras no lo descansa.
	if _pj_actual != null:
		_pj_actual.stamina = current_stamina
		_pj_actual.set_meta("sin_fuelle", _exhausted)
	_pj_actual = nuevo
	# Y el del nuevo: -1 = nunca ha corrido (companero recien contratado) -> entra descansado.
	max_stamina = _calc_max_aguante()
	current_stamina = _aguante_de(_pj_actual)
	# El cansancio viaja CON la persona: si el que pones delante venia agotado, sigue agotado.
	_exhausted = bool(_pj_actual.get_meta("sin_fuelle", false))
	refrescar_grupo()
	# Y la fila, tal y como estaba: cada cuerpo en su sitio y el rastro tendido entre ellos.
	if _sequito != null and _sequito.has_method("reordenar"):
		_sequito.reordenar(previas)


# Repinta TODO lo que depende de quien va en el grupo: el cuerpo del lider, el sequito que va
# detras y las barras de vida de los companeros. No toca el aguante (de eso se encarga
# refrescar_lider), asi que se puede llamar todas las veces que haga falta.
func refrescar_grupo() -> void:
	_grupo_visto = Game.party.duplicate()
	_pj_actual = Game.lider()
	_pintar_cuerpo()
	if _sequito != null and _sequito.has_method("refrescar"):
		_sequito.refrescar()
	# MULTIJUGADOR: ha cambiado mi equipo, asi que los demas necesitan las caras nuevas. Van las DOS
	# mitades, y en este orden:
	#
	#  1) MI aspecto. Game.player_color/imagen/... son propiedades DELEGADAS al lider, asi que poner
	#     a otro en cabeza cambia mi aspecto. Sin reemitirlo, el otro se quedaba con el del lider
	#     anterior clavado en mi avatar principal -- y como ese mismo personaje aparecia ADEMAS
	#     (bien) en mi sequito, veia dos cuerpos con la misma cara. No era un desfase: el avatar
	#     principal se quedaba con el aspecto del saludo hasta que volvias a poner delante a ese.
	#  2) EL SEQUITO. Va despues para que el avatar principal ya este repintado cuando cambien las
	#     caras de detras: si no, hay un instante con dos iguales.
	#
	# Las dos son no-op sin sesion, y reparten a TODOS los peers (no asumen un solo invitado).
	Net.anunciar_aspecto()
	Net.anunciar_grupo()
	# Y sus imbuiciones: al cambiar el equipo cambia QUIEN va en cada hueco, asi que el paquete de
	# imbuiciones (que va por posicion) se queda desfasado si no se reemite aqui tambien.
	Net.anunciar_imbue()
	_rehacer_barras()
	_refrescar_barras()
	# La MOCHILA del HUD va detras de la ultima columna de barras: si el grupo crece o mengua,
	# tiene que apartarse. Se le avisa aqui en vez de que ella lo mire cada frame.
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("recolocar"):
		hud.recolocar()


# Si el grupo ha cambiado desde el ultimo repintado, repintar. Se mira cada frame porque cambiar
# de gente pasa desde sitios muy distintos (taberna, Hogar, teclas 1/2/3) y comparar dos arrays
# cortos no cuesta nada; asi ninguno tiene que acordarse de avisar.
#
# La IMBUICION va por el mismo camino y por el mismo motivo: sus cargas se gastan DENTRO del
# combate, asi que al volver al mapa el elemento puede haber desaparecido sin que nadie de aqui se
# haya enterado. Mirar un int del dict cada frame es gratis y evita tener que avisar desde combat.
func _comprobar_grupo() -> void:
	if _grupo_visto != Game.party:
		refrescar_grupo()
	elif _imbue_visto != _firma_imbue():
		# Solo ha cambiado la imbuicion: NO vale llamar a refrescar_grupo, que re-difunde por red el
		# aspecto entero (el PNG de 128x128 de cada uno). Las cargas se gastan en cada combate, asi
		# que eso seria mandar las imagenes del grupo cada dos por tres.
		refrescar_imbue()


# Repinta SOLO los rastros de imbuicion: el tuyo y el de cada companero de la fila. Es el hermano
# ligero de refrescar_grupo, para lo que cambia a menudo.
func refrescar_imbue() -> void:
	_pintar_imbue()
	# refrescar_imbue y NO refrescar: aquella se salta a los companeros que no han cambiado de dueño,
	# que es justo el caso de aqui (misma gente, otra imbuicion).
	if _sequito != null and _sequito.has_method("refrescar_imbue"):
		_sequito.refrescar_imbue()
	# MULTIJUGADOR: canal propio y barato (un int por persona), no el aspecto completo.
	Net.anunciar_imbue()


# Los elementos imbuidos del grupo, en orden. El criterio de "que cuenta como imbuido" vive en la
# ficha (PersonajeData.imbue_elemento), que es quien tiene el dict.
func _firma_imbue() -> Array:
	var out: Array = []
	for pj in Game.party:
		out.append(Elementos.Elemento.NINGUNO if pj == null else (pj as PersonajeData).imbue_elemento())
	return out


# Las barras de los COMPANEROS, debajo de las tuyas: mas finas y sin numeros gordos, porque son
# informacion de apoyo (¿aguanta el de atras?), no lo que estas mirando todo el rato. Cada una
# lleva delante el cuadradito de su color, que es como los distingues en el mapa.
# Van a la DERECHA, bajo el panel de piso/monedas, y no debajo de tus barras: la esquina de la
# izquierda ya la ocupan tus tres barras Y la caja de ayudas de teclas (hud.gd, en 8,64), asi que
# ahi se pisaban. A la derecha hay sitio de sobra y ademas quedan agrupadas con el resto de
# informacion de estado.
#
# Se anclan a la esquina TOP_RIGHT en vez de ponerles una x fija: asi siguen pegadas al borde
# aunque cambie la resolucion, igual que hace el panel de piso/monedas.
# ============================================================
#  LAS BARRAS DEL GRUPO
#  Cada personaje es una COLUMNA de tres barras (vida, aguante, mana), y las columnas van una al
#  lado de la otra: tu la primera, y los companeros a tu derecha en el orden en que te siguen.
#
#  Las de los companeros son IGUALES que las tuyas (mismo alto, mismo ancho, mismos colores y el
#  mismo orden): son las barras de una persona, y hacerlas distintas obligaria a traducir a cada
#  vistazo. Van SIEMPRE las tres aunque hoy no tenga hechizos, por lo mismo.
#
#  El cuadrado del PESO (la mochila) lo pinta hud.gd y se coloca DESPUES de la ultima columna,
#  asi que se aparta solo segun el tamaño del grupo. Por eso estas medidas son constantes
#  publicas: el HUD las lee para saber donde acaba la fila (ver hud.recolocar).
# ============================================================
const X_COL_BARRAS := 12.0    # donde empieza tu columna (misma sangria que siempre)
const ANCHO_COL := 200.0      # lo que mide una columna ENTERA (barras + cuadro de equipo)
const SEP_COL := 8.0          # aire entre una columna y la siguiente
# EL CUADRO DE EQUIPO, a la derecha de las tres barras de cada uno (ver cuadro_equipo.gd). Las
# barras se encogen para dejarle sitio DENTRO de la columna, asi que la fila sigue siendo una fila
# de columnas iguales y la mochila se coloca detras sola.
#
# Va del NOMBRE al FONDO DE LA ULTIMA BARRA, ni un pixel mas: ver ALTO_EQUIPO abajo.
const LADO_EQUIPO := 68.0
const SEP_EQUIPO := 6.0
const ANCHO_BARRA := ANCHO_COL - LADO_EQUIPO - SEP_EQUIPO
# El NOMBRE va encima de las tres barras, y por eso todo el bloque baja: con las barras pegadas
# al borde de arriba (y=12, como estaban cuando no habia grupo) el nombre se salia de la pantalla.
const Y_NOMBRE := 4.0
const ALTO_NOMBRE := 14.0
# Los tres huecos de una columna. TODOS los personajes usan estos, tu incluido: asi las columnas
# quedan alineadas al pixel y no hay dos sitios que puedan descuadrarse.
const Y_HP := Y_NOMBRE + ALTO_NOMBRE
const ALTO_HP := 18.0
const Y_EN := Y_HP + ALTO_HP + 4.0
const ALTO_EN := 12.0
const Y_MP := Y_EN + ALTO_EN + 4.0
const ALTO_MP := 12.0
# LA LINEA DE ABAJO, y el alto de todo lo que va a su lado. Todo lo que se pinte a la derecha de las
# barras -el cuadro de equipo de cada uno y la mochila del HUD- tiene que empezar en el nombre y
# acabar EXACTAMENTE aqui, en el fondo de la barra de mana. Antes el cuadro llegaba hasta el final
# del bloque (los chips incluidos) y se salia 25 px por debajo de las barras: la fila se veia
# descuadrada por abajo.
#
# Sale UNA SOLA VEZ y de aqui lo lee todo el mundo (hud.recolocar tambien): es lo unico que
# garantiza que sigan cuadrados el dia que una barra cambie de alto.
const Y_LINEA_BAJA := Y_MP + ALTO_MP
const ALTO_EQUIPO := Y_LINEA_BAJA - Y_NOMBRE
# La linea de CHIPS de estados (y las cargas de Foco), debajo de las tres barras. Los estados duran
# entre combates, asi que tienen que verse desde el mapa.
const Y_ESTADOS := Y_MP + ALTO_MP + 3.0
# 22 y no 12: desde que los estados se pintan como CHIPS con recuadro y no como una linea de texto
# recortada, la fila necesita el alto del chip. ALTO_BLOQUE lo recoge solo y hud.recolocar() baja la
# caja de teclas: no hay ningun otro sitio que dependa de esto.
const ALTO_ESTADOS := 22.0
# Donde acaba la fila entera. Lo lee hud.gd para colocar debajo la caja de ayudas de teclas.
const ALTO_BLOQUE := Y_ESTADOS + ALTO_ESTADOS


# La x donde arranca la columna del personaje i (0 = tu). La usa tambien el HUD para saber donde
# poner la mochila, que va detras de la ultima.
static func x_columna(i: int) -> float:
	# El borde seguro se suma aqui, que es el unico sitio que decide donde empieza la fila: en un
	# movil con la pantalla redondeada, la primera columna se comia el canto (ver Tactil.borde).
	return X_COL_BARRAS + Tactil.borde.x + float(i) * (ANCHO_COL + SEP_COL)


# Rehace TODAS las columnas de barras: una por miembro del grupo, en su ORDEN FIJO de party (el
# hueco 0 es siempre el primero del equipo, no "el lider"). La columna del que va en cabeza lleva
# una coronita en el nombre. Se llama al cambiar el grupo o el lider (refrescar_grupo).
func _rehacer_barras() -> void:
	for fila in _barras:
		(fila["raiz"] as Node).queue_free()
	_barras.clear()
	if _barras_layer == null:
		return
	var lider: PersonajeData = Game.lider()
	for i in Game.party.size():
		var pj: PersonajeData = Game.party[i]
		var raiz := Control.new()
		# La y tambien baja por el borde seguro: la muesca y la esquina redondeada se comen la fila
		# de arriba igual que el canto lateral.
		raiz.position = Vector2(x_columna(i), Tactil.borde.y)
		raiz.size = Vector2(ANCHO_COL, ALTO_BLOQUE)
		# LA TARJETA ENTERA ES EL BOTON de cambiar de lider: las tres barras, el nombre y el hueco
		# entre medias. Sale por el mismo sitio que las teclas 1/2/3 (cambiar_lider + refrescar), asi
		# que no hay una segunda version de la regla.
		#
		# Se pulsa TAMBIEN con el raton, y no solo con los dedos: la tarjeta se ve igual en las dos, y
		# tener una zona que responde en el movil y no en el escritorio no hay quien lo adivine. Las
		# teclas siguen igual.
		raiz.mouse_filter = Control.MOUSE_FILTER_STOP
		raiz.gui_input.connect(func(event: InputEvent) -> void:
			var toque: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
				or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
			if toque and Game.cambiar_lider(i):
				refrescar_lider()
		)
		_barras_layer.add_child(raiz)

		# El cuadradito de color y el nombre encima, lo unico que distingue una columna de otra.
		var punto := ColorRect.new()
		punto.size = Vector2(9, 9)
		punto.position = Vector2(0, Y_NOMBRE + 1.0)
		punto.color = pj.color
		punto.material = Game.material_de(pj)
		punto.mouse_filter = Control.MOUSE_FILTER_IGNORE   # que el toque llegue a la tarjeta
		raiz.add_child(punto)

		# La CORONA va aparte del nombre (mismo Label lleva el emoji + el texto): asi al cambiar de
		# lider solo hay que reescribir el text, sin recrear la columna.
		var nombre := Label.new()
		nombre.text = ("👑 " if pj == lider else "") + pj.nombre
		nombre.position = Vector2(12, Y_NOMBRE - 4.0)
		nombre.add_theme_font_size_override("font_size", 10)
		nombre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		nombre.add_theme_constant_override("outline_size", 3)
		nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		raiz.add_child(nombre)

		# Las tres barras, iguales para todos (vida, aguante, mana).
		var hp: ProgressBar = _barra_col(raiz, Y_HP, ALTO_HP, Color(1.0, 0.4, 0.4))
		var hp_lbl: Label = _crear_label_barra(hp)
		var en: ProgressBar = _barra_col(raiz, Y_EN, ALTO_EN, Color(0.4, 1.0, 0.5))
		var en_lbl: Label = _crear_label_barra(en)
		var mp: ProgressBar = _barra_col(raiz, Y_MP, ALTO_MP, Color(0.4, 0.6, 1.0))
		var mp_lbl: Label = _crear_label_barra(mp)

		# EL CUADRO DE EQUIPO, pegado a la derecha de las tres barras y con su mismo alto (de la de
		# vida al fondo de la de mana). Alterna solo entre armadura y armas; ver cuadro_equipo.gd.
		var equipo := CuadroEquipo.new()
		equipo.pj = pj
		equipo.position = Vector2(ANCHO_BARRA + SEP_EQUIPO, Y_NOMBRE)
		equipo.size = Vector2(LADO_EQUIPO, ALTO_EQUIPO)
		raiz.add_child(equipo)

		# Los ESTADOS que lleva puestos, en una fila de CHIPS debajo de las barras. Los estados duran
		# fuera del combate (el veneno sigue corriendo, el Pegajoso te frena, el plato de cocina dura
		# 20 minutos), asi que hace falta poder verlos sin abrir nada: si no, la vida baja sola y no
		# hay forma de saber por que.
		var estados := HBoxContainer.new()
		estados.position = Vector2(0, Y_ESTADOS)
		# El ancho ENTERO de la columna: el cuadro de equipo acaba en la linea de las barras
		# (Y_LINEA_BAJA), asi que por debajo no estorba y los chips tienen todo el sitio.
		estados.size = Vector2(ANCHO_COL, ALTO_ESTADOS)
		estados.add_theme_constant_override("separation", 3)
		estados.clip_contents = true
		# La FILA no atrapa el toque (asi el hueco entre chips sigue cambiando de lider); los chips que
		# van dentro si lo hacen, que cada uno tiene su tooltip.
		estados.mouse_filter = Control.MOUSE_FILTER_IGNORE
		raiz.add_child(estados)

		# La FIRMA de lo que hay pintado ahora mismo. _refrescar_barras corre en CADA frame y los
		# chips son nodos: sin esto se reconstruirian sesenta veces por segundo para pintar lo mismo.
		_barras.append({"pj": pj, "raiz": raiz, "nombre": nombre, "hp": hp, "hp_lbl": hp_lbl,
			"en": en, "en_lbl": en_lbl, "mp": mp, "mp_lbl": mp_lbl, "equipo": equipo,
			"estados": estados, "estados_firma": ""})

	# La fila acaba de cambiar de ancho (un companero mas o uno menos): puede que ya no quepa.
	_ajustar_escala_fila()


# Una barra de una columna (mismo ancho para las tres, solo cambian el alto y el color).
func _barra_col(raiz: Control, y: float, alto: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(ANCHO_BARRA, alto)
	b.size = Vector2(ANCHO_BARRA, alto)
	b.position = Vector2(0, y)
	b.self_modulate = color
	# UNA BARRA NO SE PULSA: se deja pasar el toque a la tarjeta, que es la que cambia de lider. Un
	# Control atrapa el raton por defecto, y como las tres barras ocupan casi toda la tarjeta, lo
	# unico que quedaba vivo era la tira del nombre y los huecos entre barras.
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(b)
	return b


# EL CUERPO. Desde que hay arte es un MunecoJugador: la pila de capas (cuerpo, armadura, armas) que
# se tiñe con tu color. El ColorRect de player.tscn se queda de RESPALDO y solo se ve si el muñeco
# no ha podido montarse -- igual que un bicho sin generador sigue saliendo como un cuadrado. Vale la
# pena: si algun dia falta un horneado, el juego se ve raro pero se juega, en vez de moverse un
# personaje invisible.
func _pintar_cuerpo() -> void:
	var cuerpo := get_node_or_null("ColorRect") as ColorRect
	if _muneco == null:
		_muneco = MunecoJugador.new()
		add_child(_muneco)
	_muneco.montar(Game.lider())
	if _muneco.hay_dibujo():
		# El tinte y el metal son los MISMOS que ya elegiste: no hay ajuste nuevo que tocar, solo
		# que ahora en vez de pintar un cuadrado pintan una persona.
		_muneco.tenir(Game.player_color, Game.player_metalico)
		# TU IMAGEN, EN LA CABEZA. Es la misma que ya se pintaba en el ColorRect de respaldo (la
		# linea de abajo), solo que ahora va donde tiene que ir. Sin esta llamada el muñeco tapa el
		# ColorRect y tu retrato deja de verse en el mapa sin que nada de errores: eso es lo que
		# pasaba desde que entro el arte.
		_muneco.poner_cara(Game.textura_cuerpo())
		_muneco.animar(PoseJugador.animacion(_facing, movement_mode, false))
		if cuerpo != null:
			cuerpo.visible = false
	elif cuerpo != null:
		cuerpo.visible = true
		cuerpo.color = Game.player_color
		cuerpo.material = Game.material_cuerpo()
	_pintar_imbue()


# Traduce el estado del movimiento a la animacion que toca. Quien decide QUE animacion es
# PoseJugador, no esto -- la misma regla la necesitan el compañero, el jugador remoto y el visor.
#
# Se llama en cada frame de fisica y solo hace algo cuando la animacion CAMBIA (lo filtra el propio
# muñeco): reiniciarla cada frame la dejaria congelada en el primer fotograma.
func _actualizar_animacion(moviendose: bool, delta: float) -> void:
	if _golpe_t > 0.0:
		_golpe_t -= delta
	if _muneco == null or not _muneco.hay_dibujo():
		return
	_muneco.animar(PoseJugador.animacion(_facing, movement_mode, moviendose, _golpe_t > 0.0))


# RASTRO de la imbuicion: cuadraditos del color del elemento que suben y se quedan atras al andar.
# Es informacion de juego, no adorno -- la imbuicion dura entre combates y se gasta por cargas, asi
# que saber de un vistazo si la llevas puesta y de que elemento importa.
#
# El emisor se crea la primera vez y luego solo se repinta; si te quedas sin elemento se borra del
# todo (dejarlo parado gastaria un nodo por cada personaje que alguna vez se imbuyo).
func _pintar_imbue() -> void:
	# La firma se apunta AQUI (no en refrescar_grupo) porque este es el punto por el que pasan todos
	# los repintados del cuerpo, vengan de donde vengan.
	_imbue_visto = _firma_imbue()
	var pj: PersonajeData = Game.lider()
	var elem: int = Elementos.Elemento.NINGUNO if pj == null else pj.imbue_elemento()
	if not Elementos.tiene_color(elem):
		if _fx_imbue != null:
			_fx_imbue.queue_free()
			_fx_imbue = null
		return
	if _fx_imbue == null:
		_fx_imbue = Particulas.ascendentes(self, Elementos.color(elem), 1.0, LADO_CUERPO)
	else:
		Particulas.repintar(_fx_imbue, Elementos.color(elem))


# True si estamos agotados (lo consulta el enemigo para atacar al instante).
func is_exhausted() -> bool:
	return _exhausted


# El aguante de UN miembro del grupo: (actual, maximo). Lo pide Game al montar el combate, porque
# esa barra es la ENERGIA con la que cada uno entra a pelear (KAN-57). El del que va en cabeza no
# esta en su ficha sino en las variables vivas (las usa el movimiento), de ahi el caso aparte.
# Vuelca a las variables vivas el aguante que la FICHA del lider trae ahora mismo. Lo llama Game
# al salir del combate: alli la energia se gasta y se regenera por persona, y se guarda en las
# fichas; sin esto, el cuerpo del mapa seguiria con el aguante que tenia al entrar y se comeria
# todo lo que paso en la pelea.
func recargar_aguante_lider() -> void:
	_pj_actual = Game.lider()
	max_stamina = _calc_max_aguante()
	current_stamina = _aguante_de(_pj_actual)
	_exhausted = bool(_pj_actual.get_meta("sin_fuelle", false))


# El aguante de UN miembro del grupo: (actual, maximo). Lo pide Game al montar el combate, porque
# esa barra es la ENERGIA con la que cada uno entra a pelear (KAN-57). El del que va en cabeza no
# esta en su ficha sino en las variables vivas (las usa el movimiento), de ahi el caso aparte.
func aguante_de_grupo(pj: PersonajeData) -> Vector2:
	if pj == _pj_actual:
		return Vector2(current_stamina, max_stamina)
	return Vector2(_aguante_de(pj), _calc_max_aguante(pj))


# ============================================================
#  EXCELIA DE AGILIDAD: HUIR
#  Huir no es "correr con un bicho al lado": es ABRIR HUECO con uno que te esta persiguiendo a TI.
#  La diferencia importa, porque lo primero se farmea trivialmente dandole vueltas alrededor.
#
#  La regla es una MARCA DE AGUA: se guarda la mayor distancia que le has sacado al perseguidor en
#  esta misma persecucion y solo se cobra lo que la SUPERA. De ahi salen las dos garantias:
#   - Dar vueltas en circulo: la distancia oscila pero nunca bate el record -> no paga nada.
#   - Yo-yo (dejarse alcanzar y volver a huir): el tramo ya cobrado no se vuelve a pagar, porque
#     el record NO se reinicia mientras el mismo bicho te siga persiguiendo.
#  El techo lo pone el propio bicho: al pasar de su lose_range te pierde y la persecucion acaba.
#
#  Y hay que estar CORRIENDO: huir andando no es huir. Eso ademas lo cose con el aguante, que se
#  gasta justo cuando tienes a alguien dentro de _PELIGRO_RANGE.
#
#  Lo que se cobra tiene DOS ejes que se multiplican, y no hay que confundirlos:
#   - CONTRA QUE huyes: Game.reto(poder, nivel) del perseguidor (hasta x5). Un bicho de un nivel
#     por debajo del tuyo te mide contra tu poder de por vida, o sea que no da casi nada: es lo
#     que impide farmear el piso 1 cuando ya has ascendido.
#   - CUANTO TE COSTO: Game.huida_dificultad_mult(vel_del_bicho, tu_velocidad_real). Dejar atras a
#     un lento siendo un rayo no entrena; despegarte de uno que te pisa los talones, si.
#
#  Y lo cobra el GRUPO ENTERO, cada uno con SU reto: corriendo va todo el mundo y el aguante lo
#  pagan todos, asi que la Agilidad no puede quedarsela el que va en cabeza.
# ============================================================

func _tick_huida() -> void:
	# ¿Nos sigue persiguiendo el mismo? (O(1): no hace falta barrer el grupo entero.)
	if _huida_perseguidor != null and (not is_instance_valid(_huida_perseguidor) \
			or _huida_presa == null or not is_instance_valid(_huida_presa) \
			or not _huida_perseguidor.persigue_a(_huida_presa)):
		_reset_huida()

	# Sin perseguidor, buscamos uno nuevo, pero solo si estamos corriendo (es cuando puede pagar).
	if _huida_perseguidor == null:
		if movement_mode != 2:
			return
		var par: Array = _perseguidor()
		var nuevo: Node2D = par[0]
		if nuevo == null:
			return
		_huida_perseguidor = nuevo
		_huida_presa = par[1]
		# El record arranca en la distancia ACTUAL: lo que ya tenias de ventaja no se te paga.
		_huida_record = _dist_huida()
		_huida_acum = 0.0
		return

	# Solo se cobra corriendo, y solo el hueco que bate el record.
	if movement_mode != 2:
		return
	var d: float = _dist_huida()
	if d < 0.0:
		return
	if d <= _huida_record:
		return
	_huida_acum += d - _huida_record
	_huida_record = d
	if _huida_acum < _HUIDA_TICK:
		return
	# Lo que COSTO la fuga (velocidad del bicho contra la tuya real) multiplica la base; el reto por
	# poder del enemigo va aparte y dice contra QUE huias. Son los dos ejes y se acumulan.
	var vel_bicho: float = 0.0
	if _huida_perseguidor.has_method("vel_persecucion"):
		vel_bicho = _huida_perseguidor.vel_persecucion()
	var poder: float = _poder_enemigo_nodo(_huida_perseguidor)
	var nivel: int = _nivel_enemigo_nodo(_huida_perseguidor)
	while _huida_acum >= _HUIDA_TICK:
		_huida_acum -= _HUIDA_TICK
		# Entrena el GRUPO ENTERO, no solo el lider: huir corre todo el mundo y el aguante lo pagan
		# los tres (ver _tick_aguante_companeros), asi que seria absurdo que la Agilidad se la
		# quedara el que va delante. Mismo criterio que el combate, que ya reparte por persona.
		#
		# Y los DOS ejes se calculan para CADA UNO:
		#   - el RETO, contra su propio poder: al mas flojo el mismo bicho le exige mas.
		#   - la DIFICULTAD, contra SU velocidad maxima real y no la del grupo. El grupo va al paso
		#     del lider, pero eso es prestado: al que va arrastrado esta misma fuga le habria
		#     costado la vida yendo solo, y es lo que tiene que aprender. Si se midiera con la
		#     velocidad del grupo, llevar de lider a un rayo le robaria el aprendizaje a los demas.
		for pj in Game.party:
			var base_pj: float = Game.GAIN_AGILIDAD_HUIDA \
				* Game.huida_dificultad_mult(vel_bicho, _vel_carrera_de(pj))
			Game.ganar("agilidad", Game.reto(poder, nivel, pj), base_pj, Game.RETO_MAX_FISICO, pj)


# Velocidad de carrera que tendria ESTE personaje si fuera el que marca el paso. No es a la que se
# mueve ahora (el grupo va al ritmo del lider): es SU tope real, con su Agilidad y su armadura. La
# carga si es comun a todos, porque la mochila es una sola.
func _vel_carrera_de(pj: PersonajeData) -> float:
	return walk_speed * run_multiplier \
		* Game.agilidad_speed_mult(pj) \
		* Game.armor_speed_mult(pj) \
		* Game.overload_speed_factor()


# Olvida la persecucion en curso. Se llama al perderla y, MUY importante, en los teletransportes:
# un salto de posicion (cambiar de lider, bajar de piso) dispararia el hueco de golpe y regalaria
# excelia por algo que no has corrido.
# Version publica: la llama Game al SALIR de un combate. En multi el mundo sigue vivo mientras
# peleas, asi que la distancia al perseguidor puede haber dado un salto que no has corrido tu.
func reset_huida() -> void:
	_reset_huida()


func _reset_huida() -> void:
	_huida_perseguidor = null
	_huida_presa = null
	_huida_record = 0.0
	_huida_acum = 0.0


# El enemigo que persigue a ALGUIEN DEL GRUPO, y a quien persigue: [enemigo, presa]. [null, null] si
# ninguno. Cuenta el grupo ENTERO y no solo el lider: la Excelia de la huida ya se reparte entre
# todos (ver _tick_huida), asi que si el bicho va a por el que llevas detras estais huyendo igual.
# Antes solo miraba persigue_a(self) y por eso huir de algo que perseguia a un companero no pagaba
# NADA, aunque acabaras en combate con el.
func _perseguidor() -> Array:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (is_instance_valid(e) and e.has_method("persigue_a")):
			continue
		if e.persigue_a(self):
			return [e as Node2D, self as Node2D]
		for c in get_tree().get_nodes_in_group("aliado"):
			if c == self or not is_instance_valid(c) or not (c is Node2D):
				continue
			# MULTIJUGADOR: los cuerpos de OTROS JUGADORES estan en "aliado" (para que los bichos
			# los persigan, hito 5.4), pero su huida es SUYA: si contaran aqui, entrenarias
			# Agilidad porque a tu compañero lo persiguen. Solo cuentan tus acompañantes.
			if c.has_meta("peer_id"):
				continue
			if e.persigue_a(c):
				return [e as Node2D, c as Node2D]
	return [null, null]


# La distancia que de verdad manda: la que hay entre el bicho y LA PRESA que persigue (que puede ser
# un companero, no tu). Si midiera siempre desde el lider, correr tu mientras el bicho alcanza al de
# atras contaria como "abrir hueco", que es justo lo contrario de lo que pasa.
func _dist_huida() -> float:
	if _huida_presa == null or not is_instance_valid(_huida_presa) \
			or _huida_perseguidor == null or not is_instance_valid(_huida_perseguidor):
		return -1.0
	return _huida_presa.global_position.distance_to(_huida_perseguidor.global_position)


# Lo que un bicho "oye" de mi: mi velocidad de verdad + el ruido que estoy haciendo por otras vias
# (cantar, un conjuro que revienta). Lo pregunta enemy._detecta_a; quien no tenga este metodo (un
# companero, el avatar de otro humano) sigue midiendose solo por su velocidad, como siempre.
func ruido_oido() -> float:
	return velocity.length() + ruido_extra + _ruido_pico


# Un ruido de GOLPE que se desinfla en 'segundos' (el estallido de un conjuro fallido). No se suma
# al que hubiera: se queda el mas fuerte, que es como funciona un ruido de verdad — dos petardazos
# seguidos no suenan al doble, suena el gordo.
func hacer_ruido(cuanto: float, segundos: float) -> void:
	if cuanto <= _ruido_pico:
		return
	_ruido_pico = cuanto
	_ruido_pico_dur = maxf(0.01, segundos)
	_ruido_pico_t = _ruido_pico_dur


# Desinfla el pico de ruido. Se llama desde _physics_process.
func _tick_ruido(delta: float) -> void:
	if _ruido_pico_t <= 0.0:
		return
	_ruido_pico_t -= delta
	if _ruido_pico_t <= 0.0:
		_ruido_pico = 0.0
		_ruido_pico_t = 0.0
		return
	# Baja en rampa: el estallido se apaga, no se corta de cuajo.
	_ruido_pico *= _ruido_pico_t / maxf(_ruido_pico_t + delta, 0.001)


# ¿Hay linea de vision LIBRE (sin pared) entre el jugador y 'punto'? Mismo patron que el enemigo
# (Enemy._linea_de_vision_libre): un rayo con la mascara de la ROCA. Se excluye a todo el grupo
# porque el jugador y los companeros COMPARTEN capa con la roca; sin excluirlos, el rayo chocaria
# consigo mismo o con un aliado y creeria que hay pared donde no la hay.
#
# ve_a() es lo mismo pero PUBLICO: lo pregunta el panel del canto desde otro archivo (para bloquear
# el recitado si el bicho se te mete detras de un muro) y no tiene por que llamar a un _privado.
func ve_a(punto: Vector2) -> bool:
	return _vision_libre(punto)


func _vision_libre(punto: Vector2) -> bool:
	var espacio: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, punto, CAPA_ROCA)
	query.exclude = _excluir_del_rayo()
	return espacio.intersect_ray(query).is_empty()


# Cuerpos que el rayo de vision NUNCA debe tomar por pared: todo el grupo (grupo "aliado" = lider
# + companeros), que comparte capa con la roca. Los enemigos no estan en CAPA_ROCA, asi que el
# rayo ya no los ve: solo detecta muros.
func _excluir_del_rayo() -> Array[RID]:
	var out: Array[RID] = []
	for n in get_tree().get_nodes_in_group("aliado"):
		if n is CollisionObject2D:
			out.append((n as CollisionObject2D).get_rid())
	return out


# Enemigo VIVO mas cercano y a que distancia esta: [Node, float]. Sin nadie cerca devuelve
# [null, INF]. Se barre UNA vez por frame y el resultado lo comparten los dos radios que lo
# necesitan (el aguante con _PELIGRO_RANGE y la Excelia de Agilidad con _AGILIDAD_RANGE), que
# antes hacian su propia pasada. Los cadaveres no cuentan: enemy.morir() los saca del grupo.
func _enemigo_mas_cercano() -> Array:
	var best: float = INF
	var nearest: Node = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	return [nearest, best]


# Poder de un enemigo (suma de habilidades segun su 't') para el "reto".
func _poder_enemigo_nodo(e: Node) -> float:
	if e == null or not is_instance_valid(e) or e.data == null:
		return 0.0
	var t: float = 0.5
	if "current_t" in e:
		t = e.current_t
	return float(e.data.suma_habilidades(t))


# NIVEL (tier de contenido) de un enemigo del mapa. Game.reto() lo necesita para saber contra que
# medirte: el progreso de tu nivel actual, o el acumulado de por vida si el bicho es de uno anterior.
func _nivel_enemigo_nodo(e: Node) -> int:
	if e == null or not is_instance_valid(e) or e.data == null:
		return 1
	return e.data.level


# TODO lo que hace el boton de atacar, que ya no es una sola cosa:
#
#   TOQUE CORTO  -> el ataque de siempre (entrar en combate cuerpo a cuerpo).
#   MANTENER 1 s -> si llevas baston o varita, sacas tus hechizos y recitas AHI MISMO (casteo_mapa).
#
# El flanco de pulsacion NO ha cambiado de sitio a proposito: el ataque cuerpo a cuerpo sigue
# saliendo en el instante en que pulsas, no al soltar. Si se esperara a saber si es toque o
# mantenido, pegar se sentiria con medio segundo de retraso — y contra una embestida eso es la
# diferencia entre entrar tu o entrar el.
#
# Solo si el flanco NO ha entrado en combate empieza a contar el mantenido: teniendo al bicho
# pegado, la pulsacion ya se ha gastado en pegarle.
const CASTEO_MANTENER := 1.0   # segundos aguantando el boton para sacar los hechizos

func _tick_ataque(delta: float) -> void:
	var atk: bool = Input.is_action_pressed(&"atacar")
	# Mientras recitas, el boton no hace nada mas: las frases se tocan en la banda de abajo.
	if is_instance_valid(_casteo):
		_attack_was = atk
		_atk_hold = 0.0
		return
	if atk and not _attack_was:
		_atk_hold = 0.0
		# EL ESPADAZO SE VE AUNQUE NO ACIERTE, y ese es justo el caso que importa: si acierta, el
		# combate se lleva la escena y no da tiempo a ver nada. Golpear al aire, en cambio, es lo que
		# el jugador necesita distinguir de "el boton no ha respondido" -- que era exactamente la
		# queja que llevo a que este boton avise por texto cuando el bicho esta lejos.
		_golpe_t = DUR_GOLPE
		if not _try_attack():
			_atk_buffer = ATK_BUFFER
			# Toque corto a distancia de CONJURO: no ha llegado el espadazo, pero algo se puede
			# hacer. Se dice, que si no el boton esta encendido y parece que no responde.
			if hay_conjuro_a_tiro():
				_toast("Está lejos: MANTÉN para recitar un hechizo.")
		else:
			_atk_hold = -1.0   # ya ha entrado en combate: este mantenido no cuenta
	elif atk and _atk_hold >= 0.0:
		_atk_hold += delta
		if _atk_hold >= CASTEO_MANTENER:
			_atk_hold = -1.0   # un canto por pulsacion: hay que soltar y volver a mantener
			_abrir_casteo()
	if not atk:
		_atk_hold = 0.0
	# El ESPACIO que no encontro a nadie se RECUERDA y se reintenta (ver ATK_BUFFER). Ojo: esto corre
	# tambien mientras mantienes, y es lo que quieres — si el bicho llega hasta ti a mitad del
	# mantenido, le pegas y el canto no llega a abrirse.
	if not (atk and not _attack_was) and _atk_buffer > 0.0:
		_atk_buffer -= delta
		if _try_attack():
			_atk_buffer = 0.0
			_atk_hold = -1.0
	_attack_was = atk


# Busca un enemigo VIVO justo enfrente y muy cerca; si lo hay, inicia el combate
# con NUESTRA iniciativa. Devuelve true si ataco (lo usa _try_interact para saber
# si ya ha consumido la pulsacion de F).
func _try_attack() -> bool:
	var candidatos: Array = _enemigos_a_tiro()
	for par in candidatos:
		var e = par[1]
		if not e.has_method("atacado_por_jugador"):
			continue
		# El resultado MANDA. Antes esto era `e.atacado_por_jugador(); return true`, o sea que la
		# pulsacion se daba por gastada aunque el otro lado no hubiera hecho NADA (el caso tipico: un
		# espejo que se niega). Y como se salia del bucle, ni se probaba el siguiente: por eso "entrar
		# en una pelea ya empezada" obligaba a recolocarse y repulsar hasta acertar.
		if bool(e.atacado_por_jugador()):
			return true
	# Habia bichos a tiro pero ninguno ha admitido la pelea: decirlo. Callarse era lo que dejaba al
	# jugador pensando que estaba mal colocado.
	if not candidatos.is_empty():
		_avisar_no_puedo_entrar()
	return false


# Los enemigos a los que PODRIA pegar ahora mismo, ORDENADOS del mas cercano al mas lejano, como
# [hueco, nodo]. El orden importa: antes se cogia el primero de get_nodes_in_group("enemy"), que va en
# un orden arbitrario, asi que con 2-5 bichos apelotonados (o sea, en cualquier pelea) le pegabas al
# que no querias.
# 'alcance' = de centro a centro, como attack_range (el filtro real es el HUECO, que le resta los
# dos medios cuerpos). Se le pasa otro numero para el CANTO, que llega mucho mas lejos que un
# espadazo: el filtro (hueco + cono + pared) tiene que ser el mismo, solo cambia la distancia.
func _enemigos_a_tiro(alcance: float = -1.0) -> Array:
	var rango: float = alcance if alcance > 0.0 else attack_range
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - global_position
		var dist: float = to_e.length()
		if dist <= 0.01:
			continue
		# El alcance se mide por el HUECO entre los dos cuerpos, no entre sus centros: dos
		# cuadrados de 32x32 tocandose POR LA ESQUINA tienen los centros a 45.2 px, o sea mas
		# de lo que era attack_range (44) -> estabas pegado al slime y no podias pegarle. Con un elite
		# (1.6x de tamaño) la esquina son ~59 px: era intocable en diagonal. Ver enemy.hueco_hasta().
		var hueco: float = _hueco_hasta(e)
		# 'rango' es de CENTRO A CENTRO y 'hueco' es entre cuerpos, asi que hay que descontar los dos
		# medios cuerpos para poder compararlos. Va con MEDIO_CUERPO.x y no con un 32 escrito a mano
		# como estaba: escrito a mano, el dia que cambie el cuerpo del jugador este filtro se queda
		# con el numero viejo y el alcance del espadazo se desplaza sin que nadie lo pida.
		if hueco > rango - (PoseJugador.MEDIO_CUERPO.x + 16.0):
			continue
		# El CONO sigue mandando: atacar exige mirar al bicho, es una accion deliberada.
		if absf(_facing.angle_to(to_e / dist)) > deg_to_rad(attack_half_angle_deg):
			continue
		# PARED EN MEDIO. Con los 12 px de hueco de antes daba igual; con 68 es de lo mas normal tener
		# un muro entre los dos, y encender el boton ahi seria prometer una pelea que no existe.
		# Va el ULTIMO porque es lo unico que cuesta (un rayo): el hueco y el cono ya han descartado a
		# casi todos. Y solo se pregunta FUERA del cuerpo a cuerpo de siempre: si el bicho esta
		# encima, se acepta sin rayo — asi el alcance nuevo es el unico que paga la comprobacion y no
		# hay forma de que un corte raro del rayo estropee lo que hoy ya funciona.
		if hueco > HUECO_CUERPO_A_CUERPO and not _vision_libre(e.global_position):
			continue
		out.append([hueco, e])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


# ¿Tengo la intencion de atacar a ESTE bicho ahora mismo? La pregunta el enemigo antes de abrirse la
# pelea a su nombre: si yo tenia el espacio puesto y le estaba mirando, el CONTRA es mio y la
# iniciativa (media barra de ATB) tambien, aunque su carga haya llegado antes en este frame.
# Golpear una embestida es leer el telegrafiado, no ganar una carrera de frames.
func quiere_atacarme(bicho: Node) -> bool:
	if _atk_buffer <= 0.0 or bicho == null or not is_instance_valid(bicho):
		return false
	for par in _enemigos_a_tiro():
		if par[1] == bicho:
			return true
	return false


# ============================================================
#  RECITAR UN HECHIZO EN EL MAPA (mantener el boton de atacar)
# ------------------------------------------------------------
# Es la forma que tiene un mago de ABRIR la pelea: recitas aqui fuera y, si lo cantas entero, el
# conjuro sale disparado. Al impactar se abre el combate con ese bicho como objetivo principal y el
# hechizo se resuelve DENTRO, tal cual. Toda la maquina del recitado vive en casteo_mapa.gd; aqui
# solo estan el "puedo o no" y lo que pasa cuando el conjuro llega.
const CASTEO_MAPA = preload("res://scripts/ui/casteo_mapa.gd")
const PROYECTIL_HECHIZO = preload("res://scripts/actors/player/proyectil_hechizo.gd")

# Hasta donde llega el conjuro. Mucho mas que el espadazo (44): es justo la gracia de ser mago.
# Bajado de 300 tras el playtest — a media pantalla cantabas sin que nada te molestara nunca. Este
# numero manda tambien sobre cuando se enciende el boton en azul (ver hay_conjuro_a_tiro): las dos
# cosas son la misma pregunta y se ajustan de un solo sitio.
const RANGO_CASTEO := 200.0


func _abrir_casteo() -> void:
	if is_instance_valid(_casteo) or Game.combate_activo():
		return
	var pj: PersonajeData = Game.lider()
	if not Game.lleva_arma_magica(pj):
		return   # sin baston ni varita no hay nada que sacar: ni aviso, seria ruido de UI
	if pj.equipped_spells.is_empty():
		_toast("No llevas hechizos equipados.")
		return
	# El objetivo se fija AHORA (el mas cercano dentro del cono, sin pared) y ya no cambia: si
	# pudiera cambiar a media cancion, acabarias lanzandole a otro por haberte girado.
	var candidatos: Array = _enemigos_a_tiro(RANGO_CASTEO)
	if candidatos.is_empty():
		_toast("No hay nada a tiro a lo que lanzarle un conjuro.")
		return
	var objetivo = candidatos[0][1]
	var c: Node = CASTEO_MAPA.new()
	c.setup(pj, self, objetivo)
	c.lanzado.connect(_soltar_conjuro)
	c.fallado.connect(func(_sp, _dano, _muerto) -> void: _casteo = null)
	c.cancelado.connect(func() -> void: _casteo = null)
	add_child(c)
	_casteo = c


# Cantado entero: sale el proyectil hacia el bicho. El mana ya lo cobro el panel.
func _soltar_conjuro(spell: SpellData, objetivo: Node) -> void:
	_casteo = null
	if not is_instance_valid(objetivo):
		return
	var color: Color = Elementos.color(spell.elemento) if Elementos.tiene_color(spell.elemento) \
		else Color(0.75, 0.75, 0.95)
	var p: Node2D = PROYECTIL_HECHIZO.new()
	p.setup(objetivo, color, spell)   # el hechizo decide su FORMA (elemento) y su TAMAÑO (potencia)
	p.global_position = global_position
	# Cuelga del PADRE (el piso), no de mi: si colgara de mi, me seguiria a mi en vez de volar.
	var mundo: Node = get_parent()
	if mundo == null:
		return
	mundo.add_child(p)
	p.impacto.connect(_impacto_conjuro.bind(spell))
	Net.anunciar_conjuro(objetivo, color, spell)   # que se vea volar EL MISMO en las otras pantallas


# El conjuro ha llegado: se abre la pelea a mi nombre (con la iniciativa de siempre) y el hechizo
# queda APUNTADO para que el combate lo resuelva en cuanto se monte, como si lo hubiera lanzado
# dentro. Lo recoge Game.start_combat / unir_aliado_al_combate: los DOS caminos de entrada.
func _impacto_conjuro(objetivo: Node, spell: SpellData) -> void:
	if not is_instance_valid(objetivo) or not objetivo.has_method("atacado_por_jugador"):
		return
	Game.apuntar_hechizo_de_entrada(spell, objetivo, Game.lider())
	if not bool(objetivo.atacado_por_jugador()):
		# No ha admitido la pelea (ya la tiene otro, un espejo que se niega...): el hechizo apuntado
		# se tira, que si no se quedaria esperando a la siguiente pelea que se abriera por lo que
		# fuera y saldria solo de la nada.
		Game.olvidar_hechizo_de_entrada()


# Algo de fuera se lleva el canto por delante (un bicho que me alcanza y abre la pelea). Lo llama
# quien entra en combate.
#
# El conjuro NO se pierde: se apunta por donde iba y la pantalla de combate lo RETOMA en esa misma
# frase (ver Game.apuntar_canto_a_medias). Que te interrumpan a la tercera frase y perderlo todo era
# el peor castigo posible, y encima por algo que no depende de ti.
func interrumpir_casteo() -> void:
	if is_instance_valid(_casteo):
		var a_medias: Dictionary = _casteo.interrumpir()
		if not a_medias.is_empty():
			Game.apuntar_canto_a_medias(a_medias.get("spell"), int(a_medias.get("frase", 0)),
				Game.lider())
	_casteo = null


func _toast(texto: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast(texto)


func _avisar_no_puedo_entrar() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("No puedes entrar en esa pelea ahora mismo.")


# EL BULTO CON EL QUE SE PELEA, no la caja de colision de player.tscn (esa es la HUELLA DE LOS PIES,
# con la que se choca contra los muros). Son dos cosas distintas a proposito: ver la nota de los dos
# cuerpos en pose_jugador.gd, que es donde viven los numeros.
#
# Va como METODO y no como constante porque es lo que pregunta el enemigo (Enemy.hueco_hasta hace
# has_method("medio_cuerpo")): asi el bicho no tiene que saber si lo que tiene delante es el
# jugador, un compañero o el otro humano, solo que sabe decir cuanto ocupa. Lo que no lo sabe decir
# se queda con el cuerpo base de 32x32.
func medio_cuerpo() -> Vector2:
	return PoseJugador.MEDIO_CUERPO


# Hueco entre el cuerpo del jugador y el de 'otro' (0 = tocandose, de lado o de esquina).
# Descuenta lo que sobresale un elite (radio_extra), igual que hace la interaccion con los
# cadaveres en _mas_cercano_en_grupo.
#
# POR EJE, no con un solo numero: el jugador es mas alto que ancho (ver MEDIO_CUERPO) y con una suma
# unica se estaria peleando con un cuadrado que no existe.
func _hueco_hasta(otro: Node) -> float:
	if not (otro is Node2D):
		return INF
	var d: Vector2 = ((otro as Node2D).global_position - global_position).abs()
	var extra: float = float(otro.radio_extra) if "radio_extra" in otro else 0.0
	# medio jugador + medio bicho (16, el cuerpo base) + lo que sobresale el elite
	var suma: Vector2 = PoseJugador.MEDIO_CUERPO + Vector2(16.0 + extra, 16.0 + extra)
	return maxf(d.x - suma.x, d.y - suma.y)


# INTERACTUAR (F). El orden NO es por distancia entre categorias, es por lo EFIMERO que es cada
# cosa: primero lo que se te puede escapar, y al final lo que va a seguir ahi dentro de una hora.
#   1) NPC interactuable (altar, tienda, puerta, escalera, hogar).
#   2) EXTRAER el cristal de un cadaver  -> se pudre (ver Enemy.CADAVER_SEGUNDOS).
#   3) RECOGER un item del suelo         -> es lo que acaba de soltar el bicho.
#   4) RECOLECTAR una veta o una planta  -> no se va a ningun sitio.
#
# El pickup subio por delante del recolectable despues de un playtest: matabas un bicho en la orilla
# del estanque y la F abria la caña de pescar en vez de coger tu propio loot, porque el charco es un
# "recolectable" enorme que gana la medida de cercania casi siempre. Mismo motivo por el que el
# cadaver iba ya delante: lo perecedero primero.
#
# ATACAR ya NO esta aqui: tiene su propia tecla (ESPACIO). Asi, acercarte a lootear con un
# bicho al lado no te mete en un combate que no habias pedido.
# Si hay ALGO a mano con lo que interactuar (lo mismo que mira _try_interact). Lo pregunta la barra
# tactil para encender o apagar su boton de interactuar.
#
# Empezo siendo una sola funcion que decidia POR TI cual de las dos cosas hacer (tocar si habia algo,
# pegar si no). Sonaba bien y jugando era malo: con un cadaver o una veta al lado, el boton no
# atacaba nunca y entrar en combate se volvia un baile. Ahora son dos botones y dos preguntas, y cada
# uno se apaga cuando no tiene nada que hacer, que se ve de un vistazo y no hay que adivinarlo.
func hay_algo_que_tocar() -> bool:
	return _mas_cercano_en_grupo("interactable", false) != null \
		or _mas_cercano_en_grupo("corpse", true) != null \
		or _mas_cercano_en_grupo("pickup", false) != null \
		or _mas_cercano_en_grupo("recolectable", false, "estanque") != null \
		or _mas_cercano_en_grupo("estanque", false) != null


func hay_enemigo_a_tiro() -> bool:
	return not _enemigos_a_tiro().is_empty()


# ¿Hay alguien a quien pueda CANTARLE un hechizo desde aqui? Es el alcance LARGO, y solo cuenta si
# llevas baston o varita y tienes hechizos equipados: es lo que hace que a un mago el boton se le
# encienda mucho antes que a un espadachin, que es justo la gracia.
func hay_conjuro_a_tiro() -> bool:
	var pj: PersonajeData = Game.lider()
	if not Game.lleva_arma_magica(pj) or pj.equipped_spells.is_empty():
		return false
	return not _enemigos_a_tiro(RANGO_CASTEO).is_empty()


# LO QUE DECIDE SI EL BOTON DE ATACAR ESTA ENCENDIDO. No es lo mismo que "puedo dar un espadazo":
# con un arma magica, a media pantalla ya puedes hacer algo (mantener y cantar), y el boton tiene
# que decirtelo. Ademas es NECESARIO: un boton apagado no acepta ni el mantenido (ver
# touch_controls._conectar_mantener), asi que con esto apagado era literalmente imposible ponerse a
# recitar en el movil — te encendia a distancia de espadazo, y ahi la pulsacion ya se va en el
# espadazo.
func hay_algo_que_atacar() -> bool:
	return hay_enemigo_a_tiro() or hay_conjuro_a_tiro()


# ¿Se ha quedado sin fuelle el que marca el paso? Lo mira la barra tactil para apagar el boton de
# correr: el codigo ya deja de correr solo, pero el boton se quedaria hundido diciendo que corres.
func sin_fuelle() -> bool:
	return _exhausted or _pj_agotado() != null


func _try_interact() -> void:
	# 1) NPCs interactuables (altar, tienda, puerta, etc).
	var interactable: Node = _mas_cercano_en_grupo("interactable", false)
	if interactable != null and interactable.has_method("interact_with_player"):
		interactable.interact_with_player()
		return

	# 2) Cadaver para extraer.
	var corpse: Node = _mas_cercano_en_grupo("corpse", true)
	if corpse != null:
		Game.start_extraction(corpse)
		return

	# 3) Item del suelo para recoger (lo que solto el monstruo, o algo que tiraste tu).
	var pickup: Node = _mas_cercano_en_grupo("pickup", false)
	if pickup != null and pickup.has_method("recoger"):
		# MULTIJUGADOR: un drop replicado (con net_id) no se coge a pelo: se le PIDE al host,
		# que arbitra la carrera (el primero se lo lleva; a los demas, silencio). El item
		# llegara por Net._recoger_concedido -> Game.embolsar si me lo dan.
		if Net.activo and pickup.has_meta("net_id"):
			Net.solicitar_recoger(pickup.get_meta("net_id"))
			return
		Game.embolsar(pickup.recoger())
		return

	# 4) Veta o planta: abre su minijuego (pico -> Fuerza, hoz -> Destreza).
	# El ESTANQUE va el ultimo de los ultimos: ocupa 5x4 celdas y mide la distancia desde su BORDE
	# (radio_extra), asi que a igualdad de cercania le gana a cualquier veta de la sala. Se busca
	# primero entre todo lo demas y solo se cae al agua si de verdad no hay otra cosa a mano.
	var reco: Node = _mas_cercano_en_grupo("recolectable", false, "estanque")
	if reco == null:
		reco = _mas_cercano_en_grupo("estanque", false)
	if reco != null and reco.has_method("interactuar"):
		reco.interactuar()


# Recoloca al jugador (lo usa el generador del piso para plantarte en la sala de
# entrada, que cambia con cada mapa). Olvida la persecucion en curso: un
# teletransporte NO es huir y no debe contar como excelia.
func recolocar(pos: Vector2) -> void:
	global_position = pos
	_reset_huida()
	# EL SEQUITO VIENE CONTIGO. Esto no es un detalle: los companeros son cuerpos con colision, y
	# el rastro que traian apunta al sitio del que acabas de salir. Sin rehacerlo aqui se quedaban
	# plantados donde nace el jugador en la escena -que en la mazmorra es roca maciza-, sin poder
	# salir de la piedra ni volver a la fila: bajabas al piso y te encontrabas solo.
	if _sequito != null and _sequito.has_method("teletransportar"):
		_sequito.teletransportar()
	# La camara va suavizada: sin esto, al plantarte en el piso nuevo se vendria detras
	# haciendo una panoramica de media mazmorra en vez de estar YA donde estas.
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam != null:
		cam.reset_smoothing()


# Ignora ESPACIO y F hasta que las SUELTES. Hace falta porque esas mismas pulsaciones pueden
# venir de cerrar otra pantalla: bajar de piso es pulsar F, y el minijuego de extraccion se
# juega a ESPACIAZOS. Sin esto, el ultimo espacio del minijuego te lanzaria contra el bicho
# que tengas al lado nada mas volver al mapa.
func bloquear_interaccion() -> void:
	_interact_was = true
	_attack_was = true


# Devuelve el nodo mas cercano del grupo dentro del rango de interaccion.
# Si skip_extracted, ignora los cadaveres ya extraidos.
# Si excluir != "", se salta los nodos que ademas esten en ESE grupo (lo usa la F para dejar el
# estanque fuera del reparto de "recolectable" y probarlo aparte, al final).
func _mas_cercano_en_grupo(grupo: String, skip_extracted: bool, excluir: String = "") -> Node:
	var nearest: Node = null
	var best: float = INF
	for n in get_tree().get_nodes_in_group(grupo):
		if not is_instance_valid(n):
			continue
		if excluir != "" and n.is_in_group(excluir):
			continue
		if skip_extracted and "extracted" in n and n.extracted:
			continue
		# MULTIJUGADOR: un cuerpo que ya esta trabajando tu compañero no es un objetivo valido. Sin
		# esto, los dos juntos con dos cuerpos al lado apuntaban al MISMO (el mas cercano de cada uno)
		# y el segundo se comia un "esta ocupado" creyendo que iba al otro cuerpo. Ahora se salta y la
		# F cae en el siguiente, que es lo que el jugador creia estar haciendo.
		if skip_extracted and n.has_meta("net_id") and Net.cuerpo_ocupado_por_otro(n.get_meta("net_id")):
			continue
		# Los cuerpos GRANDES (elites) te empujan mas lejos de su centro con su propia
		# colision, asi que descontamos lo que sobresalen: la distancia se mide contra el
		# BORDE del bicho, no su centro. Tamaño normal -> radio_extra 0 (nada cambia).
		var extra: float = float(n.radio_extra) if "radio_extra" in n else 0.0
		var d: float = maxf(0.0, global_position.distance_to(n.global_position) - extra)
		if d <= interact_range and d < best:
			best = d
			nearest = n
	return nearest


# Crea la CAPA donde viven las columnas de barras (arriba a la izquierda). Va en su propia
# CanvasLayer para que no la mueva la camara. Las columnas las monta _rehacer_barras (una por
# personaje) cuando el grupo ya esta listo.
func _crear_capa_barras() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_barras_layer = layer
	# LA FILA SE AJUSTA A LA VENTANA. Con cuatro companeros la fila mide ~850 px, asi que en una
	# ventana pequeña se metia debajo de la botonera y se solapaba todo. En vez de recortar lo que
	# se enseña, la fila entera se ENCOGE hasta caber: se ve mas pequeña, pero se ve TODA y no pisa
	# nada. Hay que rehacerlo cada vez que cambia el tamaño de la ventana.
	get_viewport().size_changed.connect(_ajustar_escala_fila)


# Cuanto hay que encoger la fila del grupo para que quepa entre el borde izquierdo y la botonera.
# 1.0 = cabe entera. Nunca agranda (no tiene sentido inflar la interfaz en un monitor grande).
#
# OJO CON LAS UNIDADES: el proyecto estira por 'canvas_items' con aspecto 'expand', asi que el ancho
# LOGICO nunca baja de los 1280 de referencia —el motor ya encoge la ventana entera por su cuenta—
# y aqui se mide en logico. O sea que esto NO salta por cambiar de resolucion, salta por el TAMAÑO
# DEL GRUPO, que es lo que de verdad hacia desbordar la fila: con cuatro companeros y los botones
# grandes de antes, la fila pedia 1280 justos y las tarjetas se metian debajo de la botonera.
#
# Hoy, con PARTY_MAX = 4 y los botones de escritorio, la fila pide ~1227 de 1280: cabe, y esto se
# queda de RED DE SEGURIDAD para el dia que crezca el grupo, la columna o la botonera. El suelo es
# bajo a proposito: entre "se lee pequeño" y "se solapa", lo segundo no es aceptable.
const ESCALA_FILA_MIN := 0.35

func escala_fila() -> float:
	var vp: Viewport = get_viewport()
	if vp == null:
		return 1.0
	var disponible: float = float(vp.get_visible_rect().size.x) - Hud.ancho_botonera() - X_COL_BARRAS
	# Lo que ocupa TODO: una columna por miembro del grupo mas la mochila del HUD detras.
	var necesario: float = x_columna(maxi(Game.party.size(), 1)) + Hud.LADO_MOCHILA + 8.0
	if necesario <= 0.0:
		return 1.0
	return clampf(disponible / necesario, ESCALA_FILA_MIN, 1.0)


# Aplica esa escala a la capa de barras y le pide al HUD que recoloque la mochila, que va detras de
# la ultima columna y tiene que encogerse con ellas.
func _ajustar_escala_fila() -> void:
	if _barras_layer == null:
		return
	var f: float = escala_fila()
	_barras_layer.scale = Vector2(f, f)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("recolocar"):
		hud.recolocar()


# Crea un Label centrado que cubre toda la barra, para pintar el numero DENTRO.
# Con outline oscuro para leerse sobre cualquier color de relleno.
func _crear_label_barra(bar: ProgressBar, tam: int = 11) -> Label:
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


# Refresca TODAS las columnas (vida, aguante y mana de cada miembro del grupo). Se llama cada
# frame. Sirve tanto explorando como con el inventario abierto (la vida sube con la cura de
# pociones, el aguante se recupera con el tiempo...).
func _refrescar_barras() -> void:
	# El aguante y el cansancio del LIDER viven en las variables vivas (current_stamina/_exhausted)
	# porque los usa el movimiento; aqui se vuelcan a SU ficha para que (a) su columna se pinte con
	# el mismo codigo que las demas y (b) el valor persista al cambiar de piso o de escena.
	if _pj_actual != null:
		_pj_actual.stamina = current_stamina
		_pj_actual.set_meta("sin_fuelle", _exhausted)
	for fila in _barras:
		var pj: PersonajeData = fila["pj"]
		var maxhp_c: float = Game.player_max_hp(pj)
		var hp_c: float = Game.player_hp(pj)
		(fila["hp"] as ProgressBar).max_value = maxf(1.0, maxhp_c)
		(fila["hp"] as ProgressBar).value = hp_c
		(fila["hp_lbl"] as Label).text = "%.1f/%.1f" % [hp_c, maxhp_c]
		var en_bar: ProgressBar = fila["en"]
		var maxen_c: float = _calc_max_aguante(pj)
		var en_c: float = _aguante_de(pj)
		en_bar.max_value = maxf(1.0, maxen_c)
		en_bar.value = en_c
		# Rojiza cuando ese se ha quedado sin fuelle (el lider por _exhausted, via el meta de arriba).
		en_bar.self_modulate = Color(1.0, 0.4, 0.4) if bool(pj.get_meta("sin_fuelle", false)) \
			else Color(0.4, 1.0, 0.5)
		(fila["en_lbl"] as Label).text = "%.0f/%.0f" % [en_c, maxen_c]
		var mp_bar: ProgressBar = fila["mp"]
		var maxmp_c: float = Game.player_max_mp(pj)
		var mp_c: float = Game.player_mp(pj)
		mp_bar.max_value = maxf(1.0, maxmp_c)
		mp_bar.value = mp_c
		(fila["mp_lbl"] as Label).text = "%.2f/%.2f" % [mp_c, maxmp_c]
		# Los estados que lleva encima fuera del combate (y las cargas de Foco), como chips.
		#
		# Esto corre en CADA FRAME y los chips son nodos, asi que se comparan primero por su FIRMA
		# (el texto ya montado, que lleva dentro lo que le queda a cada estado): solo se reconstruyen
		# cuando de verdad cambia algo, o serian sesenta reconstrucciones por segundo para pintar lo
		# mismo. Los estados solo cambian cada SEG_POR_TURNO_FUERA, asi que casi siempre no hay nada
		# que hacer aqui.
		# El cuadro de equipo (armadura / armas y su desgaste). Se refresca con el mismo criterio que
		# los chips: el se guarda su propia firma y solo se repinta si algo ha cambiado de verdad.
		var eq = fila.get("equipo")
		if eq != null and is_instance_valid(eq):
			eq.refrescar()
		var caja: HBoxContainer = fila["estados"]
		var firma: String = Game.etiqueta_estados(pj)
		if firma != String(fila["estados_firma"]):
			fila["estados_firma"] = firma
			for viejo in caja.get_children():
				viejo.queue_free()
			for chip in Game.chips_estados(pj):
				caja.add_child(StatusChip.crear(String(chip[0]), chip[3] as Color, String(chip[1])))


# Bebe la PRIMERA poción del inventario (tecla Q, fuera de combate). Arranca la
# cura-por-tiempo de Game (no hace nada si no tienes pociones o ya estas a tope).
func _beber_pocion() -> void:
	# Q = recuperación óptima (auto). Para ELEGIR una poción concreta, abre el inventario (I).
	Game.beber_optima()
