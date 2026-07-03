# ============================================================
#  combat.gd
#  Pantalla de combate por turnos INTERACTIVA.
#  Recibe los combatientes reales (jugador y enemigo) desde Game via setup().
#  Si se abre sola (F6), usa combatientes de PRUEBA.
#  Orden de turnos ATB (barra que se llena a ritmo de la velocidad); en tu
#  turno se pausa y esperas a pulsar "Atacar"; el enemigo actua solo.
#
#  Estructura de nodos esperada (combat.tscn):
#    Combat (Control)  <- este script
#    └── VBox (VBoxContainer)
#        ├── EnemyName (Label)   ├── EnemyHP (ProgressBar)
#        ├── PlayerName (Label)  ├── PlayerHP (ProgressBar)
#        ├── Log (Label)         └── AttackButton (Button)
# ============================================================

extends Control

const UMBRAL := 100.0          # cuanto llenar la barra para actuar
const SPEED_SCALE := 10.0      # ritmo de llenado (mas alto = combate mas rapido)
const INICIATIVA_VENTAJA := 50.0  # media barra de ventaja para quien inicia

# Si entras AGOTADO, tus primeras acciones van mas lentas.
const EXHAUSTED_SLOW_ACTIONS := 2   # cuantas acciones afectadas
const EXHAUSTED_RATE := 0.5         # a que ritmo (0.5 = la mitad)

# Aturdir/retrasar (armas contundentes). Un golpe contundente que aturde le RESTA
# barra ATB al objetivo (pierde tempo). El retraso NORMAL es aleatorio dentro de
# una franja; un golpe CRITICO que ademas aturde es un aturdimiento COMPLETO:
# le manda la barra a -UMBRAL = pierde el turno entero.
const ATB_STUN_MIN := 0.30   # retraso parcial minimo (fraccion de barra)
const ATB_STUN_MAX := 0.60   # retraso parcial maximo

@onready var _enemy_name: Label = $VBox/EnemyName
@onready var _enemy_hp: ProgressBar = $VBox/EnemyHP
@onready var _player_name: Label = $VBox/PlayerName
@onready var _player_hp: ProgressBar = $VBox/PlayerHP
@onready var _log: Label = $VBox/Log
@onready var _attack_button: Button = $VBox/AttackButton
# Boton Defender (KAN-54): lo creamos por codigo para no tocar la escena.
var _defend_button: Button = null

# Linea de ORDEN DE TURNOS (estilo Epic Seven), creada por codigo.
var _timeline: Control = null

# Se emite al cerrar el combate (lo escucha Game para reanudar la mazmorra).
signal combat_finished(player_won: bool, player_hp_left: float)

var _player: Combatant
var _enemy: Combatant
var _gauge: Dictionary = {}

enum State { ADVANCING, WAITING_PLAYER, FINISHED }
var _state: State = State.ADVANCING

var _injected: bool = false       # true si Game nos paso los combatientes
var _enemy_initiated: bool = false
var _player_won: bool = false

var _player_exhausted_start: bool = false  # entro agotado
var _slow_actions_left: int = 0            # acciones lentas que quedan
var _player_overload_factor: float = 1.0   # <1 si entro sobrecargado (lento todo el combate)
var _player_defending: bool = false        # true si elegiste Defender (dura hasta tu proximo turno)


# Lo llama Game ANTES de añadir esta escena al arbol.
func setup(player_c: Combatant, enemy_c: Combatant, enemy_initiated: bool,
		player_exhausted: bool = false, player_overload_factor: float = 1.0) -> void:
	_player = player_c
	_enemy = enemy_c
	_enemy_initiated = enemy_initiated
	_player_exhausted_start = player_exhausted
	_player_overload_factor = player_overload_factor
	_injected = true


func _ready() -> void:
	# Forzamos que esta pantalla ocupe toda la ventana, aunque se abra como
	# overlay encima de la mazmorra (si no, sale descentrada/pequeña).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_anadir_fondo()  # fondo opaco para tapar la mazmorra detras

	if not _injected:
		# Combatientes de PRUEBA (para abrir combat.tscn directamente con F6).
		var pab := Abilities.new()
		pab.fuerza = 120; pab.resistencia = 90; pab.destreza = 60; pab.agilidad = 110; pab.magia = 20
		_player = Combatant.new("Heroe", 1, pab, 50, 5, 5, 5)
		var eab := Abilities.new()
		eab.fuerza = 80; eab.resistencia = 70; eab.destreza = 30; eab.agilidad = 60; eab.magia = 0
		_enemy = Combatant.new("Slime", 1, eab, 40, 4, 5, 4)

	_gauge = {_player: 0.0, _enemy: 0.0}
	# Iniciativa: quien empezo el combate arranca con media barra.
	if _enemy_initiated:
		_gauge[_enemy] = INICIATIVA_VENTAJA
	elif _injected:
		_gauge[_player] = INICIATIVA_VENTAJA

	# Si entro agotado, sus primeras acciones iran mas lentas.
	if _player_exhausted_start:
		_slow_actions_left = EXHAUSTED_SLOW_ACTIONS

	_attack_button.pressed.connect(_on_attack_pressed)
	_crear_boton_defender()
	_setup_ui()
	_crear_timeline()
	if _enemy_initiated:
		_set_log("¡" + _enemy.nombre + " te sorprende! Tiene la iniciativa.")
	elif _injected:
		_set_log("¡Ataque por la espalda! Tienes la iniciativa. 🗡️")
	else:
		_set_log("¡Empieza el combate contra " + _enemy.nombre + "!")
	if _player_exhausted_start:
		_log.text += "  (Agotado: tus primeras acciones son mas lentas)"


# Crea el boton "Defender" justo debajo del de Atacar (dentro del mismo VBox).
func _crear_boton_defender() -> void:
	_defend_button = Button.new()
	_defend_button.text = "Defender"
	_defend_button.pressed.connect(_on_defend_pressed)
	$VBox.add_child(_defend_button)


func _setup_ui() -> void:
	_player_hp.max_value = _player.max_hp
	_enemy_hp.max_value = _enemy.max_hp
	_player_hp.show_percentage = false
	_enemy_hp.show_percentage = false
	_update_hp()
	_attack_button.disabled = true
	_defend_button.disabled = true


func _update_hp() -> void:
	_player_hp.value = _player.current_hp
	_enemy_hp.value = _enemy.current_hp
	_enemy_name.text = "%s  (Nv.%d)   %.2f/%d" % [
		_enemy.nombre, _enemy.level, _enemy.current_hp, _enemy.max_hp]
	_player_name.text = "%s  (Nv.%d)   %.2f/%d" % [
		_player.nombre, _player.level, _player.current_hp, _player.max_hp]


func _process(delta: float) -> void:
	_update_timeline()  # refleja el orden de turnos siempre
	if _state != State.ADVANCING:
		return

	# Si estamos en una accion lenta por agotamiento, el jugador llena su
	# barra a mitad de ritmo.
	var player_rate: float = SPEED_SCALE
	if _slow_actions_left > 0:
		player_rate *= EXHAUSTED_RATE
	player_rate *= _player_overload_factor
	_gauge[_player] += _player.spd() * delta * player_rate
	_gauge[_enemy] += _enemy.spd() * delta * SPEED_SCALE

	if _gauge[_player] >= UMBRAL or _gauge[_enemy] >= UMBRAL:
		if _gauge[_player] >= _gauge[_enemy]:
			_gauge[_player] -= UMBRAL
			_begin_player_turn()
		else:
			_gauge[_enemy] -= UMBRAL
			_enemy_turn()


func _begin_player_turn() -> void:
	_state = State.WAITING_PLAYER
	_player_defending = false  # la guardia solo dura hasta tu proximo turno
	_attack_button.disabled = false
	_defend_button.disabled = false
	_set_log("¡Tu turno! Elige una accion.")


func _on_attack_pressed() -> void:
	# Si el combate ya termino, el boton hace de "Continuar" (cierra la pantalla).
	if _state == State.FINISHED:
		combat_finished.emit(_player_won, _player.current_hp)
		# Si lo abrio Game, el cierra la capa; si es prueba (F6), nos cerramos solos.
		if not _injected:
			queue_free()
		return

	if _state != State.WAITING_PLAYER:
		return

	# Los enemigos no defienden (de momento): defending = false.
	var result := StatsMath.resolve_attack(_player, _enemy, false)
	_debug_ataque(_player, _enemy, result)
	# Excelia: atacar sube Fuerza aunque el enemigo esquive (has practicado el
	# golpe). arma_factor = motion_value de la MANO ACTIVA (KAN-82); tope fisico (5).
	var arma_factor: float = _player.motion_value
	Game.ganar("fuerza", Game.reto(_poder_enemigo()) * arma_factor, Game.GAIN_FUERZA_ATAQUE,
		Game.RETO_MAX_FISICO)
	var con_arma: String = _player.current_hand_name()
	if result.evaded:
		_set_log("%s esquiva tu ataque (%s). 💨" % [_enemy.nombre, con_arma])
	else:
		_enemy.take_damage(result.damage)
		var txt: String
		if result.crit:
			txt = "¡CRITICO! %s golpea con %s por %.2f de daño. 💥" % [_player.nombre, con_arma, result.damage]
			# Excelia: clavar un critico entrena Agilidad (encontraste el hueco).
			Game.ganar("agilidad", Game.reto(_poder_enemigo()), Game.GAIN_AGILIDAD_CRITICO,
				Game.RETO_MAX_FISICO)
		else:
			txt = "%s golpea con %s por %.2f de daño." % [_player.nombre, con_arma, result.damage]
		# Aturdir/retrasar (arma contundente): el enemigo pierde tempo (barra ATB).
		# Retraso parcial normal; si el golpe fue CRITICO, aturdimiento completo.
		if result.aturde:
			txt += _aplicar_aturdir(_enemy, result.crit)
		_set_log(txt)
	_update_hp()
	_player.advance_hand()  # dual-wield: el proximo golpe sera con la otra mano
	_attack_button.disabled = true
	_defend_button.disabled = true

	# Esta accion del jugador ya cuenta: gastamos una "accion lenta".
	if _slow_actions_left > 0:
		_slow_actions_left -= 1

	if not _enemy.is_alive():
		_end(true)
	else:
		_state = State.ADVANCING


# Accion Defender (KAN-54): mitiga el proximo daño y anula criticos en tu contra
# hasta tu siguiente turno. Cuesta el turno (no atacas).
func _on_defend_pressed() -> void:
	if _state != State.WAITING_PLAYER:
		return
	_player_defending = true
	_set_log("%s se pone en guardia. 🛡️ (menos daño hasta tu proximo turno)" % _player.nombre)
	_attack_button.disabled = true
	_defend_button.disabled = true
	if _slow_actions_left > 0:
		_slow_actions_left -= 1
	_state = State.ADVANCING


func _enemy_turn() -> void:
	var result := StatsMath.resolve_attack(_enemy, _player, _player_defending)
	_debug_ataque(_enemy, _player, result)
	if result.evaded:
		_set_log("%s esquiva el ataque de %s. 💨" % [_player.nombre, _enemy.nombre])
		# Excelia: esquivar un golpe entrena Agilidad (en vez de correr en circulos).
		Game.ganar("agilidad", Game.reto(_poder_enemigo()), Game.GAIN_AGILIDAD_ESQUIVAR,
			Game.RETO_MAX_FISICO)
		_update_hp()
		return

	var dmg: float = result.damage
	_player.take_damage(dmg)
	# Excelia: la Resistencia sube por la PELIGROSIDAD del enemigo (como el
	# ataque), modulada por el DAÑO recibido (golpe gordo entrena mas). Asi
	# tambien sube bien al principio, cuando el enemigo es un gran reto.
	var dmg_mult: float = clampf(dmg / maxf(1.0, float(_player.max_hp) * 0.1), 0.5, 2.0)
	Game.ganar("resistencia", Game.reto(_poder_enemigo()) * dmg_mult, Game.GAIN_RESISTENCIA_GOLPE,
		Game.RETO_MAX_FISICO)
	# Excelia: si BLOQUEAS (Defender), entrenas Resistencia EXTRA segun cuanto
	# bloquees (escudo grande entrena mas). Formaliza KAN-81 y premia el escudo.
	if _player_defending:
		Game.ganar("resistencia", Game.reto(_poder_enemigo()) * _player.defend_block,
			Game.GAIN_RESISTENCIA_BLOQUEO, Game.RETO_MAX_FISICO)
	var msg: String
	if result.crit:
		msg = "%s te CLAVA un critico: %.2f de daño! 💥" % [_enemy.nombre, dmg]
	else:
		msg = "%s te ataca por %.2f de daño." % [_enemy.nombre, dmg]
	if _player_defending:
		msg += " (defendido 🛡️)"
	# Aturdir/retrasar del enemigo (si algun dia lleva arma contundente).
	if result.aturde:
		msg += _aplicar_aturdir(_player, result.crit)
	_set_log(msg)
	_update_hp()
	_enemy.advance_hand()  # (sin efecto ahora; los enemigos aun no llevan 2 armas)

	if not _player.is_alive():
		_end(false)


func _end(player_won: bool) -> void:
	_player_won = player_won
	_state = State.FINISHED
	_attack_button.disabled = false
	_attack_button.text = "Continuar"
	if _defend_button != null:
		_defend_button.disabled = true
		_defend_button.visible = false
	if player_won:
		_set_log("¡GANASTE el combate contra " + _enemy.nombre + "! 🎉")
	else:
		_set_log("Has caido en combate... 💀")


func _set_log(texto: String) -> void:
	_log.text = texto


# Aplica el aturdir a un objetivo (resta barra ATB) y devuelve el texto para el log.
# es_crit = el golpe fue CRITICO -> aturdimiento COMPLETO (pierde el turno).
func _aplicar_aturdir(objetivo: Combatant, es_crit: bool) -> String:
	if es_crit:
		_gauge[objetivo] = -UMBRAL   # barra a negativo: se salta el turno entero
		return "  ¡ATURDIDO! 💫 (pierde el turno)"
	var f: float = randf_range(ATB_STUN_MIN, ATB_STUN_MAX)
	_gauge[objetivo] = maxf(0.0, _gauge[objetivo] - UMBRAL * f)
	return "  ¡Retrasado! 💫"


# Log de DESARROLLO (consola): probabilidades reales de esquiva/crit/aturdir de
# CADA ataque, con las stats implicadas, para afinar la curva en cada situacion.
func _debug_ataque(atacante: Combatant, defensor: Combatant, r: Dictionary) -> void:
	var outcome: String = "esquivado" if r.evaded else ("CRITICO" if r.crit else "golpe")
	if r.aturde:
		outcome += "+ATURDE"
	var mano: String = atacante.current_hand_name()
	var quien: String = atacante.nombre + ("[" + mano + "]" if mano != "" else "")
	print("[combate] %s(Dex %d) -> %s(Agi %d) | esquiva:%.1f%% crit:%.1f%% aturdir:%.1f%% | ATK:%.2f dmg:%.2f | %s" % [
		quien, atacante.abilities.destreza,
		defensor.nombre, defensor.abilities.agilidad,
		r.evade_p * 100.0, r.crit_p * 100.0, r.aturde_p * 100.0,
		atacante.atk(), r.damage, outcome])


# Poder del enemigo (suma de sus habilidades) para la dificultad relativa.
func _poder_enemigo() -> float:
	if _enemy == null or _enemy.abilities == null:
		return 0.0
	var a: Abilities = _enemy.abilities
	return float(a.fuerza + a.resistencia + a.destreza + a.agilidad + a.magia)


# Crea la linea de orden de turnos (banda horizontal en la zona media).
func _crear_timeline() -> void:
	_timeline = preload("res://scripts/ui/turn_timeline.gd").new()
	_timeline.anchor_left = 0.0
	_timeline.anchor_right = 1.0
	_timeline.offset_top = 320.0
	_timeline.offset_bottom = 400.0
	add_child(_timeline)


func _update_timeline() -> void:
	if _timeline != null:
		_timeline.set_ratios(_gauge.get(_player, 0.0) / UMBRAL, _gauge.get(_enemy, 0.0) / UMBRAL)


# Crea un fondo opaco a pantalla completa, por DETRAS de la interfaz.
func _anadir_fondo() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # que no robe los clics al boton
	add_child(bg)
	move_child(bg, 0)  # al fondo (los hermanos siguientes se dibujan encima)
