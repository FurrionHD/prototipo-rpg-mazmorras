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
var base_magic: float = 0.0     # base del hechizo (0 = sin magia; enemigos)

# Vida actual / maxima (se calculan al crear). current_hp es FLOAT para no perder
# precision con el daño decimal (asi ves mejoras pequeñas golpe a golpe).
var max_hp: float = 0.0
var current_hp: float = 0.0

# --- MAGIA (KAN-56) ---
# Mana (maximo por Magia; enemigos = 0). current_mp es FLOAT por el regen fino.
var max_mp: float = 0.0
var current_mp: float = 0.0
# Hechizos equipados (Array[SpellData]). Vacio = no lanza magia (enemigos, o el
# jugador sin hechizos equipados).
var spells: Array = []
# Amplificador de daño magico del arma (bastones/varitas, KAN-95). Neutro por defecto.
var magic_amp: float = 1.0
# Regen de maná EXTRA por turno que aporta el arma magica (KAN-95).
var mp_regen_bonus: float = 0.0
# Reduccion PORCENTUAL del coste de maná (mejora Eficiencia, KAN-95). 0 = sin descuento.
var mana_reduccion: float = 0.0
# Velocidad de CASTEO: al lanzar hechizos la barra ATB usa esta (la varita del mago
# hibrido la cambia respecto a la del arma principal). Por defecto = velocidad_mult.
var cast_velocidad_mult: float = 1.0

# --- Modificadores del LOADOUT (arma + secundaria). Neutros por defecto, asi un
# combatiente SIN equipo (p.ej. enemigos) se comporta como antes. El jugador los
# rellena en Game.crear_player_combatant() con Game.loadout_mods(). ---
# Estos son los del ARMA ACTIVA (la mano con la que golpeas AHORA). En dual-wield
# alternan entre las dos manos golpe a golpe (ver hands / advance_hand).
var ataque_arma: float = 0.0     # RAW que aporta el arma (se suma al raw del jugador)
var motion_value: float = 1.0    # % del raw por golpe (arma). 1.0 = neutro
var crit_bonus: float = 0.0      # se suma a la prob. de critico
var precision: float = 0.0       # ACIERTO (mejora Precision): baja la evasion del rival
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
var crit_resist: float = 0.0     # RESIST. CRITICOS (armadura pesada): baja el crit del atacante

# MANOS del loadout: 1 (arma sola / 2 manos / con escudo) o 2 (dual-wield). Cada
# mano es un Dictionary {nombre, motion_value, ataque_arma, crit_bonus, dano_tipo,
# aturdir_base}. Se ALTERNAN por golpe (advance_hand). Vacio = enemigos (sin arma).
var hands: Array = []
var _hand_idx: int = 0

# --- ESTADOS ALTERADOS (KAN-58) ---
# Estados ACTIVOS sobre este combatiente (Array[StatusEffects.Instance]). El motor
# (apply/tick/agregadores) vive aqui; las definiciones en status_effects.gd.
var statuses: Array = []

# Estados que este combatiente aplica AL GOLPEAR (KAN-58 Fase 3). Array[StatusApplication].
# Lo rellena EnemyData (slimes: pegajoso/veneno) o el arma del jugador (futuro: sangrado).
var on_hit: Array = []

# Resistencia a ESTADOS alterados (0..1): MULTIPLICA a la baja la probabilidad de que
# te apliquen un estado negativo. La aporta la mejora Resistencia de la armadura (KAN-58).
var status_resist: float = 0.0


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
	max_mp = StatsMath.max_mp_value(abilities, level)
	current_mp = max_mp


# Valores reales de combate (calculados con las formulas de StatsMath).
# atk() = (base + arma) × factor_fuerza × motion_value.
#   - base + arma: el raw comun (el arma SUMA ataque, equipar sube el daño).
#   - factor_fuerza (1 + Fuerza/DIV): la Fuerza MULTIPLICA ese raw -> crecer se nota
#     y escala con el arma (estilo MH).
#   - motion_value: reparte el raw por golpe (rapidas < 1, grandes > 1).
# spd() lleva la velocidad del arma (mas/menos turnos).
func atk() -> float:
	return (base_attack + ataque_arma) * StatsMath.fuerza_factor(abilities.fuerza) * motion_value * status_atk_mult()
func def_value() -> float: return StatsMath.defense_value(abilities, level, base_defense + extra_defense) * status_def_mult()
func spd() -> float: return StatsMath.speed_value(abilities, level, base_speed) * velocidad_mult * status_spd_mult()
# Velocidad al CASTEAR (KAN-95): igual que spd() pero con la velocidad de casteo.
func cast_spd() -> float: return StatsMath.speed_value(abilities, level, base_speed) * cast_velocidad_mult * status_spd_mult()

func is_alive() -> bool:
	return current_hp > 0.0

func take_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)


# --- Mana (KAN-56) ---
func spend_mana(amount: float) -> void:
	current_mp = maxf(0.0, current_mp - amount)

func regen_mana(amount: float) -> void:
	current_mp = minf(max_mp, current_mp + amount)

func has_mana(amount: float) -> bool:
	return current_mp >= amount


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
	precision = h.get("precision", 0.0)
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


# ============================================================
#  ESTADOS ALTERADOS (KAN-58) — motor
# ============================================================

# Aplica un estado con su MAGNITUD (daño/turno del DoT, la calcula el aplicador) y
# su DURACION propias. El apilado depende del stack_mode del estado (ver
# status_effects.gd): "none" (1 instancia, resetea+sube al mas fuerte), "merge" (1
# instancia con cuenta de stacks) o "independent" (cada aplicacion = un stack con su
# propia duracion; refresh_all reinicia la duracion de TODOS los stacks existentes).
# turns < 0 = duracion base del def; magnitude < 0 = magnitud por defecto del def.
# stack_cap (>=0) = tope de stacks que ESTA aplicacion puede alcanzar (habilidades/
# enemigos flojos capan a nivel bajo; ataques especiales, mas alto). -1 = tope del def.
func apply_status(id: int, turns: int = -1, magnitude: float = -1.0,
		stacks_add: int = 1, refresh_all: bool = false, stack_cap: int = -1) -> void:
	var d: Dictionary = StatusEffects.def(id)
	if d.is_empty():
		return
	if turns < 0:
		turns = int(d.get("turns", 3))
	if magnitude < 0.0:
		magnitude = float(d.get("dot_default", 0.0))
	var mode: String = String(d.get("stack_mode", "none"))
	var maxs: int = int(d.get("max_stacks", 99))
	if stack_cap >= 0:
		maxs = mini(maxs, stack_cap)   # esta aplicacion no puede pasar de su tope

	var nombre_estado: String = String(d.get("nombre", "?"))

	if mode == "independent":
		# Una habilidad puede reiniciar la duracion de TODOS los stacks existentes.
		if refresh_all:
			for e in statuses:
				if e.id() == id:
					e.turns = turns
		# Al tope: refresca el stack mas proximo a expirar (no añade otro).
		if _count_status(id) >= maxs:
			var viejo = _min_turns_status(id)
			if viejo != null:
				viejo.turns = turns
				viejo.magnitude = maxf(viejo.magnitude, magnitude)
			print("[estado] %s: %s al tope (%d stacks) -> refresca el mas viejo (mag %.2f, %d turnos)" % [
				nombre, nombre_estado, maxs, magnitude, turns])
			return
		var ni := StatusEffects.Instance.new(d, turns, 1)
		ni.magnitude = magnitude
		statuses.append(ni)
		print("[estado] %s recibe %s: +1 stack (%.2f/turno c/u, %d turnos) -> %d stacks" % [
			nombre, nombre_estado, magnitude, turns, _count_status(id)])
		return

	# "none" / "merge": una sola instancia por id.
	for e in statuses:
		if e.id() == id:
			e.turns = turns   # resetea la duracion
			e.magnitude = maxf(e.magnitude, magnitude)   # sube al mas fuerte
			if mode == "merge":
				e.stacks = mini(e.stacks + stacks_add, maxs)
			print("[estado] %s: %s re-aplicado (x%d, %.2f/turno, %d turnos)" % [
				nombre, nombre_estado, e.stacks, e.dot_damage(), turns])
			return
	var inst := StatusEffects.Instance.new(d, turns, mini(stacks_add, maxs) if mode == "merge" else 1)
	inst.magnitude = magnitude
	statuses.append(inst)
	print("[estado] %s recibe %s (x%d, %.2f/turno, %d turnos)" % [
		nombre, nombre_estado, inst.stacks, inst.dot_damage(), turns])


# Nº de instancias activas de un estado (para el tope de stacks independientes).
func _count_status(id: int) -> int:
	var n: int = 0
	for e in statuses:
		if e.id() == id:
			n += 1
	return n

# Instancia de ese estado mas proxima a expirar (menor 'turns'), o null si ninguna.
func _min_turns_status(id: int):
	var best = null
	for e in statuses:
		if e.id() == id and (best == null or e.turns < best.turns):
			best = e
	return best


# Tick AL INICIO del turno de este combatiente: aplica el DoT de todos sus estados,
# calcula si esta ATURDIDO (pierde el turno) y decrementa/expira duraciones.
# Devuelve {damage, stunned, expired:[nombres], dot:[etiquetas]} para el log.
func tick_statuses() -> Dictionary:
	var total_dmg: float = 0.0
	var stunned: bool = false
	var expired: Array = []
	var dot_labels: Array = []
	var kept: Array = []
	for e in statuses:
		if e.is_stun():
			stunned = true
		var dmg: float = e.dot_damage()
		if dmg > 0.0:
			total_dmg += dmg
			dot_labels.append("%s %.1f" % [str(e.d.get("icono", "?")), dmg])
		e.turns -= 1
		if e.turns <= 0:
			expired.append(str(e.d.get("nombre", "?")))
		else:
			kept.append(e)
	statuses = kept
	if total_dmg > 0.0:
		take_damage(total_dmg)
	# Log de consola para montar Excel (combate completo copiable). Un [estado] por
	# tick con el desglose de DoT + la vida resultante, mas expiraciones y aturdido.
	if total_dmg > 0.0:
		print("[estado] %s sufre DoT: %s = %.2f | HP %.2f/%.2f" % [
			nombre, " ".join(dot_labels), total_dmg, current_hp, max_hp])
	for nom in expired:
		print("[estado] %s: expira %s" % [nombre, nom])
	if stunned:
		print("[estado] %s aturdido: pierde el turno" % nombre)
	return {"damage": total_dmg, "stunned": stunned, "expired": expired, "dot": dot_labels}


# --- Consultas / agregadores ---
func has_status(id: int) -> bool:
	for e in statuses:
		if e.id() == id:
			return true
	return false

func status_atk_mult() -> float:
	var m: float = 1.0
	for e in statuses:
		m *= e.atk_mult()
	return m

func status_def_mult() -> float:
	var m: float = 1.0
	for e in statuses:
		m *= e.def_mult()
	return m

func status_spd_mult() -> float:
	var m: float = 1.0
	for e in statuses:
		m *= e.spd_mult()
	return m

# Multiplicador de la prob. de aturdir que RECIBE este combatiente (RAYO, KAN-58).
func stun_taken_mult() -> float:
	var m: float = 1.0
	for e in statuses:
		m *= e.stun_prob_mult()
	return m

# Tira los estados "al golpear" de este combatiente sobre 'target' (tras un golpe que
# acierta). Cada uno con su propia probabilidad. Devuelve los NOMBRES aplicados (para
# el log); vacio si ninguno prendio.
func roll_on_hit(target: Combatant) -> Array:
	var aplicados: Array = []
	if target == null:
		return aplicados
	for a in on_hit:
		if a.estado < 0:
			continue
		# La resistencia a estados del OBJETIVO baja la probabilidad de que prenda.
		var p: float = a.prob * (1.0 - target.status_resist)
		if randf() >= p:
			continue
		target.apply_status(a.estado, a.turns, a.magnitud, 1, false, a.cap)
		aplicados.append(str(StatusEffects.def(a.estado).get("nombre", "?")))
	return aplicados


# Resumen para la UI: "☠x2·3t 🔥·2t". Cadena vacia si no tiene estados.
func status_summary() -> String:
	if statuses.is_empty():
		return ""
	var partes: Array = []
	for e in statuses:
		partes.append(e.etiqueta())
	return " ".join(partes)
