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
# DEFENSA MAGICA base: lo que mitiga los hechizos que RECIBES, aunque tu Magia sea 0. Es el
# espejo de base_defense (que hace lo propio con los golpes fisicos). Sin esto, un bicho sin
# Magia recibe los hechizos a raw limpio, y la magia siempre gana. Ver StatsMath.resolve_spell.
var base_magic: float = 0.0

# Vida actual / maxima (se calculan al crear). current_hp es FLOAT para no perder
# precision con el daño decimal (asi ves mejoras pequeñas golpe a golpe).
var max_hp: float = 0.0
var current_hp: float = 0.0

# --- ENERGIA DE COMBATE (KAN-57) ---
# Es la MISMA stamina/aguante de exploracion: entras al combate con la que tengas y
# al salir lo que quede vuelve a tu stamina. Solo el JUGADOR la usa (enemigos = 0).
# Las HABILIDADES y DEFENDER la GASTAN; el ataque basico la REGENERA.
var max_energy: float = 0.0
var current_energy: float = 0.0

# --- MAGIA (KAN-56) ---
# Mana (maximo por Magia; enemigos = 0). current_mp es FLOAT por el regen fino.
var max_mp: float = 0.0
var current_mp: float = 0.0
# Hechizos equipados (Array[SpellData]). Vacio = no lanza magia (enemigos, o el
# jugador sin hechizos equipados).
var spells: Array = []
# Habilidades de combate disponibles (Array[AbilityData]), del loadout (KAN-57).
var abilities_combate: Array = []
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

# --- POSTURA DE CONTRAATAQUE del estoque ("En guardia", KAN-57). Flag TRANSITORIO que dura
# hasta tu proxima accion (como _player_defending, lo limpia el combate). Lleva sus propios
# numeros, copiados del AbilityData al activarla (data-driven). Neutros = sin postura. ---
var en_guardia: bool = false        # true = estas en la postura de guardia/contraataque
var guardia_spd_mult: float = 1.0   # multiplica tu velocidad mientras aguantas (< 1 = lento)
var guardia_contra_mult: float = 1.0    # daño del riposte al esquivar (vs un básico)

# Esquiva EXTRA por HABILIDADES/BUFFS (0 = ninguna). Generico: la suben la postura del
# estoque y (futuro) cualquier buff de esquiva. Si > 0, rompe el tope normal de esquiva
# (EVADE_MAX 0.35 -> EVADE_MAX_BUFF 0.65) en StatsMath.resolve_attack.
var evasion_bonus: float = 0.0

# --- FOCO ARCANO (Canalización reworkeada, KAN-56/57) ---
# Cargas que amplifican tus HECHIZOS: cada hechizo OFENSIVO que lanzas gasta 1 y pega
# +FOCO_BONUS. No expiran por turnos (aguantan el canto largo); se resetean por combate.
var foco_cargas: int = 0
const FOCO_BONUS := 0.30   # +30% de daño al hechizo con carga de Foco arcano

# Multiplicador de daño del hechizo por Foco arcano: 1+FOCO_BONUS si tienes carga (la GASTA),
# 1.0 si no. Lo llama combat.gd al disparar un hechizo OFENSIVO (los de buff/debuff no gastan).
func consumir_foco() -> float:
	if foco_cargas > 0:
		foco_cargas -= 1
		return 1.0 + FOCO_BONUS
	return 1.0

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
# Mapa AbilityData -> [indices de mano que la aportan] (KAN-57). Lo rellena Game.
# Sirve para el DUAL: una habilidad solo usa su version dual si AMBAS armas la traen.
var ability_hands: Dictionary = {}

# --- MODO PRUEBA (dev): muñeco de DPS / pegador de armadura ---
# es_dummy = este combatiente es un muñeco de pruebas (el combate loguea el DPS).
var es_dummy: bool = false
# dummy_dmg_out_mult multiplica el daño que HACE (Saco = 0: no pega). Neutro = 1.
var dummy_dmg_out_mult: float = 1.0
# Si >= 0, spd() devuelve esto (velocidad ESTANDAR fija, para cadencia de turnos regular).
var dummy_speed_override: float = -1.0
# invulnerable = no pierde vida (tests largos sin morir); el daño recibido se sigue logueando.
var invulnerable: bool = false

# --- ESTADOS ALTERADOS (KAN-58) ---
# Estados ACTIVOS sobre este combatiente (Array[StatusEffects.Instance]). El motor
# (apply/tick/agregadores) vive aqui; las definiciones en status_effects.gd.
var statuses: Array = []

# Estados que este combatiente aplica AL GOLPEAR (KAN-58 Fase 3). Array[StatusApplication].
# Lo rellena EnemyData (slimes: pegajoso/veneno) o el arma del jugador (futuro: sangrado).
var on_hit: Array = []

# HABILIDADES del enemigo (Array[AbilityData]) y probabilidad de usar una cada turno.
# Las rellena EnemyData; el jugador no las usa por aqui (tira de su loadout). Ver combat.gd.
# OJO: se llama 'habilidades' (no 'abilities') para no chocar con 'abilities' (las 5 stats).
var habilidades: Array = []
var prob_habilidad: float = 0.5

# Resistencia a ESTADOS alterados (0..1): MULTIPLICA a la baja la probabilidad de que
# te apliquen un estado negativo. La aporta la mejora Resistencia de la armadura (KAN-58).
var status_resist: float = 0.0

# --- SISTEMA ELEMENTAL (KAN-58) ---
# Afinidad propia; su perfil por defecto (Elementos.PERFIL_DEFECTO) define que resiste/le
# duele. resist_elemental = override arbitrario (Elemento -> mult), gana a la tabla (un
# minotauro puede resistir Fuego sin ser de fuego). inmune_estados = ids de StatusEffects.Id
# que este combatiente NO puede recibir (slime de fuego: inmune a Quemadura). Los rellena
# EnemyData; el jugador los deja neutros por ahora.
var elemento: int = Elementos.Elemento.NINGUNO
# FRANJA de la afinidad: 1.0 = PURO (una criatura hecha del elemento: ×0.5 / ×1.5), menos =
# mas suave. Un cuerpo imbuido va a INTENSIDAD_IMBUIDO (0.4 -> ×0.8 / ×1.2): no es lo mismo
# SER de fuego que haberte echado un manto por encima. No afecta a inmunidades (son binarias).
var elemento_intensidad: float = Elementos.INTENSIDAD_PURA
var resist_elemental: Dictionary = {}
var inmune_estados: Array = []

# Elemento del que va tu GOLPE ENTERO (lo usan los enemigos: el slime de fuego pega fuego).
# En el JUGADOR se queda siempre NINGUNO: su daño elemental sale de la IMBUICION (abajo), no
# de teñir el golpe entero — si no, contra un enemigo resistente se le partiria el daño base.
var elemento_ataque: int = Elementos.Elemento.NINGUNO

# --- IMBUICION (buff por combate, como foco_cargas) ---
# Añade una PORCION de daño elemental a tus golpes de arma: daño × (1 + imbue_pct × mult_elem).
# Es porcentual a proposito: escala sola con Fuerza/arma/mejoras/criticos y nunca hay que
# retunearla. La de CUERPO ademas fija tu 'elemento' (afinidad) -> resistencias, debilidades
# e inmunidades por la tabla; al expirar vuelve a NINGUNO.
var imbue_elemento: int = Elementos.Elemento.NINGUNO
var imbue_pct: float = 0.0
# Dura ATAQUES, no turnos: se gasta un uso por cada ATAQUE que lanzas (basico o habilidad),
# no por cada turno que pasa. Si durase turnos, recitar un conjuro largo te la fundiria antes
# de llegar a pegar un solo golpe con ella.
var imbue_usos: int = 0
var imbue_cuerpo: bool = false
# ESTADO que aplican tus golpes imbuidos (Quemadura / Rayo / Mojado) y su probabilidad BASE
# (en igualdad de poder). La prob. real la escala un contest de tu Magia vs su Resistencia.
var imbue_estado: int = -1
var imbue_prob: float = 0.0


# True si este combatiente NO puede recibir el estado 'id'. Tres vias:
#  - inmunidad a medida (inmune_estados): un minotauro peludo inmune a algo sin ser de ese elemento.
#  - su AFINIDAD elemental: un ser de fuego no se quema.
#  - un ESTADO que lleve encima: si estas Mojado no puedes arder.
func es_inmune(id: int) -> bool:
	if inmune_estados.has(id) or Elementos.inmunidades_de(elemento).has(id):
		return true
	for e in statuses:
		if e.inmuniza_a(id):
			return true
	return false


# Imbuye el arma (cuerpo = false) o el CUERPO (cuerpo = true) con un elemento.
func aplicar_imbue(elem: int, pct: float, usos: int, cuerpo: bool,
		estado: int = -1, prob: float = 0.0,
		intensidad: float = Elementos.INTENSIDAD_IMBUIDO) -> void:
	imbue_elemento = elem
	imbue_pct = pct
	imbue_usos = maxi(1, usos)
	imbue_cuerpo = cuerpo
	imbue_estado = estado
	imbue_prob = prob
	if cuerpo:
		# Afinidad: resistencias/debilidades/inmunidades por la tabla, pero en la franja
		# SUAVE del imbuido (no eres el elemento, te lo has puesto encima).
		elemento = elem
		elemento_intensidad = intensidad


# Etiqueta de la IMBUICION activa para el HUD ("" si no hay ninguna). DERIVADA de los campos:
# el icono dice si es de ARMA (🗡) o de CUERPO (🛡), y detras van el elemento, el bonus y los
# ATAQUES que le quedan. Ej: "🗡💧Agua +30%·4 ataques".
func imbue_etiqueta() -> String:
	if imbue_elemento == Elementos.Elemento.NINGUNO or imbue_usos <= 0:
		return ""
	return "%s%s%s +%d%%·%d ataque%s" % [
		"🛡" if imbue_cuerpo else "🗡", Elementos.icono(imbue_elemento),
		Elementos.nombre(imbue_elemento), roundi(imbue_pct * 100.0), imbue_usos,
		"" if imbue_usos == 1 else "s"]


# Tira el ESTADO de la imbuicion tras un golpe que ACIERTA. Devuelve su nombre si prende, ""
# si no. La probabilidad escala con tu Magia RELATIVA a la Resistencia del rival (ver
# StatsMath.imbue_proc_chance) y la baja su resistencia a estados. apply_status() ya corta
# solo si el objetivo es inmune (el slime de fuego no se quema).
func roll_imbue(target: Combatant) -> String:
	if imbue_estado < 0 or imbue_prob <= 0.0 or target == null:
		return ""
	if target.es_inmune(imbue_estado):
		return ""
	var p: float = StatsMath.imbue_proc_chance(imbue_prob, float(abilities.magia),
		float(target.abilities.resistencia)) * (1.0 - target.status_resist)
	if randf() >= p:
		return ""
	target.apply_status(imbue_estado)   # duracion/magnitud por defecto del catalogo
	return String(StatusEffects.def(imbue_estado).get("nombre", "?"))


# Gasta UN USO de la imbuicion: lo llama cada ATAQUE que lanzas (basico o habilidad), da igual
# cuantos golpes traiga o si fallan (el filo se desgasta al blandirlo). Los turnos que pases
# recitando, defendiendote o bebiendo NO la gastan.
# Al agotarse limpia el bonus y, si era de CUERPO, la afinidad. True si acaba de agotarse.
func consumir_imbue() -> bool:
	if imbue_usos <= 0:
		return false
	imbue_usos -= 1
	if imbue_usos > 0:
		return false
	if imbue_cuerpo:
		elemento = Elementos.Elemento.NINGUNO
		elemento_intensidad = Elementos.INTENSIDAD_PURA   # vuelve al valor neutro por defecto
	imbue_elemento = Elementos.Elemento.NINGUNO
	imbue_pct = 0.0
	imbue_cuerpo = false
	imbue_estado = -1
	imbue_prob = 0.0
	return true


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
func spd() -> float:
	if dummy_speed_override >= 0.0:
		return dummy_speed_override   # modo prueba: velocidad estandar fija
	return StatsMath.speed_value(abilities, level, base_speed) * velocidad_mult * status_spd_mult() * _guardia_spd()
# Velocidad al CASTEAR (KAN-95): igual que spd() pero con la velocidad de casteo.
func cast_spd() -> float: return StatsMath.speed_value(abilities, level, base_speed) * cast_velocidad_mult * status_spd_mult() * _guardia_spd()

# Penalizacion de velocidad de la postura de guardia (1.0 = sin postura).
func _guardia_spd() -> float: return guardia_spd_mult if en_guardia else 1.0

# Sale de la postura de guardia y resetea sus numeros (lo llama el combate al empezar tu
# turno: la postura dura "hasta tu proxima accion", como el Defender).
func salir_de_guardia() -> void:
	en_guardia = false
	guardia_spd_mult = 1.0
	guardia_contra_mult = 1.0
	evasion_bonus = 0.0

func is_alive() -> bool:
	return current_hp > 0.0

func take_damage(amount: float) -> void:
	if invulnerable:
		return   # modo prueba: no pierde vida (el daño recibido se loguea igual)
	current_hp = maxf(0.0, current_hp - amount)

# Cura vida SIN pasarse del maximo (pociones / Regeneración). No revive (si estas a 0
# es que ya perdiste el turno de tick).
func heal(amount: float) -> void:
	current_hp = minf(max_hp, current_hp + maxf(0.0, amount))


# --- Energia de combate (KAN-57) ---
func spend_energy(amount: float) -> void:
	current_energy = maxf(0.0, current_energy - amount)

func regen_energy(amount: float) -> void:
	current_energy = minf(max_energy, current_energy + amount)

func has_energy(amount: float) -> bool:
	return current_energy >= amount


# --- Cooldowns de habilidades (KAN-57) ---
# Turnos restantes por AbilityData. Se decrementa al inicio de cada turno (tick_cooldowns);
# es estado POR COMBATE (un Combatant nuevo por combate -> arranca vacio).
var ability_cooldowns: Dictionary = {}

# Turnos que le quedan a una habilidad para volver a estar disponible (0 = lista).
func ability_cd_left(ab) -> int:
	return int(ability_cooldowns.get(ab, 0))

func ability_ready(ab) -> bool:
	return ability_cd_left(ab) <= 0

# Arranca el cooldown de una habilidad tras usarla (si tiene).
func start_cooldown(ab) -> void:
	if ab != null and ab.cooldown > 0:
		ability_cooldowns[ab] = ab.cooldown

# Decrementa todos los cooldowns un turno (al inicio del turno del combatiente).
func tick_cooldowns() -> void:
	for ab in ability_cooldowns.keys():
		ability_cooldowns[ab] = maxi(0, int(ability_cooldowns[ab]) - 1)


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

# Activa una mano CONCRETA por indice (KAN-57: las habilidades golpean con el arma que
# las aporta, no con la que toque por el ciclo del dual). Fuera de rango = no hace nada.
func set_active_hand(i: int) -> void:
	if i >= 0 and i < hands.size():
		_hand_idx = i
		_apply_hand(i)

# Indices de mano (arma) que aportan esta habilidad (dual solo si son 2). Por defecto [0].
func ability_hand_indices(ab) -> Array:
	return ability_hands.get(ab, [0])

func ability_manos(ab) -> int:
	return maxi(1, ability_hand_indices(ab).size())

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
		stacks_add: int = 1, refresh_all: bool = false, stack_cap: int = -1,
		mult_override: float = 0.0) -> void:
	var d: Dictionary = StatusEffects.def(id)
	if d.is_empty():
		return
	# INMUNIDAD a estados (choke point unico): por AFINIDAD (el de fuego no se quema, el
	# imbuido en agua tampoco) o a medida. Cubre TODAS las vias (golpes, hechizos, skills
	# enemigas, teclas dev) porque todas pasan por aqui.
	if es_inmune(id):
		print("[estado] %s es INMUNE a %s" % [nombre, String(d.get("nombre", "?"))])
		return
	# Estados que APAGAN a otros al aplicarse: Mojado te apaga la Quemadura que llevaras.
	for id_apagado in (d.get("limpia", []) as Array):
		var quitados: int = _quitar_status(id_apagado)
		if quitados > 0:
			print("[estado] %s: %s APAGA %s" % [nombre, String(d.get("nombre", "?")),
				String(StatusEffects.def(id_apagado).get("nombre", "?"))])
	if turns < 0:
		turns = int(d.get("turns", 3))
	if magnitude < 0.0:
		magnitude = float(d.get("dot_default", 0.0))
		if magnitude <= 0.0:
			magnitude = float(d.get("heal_default", 0.0))   # Regeneración: cura por defecto (dev)
		if magnitude <= 0.0:
			magnitude = float(d.get("mana_default", 0.0))   # Regen. maná por defecto (dev)
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
		ni.mult_override = mult_override
		statuses.append(ni)
		print("[estado] %s recibe %s: +1 stack (%.2f/turno c/u, %d turnos) -> %d stacks" % [
			nombre, nombre_estado, magnitude, turns, _count_status(id)])
		return

	# "none" / "merge": una sola instancia por id.
	for e in statuses:
		if e.id() == id:
			e.turns = turns   # resetea la duracion
			e.fresh = true    # refrescar = como recien aplicado (se salta el proximo decremento)
			e.magnitude = maxf(e.magnitude, magnitude)   # sube al mas fuerte
			# Nivel de stat: se queda con el MAS FUERTE (mas lejos de 1.0).
			if mult_override > 0.0 and absf(mult_override - 1.0) > absf(e.base_stat_mult() - 1.0):
				e.mult_override = mult_override
			if mode == "merge":
				e.stacks = mini(e.stacks + stacks_add, maxs)
			print("[estado] %s: %s re-aplicado (x%d, %.2f/turno, %d turnos)" % [
				nombre, nombre_estado, e.stacks, e.dot_damage(), turns])
			return
	var inst := StatusEffects.Instance.new(d, turns, mini(stacks_add, maxs) if mode == "merge" else 1)
	inst.magnitude = magnitude
	inst.mult_override = mult_override
	statuses.append(inst)
	print("[estado] %s recibe %s (x%d, %.2f/turno, %d turnos)" % [
		nombre, nombre_estado, inst.stacks, inst.dot_damage(), turns])


# Quita TODAS las instancias de un estado. Devuelve cuantas quito (0 = no lo tenia).
func _quitar_status(id: int) -> int:
	var antes: int = statuses.size()
	var quedan: Array = []
	for e in statuses:
		if e.id() != id:
			quedan.append(e)
	statuses = quedan
	return antes - statuses.size()


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
# DoT y stun: aplican su efecto y decrementan/expiran normal. BUFFS/DEBUFFS de stat:
# se saltan el PRIMER decremento (flag 'fresh'), asi un buff/debuff de 3 turnos sigue
# activo durante la accion de los 3 turnos (si no, se "gasta" uno antes de poder usarlo).
func tick_statuses() -> Dictionary:
	var total_dmg: float = 0.0
	var total_heal: float = 0.0
	var total_mana: float = 0.0
	var stunned: bool = false
	var expired: Array = []
	var dot_labels: Array = []
	var heal_labels: Array = []
	var kept: Array = []
	for e in statuses:
		var dmg: float = e.dot_damage()
		var cura: float = e.heal_amount()
		var mana: float = e.mana_amount()
		# Buff/debuff de stat = ni DoT, ni cura, ni maná, ni stun (se salta el primer decremento).
		var es_stat: bool = dmg <= 0.0 and cura <= 0.0 and mana <= 0.0 and not e.is_stun()
		if e.is_stun():
			stunned = true
		if dmg > 0.0:
			total_dmg += dmg
			dot_labels.append("%s %.1f" % [str(e.d.get("icono", "?")), dmg])
		if cura > 0.0:
			total_heal += cura
			heal_labels.append("%s %.1f" % [str(e.d.get("icono", "?")), cura])
		if mana > 0.0:
			total_mana += mana
		if es_stat and e.fresh:
			e.fresh = false   # se salta el primer decremento: activo durante este turno
			kept.append(e)
			continue
		e.turns -= 1
		if e.turns <= 0:
			expired.append(str(e.d.get("nombre", "?")))
		else:
			kept.append(e)
	statuses = kept
	if total_dmg > 0.0:
		take_damage(total_dmg)
	if total_heal > 0.0:
		heal(total_heal)
	if total_mana > 0.0:
		regen_mana(total_mana)
	# Log de consola para montar Excel (combate completo copiable). Un [estado] por
	# tick con el desglose de DoT + la vida resultante, mas expiraciones y aturdido.
	if total_dmg > 0.0:
		print("[estado] %s sufre DoT: %s = %.2f | HP %.2f/%.2f" % [
			nombre, " ".join(dot_labels), total_dmg, current_hp, max_hp])
	if total_heal > 0.0:
		print("[estado] %s se cura: %s = %.2f | HP %.2f/%.2f" % [
			nombre, " ".join(heal_labels), total_heal, current_hp, max_hp])
	if total_mana > 0.0:
		print("[estado] %s recupera maná: %.2f | MP %.2f/%.2f" % [
			nombre, total_mana, current_mp, max_mp])
	for nom in expired:
		print("[estado] %s: expira %s" % [nombre, nom])
	if stunned:
		print("[estado] %s aturdido: pierde el turno" % nombre)
	return {"damage": total_dmg, "heal": total_heal, "mana": total_mana, "stunned": stunned,
		"expired": expired, "dot": dot_labels, "heal_labels": heal_labels}


# Cura que TODAVIA queda por dar de los estados de Regeneración activos (ticks restantes x
# cura por turno). Al terminar el combate se arrastra a la cura fuera de combate (KAN-57),
# para no malgastar una poción que no acabo de hacer efecto.
func regen_pendiente() -> float:
	var total: float = 0.0
	for e in statuses:
		if e.is_heal():
			total += e.heal_amount() * float(maxi(0, e.turns))
	return total

# Igual que regen_pendiente pero para el MANÁ (Regen. maná): lo que quedaba por restaurar.
func regen_mana_pendiente() -> float:
	var total: float = 0.0
	for e in statuses:
		if e.is_mana_heal():
			total += e.mana_amount() * float(maxi(0, e.turns))
	return total


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

# Multiplicador de la prob. de aturdir que RECIBE este combatiente. Lo SUBE el estado RAYO
# (x1.5) y lo BAJA la afinidad de Rayo (cuerpo imbuido: resistente al aturdimiento, no inmune).
func stun_taken_mult() -> float:
	var m: float = Elementos.stun_taken_por_afinidad(elemento)
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
		var mag: float = StatusEffects.app_magnitude(a, atk())   # sangrado escala con MI ataque
		target.apply_status(a.estado, a.turns, mag, 1, false, a.cap)
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
