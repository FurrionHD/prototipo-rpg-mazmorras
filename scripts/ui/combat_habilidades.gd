# ============================================================
#  combat_habilidades.gd  (tema de la pantalla de combate: combat.habilidades)
#  HABILIDADES DE ARMA en combate: el submenu del loadout, a quien van (enemigo, area, aliado), las
#  CARGAS que sueltas tu, la resolucion golpe a golpe y los estados que tiran. Lo demas, a _pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# --- ATAQUES DE CARGA: la sueltas TU, y eliges a quien ------------------------------------------
#
# Gemelas de las tres de arriba (_mostrar_disparo / _pintar_disparo / lanzar_conjuro) y por el mismo
# motivo: hay un turno en el que la unica accion posible es "soltar esto", y hay que preguntarle al
# DUEÑO del personaje, no resolverlo con el objetivo que tenga marcado esta pantalla.

# La carga esta lista y hay que decidir a quien cae. Gemela de _pedir_accion_del_turno.
func _pedir_soltar_carga(ab: AbilityData) -> void:
	var dueno: int = int(_pantalla._dueno_aliado.get(_pantalla._player, 0))
	if dueno != 0 and not Net.peleas.esta_en_mi_pelea(dueno):
		# Ya no esta en la pelea: pedirle la orden seria esperar para siempre (mismo criterio que
		# _pedir_accion_del_turno).
		_pantalla.sacar_a(dueno)
		return
	if dueno != 0:
		_pantalla._ocultar_cajas()
		_pantalla._set_log("%s tiene %s lista. Esperando su objetivo..." % [_pantalla._player.nombre, ab.nombre])
		_pantalla.espejo._pedir_a_remoto(dueno, {"tipo": "soltar", "nombre": ab.nombre})
		return
	_pintar_soltar(ab.nombre)


# UN SOLO BOTON, y SIN cancelar: la energia y el cooldown se pagaron al empezar la carga (ver
# _empezar_carga_jugador), asi que aqui ya no hay vuelta atras. Se reusa _cast_box, que es la caja
# dinamica que ya existe para esto; _actions_box es una rejilla de botones fijos.
func _pintar_soltar(nombre: String) -> void:
	_pantalla._ocultar_cajas()
	for c in _pantalla._cast_box.get_children():
		c.queue_free()
	# El objetivo por defecto tiene que ser uno VIVO: si el marcado es un cadaver, lo que ve el
	# jugador no seria lo que va a pasar (el anfitrion cae al primer vivo en _objetivo()).
	_apuntar_al_primer_vivo()
	var b := Button.new()
	b.text = "⚡ ¡Soltar %s!" % nombre
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, _pantalla.ALTO_BOTON_ACCION)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(_on_soltar_pulsado)
	_pantalla._cast_box.add_child(b)
	_pantalla._alto_panel(_pantalla.ALTO_BOTON_ACCION)
	_pantalla._cast_box.visible = true
	_pantalla._set_log("%s está lista. Elige a quién y suéltala." % nombre)
	_pantalla._ocultar_log()   # el boton ocupa el sitio del historial, igual que el de disparo


# Si el objetivo marcado esta muerto (o no hay), se apunta al primer vivo y se repinta la seleccion.
func _apuntar_al_primer_vivo() -> void:
	if _pantalla._target_idx >= 0 and _pantalla._target_idx < _pantalla._enemies.size() and _pantalla._enemies[_pantalla._target_idx].is_alive():
		return
	for i in _pantalla._enemies.size():
		if _pantalla._enemies[i].is_alive():
			_pantalla.figuras._seleccionar(i)
			return


# ESPEJO: mi carga esta lista, el boton va aqui. Con los DOS guardias de eco de lanzar_conjuro, o el
# reenvio del heartbeat me repinta el boton de una carga que ya solte.
func soltar_carga(nombre: String, seq: int = 0) -> void:
	if not _pantalla._espejo:
		return
	if seq != 0 and seq == _pantalla.espejo._seq_contestada:
		_pantalla._traza_add("me repiten la carga #%d, que YA conteste: la ignoro" % seq)
		return
	if seq != 0:
		_pantalla.espejo._seq_espejo = seq
	if _pantalla._state == _pantalla.State.WAITING_PLAYER and _pantalla._cast_box != null and _pantalla._cast_box.visible:
		return   # repeticion del anfitrion: ya tengo el boton delante
	_pantalla._traza_add("ME PIDEN SOLTAR (#%d) %s" % [seq, nombre])
	_pantalla._state = _pantalla.State.WAITING_PLAYER
	_pintar_soltar(nombre)


# El boton. En el espejo NO se pasa por _usar_habilidad: su rama espejo manda {"tipo": "habilidad"},
# que _encaja_con_lo_pedido rechazaria contra un "soltar" pendiente y dejaria la pelea colgada hasta
# el heartbeat.
func _on_soltar_pulsado() -> void:
	if _pantalla._state != _pantalla.State.WAITING_PLAYER:
		return
	if _pantalla._espejo:
		_pantalla.espejo._responder_al_anfitrion({"tipo": "soltar", "obj": _pantalla._target_idx})
		return
	_soltar_la_carga()


# La orden, ya con objetivo. Un solo sitio para los dos caminos (el boton local y el remoto).
func _soltar_la_carga() -> void:
	if _pantalla._state != _pantalla.State.WAITING_PLAYER or _pantalla._player == null or _pantalla._player.charging == null:
		return
	if not _pantalla._player.is_alive():
		return   # se lo han llevado entre la peticion y la respuesta
	var ab: AbilityData = _pantalla._player.charging
	_pantalla._player.charging = null
	_pantalla._player.charge_left = 0
	# 'soltando': ni cobra energia ni arranca cooldown otra vez, que se pagaron al empezarla.
	_usar_habilidad(ab, true)


# ============================================================
#  HABILIDADES (KAN-57): submenu del loadout + resolucion
# ------------------------------------------------------------
func _accion_habilidad() -> void:
	_pantalla._ocultar_cajas()
	for c in _pantalla._ability_box.get_children():
		c.queue_free()
	# EN EL ORDEN DE LOS HUECOS, el que pusiste tu arrastrando en el gestor. Antes esto hacia un
	# sort_custom por coste de energia descendente y tiraba tu orden entero: daba igual donde
	# colocaras cada habilidad, en la pelea salian como quisiera el coste. Y el gestor tiene cuatro
	# huecos justamente para que el 1 sea el que tienes mas a mano.
	var abils: Array = _pantalla._player.abilities_combate.duplicate()
	# Hasta el ULTIMO hueco ocupado, no siempre los cuatro: los huecos de EN MEDIO se pintan vacios
	# (si no, el 3 se subiria al sitio del 2 y las posiciones dejarian de ser fijas), pero los que
	# sobran AL FINAL no se pintan, que serian botones muertos colgando.
	var ultimo: int = -1
	for i in abils.size():
		if abils[i] != null:
			ultimo = i
	var celdas: int = ultimo + 1
	var grid := _pantalla._rejilla_submenu(_pantalla._ability_box)
	for i in celdas:
		var ab = abils[i]
		if ab == null:
			# Un hueco que dejaste vacio a proposito. Ocupa su sitio y no hace nada.
			var vacio := Button.new()
			vacio.text = "—"
			vacio.disabled = true
			vacio.tooltip_text = "Hueco %d, sin habilidad puesta" % (i + 1)
			_pantalla._celda_submenu(vacio)
			grid.add_child(vacio)
			continue
		var manos: int = _pantalla._player.ability_manos(ab)
		var es_conv: bool = ab.energia_a_mana > 0.0   # Canalizar: gasta toda la energia
		var coste: float = _pantalla._player.current_energy if es_conv else ab.coste(manos)
		var cd_left: int = _pantalla._player.ability_cd_left(ab)
		var b := TooltipButton.new()
		var cd_txt := "  ⏳%d" % cd_left if cd_left > 0 else ""
		var costo_txt := ("toda EN → %.1f MP" % (coste / ab.energia_a_mana)) if es_conv else ("%.0f EN" % coste)
		# A media anchura no cabe todo: en el boton van el nombre, el coste y el cooldown (que es
		# lo que decide si puedes pulsarlo AHORA), y las cargas de Foco se quedan para el tooltip.
		var foco_txt := "  🔮%d cargas" % ab.foco_cargas if ab.foco_cargas > 0 else ""
		b.text = "%s  (%s)%s" % [ab.nombre, costo_txt, cd_txt]
		# Tooltip: datos DERIVADos de los campos (resumen) + el sabor de la descripcion.
		b.tooltip_text = foco_txt.strip_edges() + "\n" + ab.resumen(manos) if foco_txt != "" else ab.resumen(manos)
		if ab.descripcion != "":
			b.tooltip_text += "\n\n" + ab.descripcion
		if cd_left > 0:
			b.disabled = true
			b.tooltip_text = "⛔ En cooldown: %d turno%s\n\n%s" % [cd_left, "" if cd_left == 1 else "s", b.tooltip_text]
		elif ab.foco_cargas > 0 and _pantalla._player.foco_cargas > 0:
			b.disabled = true
			b.tooltip_text = "⛔ Aún te quedan %d cargas de Foco arcano: gástalas antes\n\n%s" % [_pantalla._player.foco_cargas, b.tooltip_text]
		elif es_conv and _pantalla._player.current_energy < ab.energia_a_mana:
			b.disabled = true
			b.tooltip_text = "⛔ Necesitas al menos %.0f EN\n\n%s" % [ab.energia_a_mana, b.tooltip_text]
		elif not es_conv and not _pantalla._player.has_energy(coste):
			b.disabled = true
			b.tooltip_text = "⛔ Sin energía suficiente\n\n%s" % b.tooltip_text
		elif ab.excluye_al_lanzador() and _aliados_hab(ab).is_empty():
			b.disabled = true
			b.tooltip_text = "⛔ No tienes a nadie más a quien cubrir\n\n%s" % b.tooltip_text
		# Las que caen sobre un aliado preguntan A QUIEN antes de resolverse, igual que un Filo.
		if ab.objetivo_aliado == AbilityData.Objetivo.ALIADO:
			b.pressed.connect(_elegir_aliado_habilidad.bind(ab))
		else:
			b.pressed.connect(_usar_habilidad.bind(ab))
		_pantalla._celda_submenu(b)
		grid.add_child(b)
	_pantalla._cerrar_submenu(_pantalla._ability_box, celdas, _pantalla._mostrar_acciones)
	_pantalla._ocultar_log()   # el submenu ocupa el sitio del historial


# Los OBJETIVOS de una habilidad de ÁREA: el principal SIEMPRE el primero, y detrás sus
# vecinos VIVOS más cercanos (alternando izquierda/derecha) hasta llenar area_max. Reusa la
# misma geometría que el salpicón de los hechizos: los cadáveres no cuentan ni desplazan la
# numeración (ver _adyacentes_vivos). area_max >= nº de vivos -> toca a todos.
func _objetivos_hab(ab: AbilityData, principal: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = [principal]
	if not ab.es_area() or ab.area_max <= 1:
		return out
	var centro: int = _pantalla._enemies.find(principal)
	if centro < 0:
		return out
	# Punteros que se alejan del centro a cada lado; cogemos el primer vivo de cada tanda.
	var izq: int = centro - 1
	var der: int = centro + 1
	while out.size() < ab.area_max:
		var anadido := false
		# Izquierda: primer vivo hacia el borde.
		while izq >= 0:
			if _pantalla._enemies[izq].is_alive():
				out.append(_pantalla._enemies[izq]); izq -= 1; anadido = true
				break
			izq -= 1
		if out.size() >= ab.area_max:
			break
		# Derecha: primer vivo hacia el borde.
		while der < _pantalla._enemies.size():
			if _pantalla._enemies[der].is_alive():
				out.append(_pantalla._enemies[der]); der += 1; anadido = true
				break
			der += 1
		if not anadido:
			break   # no quedan vivos a ningún lado
	return out


# El enemigo VIVO más cercano a 'muerto' (para redirigir los golpes que sobran de una flurry
# cuando el objetivo cae). Primero mira a los lados; si no, el primero vivo que haya. null si no
# queda nadie.
func _siguiente_vivo(muerto: Combatant) -> Combatant:
	var centro: int = _pantalla._enemies.find(muerto)
	if centro >= 0:
		for paso in [-1, 1]:
			var i: int = centro + paso
			while i >= 0 and i < _pantalla._enemies.size():
				if _pantalla._enemies[i].is_alive():
					return _pantalla._enemies[i]
				i += paso
	var vivos: Array[Combatant] = _pantalla._vivos()
	return vivos[0] if not vivos.is_empty() else null


# Resuelve UN golpe de habilidad sobre 'objetivo' con 'escala' extra (área: salpicón o falloff
# del barrido; 1.0 = golpe pleno). Aplica daño, imbuición, maná por golpe y —si la habilidad es
# efectos_por_golpe— sus estados. Devuelve un dict con lo necesario para acumular y loguear.
# 'etq' etiqueta el objetivo en el log cuando hay varios ("" en single-target).
func _resolver_golpe_hab(ab: AbilityData, objetivo: Combatant, i: int, manos: int,
		escala: float, etq: String, m_golpe: float) -> Dictionary:
	# 'c' = a QUIEN fue este golpe. Lo necesita el log para decir el reparto por enemigo (mismo
	# campo que usan los resultados de hechizo, ver _log_hechizo). 'm_golpe' = el multiplicador que
	# le toca a ESTE golpe segun el plan (mano principal/segunda del dual, o arma/escudo).
	var r := {"c": objetivo, "dmg": 0.0, "imbue": 0.0, "mult_imbue": 1.0, "crit": false,
		"evaded": false, "mana": 0.0, "conecto": false, "estados": [], "linea": "",
		"robado": 0.0}
	# Los golpes DE ESCUDO pegan con tu DEFENSA, no con tu arma (ver AbilityData.escudo_desde_golpe).
	# En Guardia rota / Aplastamiento eso significa que el golpe 0 va con Ataque y el 1 con Defensa:
	# cada uno con su atributo.
	var atk_ov: float = _pantalla._player.atk_escudo() if ab.golpe_es_de_escudo(i) else -1.0
	# TODO lo de este golpe cae a la vez, alcance a uno o a cuatro: un molinete es UN barrido por
	# golpe, no un golpecito por bicho. La resolucion sigue yendo objetivo a objetivo; lo unico que
	# se agrupa es como se ve (ver _fx_tanda).
	_pantalla.efectos._fx_tanda(i)
	# Manda lo que pida la habilidad (fx_estilo) y, si no pide nada, el gesto del arma con la que
	# esta pegando. Igual que la rata, que muerde le salga la tecnica o no.
	#
	# CON UNA EXCEPCION: un golpe DE ESCUDO se ve como un escudazo, pegue lo que pegue la habilidad.
	# Guardia rota es un tajo Y un golpe de escudo, y con el estilo de la habilidad para los dos se
	# veian dos tajos iguales -- justo lo contrario de lo que dice su ficha. Es la misma regla que ya
	# sigue el DAÑO: el golpe de escudo pega con tu Defensa y no con el arma (ver atk_escudo), asi
	# que tambien tiene que verse como lo que es.
	#
	# Y CON UNA EXCEPCION A LA EXCEPCION: si la tecnica es ENTERA de escudo y pide dibujo propio, manda
	# el suyo (ver AbilityData.es_toda_de_escudo). La Embestida se da toda con el escudo pero no es un
	# escudazo -- es una carga con el hombro detras --, y sin esto no habia forma de que lo enseñara.
	# El Golpe de escudo, que si es un escudazo y punto, no pide nada y se queda con el respaldo.
	var estilo_ab: int = _pantalla.efectos._estilo_de_habilidad(ab, _pantalla._player)
	if ab.golpe_es_de_escudo(i) and not (ab.es_toda_de_escudo() and ab.fx_estilo >= 0):
		estilo_ab = CombatFX.Estilo.ESCUDAZO
	var result := StatsMath.resolve_attack(_pantalla._player, objetivo, false, atk_ov)
	if result.evaded:
		r.evaded = true
		r.linea = "golpe %d%s: esquivado 💨" % [i + 1, etq]
		_pantalla.efectos._fx_golpe(_pantalla._player, objetivo, 0.0, false, true, Elementos.Elemento.NINGUNO, estilo_ab)
		return r
	var dmg: float = result.damage * ab.dano_mult * m_golpe * escala
	r.dmg = dmg
	r.imbue = float(result.get("dmg_imbue", 0.0)) * ab.dano_mult * m_golpe * escala
	r.mult_imbue = float(result.get("mult_imbue", 1.0))
	objetivo.take_damage(dmg)
	# ROBO DE VIDA (AbilityData.robo_vida): sobre el daño que de verdad ha entrado. Hoy no lo usa
	# ninguna tecnica del jugador -- lo estrena el Drenaje del chupasimas, en la rama de enfrente --
	# pero va tambien aqui porque el campo es de AbilityData: si solo se enchufara en la rama del
	# enemigo, una habilidad del jugador con robo_vida no curaria nada y no daria ningun error.
	if ab.robo_vida > 0.0:
		r.robado = dmg * ab.robo_vida
		_pantalla._player.heal(r.robado)
	_pantalla.efectos._fx_golpe(_pantalla._player, objetivo, dmg, result.crit, false,
		_pantalla._player.imbue_elemento if r.imbue > 0.0 else Elementos.Elemento.NINGUNO, estilo_ab)
	_pantalla._apuntar_dano(objetivo, dmg, _pantalla._player)   # contador oculto de Cazador
	r.mana = _pantalla._ganar_mana_golpe()       # cada golpe que conecta repone maná
	if float(result.get("dmg_imbue", 0.0)) > 0.0:
		_pantalla.magia._gastar_amplificadores(objetivo, _pantalla._player.imbue_elemento)
	r.conecto = true
	r.crit = result.crit
	var esc_txt: String = "" if is_equal_approx(escala, 1.0) else " [%d%%]" % roundi(escala * 100.0)
	# Etiqueta de "con qué se pega": arma+escudo distingue arma/escudo; el dual, la 2ª mano.
	var mano_txt: String = ""
	if ab.escudo_desde_golpe >= 0:
		# Se dice con QUE se pega y, en el escudazo, que va con la DEFENSA: es la unica pista de
		# que subir armadura le sube el daño a ese golpe.
		mano_txt = " [escudo · DEF]" if ab.golpe_es_de_escudo(i) else " [arma]"
		if ab.golpe_es_de_escudo(i) and m_golpe < 1.0:
			mano_txt = " [escudo · DEF %d%%]" % roundi(m_golpe * 100.0)
	elif m_golpe < 1.0:
		mano_txt = " [2ª mano %d%%]" % roundi(m_golpe * 100.0)
	r.linea = "golpe %d%s%s%s: %s %.2f%s" % [i + 1, etq, mano_txt, esc_txt,
		("CRITICO 💥" if result.crit else "acierta"), dmg,
		_pantalla.magia._imbue_dmg_txt(result, ab.dano_mult * m_golpe * escala)]
	# IMBUICION: cada golpe que acierta tira su estado (multi-golpe = más tiradas).
	if ab.efectos_por_golpe and objetivo.is_alive():
		# "objetivo": los buffs propios NO se tiran aqui (un multi-golpe los aplicaria una vez por
		# tajo). Se hacen una sola vez al final de la habilidad, en _usar_habilidad.
		# 'escala' es la fraccion de daño que encaja ESTE objetivo, y con ella va la probabilidad:
		# al de al lado que se come el 40% del golpe le prende el estado un 40% de las veces.
		var ap: Array = _tirar_efectos_habilidad(ab, objetivo, result.crit, "objetivo", escala, escala)
		r.estados = ap
		if not ap.is_empty():
			r.linea += "  -> " + ", ".join(ap)
	if objetivo.is_alive():
		var imb_h: String = _pantalla._player.roll_imbue(objetivo)
		if imb_h != "":
			r.estados.append(imb_h)
			r.linea += "  ⚡ " + imb_h
	return r


# A quien se le puede echar una habilidad de aliado: los vivos, sin el que la usa si es de cubrir.
func _aliados_hab(ab: AbilityData) -> Array[Combatant]:
	var vivos: Array[Combatant] = _pantalla._aliados_vivos()
	if ab.excluye_al_lanzador():
		vivos.erase(_pantalla._player)
	return vivos


# Segundo paso de las habilidades que caen sobre UN ALIADO (Purificar, Égida menor): a quien.
# Mismo patron que el de los hechizos (_elegir_objetivo_aliado), pero en la caja de habilidades.
# Con un solo aliado en pie no se pregunta nada: va directa a el.
func _elegir_aliado_habilidad(ab: AbilityData) -> void:
	var vivos: Array[Combatant] = _aliados_hab(ab)
	if vivos.is_empty():
		return   # el boton ya sale apagado en este caso (ver el menu de habilidades)
	if vivos.size() == 1:
		_pantalla._hab_aliado = vivos[0]
		_usar_habilidad(ab)
		return
	for c in _pantalla._ability_box.get_children():
		c.queue_free()
	var grid := _pantalla._rejilla_submenu(_pantalla._ability_box)
	for al in vivos:
		var b := TooltipButton.new()
		var estados: String = al.status_summary()
		b.text = "%s  (%.0f/%.0f ♥)" % [al.nombre, al.current_hp, al.max_hp]
		b.tooltip_text = "%s usa %s sobre %s.%s" % [_pantalla._player.nombre, ab.nombre, al.nombre,
			"\n\nAhora lleva: %s" % estados if estados != "" else "\n\nNo tiene ningún estado encima."]
		b.pressed.connect(func():
			_pantalla._hab_aliado = al
			_usar_habilidad(ab))
		_pantalla._celda_submenu(b)
		grid.add_child(b)
	_pantalla._cerrar_submenu(_pantalla._ability_box, vivos.size(), _accion_habilidad)
	_pantalla._ocultar_log()


# EL JUGADOR EMPIEZA A CARGAR. El turno se va en anunciarlo, y aturdirte te la interrumpe (ver
# _begin_player_turn).
#
# El OBJETIVO no se guarda, y ahora eso es literal: al llegar el turno de soltarla se le PREGUNTA a
# su dueño a quien (boton "Soltar X" + clic en el bloque, ver _pedir_soltar_carga). Dos turnos son
# muchos en una pelea y el bicho al que apuntabas puede estar muerto, asi que apuntar al empezar no
# valdria de nada; y en multi el _target_idx de esta pantalla no es el suyo.
func _empezar_carga_jugador(ab: AbilityData) -> void:
	_pantalla._player.charging = ab
	_pantalla._player.charge_left = ab.carga_turnos
	print("[habilidad] %s empieza a cargar %s (%d turno%s)" % [
		_pantalla._player.nombre, ab.nombre, ab.carga_turnos, "" if ab.carga_turnos == 1 else "s"])
	_pantalla._set_log("⚡ %s se prepara para %s. (si te aturden, se interrumpe)" % [_pantalla._player.nombre, ab.nombre])
	_pantalla._fin_de_eleccion()   # cierra la accion: oculta las cajas y repinta (aqui sale el chip ⚡)
	_pantalla._tras_accion_jugador_varios([])   # pasa el turno sin rematar a nadie: no ha habido golpe


# 'soltando' = esta habilidad viene de una CARGA que acaba de llegar a cero (la dispara
# _begin_player_turn). Cuando es true no se vuelve a cobrar ni a validar nada: la energia y el
# cooldown se pagaron al EMPEZAR a cargar, hace dos turnos.
func _usar_habilidad(ab: AbilityData, soltando: bool = false) -> void:
	# En el espejo se elige, pero resuelve el anfitrion: le viaja QUE habilidad (por su ruta) y
	# contra quien. El la busca en el loadout de mi personaje, que es el mismo que tiene el.
	if _pantalla._espejo and ab != null:
		# Y A QUIEN, si es de aliado: como la magia, por indice en _aliados. No viajaba, y el anfitrion
		# resolvia el Muro del que se unia siempre sobre si mismo.
		var ia_h: int = -1
		if ab.objetivo_aliado == AbilityData.Objetivo.ALIADO and _pantalla._hab_aliado != null:
			ia_h = _pantalla._aliados.find(_pantalla._hab_aliado)
		_pantalla.espejo._responder_al_anfitrion({"tipo": "habilidad", "ruta": ab.resource_path, "obj": _pantalla._target_idx,
			"aliado": ia_h})
		return
	# OBJETIVO capturado UNA vez, al principio de la accion. No se vuelve a preguntar por el
	# dentro del bucle de golpes a proposito: si el objetivo cae al tercer tajo de una habilidad
	# de cinco, los dos que quedan tienen que caer en el vacio, no saltar solos al siguiente
	# enemigo. Una accion = un objetivo, el que elegiste al lanzarla.
	var obj: Combatant = _pantalla._objetivo()
	# Manos que aportan ESTA habilidad (dual solo si son 2: daga+daga, no daga+estoque).
	var idxs: Array = _pantalla._player.ability_hand_indices(ab)
	var manos: int = maxi(1, idxs.size())
	var es_conversion: bool = ab.energia_a_mana > 0.0   # Canalizar: gasta TODA la energia
	var coste: float = _pantalla._player.current_energy if es_conversion else ab.coste(manos)
	# Al SOLTAR una carga no se valida ni se cobra: ya se hizo al empezarla, y volver a exigir
	# energia aqui te dejaria la habilidad a medias por haberte quedado seco entre medias.
	if not soltando:
		# Fuera de turno = ni es una eleccion ni hay turno que gastar (un click perdido, un eco de la
		# interfaz): se ignora y ya. Es el UNICO caso que sale por un return seco, ver abajo.
		if _pantalla._state != _pantalla.State.WAITING_PLAYER:
			return
		# LA HABILIDAD NO SE PUEDE LANZAR (en cooldown, con cargas de Foco pendientes, sin energia).
		# En local no llegas aqui: el boton sale deshabilitado. Pero una eleccion REMOTA se valida en
		# esta maquina, y su pantalla puede estar mintiendole (era el caso del dual perdido: el espejo
		# le ponia Rafaga a 48 EN, la pulsaba con 50 y aqui costaba 70). Un return seco dejaba la
		# pelea COLGADA PARA TODOS: _aplicar_accion_remota ya hizo _fin_de_espera, asi que nadie
		# vuelve a pedirle el turno y el estado se queda en WAITING_PLAYER para siempre.
		# Se cae a basico, igual que cuando la habilidad ya no esta en su loadout: no se pierde el turno.
		#
		# Y DICE POR QUE. Antes solo imprimia "no puede lanzarla": desde el mando eso es un basico que
		# sale de la nada, indistinguible de un bug de la interfaz, y asi se pierde una tarde buscando
		# el fallo donde no esta. El motivo es lo que delata cual de las tres puertas se cerro y, si es
		# una pantalla que miente, en que campo.
		var motivo: String = ""
		if not _pantalla._player.ability_ready(ab):
			motivo = "le quedan %d turno(s) de cooldown" % _pantalla._player.ability_cd_left(ab)
		elif ab.foco_cargas > 0 and _pantalla._player.foco_cargas > 0:
			motivo = "aún le quedan %d cargas de Foco por gastar" % _pantalla._player.foco_cargas
		elif es_conversion:
			if _pantalla._player.current_energy < ab.energia_a_mana:
				motivo = "necesita %.0f EN y tiene %.0f" % [ab.energia_a_mana, _pantalla._player.current_energy]
		elif not _pantalla._player.has_energy(coste):
			motivo = "cuesta %.0f EN a %d mano(s) y tiene %.0f" % [coste, manos, _pantalla._player.current_energy]
		if motivo != "":
			print("[habilidad] %s no puede lanzar %s (%s): ataca de basico" % [
				_pantalla._player.nombre, ab.nombre, motivo])
			_pantalla._set_log("%s no puede usar %s: %s. Ataca normal." % [_pantalla._player.nombre, ab.nombre, motivo])
			_pantalla._accion_atacar()
			return
		# ATAQUE DE CARGA: si la habilidad tarda turnos en soltarse, este turno se va en ANUNCIARLA.
		# Va DESPUES de cobrar la energia y ANTES de resolver nada: te comprometes al empezar.
		# El campo existia desde siempre (AbilityData.carga_turnos) y la ficha lo prometia, pero solo
		# lo implementaba la rama ENEMIGA: las del jugador se disparaban al instante. Ver
		# _enemy_begin_charge.
		#
		# LAS DOS RAMAS YA NO SON ESPEJO, y es a proposito: la del BICHO sigue resolviendose sola al
		# llegar su turno (_enemy_turn), y la del JUGADOR pide la orden a su dueño con un boton
		# "Soltar X" para que elija objetivo (ver _pedir_soltar_carga). Antes se disparaba sola con el
		# _target_idx de la pantalla, que en multi era el ultimo clic del anfitrion.
		if ab.carga_turnos > 0:
			_pantalla._player.spend_energy(coste)
			_pantalla._player.start_cooldown(ab)
			_empezar_carga_jugador(ab)
			return
		_pantalla._player.spend_energy(coste)
		_pantalla._player.start_cooldown(ab)   # entra en cooldown (si la habilidad tiene)
	# Maná recuperado: FIJO (mana_gain) + por CONVERSION de toda la energia (energia_a_mana).
	# Al SOLTAR una carga la conversion NO paga otra vez: la energia se fundio al empezarla, y aqui
	# 'coste' vale lo que tengas AHORA. Sin este guardia, una habilidad de conversion con carga te
	# daria maná gratis por energia que ya no gastas.
	var mana_ganado: float = ab.mana_gain
	if es_conversion and not soltando:
		mana_ganado += coste / ab.energia_a_mana
	if mana_ganado > 0.0:
		_pantalla._player.regen_mana(mana_ganado)
	var mana_txt := "  +%.1f MP" % mana_ganado if mana_ganado > 0.0 else ""
	# Al soltar una carga el coste ya se pago hace dos turnos: decir "76 EN" aqui haria pensar que se
	# cobra dos veces cuando se lea el log buscando por que alguien se queda sin energia.
	print("[habilidad] %s usa %s  (%s, %s%s)" % [
		_pantalla._player.nombre, ab.nombre, ("dual" if manos >= 2 else "1 mano"),
		"carga soltada, ya pagada" if soltando else "%.0f EN" % coste, mana_txt])
	var total: float = 0.0
	var total_imbue: float = 0.0   # cuanto del total lo ha puesto la imbuicion (va DENTRO de 'total')
	var mult_imbue: float = 1.0
	var golpes: int = 0
	var estados_log: Array = []
	var tocados: Array = [obj]      # todos los enemigos alcanzados: se rematan AL FINAL, de una vez
	# LOG: el RASTRO (un token por golpe, en orden: "4.21" / "falla" / "💥9.80") y el REPARTO
	# (Combatant -> daño acumulado). Antes el desglose golpe a golpe solo iba a la consola y en
	# pantalla salia un "0 de daño (2 golpes)" que no explicaba nada.
	var rastro: Array = []
	var dano_por_obj: Dictionary = {}
	# ¿Alguno de los golpes fue CRITICO? Se declara AQUI FUERA, y no dentro del bloque de golpes,
	# porque lo necesita la tirada de efectos, que ahora vive fuera (ver el bloque de EFECTOS mas
	# abajo). Sin golpes se queda en false, que es lo correcto: una habilidad que no pega no critea.
	var hubo_critico: bool = false
	# GOLPES de daño (rango aleatorio; cada tajo con su ESQUIVA y CRITICO propios). Si
	# efectos_por_golpe, cada tajo que acierta tira los efectos (sangrado 40%/hit).
	# Las de UTILIDAD PURA (dano_mult 0, p.ej. Canalizar) NO golpean.
	if ab.dano_mult > 0.0:
		golpes = ab.num_golpes(manos, _pantalla._vivos().size())   # flurries: más golpes cuantos más enemigos
		# PLAN de golpes: mano y multiplicador de cada uno. Intercala las manos del dual (der, izq,
		# der, izq) y, en arma+escudo, alterna arma (fuerte) / escudo (flojo). Ver ab.plan_golpes.
		var plan: Array = ab.plan_golpes(golpes, manos)
		var conecto: int = 0
		# Aciertos POR OBJETIVO (combatiente -> nº de golpes que le entraron). El contador de arriba
		# es el total contra TODOS y no vale para decidir a quien se le aplican los efectos: ver el
		# bloque de efectos no-por-golpe al final del bucle.
		var conecto_por_obj: Dictionary = {}
		# FRACCION DE DAÑO que ha encajado cada objetivo (1.0 el principal, menos los secundarios de
		# un area). De aqui sale la probabilidad de que les prenda el estado: quien se come el 40%
		# del golpe tiene el 40% de la tirada. Derivarlo del daño y no de un campo aparte hace que
		# al tocar area_secundario / area_falloff esto se ajuste solo.
		var escala_por_obj: Dictionary = {}
		var mana_ganado_golpes: float = 0.0
		# Objetivos del ÁREA (el principal siempre el primero). En single-target = [obj].
		var objetivos: Array[Combatant] = _objetivos_hab(ab, obj)
		tocados = []
		for i in golpes:
			# La mano activa alterna con el dual (daga+daga); con una sola arma, siempre la misma.
			var m_golpe: float = float(plan[i]["mult"])
			_pantalla._player.set_active_hand(idxs[mini(int(plan[i]["hand"]), idxs.size() - 1)])
			var golpe_res: Array = []   # resultados de ESTE golpe (varios si es área)
			match ab.area_modo:
				AbilityData.AreaModo.SPLASH:
					# Principal al 100%, cada secundario x el % que toca (baja con la multitud si la
					# habilidad tiene decay). El total CRECE con cada enemigo tocado.
					var n_vivos_s: int = 0
					for t in objetivos:
						if t.is_alive(): n_vivos_s += 1
					var esc_sec: float = ab.secundario_para(n_vivos_s)
					for t in objetivos:
						if not t.is_alive():
							continue
						var esc: float = 1.0 if t == obj else esc_sec
						var etq: String = "" if t == obj else " (%s)" % t.nombre
						golpe_res.append(_resolver_golpe_hab(ab, t, i, manos, esc, etq, m_golpe))
						escala_por_obj[t] = maxf(float(escala_por_obj.get(t, 0.0)), esc)
						if t not in tocados: tocados.append(t)
				AbilityData.AreaModo.BARRIDO:
					# Todos reciben el golpe, pero x falloff^(n-1) con n = vivos alcanzados EN ESTE
					# golpe (se recalcula): si uno cae, n baja y el resto pega más fuerte.
					var vivos_alc: Array = objetivos.filter(func(c): return c.is_alive())
					var n: int = vivos_alc.size()
					var esc_b: float = pow(ab.area_falloff, maxi(0, n - 1))
					for t in vivos_alc:
						var etq2: String = "" if t == obj else " (%s)" % t.nombre
						golpe_res.append(_resolver_golpe_hab(ab, t, i, manos, esc_b, etq2, m_golpe))
						escala_por_obj[t] = maxf(float(escala_por_obj.get(t, 0.0)), esc_b)
						if t not in tocados: tocados.append(t)
				_:
					# SIN área. Un objetivo; si cae y la habilidad REDIRIGE, salta al siguiente vivo.
					var actual: Combatant = obj
					if not actual.is_alive() and ab.redirige_al_morir:
						actual = _siguiente_vivo(actual)
					if actual == null or not actual.is_alive():
						break   # nadie a quien pegar: los golpes que quedan se pierden
					golpe_res.append(_resolver_golpe_hab(ab, actual, i, manos, 1.0,
						"" if actual == obj else " (%s)" % actual.nombre, m_golpe))
					if actual not in tocados: tocados.append(actual)
			# Acumular y loguear los golpes resueltos, en orden.
			for r in golpe_res:
				total += r.dmg
				total_imbue += r.imbue
				if r.dmg > 0.0:
					mult_imbue = r.mult_imbue
				if r.conecto:
					conecto += 1
					# Y POR OBJETIVO, que es lo que decide luego a quien se le tiran los efectos: el
					# contador de arriba suma los aciertos contra CUALQUIERA, asi que no sirve para
					# saber si a ESTE le llego algo. Ver el bloque de efectos no-por-golpe.
					conecto_por_obj[r.c] = int(conecto_por_obj.get(r.c, 0)) + 1
				if r.crit:
					hubo_critico = true
				mana_ganado_golpes += r.mana
				estados_log += r.estados
				# Token de ESTE golpe para el rastro del log (con su objetivo: si la habilidad toca a
				# varios, al final se le pega la etiqueta de a quien fue), y su daño a la cuenta
				# del objetivo para el reparto.
				rastro.append({"t": "falla" if r.evaded
					else ("💥%.2f" % r.dmg if r.crit else "%.2f" % r.dmg), "c": r.c})
				dano_por_obj[r.c] = float(dano_por_obj.get(r.c, 0.0)) + r.dmg
				print("        " + r.linea)
			# Fin de la habilidad si, sin área ni redirección, el objetivo ya cayó (los que
			# sobran no saltan solos). En área/barrido seguimos: aún puede quedar gente viva.
			if ab.area_modo == AbilityData.AreaModo.NINGUNO and not ab.redirige_al_morir \
					and not obj.is_alive():
				break
			# Si no queda NADIE vivo entre los objetivos, no hay a quién seguir pegando.
			if _pantalla._vivos().is_empty():
				break
		# Efectos NO por golpe: UNA tirada al final por cada objetivo VIVO AL QUE LE ENTRO ALGUN
		# GOLPE (golpe de escudo -> stun; Onda -> aturde+ralentiza a los que alcanzo de verdad).
		#
		# EL QUE ESQUIVA NO SE COME EL DEBUFF. Esto se preguntaba con el contador GLOBAL (`conecto`),
		# que suma los aciertos contra cualquiera, y se aplicaba a todo `tocados` -- y en `tocados`
		# entra cualquier enemigo BARRIDO por el area, esquive o no (los mete _resolver_golpe_hab
		# antes de saber si esquivo). Resultado: en un area contra tres bichos, si le acertabas a uno
		# solo, los otros dos se comian el aturdido igual sin haber sido tocados. Lo mismo con
		# redirige_al_morir. Ahora se mira acierto POR OBJETIVO, que es justo lo que ya hacia la rama
		# enemiga (_enemy_resolver_golpes lleva su `conecto` de uno en uno porque se llama por bicho).
		#
		# Vale para todos sin escribirlo dos veces: las acciones de los compas y de los otros
		# jugadores las resuelve el anfitrion por esta misma funcion (ver aplicar_accion_remota).
		if not ab.efectos_por_golpe:
			for t in tocados:
				if t.is_alive() and int(conecto_por_obj.get(t, 0)) > 0:
					# "objetivo": aqui solo van los efectos que le lanzas AL RIVAL. Los buffs propios
					# se aplican una sola vez, justo debajo -- si fueran por este bucle, un area
					# contra tres bichos te daria el buff tres veces.
					estados_log += _tirar_efectos_habilidad(ab, t, hubo_critico, "objetivo",
						float(escala_por_obj.get(t, 1.0)), float(escala_por_obj.get(t, 1.0)))
		# Excelia: como el ataque, entrena Fuerza (por impacto medio, contra el principal).
		var pj_hab: PersonajeData = Game.pj_de_combatant(_pantalla._player)
		Game.ganar("fuerza", _pantalla._reto(obj, pj_hab) * _pantalla._player.motion_value, Game.GAIN_FUERZA_ATAQUE,
			Game.RETO_MAX_FISICO, pj_hab)
		# Y si en la habilidad ha entrado algun CRITICO, entrena Agilidad igual que el basico: el
		# hueco lo encuentras igual con una habilidad que con un espadazo suelto. Antes esta rama
		# solo pagaba Fuerza, asi que a quien juega a base de habilidades —o sea, cualquiera en
		# cuanto tiene energia— la Agilidad no le subia por critear en toda la pelea.
		# Se paga UNA vez por habilidad aunque hayan criteado varios golpes (mismo criterio que la
		# esquiva de las habilidades enemigas) y con el mismo tope de peso que el basico.
		if hubo_critico:
			Game.ganar("agilidad", _pantalla._reto(obj, pj_hab)
				* minf(_pantalla._player.motion_value, Game.GAIN_AGILIDAD_CRIT_MV_MAX),
				Game.GAIN_AGILIDAD_CRITICO, Game.RETO_MAX_FISICO, pj_hab)
		print("        total: %.2f de daño en %d golpe%s%s | EN -%.0f -> %.1f/%.1f%s" % [
			total, golpes, "" if golpes == 1 else "s",
			_pantalla.magia._desglose_imbue(total, total_imbue, mult_imbue),
			0.0 if soltando else coste, _pantalla._player.current_energy, _pantalla._player.max_energy,
			"" if mana_ganado_golpes <= 0.0 else " | MP +%.1f -> %.1f/%.1f" % [
				mana_ganado_golpes, _pantalla._player.current_mp, _pantalla._player.max_mp]])
		# El maná que han repuesto los golpes se suma al del propio efecto de la habilidad
		# (mana_gain), que ya se aplico arriba: aqui solo se junta para el mensaje.
		mana_ganado += mana_ganado_golpes
		_pantalla._dps_add(ab.nombre, total)
		# Una habilidad = UN uso de imbuicion, traiga los golpes que traiga (si no, las
		# multi-golpe la fundirian de una). Las de utilidad pura (Canalizar) no la gastan.
		_pantalla.magia._gastar_imbue()
	else:
		# UTILIDAD PURA (dano_mult 0): no hay golpes, pero SI puede llevar efectos que le lanzas al
		# rival (un debuff sin daño). Sin esta rama se perdian: no hay acierto que comprobar, asi que
		# entran directos, y su propia `prob` decide.
		for t in _objetivos_hab(ab, obj):
			if t != null and t.is_alive():
				estados_log += _tirar_efectos_habilidad(ab, t, false, "objetivo")

	# BUFFS PROPIOS (en_objetivo = false): UNA vez por uso, pegue la habilidad o no.
	#
	# ESTO ESTABA DENTRO DEL `if ab.dano_mult > 0.0` y era un agujero de los gordos: las OCHO
	# habilidades de puro apoyo del jugador (Grito de aliento, Cobertura, Muro de aliados, Voz de
	# mando, Égida menor, Chispa vinculada, Guardia de carne, Velo umbrío) no aplicaban NADA. Se
	# gastaban la energía, salían en el log y no pasaba nada. La rama enemiga siempre lo hizo bien
	# (ver _enemy_use_ability: su llamada "self" va fuera del if/else de daño) — son funciones
	# espejo y se habian desincronizado justo aqui. Si se vuelve a tocar una, tocar la otra.
	estados_log += _tirar_efectos_habilidad(ab, obj, hubo_critico, "self")

	if ab.bloqueo_turnos > 0:
		_pantalla._player_defending = true   # golpe de escudo: te deja en guardia
	# Postura de contraataque del estoque (KAN-57): entras en guardia hasta tu proxima accion.
	# Bajas velocidad (data-driven), esquivas mas y devuelves los golpes que esquivas (riposte).
	if ab.postura_contraataque:
		_pantalla._player.en_guardia = true
		_pantalla._player.guardia_spd_mult = ab.guardia_spd_mult
		_pantalla._player.evasion_bonus = ab.evasion_bonus
		_pantalla._player.guardia_contra_mult = ab.contra_mult
	# Foco arcano (Canalización): concede cargas que amplifican tus proximos hechizos.
	if ab.foco_cargas > 0:
		_pantalla._player.foco_cargas += ab.foco_cargas
	# Provocacion (escudo): pasas a atraer los golpes N turnos (ver _elegir_objetivo_enemigo).
	# OJO: va al MISMO nivel que el Foco, no dentro. Estuvo anidada por error y, como la
	# Provocacion no da cargas de Foco, no se aplicaba NUNCA.
	if ab.provoca_turnos > 0:
		_pantalla._player.provocar_turnos = ab.provoca_turnos
	# COBERTURA (escudo grande, "Muro"): te plantas delante del aliado elegido. Va al MISMO nivel
	# que la Provocacion, no dentro de nada -- ver el aviso de ahi arriba, que a la Provocacion le
	# paso justo eso y no se aplicaba nunca.
	# La pareja se monta por LOS DOS LADOS y se rompe la anterior primero: solo se puede cubrir a
	# uno, y sin el _romper_cobertura de delante el aliado viejo se quedaba con un protegido_por
	# apuntando a alguien que ya cubre a otro.
	if ab.protege_turnos > 0:
		var a_cubrir: Combatant = _pantalla._hab_objetivo_aliado()
		if a_cubrir != null and a_cubrir != _pantalla._player:
			_pantalla.objetivos._romper_cobertura(_pantalla._player)
			_pantalla.objetivos._romper_cobertura(a_cubrir)   # y si a EL ya lo cubria otro, ese otro se queda libre
			_pantalla._player.protegiendo_a = a_cubrir
			a_cubrir.protegido_por = _pantalla._player
			_pantalla._player.proteger_turnos = ab.protege_turnos
			_pantalla._defendiendo[_pantalla._player] = true   # cubrir es tener el escudo alto: ver _begin_player_turn
	# IMBUICION DESDE EL ARMA (el veneno de la daga). Reutiliza la misma maquinaria que los Filos:
	# se gasta 1 carga por ATAQUE, aguanta entre combates y se ve en el mismo chip. OJO: aplicar_imbue
	# SUSTITUYE, asi que envenenar la daga te quita el Filo o el Manto que llevaras -- hay una sola
	# ranura de imbuicion, y es a proposito.
	if ab.es_imbuicion():
		_pantalla._player.aplicar_imbue(ab.imbue_elemento, ab.imbue_pct, ab.imbue_usos, false,
			ab.imbue_estado, ab.imbue_prob, Elementos.INTENSIDAD_IMBUIDO,
			ab.imbue_prob_doble, ab.imbue_por_destreza)
		estados_log.append("%s en el arma (%d ataques)" % [
			str(StatusEffects.def(ab.imbue_estado).get("nombre", "?")), ab.imbue_usos])
	# LIMPIAR DEBUFFS: a un aliado elegido (Purificar) o a todo el grupo (el area del baston).
	if ab.limpia_debuffs > 0:
		# Sin ternario a proposito: _aliados_vivos() devuelve Array[Combatant] y la otra rama un
		# Array pelado, y GDScript avisa de que los dos lados no son del mismo tipo.
		var a_limpiar: Array = []
		if ab.objetivo_aliado == AbilityData.Objetivo.GRUPO:
			a_limpiar.assign(_pantalla._aliados_vivos())
		else:
			a_limpiar.append(_pantalla._hab_objetivo_aliado())
		for al in a_limpiar:
			var quitados: Array = al.limpiar_debuffs(ab.limpia_debuffs)
			if not quitados.is_empty():
				estados_log.append("%s se quita %s" % [al.nombre, ", ".join(quitados)])
	# RECORTE DE COOLDOWNS: a las OTRAS habilidades, nunca a la suya (ver AbilityData).
	if ab.reduce_cooldowns > 0:
		var destrabadas: int = _pantalla._player.reducir_cooldowns(ab.reduce_cooldowns, ab)
		estados_log.append("cooldowns −%dt%s" % [ab.reduce_cooldowns,
			"" if destrabadas == 0 else " (%d lista%s)" % [destrabadas, "" if destrabadas == 1 else "s"]])

	# ---- Mensaje al jugador ----
	# Con daño van DOS lineas: el RASTRO (que hizo cada golpe) y el REPARTO (cuanto se llevo cada
	# uno y el total). Un "0 de daño (2 golpes)" no decia si habias fallado, esquivado o pegado a
	# un muerto. Mismo criterio que los hechizos (ver _log_hechizo): nunca una linea por golpe,
	# que el log solo tiene LOG_MAX.
	var msg: String
	if ab.dano_mult > 0.0:
		var titulo: String = ab.nombre if tocados.size() > 1 else "%s → %s" % [ab.nombre, _pantalla._etq(obj)]
		var sin_dar: String = "… no le has dado con ninguno de los %d golpe%s." % [
			rastro.size(), "" if rastro.size() == 1 else "s"]
		msg = _pantalla.magia._log_desglose(titulo, rastro, tocados, dano_por_obj, total, sin_dar,
			_pantalla.magia._desglose_imbue(total, total_imbue, mult_imbue))
	else:
		msg = "%s usa %s." % [_pantalla._player.nombre, ab.nombre]
	if mana_ganado > 0.0:
		msg += "  +%.1f MP." % mana_ganado
	if not estados_log.is_empty():
		msg += "  ✨%s." % ", ".join(estados_log)
	if ab.bloqueo_turnos > 0:
		msg += "  🛡️ En guardia."
	if ab.postura_contraataque:
		msg += "  🤺 En guardia (contraataque al esquivar)."
	if ab.foco_cargas > 0:
		msg += "  🔮 Foco arcano: %d cargas (+%d%% daño a tus próximos hechizos)." % [
			_pantalla._player.foco_cargas, roundi(Combatant.FOCO_BONUS * 100.0)]
	if ab.provoca_turnos > 0:
		msg += "  🎯 Provocas %d turnos: los enemigos irán más a por ti." % ab.provoca_turnos
	_pantalla._set_log(msg)
	# LAS QUE NO PEGAN TAMBIEN SE VEN. Una habilidad con dano_mult 0 no entra en el reparto de golpes,
	# o sea que NO PASA POR _fx_golpe EN SU VIDA: sin esto, el Filo emponzoñado se aplicaria en
	# silencio y sin dibujo. Es la gemela de la llamada que ya hacia la rama enemiga (ver _fx_adorno
	# y _enemy_use_ability): el mismo agujero, en el otro bando.
	#
	# VA AQUI ABAJO Y NO ARRIBA, y no da igual: el COLOR del adorno sale de lo que el personaje lleve
	# puesto en ese instante (ver _color_golpe), y la imbuicion se aplica en este mismo bloque de
	# efectos. Pintandolo antes, el Filo emponzoñado salia de acero -- el bote gris, el liquido gris y
	# la hoja sin cambiar de color-- porque todavia no se habia envenenado nada.
	_pantalla.enemigos._fx_adorno(_pantalla._player, ab, _pantalla._objetivo())
	# Y LO QUE TE ECHAS TU ENCIMA (el Voto de guardia: pegas Y te cubres). Va aparte del adorno
	# porque estas SI hacen daño, asi que su dibujo de golpe ya se ha pintado sobre el enemigo.
	_pantalla.enemigos._fx_sobre_mi(ab)
	_pantalla._update_hp()
	_pantalla._fin_de_eleccion()
	# A TODOS los alcanzados, no solo al objetivo principal (misma regla que la magia de area).
	# _tras_accion_jugador_varios es el UNICO camino que llama a _morir_enemigo, asi que rematando
	# solo a 'obj' un enemigo que cayera como objetivo SECUNDARIO (area) o REDIRIGIDO no se apagaba
	# nunca: se quedaba con el recuadro de vivo, los chips de sus estados congelados a la vista y su
	# marca en la barra de turnos, pero sin poder atacarlo. Como todas las habilidades que alcanzan
	# a secundarios llevan estado, parecia un bug "de los debuffs".
	_pantalla._tras_accion_jugador_varios(tocados if not tocados.is_empty() else [obj])


# Tira los efectos de una habilidad sobre 'objetivo' (cada uno con su prob y la resistencia a
# estados del rival). El objetivo va por PARAMETRO, y es el que capturo la accion al lanzarse:
# asi los estados caen sobre el mismo bicho que esta recibiendo los golpes.
# Devuelve los NOMBRES de los que prenden.
# Tira los efectos de una habilidad TUYA. Espejo de _enemy_tirar_efectos, con el que tiene que
# mantenerse a la par: durante mucho tiempo esta rama ignoraba en_objetivo y mandaba TODO al
# enemigo, asi que un auto-buff en un arma se lo quedaba el bicho.
#
#   filtro: "todos" | "objetivo" (solo lo que va al rival) | "self" (solo los buffs propios).
#           Un area llama con "objetivo" por cada enemigo tocado y con "self" UNA sola vez, para
#           que el buff propio no se aplique una vez por bicho.
#   escala_prob / escala_mag: < 1.0 en los SECUNDARIOS de un area. Salen de la FRACCION DE DAÑO que
#           ha encajado ese objetivo, no de un numero a mano: si encaja el 40% del golpe, tiene el
#           40% de la probabilidad. Asi al tocar area_secundario esto se ajusta solo.
func _tirar_efectos_habilidad(ab: AbilityData, objetivo: Combatant, fue_critico: bool = false,
		filtro: String = "todos", escala_prob: float = 1.0, escala_mag: float = 1.0) -> Array:
	var out: Array = []
	for a in ab.efectos:
		if a.estado < 0:
			continue
		if a.solo_crit and not fue_critico:
			continue   # efecto reservado al critico (p.ej. 2o sangrado de la Punalada)
		var al_enemigo: bool = a.en_objetivo
		if filtro == "objetivo" and not al_enemigo:
			continue
		if filtro == "self" and al_enemigo:
			continue
		# A QUIEN cae. Los buffs propios pueden ir a todo el grupo (grito del tanque) o a UN aliado
		# que has elegido tu (Égida menor, Chispa vinculada): eso lo sabe _hab_objetivo_aliado, que
		# devuelve al que lanza cuando la habilidad no pregunta por nadie. Antes ponia `_player` a
		# pelo, asi que el escudo que le echabas al tanque te lo quedabas tu.
		var destinos: Array = []
		if al_enemigo:
			destinos.append(objetivo)
		elif a.a_todo_el_grupo:
			for al in _pantalla._aliados_vivos():
				destinos.append(al)
		else:
			destinos.append(_pantalla._hab_objetivo_aliado())
		var nom: String = str(StatusEffects.def(a.estado).get("nombre", "?"))
		for d in destinos:
			if d == null or not d.is_alive() or d.es_inmune(a.estado):
				continue
			# Solo lo que le LANZAS a alguien se resiste; un buff tuyo siempre prende (igual que
			# en los hechizos, ver _aplicar_estado_hechizo).
			var p: float = a.prob
			if al_enemigo:
				# ATURDIR: la probabilidad de la habilidad es solo la BASE; encima suma el aturdir
				# del ARMA (que ya viene con Peso y rareza aplicados, ver Game._hand_from). Sin esto,
				# mejorar Peso no le hacia nada a Golpe sismico ni a Aplastamiento.
				var base: float = a.prob
				if a.estado == StatusEffects.Id.ATURDIDO:
					base += _pantalla._player.aturdir_base
				# Y de ahi a la puerta comun, como todo lo demas: la resistencia del bicho al control,
				# su afinidad y el estado Rayo entran ya dentro (ver Combatant.resist_estados).
				p = StatusEffects.prob_final(base * escala_prob, _pantalla._player, d, a.estado)
			if randf() >= p:
				continue
			var mag: float = StatusEffects.app_magnitude(a, _pantalla._player.atk(), _pantalla._player.motion_value) * escala_mag
			# N stacks por tirada, igual que la rama enemiga. Antes se aplicaba siempre 1 e
			# ignoraba a.stacks: la primera habilidad que lo use tiene que funcionar sin acordarse.
			for _s in maxi(1, a.stacks):
				d.apply_status(a.estado, a.turns, mag, 1, false, a.cap, a.mult)
			out.append(nom if al_enemigo else "%s (%s)" % [nom, d.nombre])
	return out
