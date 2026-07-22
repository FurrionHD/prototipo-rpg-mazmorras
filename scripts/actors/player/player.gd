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

# Direccion a la que "mira" el jugador (ultimo movimiento), para atacar.
var _facing: Vector2 = Vector2.DOWN

# Ataque cuerpo a cuerpo para INICIAR combate (corto alcance hacia delante).
@export var attack_range: float = 44.0
@export var attack_half_angle_deg: float = 70.0

# Interaccion (F) con cadaveres para extraer el cristal.
@export var interact_range: float = 40.0
var _interact_was: bool = false
var _attack_was: bool = false   # antirrebote de ESPACIO (atacar)

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

var _drink_was: bool = false   # antirebote de la tecla Q (beber pocion)
# Antirebote de las teclas 1/2/3 (cambiar de lider), una por posicion del equipo. La 0 no se usa:
# la tecla 1 es "el que ya va en cabeza" y no hace nada, pero se deja el hueco para que el indice
# del array sea el mismo que el de Game.party y no haya que restar 1 en ningun sitio.
var _lider_was: Array[bool] = [false, false, false, false]

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


func _ready() -> void:
	# "aliado" = la lista de objetivos que mira el enemigo. El lider entra en ella igual que los
	# companeros (companion.gd), asi que el bicho no tiene que distinguir quien lleva la corona:
	# va a por el que tenga mas a mano.
	add_to_group("aliado")
	_crear_capa_barras()
	add_child(preload("res://scripts/ui/hud.gd").new())  # HUD (barras, peso, piso, ayudas)
	add_child(preload("res://scripts/ui/inventory_menu.gd").new())  # inventario (I)
	add_child(preload("res://scripts/ui/craft_menu.gd").new())      # boticaria (F sobre el NPC)
	add_child(preload("res://scripts/ui/shop_menu.gd").new())       # tienda (F sobre el tendero)
	add_child(preload("res://scripts/ui/forge_menu.gd").new())      # herrero (F sobre el NPC)
	var _carpinteria_menu := preload("res://scripts/ui/forge_menu.gd").new()  # carpintero: mismo menu, modo distinto
	_carpinteria_menu.modo = "carpintero"                          # fijar ANTES de add_child: _ready ya lo lee
	add_child(_carpinteria_menu)                                   # carpintero (F sobre el NPC)
	add_child(preload("res://scripts/ui/tannery_menu.gd").new())    # peletero (F sobre el NPC)
	add_child(preload("res://scripts/ui/tavern_menu.gd").new())     # taberna: contratar (F sobre el NPC)
	add_child(preload("res://scripts/ui/home_menu.gd").new())       # hogar: equipo + almacen (F sobre el NPC)
	add_child(preload("res://scripts/ui/floor_select_menu.gd").new())  # elegir piso (puerta de la mazmorra)
	add_child(preload("res://scripts/ui/character_menu.gd").new())  # menu de personaje (C)
	add_child(preload("res://scripts/ui/map_menu.gd").new())        # mapa del piso (M)
	add_child(preload("res://scripts/ui/altar_menu.gd").new())      # menu del altar (F sobre el altar)
	add_child(preload("res://scripts/ui/desarrollo_menu.gd").new()) # selector de desarrollo (subir de nivel)
	add_child(preload("res://scripts/ui/debug_panel.gd").new())  # panel de debug (cualquier sala)
	add_child(preload("res://scripts/ui/spawner.gd").new())      # spawner de enemigos (dev/test)
	add_child(preload("res://scripts/ui/material_spawner.gd").new())  # spawner de vetas/plantas (dev/test)
	add_child(preload("res://scripts/ui/keys_help.gd").new())    # ayuda de teclas en pantalla (F1)
	add_child(preload("res://scripts/ui/pause_menu.gd").new())   # menu de pausa (ESC): guardar / salir

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
	_interact_was = Input.is_key_pressed(KEY_F)
	_attack_was = Input.is_key_pressed(KEY_SPACE)
	_drink_was = Input.is_key_pressed(KEY_Q)

	# Recuperacion segun el nivel (fija, no depende de stats).
	_regen_actual = stamina_regen + stamina_regen_per_level * (Game.player_level - 1)


func _physics_process(delta: float) -> void:
	# Con el inventario abierto: no te mueves ni interactuas (F/ataque). El
	# enemigo sigue su IA aparte, asi que puede emboscarte igualmente. Pero el
	# TIEMPO pasa, asi que el aguante se sigue recuperando.
	_comprobar_grupo()            # ¿ha entrado o salido alguien del equipo? (taberna, Hogar, 1/2/3)
	Game.tick_heal(delta)         # cura de pociones (fuera de combate) corre siempre que pasa el tiempo
	Game.tick_mana_pocion(delta)  # maná de pociones de maná (fuera de combate)
	_actualizar_max_aguante()     # el maximo escala con Resistencia/Agilidad (refresca si cambian las stats)
	if Game.inventory_open or Game.debug_panel_open:
		velocity = Vector2.ZERO
		current_stamina = minf(max_stamina, current_stamina + _regen_actual * delta)
		_tick_aguante_companeros(delta, false)   # el tiempo pasa para todos, no solo para ti
		if _exhausted and current_stamina >= max_stamina * exhausted_recover_ratio:
			_exhausted = false
		_refrescar_barras()
		return

	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")
	var moving: bool = direction != Vector2.ZERO
	if moving:
		_facing = direction.normalized()  # recordamos hacia donde miramos

	# Modo segun teclas (Ctrl = sigilo tiene prioridad sobre Shift = correr).
	# Si estamos AGOTADOS, no se puede correr (hasta recuperar la mitad).
	var sneaking: bool = Input.is_key_pressed(KEY_CTRL)
	# El grupo va al paso del MAS CANSADO: basta con que UNO este sin fuelle para que el grupo entero
	# se arrastre, sea el lider o un companero. Antes, si el agotado era un companero, solo se perdia
	# el correr (seguias andando normal) y el que no podia mas te seguia el paso como si nada.
	var agotado: PersonajeData = _pj_agotado()
	var running: bool = Input.is_key_pressed(KEY_SHIFT) and not sneaking \
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
	var gastando: bool = running and dist_enemigo <= _PELIGRO_RANGE
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

	velocity = direction * speed
	move_and_slide()

	# ALBOROTO: la mazmorra te oye. Correr mete ruido (llena el medidor de los brotes), ir en
	# sigilo lo baja. El modo ya esta calculado arriba (0 sigilo, 1 andar, 2 correr).
	Game.tick_alboroto(delta, movement_mode)

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
	var atk: bool = Input.is_key_pressed(KEY_SPACE)
	if atk and not _attack_was:
		_try_attack()
	_attack_was = atk

	var inter: bool = Input.is_key_pressed(KEY_F)
	if inter and not _interact_was:
		_try_interact()
	_interact_was = inter

	# Beber una pocion (Q): cura por el tiempo fuera de combate.
	var drink: bool = Input.is_key_pressed(KEY_Q)
	if drink and not _drink_was:
		_beber_pocion()
	_drink_was = drink

	# 1/2/3: quien va EN CABEZA. Cambia el cuerpo que mueves, su aguante y su velocidad, y en
	# combate sera el suyo el combatiente que entra. Es la jugada tactica de fuera de combate:
	# entrar tu primero, o mandar delante al que aguanta.
	# Ahora cada hueco es fijo, asi que la tecla 1 (hueco 0) tambien sirve: pone en cabeza al
	# primero. cambiar_lider no hace nada si ya es el lider.
	for i in range(mini(Game.party.size(), _lider_was.size())):
		var pulsada: bool = Input.is_key_pressed(KEY_1 + i)
		if pulsada and not _lider_was[i]:
			if Game.cambiar_lider(i):
				refrescar_lider()
		_lider_was[i] = pulsada


# Aguante maximo segun la Resistencia y la Agilidad. Usa el TOTAL acumulado (oculto), NO el
# visible: el visible vuelve a 0 al SUBIR DE NIVEL, y con el visible el aguante maximo se
# desplomaba a base_stamina en cada ascenso. Mismo criterio que la recoleccion y el reto.
func _calc_max_aguante(pj: PersonajeData = null) -> float:
	return base_stamina \
		+ Game.stat_total("resistencia", pj) * stamina_per_resistencia \
		+ Game.stat_total("agilidad", pj) * stamina_per_agilidad


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
	var peor_agi: int = 0
	if _exhausted:
		peor = _pj_actual
		peor_agi = Game.stat_total("agilidad", _pj_actual)
	for pj in Game.companeros():
		var maxi_: float = _calc_max_aguante(pj)
		if _aguante_de(pj) <= 0.0:
			pj.set_meta("sin_fuelle", true)
		elif _aguante_de(pj) >= maxi_ * exhausted_recover_ratio:
			pj.set_meta("sin_fuelle", false)
		if not bool(pj.get_meta("sin_fuelle", false)):
			continue
		var agi: int = Game.stat_total("agilidad", pj)
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
		previas = _sequito.posiciones()
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
func _comprobar_grupo() -> void:
	if _grupo_visto != Game.party:
		refrescar_grupo()


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
const ANCHO_COL := 180.0      # lo que mide una columna: el ancho de tus barras de toda la vida
const SEP_COL := 8.0          # aire entre una columna y la siguiente
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
# Donde acaba la fila entera. Lo lee hud.gd para colocar debajo la caja de ayudas de teclas.
const ALTO_BLOQUE := Y_MP + ALTO_MP


# La x donde arranca la columna del personaje i (0 = tu). La usa tambien el HUD para saber donde
# poner la mochila, que va detras de la ultima.
static func x_columna(i: int) -> float:
	return X_COL_BARRAS + float(i) * (ANCHO_COL + SEP_COL)


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
		raiz.position = Vector2(x_columna(i), 0.0)
		raiz.size = Vector2(ANCHO_COL, Y_MP + ALTO_MP)
		raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barras_layer.add_child(raiz)

		# El cuadradito de color y el nombre encima, lo unico que distingue una columna de otra.
		var punto := ColorRect.new()
		punto.size = Vector2(9, 9)
		punto.position = Vector2(0, Y_NOMBRE + 1.0)
		punto.color = pj.color
		punto.material = Game.material_de(pj)
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

		_barras.append({"pj": pj, "raiz": raiz, "nombre": nombre, "hp": hp, "hp_lbl": hp_lbl,
			"en": en, "en_lbl": en_lbl, "mp": mp, "mp_lbl": mp_lbl})


# Una barra de una columna (mismo ancho para las tres, solo cambian el alto y el color).
func _barra_col(raiz: Control, y: float, alto: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(ANCHO_COL, alto)
	b.size = Vector2(ANCHO_COL, alto)
	b.position = Vector2(0, y)
	b.self_modulate = color
	raiz.add_child(b)
	return b


# El cuerpo es un ColorRect mientras no haya arte; el brillo metalico y la imagen los pinta un
# shader por encima de ese color (null = mate y sin imagen).
func _pintar_cuerpo() -> void:
	var cuerpo := get_node_or_null("ColorRect") as ColorRect
	if cuerpo == null:
		return
	cuerpo.color = Game.player_color
	cuerpo.material = Game.material_cuerpo()


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
			if c != self and is_instance_valid(c) and c is Node2D and e.persigue_a(c):
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


# Busca un enemigo VIVO justo enfrente y muy cerca; si lo hay, inicia el combate
# con NUESTRA iniciativa. Devuelve true si ataco (lo usa _try_interact para saber
# si ya ha consumido la pulsacion de F).
func _try_attack() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - global_position
		var dist: float = to_e.length()
		if dist <= 0.01:
			continue
		# El alcance se mide por el HUECO entre los dos cuerpos, no entre sus centros: dos
		# cuadrados de 32x32 tocandose POR LA ESQUINA tienen los centros a 45.2 px, o sea mas
		# de attack_range (44) -> estabas pegado al slime y no podias pegarle. Con un elite
		# (1.6x de tamaño) la esquina son ~59 px: era intocable en diagonal. Ver enemy.hueco_hasta().
		if _hueco_hasta(e) > attack_range - 32.0:
			continue
		# El CONO sigue mandando: atacar exige mirar al bicho, es una accion deliberada.
		if absf(_facing.angle_to(to_e / dist)) <= deg_to_rad(attack_half_angle_deg):
			if e.has_method("atacado_por_jugador"):
				e.atacado_por_jugador()
				return true
	return false


# Hueco entre el cuerpo del jugador y el de 'otro' (0 = tocandose, de lado o de esquina).
# Descuenta lo que sobresale un elite (radio_extra), igual que hace la interaccion con los
# cadaveres en _mas_cercano_en_grupo.
func _hueco_hasta(otro: Node) -> float:
	if not (otro is Node2D):
		return INF
	var d: Vector2 = ((otro as Node2D).global_position - global_position).abs()
	var extra: float = float(otro.radio_extra) if "radio_extra" in otro else 0.0
	var suma: float = 32.0 + extra   # medio jugador (16) + medio bicho (16) + lo que sobresale el elite
	return maxf(d.x - suma, d.y - suma)


# INTERACTUAR (F). Por orden de cercania de la intencion:
#   1) NPC interactuable (altar, tienda, puerta, escalera, hogar).
#   2) EXTRAER el cristal de un cadaver.
#   3) RECOLECTAR una veta o una planta (su minijuego).
#   4) RECOGER un item del suelo.
# El cadaver va ANTES que el recolectable a proposito: un bicho que cae encima de una veta
# no puede dejarte sin tu cristal (y la veta no se va a ningun sitio, sigue ahi despues).
# ATACAR ya NO esta aqui: tiene su propia tecla (ESPACIO). Asi, acercarte a lootear con un
# bicho al lado no te mete en un combate que no habias pedido.
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

	# 3) Veta o planta: abre su minijuego (pico -> Fuerza, hoz -> Destreza).
	var reco: Node = _mas_cercano_en_grupo("recolectable", false)
	if reco != null and reco.has_method("interactuar"):
		reco.interactuar()
		return

	# 4) Item del suelo para recoger (lo que solto el monstruo, o algo que tiraste tu).
	var pickup: Node = _mas_cercano_en_grupo("pickup", false)
	if pickup != null and pickup.has_method("recoger"):
		var item: Resource = pickup.recoger()
		if item is MaterialItem:
			var m := item as MaterialItem
			Game.materiales.append(m)
			Game.descubrir(m.data)
			print("Recoges: ", m.nombre(), " (", m.calidad_texto(), "). Total materiales: ",
				Game.materiales.size())
			Game._aviso_recogida(m.nombre())
		elif item is Cristal:
			var c := item as Cristal
			Game.crystals.append(c)
			print("Recoges: Cristal Cat ", c.categoria, " (", c.calidad_texto(),
				"). Total cristales: ", Game.crystals.size())
			Game._aviso_recogida("Cristal T%d" % c.categoria)


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
func _mas_cercano_en_grupo(grupo: String, skip_extracted: bool) -> Node:
	var nearest: Node = null
	var best: float = INF
	for n in get_tree().get_nodes_in_group(grupo):
		if not is_instance_valid(n):
			continue
		if skip_extracted and "extracted" in n and n.extracted:
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


# Bebe la PRIMERA poción del inventario (tecla Q, fuera de combate). Arranca la
# cura-por-tiempo de Game (no hace nada si no tienes pociones o ya estas a tope).
func _beber_pocion() -> void:
	# Q = recuperación óptima (auto). Para ELEGIR una poción concreta, abre el inventario (I).
	Game.beber_optima()
