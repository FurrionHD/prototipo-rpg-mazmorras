# ============================================================
#  combat_magia.gd  (tema de la pantalla de combate: combat.magia)
#  MAGIA en combate: el submenu de hechizos, a quien van, el RECITADO frase a frase (con el examen y el
#  backfire), el disparo, la resolucion (area, dispersa, curas, imbuiciones, estados) y su registro.
#  Tambien los conjuros que llegan de fuera (el canto del mapa, el de quien se une). Lo demas, a _pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# Magia (KAN-56): nº de opciones del test de recitado (a/b/c/d). El maná se recupera
# PEGANDO (_ganar_mana_golpe) y GANANDO el combate (_end): ya no hay goteo por turno,
# salvo el que aporte el arma magica (mp_regen_turno).
const N_OPCIONES_TEST := 4
# Las FRASES del recitado van a DOS columnas (las acciones y los submenus van a tres): lo que llevan
# dentro es una frase entera, no el nombre corto de un hechizo.
const COLUMNAS_FRASES := 2


# ============================================================
#  MAGIA (KAN-56): submenu de hechizos + recitado por frases + disparo
# ------------------------------------------------------------
# Accion Magia: abre el submenu con los hechizos equipados y su coste de mana.
func _accion_magia() -> void:
	_pantalla._ocultar_cajas()
	# Reconstruimos el submenu cada vez (el mana cambia -> disponibilidad).
	for c in _pantalla._spell_box.get_children():
		c.queue_free()
	# Ordenados por coste de mana EFECTIVO descendente (los mas caros arriba).
	var spells_ord: Array = _pantalla._player.spells.duplicate()
	spells_ord.sort_custom(func(a, b): return _coste_efectivo(a) > _coste_efectivo(b))
	var grid := _pantalla._rejilla_submenu(_pantalla._spell_box)
	for spell in spells_ord:
		var b := TooltipButton.new()
		var coste: float = _coste_efectivo(spell)
		# A media anchura no cabe el numero de frases; va en el tooltip (descripcion_mecanica).
		b.text = "%s  (%.2f MP)" % [spell.nombre, coste]
		# Tooltip: datos DERIVADOS de los campos (resumen) + el sabor de la descripcion.
		# Igual que las habilidades (ver _accion_habilidad): la magia lo tenia todo escrito
		# en SpellData.resumen() y no lo enseñaba nadie.
		# Con el daño REAL entre parentesis: en combate es justo lo que decide si este hechizo
		# remata al bicho que tienes delante o no.
		b.tooltip_text = spell.descripcion_mecanica(spell.dano_mostrado() * Game.poder_magico())
		if spell.descripcion != "":
			b.tooltip_text += "\n\n" + spell.descripcion
		# El motivo del bloqueo va DELANTE del resumen, no en su lugar: si no te llega el
		# maná es justo cuando quieres mirar lo que hace el hechizo.
		if not _pantalla._player.has_mana(coste):
			b.disabled = true
			b.tooltip_text = "⛔ Maná insuficiente\n\n%s" % b.tooltip_text
		elif spell.imbue_tipo == 1 and _con_arma_vivos().is_empty():
			# Imbuir el ARMA sin llevar arma no tiene sentido: no hay filo que teñir. Las de
			# CUERPO si valen a manos vacias (te imbuyes tu, no el acero).
			# Se mira a TODO el grupo, no a Game.equipped_main (el arma del LIDER): el filo se lo
			# puedes echar a un compañero, asi que solo estorba si NADIE lleva arma.
			b.disabled = true
			b.tooltip_text = "⛔ Nadie del grupo lleva arma que imbuir\n\n%s" % b.tooltip_text
		# Los que caen sobre un ALIADO preguntan antes a quien; el resto van directos al enemigo.
		if _va_a_aliado(spell):
			b.pressed.connect(_elegir_objetivo_aliado.bind(spell))
		else:
			b.pressed.connect(_elegir_hechizo.bind(spell))
		_pantalla._celda_submenu(b)
		grid.add_child(b)
	_pantalla._cerrar_submenu(_pantalla._spell_box, spells_ord.size(), _pantalla._mostrar_acciones)
	_pantalla._ocultar_log()   # el submenu ocupa el sitio del historial


# ¿Este hechizo cae sobre uno de LOS TUYOS? Los Filos y Mantos (imbuicion) y los BUFF puros
# (Fortaleza). Los de ataque y los DEBUFF van al enemigo y no preguntan nada.
func _va_a_aliado(spell: SpellData) -> bool:
	# Las de CURACION tambien: se echan sobre uno de los tuyos, asi que pasan por el mismo selector
	# que los Filos. Las de grupo (alcance TODOS) NO preguntan -- van a todos y no hay nada que
	# elegir; ver la rama de _curar_con_hechizo.
	return spell != null and (spell.imbue_tipo > 0 or spell.tipo == SpellData.TipoEfecto.BUFF
		or (spell.tipo == SpellData.TipoEfecto.CURACION
			and spell.alcance != SpellData.Alcance.TODOS))


# Los tuyos en pie que llevan ARMA. Solo importa para los FILOS: un filo tiñe el acero, y a quien
# va con las manos vacias no hay nada que teñirle.
func _con_arma_vivos() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in _pantalla._aliados_vivos():
		var pj: PersonajeData = Game.pj_de_combatant(c)
		if pj != null and pj.equipped_main != null:
			out.append(c)
	return out


# Segundo paso del submenu de magia: A QUIEN se lo echas. Mismo patron que las pociones
# (_elegir_objetivo_objeto): con un solo candidato no se pregunta, va directo.
func _elegir_objetivo_aliado(spell: SpellData) -> void:
	var candidatos: Array[Combatant] = _con_arma_vivos() if spell.imbue_tipo == 1 else _pantalla._aliados_vivos()
	if candidatos.size() <= 1:
		_elegir_hechizo(spell, candidatos[0] if not candidatos.is_empty() else _pantalla._player)
		return
	for c in _pantalla._spell_box.get_children():
		c.queue_free()
	var grid := _pantalla._rejilla_submenu(_pantalla._spell_box)
	for al in candidatos:
		var b := TooltipButton.new()
		var actual: String = al.imbue_etiqueta()
		b.text = "%s%s" % [al.nombre, "   (%s)" % actual if actual != "" else ""]
		b.tooltip_text = "%s le echa %s a %s.%s" % [_pantalla._player.nombre, spell.nombre, al.nombre,
			"\n\nOJO: ya lleva una imbuición puesta y la nueva la sustituye." if actual != "" else ""]
		b.pressed.connect(_elegir_hechizo.bind(spell, al))
		_pantalla._celda_submenu(b)
		grid.add_child(b)
	_pantalla._cerrar_submenu(_pantalla._spell_box, candidatos.size(), _accion_magia)
	_pantalla._ocultar_log()


# Coste de maná EFECTIVO tras la mejora Eficiencia del equipo (KAN-95). FLOAT (sin
# redondeo hacia arriba: así CUALQUIER % de Eficiencia se nota). Mínimo 0.5.
func _coste_efectivo(spell: SpellData) -> float:
	return maxf(0.5, float(spell.coste_mana) * (1.0 - _pantalla._player.mana_reduccion)
		* _pantalla._player.status_mana_coste_mult())


# Empiezas a castear: se COMPRUEBA que te llega el mana, pero NO se cobra todavia, y recitas la
# primera frase en este MISMO turno.
#
# El cobro se hace al SOLTAR el hechizo (_disparar_hechizo) o al FALLAR una frase (_backfire).
# Antes se cobraba aqui, antes de la primera frase, y eso te quitaba el mana por la cara cuando el
# conjuro se caia por algo que no era culpa tuya: si mataban al ultimo enemigo mientras recitabas, o
# si te tumbaban a ti, el mana se habia ido igual. Fallar SI sigue costandolo: eso si es tuyo.
# 'aliado' = a quien va, para los que caen sobre los tuyos (null = al que lanza).
func _elegir_hechizo(spell: SpellData, aliado: Combatant = null) -> void:
	# ESPEJO: aqui solo se ELIGE. El conjuro entero (mana, frases y disparo) lo lleva el anfitrion;
	# lo que se enruta despues, turno a turno, son las frases (ver _mostrar_test). El destinatario
	# viaja como INDICE en _aliados, igual que ya hacia la pocion.
	if _pantalla._espejo and spell != null:
		_pantalla.espejo._responder_al_anfitrion({"tipo": "magia", "ruta": spell.resource_path,
			"aliado": _pantalla._aliados.find(aliado) if aliado != null else -1})
		return
	if not _pantalla._player.has_mana(_coste_efectivo(spell)):
		return
	_pantalla._cast_spell = spell
	_pantalla._cast_index = 0
	_pantalla._cast_aliado = aliado if aliado != null else _pantalla._player
	_mostrar_test(0)


# Muestra el test tipo examen para la frase idx del hechizo en curso.
func _mostrar_test(idx: int) -> void:
	var correcta: String = _pantalla._cast_spell.frases[idx]
	var opciones := SpellBook.opciones_test(correcta, _otras_frases_equipadas(), N_OPCIONES_TEST)
	# MULTI: si el que recita es el personaje de OTRO, el examen se le pone a EL. Las opciones se
	# sortean aqui (soy quien lleva la pelea) y el responde con el TEXTO que eligio; quien decide
	# si acerto sigo siendo yo, asi que la validacion no se va de esta maquina.
	var dueno: int = int(_pantalla._dueno_aliado.get(_pantalla._player, 0))
	# ¿SIGUE EN LA PELEA? Mismo guardia que en _pedir_accion_del_turno: pedirle la frase a quien ya
	# se fue es esperar para siempre. Aqui faltaba, y el que se iba A MEDIO RECITAR no entraba por
	# aquel camino (el conjuro en curso se atiende antes), asi que colgaba la pelea igual.
	if dueno != 0 and not Net.peleas.esta_en_mi_pelea(dueno):
		_pantalla.sacar_a(dueno)
		return
	if dueno != 0:
		_pantalla._ocultar_cajas()
		_pantalla._set_log("🔮 %s recita %s (%d/%d). Esperando..." % [
			_pantalla._player.nombre, _pantalla._cast_spell.nombre, idx + 1, _pantalla._cast_spell.longitud()])
		_pantalla.espejo._pedir_a_remoto(dueno, {"tipo": "frase", "idx": idx, "opciones": opciones,
			"nombre": _pantalla._cast_spell.nombre, "largo": _pantalla._cast_spell.longitud()})
		return
	_pintar_test(idx, opciones, _pantalla._cast_spell.nombre, _pantalla._cast_spell.longitud(), correcta)


# Pinta el examen de UNA frase. Vale igual para la pantalla que lleva la pelea y para un espejo al
# que se lo han pedido: la unica diferencia es que en el espejo no se sabe cual es la correcta (la
# valida el anfitrion), asi que se le pasa "".
func _pintar_test(idx: int, opciones: Array, nombre: String, largo: int, correcta: String) -> void:
	_pantalla._ocultar_cajas()
	for c in _pantalla._cast_box.get_children():
		c.queue_free()
	# En REJILLA, como los hechizos y las habilidades, y del mismo alto que ellos: cuadradas y
	# pegadas unas a otras. Una por fila dejaba cuatro tiras largas y bajas que no se parecian a
	# nada de lo demas. DOS columnas y no tres (COLUMNAS_ACCION): aqui dentro va una FRASE entera,
	# no el nombre corto de un hechizo.
	_pantalla._cast_box.add_theme_constant_override("separation", 12)
	# ...y a UNA si a dos no cabe la frase mas larga: una opcion recortada no se puede leer, y sin
	# poder leerla la eliges a ciegas y te comes el backfire (ver SpellBook.columnas_para_frases).
	var cols: int = SpellBook.columnas_para_frases(opciones, _pantalla._panel_acciones.size.x,
		_pantalla._cast_box.get_theme_default_font(), 17, COLUMNAS_FRASES)
	var grid := _pantalla._rejilla_submenu(_pantalla._cast_box, cols)
	var letras := ["a", "b", "c", "d", "e", "f"]
	for i in opciones.size():
		var b := Button.new()
		b.text = "%s)  %s" % [letras[i], opciones[i]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, _pantalla.ALTO_BOTON_ACCION)
		b.add_theme_font_size_override("font_size", 17)
		b.clip_text = true
		b.pressed.connect(_responder_frase.bind(String(opciones[i]), correcta))
		grid.add_child(b)
	var filas: int = ceili(opciones.size() / float(cols))
	var alto: float = filas * _pantalla.ALTO_BOTON_ACCION + (filas - 1) * 10.0
	# ECHARSE ATRAS: solo en la PRIMERA frase. En cuanto has recitado una ya no se puede (el conjuro
	# esta en marcha), asi que el boton ni se pinta. Y aqui no se pierde nada: el maná se cobra al
	# soltar el hechizo o al fallar, nunca al empezar (ver _elegir_hechizo).
	if idx == 0:
		var volver := Button.new()
		volver.text = "◄ Volver (aún no has recitado nada)"
		volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volver.custom_minimum_size = Vector2(0, _pantalla.ALTO_BOTON_VOLVER)
		volver.add_theme_font_size_override("font_size", 18)
		volver.pressed.connect(_cancelar_casteo)
		_pantalla._cast_box.add_child(volver)
		alto += 12.0 + _pantalla.ALTO_BOTON_VOLVER
	_pantalla._alto_panel(alto)
	_pantalla._cast_box.visible = true
	_pantalla._set_log("🔮 %s — recita la frase %d/%d:" % [nombre, idx + 1, largo])
	_pantalla._ocultar_log()   # las frases ocupan el sitio del historial


# ESPEJO: me toca recitar una frase de MI personaje. El examen lo ha sorteado el anfitrion.
func recitar_frase(idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0) -> void:
	if not _pantalla._espejo:
		return
	if seq != 0 and seq == _pantalla.espejo._seq_contestada:
		_pantalla._traza_add("me repiten la frase #%d, que YA conteste: la ignoro" % seq)
		return
	if seq != 0:
		_pantalla.espejo._seq_espejo = seq
	# Repeticion del anfitrion: si ya tengo el examen delante, no se re-sortea (ver turno_mio).
	if _pantalla._state == _pantalla.State.WAITING_PLAYER and _pantalla._cast_box != null and _pantalla._cast_box.visible:
		return
	_pantalla._traza_add("ME PIDEN LA FRASE %d (#%d) de %s" % [idx + 1, seq, nombre])
	_pantalla._state = _pantalla.State.WAITING_PLAYER
	_pintar_test(idx, opciones, nombre, largo, "")


# Frases de los OTROS hechizos equipados (para nutrir los distractores del test).
func _otras_frases_equipadas() -> Array:
	var pool: Array = []
	for spell in _pantalla._player.spells:
		if spell != _pantalla._cast_spell:
			for f in spell.frases:
				pool.append(f)
	return pool


# Responde una frase del test: acierto -> avanza; fallo -> backfire.
func _responder_frase(elegida: String, correcta: String) -> void:
	if _pantalla._state != _pantalla.State.WAITING_PLAYER:
		return
	# ESPEJO: no se si he acertado (la frase correcta no viaja: la comprueba el anfitrion).
	if _pantalla._espejo:
		_pantalla.espejo._responder_al_anfitrion({"tipo": "frase", "texto": elegida})
		return
	if elegida == correcta:
		# LA FRASE QUE SE HA DICHO, al registro: en el de todos, porque esto corre en quien lleva la pelea
		# (tambien cuando la eligio otro desde su espejo) y le llega a los demas con la instantanea.
		_pantalla._set_log("🗣️ %s recita: «%s» ✓" % [_pantalla._player.nombre, elegida])
		# La Magia NO se entrena por frase (solo al LANZAR, en _disparar_hechizo), para
		# que la ganancia sea predecible y no se cuente doble.
		_pantalla._cast_index += 1
		# oculto de Encantamiento rapido. La ficha se saca AQUI y no dentro: el que recita es quien
		# tiene el turno en este instante, y _player se presta y se devuelve en otras ramas.
		Game.contar_frase_recitada(_pantalla._pj_de_magia(_pantalla._player, "recitar " + _pantalla._cast_spell.nombre))
		if _pantalla._cast_index < _pantalla._cast_spell.longitud():
			_pantalla._set_log("✓ Frase correcta. Continua el proximo turno...")
		else:
			_pantalla._set_log("✓ ¡Encantamiento completo! El proximo turno lo lanzas.")
		_pantalla._player.regen_energy(_pantalla.ATTACK_ENERGY_REGEN)   # recitar es un turno basico: regenera energia (KAN-57)
		# Repinta el bloque: sin esto el chip del conjuro (ver _chips_de) se quedaba una frase
		# atrasado, porque los chips solo se rehacen desde aqui.
		_pantalla._update_hp()
		_pantalla._fin_de_eleccion()
		_pantalla._state = _pantalla.State.ADVANCING
	else:
		_backfire(elegida, correcta)


# ECHARSE ATRAS con el conjuro recien elegido, ANTES de recitar la primera frase. No cuesta maná (se
# cobra al soltarlo o al fallar, ver _elegir_hechizo) y NO gasta el turno: te devuelve al submenu de
# magia, por si el hechizo que has tocado no era el que querias.
#
# Con una frase ya recitada esto no se puede llamar: el boton solo se pinta con idx == 0
# (_pintar_test), y aun asi el anfitrion lo vuelve a comprobar antes de aplicarlo.
func _cancelar_casteo() -> void:
	if _pantalla._state != _pantalla.State.WAITING_PLAYER:
		return
	# ESPEJO: la decision es mia, pero el conjuro lo lleva el anfitrion. Se ocultan las cajas ANTES de
	# contestar: el menu de acciones que me devolvera viene por el mismo camino que una repeticion, y
	# los guardias de turno_mio / recitar_frase lo descartarian si aun tuviera los botones delante.
	if _pantalla._espejo:
		_pantalla._ocultar_cajas()
		_pantalla._set_log("Cancelando el conjuro...")
		_pantalla.espejo._responder_al_anfitrion({"tipo": "cancelar"})
		return
	if _pantalla._cast_spell == null or _pantalla._cast_index > 0:
		return
	_limpiar_casteo()
	_pantalla._update_hp()   # se va el chip 🔮 del bloque: los chips solo se rehacen desde aqui
	_accion_magia()


# Turno de DISPARO: un unico boton para lanzar el hechizo ya recitado.
func _mostrar_disparo() -> void:
	# MULTI: el conjuro es de otro -> el boton va en SU pantalla (y alli puede reapuntar antes de
	# soltarlo, que para eso tiene los mismos bloques clicables).
	var dueno: int = int(_pantalla._dueno_aliado.get(_pantalla._player, 0))
	if dueno != 0 and not Net.peleas.esta_en_mi_pelea(dueno):
		_pantalla.sacar_a(dueno)   # ver _mostrar_test: se fue con el conjuro ya recitado
		return
	if dueno != 0:
		_pantalla._ocultar_cajas()
		_pantalla._set_log("%s tiene el conjuro listo. Esperando..." % _pantalla._player.nombre)
		_pantalla.espejo._pedir_a_remoto(dueno, {"tipo": "disparo", "nombre": _pantalla._cast_spell.nombre})
		return
	_pintar_disparo(_pantalla._cast_spell.nombre)


func _pintar_disparo(nombre: String) -> void:
	_pantalla._ocultar_cajas()
	for c in _pantalla._cast_box.get_children():
		c.queue_free()
	var b := Button.new()
	b.text = "🔥 ¡Lanzar %s!" % nombre
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, _pantalla.ALTO_BOTON_ACCION)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(_disparar_hechizo)
	_pantalla._cast_box.add_child(b)
	_pantalla._alto_panel(_pantalla.ALTO_BOTON_ACCION)
	_pantalla._cast_box.visible = true
	_pantalla._set_log("El conjuro está listo. ¡Lánzalo!")
	_pantalla._ocultar_log()   # el boton de disparo ocupa el sitio del historial


# ESPEJO: mi conjuro esta listo, el boton de lanzarlo va aqui.
func lanzar_conjuro(nombre: String, seq: int = 0) -> void:
	if not _pantalla._espejo:
		return
	if seq != 0 and seq == _pantalla.espejo._seq_contestada:
		_pantalla._traza_add("me repiten el disparo #%d, que YA conteste: lo ignoro" % seq)
		return
	if seq != 0:
		_pantalla.espejo._seq_espejo = seq
	if _pantalla._state == _pantalla.State.WAITING_PLAYER and _pantalla._cast_box != null and _pantalla._cast_box.visible:
		return   # repeticion del anfitrion: ya tengo el boton delante
	_pantalla._traza_add("ME PIDEN EL DISPARO (#%d) de %s" % [seq, nombre])
	_pantalla._state = _pantalla.State.WAITING_PLAYER
	_pintar_disparo(nombre)


func _disparar_hechizo() -> void:
	if _pantalla._state != _pantalla.State.WAITING_PLAYER:
		return
	# ESPEJO: el objetivo viaja como indice; lo resuelve el anfitrion con el conjuro que ya tiene
	# recitado en la ficha del doble.
	if _pantalla._espejo:
		_pantalla.espejo._responder_al_anfitrion({"tipo": "disparar", "obj": _pantalla._target_idx})
		return
	var spell := _pantalla._cast_spell
	# ¿ESTE YA ESTABA PAGADO? Lo esta el conjuro que alguien recito en el MAPA y se trajo al unirse a
	# esta pelea: casteo_mapa cobra el maná antes del impacto (ver Game.casteo_para_viajar). Cobrarlo
	# otra vez aqui seria pagarlo dos veces, y si no le llegara, encima le tiraria el conjuro por la
	# rama de "se le deshace".
	var ya_pagado: bool = bool((_pantalla._casteos.get(_pantalla._player, {}) as Dictionary).get("pagado", false))
	# AQUI se paga el hechizo (ver _elegir_hechizo): al soltarlo, no al empezar a recitarlo. Se
	# vuelve a comprobar porque entre la eleccion y este momento han pasado turnos y el mana puede
	# haber bajado (otro conjuro, un drenaje futuro). Si no llega, el conjuro se disipa sin daño y
	# sin cobrar: no se puede lanzar lo que no se puede pagar.
	var coste: float = _coste_efectivo(spell)
	if not ya_pagado:
		if not _pantalla._player.has_mana(coste):
			_pantalla._set_log("%s se queda sin maná y el conjuro se le deshace. 💨" % _pantalla._player.nombre)
			_limpiar_casteo()
			_pantalla._update_hp()
			_pantalla._fin_de_eleccion()
			_pantalla._tras_accion_jugador_varios([])
			return
		_pantalla._player.spend_mana(coste)
	# Objetivo PRINCIPAL, capturado una vez, como en el resto de acciones (ver _usar_habilidad).
	# El area y los rebotes salen de el; y el sigue siendo el que cuenta para la Excelia y el DPS.
	var obj: Combatant = _pantalla._objetivo()
	var tocados: Array = _resolver_hechizo(spell, obj)
	_pantalla._player.regen_energy(_pantalla.ATTACK_ENERGY_REGEN)   # lanzar es un turno basico: regenera energia (KAN-57)
	_limpiar_casteo()
	_pantalla._update_hp()
	_pantalla._fin_de_eleccion()
	# Un hechizo de area puede tumbar a varios de golpe: hay que rematarlos a TODOS. El
	# principal va en la lista aunque el hechizo no sea de area (es el primero del area).
	_pantalla._tras_accion_jugador_varios(tocados if not tocados.is_empty() else [obj])


# TODO lo que HACE un hechizo ya soltado: daño (area, dispersion, rebotes), estados, imbuicion,
# log y excelia. Devuelve los enemigos TOCADOS, para rematarlos de una vez.
#
# Esta aparte porque hay DOS sitios que sueltan un hechizo: el turno de disparo de toda la vida
# (_disparar_hechizo) y el conjuro con el que ABRES la pelea desde el mapa (hechizo_de_entrada).
# Lo que va fuera —cobrar el maná, gastar el turno, la energia— es de cada uno; esto es lo comun.
#
# OJO: da por hecho que _player ES QUIEN LANZA. Todo lo de dentro (resolve_spell, el contador de
# Cazador, el log, la excelia) tira de _player, y por eso quien llame desde fuera de un turno tiene
# que dejarlo puesto (lo hace hechizo_de_entrada).
func _resolver_hechizo(spell: SpellData, obj: Combatant) -> Array:
	# Todos los enemigos tocados (area + rebotes): hay que rematarlos AL FINAL, de una vez.
	var tocados: Array = []
	# DAÑO solo para hechizos de ATAQUE (los de BUFF/DEBUFF no pegan, solo aplican estado).
	var dano: float = 0.0
	# EL DIBUJO UNICO, antes de resolver nada: es UNA cosa que cae sobre todos, no una por bicho.
	# Se ancla al enemigo del CENTRO de los vivos y se le da un peso alto, que es lo que decide su
	# tamaño (ver CapaHechizos: e["r"] sale del peso). Va como 'solo_dibujo': no es un golpe, es el
	# decorado -- los golpes de verdad van luego, uno por victima, sin pintar.
	if spell.fx_unico and _pantalla._fx != null:
		# DONDE SE ANCLA: si el hechizo cae sobre TODOS, en el enemigo del centro de la fila, que es
		# lo mas parecido a "en medio de todos". Si va a uno solo, encima de ESE -- anclarlo al centro
		# de la fila pondria la voragine sobre un bicho al que no le esta pasando nada.
		var centro: Combatant = obj
		if spell.alcance == SpellData.Alcance.TODOS:
			var vivos_c: Array[Combatant] = _pantalla._vivos()
			if not vivos_c.is_empty():
				centro = vivos_c[vivos_c.size() / 2]
		if centro != null:
			_pantalla.efectos._fx_golpe(_pantalla._player, centro, 0.0, false, false, int(spell.elemento),
				spell.fx_estilo if spell.fx_estilo >= 0 else CombatFX.Estilo.ARCANO,
				3.0, true)
	if spell.tipo == SpellData.TipoEfecto.ATAQUE:
		# Foco arcano (Canalización): gasta 1 carga y amplifica el daño del hechizo. Solo
		# los OFENSIVOS gastan carga; el largo la gasta AL DISPARAR (respeta el canto). Se
		# consume UNA vez y multiplica TODOS los golpes (los del area y los de los rebotes).
		var foco: float = _pantalla._player.consumir_foco()
		# 1) AREA: el principal y a quien salpique, cada uno con su multiplicador.
		#    DISPERSA (Tormenta, Andanada): los golpes no van al objetivo fijo, sino repartidos
		#    a vivos al azar; cada bola aplica ahi el alcance del hechizo. Ver _resolver_dispersa.
		var res_area: Array = []
		if spell.dispersa:
			res_area = _resolver_dispersa(spell, foco)
			for r in res_area:
				tocados.append(r.c)
		else:
			# DE DONDE SALE cada golpe del area. Si el hechizo reparte DESIGUAL (Brasa, Descarga:
			# mucho al principal y menos a los de al lado), lo que pasa de verdad es que revienta
			# en el principal y de ahi alcanza a sus vecinos -- asi que el efecto de los vecinos
			# sale DEL PRINCIPAL, no de tu mano. Si reparte IGUAL a todos (Rocío, Torrente), si
			# es que has barrido a todo el mundo, y entonces cada ola sale de ti.
			var reparte_igual: bool = spell.alcance == SpellData.Alcance.TODOS
			for t in _pantalla.objetivos._objetivos_area(spell, obj):
				var de: Combatant = null if (reparte_igual or t.c == obj) else obj
				res_area.append(_resolver_golpes_hechizo(spell, t.c, foco, float(t.escala),
					true, de))
				tocados.append(t.c)
		# 2) REBOTES: DESPUES del area, cada uno a un vivo al azar. _vivos() se recalcula en
		# CADA rebote, asi que la cadena nunca cae sobre un cadaver (ni sobre el que acaba de
		# tumbar el rebote anterior).
		var res_reb: Array = []
		# LOS GOLPES QUE SOBRAN (Vorágine, Venablo, Pulso arcano): si el objetivo cae antes de
		# llevarse todos los suyos, el resto salta a otros enemigos en vez de perderse.
		if spell.sobrantes_saltan() and not res_area.is_empty():
			for r in _saltar_sobrantes(spell, res_area[0], foco):
				res_reb.append(r)
				tocados.append(r.c)
		# De donde SALE cada arco. El primero de tu mano, y a partir de ahi cada salto desde la
		# victima anterior: es puro dibujo (la mecanica sigue eligiendo al azar, y puede repetir
		# objetivo), pero es lo que hace que cinco rebotes se lean como UNA cadena y no como cinco
		# lanzamientos sueltos.
		var anterior: Combatant = null
		# La cadena arranca DESPUES del ultimo golpe del area: un rebote es una cosa que pasa
		# detras, no a la vez (ver _fx_tanda).
		var tanda_reb: int = spell.golpes()
		for i in spell.rebotes_n():
			var vivos: Array[Combatant] = _pantalla._vivos()
			if vivos.is_empty():
				break   # no queda nadie a quien saltar: la cadena se apaga
			var victima: Combatant = vivos.pick_random()
			res_reb.append(_resolver_golpes_hechizo(spell, victima, foco, spell.dano_rebote,
				spell.rebote_estados, anterior, true, tanda_reb))
			tanda_reb += spell.golpes()
			tocados.append(victima)
			# Se apunta aunque este rebote la mate: los muertos se rematan al final de la accion
			# (_tras_accion_jugador_varios), asi que su tarjeta sigue ahi para el arco siguiente.
			anterior = victima
		dano = _log_hechizo(spell, res_area, res_reb, foco)
		_pantalla._dps_add("Hechizo: %s" % spell.nombre, dano)   # una entrada por lanzamiento, agregada
	else:
		_pantalla._set_log("✨ %s lanza %s." % [_pantalla._player.nombre, spell.nombre])
		# Los estados de un hechizo sin daño (buff/debuff) se aplican aqui: no hay golpes que
		# los lleven. Los de ATAQUE ya los ha tirado cada golpe con SU elemento.
		_aplicar_estado_hechizo(spell)
	# CURACION: no pega, cura. Va DESPUES del bloque de daño y no dentro, porque un hechizo de
	# curacion nunca entra por ahi (su tipo no es ATAQUE).
	if spell.tipo == SpellData.TipoEfecto.CURACION:
		_curar_con_hechizo(spell)
	# IMBUICION (KAN-58): el hechizo no pega, tiñe tus GOLPES DE ARMA con su elemento.
	if spell.imbue_tipo > 0:
		_aplicar_imbuicion(spell)
	# Excelia (formula dedicada de Magia): entrena al LANZAR, escalado por el mana
	# gastado (hechizos caros = mas potentes = entrenan mas) x reto del enemigo.
	var mana_factor: float = float(spell.coste_mana) / Game.MAGIA_COSTE_REF
	# Reto por-stat (contra TU magia, no tu poder total): asi un cuerpo fuerte con magia baja SI
	# entrena la magia contra bichos de su piso, en vez de quedarse clavado a 0 (ver Game.reto_stat).
	var pj_lanza: PersonajeData = _pantalla._pj_de_magia(_pantalla._player, "lanzar " + spell.nombre)   # entrena EL QUE LANZA
	Game.ganar("magia", Game.reto_stat(_pantalla._poder_enemigo(obj), "magia", obj.level, pj_lanza),
		Game.GAIN_MAGIA_CAST * mana_factor, Game.RETO_MAX_FISICO, pj_lanza)
	Game.contar_hechizo(pj_lanza)   # contador oculto de Erudito
	print("[magia] %s lanza %s | dano:%.2f (Magia %d) | def. magica de %s: %.2f" % [
		_pantalla._player.nombre, spell.nombre, dano, _pantalla._player.abilities.magia, obj.nombre,
		StatsMath.magic_value(obj.abilities, obj.level, obj.base_magic)])
	return tocados


# EL CANTO QUE TE INTERRUMPIERON. Estabas recitando en el mapa y esta misma pelea te ha caido
# encima: el conjuro NO se pierde, se sigue aqui por la frase que llevabas.
#
# No hace falta ni una linea de turnos nueva: los conjuros a medias ya viven en _casteos (es de
# donde tira el espejo para restaurar el canto de otro, ver aplicar_roster), y en cuanto esta ahi
# puesto, _player_turn le saca a ese aliado el examen de SU frase en vez de las acciones normales.
#
# El maná sigue sin cobrarse hasta soltarlo, asi que la cuenta cuadra sola: te interrumpen, no pagas.
func retomar_canto(spell: SpellData, idx_frase: int, idx_lanzador: int) -> void:
	if spell == null or _pantalla._espejo:
		return
	if idx_lanzador < 0 or idx_lanzador >= _pantalla._aliados.size():
		return
	var quien: Combatant = _pantalla._aliados[idx_lanzador]
	var frase: int = clampi(idx_frase, 0, maxi(0, spell.longitud() - 1))
	_pantalla._casteos[quien] = {"spell": spell, "idx": frase}
	_pantalla._set_log("🔮 %s sigue recitando %s (frase %d/%d)." % [
		quien.nombre, spell.nombre, frase + 1, spell.longitud()])
	_pantalla._update_hp()   # repinta el chip del conjuro en su bloque


# A QUIEN iba la magia de apoyo con la que entra alguien (ver Game.apuntar_hechizo_de_entrada): el
# personaje 'nombre' del jugador 'peer'. Se busca por DUEÑO + nombre de la ficha, que es lo unico que
# significa lo mismo en las dos maquinas. null = a si mismo, o a todos si es de grupo (ahi da igual).
func _aliado_de_apoyo(apoyo) -> Combatant:
	if not (apoyo is Dictionary) or (apoyo as Dictionary).is_empty() or bool(apoyo.get("grupo", false)):
		return null
	var peer: int = int(apoyo.get("peer", 0))
	# En _dueno_aliado los mios no estan (dueño 0): si el destino soy yo, busco entre los de dueño 0.
	var dueno: int = 0 if peer == Net.multiplayer.get_unique_id() else peer
	var nombre: String = String(apoyo.get("nombre", ""))
	for c in _pantalla._aliados:
		if int(_pantalla._dueno_aliado.get(c, 0)) != dueno:
			continue
		var pj: PersonajeData = Game.pj_de_combatant(c)
		if pj != null and pj.nombre == nombre:
			return c
	return null


# EL CONJURO QUE TRAE EL QUE SE UNE A MI PELEA. Hermana de retomar_canto, pero para un aliado que
# entra a mitad desde OTRA maquina: su nota de casteo no puede soltarse en su pantalla (alli solo hay
# un espejo), asi que viaja con la ficha y se siembra aqui, sobre su doble.
#
# A partir de ahi no hace falta nada mas: el flujo de turnos de siempre ve _casteos puesto y le saca
# el examen de su frase o el disparo, y como su dueño es remoto se lo pide a EL (ver _mostrar_test /
# _mostrar_disparo). Sin esto, el que se metia a ayudar con un conjuro cantado lo perdia.
#
# 'frase' == longitud() significa YA TERMINADO (es lo que mira _begin_player_turn para ir al
# disparo). Por eso el clamp llega hasta longitud() INCLUSIVE, al reves que en retomar_canto.
func aplicar_casteo_entrante(idx_aliado: int, d: Dictionary) -> void:
	if _pantalla._espejo or idx_aliado < 0 or idx_aliado >= _pantalla._aliados.size():
		return
	var sp: SpellData = load(String(d.get("ruta", ""))) as SpellData
	if sp == null:
		return
	var quien: Combatant = _pantalla._aliados[idx_aliado]
	var frase: int = clampi(int(d.get("frase", 0)), 0, sp.longitud())
	# 'pagado' = el maná se gasto YA, fuera, al recitarlo en el mapa (casteo_mapa lo cobra antes del
	# impacto). Sin esta marca, _disparar_hechizo se lo volveria a cobrar aqui.
	_pantalla._casteos[quien] = {"spell": sp, "idx": frase, "aliado": _aliado_de_apoyo(d.get("apoyo", {})),
		"pagado": bool(d.get("pagado", false))}
	if frase >= sp.longitud():
		_pantalla._set_log("✨ %s entra con %s ya recitado." % [quien.nombre, sp.nombre])
	else:
		_pantalla._set_log("🔮 %s entra recitando %s (frase %d/%d)." % [
			quien.nombre, sp.nombre, frase + 1, sp.longitud()])
	_pantalla._update_hp()   # pinta ya el chip 🔮 de su bloque


# EL CONJURO CON EL QUE ABRES LA PELEA. Lo has recitado en el mapa (casteo_mapa.gd), ha impactado, y
# la pelea se ha abierto por el camino de siempre: aqui se cobra el hechizo, contra el bicho al que
# le diste y ANTES del primer turno. No gasta turno ni energia — el turno no ha empezado.
#
# 'idx_enemigo' es el indice del bicho DENTRO de la pelea (el nodo del mapa no significa nada aqui) y
# 'idx_lanzador' el del que lo canto dentro del grupo. Lo llama Game._soltar_hechizo_de_entrada por
# los DOS caminos de entrada: el que abre la pelea y el que se une a una ya abierta.
func hechizo_de_entrada(spell: SpellData, idx_enemigo: int, idx_lanzador: int) -> void:
	if spell == null or _pantalla._espejo:
		return
	if idx_enemigo < 0 or idx_enemigo >= _pantalla._enemies.size():
		return
	if idx_lanzador < 0 or idx_lanzador >= _pantalla._aliados.size():
		return
	var obj: Combatant = _pantalla._enemies[idx_enemigo]
	if not obj.is_alive():
		return
	_pantalla._target_idx = idx_enemigo   # al que le diste es el objetivo principal, tambien para el turno 1
	# _resolver_hechizo va por _player para TODO (daño, log, excelia, contadores). Fuera de un turno,
	# _player es quien la pantalla tenga puesto, que no tiene por que ser el que canto: se le presta
	# el sitio al lanzador y se devuelve. Es eso o pasarle el lanzador a media docena de funciones.
	var previo: Combatant = _pantalla._player
	_pantalla._player = _pantalla._aliados[idx_lanzador]
	_pantalla._set_log("✨ %s abre la pelea con %s." % [_pantalla._player.nombre, spell.nombre])
	var tocados: Array = _resolver_hechizo(spell, obj)
	_pantalla._player = previo
	_pantalla._update_hp()
	# Si el conjuro se los ha llevado a todos, esto cierra la pelea con victoria (y su loot y su
	# excelia): matar de entrada es un desenlace legitimo, no un caso raro que haya que evitar.
	_pantalla._tras_accion_jugador_varios(tocados if not tocados.is_empty() else [obj])


# CURAR CON UN HECHIZO. A quien elegiste (_cast_aliado) o a TODO el grupo si su alcance es TODOS.
#
# LA CURA SALE POR Combatant.heal Y POR NINGUN OTRO SITIO. Ahi vive status_heal_recv_mult —lo que
# hace que una Herida profunda te cure menos— asi que escribir 'current_hp += x' aqui se saltaria
# ese estado en silencio y solo para la magia.
#
# ES INSTANTANEA. Se parece a la pocion en la FORMULA (un % de la vida maxima mas una parte fija)
# pero NO en como llega: la pocion gotea por turnos con el estado Regeneracion, y esto entra entero
# en el momento en que se lanza. Es lo que justifica que cueste maná y un turno de recitado.
#
# Las dos partes son a proposito: el % hace que la magia siga valiendo cuando las vidas son enormes,
# y la parte magica (dano_base por el poder del que lanza, o sea su Magia y el magic_amp del baston)
# hace que un mago con buen baston cure mas que uno pelado. Solo con el %, subir la Magia no haria
# nada; solo con la parte magica, la cura se quedaria en un rasguño a los pocos tiers.
func _curar_con_hechizo(spell: SpellData) -> void:
	var destinos: Array[Combatant] = []
	if spell.alcance == SpellData.Alcance.TODOS:
		destinos = _pantalla._aliados_vivos()
	elif _pantalla._cast_aliado != null:
		destinos = [_pantalla._cast_aliado] as Array[Combatant]
	else:
		destinos = [_pantalla._player] as Array[Combatant]

	var partes: PackedStringArray = []
	for c in destinos:
		if c == null or not c.is_alive():
			continue
		var antes: float = c.current_hp
		var cura: float = spell.cura_pct * c.max_hp + StatsMath.resolve_heal(_pantalla._player, spell)
		c.heal(cura)
		# LO QUE HA SUBIDO DE VERDAD, no lo que se pidio: con la vida casi llena la mitad se pierde,
		# y cantar el numero pedido seria mentir en la unica linea que el jugador lee.
		var real: float = c.current_hp - antes
		_pantalla.efectos._fx_golpe(_pantalla._player, c, 0.0, false, false, int(spell.elemento),
			spell.fx_estilo if spell.fx_estilo >= 0 else CombatFX.Estilo.CURACION_LUZ, 1.5, true)
		partes.append("%s +%.0f" % [c.nombre, real])
	_pantalla._set_log("✨ %s lanza %s.  %s" % [_pantalla._player.nombre, spell.nombre, "  ·  ".join(partes)])


# IMBUICION (KAN-58): tiñe tus golpes de arma con el elemento del hechizo.
#   ARMA   -> solo el bonus de daño elemental.
#   CUERPO -> ademas te da la AFINIDAD: resistes/eres debil a lo que diga la tabla, y te
#             vuelves INMUNE a los estados de ese elemento (imbuido en agua no te queman).
func _aplicar_imbuicion(spell: SpellData) -> void:
	var cuerpo: bool = spell.imbue_tipo == 2
	# EL ELEMENTO SE PREGUNTA UNA VEZ y se usa el resto de la funcion: los que van al azar sacan uno
	# distinto en cada llamada, asi que releer spell.elemento mas abajo pondria en el log un elemento
	# y en el cuerpo otro. Todo lo que sigue mira 'elem_id', nunca spell.elemento.
	var elem_id: int = spell.elemento_imbuido()
	# Al DESTINATARIO elegido (ver _elegir_objetivo_aliado), que puede no ser el que lanza.
	var quien: Combatant = _pantalla._cast_aliado
	quien.aplicar_imbue(elem_id, spell.imbue_pct, spell.imbue_usos, cuerpo,
		spell.imbue_estado, spell.imbue_prob, spell.imbue_intensidad,
		0.0, false, spell.imbue_spd_mult)
	var elem: String = Elementos.nombre(elem_id)
	var usos_txt: String = "%d carga%s" % [spell.imbue_usos, "" if spell.imbue_usos == 1 else "s"]
	print("[imbuicion] %s imbuye %s de %s a %s: +%d%% de daño %s durante %s" % [
		_pantalla._player.nombre, ("el CUERPO" if cuerpo else "el ARMA"), elem, quien.nombre,
		roundi(spell.imbue_pct * 100.0), elem, usos_txt])
	var de_quien: String = "tu" if quien == _pantalla._player else ("el %s de" % ("cuerpo" if cuerpo else "arma"))
	var msg: String = ("✨ Imbuyes tu %s de %s: +%d%% de daño de %s (%s)." % [
		("cuerpo" if cuerpo else "arma"), elem, roundi(spell.imbue_pct * 100.0), elem, usos_txt]
		) if quien == _pantalla._player else ("✨ Imbuyes %s %s de %s: +%d%% de daño de %s (%s)." % [
		de_quien, quien.nombre, elem, roundi(spell.imbue_pct * 100.0), elem, usos_txt])
	if cuerpo:
		# Lo que ganas y lo que pierdes, DERIVADO del estado REAL del jugador (ya lleva la
		# afinidad puesta con su FRANJA de intensidad). Nada hardcodeado: si tocas la tabla o
		# la intensidad, este texto se actualiza solo y dice el % de verdad.
		var resiste: Array = []
		var debil: Array = []
		for e in Elementos.PERFIL_DEFECTO.get(elem_id, {}):
			var m: float = Elementos.mult_recibido(e, quien)
			# En positivo y sin restas mentales: "20% de resistencia" / "+20% de daño".
			if m < 0.99:
				resiste.append("%s (%d%%)" % [Elementos.nombre(e), roundi((1.0 - m) * 100.0)])
			elif m > 1.01:
				debil.append("%s (+%d%%)" % [Elementos.nombre(e), roundi((m - 1.0) * 100.0)])
		if not resiste.is_empty():
			msg += "  🛡 Resistes: %s." % ", ".join(resiste)
		var inm: Array = []
		for id in Elementos.inmunidades_de(elem_id):
			inm.append(str(StatusEffects.def(id).get("nombre", "?")))
		if not inm.is_empty():
			msg += "  Inmune a: %s." % ", ".join(inm)
		if not debil.is_empty():
			msg += "  ⚠ Débil a: %s." % ", ".join(debil)
		print("[imbuicion] afinidad %s (intensidad %.2f) -> resiste %s | inmune %s | debil a %s" % [
			elem, spell.imbue_intensidad, resiste, inm, debil])
	# La velocidad va DESPUES de la afinidad: es lo ultimo que gana, y asi la linea se lee en el
	# mismo orden en que se aplica.
	if spell.imbue_spd_mult > 1.0:
		msg += "  🌀 Y te mueves un %d%% más rápido." % roundi((spell.imbue_spd_mult - 1.0) * 100.0)
	_pantalla._set_log(msg)


# Resuelve TODOS los golpes de un hechizo de ATAQUE contra UN objetivo. NO escribe en el log:
# devuelve lo ocurrido y ya lo cuenta _log_hechizo, que es quien ve el hechizo entero (con
# area y rebotes, una linea por golpe no cabria ni de lejos en el log).
# Cada golpe elige SU elemento (aleatorio si el hechizo trae reparto), pega, y tira SUS
# estados. El orden es el que hace bonito el multi-elemento: los estados de un golpe se
# aplican DESPUES de su daño, asi que un golpe nunca se amplifica a si mismo... pero la
# lluvia que moja SI amplifica (x1.5) los rayos que caigan DETRAS.
#   escala       -> multiplicador de daño de ESTE objetivo (1.5 al principal de Brasa, 0.75 al
#                   salpicon...). Modula 'frac', y como resolve_spell es LINEAL en el ataque,
#                   escalar aqui es exactamente lo mismo que escalar el dano_base solo para el.
#   tira_estados -> false en los rebotes (ver SpellData.rebote_estados).
#   desde        -> DE DONDE SALE el efecto, si no sale de ti. Dos usos:
#                   * rebotes: el arco sale de la victima anterior (cadena);
#                   * salpicon de un hechizo que reparte desigual (Brasa, Descarga): sale del
#                     OBJETIVO PRINCIPAL, no de tu mano. Es la diferencia entre "he lanzado tres
#                     bolas" y "ha reventado ahi y ha alcanzado a los de al lado", que es lo que
#                     de verdad pasa. Ver _resolver_hechizo.
#   rebote       -> solo para el ASPECTO: los rebotes se pintan como arcos.
#   tanda_base   -> tambien solo aspecto: desde que golpe cuenta esta llamada, para que el golpe i
#                   caiga a la vez sobre todos los del area (ver _fx_tanda). El area pasa 0 (las
#                   llamadas son hermanas, una por objetivo); los REBOTES pasan un numero que
#                   crece, porque una cadena tiene que verse justamente como un salto tras otro.
# Devuelve {c, dano, mult, golpes, trail, estados}.
func _resolver_golpes_hechizo(spell: SpellData, objetivo: Combatant, foco: float,
		escala: float = 1.0, tira_estados: bool = true, desde: Combatant = null,
		rebote: bool = false, tanda_base: int = 0, desde_golpe: int = 0) -> Dictionary:
	var n: int = spell.golpes()
	var frac: float = escala / float(n)
	var peso: float = _pantalla.efectos._peso_hechizo(spell, escala)
	var lanzador: Combatant = desde if desde != null else _pantalla._player
	var multi: bool = n > 1
	var total: float = 0.0
	var trail: Array = []
	# Estados ya contados en el log, FRESCO por objetivo: si se compartiera entre los enemigos
	# del area, solo se anunciaria el estado del primero y los demas entrarian en silencio.
	var anunciados: Dictionary = {}
	var aplicados: Array = []   # estados que ENTRAN, para que el log los pliegue en una linea
	var ultimo_mult: float = 1.0
	var hubo_crit: bool = false
	# 'desde_golpe' > 0 = esta llamada recoge los golpes que SOBRARON de otra (ver _saltar_sobrantes):
	# siguen numerandose donde se quedaron, asi que su elemento y su frac son los que les tocaban.
	for i in range(desde_golpe, n):
		if not objetivo.is_alive():
			break   # ya ha caido: los que quedan los recoge _saltar_sobrantes (o se pierden)
		_pantalla.efectos._fx_tanda(tanda_base + i)
		var elem: int = spell.elemento_de_golpe(i, n)
		var res: Dictionary = StatsMath.resolve_spell(_pantalla._player, objetivo, spell, elem, frac)
		var dmg: float = float(res.damage) * foco
		var mult: float = float(res.get("mult_elem", 1.0))
		ultimo_mult = mult
		if bool(res.get("crit", false)):
			hubo_crit = true
		objetivo.take_damage(dmg)
		# Cada golpe del hechizo lleva SU elemento: en un multi-elemento los numeros salen de
		# colores distintos y con la forma de su elemento, que es justo lo que cuenta el hechizo.
		# SALPICON = este golpe no va al objetivo principal, sino a un vecino al que ha alcanzado lo
		# que ha reventado en el principal. Se reconoce por 'desde' (viene del principal, no de tu
		# mano) sin ser rebote, que es la otra cosa que trae 'desde'. Se pinta distinto: ver
		# _estilo_salpicon.
		var es_salpicon: bool = desde != null and not rebote
		_pantalla.efectos._fx_golpe(lanzador, objetivo, dmg, bool(res.get("crit", false)), false, elem,
			_pantalla.efectos._estilo_hechizo(spell, elem, rebote, es_salpicon), peso, false, "",
			AbilityData.Gesto.AUTO, &"", 0, float(res.get("mult_elem", 1.0)))
		_pantalla._apuntar_dano(objetivo, dmg, _pantalla._player)   # contador oculto de Cazador
		total += dmg
		# CRITICO MAGICO: mismo 💥 que en el rastro del golpe fisico, para que se lea igual.
		trail.append("%s%s%.1f%s" % [Elementos.icono(elem),
			"💥" if bool(res.get("crit", false)) else "", dmg, _mult_sufijo(mult)])
		print("[magia] %s golpe %d/%d %s sobre %s: %.2f (x%.2f)%s" % [
			spell.nombre, i + 1, n, Elementos.nombre(elem), objetivo.nombre, dmg, mult,
			"  CRITICO 💥" if bool(res.get("crit", false)) else ""])
		# Este golpe GASTA lo que lo amplificaba (el rayo evapora el Mojado): el x1.5 se cobra
		# una vez y hay que volver a mojar. Va DESPUES del daño (este golpe si lo cobra).
		_gastar_amplificadores(objetivo, elem)
		# Estados de ESTE golpe (solo los que pidan su elemento). Van DESPUES de su daño.
		if tira_estados:
			# En multi-objetivo el log lo escribe _log_hechizo de una sentada: aqui callamos.
			_aplicar_estado_hechizo(spell, objetivo, elem, not multi, anunciados,
				spell.es_multiobjetivo(), aplicados)
	return {
		"c": objetivo, "dano": total, "mult": ultimo_mult, "crit": hubo_crit,
		"golpes": trail.size(), "trail": trail, "estados": aplicados,
	}


# LOS GOLPES QUE SOBRAN de un hechizo de un solo objetivo. 'primero' es lo que devolvio el golpe al
# objetivo principal; si se llevo menos golpes de los que tiene el hechizo es que cayo antes, y los que
# faltan saltan a un vivo al azar -- y si ese tambien cae, al siguiente. Cada uno sigue siendo el golpe
# que era (su elemento, su frac, sus estados): solo cambia a quien le cae.
#
# Se pintan como un ARCO que sale del que acaba de caer: es lo que hace que se lea como "lo que le
# sobraba se ha ido a otro" y no como un segundo lanzamiento.
func _saltar_sobrantes(spell: SpellData, primero: Dictionary, foco: float) -> Array:
	var out: Array = []
	var n: int = spell.golpes()
	var hechos: int = int(primero.get("golpes", n))
	var anterior: Combatant = primero.get("c") as Combatant
	while hechos < n:
		var vivos: Array[Combatant] = _pantalla._vivos()
		if vivos.is_empty():
			break   # no queda nadie: se pierden, como siempre
		var victima: Combatant = vivos.pick_random()
		var r: Dictionary = _resolver_golpes_hechizo(spell, victima, foco, spell.dano_objetivo,
			true, anterior, true, 0, hechos)
		if int(r.golpes) <= 0:
			break   # salvaguarda: un vivo recien elegido siempre se lleva al menos uno
		hechos += int(r.golpes)
		out.append(r)
		anterior = victima
	return out


# DISPERSION (Tormenta, Andanada ignea): cada uno de los 'hits' es una BOLA que cae en un vivo
# al AZAR. Se recalculan los vivos POR BOLA, asi ninguna cae sobre un cadaver. Al reves que los
# rebotes, SI tira estados. Agrega POR objetivo y devuelve el array con la forma que consume
# _log_hechizo (una entrada {c, dano, mult, golpes, trail, estados} por enemigo tocado).
#
# SALPICON por elemento: cada bola tira UN elemento (la bola entera es esa gota o ese rayo). Solo
# las del ELEMENTO DE IDENTIDAD del hechizo (spell.elemento) salpican a los adyacentes: en la
# Tormenta el rayo arquea a los lados y la lluvia cae suelta; en la Andanada todo es fuego = todo
# salpica. En 1v1 no hay adyacentes, asi que el salpicon no cambia nada: solo mejora el multi.
func _resolver_dispersa(spell: SpellData, foco: float) -> Array:
	var n: int = spell.golpes()
	var acc: Dictionary = {}     # Combatant -> {c, dano, mult, golpes, trail, estados}
	var anun: Dictionary = {}    # Combatant -> estados ya anunciados (no repetir en el log)
	var orden: Array = []        # orden de aparicion, para un log estable
	for i in n:
		var vivos: Array[Combatant] = _pantalla._vivos()
		if vivos.is_empty():
			break   # no queda nadie: los golpes que faltaban se pierden
		var principal: Combatant = vivos.pick_random()
		var elem: int = spell.elemento_de_golpe(i, n)   # UN elemento para toda la bola
		# ¿Esta bola salpica? Solo los golpes del elemento de identidad, y solo si hay salpicon.
		var objetivos: Array
		if spell.salpica() and elem == spell.elemento:
			objetivos = _pantalla.objetivos._objetivos_area(spell, principal)
		else:
			objetivos = [{"c": principal, "escala": spell.dano_objetivo}]
		# El dano_base se reparte entre las N bolas: escala/N.
		for t in objetivos:
			var obj: Combatant = t.c
			if not obj.is_alive():
				continue
			var res: Dictionary = StatsMath.resolve_spell(_pantalla._player, obj, spell, elem, float(t.escala) / float(n))
			var dmg: float = float(res.damage) * foco
			var mult: float = float(res.get("mult_elem", 1.0))
			obj.take_damage(dmg)
			# EL GOLPE SE VE. Faltaba: la dispersion era la UNICA ruta de daño que no pasaba por
			# _fx_golpe, y por eso Tormenta y Andanada -los dos hechizos mas gordos- no sacaban ni
			# un numero ni un temblor. Se veian menos que un puñetazo.
			# El salpicon de una bola sale DEL SITIO DONDE HA CAIDO, no de tu mano: la bola cae en
			# uno y de ahi alcanza a sus vecinos (ver _resolver_hechizo, misma regla).
			# La bola y SU salpicon son el mismo instante: cae en uno y revienta, no va tocando
			# vecinos de uno en uno. Cada bola (i) si es su propia tanda. Ver _fx_tanda.
			_pantalla.efectos._fx_tanda(i)
			# Igual que en _resolver_golpes_hechizo: al vecino le llega la ONDA de lo que ha
			# reventado en el principal, no otra bola. Ver _estilo_salpicon.
			_pantalla.efectos._fx_golpe(_pantalla._player if obj == principal else principal, obj, dmg,
				bool(res.get("crit", false)), false, elem,
				_pantalla.efectos._estilo_hechizo(spell, elem, false, obj != principal),
				_pantalla.efectos._peso_hechizo(spell, float(t.escala)), false, "",
				AbilityData.Gesto.AUTO, &"", 0, float(res.get("mult_elem", 1.0)))
			_pantalla._apuntar_dano(obj, dmg, _pantalla._player)   # contador oculto de Cazador
			if not acc.has(obj):
				acc[obj] = {"c": obj, "dano": 0.0, "mult": 1.0, "crit": false, "golpes": 0, "trail": [], "estados": []}
				anun[obj] = {}
				orden.append(obj)
			var a: Dictionary = acc[obj]
			a.dano = float(a.dano) + dmg
			a.mult = mult
			if bool(res.get("crit", false)):
				a.crit = true
			a.golpes = int(a.golpes) + 1
			a.trail.append("%s%s%.1f%s" % [Elementos.icono(elem),
				"💥" if bool(res.get("crit", false)) else "", dmg, _mult_sufijo(mult)])
			print("[magia] %s bola %d/%d %s sobre %s: %.2f (x%.2f)%s" % [
				spell.nombre, i + 1, n, Elementos.nombre(elem), obj.nombre, dmg, mult,
				"  CRITICO 💥" if bool(res.get("crit", false)) else ""])
			# La lluvia que moja amplifica (x1.5) los rayos que caigan DETRAS: el golpe gasta lo
			# que lo amplificaba, igual que en la ruta normal.
			_gastar_amplificadores(obj, elem)
			# Estados de ESTE golpe (solo los de su elemento). Multi-objetivo: el log lo pliega
			# _log_hechizo de una sentada, aqui solo se acumulan los que ENTRAN.
			_aplicar_estado_hechizo(spell, obj, elem, false, anun[obj], true, a.estados)
	var out: Array = []
	for obj in orden:
		out.append(acc[obj])
	return out


# CUENTA en el log un hechizo ya resuelto y devuelve el daño TOTAL.
#   res_area -> resultados de la fase de area (el principal SIEMPRE el primero).
#   res_reb  -> resultados de los rebotes, en orden.
# El log solo guarda LOG_MAX lineas, y una Descarga sobre 4 enemigos son 18 impactos: en
# multi-objetivo se cuenta UNA LINEA POR FASE (area / rebotes / estados / total), nunca una
# por golpe. El rastro golpe a golpe se ve en la consola.
func _log_hechizo(spell: SpellData, res_area: Array, res_reb: Array, foco: float) -> float:
	var total: float = 0.0
	for r in res_area + res_reb:
		total += float(r.dano)
	var foco_txt: String = "  🔮Foco arcano +%d%% (quedan %d)" % [
		roundi(Combatant.FOCO_BONUS * 100.0), _pantalla._player.foco_cargas] if foco > 1.0 else ""

	# MONO-OBJETIVO: el formato de siempre, intacto (Tormenta, Bola de Fuego...).
	if not spell.es_multiobjetivo():
		var r0: Dictionary = res_area[0]
		if spell.es_multigolpe():
			_pantalla._set_log("🌩 %s descarga %d golpes sobre %s: %s" % [
				spell.nombre, int(r0.golpes), _pantalla._etq(r0.c), " · ".join(r0.trail)])
			if not res_reb.is_empty():
				var saltos: Array = []
				for r in res_reb:
					saltos.append("%s (%.1f%s)" % [_pantalla._etq(r.c), float(r.dano), _mult_sufijo(float(r.mult))])
				_pantalla._set_log("↪ Los golpes que sobraban saltan a %s" % ", ".join(saltos))
			_pantalla._set_log("… %.2f de daño en total.%s" % [total, foco_txt])
		else:
			# El 💥 del critico: en los multigolpe ya iba dentro del rastro, pero un hechizo de UN
			# golpe no pinta rastro y el critico no se veia por ningun lado — solo intuias que habia
			# pasado algo porque el numero salia mas gordo de lo normal.
			_pantalla._set_log("🔥 %s impacta a %s por %.2f de daño.%s%s%s" % [
				spell.nombre, _pantalla._etq(r0.c), total,
				"  ¡CRITICO! 💥" if bool(r0.get("crit", false)) else "",
				_elem_txt(float(r0.mult)), foco_txt])
		return total

	# MULTI-OBJETIVO: "Nombre (daño)" por enemigo, en una linea.
	var partes: Array = []
	for r in res_area:
		# El 💥 por objetivo: en un area, uno puede comerse el critico y los demas no.
		partes.append("%s (%s%.1f%s)" % [_pantalla._etq(r.c), "💥" if bool(r.get("crit", false)) else "",
			float(r.dano), _mult_sufijo(float(r.mult))])
	_pantalla._set_log("%s %s alcanza a %s" % [Elementos.icono(spell.elemento), spell.nombre, ", ".join(partes)])
	if not res_reb.is_empty():
		var reb: Array = []
		for r in res_reb:
			# Los repetidos se listan tal cual: que se vea cuando la cadena insiste en el mismo.
			reb.append("%s (%.1f%s)" % [_pantalla._etq(r.c), float(r.dano), _mult_sufijo(float(r.mult))])
		_pantalla._set_log("↯ Rebota ×%d: %s" % [reb.size(), ", ".join(reb)])
	# Estados PLEGADOS: una linea por estado con todos los que lo cogieron, no una por enemigo.
	var por_estado: Dictionary = {}
	for r in res_area + res_reb:
		for id in r.estados:
			if not por_estado.has(id):
				por_estado[id] = []
			if not por_estado[id].has(_pantalla._etq(r.c)):
				por_estado[id].append(_pantalla._etq(r.c))
	for id in por_estado:
		_pantalla._set_log("✨ %s: %s" % [
			String(StatusEffects.def(int(id)).get("nombre", "?")), ", ".join(por_estado[id])])
	_pantalla._set_log("… %.2f de daño en total.%s" % [total, foco_txt])
	return total


# Desglose de una habilidad MULTI-GOLPE en dos lineas, COMPARTIDO por tus habilidades y las del
# enemigo (el problema -"6 golpes, 0 de daño" no dice nada- y la solucion son los mismos).
#   titulo    -> lo que va antes de los golpes en la linea 1 ("Rafaga → 2. Slime", "2. Rata usa Frenesi").
#   rastro    -> [{t: token, c: Combatant}] en orden de golpe; token = "4.21" / "falla" / "💥9.80".
#   tocados   -> objetivos alcanzados (para el reparto y para saber si es multi-objetivo).
#   sin_dar   -> linea 2 a devolver si no conecto NINGUN golpe (el llamante la redacta: "le has"/"te ha").
#   sufijo    -> extra que se pega al final de la linea de daño (desglose de imbuicion del jugador; "" en el enemigo).
# Emite la LINEA 1 (el rastro) y DEVUELVE la LINEA 2, que el llamante remata con sus extras
# (estados, guardia, mana...) antes de mandarla al log. _etq() numera enemigos y deja pelados a los
# aliados, asi que la misma funcion etiqueta bien en los dos sentidos.
func _log_desglose(titulo: String, rastro: Array, tocados: Array, dano_por_obj: Dictionary,
		total: float, sin_dar: String, sufijo: String = "") -> String:
	var multi: bool = tocados.size() > 1
	var aciertos: int = 0
	var toks: Array = []
	for g in rastro:
		if String(g["t"]) != "falla":
			aciertos += 1
		toks.append("%s (%s)" % [g["t"], _pantalla._etq(g["c"])] if multi else String(g["t"]))
	if not toks.is_empty():
		_pantalla._set_log("⚔ %s:  %s" % [titulo, " · ".join(toks)])
	if total <= 0.0:
		return sin_dar
	if multi:
		var partes: Array = []
		for c in tocados:
			partes.append("%s (%.2f)" % [_pantalla._etq(c), float(dano_por_obj.get(c, 0.0))])
		return "… %.2f de daño: %s%s" % [total, ", ".join(partes), sufijo]
	return "… %.2f de daño (%d de %d golpes).%s" % [total, aciertos, rastro.size(), sufijo]


# Un golpe de 'elem' gasta los estados que lo amplificaban (Rayo sobre Mojado). Solo se
# anuncia en la consola: en el log del combate seria una linea por golpe.
func _gastar_amplificadores(objetivo: Combatant, elem: int) -> void:
	if elem == Elementos.Elemento.NINGUNO:
		return
	for nom in objetivo.consumir_amplificadores(elem):
		print("[estado] el golpe de %s GASTA el %s de %s (el x1.5 no se repite)" % [
			Elementos.nombre(elem), nom, _pantalla._etq(objetivo)])


# Feedback elemental de UN golpe, compacto, para el rastro del log ("⚡4.1×1.5").
func _mult_sufijo(mult: float) -> String:
	if mult > 1.01 or mult < 0.99:
		return "×%.1f" % mult
	return ""


# DESGLOSE de un daño ya hecho: cuanto fue fisico y cuanto lo puso la IMBUICION ("" si no hay
# imbuicion). El daño elemental va DENTRO del total, no encima: por eso se resta en vez de
# sumarse. Ej con un total de 38.16:  "(27.29 físico + 💧10.87 de Agua ×1.5)".
func _desglose_imbue(total: float, dmg_imbue: float, mult_imbue: float) -> String:
	if dmg_imbue <= 0.0:
		return ""
	return "  (%.2f físico + %s%.2f de %s%s)" % [
		maxf(0.0, total - dmg_imbue), Elementos.icono(_pantalla._player.imbue_elemento), dmg_imbue,
		Elementos.nombre(_pantalla._player.imbue_elemento), _mult_sufijo(mult_imbue)]


# Lo mismo para UN golpe suelto, a partir del result de resolve_attack.
# 'escala' = el dano_mult de la habilidad (escala el golpe entero, y con el la porcion).
func _imbue_dmg_txt(result: Dictionary, escala: float = 1.0) -> String:
	return _desglose_imbue(float(result.damage) * escala,
		float(result.get("dmg_imbue", 0.0)) * escala,
		float(result.get("mult_imbue", 1.0)))


# Feedback elemental de un GOLPE FISICO ya resuelto, para LAS DOS RAMAS del combate.
#
# Existe porque la rama del enemigo se lo callaba: el slime de fuego aplicaba su ×1.5 contra un
# cuerpo imbuido de agua y el log decia "te ataca por 12.40" a secas, con lo que el jugador no tenia
# forma de enterarse de que su manto estaba haciendo algo. Y esa es justo la trampa de las ramas
# espejo: arreglar solo la mia deja la mitad del sistema invisible.
#
# 'elem' es el elemento del ATACANTE (Combatant.elemento_ataque). En el jugador es siempre NINGUNO
# -- su parte elemental sale de la imbuicion y la cuenta _desglose_imbue -- asi que aqui devuelve "".
func _elem_golpe_txt(result: Dictionary, elem: int) -> String:
	if elem == Elementos.Elemento.NINGUNO:
		return ""
	var txt: String = _elem_txt(float(result.get("mult_elem", 1.0)))
	if txt == "":
		return ""   # neutro: no se dice nada, como en los hechizos
	return "  %s%s" % [Elementos.icono(elem), txt.strip_edges()]


# Lo mismo para una habilidad enemiga, que puede tocar a VARIOS con multiplicadores distintos
# (un area de fuego contra un grupo donde solo uno lleva el manto de agua). Si a todos les entro
# igual se dice una vez y en corto; si no, se dice por nombre, que es la unica forma de que el
# jugador sepa a quien le esta sirviendo su manto.
func _elem_reparto_txt(elem: int, mult_por_obj: Dictionary) -> String:
	if elem == Elementos.Elemento.NINGUNO or mult_por_obj.is_empty():
		return ""
	var notas: PackedStringArray = []
	var iguales: bool = true
	var primero: float = -1.0
	for c in mult_por_obj:
		var m: float = float(mult_por_obj[c])
		if primero < 0.0:
			primero = m
		elif not is_equal_approx(m, primero):
			iguales = false
		if _elem_txt(m) != "":
			notas.append("%s%s" % [c.nombre, _elem_txt(m)])
	if notas.is_empty():
		return ""
	if iguales:
		return "  %s%s" % [Elementos.icono(elem), _elem_txt(primero).strip_edges()]
	return "  %s %s" % [Elementos.icono(elem), ", ".join(notas)]


# Feedback elemental de un hechizo de UN solo golpe. OJO: GDScript no soporta %g.
func _elem_txt(mult: float) -> String:
	if mult > 1.01:
		return "  ¡DÉBIL! ×%.1f" % mult
	if mult < 0.99:
		return "  resiste ×%.1f" % mult
	return ""


# Gasta UN uso de la imbuicion. Lo llaman las acciones que ATACAN (basico y habilidades que
# pegan), NUNCA el paso del turno: asi recitar un conjuro largo, defenderte o beber no te funde
# el filo antes de haberlo usado. Se llama DESPUES de resolver el ataque (el golpe que la gasta
# tambien se beneficia de ella).
func _gastar_imbue() -> void:
	if _pantalla._player.consumir_imbue():
		print("[imbuicion] Se agota la imbuición de %s (sin usos)." % _pantalla._player.nombre)
		_pantalla._set_log("Se agota tu imbuición. ✨")


# Aplica (o no) los estados del hechizo. Al ENEMIGO = con PROBABILIDAD (el enemigo puede
# resistir). A UNO MISMO (buff) = siempre.
#   elem_golpe >= 0 -> solo se tiran los efectos de ESE elemento (los que piden otro se
#                      saltan). Es lo que hace que la Tormenta moje con el agua y electrice
#                      con el rayo. < 0 = sin filtro (hechizos de buff/debuff, sin golpes).
#   verboso    -> false en multi-golpe: 20 tiradas fallidas serian 20 lineas de log. Los
#                 fallos se ven igual en la consola; en el log solo se anuncia lo que ENTRA.
#   anunciados -> estados ya nombrados en el log (no repetir "recibe Mojado" en cada golpe).
#   silencioso -> no toca el log NADA (ni inmunidades ni resistencias: van a la consola). Lo
#                 usa el multi-objetivo, donde el log lo escribe _log_hechizo de una sentada.
#   aplicados  -> se rellena con los estados que ENTRAN, para que el llamador los pliegue.
func _aplicar_estado_hechizo(spell: SpellData, objetivo_ataque: Combatant = null,
		elem_golpe: int = -1, verboso: bool = true, anunciados: Dictionary = {},
		silencioso: bool = false, aplicados: Array = []) -> void:
	var enemigo: Combatant = objetivo_ataque if objetivo_ataque != null else _pantalla._objetivo()
	for a in spell.efectos:
		if a.estado < 0:
			continue
		# Filtro por elemento del golpe: elemento_req -1 = en todos los golpes.
		if elem_golpe >= 0 and int(a.elemento_req) >= 0 and int(a.elemento_req) != elem_golpe:
			continue
		var al_enemigo: bool = a.en_objetivo
		# Los buffs (en_objetivo = false) van al ALIADO ELEGIDO, que por defecto es el que lanza:
		# Fortaleza se la puedes echar al tanque, no solo a ti. Y con a_todo_el_grupo, a TODOS —
		# esta rama lo ignoraba, que es el mismo agujero que tenian las habilidades: las dos tienen
		# que contestar igual o un hechizo de grupo escrito mañana solo buffearia a uno.
		var destinos_h: Array = []
		if al_enemigo:
			destinos_h.append(enemigo)
		elif a.a_todo_el_grupo:
			for al_h in _pantalla._aliados_vivos():
				destinos_h.append(al_h)
		else:
			destinos_h.append(_pantalla._cast_aliado)
		var objetivo: Combatant = destinos_h[0]
		var nom: String = str(StatusEffects.def(a.estado).get("nombre", "?"))
		# Inmunidad elemental: si el objetivo no puede recibir el estado, avisar y no tirar.
		if objetivo.es_inmune(a.estado):   # incluye la inmunidad derivada de su AFINIDAD elemental
			if not anunciados.has(a.estado):
				anunciados[a.estado] = true
				if not silencioso:
					_pantalla._set_log("… %s es INMUNE a %s." % [_pantalla._etq(objetivo), nom])
				print("[estado] %s es INMUNE a %s" % [objetivo.nombre, nom])
			continue
		if al_enemigo:
			# Mi eficacia contra su resistencia, por la puerta comun. Lo del ATURDIDO ya va dentro:
			# el x1.5 por estar ELECTRIZADO y el x0.6 de la afinidad Rayo entran como resistencia de
			# familia (ver Combatant._resist_control_extra), no como un carril aparte.
			var p: float = StatusEffects.prob_final(spell.efecto_prob(a), _pantalla._player, objetivo, a.estado)
			if randf() >= p:
				if verboso and not silencioso:   # en multi-golpe callamos los fallos: serian 20 lineas de ruido
					_pantalla._set_log("… pero %s resiste el %s. (%.0f%%)" % [_pantalla._etq(objetivo), nom, p * 100.0])
				print("[estado] %s RESISTE %s del hechizo (prob %.0f%%)" % [objetivo.nombre, nom, p * 100.0])
				continue
		for d_h in destinos_h:
			if d_h == null or not d_h.is_alive():
				continue
			d_h.apply_status(a.estado, a.turns, a.magnitud, 1, false, a.cap)
			print("[estado] %s recibe %s del hechizo %s (prob %.0f%%)" % [
				_pantalla._etq(d_h), nom, spell.nombre, spell.efecto_prob(a) * 100.0])
		if not aplicados.has(int(a.estado)):
			aplicados.append(int(a.estado))
		if not anunciados.has(a.estado) and not silencioso:
			anunciados[a.estado] = true
			var a_quien: String = "todo el grupo" if destinos_h.size() > 1 else _pantalla._etq(objetivo)
			_pantalla._set_log("✨ %s: %s recibe %s." % [spell.nombre, a_quien, nom])


# Fallar una frase: el conjuro se descontrola. Daño propio (mayor cuanto mas avanzado ibas), el
# conjuro se interrumpe y AQUI se cobra el mana: el hechizo ya no se paga por adelantado (ver
# _elegir_hechizo), pero equivocarse de frase sigue costandolo. Es lo unico que se pierde por tu
# mano; que te lo tiren o que se acabe la pelea recitando ya no cobra nada.
# 'elegida' y 'correcta': la frase que se dijo y la que tocaba. Van al registro ANTES del descontrol para
# que se sepa por que ha fallado (lo pidio el usuario: sin eso solo veias el golpe).
func _backfire(elegida: String = "", correcta: String = "") -> void:
	var spell := _pantalla._cast_spell
	if elegida != "":
		_pantalla._set_log("🗣️ %s recita «%s»… pero era «%s»." % [_pantalla._player.nombre, elegida, correcta])
	_pantalla._player.spend_mana(_coste_efectivo(spell))
	# Por TU VIDA MAXIMA, no por el daño del hechizo: asi fallar duele lo mismo el primer dia que
	# con 500 de vida (ver StatsMath.backfire_damage). Y puede tumbarte: el KO se resuelve abajo.
	var dmg := StatsMath.backfire_damage(spell, _pantalla._cast_index, spell.longitud(), _pantalla._player.max_hp)
	_pantalla._player.take_damage(dmg)
	print("[magia] BACKFIRE %s | frase %d/%d | dano propio:%.2f" % [
		spell.nombre, _pantalla._cast_index + 1, spell.longitud(), dmg])
	_pantalla._set_log("💥 %s recita mal el conjuro y se descontrola: %.2f de daño. El hechizo se pierde."
		% [_pantalla._player.nombre, dmg])
	_pantalla._player.regen_energy(_pantalla.ATTACK_ENERGY_REGEN)   # aun fallando, es un turno sin gasto de energia (KAN-57)
	_limpiar_casteo()
	_pantalla._update_hp()
	_pantalla._fin_de_eleccion()
	if not _pantalla._player.is_alive():
		_pantalla.altas._caer_aliado(_pantalla._player)   # el conjuro descontrolado puede tumbar al que lo recitaba
		if _pantalla.altas.derrota():
			_pantalla._end(false)
			return
	_pantalla._state = _pantalla.State.ADVANCING


func _limpiar_casteo() -> void:
	_pantalla._cast_spell = null
	_pantalla._cast_index = 0
