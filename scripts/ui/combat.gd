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
# La escena trae un unico boton (AttackButton). Ahora las 4 acciones se crean por
# codigo (barra de acciones, KAN-55) y ESE boton se reutiliza como "Continuar" al
# terminar el combate.
@onready var _continue_button: Button = $VBox/AttackButton

# Sistema de ACCIONES (KAN-55): barra con Atacar / Magia / Defender / Huir. Se
# genera por codigo (convencion: UI por codigo por ahora) y es de datos, asi
# futuras acciones (habilidades, objetos) solo añaden una entrada.
enum Action { ATTACK, MAGIC, DEFEND, FLEE }
var _actions_box: HBoxContainer = null
var _action_buttons: Dictionary = {}   # Action(int) -> Button

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
# player_mp_left persiste el mana gastado (KAN-56).
signal combat_finished(player_won: bool, player_hp_left: float, player_mp_left: float)

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

	_continue_button.text = "Continuar"
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	_crear_acciones()
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


# Crea la barra de acciones (KAN-55): Atacar / Magia / Defender / Huir, de datos.
func _crear_acciones() -> void:
	_actions_box = HBoxContainer.new()
	$VBox.add_child(_actions_box)
	var defs := [
		[Action.ATTACK, "Atacar"],
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
	_ocultar_cajas()


# Oculta las tres cajas del turno del jugador (acciones / submenu magia / recitado).
func _ocultar_cajas() -> void:
	if _actions_box != null: _actions_box.visible = false
	if _spell_box != null: _spell_box.visible = false
	if _cast_box != null: _cast_box.visible = false


func _setup_ui() -> void:
	_player_hp.max_value = _player.max_hp
	_enemy_hp.max_value = _enemy.max_hp
	_player_hp.show_percentage = false
	_enemy_hp.show_percentage = false
	_update_hp()
	_continue_button.visible = false
	_ocultar_cajas()


func _update_hp() -> void:
	_player_hp.value = _player.current_hp
	_enemy_hp.value = _enemy.current_hp
	_enemy_name.text = "%s  (Nv.%d)   %.2f/%d" % [
		_enemy.nombre, _enemy.level, _enemy.current_hp, _enemy.max_hp]
	# El jugador muestra ademas su MANA si tiene (KAN-56).
	var mp_txt := ""
	if _player.max_mp > 0:
		mp_txt = "   MP %d/%d" % [roundi(_player.current_mp), _player.max_mp]
	_player_name.text = "%s  (Nv.%d)   %.2f/%d%s" % [
		_player.nombre, _player.level, _player.current_hp, _player.max_hp, mp_txt]


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
	_player.regen_mana(StatsMath.mp_regen(float(_player.abilities.magia)))  # regen escala con Magia (KAN-56)
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


func _accion_disponible(id: int) -> bool:
	match id:
		Action.ATTACK: return true
		Action.DEFEND: return true
		Action.FLEE: return true
		Action.MAGIC: return _hay_hechizos()
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


# El boton reutilizado (antes "Atacar") cierra la pantalla al terminar el combate.
func _on_continue_pressed() -> void:
	if _state != State.FINISHED:
		return
	combat_finished.emit(_player_won, _player.current_hp, _player.current_mp)
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
		b.text = "%s  (%d MP · %d frase%s)" % [
			spell.nombre, spell.coste_mana, spell.longitud(),
			"" if spell.longitud() == 1 else "s"]
		if not _player.has_mana(float(spell.coste_mana)):
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


# Empiezas a castear: se descuenta el mana YA (si fallas lo pierdes) y recitas la
# primera frase en este MISMO turno.
func _elegir_hechizo(spell: SpellData) -> void:
	if not _player.has_mana(float(spell.coste_mana)):
		return
	_player.spend_mana(float(spell.coste_mana))
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
		# Excelia: recitar bien entrena Magia (practicas el conjuro).
		Game.ganar("magia", Game.reto(_poder_enemigo()), Game.GAIN_MAGIA_CAST)
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
	var result := StatsMath.resolve_spell(_player, _enemy, spell)
	_enemy.take_damage(result.damage)
	# Excelia: lanzar entrena Magia extra, mas cuanto mas largo el hechizo.
	Game.ganar("magia", Game.reto(_poder_enemigo()) * float(spell.longitud()), Game.GAIN_MAGIA_CAST)
	print("[magia] %s lanza %s | dano:%.2f (Magia %d)" % [
		_player.nombre, spell.nombre, result.damage, _player.abilities.magia])
	_set_log("🔥 %s impacta a %s por %.2f de daño." % [spell.nombre, _enemy.nombre, result.damage])
	_limpiar_casteo()
	_update_hp()
	_fin_de_eleccion()
	if not _enemy.is_alive():
		_end(true)
	else:
		_state = State.ADVANCING


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
		_set_log(txt)
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
	_player_defending = true
	_set_log("%s se pone en guardia. 🛡️ (menos daño hasta tu proximo turno)" % _player.nombre)
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
	var result := StatsMath.resolve_attack(_enemy, _player, _player_defending)
	_debug_ataque(_enemy, _player, result, _player_defending)
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


func _set_log(texto: String) -> void:
	_log.text = texto


# Aplica el aturdir a un objetivo (resta barra ATB) y devuelve el texto para el log.
# es_crit = el golpe fue CRITICO -> aturdimiento COMPLETO (pierde el turno).
func _aplicar_aturdir(objetivo: Combatant, es_crit: bool) -> String:
	if es_crit:
		_gauge[objetivo] = -UMBRAL   # barra a negativo: se salta el turno entero
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


# Crea un fondo opaco a pantalla completa, por DETRAS de la interfaz.
func _anadir_fondo() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # que no robe los clics al boton
	add_child(bg)
	move_child(bg, 0)  # al fondo (los hermanos siguientes se dibujan encima)
