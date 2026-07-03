# ============================================================
#  game.gd  (AUTOLOAD: se llama "Game" y esta disponible en todo el juego)
#  - Guarda las stats del JUGADOR (persisten entre combates, incluida la vida).
#  - Abre la pantalla de combate ENCIMA de la mazmorra (overlay) y pausa el
#    resto del juego mientras dura. Al terminar, reanuda y, si ganaste,
#    elimina al enemigo de la mazmorra.
# ============================================================

extends Node

# --- Stats del jugador (de momento fijas aqui; luego vendran de su .tres) ---
var player_level: int = 1
# Habilidades VISIBLES (las que usa el combate/capacidad). Empiezan a 0 y solo
# se actualizan al "volver al hogar" (tecla U -> actualizar_estado()).
var player_fuerza: int = 0
var player_resistencia: int = 0
var player_destreza: int = 0
var player_agilidad: int = 0
var player_magia: int = 0
var player_base_hp: float = 50.0
var player_base_attack: float = 5.0
var player_base_defense: float = 5.0
var player_base_speed: float = 5.0
# Vida actual (persiste entre combates). -1 = aun no inicializada (= llena).
var player_current_hp: float = -1.0

# --- Subida de habilidades (Excelia estilo DanMachi) ---
# Valor INTERNO (float) que sube con el uso. Lo visible (player_*) solo se
# sincroniza al "actualizar estado" (hogar). Rendimientos decrecientes segun
# el interno; dificultad relativa (enemigo/accion facil = sube poco).
var ability_internal: Dictionary = {
	"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
# Rendimientos decrecientes RELATIVOS AL TOPE: subes bien casi todo el camino
# y frena cerca de 999, pero con un SUELO para que nunca sea imposible.
# factor = max(FLOOR, (1 - interno/999)^POWER).
const ABILITY_CAP := 999.0
const DIMINISH_POWER := 0.8        # <1 = curva mas suave (aguanta mas arriba)
const DIMINISH_FLOOR := 0.15       # suelo: cerca de 999 sigues subiendo (lento, no 0)
const RETO_MAX := 8.0              # tope de dificultad relativa (enemigo muy superior = mas ganancia)
# Tope de reto SOLO para las stats FISICAS (Fuerza/Resistencia/Agilidad): mas
# bajo que el de Destreza (8) para que no se disparen contra enemigos superiores.
const RETO_MAX_FISICO := 5.0
# Suelo de PODER del jugador (solo lo usa reto() -> stats fisicas). A nivel 0 tu
# poder real es ~0; este suelo evita que CUALQUIER bicho te parezca amenaza
# maxima al arrancar (con 40, el slime por defecto de 125 da reto ~3, graduado).
# OJO: el minijuego de Destreza usa OTRO piso (EXTRACTION_DESTREZA_FLOOR), aparte.
const PODER_JUGADOR_SUELO := 40.0
# Ganancias base por fuente (ajustables).
const GAIN_FUERZA_ATAQUE := 0.15
const GAIN_FUERZA_PESO := 0.0    # DESACTIVADA por ahora (rediseñar sin romper escalado)
const GAIN_AGILIDAD_CORRER := 0.12
const GAIN_RESISTENCIA_GOLPE := 0.23
const GAIN_DESTREZA_MINIJUEGO := 2.2  # arranque (Destreza baja); el pivote de abajo modula el resto
# Fuentes de COMBATE para las stats que se farmean mal (bases altas: son eventos
# raros, no ocurren cada turno como el ataque):
const GAIN_AGILIDAD_ESQUIVAR := 0.6   # esquivar un golpe entrena Agilidad (adios correr en circulos)
const GAIN_AGILIDAD_CRITICO := 0.3    # clavar un critico entrena Agilidad (encontrar el hueco)
const GAIN_RESISTENCIA_BLOQUEO := 0.3 # bloquear con Defender entrena Resistencia extra (KAN-81); moderado para no sobre-premiar el escudo
# --- Dificultad de la extraccion ---
# Exigencia del enemigo = suma_habilidades x FACTOR. Dificultad relativa =
# exigencia / (tu Destreza + SUELO). ~1 = a la par; >1 mas dificil. La
# dificultad hace la zona mas pequeña Y el marcador mas rapido.
const EXTRACTION_REQ_FACTOR := 0.25
const EXTRACTION_BASE_ZONE := 0.16      # tamaño de zona a dificultad 1
const EXTRACTION_DESTREZA_FLOOR := 20.0 # skill base minimo (bajo: el novato SI sufre)
const EXTRACTION_BASE_MARKER := 0.8     # velocidad del marcador a dificultad 1
# Pivote para la GANANCIA de Destreza: solo aprendes de verdad si la extraccion
# fue dura PARA TI. Por debajo de este reto la ganancia cae en picado (curva ^2);
# por encima se mantiene. Sube el pivote para castigar mas las extracciones
# faciles (experto sacando de bichos flojos ~0); bajalo para lo contrario.
const EXTRACTION_DESTREZA_PIVOTE := 1.5
# Por ENCIMA del pivote la Destreza SIGUE subiendo con el reto (extraccion
# durisima = novato vs bicho superior = mucha mas Destreza), pero COMPRIMIDA por
# esta pendiente para no dispararse, y con un tope PROPIO mas alto que el global
# RETO_MAX (una extraccion brutal enseña mucho mas que una "solo dificil").
const EXTRACTION_DESTREZA_SLOPE := 0.65
const EXTRACTION_DESTREZA_RETO_MAX := 8.0

# Dificultad del ultimo minijuego de extraccion (para la ganancia de Destreza).
var _last_extraction_zone: float = 0.13
var _last_extraction_hits: int = 3

# Base de combate COMUN para los enemigos (los diferencia sus HABILIDADES).
# Cada EnemyData la ajusta con multiplicadores de arquetipo (por defecto 1.0).
var enemy_base_hp: float = 28.0
var enemy_base_attack: float = 3.0
var enemy_base_defense: float = 3.0
var enemy_base_speed: float = 4.0

var _combat_scene: PackedScene = preload("res://scenes/ui/combat.tscn")
var _extraction_script: GDScript = preload("res://scripts/ui/extraction.gd")
var _drop_pickup_script: GDScript = preload("res://scripts/items/drop_pickup.gd")
var _active_enemy: Node = null     # enemigo del combate en curso
var _active_layer: CanvasLayer = null  # capa donde vive la pantalla actual

# Profundidad actual de la mazmorra (para escalar dificultad). Aun sin pisos: 1.
var current_floor: int = 1

# True mientras el panel de inventario esta abierto: el jugador no se mueve ni
# interactua (pero el enemigo sigue y puede emboscarte).
var inventory_open: bool = false

# Cristales y drops obtenidos (inventario temporal hasta la Fase 6).
var crystals: Array[Cristal] = []
var drops: Array[MonsterDrop] = []

# Dinero (obtenido por vender cristales en la tienda).
var money: int = 0

# PRUEBAS: fuerza el drop al 100%. Poner en false para usar drop_chance real.
var dev_force_drop: bool = false

# PRUEBAS: peso inicial como % de la capacidad al arrancar (0 = nada).
var dev_start_weight_ratio: float = 0.0

# PRUEBAS: arrancar con este valor en TODAS las habilidades (interno+visible).
# 0 = empezar a 0 (normal). Util para revisar el escalado de la subida.
var dev_start_abilities: int = 0


func _ready() -> void:
	# TEMPORAL: arrancar con las habilidades a un valor para revisar el escalado.
	if dev_start_abilities > 0:
		for k in ability_internal:
			ability_internal[k] = float(dev_start_abilities)
		actualizar_estado()  # sincroniza lo visible con lo interno

	# TEMPORAL: relleno de cristales hasta ~X% de la capacidad para probar peso.
	if dev_start_weight_ratio > 0.0:
		var objetivo: float = dev_start_weight_ratio * capacidad_carga()
		while peso_actual() < objetivo and crystals.size() < 200:
			var c := Cristal.new()
			c.categoria = randi_range(1, 3)
			c.calidad = Cristal.Calidad.INTACTO
			crystals.append(c)

# Bonus de HERRAMIENTAS de recoleccion (cuchillos...). Placeholder hasta tener
# sistema de equipo: las herramientas rellenaran estos valores.
var tool_hit_reduction: int = 0    # reduce pulsaciones necesarias
var tool_destreza_bonus: int = 0   # Destreza extra para la extraccion

# --- Equipamiento: loadout de DOS manos (arma principal + secundaria) ---
# La secundaria puede ser otra WeaponData (dual-wield), un ShieldData o null.
# Un arma a dos manos (dos_manos) obliga a secundaria = null.
var equipped_main: WeaponData = preload("res://resources/weapons/punos.tres")
var equipped_off: Resource = null   # WeaponData | ShieldData | null
# Dual-wield: llevar arma en la secundaria acelera el ataque (mas turnos). La
# velocidad final tiene DOS componentes (ver loadout_mods):
#  1) Un bonus fijo por llevar dos armas, DECRECIENTE segun lo rapida que ya sea
#     la principal (a la daga, ya en el tope de 1 mano, se le da menos empujon
#     extra que a un arma lenta) para no desbordar frente a las armas a 2 manos.
#  2) Un extra que suma la PROPIA velocidad de la secundaria por encima de la
#     linea base (ONE_HAND_VEL_MIN): una daga de secundaria aporta velocidad de
#     verdad; una maza (vel base, ONE_HAND_VEL_MIN) no aporta nada extra, ni
#     tampoco resta - solo dejar de restar/promediar ya evita que te frene.
const DUAL_BONUS_SLOW := 0.30      # bonus (1) cuando la principal = ONE_HAND_VEL_MIN
const DUAL_BONUS_FAST := 0.10      # bonus (1) cuando la principal = ONE_HAND_VEL_MAX
const ONE_HAND_VEL_MIN := 1.0      # velocidad_mult del arma a 1 mano mas lenta (maza/espada larga)
const ONE_HAND_VEL_MAX := 1.35     # velocidad_mult del arma a 1 mano mas rapida (daga)
const OFF_HAND_SPEED_WEIGHT := 0.5 # cuanto de la velocidad "extra" de la secundaria se suma (2)
# Bloqueo base al Defender (sin secundaria); la secundaria/escudo suma encima.
const DEFEND_BLOCK_BASE := 0.30

# PRUEBAS: cambiar loadout en caliente (K = arma principal, L = mano secundaria).
var _dev_weapons: Array[String] = [
	"res://resources/weapons/punos.tres",
	"res://resources/weapons/daga.tres",
	"res://resources/weapons/espada_corta.tres",
	"res://resources/weapons/espada_larga.tres",
	"res://resources/weapons/maza_peq.tres",
	"res://resources/weapons/mandobles.tres",
	"res://resources/weapons/hacha_grande.tres",
	"res://resources/weapons/martillo_grande.tres",
]
var _dev_offs: Array = [
	null,
	"res://resources/weapons/daga.tres",
	"res://resources/weapons/espada_corta.tres",
	"res://resources/weapons/maza_peq.tres",
	"res://resources/shields/escudo_pequeno.tres",
	"res://resources/shields/escudo_normal.tres",
	"res://resources/shields/escudo_grande.tres",
]
var _dev_main_idx: int = 0
var _dev_off_idx: int = 0

# --- Peso / capacidad de carga ---
# De serie llevas un ZURRON pequeño (base_capacity). La Fuerza sube la
# capacidad. En el futuro: mochila y companero de apoyo sumaran aqui.
var base_capacity: float = 25.0        # zurron de serie
var extra_capacity: float = 0.0        # placeholder mochila/companero (futuro)
# La Fuerza MULTIPLICA la capacidad del contenedor (zurron+mochila) hasta un
# maximo (a Fuerza 999 = +50%). Asi no puedes llevar de todo con un zurron.
var fuerza_capacity_bonus_max: float = 0.5  # +50% a Fuerza maxima
# Sobrecarga GRADUAL: por encima del umbral, la penalizacion de velocidad crece
# con la pendiente hasta un maximo. Ej: 80% -> 0%, 90% -> ~33%, 100% -> ~66%.
var overload_threshold: float = 0.8    # % a partir del cual empiezas a ir lento
var overload_slope: float = 3.3        # cuanto crece la penalizacion por encima
var overload_max_penalty: float = 0.8  # penalizacion maxima (0.8 = -80% velocidad)


# Crea el Combatant del jugador con sus stats actuales (manteniendo la vida).
func crear_player_combatant() -> Combatant:
	var a := Abilities.new()
	a.fuerza = player_fuerza
	a.resistencia = player_resistencia
	a.destreza = player_destreza
	a.agilidad = player_agilidad
	a.magia = player_magia
	var c := Combatant.new("Heroe", player_level, a,
		player_base_hp, player_base_attack, player_base_defense, player_base_speed)
	if player_current_hp < 0.0:
		player_current_hp = float(c.max_hp)  # primera vez: vida llena
	c.current_hp = clampf(player_current_hp, 0.0, float(c.max_hp))

	# Aplicar los modificadores del loadout. Las MANOS (1 o 2) se alternan por
	# golpe en combate; set_hands activa la primera. El resto son del loadout entero.
	var m := loadout_mods()
	c.set_hands(m["hands"])
	c.velocidad_mult = m["velocidad_mult"]
	c.defend_block = m["defend_block"]
	c.evasion_penal = m["evasion_penal"]
	return c


# Combina la mano principal + la secundaria en los modificadores finales de
# combate. La secundaria aporta VELOCIDAD (dual) o BLOQUEO/penalizacion (escudo).
func loadout_mods() -> Dictionary:
	var main: WeaponData = equipped_main
	# Mods COMPARTIDOS (del loadout entero) + lista de MANOS (armas que alternan).
	var m := {
		"velocidad_mult": main.velocidad_mult,
		"defend_block": DEFEND_BLOCK_BASE,
		# El arma principal define lo escurridizo que eres (daga = +esquiva). Un
		# evasion_penal NEGATIVO = bonus de esquiva (los escudos suman penal, encima).
		"evasion_penal": -main.evasion_bonus,
		"hands": [_hand_from(main)],   # mano principal siempre
	}
	if main.dos_manos:
		# Arma grande a dos manos: sin secundaria, pero bloquea decente por su tamaño.
		m["defend_block"] += main.bloqueo
	elif equipped_off is ShieldData:
		var sh: ShieldData = equipped_off
		m["velocidad_mult"] *= sh.velocidad_mult   # el escudo te frena algo
		m["defend_block"] += sh.bloqueo            # pero bloquea mucho
		m["evasion_penal"] += sh.evasion_penal
	elif equipped_off is WeaponData:
		var off: WeaponData = equipped_off
		# Base: la velocidad de la PRINCIPAL con el bonus fijo de dual (decreciente
		# si la principal ya es rapida) + lo que aporte de mas la SECUNDARIA sobre
		# la linea base (una maza de secundaria no resta ni suma; una daga si suma).
		var frac := clampf((main.velocidad_mult - ONE_HAND_VEL_MIN) / (ONE_HAND_VEL_MAX - ONE_HAND_VEL_MIN), 0.0, 1.0)
		var dual_bonus := lerpf(DUAL_BONUS_SLOW, DUAL_BONUS_FAST, frac)
		var off_extra := maxf(0.0, off.velocidad_mult - ONE_HAND_VEL_MIN) * OFF_HAND_SPEED_WEIGHT
		m["velocidad_mult"] = main.velocidad_mult * (1.0 + dual_bonus) + off_extra
		m["defend_block"] += off.bloqueo            # bloqueo mediocre con arma
		# Dual: la secundaria es la 2ª mano -> se alterna con la principal golpe a
		# golpe. Cada arma conserva su MV/crit/aturdir propios (no se promedian).
		(m["hands"] as Array).append(_hand_from(off))
	# else: mano secundaria vacia -> una sola mano (la principal).
	return m


# Extrae los datos POR MANO de un arma (lo que cambia golpe a golpe en dual).
func _hand_from(w: WeaponData) -> Dictionary:
	return {
		"nombre": w.nombre,
		"motion_value": w.motion_value,
		"ataque_arma": w.ataque_base,
		"crit_bonus": w.crit_bonus,
		"dano_tipo": int(w.dano_tipo),
		"aturdir_base": w.aturdir_base,
	}


# True si ESTE loadout (con 'main' de principal) admite 'item' en la secundaria.
# Escudo o vacio: siempre (si la principal no es a 2 manos). Arma: debe permitir
# dual y, si la principal solo admite off-hand ligera (espada larga), ser ligera.
func _secundaria_valida(main: WeaponData, item: Resource) -> bool:
	if main.dos_manos:
		return false
	if item is WeaponData:
		var w: WeaponData = item
		if not w.puede_dual:
			return false
		if main.off_hand_solo_escudo:
			return false   # este main (espada larga) no admite NINGUN arma en off
	return true   # ShieldData o null

# Equipa un arma en la mano principal. Revalida la secundaria: si la nueva
# principal no la admite (2 manos, o solo-ligera), la quita.
func equipar_arma(w: WeaponData) -> void:
	equipped_main = w
	if not _secundaria_valida(w, equipped_off):
		equipped_off = null

# Equipa la mano secundaria (arma dual o escudo); null = vacia.
func equipar_secundaria(item: Resource) -> bool:
	if not _secundaria_valida(equipped_main, item):
		return false
	equipped_off = item
	return true


# --- Peso / capacidad ---
func capacidad_carga() -> float:
	var contenedor: float = base_capacity + extra_capacity
	var mult: float = 1.0 + clampf(player_fuerza / 999.0, 0.0, 1.0) * fuerza_capacity_bonus_max
	return contenedor * mult

func peso_actual() -> float:
	var w: float = 0.0
	for c in crystals:
		w += c.peso()
	for d in drops:
		w += d.peso()
	return w

func ratio_carga() -> float:
	var cap: float = capacidad_carga()
	return 0.0 if cap <= 0.0 else peso_actual() / cap

func esta_sobrecargado() -> bool:
	return ratio_carga() >= overload_threshold

# Multiplicador de velocidad por sobrecarga (1.0 = normal). Baja GRADUALMENTE
# cuanto mas te pasas del umbral, hasta un suelo (1 - overload_max_penalty).
func overload_speed_factor() -> float:
	var over: float = ratio_carga() - overload_threshold
	if over <= 0.0:
		return 1.0
	var penalty: float = clampf(over * overload_slope, 0.0, overload_max_penalty)
	return 1.0 - penalty


# --- Subida de habilidades ---

# Suma una ganancia al INTERNO de una habilidad, con rendimientos decrecientes.
# max_reto = tope del reto para ESTA ganancia. Por defecto RETO_MAX (8, el de
# Destreza); las stats fisicas pasan RETO_MAX_FISICO (5) para no dispararse.
func ganar(abil: String, reto_val: float, base: float, max_reto: float = RETO_MAX) -> void:
	if not ability_internal.has(abil):
		return
	var interno: float = ability_internal[abil]
	var factor: float = maxf(DIMINISH_FLOOR,
		pow(clampf(1.0 - interno / ABILITY_CAP, 0.0, 1.0), DIMINISH_POWER))
	var gain: float = base * clampf(reto_val, 0.0, max_reto) * factor
	ability_internal[abil] = interno + gain

# Poder del jugador (suma de visibles) con un suelo para no dividir por 0.
func poder_jugador_eff() -> float:
	var suma: float = float(player_fuerza + player_resistencia + player_destreza
		+ player_agilidad + player_magia)
	return maxf(suma, PODER_JUGADOR_SUELO)

# Dificultad relativa: enemigo/accion facil respecto a ti = poco.
func reto(poder_enemigo: float) -> float:
	return clampf(poder_enemigo / poder_jugador_eff(), 0.0, RETO_MAX)

# "Actualizar estado" (hogar / tu dios): aplica lo INTERNO a lo VISIBLE.
func actualizar_estado() -> void:
	player_fuerza = floori(ability_internal["fuerza"])
	player_resistencia = floori(ability_internal["resistencia"])
	player_destreza = floori(ability_internal["destreza"])
	player_agilidad = floori(ability_internal["agilidad"])
	player_magia = floori(ability_internal["magia"])
	print("=== ESTADO ACTUALIZADO ===  F:", player_fuerza, " R:", player_resistencia,
		" D:", player_destreza, " A:", player_agilidad, " M:", player_magia)


# Teclas de DESARROLLO (temporales): U actualizar estado, H cura, R respawn.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_U:
			actualizar_estado()
		KEY_H:
			player_current_hp = -1  # se rellena a tope en el proximo combate
			print("[dev] Vida al 100%")
		KEY_R:
			print("[dev] Respawn: recargando la mazmorra")
			get_tree().reload_current_scene()
		KEY_K:
			_dev_cycle_weapon()
		KEY_L:
			_dev_cycle_off()


# --- PRUEBAS: ciclar el loadout con el teclado ---
func _dev_cycle_weapon() -> void:
	_dev_main_idx = wrapi(_dev_main_idx + 1, 0, _dev_weapons.size())
	equipar_arma(load(_dev_weapons[_dev_main_idx]))
	if equipped_off == null:   # la nueva principal pudo invalidar la secundaria
		_dev_off_idx = 0
	_dev_print_loadout()

func _dev_cycle_off() -> void:
	if equipped_main.dos_manos:
		print("[dev] ", equipped_main.nombre, " es a dos manos: sin mano secundaria")
		return
	# Busca la SIGUIENTE secundaria valida para la principal actual (salta las que
	# no admite, p.ej. espada larga + otra arma pesada).
	for _i in range(_dev_offs.size()):
		_dev_off_idx = wrapi(_dev_off_idx + 1, 0, _dev_offs.size())
		var p: Variant = _dev_offs[_dev_off_idx]
		var item: Resource = null if p == null else load(p)
		if equipar_secundaria(item):
			_dev_print_loadout()
			return

func _dev_print_loadout() -> void:
	var off_name: String = "—"
	if equipped_off is WeaponData:
		off_name = (equipped_off as WeaponData).nombre + " (dual)"
	elif equipped_off is ShieldData:
		off_name = (equipped_off as ShieldData).nombre
	var m := loadout_mods()
	print("[dev] Loadout: ", equipped_main.nombre, " + ", off_name,
		"  | vel×:", m["velocidad_mult"], " bloqueo:", m["defend_block"],
		" esq-:", m["evasion_penal"], "  (manos alternan por golpe)")
	for h in m["hands"]:
		print("        mano ", h["nombre"], ": ATK ", h["ataque_arma"], " MV ", h["motion_value"],
			" crit+ ", h["crit_bonus"], " aturdir ", h["aturdir_base"])


# Abre el combate contra un enemigo de la mazmorra.
func start_combat(enemy_node: Node, enemy_data: EnemyData, enemy_initiated: bool) -> void:
	if _active_enemy != null or enemy_data == null:
		return  # ya hay un combate o faltan datos

	_active_enemy = enemy_node
	var player_c := crear_player_combatant()
	var power: float = 1.0
	if "current_power" in enemy_node:
		power = enemy_node.current_power
	var enemy_c := enemy_data.crear_combatant(power)

	# ¿El jugador entra agotado? (sus 2 primeras acciones seran mas lentas)
	var player_exhausted := false
	var pnode := get_tree().get_first_node_in_group("player")
	if pnode != null and pnode.has_method("is_exhausted"):
		player_exhausted = pnode.is_exhausted()

	var combat := _combat_scene.instantiate()
	# PROCESS_MODE_ALWAYS = el combate sigue funcionando aunque el arbol este en pausa.
	combat.process_mode = Node.PROCESS_MODE_ALWAYS
	combat.setup(player_c, enemy_c, enemy_initiated, player_exhausted, overload_speed_factor())
	combat.combat_finished.connect(_on_combat_finished)

	# Lo metemos en una CanvasLayer: asi NO le afecta la camara 2D de la
	# mazmorra (si no, la pantalla de combate sale descentrada).
	var layer := CanvasLayer.new()
	layer.layer = 100  # por encima de todo
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	layer.add_child(combat)
	_active_layer = layer

	get_tree().paused = true  # congela la mazmorra mientras luchas


# Abre el minijuego de extraccion sobre el cuerpo de un enemigo.
func start_extraction(corpse: Node) -> void:
	if _active_layer != null or corpse == null:
		return
	var data: EnemyData = corpse.data
	if data == null:
		return

	# Categoria ponderada por el poder del bicho (t).
	var t: float = 0.5
	if corpse.has_method("poder_normalizado"):
		t = corpse.poder_normalizado()
	var categoria: int = data.roll_crystal_category(t)
	var eff_destreza: int = player_destreza + tool_destreza_bonus

	# Exigencia del monstruo: sale de su FUERZA (suma de habilidades x su poder).
	var enemy_power: float = 1.0
	if "current_power" in corpse:
		enemy_power = corpse.current_power
	var enemy_suma: float = float(data.suma_habilidades(enemy_power))
	var req: float = maxf(1.0, enemy_suma * EXTRACTION_REQ_FACTOR)

	# Dificultad RELATIVA: exigencia del enemigo (su fuerza total) / tu DESTREZA
	# (solo Destreza, con suelo). ~1 = a la par; >1 mas dificil.
	var difficulty: float = req / (float(eff_destreza) + EXTRACTION_DESTREZA_FLOOR)
	var zone_ratio: float = clampf(EXTRACTION_BASE_ZONE / difficulty, 0.05, 0.35)

	# Pulsaciones: base del enemigo, ajustadas por la DIFICULTAD:
	#   dificil (enemigo muy superior) -> MAS pulsaciones (~2x = +1, ~3x = +2...);
	#   facil (tu muy superior) -> MENOS. Y las herramientas restan.
	# SIEMPRE minimo 3: una extraccion nunca es un "toque y listo".
	var ajuste_hits: int = 0
	if difficulty >= 1.0:
		ajuste_hits = floori(difficulty) - 1
	else:
		ajuste_hits = -(floori(1.0 / difficulty) - 1)
	var required_hits: int = maxi(3,
		data.extraction_hits + ajuste_hits - tool_hit_reduction)
	# Guardamos la dificultad para la ganancia de Destreza al terminar.
	_last_extraction_zone = zone_ratio
	_last_extraction_hits = required_hits
	# Marcador: mas rapido cuanto mas DIFICIL (y mas profundo el piso).
	var marker_speed: float = EXTRACTION_BASE_MARKER * clampf(difficulty, 0.6, 2.5) \
		+ float(current_floor - 1) * 0.08
	var speed_step: float = 0.15

	var ex: Control = _extraction_script.new()
	ex.process_mode = Node.PROCESS_MODE_ALWAYS
	ex.setup(categoria, required_hits, zone_ratio, marker_speed, speed_step)
	ex.extraction_finished.connect(_on_extraction_finished.bind(corpse))

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	layer.add_child(ex)
	_active_layer = layer
	get_tree().paused = true


func _on_extraction_finished(cristal: Cristal, corpse: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(corpse):
		corpse.extracted = true  # ya no se puede volver a extraer
		if corpse.has_method("desvanecer"):
			corpse.desvanecer()  # el cuerpo se desvanece y desaparece
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null

	if cristal != null and not cristal.se_pierde():
		crystals.append(cristal)
		print("Obtienes cristal categoria ", cristal.categoria,
			" (", cristal.calidad_texto(), "). Total: ", crystals.size())
		# Destreza: subes mas cuanto mas dificil era el minijuego PARA TI (zona
		# pequeña + mas pulsaciones = reto alto). El reto ya es relativo a tu
		# Destreza, asi que un experto sacando de un bicho flojo tiene reto bajo.
		var reto_bruto: float = (EXTRACTION_BASE_ZONE / _last_extraction_zone) \
			* (float(_last_extraction_hits) / 3.0)
		# Forma de la curva segun el reto que fue PARA TI:
		#  - reto <= pivote: curva ^2 que HUNDE lo facil (experto vs bicho flojo ~0);
		#    baja los casos "200 vs mismo nivel/debil".
		#  - reto  > pivote: SIGUE subiendo (lineal comprimido por SLOPE) hasta un
		#    tope propio ALTO; asi "novato vs bicho muy superior" (extraccion
		#    brutal) da mucha Destreza, no se queda capado como antes.
		var dificultad: float
		if reto_bruto <= EXTRACTION_DESTREZA_PIVOTE:
			dificultad = reto_bruto * reto_bruto / EXTRACTION_DESTREZA_PIVOTE
		else:
			dificultad = EXTRACTION_DESTREZA_PIVOTE \
				+ (reto_bruto - EXTRACTION_DESTREZA_PIVOTE) * EXTRACTION_DESTREZA_SLOPE
		dificultad = clampf(dificultad, 0.0, EXTRACTION_DESTREZA_RETO_MAX)
		ganar("destreza", dificultad, GAIN_DESTREZA_MINIJUEGO)
	else:
		print("El cristal se rompio: lo has perdido.")

	# Drop raro del monstruo (probabilidad baja; en pruebas, 100%).
	if cristal != null and is_instance_valid(corpse) and corpse.data != null:
		_tirar_drop(corpse, cristal.categoria)


# Tira (o no) el drop del monstruo. Si sale, aparece en el SUELO (para
# recogerlo con F) DESPUES de que el cuerpo se desvanezca.
func _tirar_drop(corpse: Node, categoria: int) -> void:
	var data: EnemyData = corpse.data
	var chance: float = 1.0 if dev_force_drop else data.drop_chance
	if randf() >= chance:
		return

	# Valor en una franja de 3 que se desplaza con la categoria del cristal.
	var base: int = maxi(1, categoria - 2)
	var valor: int = randi_range(base, base + 2)
	var drop := MonsterDrop.new()
	drop.nombre = data.drop_name
	drop.calidad = MonsterDrop.calidad_desde_valor(valor)

	var pos: Vector2 = corpse.global_position
	var parent: Node = corpse.get_parent()

	# Esperamos a que el cuerpo termine de desvanecerse, y entonces dejamos
	# el drop en el suelo donde estaba.
	await get_tree().create_timer(0.7).timeout
	if parent != null and is_instance_valid(parent):
		var pickup: Node2D = _drop_pickup_script.new()
		pickup.setup(drop)
		parent.add_child(pickup)
		pickup.global_position = pos
		print("El monstruo deja un drop en el suelo: ", drop.nombre,
			" (", drop.calidad_texto(), ")")


func _on_combat_finished(player_won: bool, player_hp_left: float) -> void:
	get_tree().paused = false
	player_current_hp = player_hp_left

	# Si ganaste, el enemigo NO desaparece: queda como cadaver para poder
	# extraerle el cristal (minijuego, Fase 5).
	if player_won and is_instance_valid(_active_enemy) and _active_enemy.has_method("morir"):
		_active_enemy.morir()
	_active_enemy = null

	# Quitamos la capa del combate (con la pantalla dentro).
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null
