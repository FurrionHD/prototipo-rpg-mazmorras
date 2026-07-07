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

# Huir (KAN-55): entrar agotado dificulta la huida (la probabilidad se multiplica).
const FLEE_EXHAUSTED_MULT := 0.6

# Magia (KAN-56): nº de opciones del test de recitado (a/b/c/d). El regen de mana
# por turno lo calcula StatsMath.mp_regen() (escala con la Magia).
const N_OPCIONES_TEST := 4

# Aturdir/retrasar (armas contundentes). Golpe NORMAL que aturde = retraso PARCIAL de
# barra ATB (stagger, franja de abajo). Golpe CRITICO que aturde = ESTADO Aturdido
# (pierde su proximo turno, lo gestiona el motor de estados). Ver _aplicar_aturdir.
const ATB_STUN_MIN := 0.30   # retraso parcial minimo (fraccion de barra)
const ATB_STUN_MAX := 0.60   # retraso parcial maximo

# Energia de combate (KAN-57): Defender y HABILIDADES gastan; el ataque basico regenera.
# Asi no puedes turtlear: hay que pegar para poder defender/soltar habilidades. PROVISIONAL.
const DEFEND_ENERGY_COST := 15.0
const ATTACK_ENERGY_REGEN := 12.0

@onready var _enemy_name: Label = $VBox/EnemyName
@onready var _enemy_hp: ProgressBar = $VBox/EnemyHP
@onready var _player_name: Label = $VBox/PlayerName
@onready var _player_hp: ProgressBar = $VBox/PlayerHP
@onready var _log: Label = $VBox/Log
# La escena trae un unico boton (AttackButton). Ahora las 4 acciones se crean por
# codigo (barra de acciones, KAN-55) y ESE boton se reutiliza como "Continuar" al
# terminar el combate.
@onready var _continue_button: Button = $VBox/AttackButton

# Sistema de ACCIONES (KAN-55): barra con Atacar / Magia / Defender / Huir. Se
# genera por codigo (convencion: UI por codigo por ahora) y es de datos, asi
# futuras acciones (habilidades, objetos) solo añaden una entrada.
enum Action { ATTACK, HABILIDAD, MAGIC, DEFEND, FLEE }
var _actions_box: HBoxContainer = null
var _action_buttons: Dictionary = {}   # Action(int) -> Button
var _ability_box: VBoxContainer = null   # submenu de habilidades (KAN-57)

# --- Casteo de hechizos (KAN-56) ---
# Submenu de hechizos (al pulsar Magia) y caja dinamica del recitado/disparo.
var _spell_box: VBoxContainer = null
var _cast_box: VBoxContainer = null
# Conjuro EN CURSO: hechizo elegido + cuantas frases llevas recitadas OK. Persiste
# entre turnos (recitas una por turno). null = no estas casteando.
var _cast_spell: SpellData = null
var _cast_index: int = 0

# Linea de ORDEN DE TURNOS (estilo Epic Seven), creada por codigo.
var _timeline: Control = null

# Se emite al cerrar el combate (lo escucha Game para reanudar la mazmorra).
# player_mp_left persiste el mana gastado (KAN-56); player_energy_left persiste la
# energia = stamina de exploracion (KAN-57).
signal combat_finished(player_won: bool, player_hp_left: float, player_mp_left: float, player_energy_left: float)

var _player: Combatant
var _enemy: Combatant
var _gauge: Dictionary = {}

enum State { ADVANCING, WAITING_PLAYER, PAUSED, FINISHED }
var _state: State = State.ADVANCING

# Pausa breve tras la accion del ENEMIGO para poder leer que hizo (las barras ATB
# se congelan durante la pausa). El combate corre con el arbol en pausa, pero esta
# escena tiene PROCESS_MODE_ALWAYS, asi que el tiempo (delta) sigue corriendo.
const ENEMY_TURN_PAUSE := 1.0   # segundos
var _pause_left: float = 0.0

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
		# Energia de prueba (F6): el jugador entra con la barra llena.
		_player.max_energy = 100.0
		_player.current_energy = 100.0

	_gauge = {_player: 0.0, _enemy: 0.0}
	# Iniciativa: quien empezo el combate arranca con media barra.
	if _enemy_initiated:
		_gauge[_enemy] = INICIATIVA_VENTAJA
	elif _injected:
		_gauge[_player] = INICIATIVA_VENTAJA

	# Si entro agotado, sus primeras acciones iran mas lentas.
	if _player_exhausted_start:
		_slow_actions_left = EXHAUSTED_SLOW_ACTIONS

	_continue_button.text = "Continuar"
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	_crear_acciones()
	_setup_ui()
	_crear_timeline()
	_crear_estados_dev()  # herramienta de test de estados (KAN-58 Fase 1)
	var intro: String
	if _enemy_initiated:
		intro = "¡" + _enemy.nombre + " te sorprende! Tiene la iniciativa."
	elif _injected:
		intro = "¡Ataque por la espalda! Tienes la iniciativa. 🗡️"
	else:
		intro = "¡Empieza el combate contra " + _enemy.nombre + "!"
	if _player_exhausted_start:
		intro += "  (Agotado: tus primeras acciones son mas lentas)"
	_set_log(intro)

	# Marca de INICIO en consola (para separar combates al montar los Excel).
	var quien: String = "enemigo" if _enemy_initiated else "jugador"
	print("[combate] ===== INICIO vs %s (Nv.%d) HP %.2f | %s HP %.2f%s | iniciativa: %s =====" % [
		_enemy.nombre, _enemy.level, _enemy.max_hp, _player.nombre, _player.max_hp,
		("" if _player.max_mp <= 0.0 else " MP %.2f" % _player.max_mp), quien])


# Crea la barra de acciones (KAN-55): Atacar / Magia / Defender / Huir, de datos.
func _crear_acciones() -> void:
	# Espaciador: baja un pelin los botones de accion para que no queden pegados al log.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	$VBox.add_child(spacer)
	_actions_box = HBoxContainer.new()
	$VBox.add_child(_actions_box)
	var defs := [
		[Action.ATTACK, "Atacar"],
		[Action.HABILIDAD, "Habilidad"],
		[Action.MAGIC, "Magia"],
		[Action.DEFEND, "Defender"],
		[Action.FLEE, "Huir"],
	]
	for d in defs:
		var b := Button.new()
		b.text = d[1]
		var id: int = d[0]
		b.pressed.connect(_on_action.bind(id))
		_actions_box.add_child(b)
		_action_buttons[id] = b
	# Cajas de magia (KAN-56): submenu de hechizos y caja del recitado/disparo.
	_spell_box = VBoxContainer.new()
	$VBox.add_child(_spell_box)
	_cast_box = VBoxContainer.new()
	$VBox.add_child(_cast_box)
	# Submenu de habilidades (KAN-57).
	_ability_box = VBoxContainer.new()
	$VBox.add_child(_ability_box)
	_ocultar_cajas()


# Oculta las tres cajas del turno del jugador (acciones / submenu magia / recitado).
func _ocultar_cajas() -> void:
	if _actions_box != null: _actions_box.visible = false
	if _spell_box != null: _spell_box.visible = false
	if _cast_box != null: _cast_box.visible = false
	if _ability_box != null: _ability_box.visible = false


func _setup_ui() -> void:
	_player_hp.max_value = _player.max_hp
	_enemy_hp.max_value = _enemy.max_hp
	_player_hp.show_percentage = false
	_enemy_hp.show_percentage = false
	# El log siempre muestra LOG_MAX lineas (ver _set_log), asi que ocupa un alto FIJO y
	# los botones no se mueven. clip_text evita que una linea larga se derrame a la dcha.
	_log.clip_text = true
	_update_hp()
	_continue_button.visible = false
	_ocultar_cajas()


func _update_hp() -> void:
	_player_hp.value = _player.current_hp
	_enemy_hp.value = _enemy.current_hp
	_enemy_name.text = "%s  (Nv.%d)   %.2f/%.2f%s" % [
		_enemy.nombre, _enemy.level, _enemy.current_hp, _enemy.max_hp, _estados_txt(_enemy)]
	# El jugador muestra ademas su MANA (KAN-56) y su ENERGIA (KAN-57) si tiene.
	var mp_txt := ""
	if _player.max_mp > 0.0:
		mp_txt = "   MP %.2f/%.2f" % [_player.current_mp, _player.max_mp]
	var en_txt := ""
	if _player.max_energy > 0.0:
		en_txt = "   EN %.1f/%.1f" % [_player.current_energy, _player.max_energy]
	_player_name.text = "%s  (Nv.%d)   %.2f/%.2f%s%s%s" % [
		_player.nombre, _player.level, _player.current_hp, _player.max_hp, mp_txt, en_txt, _estados_txt(_player)]


# Estados alterados para la etiqueta del combatiente (KAN-58). "" si no tiene.
func _estados_txt(c: Combatant) -> String:
	var s: String = c.status_summary()
	return "\n   " + s if s != "" else ""


func _process(delta: float) -> void:
	_update_timeline()  # refleja el orden de turnos siempre
	# Pausa de lectura tras la accion del enemigo: cuenta atras y reanuda el ATB.
	if _state == State.PAUSED:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_state = State.ADVANCING
		return
	if _state != State.ADVANCING:
		return

	# Si estamos en una accion lenta por agotamiento, el jugador llena su
	# barra a mitad de ritmo.
	var player_rate: float = SPEED_SCALE
	if _slow_actions_left > 0:
		player_rate *= EXHAUSTED_RATE
	player_rate *= _player_overload_factor
	# Al CASTEAR (KAN-95) la barra se llena a la velocidad de casteo (la varita del
	# mago hibrido la cambia respecto al arma principal); si no, la velocidad normal.
	var pspeed: float = _player.cast_spd() if _cast_spell != null else _player.spd()
	_gauge[_player] += pspeed * delta * player_rate
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
	_player.tick_cooldowns()   # habilidades (KAN-57): baja 1 turno los cooldowns activos
	# Estados alterados (KAN-58): tick al inicio del turno (DoT, expira, aturdido).
	var ev: Dictionary = _player.tick_statuses()
	_log_tick(_player, ev)
	_update_hp()
	if not _player.is_alive():
		_set_log("%s cae por el daño de sus estados. ☠" % _player.nombre)
		_end(false)   # el DoT (veneno...) puede matarte
		return
	if ev.stunned:
		_set_log("%s esta aturdido y pierde el turno. 💫" % _player.nombre)
		_pausa_lectura()
		return
	# Regen de maná: escala con la Magia (KAN-56) + el bonus del arma mágica (KAN-95).
	_player.regen_mana(StatsMath.mp_regen(float(_player.abilities.magia)) + _player.mp_regen_bonus)
	_update_hp()
	# Si estas casteando un hechizo, el turno va al recitado / disparo, NO a las
	# acciones normales (por diseño no puedes hacer otra cosa mientras cantas).
	if _cast_spell != null:
		if _cast_index < _cast_spell.longitud():
			_mostrar_test(_cast_index)
		else:
			_mostrar_disparo()
	else:
		_mostrar_acciones()


# Apila en el log los eventos del tick de estados: DoT sufrido (con iconos) y
# estados que se disipan. No hace nada si el turno no traia eventos.
func _log_tick(c: Combatant, ev: Dictionary) -> void:
	if float(ev.damage) > 0.0:
		_set_log("%s sufre %s (%.2f)." % [c.nombre, ", ".join(ev.dot), float(ev.damage)])
	if not (ev.expired as Array).is_empty():
		_set_log("A %s se le disipa: %s." % [c.nombre, ", ".join(ev.expired)])


# Muestra la barra de acciones normales (Atacar/Magia/Defender/Huir).
func _mostrar_acciones() -> void:
	_ocultar_cajas()
	_actions_box.visible = true
	_refresh_actions()
	_set_log("¡Tu turno! Elige una accion.")


# Habilita/inhabilita cada accion segun disponibilidad (en tu turno).
func _refresh_actions() -> void:
	for id in _action_buttons:
		_action_buttons[id].disabled = not _accion_disponible(id)
	_action_buttons[Action.MAGIC].tooltip_text = (
		"" if _hay_hechizos() else "No tienes hechizos equipados")
	_action_buttons[Action.DEFEND].tooltip_text = (
		"" if _player.has_energy(DEFEND_ENERGY_COST) else "Sin energia (ataca para regenerar)")
	_action_buttons[Action.HABILIDAD].tooltip_text = (
		"" if not _player.abilities_combate.is_empty() else "Tu equipo no aporta habilidades")


func _accion_disponible(id: int) -> bool:
	match id:
		Action.ATTACK: return true
		Action.DEFEND: return _player.has_energy(DEFEND_ENERGY_COST)   # Defender cuesta energia
		Action.FLEE: return true
		Action.MAGIC: return _hay_hechizos()
		Action.HABILIDAD: return not _player.abilities_combate.is_empty()
	return false


# ¿El jugador tiene hechizos equipados? (KAN-56)
func _hay_hechizos() -> bool:
	return _player != null and _player.spells.size() > 0


# Oculta la barra tras elegir y consume una "accion lenta" si entraste agotado.
func _fin_de_eleccion() -> void:
	_ocultar_cajas()
	if _slow_actions_left > 0:
		_slow_actions_left -= 1


# Despacha la accion elegida (solo en tu turno).
func _on_action(id: int) -> void:
	if _state != State.WAITING_PLAYER:
		return
	match id:
		Action.ATTACK: _accion_atacar()
		Action.DEFEND: _accion_defender()
		Action.FLEE: _accion_huir()
		Action.MAGIC: _accion_magia()
		Action.HABILIDAD: _accion_habilidad()


# El boton reutilizado (antes "Atacar") cierra la pantalla al terminar el combate.
func _on_continue_pressed() -> void:
	if _state != State.FINISHED:
		return
	combat_finished.emit(_player_won, _player.current_hp, _player.current_mp, _player.current_energy)
	# Si lo abrio Game, el cierra la capa; si es prueba (F6), nos cerramos solos.
	if not _injected:
		queue_free()


# ============================================================
#  MAGIA (KAN-56): submenu de hechizos + recitado por frases + disparo
# ------------------------------------------------------------
# Accion Magia: abre el submenu con los hechizos equipados y su coste de mana.
func _accion_magia() -> void:
	_ocultar_cajas()
	# Reconstruimos el submenu cada vez (el mana cambia -> disponibilidad).
	for c in _spell_box.get_children():
		c.queue_free()
	for spell in _player.spells:
		var b := Button.new()
		var coste: float = _coste_efectivo(spell)
		b.text = "%s  (%.2f MP · %d frase%s)" % [
			spell.nombre, coste, spell.longitud(),
			"" if spell.longitud() == 1 else "s"]
		if not _player.has_mana(coste):
			b.disabled = true
			b.tooltip_text = "Mana insuficiente"
		b.pressed.connect(_elegir_hechizo.bind(spell))
		_spell_box.add_child(b)
	var volver := Button.new()
	volver.text = "◄ Volver"
	volver.pressed.connect(_mostrar_acciones)
	_spell_box.add_child(volver)
	_spell_box.visible = true
	_set_log("Elige un hechizo para recitar.")


# Coste de maná EFECTIVO tras la mejora Eficiencia del equipo (KAN-95). FLOAT (sin
# redondeo hacia arriba: así CUALQUIER % de Eficiencia se nota). Mínimo 0.5.
func _coste_efectivo(spell: SpellData) -> float:
	return maxf(0.5, float(spell.coste_mana) * (1.0 - _player.mana_reduccion))


# Empiezas a castear: se descuenta el mana YA (si fallas lo pierdes) y recitas la
# primera frase en este MISMO turno.
func _elegir_hechizo(spell: SpellData) -> void:
	var coste: float = _coste_efectivo(spell)
	if not _player.has_mana(coste):
		return
	_player.spend_mana(coste)
	_update_hp()
	_cast_spell = spell
	_cast_index = 0
	_mostrar_test(0)


# Muestra el test tipo examen para la frase idx del hechizo en curso.
func _mostrar_test(idx: int) -> void:
	_ocultar_cajas()
	for c in _cast_box.get_children():
		c.queue_free()
	var correcta: String = _cast_spell.frases[idx]
	var opciones := SpellBook.opciones_test(correcta, _otras_frases_equipadas(), N_OPCIONES_TEST)
	var letras := ["a", "b", "c", "d", "e", "f"]
	for i in opciones.size():
		var b := Button.new()
		b.text = "%s)  %s" % [letras[i], opciones[i]]
		b.pressed.connect(_responder_frase.bind(String(opciones[i]), correcta))
		_cast_box.add_child(b)
	_cast_box.visible = true
	_set_log("🔮 %s — recita la frase %d/%d:" % [
		_cast_spell.nombre, idx + 1, _cast_spell.longitud()])


# Frases de los OTROS hechizos equipados (para nutrir los distractores del test).
func _otras_frases_equipadas() -> Array:
	var pool: Array = []
	for spell in _player.spells:
		if spell != _cast_spell:
			for f in spell.frases:
				pool.append(f)
	return pool


# Responde una frase del test: acierto -> avanza; fallo -> backfire.
func _responder_frase(elegida: String, correcta: String) -> void:
	if _state != State.WAITING_PLAYER:
		return
	if elegida == correcta:
		# La Magia NO se entrena por frase (solo al LANZAR, en _disparar_hechizo), para
		# que la ganancia sea predecible y no se cuente doble.
		_cast_index += 1
		if _cast_index < _cast_spell.longitud():
			_set_log("✓ Frase correcta. Continua el proximo turno...")
		else:
			_set_log("✓ ¡Encantamiento completo! El proximo turno lo lanzas.")
		_fin_de_eleccion()
		_state = State.ADVANCING
	else:
		_backfire()


# Turno de DISPARO: un unico boton para lanzar el hechizo ya recitado.
func _mostrar_disparo() -> void:
	_ocultar_cajas()
	for c in _cast_box.get_children():
		c.queue_free()
	var b := Button.new()
	b.text = "🔥 ¡Lanzar %s!" % _cast_spell.nombre
	b.pressed.connect(_disparar_hechizo)
	_cast_box.add_child(b)
	_cast_box.visible = true
	_set_log("El conjuro esta listo. ¡Lanzalo!")


func _disparar_hechizo() -> void:
	if _state != State.WAITING_PLAYER:
		return
	var spell := _cast_spell
	# DAÑO solo para hechizos de ATAQUE (los de BUFF/DEBUFF no pegan, solo aplican estado).
	var dano: float = 0.0
	if spell.tipo == SpellData.TipoEfecto.ATAQUE:
		dano = StatsMath.resolve_spell(_player, _enemy, spell).damage
		_enemy.take_damage(dano)
		_set_log("🔥 %s impacta a %s por %.2f de daño." % [spell.nombre, _enemy.nombre, dano])
	else:
		_set_log("✨ %s lanza %s." % [_player.nombre, spell.nombre])
	# Estado alterado del hechizo (quemadura/rayo al enemigo, buff/debuff), KAN-58 Fase 3.
	_aplicar_estado_hechizo(spell)
	# Excelia (formula dedicada de Magia): entrena al LANZAR, escalado por el mana
	# gastado (hechizos caros = mas potentes = entrenan mas) x reto del enemigo.
	var mana_factor: float = float(spell.coste_mana) / Game.MAGIA_COSTE_REF
	Game.ganar("magia", Game.reto(_poder_enemigo()), Game.GAIN_MAGIA_CAST * mana_factor, Game.RETO_MAX_FISICO)
	print("[magia] %s lanza %s | dano:%.2f (Magia %d)" % [
		_player.nombre, spell.nombre, dano, _player.abilities.magia])
	_limpiar_casteo()
	_update_hp()
	_fin_de_eleccion()
	if not _enemy.is_alive():
		_end(true)
	else:
		_state = State.ADVANCING


# Aplica (o no) los estados del hechizo. Al ENEMIGO = con PROBABILIDAD (sube con la
# longitud del hechizo; el enemigo puede resistir). A UNO MISMO (buff) = siempre.
func _aplicar_estado_hechizo(spell: SpellData) -> void:
	for a in spell.efectos:
		if a.estado < 0:
			continue
		var al_enemigo: bool = a.en_objetivo
		var objetivo: Combatant = _enemy if al_enemigo else _player
		var nom: String = str(StatusEffects.def(a.estado).get("nombre", "?"))
		if al_enemigo:
			# La resistencia a estados del objetivo baja la probabilidad efectiva.
			var p: float = spell.efecto_prob(a) * (1.0 - objetivo.status_resist)
			if randf() >= p:
				_set_log("… pero %s resiste el %s. (%.0f%%)" % [_enemy.nombre, nom, p * 100.0])
				print("[estado] %s RESISTE %s del hechizo (prob %.0f%%)" % [_enemy.nombre, nom, p * 100.0])
				continue
		objetivo.apply_status(a.estado, a.turns, a.magnitud, 1, false, a.cap)
		_set_log("✨ %s: %s recibe %s." % [spell.nombre, objetivo.nombre, nom])


# Fallar una frase: el conjuro se descontrola. Daño propio (mayor cuanto mas
# avanzado ibas), el mana ya gastado se pierde y el conjuro se interrumpe.
func _backfire() -> void:
	var spell := _cast_spell
	var dmg := StatsMath.backfire_damage(spell, _cast_index, spell.longitud())
	_player.take_damage(dmg)
	print("[magia] BACKFIRE %s | frase %d/%d | dano propio:%.2f" % [
		spell.nombre, _cast_index + 1, spell.longitud(), dmg])
	_set_log("💥 Recitas mal el conjuro y se descontrola: %.2f de daño. El hechizo se pierde." % dmg)
	_limpiar_casteo()
	_update_hp()
	_fin_de_eleccion()
	if not _player.is_alive():
		_end(false)
	else:
		_state = State.ADVANCING


func _limpiar_casteo() -> void:
	_cast_spell = null
	_cast_index = 0


# ============================================================
#  HABILIDADES (KAN-57): submenu del loadout + resolucion
# ------------------------------------------------------------
func _accion_habilidad() -> void:
	_ocultar_cajas()
	for c in _ability_box.get_children():
		c.queue_free()
	var manos: int = maxi(1, _player.hands.size())
	for ab in _player.abilities_combate:
		var coste: float = ab.coste(manos)
		var cd_left: int = _player.ability_cd_left(ab)
		var b := Button.new()
		var cd_txt := "  ⏳%d" % cd_left if cd_left > 0 else ""
		b.text = "%s  (%.0f EN)%s" % [ab.nombre, coste, cd_txt]
		if cd_left > 0:
			b.disabled = true
			b.tooltip_text = "En cooldown: %d turno%s" % [cd_left, "" if cd_left == 1 else "s"]
		elif not _player.has_energy(coste):
			b.disabled = true
			b.tooltip_text = "Sin energia suficiente"
		b.pressed.connect(_usar_habilidad.bind(ab))
		_ability_box.add_child(b)
	var volver := Button.new()
	volver.text = "◄ Volver"
	volver.pressed.connect(_mostrar_acciones)
	_ability_box.add_child(volver)
	_ability_box.visible = true
	_set_log("Elige una habilidad. (EN = energia)")


func _usar_habilidad(ab: AbilityData) -> void:
	var manos: int = maxi(1, _player.hands.size())
	var coste: float = ab.coste(manos)
	if _state != State.WAITING_PLAYER or not _player.has_energy(coste) or not _player.ability_ready(ab):
		return
	_player.spend_energy(coste)
	_player.start_cooldown(ab)   # entra en cooldown (si la habilidad tiene)
	var golpes: int = ab.num_golpes(manos)
	# Cabecera en consola; debajo, cada golpe indentado (crit/esquivado/daño + estados).
	print("[habilidad] %s usa %s  (%s, %.0f EN)" % [
		_player.nombre, ab.nombre, ("dual" if manos >= 2 else "1 mano"), coste])
	# GOLPES de daño (rango aleatorio; cada tajo con su ESQUIVA y CRITICO propios). Si
	# efectos_por_golpe, cada tajo que acierta tira los efectos (sangrado 40%/hit).
	var total: float = 0.0
	var conecto: int = 0
	var hubo_critico: bool = false   # para los efectos NO por golpe (tirada al final)
	var estados_log: Array = []
	for i in golpes:
		var result := StatsMath.resolve_attack(_player, _enemy, false)
		var linea := ""
		if result.evaded:
			linea = "golpe %d: esquivado 💨" % [i + 1]
		else:
			var dmg: float = result.damage * ab.dano_mult
			total += dmg
			_enemy.take_damage(dmg)
			conecto += 1
			if result.crit:
				hubo_critico = true
			linea = "golpe %d: %s %.2f" % [i + 1, ("CRITICO 💥" if result.crit else "acierta"), dmg]
			if ab.efectos_por_golpe and _enemy.is_alive():
				var ap: Array = _tirar_efectos_habilidad(ab, result.crit)
				estados_log += ap
				if not ap.is_empty():
					linea += "  -> " + ", ".join(ap)
		print("        " + linea)
		_player.advance_hand()   # dual: el siguiente golpe con la otra mano
		if not _enemy.is_alive():
			break
	# Efectos NO por golpe: UNA tirada al final si conecto algo (golpe de escudo -> stun).
	if not ab.efectos_por_golpe and conecto > 0 and _enemy.is_alive():
		estados_log += _tirar_efectos_habilidad(ab, hubo_critico)
	if ab.bloqueo_turnos > 0:
		_player_defending = true   # golpe de escudo: te deja en guardia
	# Excelia: como el ataque, entrena Fuerza (por impacto medio).
	Game.ganar("fuerza", Game.reto(_poder_enemigo()) * _player.motion_value, Game.GAIN_FUERZA_ATAQUE,
		Game.RETO_MAX_FISICO)
	print("        total: %.2f de daño en %d golpe%s | EN -%.0f -> %.1f/%.1f" % [
		total, golpes, "" if golpes == 1 else "s", coste, _player.current_energy, _player.max_energy])
	var msg := "%s usa %s: %.2f de daño (%d golpe%s)." % [
		_player.nombre, ab.nombre, total, golpes, "" if golpes == 1 else "s"]
	if not estados_log.is_empty():
		msg += "  Aplica: %s." % ", ".join(estados_log)
	if ab.bloqueo_turnos > 0:
		msg += "  🛡️ En guardia."
	_set_log(msg)
	_update_hp()
	_fin_de_eleccion()
	if not _enemy.is_alive():
		_end(true)
	else:
		_state = State.ADVANCING


# Tira los efectos de una habilidad sobre el enemigo (cada uno con su prob y la
# resistencia a estados del rival). Devuelve los NOMBRES de los que prenden.
func _tirar_efectos_habilidad(ab: AbilityData, fue_critico: bool = false) -> Array:
	var out: Array = []
	for a in ab.efectos:
		if a.estado < 0:
			continue
		if a.solo_crit and not fue_critico:
			continue   # efecto reservado al critico (p.ej. 2o sangrado de la Punalada)
		if randf() < a.prob * (1.0 - _enemy.status_resist):
			var mag: float = StatusEffects.app_magnitude(a, _player.atk())
			_enemy.apply_status(a.estado, a.turns, mag, 1, false, a.cap)
			out.append(str(StatusEffects.def(a.estado).get("nombre", "?")))
	return out


func _accion_atacar() -> void:
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
		# Estados "al golpear" del jugador (arma; futuro: sangrado de cortantes).
		for nom in _player.roll_on_hit(_enemy):
			txt += "  Le infliges %s." % nom
		_set_log(txt)
	# El ataque basico REGENERA energia (KAN-57): te "cargas" pegando.
	_player.regen_energy(ATTACK_ENERGY_REGEN)
	_update_hp()
	_player.advance_hand()  # dual-wield: el proximo golpe sera con la otra mano
	_fin_de_eleccion()

	if not _enemy.is_alive():
		_end(true)
	else:
		_state = State.ADVANCING


# Accion Defender (KAN-54): mitiga el proximo daño y anula criticos en tu contra
# hasta tu siguiente turno. Cuesta el turno (no atacas).
func _accion_defender() -> void:
	_player.spend_energy(DEFEND_ENERGY_COST)   # Defender consume energia (KAN-57)
	_player_defending = true
	_set_log("%s se pone en guardia. 🛡️ (menos daño hasta tu proximo turno)" % _player.nombre)
	_update_hp()
	_fin_de_eleccion()
	_state = State.ADVANCING


# Accion Huir (KAN-55): intento de escapar. Probabilidad = CONTEST de Agilidad
# (tu Agilidad vs la del enemigo); entrar agotado la reduce. Si funciona, sales
# del combate SIN loot y el enemigo sigue vivo; si fallas, pierdes el turno.
func _accion_huir() -> void:
	var chance := StatsMath.flee_chance(
		float(_player.abilities.agilidad), float(_enemy.abilities.agilidad))
	if _slow_actions_left > 0:
		chance *= FLEE_EXHAUSTED_MULT
	var ok := randf() < chance
	_fin_de_eleccion()
	if ok:
		_end(false, true)  # huida: no ganas, pero tampoco es derrota
	else:
		_set_log("%s intenta huir pero %s se lo impide. (%.0f%%)" % [
			_player.nombre, _enemy.nombre, chance * 100.0])
		_state = State.ADVANCING


func _enemy_turn() -> void:
	# Estados alterados (KAN-58): tick al inicio del turno del enemigo.
	var ev: Dictionary = _enemy.tick_statuses()
	_log_tick(_enemy, ev)
	_update_hp()
	if not _enemy.is_alive():
		_set_log("%s cae por el daño de sus estados. ☠" % _enemy.nombre)
		_end(true)   # el DoT remata al enemigo
		return
	if ev.stunned:
		_set_log("%s esta aturdido y pierde el turno. 💫" % _enemy.nombre)
		_pausa_lectura()   # ya se le resto la barra ATB en _process; pierde la accion
		return
	var result := StatsMath.resolve_attack(_enemy, _player, _player_defending)
	_debug_ataque(_enemy, _player, result, _player_defending)
	if result.evaded:
		_set_log("%s esquiva el ataque de %s. 💨" % [_player.nombre, _enemy.nombre])
		# Excelia: esquivar un golpe entrena Agilidad (en vez de correr en circulos).
		Game.ganar("agilidad", Game.reto(_poder_enemigo()), Game.GAIN_AGILIDAD_ESQUIVAR,
			Game.RETO_MAX_FISICO)
		_update_hp()
		_pausa_lectura()
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
	# Estados "al golpear" del enemigo (pegajoso/veneno de slimes, KAN-58 Fase 3).
	for nom in _enemy.roll_on_hit(_player):
		msg += "  Te inflige %s." % nom
	_set_log(msg)
	_update_hp()
	_enemy.advance_hand()  # (sin efecto ahora; los enemigos aun no llevan 2 armas)

	if not _player.is_alive():
		_end(false)
	else:
		_pausa_lectura()


# Congela el ATB una fraccion de segundo tras la accion del enemigo, para poder
# leer el log antes de que sigan llenandose las barras.
func _pausa_lectura() -> void:
	_pause_left = ENEMY_TURN_PAUSE
	_state = State.PAUSED


func _end(player_won: bool, fled: bool = false) -> void:
	_player_won = player_won
	_state = State.FINISHED
	_limpiar_casteo()
	_ocultar_cajas()
	_continue_button.visible = true
	_continue_button.disabled = false
	_continue_button.text = "Continuar"
	if player_won:
		_set_log("¡GANASTE el combate contra " + _enemy.nombre + "! 🎉")
	elif fled:
		_set_log("Has escapado de " + _enemy.nombre + ". 🏃")
	else:
		_set_log("Has caido en combate... 💀")

	# Marca de FIN en consola (cierra el bloque del combate para los Excel).
	var desenlace: String = ("huye %s" % _player.nombre) if fled else \
		("gana %s" % (_player.nombre if player_won else _enemy.nombre))
	print("[combate] ===== FIN: %s | %s HP %.2f | %s HP %.2f =====" % [
		desenlace, _player.nombre, _player.current_hp, _enemy.nombre, _enemy.current_hp])


# Log-HISTORIAL: cada evento se apila como una linea nueva y se muestran las
# ultimas LOG_MAX (antes era una sola linea que se sobrescribia y no daba tiempo a
# leer los DoT / lo que aplicabas). Evita duplicar la misma linea consecutiva.
const LOG_MAX := 6
var _log_lines: Array[String] = []

func _set_log(texto: String) -> void:
	if _log_lines.size() > 0 and _log_lines[_log_lines.size() - 1] == texto:
		return
	_log_lines.append(texto)
	while _log_lines.size() > LOG_MAX:
		_log_lines.pop_front()
	# Se muestran SIEMPRE LOG_MAX lineas (rellenando con vacias ARRIBA cuando hay menos):
	# asi el log ocupa un alto FIJO desde el primer frame y los botones de accion NO se
	# desplazan al ir creciendo el historial. El texto nuevo queda pegado a los botones.
	var display: Array[String] = _log_lines.duplicate()
	while display.size() < LOG_MAX:
		display.insert(0, "")
	_log.text = "\n".join(display)


# Aplica el aturdir a un objetivo y devuelve el texto para el log. Dos niveles (KAN-58):
#  - CRITICO -> aplica el ESTADO Aturdido (pierde su proximo turno, via el motor de
#    estados; se ve el 💫 en su etiqueta y lo gestiona el tick del turno).
#  - normal  -> retraso PARCIAL de barra ATB (stagger; pierde tempo, no el turno).
func _aplicar_aturdir(objetivo: Combatant, es_crit: bool) -> String:
	if es_crit:
		objetivo.apply_status(StatusEffects.Id.ATURDIDO)
		return "  ¡ATURDIDO! 💫 (pierde el turno)"
	var f: float = randf_range(ATB_STUN_MIN, ATB_STUN_MAX)
	# Sin recorte a 0: si la barra ya estaba baja, el retraso debe notarse igual
	# (recortar a 0 lo dejaba igual que si no hubiera aturdido nada).
	_gauge[objetivo] -= UMBRAL * f
	return "  ¡Retrasado! 💫"


# Log de DESARROLLO (consola): probabilidades reales de esquiva/crit/aturdir de
# CADA ataque, con las stats implicadas, para afinar la curva en cada situacion.
func _debug_ataque(atacante: Combatant, defensor: Combatant, r: Dictionary, bloqueando: bool = false) -> void:
	var outcome: String = "esquivado" if r.evaded else ("CRITICO" if r.crit else "golpe")
	if r.aturde:
		outcome += "+ATURDE"
	if bloqueando and not r.evaded:
		outcome += "+BLOQUEO"
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


# ============================================================
#  DEV/TEST de estados (KAN-58 Fase 1): panel abajo-dcha (cerrable con su toggle)
#  para aplicar estados a mano al enemigo o al jugador y ver el motor funcionando
#  (tick, stacks, stat, aturdido). Se retirara cuando esten enganchados a todo.
# ============================================================
var _dev_target_enemy: bool = true
var _estados_panel: PanelContainer = null

func _crear_estados_dev() -> void:
	# Boton toggle (abajo-dcha, siempre visible) para cerrar/abrir el panel dev.
	var toggle := Button.new()
	toggle.text = "ESTADOS (dev)"
	toggle.toggle_mode = true
	toggle.button_pressed = true   # arranca abierto (al fondo ya no tapa el HP de arriba)
	toggle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle.offset_right = -8
	toggle.offset_bottom = -8
	toggle.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toggle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toggle.toggled.connect(func(on: bool): _estados_panel.visible = on)
	add_child(toggle)

	# Panel anclado ABAJO-dcha; crece hacia ARRIBA (encima del toggle). No tapa el HP.
	_estados_panel = PanelContainer.new()
	_estados_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_estados_panel.offset_right = -8
	_estados_panel.offset_bottom = -40   # justo encima del boton toggle
	_estados_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_estados_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_estados_panel.custom_minimum_size = Vector2(260, 0)
	add_child(_estados_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_estados_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "ESTADOS (dev/test)"
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(title)

	var tgt := CheckButton.new()
	tgt.text = "Objetivo: Enemigo"
	tgt.button_pressed = true
	tgt.toggled.connect(func(on: bool):
		_dev_target_enemy = on
		tgt.text = "Objetivo: Enemigo" if on else "Objetivo: Jugador")
	vb.add_child(tgt)

	var flow := HFlowContainer.new()
	vb.add_child(flow)
	# Veneno: un solo boton; cada pulsacion = +1 stack (y cada stack DUPLICA el daño).
	var bv := Button.new()
	bv.text = "☠ Veneno +stack"
	bv.pressed.connect(_dev_veneno)
	flow.add_child(bv)
	# Sangrado: magnitud = escala con el ATAQUE del aplicador (el bando contrario al objetivo).
	var bs := Button.new()
	bs.text = "🩸 Sangrado"
	bs.pressed.connect(_dev_sangrado)
	flow.add_child(bs)
	# Resto de estados: magnitud/duracion por defecto del catalogo.
	for id in StatusEffects.all_ids():
		if int(id) == StatusEffects.Id.VENENO or int(id) == StatusEffects.Id.SANGRADO:
			continue
		var d: Dictionary = StatusEffects.def(id)
		var b := Button.new()
		b.text = "%s %s" % [d.get("icono", "?"), d.get("nombre", "?")]
		b.pressed.connect(_dev_aplicar_estado.bind(int(id)))
		flow.add_child(b)
	var clr := Button.new()
	clr.text = "Limpiar"
	clr.pressed.connect(_dev_limpiar_estados)
	flow.add_child(clr)


func _dev_target() -> Combatant:
	return _enemy if _dev_target_enemy else _player

# Aplicador para estados que escalan con quien los lanza: el bando CONTRARIO al objetivo.
func _dev_aplicador() -> Combatant:
	return _player if _dev_target_enemy else _enemy

func _dev_aplicar_estado(id: int) -> void:
	_dev_target().apply_status(id)
	_update_hp()
	var d: Dictionary = StatusEffects.def(id)
	_set_log("[dev] Aplicado %s a %s." % [d.get("nombre", "?"), _dev_target().nombre])

func _dev_veneno() -> void:
	_dev_target().apply_status(StatusEffects.Id.VENENO)   # +1 stack (dev: sin cap)
	_update_hp()
	_set_log("[dev] Veneno +1 stack a %s." % _dev_target().nombre)

func _dev_sangrado() -> void:
	var ap: Combatant = _dev_aplicador()
	var mag: float = StatusEffects.sangrado_magnitude(ap.atk())
	_dev_target().apply_status(StatusEffects.Id.SANGRADO, -1, mag)
	_update_hp()
	_set_log("[dev] Sangrado +1 stack (%.1f/stack · escala con %s) a %s." % [
		mag, ap.nombre, _dev_target().nombre])

func _dev_limpiar_estados() -> void:
	_dev_target().statuses.clear()
	_update_hp()


# Crea un fondo opaco a pantalla completa, por DETRAS de la interfaz.
func _anadir_fondo() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # que no robe los clics al boton
	add_child(bg)
	move_child(bg, 0)  # al fondo (los hermanos siguientes se dibujan encima)
