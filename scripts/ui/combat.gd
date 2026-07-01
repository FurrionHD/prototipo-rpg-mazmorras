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

@onready var _enemy_name: Label = $VBox/EnemyName
@onready var _enemy_hp: ProgressBar = $VBox/EnemyHP
@onready var _player_name: Label = $VBox/PlayerName
@onready var _player_hp: ProgressBar = $VBox/PlayerHP
@onready var _log: Label = $VBox/Log
@onready var _attack_button: Button = $VBox/AttackButton

# Linea de ORDEN DE TURNOS (estilo Epic Seven), creada por codigo.
var _timeline: Control = null

# Se emite al cerrar el combate (lo escucha Game para reanudar la mazmorra).
signal combat_finished(player_won: bool, player_hp_left: int)

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


func _setup_ui() -> void:
	_player_hp.max_value = _player.max_hp
	_enemy_hp.max_value = _enemy.max_hp
	_player_hp.show_percentage = false
	_enemy_hp.show_percentage = false
	_update_hp()
	_attack_button.disabled = true


func _update_hp() -> void:
	_player_hp.value = _player.current_hp
	_enemy_hp.value = _enemy.current_hp
	_enemy_name.text = "%s  (Nv.%d)   %d/%d" % [
		_enemy.nombre, _enemy.level, _enemy.current_hp, _enemy.max_hp]
	_player_name.text = "%s  (Nv.%d)   %d/%d" % [
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
	_attack_button.disabled = false
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

	var dmg := StatsMath.damage(_player.atk(), _enemy.def_value())
	_enemy.take_damage(dmg)
	# Excelia: atacar sube Fuerza (arma_factor = 1.0 placeholder hasta tener equipo).
	Game.ganar("fuerza", Game.reto(_poder_enemigo()) * 1.0, Game.GAIN_FUERZA_ATAQUE)
	_set_log("%s ataca por %d de daño." % [_player.nombre, dmg])
	_update_hp()
	_attack_button.disabled = true

	# Esta accion del jugador ya cuenta: gastamos una "accion lenta".
	if _slow_actions_left > 0:
		_slow_actions_left -= 1

	if not _enemy.is_alive():
		_end(true)
	else:
		_state = State.ADVANCING


func _enemy_turn() -> void:
	var dmg := StatsMath.damage(_enemy.atk(), _player.def_value())
	_player.take_damage(dmg)
	# Excelia: la Resistencia sube por la PELIGROSIDAD del enemigo (como el
	# ataque), modulada por el DAÑO recibido (golpe gordo entrena mas). Asi
	# tambien sube bien al principio, cuando el enemigo es un gran reto.
	var dmg_mult: float = clampf(float(dmg) / maxf(1.0, float(_player.max_hp) * 0.1), 0.5, 2.0)
	Game.ganar("resistencia", Game.reto(_poder_enemigo()) * dmg_mult, Game.GAIN_RESISTENCIA_GOLPE)
	_set_log("%s te ataca por %d de daño." % [_enemy.nombre, dmg])
	_update_hp()

	if not _player.is_alive():
		_end(false)


func _end(player_won: bool) -> void:
	_player_won = player_won
	_state = State.FINISHED
	_attack_button.disabled = false
	_attack_button.text = "Continuar"
	if player_won:
		_set_log("¡GANASTE el combate contra " + _enemy.nombre + "! 🎉")
	else:
		_set_log("Has caido en combate... 💀")


func _set_log(texto: String) -> void:
	_log.text = texto


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
