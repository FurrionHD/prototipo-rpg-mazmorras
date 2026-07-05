# ============================================================
#  combatant.gd
#  Representa a UN combatiente dentro de una batalla (jugador o enemigo).
#  Junta: nombre, nivel, habilidades (Abilities) y stats base, y a partir
#  de ahi calcula sus valores reales (ataque, defensa, velocidad, vida).
#  No es un nodo: es un objeto ligero que usa el motor de combate.
# ============================================================

extends RefCounted
class_name Combatant

var nombre: String = ""
var level: int = 1
var abilities: Abilities = null

# Stats BASE del combatiente (lo que tiene "de serie", sin habilidades).
var base_hp: float = 0.0
var base_attack: float = 0.0
var base_defense: float = 0.0
var base_speed: float = 0.0

# Vida actual / maxima (se calculan al crear). current_hp es FLOAT para no perder
# precision con el daño decimal (asi ves mejoras pequeñas golpe a golpe).
var max_hp: int = 0
var current_hp: float = 0.0

# --- Modificadores del LOADOUT (arma + secundaria). Neutros por defecto, asi un
# combatiente SIN equipo (p.ej. enemigos) se comporta como antes. El jugador los
# rellena en Game.crear_player_combatant() con Game.loadout_mods(). ---
# Estos son los del ARMA ACTIVA (la mano con la que golpeas AHORA). En dual-wield
# alternan entre las dos manos golpe a golpe (ver hands / advance_hand).
var ataque_arma: float = 0.0     # RAW que aporta el arma (se suma al raw del jugador)
var motion_value: float = 1.0    # % del raw por golpe (arma). 1.0 = neutro
var crit_bonus: float = 0.0      # se suma a la prob. de critico
var dano_tipo: int = 0           # 0 CORTE, 1 CONTUNDENTE (WeaponData.DanoTipo)
var aturdir_base: float = 0.0    # prob. base de aturdir/retrasar (contundentes)
# Estos NO cambian por mano (son del loadout entero):
var velocidad_mult: float = 1.0  # multiplica la velocidad de combate (turnos)
var defend_block: float = 0.3    # reduccion al Defender (base sin secundaria)
var evasion_penal: float = 0.0   # baja la esquiva propia (escudos)

# --- ARMADURA (loadout de 5 piezas, ver Game.armor_mods()). Neutros por defecto,
# asi un combatiente SIN armadura (enemigos) se comporta igual que antes. ---
var extra_defense: float = 0.0   # DEF plana ADITIVA de la armadura (sube la mitigacion)
var armor_reduction: float = 0.0 # % de reduccion de dano (SIEMPRE activo, acotado)

# MANOS del loadout: 1 (arma sola / 2 manos / con escudo) o 2 (dual-wield). Cada
# mano es un Dictionary {nombre, motion_value, ataque_arma, crit_bonus, dano_tipo,
# aturdir_base}. Se ALTERNAN por golpe (advance_hand). Vacio = enemigos (sin arma).
var hands: Array = []
var _hand_idx: int = 0


func _init(nombre_: String, level_: int, abilities_: Abilities,
		base_hp_: float, base_attack_: float, base_defense_: float, base_speed_: float) -> void:
	nombre = nombre_
	level = level_
	abilities = abilities_
	base_hp = base_hp_
	base_attack = base_attack_
	base_defense = base_defense_
	base_speed = base_speed_

	max_hp = StatsMath.max_hp_value(abilities, level, base_hp)
	current_hp = max_hp


# Valores reales de combate (calculados con las formulas de StatsMath).
# atk() = (base + arma) × factor_fuerza × motion_value.
#   - base + arma: el raw comun (el arma SUMA ataque, equipar sube el daño).
#   - factor_fuerza (1 + Fuerza/DIV): la Fuerza MULTIPLICA ese raw -> crecer se nota
#     y escala con el arma (estilo MH).
#   - motion_value: reparte el raw por golpe (rapidas < 1, grandes > 1).
# spd() lleva la velocidad del arma (mas/menos turnos).
func atk() -> float:
	return (base_attack + ataque_arma) * StatsMath.fuerza_factor(abilities.fuerza) * motion_value
func def_value() -> float: return StatsMath.defense_value(abilities, level, base_defense + extra_defense)
func spd() -> float: return StatsMath.speed_value(abilities, level, base_speed) * velocidad_mult

func is_alive() -> bool:
	return current_hp > 0.0

func take_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)


# Configura las manos del loadout y activa la primera. Cada mano es un Dictionary
# con motion_value/ataque_arma/crit_bonus/dano_tipo/aturdir_base (+ nombre).
func set_hands(hs: Array) -> void:
	hands = hs
	_hand_idx = 0
	if hands.size() > 0:
		_apply_hand(0)

func _apply_hand(i: int) -> void:
	var h: Dictionary = hands[i]
	motion_value = h["motion_value"]
	ataque_arma = h["ataque_arma"]
	crit_bonus = h["crit_bonus"]
	dano_tipo = h["dano_tipo"]
	aturdir_base = h["aturdir_base"]

# Pasa a la siguiente mano (dual-wield: alterna principal <-> secundaria por golpe).
# Con 1 mano no hace nada.
func advance_hand() -> void:
	if hands.size() > 1:
		_hand_idx = (_hand_idx + 1) % hands.size()
		_apply_hand(_hand_idx)

# Nombre del arma con la que golpeas AHORA (para el log). "" si no hay manos.
func current_hand_name() -> String:
	return hands[_hand_idx]["nombre"] if hands.size() > 0 else ""
