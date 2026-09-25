# ============================================================
#  combat_enemigos.gd  (tema de la pantalla de combate: combat.enemigos)
#  EL TURNO DE LOS ENEMIGOS: a quien atacan, sus habilidades (cargas, invocaciones, golpes y estados),
#  los adornos de efecto y los CONTRAATAQUES de los tuyos (riposte, bloqueo, escolta). Lo demas, a _pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# Tope de golpes esquivados que cuentan para la Agilidad dentro de UNA habilidad enemiga multi-golpe.
# Sin tope, una habilidad de cinco golpes esquivada entera rendiria cinco veces lo que un ataque
# normal esquivado; con el, esquivar un chaparron sigue valiendo mas que esquivar un golpe suelto
# (es mas dificil) pero no se dispara.
const ESQUIVA_HAB_MAX := 2.0


# Empieza una accion enemiga: se abre el cupo de gasto DEFENSIVO de las imbuiciones. Cada accion
# puede costarle a los tuyos UNA carga como mucho, aunque les salve de un estado Y les recorte el
# daño elemental a la vez, y aunque traiga cinco golpes. Ver Combatant.gastar_imbue_defensiva.
# EN EL MAPA, el sorteo de a quien pega ha salido vacio con los tuyos en pie: es que no llega. Se
# dice, y por el registro, que es lo que le llega al espejo: asi el otro jugador ve lo mismo.
func _no_llega(e: Combatant, ab: AbilityData = null) -> void:
	if not _pantalla.tactico or _pantalla._aliados_vivos().is_empty():
		return
	if ab != null:
		_pantalla._set_log("%s suelta %s, pero no llega a nadie. 💨" % [_pantalla._etq(e), ab.nombre])
	else:
		_pantalla._set_log("%s no llega a nadie y se queda a la espera." % _pantalla._etq(e))


func _abrir_turno_enemigo() -> void:
	for c in _pantalla._aliados:
		c.imbue_def_gastada = false


# Turno de UN enemigo. 'e' es el que ACTUA (no "el enemigo" a secas): con varios en la
# pelea, cada uno gasta su barra, tiene sus cooldowns y carga lo suyo por separado.
func _enemy_turn(e: Combatant) -> void:
	if _pantalla._dps_on:
		_pantalla._turnos_enemigo += 1
	_abrir_turno_enemigo()
	e.tick_cooldowns()   # habilidades del enemigo (KAN-58): baja 1 turno los cooldowns
	# Estados alterados (KAN-58): tick al inicio del turno del enemigo.
	var ev: Dictionary = e.tick_statuses()
	_pantalla._log_tick(e, ev)
	_pantalla._dps_add("DoT (estados)", float(ev.get("damage", 0.0)))   # sangrado/veneno/quemadura que le pusiste
	_pantalla._update_hp()
	if not e.is_alive():
		_pantalla._set_log("%s cae por el daño de sus estados. ☠" % _pantalla._etq(e))
		_pantalla._morir_enemigo(e)   # el DoT lo remata: cae EL, no acaba el combate
		if _pantalla._vivos().is_empty():
			_pantalla._end(true)
		else:
			_pantalla._pausa_lectura()
		return
	if ev.stunned:
		# Aturdir a un enemigo que se estaba CARGANDO cancela su ataque (interrupcion).
		if e.charging != null:
			var interrumpida: String = e.charging.nombre
			e.charging = null
			e.charge_left = 0
			print("[habilidad enemigo] %s ATURDIDO: se le INTERRUMPE %s" % [e.nombre, interrumpida])
			_pantalla._set_log("%s está aturdido: se le interrumpe %s. 💫" % [_pantalla._etq(e), interrumpida])
		else:
			_pantalla._set_log("%s está aturdido y pierde el turno. 💫" % _pantalla._etq(e))
		_pantalla._pausa_lectura()   # ya se le resto la barra ATB en _process; pierde la accion
		return

	# ATAQUE DE CARGA en curso: consume un turno cargando; al llegar a 0, se dispara.
	if e.charging != null:
		e.charge_left -= 1
		if e.charge_left > 0:
			_pantalla._set_log("%s sigue cargando %s... ⚡ (prepárate)" % [_pantalla._etq(e), e.charging.nombre])
			_pantalla._pausa_lectura()
			return
		var cargada: AbilityData = e.charging
		e.charging = null
		_enemy_use_ability(e, cargada)
		return

	# INVOCACION (Rey Slime): tiene PRIORIDAD sobre todo lo demas. Si el Rey trae una habilidad de
	# invocacion lista y hay sitio para meter slimes, la lanza SIEMPRE (telegrafiada). Va antes del
	# roll normal para que "siempre que la tenga sin cd" se cumpla, y el gate evita malgastarla con
	# el sequito ya lleno.
	if not _pantalla._dps_on:
		var inv: AbilityData = _invocacion_lista(e)
		if inv != null:
			_enemy_begin_charge(e, inv)   # carga_turnos > 0 -> se anuncia; aturdirlo la interrumpe
			return

	# Decision: usar una HABILIDAD (si tiene alguna lista y sale la tirada) o atacar normal.
	# En modo muñeco (Saco/Pegador) NO usa habilidades: mantiene limpias las pruebas de DPS/armadura.
	var listas: Array = []
	# SILENCIADO: se queda sin habilidades, igual que tu te quedas sin el boton. Le queda pegar.
	if not _pantalla._dps_on and not e.silenciado():
		for ab in e.habilidades:
			if e.ability_ready(ab) and ab.invoca_cantidad <= 0:   # la invocacion ya se decidio arriba
				listas.append(ab)
	# A QUIEN va: uno de los tuyos que siga en pie (ver _elegir_objetivo_enemigo). Se decide AQUI,
	# en el momento de pegar, y no al empezar el turno: entre medias puede haber caido alguien.
	var obj: Combatant = _pantalla.objetivos._elegir_objetivo_enemigo()
	if obj == null:
		# No queda nadie de los tuyos a quien pegar -- o, en el mapa, nadie A SU ALCANCE: se ha
		# acercado todo lo que le deja su radio y no llega, asi que pierde el ataque (la misma regla
		# que tu). Sale con _pausa_lectura (no con un return pelado): el enemigo YA perdio su barra en
		# _process, asi que sin devolver el estado a ADVANCING la pelea se quedaba parada.
		_no_llega(e)
		_pantalla._pausa_lectura()
		return
	# ENRAIZADO: la otra mitad de lo que le pasa al jugador (ver _accion_disponible). A el le quitamos
	# el boton de atacar; al bicho hay que quitarle el ataque basico AQUI, o el estado seria mitad
	# mecanica y mitad decorado -- y sin dar ningun error, que es como se pierden estas cosas.
	# Si tiene tecnica lista la usa (para conjurar no hacen falta los pies) y si no, pierde el turno.
	var atado: bool = e.enraizado()
	if not listas.is_empty() and (atado or randf() < e.prob_habilidad):
		var elegida: AbilityData = listas[randi() % listas.size()]
		if elegida.carga_turnos > 0:
			_enemy_begin_charge(e, elegida)
		else:
			_enemy_use_ability(e, elegida, obj)
		return
	if atado:
		_pantalla._set_log("🌱 %s está enraizado y no llega a atacar." % e.nombre)
		_pantalla._pausa_lectura()
		return

	var pj_obj: PersonajeData = Game.pj_de_combatant(obj)   # a quien se le apunta la excelia
	# La postura de guardia del estoque reduce el daño como el Defender (rama defending). En el mapa, las
	# dos SOLO si el golpe viene de delante (CombatTactico.cubre_de_frente).
	var defendiendo: bool = (bool(_pantalla._defendiendo.get(obj, false)) or obj.en_guardia) \
		and _pantalla.turno_mapa.cubre_de_frente(obj, e)
	# COMO PEGA ESTE BICHO a secas. Este es EL OTRO CAMINO del golpe enemigo: sin habilidad de por
	# medio, asi que el estilo sale entero del Combatant (EnemyData.fx_basico). Hay que ponerlo en
	# las dos ramas de aqui abajo -la que falla y la que acierta- igual que hace la de habilidades.
	var estilo_bas: int = _pantalla.efectos._estilo_de_habilidad(null, e)
	var result := StatsMath.resolve_attack(e, obj, defendiendo)
	_pantalla._debug_ataque(e, obj, result, defendiendo)
	if result.evaded:
		# El "FALLA" se apunta aqui arriba y no en cada rama: por debajo esto se bifurca en
		# esquiva a secas y esquiva-con-contraataque, y el golpe fallado es el mismo en las dos.
		_pantalla.efectos._fx_golpe(e, obj, 0.0, false, true, e.elemento_ataque, estilo_bas)
		# Excelia: esquivar un golpe entrena Agilidad (en vez de correr en circulos). La entrena
		# EL QUE ESQUIVA, no el que llevas delante.
		Game.ganar("agilidad", _pantalla._reto(e, pj_obj), Game.GAIN_AGILIDAD_ESQUIVAR,
			Game.RETO_MAX_FISICO, pj_obj)
		Game.contar_esquiva(pj_obj)   # contador oculto de Reflejos
		# CONTRAATAQUE (estoque, KAN-57): en guardia, cada golpe esquivado lo devuelves.
		# Se lo devuelves A QUIEN TE HA ATACADO, no a tu objetivo seleccionado.
		if obj.en_guardia and _devuelve_en_guardia(obj, e):
			var msg_ev := _contraatacar(e, obj)
			_pantalla._update_hp()
			if not e.is_alive():
				_pantalla._morir_enemigo(e)
				_pantalla._set_log(msg_ev)
				if _pantalla._vivos().is_empty():
					_pantalla._end(true)
				else:
					_pantalla._pausa_lectura()
				return
			_pantalla._set_log(msg_ev)
			_pantalla._pausa_lectura()
			return
		_pantalla._set_log("%s esquiva el ataque de %s. 💨" % [obj.nombre, _pantalla._etq(e)])
		_pantalla._update_hp()
		_pantalla._pausa_lectura()
		return

	var dmg: float = result.damage * e.dummy_dmg_out_mult   # Saco = 0 (no pega)
	# El MISMO golpe sin defensa, armadura ni bloqueo (ver StatsMath 'mitig'). Se calcula AQUI y no mas
	# abajo porque lo miran dos cosas: el contador de bloqueo (justo debajo) y la excelia de Resistencia.
	var dmg_bruto: float = float(result.get("dmg_sin_mitigar", dmg))
	obj.take_damage(dmg)
	_pantalla.efectos._fx_golpe(e, obj, dmg, result.crit, false, e.elemento_ataque, estilo_bas,
		1.0, false, "", AbilityData.Gesto.AUTO, &"", 0, float(result.get("mult_elem", 1.0)))
	# El MANTO ha recortado el golpe por su elemento: se le cobra la carga (tope de una por accion).
	if obj.resiste_por_afinidad(e.elemento_ataque):
		obj.gastar_imbue_defensiva()
	Game.desgastar_armadura(pj_obj)   # DURABILIDAD: encajar un golpe gasta un poco SU armadura
	Game.contar_dano_recibido(dmg, pj_obj)   # daño encajado (informe; ya no gatea ningun desarrollo)
	# AUTORREGENERACION: solo cuenta lo que paras habiendo LEVANTADO LA GUARDIA. El bruto va aqui con
	# el dummy_dmg_out_mult puesto (que 'dmg' ya lleva): contra el Saco, que pega 0, si no se
	# multiplicara se estaria regalando el bloqueo del golpe entero por cada porrazo de mentira.
	if defendiendo:
		Game.contar_dano_bloqueado(dmg_bruto * e.dummy_dmg_out_mult, dmg, pj_obj)
	if _pantalla._dps_on:
		_pantalla._dmg_taken_total += dmg
		_pantalla._dmg_taken_hits += 1
	# Excelia: la Resistencia sube por la PELIGROSIDAD del enemigo (como el
	# ataque), modulada por el DAÑO recibido (golpe gordo entrena mas). Asi
	# tambien sube bien al principio, cuando el enemigo es un gran reto.
	# Se mide con el golpe SIN MITIGAR ('dmg_bruto', calculado arriba): lo que te enseña es la fuerza de
	# lo que paras, no el arañazo que queda despues de pararlo. Con el mitigado, el tanque vivia clavado
	# en el suelo 0.5 del clamp -mucha vida Y mucha mitigacion, doble castigo por hacer su trabajo- y
	# encajar golpes rendia la decima parte que echar el sedal.
	var dmg_mult: float = clampf(dmg_bruto / maxf(1.0, float(obj.max_hp) * 0.1), 0.5, 2.0)
	# El reparto por AGGRO va en el 'base', NO en el reto_val: el reto_val lo capa RETO_MAX_FISICO
	# dentro de ganar(), y con un enemigo duro el bono se lo comeria el techo sin dejar rastro.
	var aggro_mult: float = _pantalla.objetivos._mult_resistencia_aggro(obj)
	Game.ganar("resistencia", _pantalla._reto(e, pj_obj) * dmg_mult, Game.GAIN_RESISTENCIA_GOLPE * aggro_mult,
		Game.RETO_MAX_FISICO, pj_obj)
	# Excelia: si BLOQUEAS (Defender), entrenas Resistencia EXTRA segun cuanto
	# bloquees (escudo grande entrena mas). Formaliza KAN-81 y premia el escudo.
	if bool(_pantalla._defendiendo.get(obj, false)):
		Game.ganar("resistencia", _pantalla._reto(e, pj_obj) * obj.defend_block,
			Game.GAIN_RESISTENCIA_BLOQUEO * aggro_mult, Game.RETO_MAX_FISICO, pj_obj)
	var msg: String
	if result.crit:
		msg = "%s CLAVA un critico a %s: %.2f de daño! 💥" % [_pantalla._etq(e), obj.nombre, dmg]
	else:
		msg = "%s ataca a %s por %.2f de daño." % [_pantalla._etq(e), obj.nombre, dmg]
	msg += _pantalla.magia._elem_golpe_txt(result, e.elemento_ataque)
	if bool(_pantalla._defendiendo.get(obj, false)):
		msg += " (defendido 🛡️)"
	# Aturdir/retrasar del enemigo (si algun dia lleva arma contundente).
	if result.aturde:
		msg += _pantalla._aplicar_aturdir(obj, result.crit)
	# Estados "al golpear" del enemigo (pegajoso/veneno de slimes, KAN-58 Fase 3).
	for nom in e.roll_on_hit(obj):
		msg += "  Le inflige %s." % nom
	# RIPOSTE AL BLOQUEAR (escudo pequeño): el golpe ha conectado y lo has parado con la guardia
	# arriba, asi que puede volver. Va DESPUES del mensaje del golpe enemigo para que el log se lea
	# en orden (primero te pegan, luego respondes); el FX lo encola _contras_pendientes y sale tras
	# la accion del bicho. Esta es UNA de las dos ramas: la otra esta en _enemy_resolver_golpes, y
	# si solo se toca una, el escudo ripostea contra los ataques a secas y no contra las tecnicas.
	var contra_bloq: String = _riposte_bloqueo(e, obj, defendiendo)
	_pantalla._set_log(msg)
	# Como ENTRADA APARTE del log, no pegado con un \n al golpe del bicho: cada linea del log es una
	# entrada, y metiendo dos en una se cuentan como una sola para el tope y para el anti-repetido.
	if contra_bloq != "":
		_pantalla._set_log(contra_bloq)
	_pantalla._update_hp()
	e.advance_hand()  # (sin efecto ahora; los enemigos aun no llevan 2 armas)

	# El riposte puede haberlo MATADO en mitad de su propio turno: la misma rama que ya existe en
	# el contraataque por esquiva, unas lineas mas arriba.
	if not e.is_alive():
		_pantalla._morir_enemigo(e)
		if _pantalla._vivos().is_empty():
			_pantalla._end(true)
			return
	if not obj.is_alive():
		_pantalla.altas._caer_aliado(obj)
		if _pantalla.altas.derrota():
			_pantalla._end(false)
			return
	_pantalla._pausa_lectura()


# ============================================================
#  HABILIDADES DEL ENEMIGO (KAN-58)
# ------------------------------------------------------------

# Empieza a cargar un ataque telegrafiado: no pega este turno, lo anuncia. El cooldown
# arranca YA (para que no reintente cargar en cuanto dispare). Aturdirlo mientras carga
# lo cancela (ver _enemy_turn). Te da tus turnos para defender/curarte/reventarlo.
# Devuelve la habilidad de INVOCACION lista de 'e' (Rey Slime) si toca lanzarla, o null. "Toca" =
# la tiene fuera de cooldown Y hay sitio para meter slimes (sequito no lleno). El Rey la prioriza.
# EL DIBUJO DE LAS QUE NO PEGAN. Una habilidad con dano_mult 0 no entra en el reparto de golpes, o
# sea que NO PASA POR _fx_golpe EN SU VIDA: si pide un fx_estilo y nadie lo pinta aqui, sale sin
# efecto y sin dar ningun error. Le paso ya dos veces -- primero con el aura de la Ignicion y
# despues con el Bramido del Minotauro y el Alarido de la Aberracion --, asi que en vez de ir
# apuntando estilos uno a uno, la regla es general: SIN DAÑO + CON ESTILO = adorno.
#
# Va como 'solo_dibujo' (el ultimo true): sale el efecto y nada mas, ni numero ni temblor ni barra.
#
# DONDE se pinta depende del estilo. Los de CombatFX.SOBRE_SI_MISMO (un aura, una coraza, un muro)
# van en la tarjeta del propio bicho. El resto -un grito, una mirada- van sobre A QUIEN alcanzan, y
# por eso se recorre la misma lista de objetivos que usaria si pegara: asi un grito que coge a tres
# se funde en UNO solo (ver _ESTILOS_DE_GRUPO) igual que lo haria un area con daño.
#
# LA USAN LOS DOS BANDOS (el bicho desde _enemy_use_ability y el jugador desde _usar_habilidad), asi
# que 'e' es "el que la lanza" y no "el bicho". OJO con el area: los objetivos salen de
# _objetivos_area_aliados, o sea de la fila de los ALIADOS DEL JUGADOR. Para un bicho eso es a quien
# ataca y para el jugador es a quien BUFA (Grito de guerra, Muro de aliados), que es justo lo que se
# quiere en los dos casos. Una habilidad de jugador sin daño que apuntase a los ENEMIGOS en area se
# pintaria en el sitio equivocado; hoy no existe ninguna, pero cuando la haya hay que partir esto.
# LO QUE EL QUE ATACA SE ECHA ENCIMA (AbilityData.fx_sobre_mi): la postura del Voto de guardia y lo
# que venga. Se pinta sobre SU tarjeta, no sobre la del enemigo, y en su propia tanda para que salga
# DESPUES del golpe -- primero pegas, luego te cubres.
#
# Va como 'solo_dibujo': no es un impacto, no lleva numero ni temblor ni toca ninguna barra.
# EL ELEMENTO QUE LLEVA ENCIMA el que lanza, para los dibujos que NO son un golpe (una postura, un
# escudo adelantado, un adorno). Sin esto las dos rutas de adorno pasaban NINGUNO -- una a pelo y la
# otra por elemento_ataque, que en el jugador es siempre NINGUNO --, asi que el arma en alto y el
# escudo salian con el COLOR de la imbuicion pero sin que el elemento hiciera nada encima.
#
# Vale para los dos bandos: los bichos llevan imbue_usos a 0 y se quedan con su elemento_ataque de
# siempre.
func _elem_encima(e: Combatant) -> int:
	if e == null:
		return Elementos.Elemento.NINGUNO
	if e.imbue_usos > 0 and e.imbue_elemento != Elementos.Elemento.NINGUNO:
		return e.imbue_elemento
	return e.elemento_ataque


func _fx_sobre_mi(ab: AbilityData) -> void:
	if ab == null or ab.fx_sobre_mi < 0 or _pantalla._fx == null:
		return
	_pantalla.efectos._fx_tanda(_pantalla._fx.ultima_tanda() + 1)
	_pantalla.efectos._fx_golpe(_pantalla._player, _pantalla._player, 0.0, false, false, _elem_encima(_pantalla._player),
		ab.fx_sobre_mi, 1.3, true)


func _fx_adorno(e: Combatant, ab: AbilityData, obj: Combatant) -> void:
	if ab == null or ab.dano_mult > 0.0:
		return
	var estilo: int = _pantalla.efectos._estilo_de_habilidad(ab, e)
	if estilo == CombatFX.Estilo.MELEE:
		return   # sin dibujo propio: un empujon de tarjeta sin golpe no se ve, y mejor asi
	# Estas son las que MAS piden sonido: un bramido o un caparazon no hacen ni un punto de daño y
	# aun asi tienen que oirse. Por eso CombatFX dispara el sonido ANTES de descartar los adornos.
	var sfx: String = _pantalla.efectos._clave_sfx(ab)
	var el: int = _elem_encima(e)
	if CombatFX.SOBRE_SI_MISMO.has(estilo):
		_pantalla.efectos._fx_golpe(e, e, 0.0, false, false, el, estilo, 1.3, true, sfx)
		return
	# LAS DE APOYO (objetivo_aliado ALIADO/GRUPO -- Muro de aliados, Grito de aliento, Purificar...)
	# van sobre QUIEN LAS RECIBE, no sobre 'obj'. 'obj' es el enemigo que tengas seleccionado (el que
	# usaría un ataque normal), y una habilidad de apoyo no depende de eso para nada -- se puede
	# lanzar con cualquier enemigo marcado, o ninguno. Sin este gate caía en el 'else' de mas abajo
	# y el adorno (el muro, el grito) se dibujaba encima del ENEMIGO, que es justo el sitio contrario
	# al que dice la propia descripcion de la habilidad. Estas NO pasan por _objetivos_area_aliados
	# porque esa reparte SEGUN LA HUELLA de un area (adyacentes al principal); un apoyo de grupo no
	# tiene "principal" que golpear, va a TODOS por igual.
	if ab.objetivo_aliado == AbilityData.Objetivo.GRUPO:
		# EN EL MAPA, solo los tuyos que pillo su huella (combat_habilidades._aliados_mapa).
		var grupo_ad = _pantalla.habilidades._aliados_mapa
		for al in (grupo_ad if grupo_ad != null else _pantalla._aliados_vivos()):
			_pantalla.efectos._fx_golpe(e, al, 0.0, false, false, el, estilo, 1.0, true, sfx)
		return
	if ab.objetivo_aliado == AbilityData.Objetivo.ALIADO:
		_pantalla.efectos._fx_golpe(e, _pantalla._hab_objetivo_aliado(), 0.0, false, false, el, estilo, 1.0, true, sfx)
		return
	if obj == null:
		return
	if ab.es_area():
		for o in _pantalla.objetivos._objetivos_area_aliados(ab, obj):
			_pantalla.efectos._fx_golpe(e, o["c"], 0.0, false, false, el, estilo,
				float(o["escala"]), true, sfx)
	else:
		_pantalla.efectos._fx_golpe(e, obj, 0.0, false, false, el, estilo, 1.0, true, sfx)


func _invocacion_lista(e: Combatant) -> AbilityData:
	for ab in e.habilidades:
		if ab.invoca_cantidad > 0 and e.ability_ready(ab) and _hay_sitio_para_invocar(e):
			return ab
	return null


# ¿Cabe invocar mas slimes al lado de 'e'? False si el escudo ya esta al tope (MAX_ENEMIGOS-1 = 3
# slimes vivos aparte del Rey) o si no hay hueco (ni cadaver reutilizable ni sitio para uno nuevo).
func _hay_sitio_para_invocar(e: Combatant) -> bool:
	var escolta_viva: int = 0
	var hay_hueco: bool = _pantalla._enemies.size() < _pantalla.MAX_ENEMIGOS
	for c in _pantalla._enemies:
		if c == e:
			continue
		if not c.is_alive():
			hay_hueco = true   # cadaver: se puede reutilizar su slot
		elif c.es_slime:
			escolta_viva += 1
	return escolta_viva < _pantalla.MAX_ENEMIGOS - 1 and hay_hueco


func _enemy_begin_charge(e: Combatant, ab: AbilityData) -> void:
	e.charging = ab
	e.charge_left = ab.carga_turnos
	e.start_cooldown(ab)
	print("[habilidad enemigo] %s empieza a cargar %s (%d turno%s)" % [
		e.nombre, ab.nombre, ab.carga_turnos, "" if ab.carga_turnos == 1 else "s"])
	_pantalla._set_log("⚡ %s se prepara para %s. ¡Prepárate! (aturdirlo lo interrumpe)" % [_pantalla._etq(e), ab.nombre])
	_pantalla._update_hp()   # pinta YA el chip ⚡ en SU tarjeta (si no, no saldria hasta el proximo refresco)
	_pantalla._pausa_lectura()


# Ejecuta una habilidad del enemigo: multi-golpe con dano_mult + sus estados (StatusApplication).
# Espejo compacto de _usar_habilidad del jugador (sin energia/dual/excelia de ataque).
# 'victima' = el aliado que se la come. Viene por parametro (no se lee de un global) porque con
# varios de los tuyos en pie cada accion enemiga elige a quien va, y una habilidad CARGADA se
# resuelve turnos despues de anunciarse: para entonces su presa puede haber cambiado.
func _enemy_use_ability(e: Combatant, ab: AbilityData, victima: Combatant = null) -> void:
	var obj: Combatant = victima if victima != null and victima.is_alive() else _pantalla.objetivos._elegir_objetivo_enemigo()
	if obj == null:
		_no_llega(e, ab)
		_pantalla._pausa_lectura()   # mismo motivo que en _enemy_turn: su barra ya se gasto, hay que reanudar
		return
	e.start_cooldown(ab)   # instantaneas: cooldown al usar (las cargadas ya lo arrancaron)
	print("[habilidad enemigo] %s usa %s contra %s" % [e.nombre, ab.nombre, obj.nombre])
	_fx_adorno(e, ab, obj)
	var total: float = 0.0
	var golpes: int = 0
	var estados_log: Array = []
	# CONTRAATAQUE del estoque (postura "En guardia"): responde a las habilidades UNA vez (no por
	# golpe). Con varios objetivos, el primero en guardia que esquive es quien contesta.
	var contra_txt: String = ""
	# Aliados que han recibido ALGO (para procesar caidas al final, sean uno o varios).
	var tocados: Array[Combatant] = []
	# Quien encajo la habilidad EN GUARDIA: se dice en el log (si no, con multi-golpe parece que
	# defender no sirvio de nada, cuando en realidad ha tapado todos los golpes).
	var defendieron: Array[Combatant] = []
	# Desglose para el log (como en tus habilidades): rastro golpe a golpe y reparto por aliado.
	var rastro: Array = []
	var dano_por_obj: Dictionary = {}
	# Y el multiplicador ELEMENTAL con el que le entro a cada uno: un area de fuego sobre el grupo
	# puede pegar x1.5 a uno y x0.5 al que lleva el manto, y eso hay que poder contarlo por separado.
	var mult_por_obj: Dictionary = {}
	var robado_total: float = 0.0   # lo que se ha curado chupando (AbilityData.robo_vida)
	if ab.dano_mult > 0.0:
		golpes = ab.num_golpes(1)   # los enemigos usan una sola "mano"
		if ab.es_area():
			# AREA (SPLASH sobre tu grupo): el principal encaja los golpes al 100%; los adyacentes,
			# a area_secundario. Los estados llegan a los lados solo si area_efectos_secundarios.
			for o in _pantalla.objetivos._objetivos_area_aliados(ab, obj):
				var t: Combatant = o["c"]
				var esc: float = float(o["escala"])
				var es_princ: bool = t == obj
				var esc_prob: float = 1.0 if es_princ else ab.area_prob_secundario
				var sub := _enemy_resolver_golpes(e, ab, t, golpes, esc, contra_txt == "",
					es_princ or ab.area_efectos_secundarios, esc_prob)
				total += float(sub["total"]); estados_log += sub["estados"]
				rastro += sub["rastro"]; dano_por_obj[t] = float(dano_por_obj.get(t, 0.0)) + float(sub["total"])
				mult_por_obj[t] = float(sub["mult_elem"]); robado_total += float(sub["robado"])
				if not tocados.has(t): tocados.append(t)
				if bool(sub["defendio"]) and not defendieron.has(t): defendieron.append(t)
				if String(sub["contra"]) != "": contra_txt = String(sub["contra"])
				if not e.is_alive(): break
		elif ab.reparto_por_golpe:
			# REPARTO POR GOLPE: cada golpe elige un aliado vivo al azar (pueden repetir objetivo).
			# El PRIMER golpe es el principal y va con el peso ENTERO (el aggro y la provocacion
			# mandan igual que en un turno normal: ~80% al que provoca). Los golpes ADICIONALES son
			# metralla: van con el peso ATENUADO, asi que tienden al tanque pero solo un poco. Sin
			# esto, el tanque se comia la tanda entera (~5 de 6) por acumulacion de tiradas.
			# OJO con 'aplicar_efectos': aqui hay UNA llamada a _enemy_resolver_golpes POR GOLPE, asi
			# que su rama de "efectos NO por golpe" (la que debe tirarse una sola vez por habilidad)
			# se disparaba una vez por golpe. Con el Doble Embate del slime (2 golpes x stacks 2)
			# salian 4 stacks de Pegajoso de un solo ataque en vez de 2. Aqui solo se dejan pasar los
			# efectos POR GOLPE; los de la habilidad se tiran una vez, fuera del bucle.
			var principal: Combatant = null
			var conecto_algo: int = 0
			for i in golpes:
				var t: Combatant = _pantalla.objetivos._elegir_objetivo_enemigo(i > 0)
				if t == null: break
				if principal == null: principal = t
				var sub := _enemy_resolver_golpes(e, ab, t, 1, 1.0, contra_txt == "",
					ab.efectos_por_golpe, 1.0, i)
				total += float(sub["total"]); estados_log += sub["estados"]
				conecto_algo += int(sub["conecto"])
				rastro += sub["rastro"]; dano_por_obj[t] = float(dano_por_obj.get(t, 0.0)) + float(sub["total"])
				mult_por_obj[t] = float(sub["mult_elem"]); robado_total += float(sub["robado"])
				if not tocados.has(t): tocados.append(t)
				if bool(sub["defendio"]) and not defendieron.has(t): defendieron.append(t)
				if String(sub["contra"]) != "": contra_txt = String(sub["contra"])
				if not e.is_alive(): break
			# Efectos de la HABILIDAD (no por golpe): una sola tirada, sobre el objetivo PRINCIPAL (el
			# del primer golpe, el que eligio el aggro con peso entero). Mismas condiciones que dentro
			# de _enemy_resolver_golpes: hay que haber conectado algo y seguir vivos los dos.
			if not ab.efectos_por_golpe and conecto_algo > 0 and principal != null \
					and principal.is_alive() and e.is_alive():
				estados_log += _enemy_tirar_efectos(e, ab, principal, 1.0, "objetivo")
		else:
			# SINGLE (de siempre): todos los golpes al mismo objetivo.
			var sub := _enemy_resolver_golpes(e, ab, obj, golpes, 1.0, true, true)
			total = float(sub["total"]); estados_log = sub["estados"]; contra_txt = String(sub["contra"])
			rastro = sub["rastro"]; dano_por_obj[obj] = float(sub["total"])
			mult_por_obj[obj] = float(sub["mult_elem"]); robado_total += float(sub["robado"])
			tocados.append(obj)
			if bool(sub["defendio"]): defendieron.append(obj)
		print("        total: %.2f de daño en %d golpe%s (%d objetivo%s)" % [
			total, golpes, "" if golpes == 1 else "s", tocados.size(), "" if tocados.size() == 1 else "s"])
	else:
		# Habilidad de PURO ESTADO (sin daño): tira sus efectos a-objetivo. Si es de area (Bramido,
		# Alarido), el debuff cae sobre TODA la fila alcanzada; si no, solo sobre el objetivo.
		if ab.es_area():
			for o in _pantalla.objetivos._objetivos_area_aliados(ab, obj):
				var t: Combatant = o["c"]
				estados_log += _enemy_tirar_efectos(e, ab, t, 1.0, "objetivo")
				if not tocados.has(t): tocados.append(t)
		else:
			estados_log += _enemy_tirar_efectos(e, ab, obj, 1.0, "objetivo")
			tocados.append(obj)

	# BUFFS PROPIOS (en_objetivo=false: Furia del minotauro, Fortaleza...): UNA vez por uso, no por
	# objetivo ni por golpe. Van aparte para que un area no los aplique varias veces.
	estados_log += _enemy_tirar_efectos(e, ab, e, 1.0, "self")

	# INVOCACION (Rey Slime): saca hasta invoca_cantidad slimes al azar del pool. Para si se queda
	# sin hueco (sequito lleno / tope de 4). Va aparte del daño/estados: una habilidad podria pegar
	# Y invocar, aunque la del Rey es de pura invocacion (dano_mult 0).
	var invocados: int = 0
	if ab.invoca_cantidad > 0 and not ab.invoca_pool.is_empty():
		for _k in range(ab.invoca_cantidad):
			var pick: EnemyData = ab.invoca_pool[randi() % ab.invoca_pool.size()]
			var cria: Combatant = _pantalla.altas._invocar_slime(pick)
			if cria == null:
				break   # no cabe ninguno mas
			invocados += 1
			# EL BROTE SE VE SALIR DE EL. Una gota gorda se DESPRENDE de la tarjeta del Rey y cae en
			# el hueco donde nace el secuaz, con su mismo color. Sin esto los slimes aparecian de la
			# nada y no se leia que habian salido de su masa, que es toda la gracia de la habilidad.
			# Cada gota en SU tanda, para que las dos no salgan pegadas.
			_pantalla.efectos._fx_tanda(_k)
			_pantalla.efectos._fx_golpe(e, cria, 0.0, false, false, e.elemento_ataque,
				CombatFX.Estilo.ESCUPITAJO, 1.2, true)
		_pantalla._update_hp()   # refresca los bloques revividos/nuevos (nombre + barra)

	# Mensaje: con daño va el DESGLOSE de dos lineas (mismo helper que tus habilidades: rastro golpe
	# a golpe + reparto por aliado); de puro estado, la cabecera simple (no hay golpes que contar).
	var msg: String
	if ab.dano_mult > 0.0:
		var titulo: String = "%s usa %s" % [_pantalla._etq(e), ab.nombre]
		if tocados.size() <= 1:
			titulo += " → %s" % _pantalla._etq(obj)
		var sin_dar: String = "… no te ha dado con ninguno de los %d golpe%s." % [
			rastro.size(), "" if rastro.size() == 1 else "s"]
		msg = _pantalla.magia._log_desglose(titulo, rastro, tocados, dano_por_obj, total, sin_dar)
	else:
		msg = "%s usa %s" % [_pantalla._etq(e), ab.nombre]
		msg += " y alcanza a %d de los tuyos." % tocados.size() if tocados.size() > 1 \
			else " contra %s." % _pantalla._etq(obj)
	if not defendieron.is_empty():
		# La guardia tapa TODOS los golpes del turno; si no se dice, con una habilidad multi-golpe
		# parece que defender no ha servido de nada.
		var nombres_def: Array = []
		for c in defendieron:
			nombres_def.append(c.nombre)
		msg += "  🛡️ %s aguanta%s en guardia (menos daño)." % [
			", ".join(nombres_def), "" if defendieron.size() == 1 else "n"]
	msg += _pantalla.magia._elem_reparto_txt(e.elemento_ataque, mult_por_obj)
	# Que se CHUPA lo que te saca. Sin decirlo, un bicho que drena se lee como un bicho que
	# simplemente no baja de vida, y eso parece un fallo en vez de su mecanica.
	if robado_total > 0.0:
		msg += "  🩸 Se cura %.2f con lo que te saca." % robado_total
	if not estados_log.is_empty():
		# Neutro: las entradas ya dicen "(a sí mismo)" cuando el estado es un buff propio.
		msg += "  Aplica: %s." % ", ".join(estados_log)
	if invocados > 0:
		msg += "  ¡Brotan %d slime%s a su lado! 🟢" % [invocados, "" if invocados == 1 else "s"]
	if contra_txt != "":
		msg += "  " + contra_txt
	_pantalla._set_log(msg)
	_pantalla._update_hp()

	if not e.is_alive():
		# El contraataque de la postura lo ha matado en mitad de su propia habilidad: cae EL,
		# el combate solo acaba si era el ultimo que quedaba en pie.
		_pantalla._morir_enemigo(e)
		if _pantalla._vivos().is_empty():
			_pantalla._end(true)
		else:
			_pantalla._pausa_lectura()
		return
	# Caidas de TODOS los aliados tocados (el area puede tumbar a varios de golpe).
	var alguno_cayo: bool = false
	for t in tocados:
		if not t.is_alive():
			_pantalla.altas._caer_aliado(t)
			alguno_cayo = true
	if alguno_cayo and _pantalla.altas.derrota():
		_pantalla._end(false)
		return
	_pantalla._pausa_lectura()


# Resuelve 'n_golpes' de la habilidad 'ab' del enemigo 'e' sobre UN aliado 't', con 'escala' de daño
# (1.0 = pleno; area_secundario en los adyacentes). 'permitir_contra' deja que t (en guardia)
# devuelva UN golpe. 'aplicar_efectos' decide si t recibe los estados (el principal siempre; los
# adyacentes solo si la habilidad lo pide). Devuelve {total, conecto, estados, contra}.
# 'tanda_base' = por que golpe de la habilidad va esta llamada. Sirve SOLO para la animacion: los
# golpes con el mismo numero caen a la vez, y asi un area enemiga se ve como un barrido aunque
# aqui se siga resolviendo victima a victima (ver _fx_tanda). En el area vale 0 (cada llamada
# recorre sus golpes desde el principio); en reparto_por_golpe, donde el que llama trae un golpe
# suelto por vuelta, hay que pasarle el indice o los dos embates del slime caerian encima.
func _enemy_resolver_golpes(e: Combatant, ab: AbilityData, t: Combatant, n_golpes: int,
		escala: float, permitir_contra: bool, aplicar_efectos: bool, escala_prob: float = 1.0,
		tanda_base: int = 0) -> Dictionary:
	var pj_t: PersonajeData = Game.pj_de_combatant(t)
	var defendiendo: bool = (bool(_pantalla._defendiendo.get(t, false)) or t.en_guardia) \
		and _pantalla.turno_mapa.cubre_de_frente(t, e)
	var total: float = 0.0
	var total_bruto: float = 0.0   # el mismo daño SIN mitigar, para la excelia de Resistencia
	var conecto: int = 0
	var estados: Array = []
	var contra: String = ""
	var rastro: Array = []   # un token por golpe para el desglose del log (mismo formato que el jugador)
	var esquivados: int = 0  # para la excelia de Agilidad, que se paga UNA vez al final
	var robado: float = 0.0  # vida que se ha chupado con esta tanda (AbilityData.robo_vida)
	# EL ASPECTO lo pide la habilidad y, si no pide nada, el propio bicho (ver _estilo_de_habilidad).
	# Por aqui pasan LOS DOS caminos: con 'ab' cuando lanza tecnica y con 'ab' nulo cuando pega su
	# ataque basico, asi que pasarle el atacante es lo que hace que la rata muerda tambien sin
	# tecnica. Se saca UNA vez, fuera del bucle: es el mismo para todos sus golpes. Tambien se usa
	# en los que FALLAN, para que un escupitajo esquivado se vea salir y pasar de largo en vez de
	# convertirse en un empujon de tarjeta.
	var estilo_ab: int = _pantalla.efectos._estilo_de_habilidad(ab, e)
	# Y EL SONIDO igual: el suyo si lo tiene, y si no el generico de su estilo. Tambien fuera del
	# bucle, y tambien en los que fallan -- un escupitajo esquivado se oye salir.
	var sfx_ab: String = _pantalla.efectos._clave_sfx(ab)
	# QUE HACE SU CUERPO. Tambien fuera del bucle: el gesto es de la ACCION entera, no de cada golpe
	# (el Frenesi es una racha de seis mordiscos, pero la rata ataca desde su sitio UNA vez, no seis
	# veces cada una a su aire).
	var gesto_ab: int = _pantalla.efectos._gesto_de_habilidad(ab)
	var anim_ab: StringName = ab.fx_anim if ab != null else &""
	for i in n_golpes:
		_pantalla.efectos._fx_tanda(tanda_base + i)
		var result := StatsMath.resolve_attack(e, t, defendiendo)
		if result.evaded:
			print("        [%s] golpe %d: esquivado 💨" % [t.nombre, i + 1])
			Game.contar_esquiva(pj_t)   # contador oculto de Reflejos
			esquivados += 1
			rastro.append({"t": "falla", "c": t})
			_pantalla.efectos._fx_golpe(e, t, 0.0, false, true, e.elemento_ataque, estilo_ab, 1.0, false, sfx_ab, gesto_ab, anim_ab)
			if t.en_guardia and permitir_contra and contra == "" and _devuelve_en_guardia(t, e):
				contra = _contraatacar(e, t)
				if not e.is_alive():
					break
		else:
			var dmg: float = result.damage * ab.dano_mult * escala * e.dummy_dmg_out_mult
			# Lo MISMO sin defensa, armadura ni bloqueo, con los MISMOS factores que 'dmg' (incluido
			# el dummy_dmg_out_mult, o el Saco regalaria bloqueo a cada porrazo de mentira). Lo miran
			# dos cosas: el contador de bloqueo de aqui y la excelia de Resistencia de mas abajo.
			var dmg_bruto: float = float(result.get("dmg_sin_mitigar", result.damage)) \
				* ab.dano_mult * escala * e.dummy_dmg_out_mult
			t.take_damage(dmg)
			# ROBO DE VIDA del bicho (el Drenaje del chupasimas). Sobre el daño YA MITIGADO: contra
			# alguien con armadura, drenar le rinde poco, y esa es la gracia -- va a por el que va
			# ligero. Se acumula para decirlo UNA vez en el log y no una por golpe.
			if ab.robo_vida > 0.0:
				var cur: float = dmg * ab.robo_vida
				e.heal(cur)
				robado += cur
			_pantalla.efectos._fx_golpe(e, t, dmg, result.crit, false, e.elemento_ataque, estilo_ab, 1.0, false,
				sfx_ab, gesto_ab, anim_ab, 0, float(result.get("mult_elem", 1.0)))
			# Igual que en el golpe basico: si el manto ha recortado el daño, se cobra la carga.
			# El tope por accion hace que una habilidad de cinco golpes cueste una, no cinco.
			if t.resiste_por_afinidad(e.elemento_ataque):
				t.gastar_imbue_defensiva()
			Game.desgastar_armadura(pj_t)   # DURABILIDAD: cada golpe encajado gasta las piezas
			Game.contar_dano_recibido(dmg, pj_t)   # daño encajado (informe; ya no gatea ningun desarrollo)
			# AUTORREGENERACION: solo lo que paras con la guardia arriba, igual que en el golpe basico.
			if defendiendo:
				Game.contar_dano_bloqueado(dmg_bruto, dmg, pj_t)
			total += dmg
			# El bruto se acumula golpe a golpe: es con lo que se mide la Resistencia (abajo), igual
			# que en el golpe basico.
			total_bruto += dmg_bruto
			conecto += 1
			rastro.append({"t": "💥%.2f" % dmg if result.crit else "%.2f" % dmg, "c": t})
			var et := "[%s] golpe %d: %s %.2f" % [t.nombre, i + 1, ("CRITICO 💥" if result.crit else "acierta"), dmg]
			if ab.efectos_por_golpe and aplicar_efectos:
				var ap: Array = _enemy_tirar_efectos(e, ab, t, escala, "objetivo", escala_prob)
				estados += ap
				if not ap.is_empty():
					et += "  -> " + ", ".join(ap)
			print("        " + et)
			# RIPOSTE AL BLOQUEAR (escudo pequeño). La OTRA punta del de _enemy_turn. Va en el
			# 'else' del evaded a proposito: el de esquiva es de la POSTURA y ya esta arriba.
			# Comparte la MISMA cuota que aquel ('contra == ""'): uno por accion. Sin eso, una
			# habilidad de seis golpes contra una rodela al 35% devolveria dos estocadas por turno
			# y el escudo pequeño pasaria a ser el que mas daño hace del juego.
			if permitir_contra and contra == "":
				contra = _riposte_bloqueo(e, t, defendiendo)
				if not e.is_alive():
					break
		if not t.is_alive():
			break
	# Efectos NO por golpe: una tirada si conecto algo y siguen vivos ambos (un contraataque puede
	# haber matado al enemigo a mitad de su propia habilidad: un muerto no te envenena).
	if aplicar_efectos and not ab.efectos_por_golpe and conecto > 0 and t.is_alive() and e.is_alive():
		estados += _enemy_tirar_efectos(e, ab, t, escala, "objetivo", escala_prob)
	# Excelia: encajar el golpe entrena la Resistencia de QUIEN lo encaja, modulada por el daño.
	# Mismo trato que el ataque BASICO (ver _enemy_turn): que el enemigo use una habilidad en vez de
	# pegar de frente no puede cambiar lo que aprendes de comertelo. Antes esta rama solo pagaba la
	# parte del GOLPE, asi que defender contra las habilidades —justo cuando mas falta hace— no
	# entrenaba nada, y con lo aficionados que son los bichos a las habilidades eso era un agujero
	# gordo en la Resistencia del que hace de tanque.
	var aggro_mult: float = _pantalla.objetivos._mult_resistencia_aggro(t)
	if total > 0.0:
		var dmg_mult: float = clampf(total_bruto / maxf(1.0, float(t.max_hp) * 0.1), 0.5, 2.0)
		Game.ganar("resistencia", _pantalla._reto(e, pj_t) * dmg_mult,
			Game.GAIN_RESISTENCIA_GOLPE * aggro_mult, Game.RETO_MAX_FISICO, pj_t)
		if bool(_pantalla._defendiendo.get(t, false)):
			Game.ganar("resistencia", _pantalla._reto(e, pj_t) * t.defend_block,
				Game.GAIN_RESISTENCIA_BLOQUEO * aggro_mult, Game.RETO_MAX_FISICO, pj_t)
	# Y esquivar entrena Agilidad, igual que en el basico. Se paga UNA sola vez por habilidad y no
	# por golpe esquivado: una de cinco golpes no puede rendir cinco veces mas que un ataque normal.
	# Los golpes de mas suben el reto (aguantar un chaparron es mas dificil que un golpe suelto) pero
	# con tope, para que la habilidad larga sea mejor que la corta sin ser cinco veces mejor.
	if esquivados > 0:
		Game.ganar("agilidad", _pantalla._reto(e, pj_t) * minf(float(esquivados), ESQUIVA_HAB_MAX),
			Game.GAIN_AGILIDAD_ESQUIVAR, Game.RETO_MAX_FISICO, pj_t)
	# 'defendio' sube al log: la guardia dura TODO el turno y tapa todos los golpes, pero si no se
	# dice, con una habilidad multi-golpe parece que el escudo no ha hecho nada.
	# El multiplicador ELEMENTAL de este atacante contra ESTE objetivo. Es constante para el par
	# (e, t) -- sale del perfil del defensor, no del golpe -- asi que se saca una vez y sube al
	# que llama, que es quien monta el mensaje y sabe cuantos objetivos hubo.
	return {"total": total, "conecto": conecto, "estados": estados, "contra": contra,
		"defendio": defendiendo, "rastro": rastro, "robado": robado,
		"mult_elem": Elementos.mult_recibido(e.elemento_ataque, t)}


# Tira los estados (StatusApplication) de una habilidad del enemigo 'e'. Respeta 'en_objetivo':
#   true  = al JUGADOR (debuff/DoT; tu resistencia a estados baja la probabilidad).
#   false = A SI MISMO (buff, p.ej. Fortaleza del slime de fuego): siempre prende.
# "A si mismo" es el ENEMIGO QUE LANZA, de ahi que 'e' venga por parametro: con varios bichos,
# leer un campo global haria que un slime se buffease a otro slime.
# N stacks por tirada (a.stacks). Devuelve los nombres aplicados para el log.
# filtro: "todos" = self + a-objetivo; "objetivo" = solo los que van a QUIEN encaja (debuff/DoT, se
# aplican por objetivo del area); "self" = solo los buffs propios (en_objetivo=false), UNA vez por uso.
func _enemy_tirar_efectos(e: Combatant, ab: AbilityData, victima: Combatant, escala_mag: float = 1.0,
		filtro: String = "todos", escala_prob: float = 1.0) -> Array:
	var out: Array = []
	for a in ab.efectos:
		if a.estado < 0:
			continue
		var al_jugador: bool = a.en_objetivo
		if filtro == "objetivo" and not al_jugador:
			continue   # los buffs propios no se reparten por objetivo (se aplican una vez aparte)
		if filtro == "self" and al_jugador:
			continue   # aqui solo van los buffs a si mismo
		# A QUIEN cae. Los buffs propios pueden ir a TODO SU BANDO (a_todo_el_grupo), igual que en la
		# rama del jugador: hoy ningun bicho lo usa, pero las dos ramas tienen que contestar lo mismo
		# — desincronizarlas es exactamente lo que dejo ocho habilidades del jugador sin funcionar.
		var destinos_e: Array = []
		if al_jugador:
			destinos_e.append(victima)
		elif bool(a.a_todo_el_grupo):
			for otro in _pantalla._vivos():
				destinos_e.append(otro)
		else:
			destinos_e.append(e)
		var objetivo: Combatant = destinos_e[0]
		var nom: String = str(StatusEffects.def(a.estado).get("nombre", "?"))
		if objetivo.es_inmune(a.estado):   # incluye la inmunidad derivada de su AFINIDAD elemental
			# Si lo que te ha librado es el MANTO, se le cobra una carga (no te queman, no te mojan,
			# no te electrizan). Las otras vias de es_inmune no son suyas y no le gastan nada.
			if al_jugador and objetivo.inmune_por_afinidad(a.estado):
				objetivo.gastar_imbue_defensiva()
			continue   # apply_status ya lo avisaria, pero asi no ensucia el log de aplicados
		# Solo los estados que te LANZAN a ti se resisten; los buffs propios siempre prenden.
		# escala_prob < 1.0 en los SECUNDARIOS del area cuando la habilidad lo pide (el lento pilla
		# menos a los lados). No toca a los buffs propios (siempre prenden).
		var p: float = a.prob
		var p_pelada: float = p   # la misma probabilidad SIN el descuento del manto
		if al_jugador:
			# Por la puerta comun, igual que las vias del jugador: la eficacia DEL BICHO contra tu
			# resistencia. Su afinidad, tu stun_resist y el Rayo entran ya dentro.
			p = StatusEffects.prob_final(a.prob * escala_prob, e, victima, a.estado)
			p_pelada = StatusEffects.prob_final(a.prob * escala_prob, e, victima, a.estado, false)
		var tirada: float = randf()
		if tirada >= p:
			# ¿Te ha salvado el manto? Solo si esta tirada HABRIA entrado sin su descuento.
			if al_jugador and tirada < p_pelada:
				victima.gastar_imbue_defensiva()
			continue
		# escala_mag < 1.0 en los SECUNDARIOS del area: el fuego/veneno que salpica a los lados es
		# de la mitad (misma prob). 1.0 en el principal y en single/reparto.
		var mag: float = StatusEffects.app_magnitude(a, e.atk(), e.motion_value) * escala_mag
		# Aplica los stacks de uno en uno (los independientes/merge suben stack por llamada).
		for d_e in destinos_e:
			if d_e == null or not d_e.is_alive():
				continue
			for _s in maxi(1, a.stacks):
				d_e.apply_status(a.estado, a.turns, mag, 1, false, a.cap, a.mult)
		out.append(nom if al_jugador else "%s (a sí mismo)" % nom)
	return out


# LOS CONTRAATAQUES SE VEN AL FINAL, no en mitad del golpe del bicho. El riposte se RESUELVE en el
# instante de la esquiva (tiene que ser asi: el bicho puede morirse y dejar de pegar), pero su
# DIBUJO se guarda aqui y se suelta cuando la accion enemiga ha terminado.
#
# Sin esto se encolaba en la misma tanda que el golpe que acababa de esquivar y las dos cosas caian
# juntas: no se leia "me ataca, lo esquivo, le devuelvo", se veia un unico borron. Y no basta con
# darle un numero de tanda alto -- CombatFX ordena las tandas por el ORDEN EN QUE APARECEN en la
# cola, no por su numero (ver arrancar_cola) --, hay que encolarlo de verdad mas tarde.
var _contras_pendientes: Array = []


# Suelta los dibujos guardados, cada uno en su propia tanda, DETRAS de todo lo del bicho.
func _soltar_contraataques() -> void:
	if _contras_pendientes.is_empty() or _pantalla._fx == null:
		return
	for c in _contras_pendientes:
		# Una tanda nueva por contraataque: caen uno detras de otro, no todos a la vez.
		_pantalla.efectos._fx_tanda(_pantalla._fx.ultima_tanda() + 1)
		_pantalla.efectos._fx_golpe(c["a"], c["v"], float(c["dmg"]), bool(c["crit"]), bool(c["evadido"]),
			int(c["elem"]), int(c["estilo"]))
	_contras_pendientes.clear()


# RIPOSTE AL BLOQUEAR (escudo pequeño). El hermano del de esquivar: aquel es de la POSTURA del
# estoque, este es del ESCUDO que llevas. Devuelve "" si no salta.
#
# TRES CONDICIONES, y ninguna es el daño:
#   - 'defendiendo': solo con la guardia ARRIBA. Es lo que lo convierte en una decision (gastas el
#     turno en Defender, o lo traes de gorra con el Golpe de escudo) y no en un peaje pasivo.
#   - probabilidad: devolver CADA golpe que paras es roto. Por eso la rodela va al 35% y no al 100%.
#   - los dos vivos. Un riposte puede matar al bicho en mitad de su propio turno.
# OJO CON EL MUÑECO: el Saco pega con dummy_dmg_out_mult = 0, asi que su golpe hace 0 de daño pero
# SE RESUELVE igual. Si esto se gateara por 'dmg > 0' no saltaria nunca contra el, y probarlo ahi
# daria un falso negativo. Se gatea por defendiendo + acierto, que es lo que de verdad pasa.
#
# NO pasa por StatusEffects.prob_final: esa es la puerta de los ESTADOS. Meter aqui la resistencia
# del bicho significaria que un jefe "resiste" que le devuelvas el golpe, y eso no quiere decir nada.
func _riposte_bloqueo(atacante: Combatant, victima: Combatant, defendiendo: bool) -> String:
	if not defendiendo or atacante == null or victima == null:
		return ""
	if not atacante.is_alive() or not victima.is_alive():
		return ""
	var p: float = victima.escudo_contra_prob
	if p <= 0.0 or randf() >= p:
		return ""
	return _contraatacar(atacante, victima, victima.escudo_contra_mult, true)


# EN GUARDIA SOLO DEVUELVE LO QUE LLEGA: en el mapa, el que esquiva tiene que tener al atacante a su
# alcance. Lo que te tiran desde lejos lo esquivas y ya (24/09, lo pidio el). En la fila, siempre.
func _devuelve_en_guardia(quien: Combatant, atacante: Combatant) -> bool:
	if not _pantalla.tactico:
		return true
	return _pantalla.turno_mapa.llega(quien, atacante)


# CONTRAATAQUE: devuelves el golpe con el arma principal. Aplica el daño al enemigo y devuelve el
# texto para el log.
# 'atacante' es QUIEN TE HA GOLPEADO, y no tu objetivo seleccionado: el riposte responde al
# que se te ha echado encima. Si pegase a tu objetivo, con varios enemigos estarias hiriendo
# a uno que no te ha tocado, y a la vez dejando ileso al que si.
# 'quien' es EL QUE HA PARADO O ESQUIVADO, no necesariamente el que tiene el turno: el enemigo pega
# a cualquiera de los tuyos y el riposte es de quien encaja el golpe.
#
# HAY DOS RIPOSTES Y ESTA FUNCION SIRVE A LOS DOS. Son cosas distintas y conviven:
#   - AL ESQUIVAR: la postura del estoque (en_guardia, KAN-57). Es el original.
#   - AL BLOQUEAR: el escudo PEQUEÑO, por probabilidad (ver _riposte_bloqueo).
# Un mismo golpe nunca dispara los dos: result.evaded bifurca antes.
# 'mult' < 0 = usa el de la postura (comportamiento historico del estoque, cero regresion).
# 'al_bloquear' solo elige la frase del log: es la unica pista de cual de los dos ha saltado.
func _contraatacar(atacante: Combatant, quien: Combatant, mult: float = -1.0,
		al_bloquear: bool = false) -> String:
	quien.set_active_hand(0)   # se devuelve con la mano PRINCIPAL (el estoque, la espada...)
	# EL GESTO DEL ARMA que contraataca. Se lee DESPUES de fijar la mano principal, que es la que
	# devuelve el golpe. Sin esto, el riposte caia en el MELEE de siempre, o sea que no dibujaba
	# NADA: el bicho fallaba, se comia un contraataque y en pantalla no pasaba nada.
	var estilo: int = _pantalla.efectos._estilo_de_habilidad(null, quien)
	# EN LA POSTURA DE RODELA lo que devuelves es un ESCUDAZO (25/09): se ve como tal y pega con tu Defensa.
	var con_escudo: bool = quien.en_guardia and quien.guardia_contra_escudo
	if con_escudo:
		estilo = CombatFX.Estilo.ESCUDAZO
	var result := StatsMath.resolve_attack(quien, atacante, false, quien.atk_escudo() if con_escudo else -1.0)
	_pantalla._debug_ataque(quien, atacante, result, false)
	# COMO EMPIEZA LA FRASE. Se arma aqui y no en cada return porque las dos ramas (el riposte que
	# conecta y el que le esquivan) cuentan lo mismo: como paraste el golpe.
	var abrir: String = "%s para el golpe y responde" % quien.nombre if al_bloquear \
		else "%s esquiva y contraataca" % quien.nombre
	if result.evaded:
		_contras_pendientes.append({"a": quien, "v": atacante, "dmg": 0.0, "crit": false,
			"evadido": true, "elem": Elementos.Elemento.NINGUNO, "estilo": estilo})
		return "%s, pero %s lo esquiva. 💨" % [abrir, atacante.nombre]
	# El multiplicador manda desde fuera cuando el riposte es del ESCUDO; si no viene, el de la
	# postura. Nunca se suman los dos: un golpe lo devuelves de UNA manera.
	var dmg: float = result.damage * (mult if mult >= 0.0 else quien.guardia_contra_mult)
	atacante.take_damage(dmg)
	# Golpe INVERTIDO: aqui el que embiste es el tuyo y el que tiembla es el bicho, en mitad de la
	# accion del bicho. Sale solo porque se pasan los dos combatientes y la direccion la calcula
	# CombatFX de los centros reales de las dos tarjetas.
	_contras_pendientes.append({"a": quien, "v": atacante, "dmg": dmg, "crit": result.crit,
		"evadido": false, "estilo": estilo,
		"elem": quien.imbue_elemento if float(result.get("dmg_imbue", 0.0)) > 0.0 \
			else Elementos.Elemento.NINGUNO})
	_pantalla._apuntar_dano(atacante, dmg, quien)   # contador oculto de Cazador
	_pantalla._dps_add("Contraataque", dmg)
	_pantalla._ganar_mana_golpe()   # el riposte es un golpe de arma que conecta: repone maná como los demas
	# Excelia: el contraataque golpea, entrena Fuerza como un ataque normal.
	var pj_contra: PersonajeData = Game.pj_de_combatant(quien)
	Game.ganar("fuerza", _pantalla._reto(atacante, pj_contra) * quien.motion_value, Game.GAIN_FUERZA_ATAQUE,
		Game.RETO_MAX_FISICO, pj_contra)
	var extra := "un CRITICO 💥 " if result.crit else ""
	# EL ARMA SALE DEL COMBATIENTE, no escrita a mano. Decia "el estoque" siempre, y desde que el
	# escudo pequeño tambien ripostea eso mentia con cualquier otra arma. set_active_hand(0) de
	# arriba ya ha fijado la principal, asi que current_hand_name() es exactamente con lo que pega.
	var arma: String = "el escudo" if con_escudo else quien.current_hand_name()
	if arma == "":
		arma = "lo que tiene a mano"
	return "%s con %s: %s%.2f de daño! %s" % [abrir, arma, extra, dmg,
		"🛡️⚔" if al_bloquear else "🤺"]
