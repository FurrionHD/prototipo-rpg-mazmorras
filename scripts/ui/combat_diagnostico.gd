# ============================================================
#  combat_diagnostico.gd  (tema de la pantalla de combate: combat.diagnostico)
#  CUANDO ALGO VA MAL Y PARA PROBAR: la tecla P (desatascar la pelea y volcar el estado entero), el
#  informe que genera, y las herramientas de desarrollo (curar al 100%, cambiar de arma, el panel de
#  estados). Lo demas, a _pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


var _dev_target_enemy: bool = true
var _estados_panel: PanelContainer = null
# Las CATEGORIAS del panel. Los nombres son los de siempre (buff, debuff, DoT) y no inventados:
# esto es un panel de pruebas, y buscar aqui tiene que costar cero.
#
# El reparto NO es "buenos y malos", es POR LO QUE TOCAN, que es como se busca cuando pruebas:
#   - Debuffs                 bajan tus numeros (ataque, defensa, curacion que recibes...)
#   - Debuffs de movimiento   tocan el TURNO: te frenan la barra o te la quitan entera
#   - Debuffs amplificadores  no te hacen NADA por si mismos ni te restringen: suben lo que le
#                             pase a lo SIGUIENTE que te caiga (Mojado multiplica x1.5 el daño
#                             del rayo; Electrizado x1.5 la probabilidad de que te aturdan)
#   - DoT                     te quitan vida cada turno
const DEV_ESTADOS_CATS: Array = [
	["Buffs", [
		StatusEffects.Id.FORTALEZA, StatusEffects.Id.BALUARTE, StatusEffects.Id.PRESTEZA,
		StatusEffects.Id.REGENERACION, StatusEffects.Id.REGEN_MANA, StatusEffects.Id.SIGILO,
		StatusEffects.Id.GUARDIA_CARNE, StatusEffects.Id.ESCOLTA, StatusEffects.Id.OPORTUNISTA,
	]],
	["Debuffs", [
		StatusEffects.Id.DEBIL, StatusEffects.Id.VULNERABLE, StatusEffects.Id.MARCA,
		StatusEffects.Id.CORROSION, StatusEffects.Id.HERIDA_PROFUNDA, StatusEffects.Id.SILENCIO,
	]],
	["Debuffs de movimiento", [
		StatusEffects.Id.LENTO, StatusEffects.Id.PEGAJOSO, StatusEffects.Id.ATURDIDO,
		StatusEffects.Id.MIEDO,
	]],
	["Debuffs amplificadores", [
		StatusEffects.Id.MOJADO, StatusEffects.Id.RAYO,
	]],
	["DoT (daño por turno)", [
		StatusEffects.Id.VENENO, StatusEffects.Id.SANGRADO, StatusEffects.Id.QUEMADURA,
	]],
	["Platos (cocina)", [
		StatusEffects.Id.PLATO_GUARDIA, StatusEffects.Id.PLATO_BRIO, StatusEffects.Id.PLATO_FURIA,
		StatusEffects.Id.PLATO_ARCANO, StatusEffects.Id.PLATO_NUCLEO,
		StatusEffects.Id.PLATO_REMEDIO, StatusEffects.Id.PLATO_ESTOMAGO,
		StatusEffects.Id.PLATO_FORTUNA,
	]],
]


# TECLA P: el combate se queda a veces sin pasar turno y no hay forma de saber por que. Esto
# vuelca el estado ENTERO al log (y a la consola) y luego intenta reanudarlo. No es una tecla de
# desarrollo: es la salida de emergencia del jugador, y el volcado es lo que nos dira que lo causa.
# Tres pasos, en este orden: contar que pasa, intentar seguir, y solo si no hay manera, salir.
func _desatascar() -> void:
	# Se apunta ANTES del volcado: asi el propio informe muestra cuantas veces se ha pulsado P y
	# cuando, que ya dice mucho (si hay cinco P seguidas, lo que se intento no funciono).
	_pantalla._traza_add("--- el jugador pulsa P ---")
	# Lo PRIMERO: cortar la animacion y dejar las tarjetas en su sitio. Va antes de todos los
	# intentos (y antes de la salida del espejo) porque los intentos 2 y 3 pisan _pause_left y el
	# turno, y una tarjeta a medio embestir se quedaria torcida y a medio brillo para siempre.
	# Cortarla no puede perder ni duplicar un turno: la cola solo pinta, no decide de quien es.
	# Se APUNTA lo que habia antes de cortar: si el atasco fuera de la animacion, eso es el dato.
	var fx_txt: String = _pantalla._fx.diagnostico() if _pantalla._fx != null else "fx: no hay"
	if _pantalla._fx != null:
		_pantalla._fx.cancelar()
	var lineas: Array = _diagnostico()
	lineas.append(fx_txt)
	_volcado_p()   # el informe LARGO va al log del juego (%APPDATA%/DungeonOratoria/logs/godot.log)
	# El log de combate es de una linea: se pinta el resumen y el detalle queda en la consola.
	_pantalla._set_log("🔧 %s" % " · ".join(lineas))

	# ESPEJO: esta pantalla no simula nada, solo pinta la pelea de otra maquina. Tocarle el estado
	# no arregla nada (el atasco esta al otro lado) y ademas desincronizaria lo que se ve. Con el
	# volcado basta: dice si el anfitrion esta esperando a alguien, que es lo que hay que saber.
	if _pantalla._espejo:
		_pantalla._set_log("🔧 La pelea la lleva otra máquina: que pulse P quien la tenga. %s" % " · ".join(lineas))
		return

	# --- Intento 1: soltar la espera de un turno remoto que no va a llegar.
	if _pantalla._state == _pantalla.State.WAITING_PLAYER and _pantalla._esperando_a != 0:
		if not Net.peleas.esta_en_mi_pelea(_pantalla._esperando_a):
			var quien: int = _pantalla._esperando_a
			_pantalla.espejo._fin_de_espera()
			_pantalla.sacar_a(quien)
			_pantalla._set_log("🔧 %d ya no está en la pelea: fuera. La pelea sigue." % quien)
			return
		# Sigue conectado: se le repite la peticion ya, sin esperar al heartbeat.
		_pantalla.espejo._espera_acum = 0.0
		_pantalla._traza_add("REENVIO A MANO (P) #%d '%s' al peer %d" % [
			int(_pantalla.espejo._peticion_pendiente.get("seq", 0)),
			String(_pantalla.espejo._peticion_pendiente.get("tipo", "?")), _pantalla._esperando_a])
		_pantalla.espejo._enviar_peticion()
		_pantalla._set_log("🔧 Le repito la petición a %d. Si no contesta, vuelve a pulsar P." % _pantalla._esperando_a)
		return

	# --- Intento 2: estado raro (esperando a nadie, o una pausa de lectura que no baja).
	# Se devuelve el mando a quien le toque y se reanuda el ATB.
	if _pantalla._state != _pantalla.State.ADVANCING:
		_pantalla.espejo._fin_de_espera()
		_pantalla._pause_left = 0.0
		if _pantalla._player != null and _pantalla._player.is_alive() and not _pantalla._huidos.has(_pantalla._player):
			# ¿DE QUIEN ES EL QUE TIENE EL TURNO? Esto no se miraba, y era el tercer camino por el que
			# se perdian turnos: si _player es el personaje de OTRO humano, pintarme aqui SUS botones
			# es jugar yo por el, y el _fin_de_espera() de arriba acababa de tirar la peticion que el
			# heartbeat estaba reenviando. O sea que el dueño se quedaba sin turno para siempre y
			# encima su personaje hacia lo que yo eligiera. Lo correcto es volver a pedirselo a el.
			var dueno_p: int = int(_pantalla._dueno_aliado.get(_pantalla._player, 0))
			if dueno_p != 0:
				_pantalla._state = _pantalla.State.WAITING_PLAYER
				if not Net.peleas.esta_en_mi_pelea(dueno_p):
					_pantalla.sacar_a(dueno_p)
					_pantalla._set_log("🔧 %s ya no está en la pelea: fuera. La pelea sigue." % dueno_p)
					return
				_pantalla._ocultar_cajas()
				_pantalla.espejo._pedir_a_remoto(dueno_p, {"tipo": "accion", "idx": _pantalla._aliados.find(_pantalla._player)})
				_pantalla._set_log("🔧 El turno es de %s, que lo lleva otro jugador: se lo vuelvo a pedir."
					% _pantalla._player.nombre)
				return
			_pantalla._state = _pantalla.State.WAITING_PLAYER
			_pantalla._mostrar_acciones()
			_pantalla._set_log("🔧 Turno devuelto a %s. Elige una acción." % _pantalla._player.nombre)
		else:
			_pantalla._state = _pantalla.State.ADVANCING
			_pantalla._set_log("🔧 Reanudado el contador de turnos.")
		return

	# --- Intento 3: dice que avanza pero nadie llega al umbral (barras a cero / todas paradas).
	# Se empuja al que mas tenga hasta el umbral para forzar el siguiente turno.
	var mejor: Combatant = null
	for c in _pantalla._aliados_vivos() + _pantalla._vivos():
		if mejor == null or _pantalla._gauge.get(c, 0.0) > _pantalla._gauge.get(mejor, 0.0):
			mejor = c
	if mejor != null:
		_pantalla._gauge[mejor] = _pantalla.UMBRAL
		_pantalla._set_log("🔧 Empujo el turno de %s." % mejor.nombre)
		return

	# --- Sin nadie a quien darle el turno: la pelea no se puede salvar. Salir como huida
	# conserva la partida (el mundo vuelve, los bichos se sueltan) en vez de dejar el juego muerto.
	_pantalla._set_log("🔧 No queda nadie a quien darle el turno: salgo del combate.")
	_pantalla._end(false, true)


# Todo lo que hace falta para entender un cuelgue, en lineas cortas.
func _diagnostico() -> Array:
	var nombres := ["ADVANCING", "WAITING_PLAYER", "PAUSED", "FINISHED"]
	var out: Array = []
	out.append("estado=%s" % (nombres[_pantalla._state] if _pantalla._state < nombres.size() else str(_pantalla._state)))
	out.append("espejo=%s" % ("SI" if _pantalla._espejo else "no"))
	if _pantalla._state == _pantalla.State.PAUSED:
		out.append("pausa_lectura=%.1fs" % _pantalla._pause_left)
	if _pantalla._esperando_a != 0:
		out.append("esperando a peer %d (%s) desde %.1fs, ¿sigue?=%s" % [
			_pantalla._esperando_a, String(_pantalla.espejo._peticion_pendiente.get("tipo", "?")), _pantalla.espejo._espera_acum,
			"si" if Net.peleas.esta_en_mi_pelea(_pantalla._esperando_a) else "NO"])
	else:
		out.append("no espero a nadie")
	out.append("turno de=%s" % (_pantalla._player.nombre if _pantalla._player != null else "nadie"))
	# Las barras: si todas estan lejos del umbral, el ATB esta parado; si alguna lo pasa y aun asi
	# no actua, el atasco esta en la resolucion del turno, no en el contador.
	var barras: Array = []
	for c in _pantalla._aliados_vivos():
		barras.append("%s %.0f" % [c.nombre, _pantalla._gauge.get(c, 0.0)])
	for e in _pantalla._vivos():
		barras.append("%s %.0f" % [e.nombre, _pantalla._gauge.get(e, 0.0)])
	out.append("barras(/%d): %s" % [int(_pantalla.UMBRAL), ", ".join(barras)])
	out.append("vivos: %d tuyos / %d bichos, huidos %d" % [
		_pantalla._aliados_vivos().size(), _pantalla._vivos().size(), _pantalla._huidos.size()])
	# Un submenu abierto NO es un cuelgue: es que hay algo esperando a que elijas.
	if _pantalla._ability_box != null and _pantalla._ability_box.visible:
		out.append("OJO: menu de habilidades abierto (elige o pulsa atras)")
	if _pantalla._actions_box != null and not _pantalla._actions_box.visible and _pantalla._state == _pantalla.State.WAITING_PLAYER:
		out.append("OJO: submenu abierto sin caja de acciones")
	return out


# EL INFORME LARGO DE LA TECLA P. Va entero al log del juego, que se guarda solo en
#   %APPDATA%\DungeonOratoria\logs\godot.log
# (file_logging esta activado en project.godot), asi que despues de una partida se puede mandar ese
# fichero y leer aqui que paso de verdad.
#
# Un turno colgado en red no se reproduce a voluntad: depende de quien tarde en elegir y de que
# paquete se cruce con cual. Por eso lo importante no es la foto del momento sino la TRAZA: la lista
# de peticiones, reenvios, respuestas y descartes con sus tiempos. Ahi se ve, por ejemplo, si a
# alguien se le pidio el turno y nunca contesto, o si contesto a una peticion que ya no era la buena.
func _volcado_p() -> void:
	var nombres := ["ADVANCING", "WAITING_PLAYER", "PAUSED", "FINISHED"]
	var L: Array[String] = []
	L.append("============ VOLCADO DE COMBATE (tecla P) ============")
	L.append("cuando: %s  ·  version del juego: %s" % [
		Time.get_datetime_string_from_system(false, true), str(Game.VERSION)])

	# --- QUIEN SOY EN ESTA PELEA
	L.append("--- YO ---")
	L.append("  esta pantalla: %s" % ("ESPEJO (la pelea la lleva otra maquina)" if _pantalla._espejo
		else "ANFITRION DE LA PELEA (la simulo yo)"))
	L.append("  red activa: %s · soy host de red: %s · mundo compartido: %s" % [
		str(Net.activo), str(Net.es_host), str(Net.mundo_compartido)])
	if Net.activo and Net.multiplayer.multiplayer_peer != null:
		L.append("  mi peer id: %d" % Net.multiplayer.get_unique_id())
	L.append("  mi identidad: %s (%s)" % [Identidad.nombre, Identidad.id])

	# --- LA PELEA A OJOS DE LA CAPA DE RED
	L.append("--- LA PELEA (segun Net) ---")
	for campo in ["_pelea_id", "_pelea_anfitrion", "_pelea_sigo"]:
		L.append("  %s = %s" % [campo, str(Net.peleas.get(campo))])
	var parts = Net.peleas.get("_pelea_participantes")
	L.append("  participantes: %s" % str(parts))

	# --- EL ESTADO DEL MOTOR
	L.append("--- ESTADO ---")
	L.append("  state = %s" % (nombres[_pantalla._state] if _pantalla._state < nombres.size() else str(_pantalla._state)))
	L.append("  pausa de lectura pendiente: %.2fs" % _pantalla._pause_left)
	L.append("  revision del roster: %d (pedida: %s)" % [_pantalla.espejo._rev, str(_pantalla.espejo._rev_pedida)])
	L.append("  numero de peticion actual: %d" % _pantalla.espejo._pet_seq)
	if _pantalla._espejo:
		L.append("  [espejo] me han pedido la #%d y ya conteste hasta la #%d" % [
			_pantalla.espejo._seq_espejo, _pantalla.espejo._seq_contestada])
	if _pantalla._esperando_a != 0:
		L.append("  ESPERANDO al peer %d desde hace %.2fs" % [_pantalla._esperando_a, _pantalla.espejo._espera_acum])
		L.append("    lo que le pedi: %s" % str(_pantalla.espejo._peticion_pendiente))
		L.append("    ¿sigue en la pelea?: %s" % ("si" if Net.peleas.esta_en_mi_pelea(_pantalla._esperando_a) else "NO"))
		L.append("    proximo reenvio en: %.2fs" % maxf(0.0, _pantalla.espejo.REENVIO_TURNO - _pantalla.espejo._espera_acum))
	else:
		L.append("  no espero respuesta de nadie")
		# Esta pareja es LA firma del cuelgue: parado esperando a alguien... a quien ya no se espera.
		if _pantalla._state == _pantalla.State.WAITING_PLAYER:
			L.append("  >>> SOSPECHOSO: estado WAITING_PLAYER pero sin nadie a quien esperar.")
			L.append("  >>> Con esta pareja el heartbeat no reenvia nada y la pelea no avanza sola.")

	# --- DE QUIEN ES EL TURNO
	L.append("--- TURNO ---")
	if _pantalla._player == null:
		L.append("  no hay nadie con el turno (_player = null)")
	else:
		var d: int = int(_pantalla._dueno_aliado.get(_pantalla._player, 0))
		L.append("  lo tiene: %s (indice %d)" % [_pantalla._player.nombre, _pantalla._aliados.find(_pantalla._player)])
		L.append("  su dueño: %s" % ("YO (local)" if d == 0 else "el peer %d" % d))
		L.append("  vivo: %s · ha huido: %s" % [str(_pantalla._player.is_alive()), str(_pantalla._huidos.has(_pantalla._player))])
	if _pantalla._cast_spell != null:
		L.append("  recitando: %s, frase %d de %d" % [
			_pantalla._cast_spell.nombre, _pantalla._cast_index + 1, _pantalla._cast_spell.longitud()])

	# --- LOS COMBATIENTES
	L.append("--- LOS TUYOS (barra / %d para actuar) ---" % int(_pantalla.UMBRAL))
	for i in _pantalla._aliados.size():
		var c: Combatant = _pantalla._aliados[i]
		var d2: int = int(_pantalla._dueno_aliado.get(c, 0))
		L.append("  [%d] %-14s barra %6.1f  HP %7.2f/%7.2f  EN %6.1f  MP %6.1f  dueño=%s%s%s" % [
			i, c.nombre, _pantalla._gauge.get(c, 0.0), c.current_hp, c.max_hp, c.current_energy,
			c.current_mp, ("local" if d2 == 0 else "peer %d" % d2),
			"" if c.is_alive() else "  [MUERTO]", "  [HUIDO]" if _pantalla._huidos.has(c) else ""])
	L.append("--- LOS BICHOS ---")
	for i in _pantalla._enemies.size():
		var e: Combatant = _pantalla._enemies[i]
		L.append("  [%d] %-14s barra %6.1f  HP %7.2f/%7.2f%s%s" % [
			i, e.nombre, _pantalla._gauge.get(e, 0.0), e.current_hp, e.max_hp,
			"" if e.is_alive() else "  [MUERTO]", "  [INVOCADO]" if _pantalla._slots_invocados.has(i) else ""])

	# --- QUE HAY EN PANTALLA (un submenu abierto no es un cuelgue: es que esperan que elijas)
	L.append("--- PANTALLA ---")
	L.append("  acciones=%s  habilidades=%s  magia=%s  objetos=%s  recitado=%s  continuar=%s" % [
		_vis(_pantalla._actions_box), _vis(_pantalla._ability_box), _vis(_pantalla._spell_box), _vis(_pantalla._objeto_box),
		_vis(_pantalla._cast_box), _vis(_pantalla._continue_button)])

	# --- LA TRAZA: esto es lo que de verdad explica el cuelgue
	L.append("--- TRAZA DE TURNOS (lo ultimo primero abajo; %d apuntes) ---" % _pantalla._traza.size())
	if _pantalla._traza.is_empty():
		L.append("  (vacia: en esta pelea no ha habido trafico de turnos por red)")
	for t in _pantalla._traza:
		L.append("  " + t)
	L.append("--- ULTIMAS LINEAS DEL COMBATE ---")
	for l in _pantalla._log_lines:
		L.append("  " + l)
	L.append("======================================================")

	for l in L:
		print(l)


func _vis(n: Node) -> String:
	if n == null:
		return "(no existe)"
	return "SI" if bool(n.get("visible")) else "no"


# [dev] Cura al jugador del combate a tope (vida + mana + energia) y refresca las barras.
func _dev_heal_full() -> void:
	_pantalla._player.current_hp = _pantalla._player.max_hp
	if _pantalla._player.max_mp > 0.0:
		_pantalla._player.current_mp = _pantalla._player.max_mp
	if _pantalla._player.max_energy > 0.0:
		_pantalla._player.current_energy = _pantalla._player.max_energy
	_pantalla._update_hp()
	_pantalla._set_log("[dev] Curación total: vida/maná/energía al 100%")


# [dev] Cambia el arma (principal si main=true, si no la secundaria) usando el ciclador
# de Game y REAPLICA el loadout al combatiente en curso (sin perder vida/mana/energia).
# Solo con combatientes reales inyectados por Game (no en el modo prueba F6).
func _dev_swap_weapon(main: bool) -> void:
	if not _pantalla._injected:
		return
	if main:
		Game._dev_cycle_weapon()
	else:
		Game._dev_cycle_off()
	Game._aplicar_loadout(_pantalla._player)
	_pantalla._update_hp()
	var oname := "—"
	if Game.equipped_off is WeaponData:
		oname = (Game.equipped_off as WeaponData).nombre + " (dual)"
	elif Game.equipped_off is WandData:
		oname = (Game.equipped_off as WandData).nombre + " (varita)"
	elif Game.equipped_off is ShieldData:
		oname = (Game.equipped_off as ShieldData).nombre
	var mano: String = "principal" if main else "secundaria"
	var mname: String = Game.equipped_main.nombre if Game.equipped_main != null else "— (sin arma)"
	_pantalla._set_log("[dev] Cambiada %s → %s + %s" % [mano, mname, oname])


func _crear_estados_dev() -> void:
	# Boton toggle (abajo-dcha, siempre visible) para cerrar/abrir el panel dev.
	var toggle := Button.new()
	toggle.text = "ESTADOS (dev)"
	toggle.toggle_mode = true
	toggle.button_pressed = false   # arranca CERRADO (el tester lo abre si lo necesita)
	# EL TOGGLE, en la fila de herramientas de arriba (con el registro y la velocidad). Suelto en
	# una esquina no le queda ninguna libre: abajo-dcha son los botones de accion y abajo-izda es
	# la tarjeta del primero de los tuyos, que es justo la que tapaba.
	toggle.text = "⚙"
	toggle.custom_minimum_size = Vector2(36, 28)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.tooltip_text = "Panel de pruebas de estados (dev)"
	toggle.toggled.connect(func(on: bool): _estados_panel.visible = on)
	if _pantalla.montaje._log_fila != null and is_instance_valid(_pantalla.montaje._log_fila):
		_pantalla.montaje._log_fila.add_child(toggle)
	else:
		_pantalla.add_child(toggle)

	# Panel anclado ABAJO-izda; crece hacia ARRIBA (encima del toggle).
	_estados_panel = PanelContainer.new()
	_estados_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_estados_panel.offset_left = _pantalla.montaje.ANCHO_TIMELINE + 8.0
	_estados_panel.offset_bottom = -40   # justo encima del boton toggle
	_estados_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_estados_panel.custom_minimum_size = Vector2(260, 0)
	_estados_panel.visible = false   # cerrado de base (coincide con el toggle sin pulsar)
	_pantalla.add_child(_estados_panel)

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

	# "Enemigo" = el que tengas SELECCIONADO. Asi el panel hereda gratis la seleccion por clic
	# y no hace falta un segundo selector de 4 entradas aqui dentro.
	var tgt := CheckButton.new()
	tgt.text = "Objetivo: Enemigo sel."
	tgt.button_pressed = true
	tgt.toggled.connect(func(on: bool):
		_dev_target_enemy = on
		tgt.text = "Objetivo: Enemigo sel." if on else "Objetivo: Jugador")
	vb.add_child(tgt)

	var clr := Button.new()
	clr.text = "Limpiar todos"
	clr.pressed.connect(_dev_limpiar_estados)
	vb.add_child(clr)

	# Los 31 estados EN UNA SOLA LISTA no caben: la columna crecia hacia arriba hasta salirse por
	# el techo de la pantalla y los de arriba quedaban inalcanzables. Van por CATEGORIAS plegables
	# (solo la primera abierta) y ademas dentro de un scroll, que es el cinturon de seguridad para
	# cuando la ventana sea pequeña o el catalogo crezca.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 2)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

	var primera := true
	for cat in DEV_ESTADOS_CATS:
		var flow: HFlowContainer = _dev_seccion(lista, String(cat[0]), primera)
		for id in cat[1]:
			match int(id):
				StatusEffects.Id.VENENO:
					# Cada pulsacion = +1 stack (y cada stack DUPLICA el daño), por eso va aparte.
					_dev_boton(flow, "☠ Veneno +stack", _dev_veneno)
				StatusEffects.Id.SANGRADO:
					# La magnitud escala con el ATAQUE del aplicador, no es la del catalogo.
					_dev_boton(flow, "🩸 Sangrado", _dev_sangrado)
				_:
					var d: Dictionary = StatusEffects.def(int(id))
					_dev_boton(flow, "%s %s" % [d.get("icono", "?"), d.get("nombre", "?")],
						_dev_aplicar_estado.bind(int(id)))
		primera = false

	# CUALQUIERA QUE FALTE. El catalogo solo se amplia por el final, asi que un estado nuevo caeria
	# fuera de las categorias de arriba y se perderia en silencio: aqui aparece solo.
	var sueltos: Array = []
	for id in StatusEffects.all_ids():
		var visto := false
		for cat2 in DEV_ESTADOS_CATS:
			if cat2[1].has(int(id)):
				visto = true
				break
		if not visto:
			sueltos.append(int(id))
	if not sueltos.is_empty():
		var flow2: HFlowContainer = _dev_seccion(lista, "Sin clasificar", false)
		for id in sueltos:
			var d2: Dictionary = StatusEffects.def(int(id))
			_dev_boton(flow2, "%s %s" % [d2.get("icono", "?"), d2.get("nombre", "?")],
				_dev_aplicar_estado.bind(int(id)))


# UNA categoria del panel de estados: cabecera que pliega y despliega, y la rejilla de botones.
# Devuelve la rejilla para que quien llama le cuelgue los suyos.
func _dev_seccion(padre: VBoxContainer, titulo: String, abierta: bool) -> HFlowContainer:
	var flow := HFlowContainer.new()
	var cab := Button.new()
	cab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cab.toggle_mode = true
	cab.button_pressed = abierta
	cab.text = ("▼ " if abierta else "▶ ") + titulo
	cab.toggled.connect(func(on: bool) -> void:
		flow.visible = on
		cab.text = ("▼ " if on else "▶ ") + titulo)
	padre.add_child(cab)
	flow.visible = abierta
	padre.add_child(flow)
	return flow


func _dev_boton(padre: Container, texto: String, accion: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.pressed.connect(accion)
	padre.add_child(b)


func _dev_target() -> Combatant:
	return _pantalla._objetivo() if _dev_target_enemy else _pantalla._player

# Aplicador para estados que escalan con quien los lanza: el bando CONTRARIO al objetivo.
func _dev_aplicador() -> Combatant:
	return _pantalla._player if _dev_target_enemy else _pantalla._objetivo()

func _dev_aplicar_estado(id: int) -> void:
	_dev_target().apply_status(id)
	_pantalla._update_hp()
	var d: Dictionary = StatusEffects.def(id)
	_pantalla._set_log("[dev] Aplicado %s a %s." % [d.get("nombre", "?"), _dev_target().nombre])

func _dev_veneno() -> void:
	_dev_target().apply_status(StatusEffects.Id.VENENO)   # +1 stack (dev: sin cap)
	_pantalla._update_hp()
	_pantalla._set_log("[dev] Veneno +1 stack a %s." % _dev_target().nombre)

func _dev_sangrado() -> void:
	var ap: Combatant = _dev_aplicador()
	var mag: float = StatusEffects.sangrado_magnitude(ap.atk(), ap.motion_value)
	_dev_target().apply_status(StatusEffects.Id.SANGRADO, -1, mag)
	_pantalla._update_hp()
	_pantalla._set_log("[dev] Sangrado +1 stack (%.1f/stack · escala con %s) a %s." % [
		mag, ap.nombre, _dev_target().nombre])

func _dev_limpiar_estados() -> void:
	_dev_target().statuses.clear()
	_pantalla._update_hp()
