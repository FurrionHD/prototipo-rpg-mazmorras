# ============================================================
#  combat.gd
#  Pantalla de combate por turnos INTERACTIVA (etapa B).
#  Reutiliza el motor: Combatant + StatsMath. El orden de turnos es ATB
#  (cada uno llena una barra a ritmo de su velocidad). En el turno del
#  jugador se PAUSA y espera a que pulses "Atacar"; el enemigo actua solo.
#
#  De momento crea un heroe y un slime de PRUEBA. Mas adelante recibira
#  los datos reales del jugador y del enemigo de la mazmorra.
#
#  Espera esta estructura de nodos (ver combat.tscn):
#    Combat (Control)  <- este script
#    └── VBox (VBoxContainer)
#        ├── EnemyName (Label)
#        ├── EnemyHP (ProgressBar)
#        ├── PlayerName (Label)
#        ├── PlayerHP (ProgressBar)
#        ├── Log (Label)
#        └── AttackButton (Button)
# ============================================================

extends Control

const UMBRAL := 100.0       # cuanto hay que llenar la barra para actuar
const SPEED_SCALE := 10.0   # ritmo de llenado (mas alto = combate mas rapido)

# Nodos de la interfaz (los nombres deben coincidir con la escena).
@onready var _enemy_name: Label = $VBox/EnemyName
@onready var _enemy_hp: ProgressBar = $VBox/EnemyHP
@onready var _player_name: Label = $VBox/PlayerName
@onready var _player_hp: ProgressBar = $VBox/PlayerHP
@onready var _log: Label = $VBox/Log
@onready var _attack_button: Button = $VBox/AttackButton

var _player: Combatant
var _enemy: Combatant
var _gauge: Dictionary = {}

# Estados del combate.
enum State { ADVANCING, WAITING_PLAYER, FINISHED }
var _state: State = State.ADVANCING


func _ready() -> void:
	# --- Combatientes de PRUEBA (luego vendran de datos reales) ---
	var pab := Abilities.new()
	pab.fuerza = 120; pab.resistencia = 90; pab.destreza = 60; pab.agilidad = 110; pab.magia = 20
	_player = Combatant.new("Heroe", 1, pab, 50, 5, 5, 5)

	var eab := Abilities.new()
	eab.fuerza = 80; eab.resistencia = 70; eab.destreza = 30; eab.agilidad = 60; eab.magia = 0
	_enemy = Combatant.new("Slime", 1, eab, 40, 4, 5, 4)

	_gauge = {_player: 0.0, _enemy: 0.0}

	_attack_button.pressed.connect(_on_attack_pressed)
	_setup_ui()
	_set_log("¡Empieza el combate contra " + _enemy.nombre + "!")


func _setup_ui() -> void:
	_player_name.text = _player.nombre + "  (Nv." + str(_player.level) + ")"
	_enemy_name.text = _enemy.nombre + "  (Nv." + str(_enemy.level) + ")"
	_player_hp.max_value = _player.max_hp
	_enemy_hp.max_value = _enemy.max_hp
	_update_hp()
	_attack_button.disabled = true


func _update_hp() -> void:
	_player_hp.value = _player.current_hp
	_enemy_hp.value = _enemy.current_hp


func _process(delta: float) -> void:
	# Solo avanzamos las barras cuando nadie esta decidiendo ni ha terminado.
	if _state != State.ADVANCING:
		return

	_gauge[_player] += _player.spd() * delta * SPEED_SCALE
	_gauge[_enemy] += _enemy.spd() * delta * SPEED_SCALE

	# Si alguien lleno su barra, actua el que la tenga mas llena.
	if _gauge[_player] >= UMBRAL or _gauge[_enemy] >= UMBRAL:
		if _gauge[_player] >= _gauge[_enemy]:
			_gauge[_player] -= UMBRAL
			_begin_player_turn()
		else:
			_gauge[_enemy] -= UMBRAL
			_enemy_turn()


# --- Turno del jugador: pausamos y esperamos a que pulse Atacar ---
func _begin_player_turn() -> void:
	_state = State.WAITING_PLAYER
	_attack_button.disabled = false
	_set_log("¡Tu turno! Elige una accion.")


func _on_attack_pressed() -> void:
	if _state != State.WAITING_PLAYER:
		return
	var dmg := StatsMath.damage(_player.atk(), _enemy.def_value())
	_enemy.take_damage(dmg)
	_set_log("%s ataca por %d de daño." % [_player.nombre, dmg])
	_update_hp()
	_attack_button.disabled = true

	if not _enemy.is_alive():
		_end(true)
	else:
		_state = State.ADVANCING  # seguimos llenando barras


# --- Turno del enemigo: ataca automaticamente ---
func _enemy_turn() -> void:
	var dmg := StatsMath.damage(_enemy.atk(), _player.def_value())
	_player.take_damage(dmg)
	_set_log("%s te ataca por %d de daño." % [_enemy.nombre, dmg])
	_update_hp()

	if not _player.is_alive():
		_end(false)


func _end(player_won: bool) -> void:
	_state = State.FINISHED
	_attack_button.disabled = true
	if player_won:
		_set_log("¡GANASTE el combate contra " + _enemy.nombre + "! 🎉")
	else:
		_set_log("Has caido en combate... 💀")


func _set_log(texto: String) -> void:
	_log.text = texto
