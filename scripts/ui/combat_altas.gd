# ============================================================
#  combat_altas.gd  (tema de la pantalla de combate: combat.altas)
#  QUIEN ENTRA Y QUIEN SALE A MEDIA PELEA: aliados que se unen, huyen y vuelven; enemigos que se meten,
#  esperan en la cola o se invocan; la retirada de cadaveres de la fila de enfrente, apagar a los caidos
#  y revivir un hueco. Lo demas, a _pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# Hay un aliado EN CAMINO (concedido por la red, todavia no dentro). Mientras este puesto, la
# pelea no se da por perdida aunque caigan todos: ver derrota().
var _espera_refuerzo := false


# El bloque de UN aliado (su caja con nombre, estados y las tres barras), colgado de la fila. Se
# saco del bucle de _setup_ui para poder añadir aliados a MITAD de pelea (hito 5.4-C): un
# compañero que se une necesita exactamente esto y nada mas.
func _anadir_bloque_aliado(c: Combatant) -> void:
	var ba: Dictionary = _pantalla.figuras._crear_bloque(c, 0, -1)
	_pantalla.efectos._crear_barras_aliado(ba, c)
	_pantalla._bloques_aliados.append(ba)
	_pantalla.montaje._aliados_box.add_child(ba["columna"])
	# La fila acaba de crecer: puede que lo que cabia antes ya no quepa (ver _ancho_bloque).
	_pantalla.montaje._reajustar_anchos(_pantalla._bloques_aliados, _pantalla._bloques_aliados.size())
	# Y puede que el que se une sea mas grande (o mas pequeño) que el resto de la pelea -- el factor
	# de zoom es compartido con los enemigos, ver _ajustar_zoom_sprites.
	_pantalla.figuras._ajustar_zoom_sprites()


# UN ALIADO MAS en la pelea en curso (hito 5.4-C): entra el personaje de otro humano que se une.
# Es el simetrico de anadir_enemigo, pero con una diferencia importante: SIEMPRE por el final
# (append), nunca insertando ni reordenando. combat_finished devuelve los resultados POR INDICE y
# Game los cruza posicionalmente con _active_player_pjs; mover a alguien de sitio le daria la vida
# y el mana de otro.
# Devuelve false si la pelea ya esta cerrandose o no cabe en pantalla.
# ¿Se ha perdido la pelea? Estaba escrito a mano en CUATRO sitios distintos; se centraliza aqui
# porque desde el hito 5.4 puede haber un refuerzo EN CAMINO (un compañero que se une, avisado por
# la red pero que aun no ha entrado). Declarar la derrota en ese hueco cerraria la pelea justo
# cuando llegaba el rescate, y encima el que llega se encontraria una pelea muerta.
func derrota() -> bool:
	if not _pantalla._aliados_vivos().is_empty():
		return false
	return not _espera_refuerzo


# Lo enciende quien vaya a meter un aliado (Net, al conceder la union) para que la pelea aguante
# hasta que entre de verdad. Se apaga solo en anadir_aliado.
func esperar_refuerzo(si: bool) -> void:
	_espera_refuerzo = si


# 'agotado' = llega SIN FUELLE de correr por el mapa. Sus primeras acciones van lentas, igual que
# las del que empieza la pelea agotado (ver setup: es la misma penalizacion, y se olvidaba aqui).
func anadir_aliado(c: Combatant, agotado: bool = false) -> bool:
	if c == null or _pantalla._state == _pantalla.State.FINISHED:
		return false
	# Los HUIDOS no ocupan plaza. _aliados NO se vacia al huir (ese array se cruza por INDICE con
	# Game._active_player_pjs, ver _retirar_aliado), asi que contarlo a pelo dejaba las plazas de quien
	# se fue pilladas PARA SIEMPRE: huias de una pelea llena y ya no podias volver a entrar nunca,
	# aunque tu compañero siguiera dentro peleandola. Su hueco tiene que quedar libre.
	if _pantalla._aliados.size() - _pantalla._huidos.size() >= _pantalla.MAX_ALIADOS:
		return false
	_desambiguar(c)
	_pantalla._aliados.append(c)
	_espera_refuerzo = false   # ya ha llegado
	_alta_de_aliado(c, agotado)
	_pantalla._set_log("%s se une a la pelea." % c.nombre)
	return true


# EL HUECO QUE DEJO ESTE MISMO PERSONAJE AL HUIR, si es que huyo de esta pelea. Devuelve su indice
# en _aliados, o -1.
#
# Existe por el bug de los DOBLES al huir y volver a entrar. Huir no saca a nadie de _aliados (ese
# array se cruza por INDICE con Game._active_player_pjs, ver _retirar_aliado), asi que al reentrar
# anadir_aliado hacia un append y en la pelea acababa habiendo DOS entradas del mismo personaje:
# _desambiguar le ponia "(2)" al nuevo, y en el espejo -que no recibe quien ha huido y solo añade
# por el final- se veian los dos bloques. La guarda de Game.unir_aliado_al_combate no lo pillaba
# porque compara identidad de objeto, y el que reentra llega por Net.partida.ficha_de_dict, que crea un
# PersonajeData NUEVO cada vez.
#
# La llave es el UID de la ficha, que si sobrevive a ficha_de_dict (viaja como un campo mas).
func hueco_huido_de(uid: String) -> int:
	if uid.is_empty():
		return -1
	for i in _pantalla._aliados.size():
		var c: Combatant = _pantalla._aliados[i]
		if not _pantalla._huidos.has(c):
			continue
		var pj: PersonajeData = Game.pj_de_combatant(c)
		if pj != null and pj.uid == uid:
			return i
	return -1


# VUELVE EL QUE HUYO, a su propio hueco. Es la gemela de anadir_aliado para un reingreso: en vez de
# alargar _aliados, PISA la posicion que ya tenia. Asi el cruce por indice con _active_player_pjs
# sigue valiendo (Game pisa la suya en el mismo indice), no hay dos entradas del mismo personaje y
# el nombre vuelve a ser el suyo sin el "(2)".
func readmitir_aliado(idx: int, c: Combatant, agotado: bool = false) -> bool:
	if c == null or _pantalla._state == _pantalla.State.FINISHED or idx < 0 or idx >= _pantalla._aliados.size():
		return false
	var viejo: Combatant = _pantalla._aliados[idx]
	_pantalla._huidos.erase(viejo)
	_pantalla._gauge.erase(viejo)
	_pantalla._defendiendo.erase(viejo)
	_pantalla._casteos.erase(viejo)
	_pantalla._lentas.erase(viejo)
	_pantalla._dueno_aliado.erase(viejo)
	_pantalla._aliados[idx] = c
	_espera_refuerzo = false
	# Su bloque sigue en _bloques_aliados (nunca se borro, solo se escondio): se reestrena en vez de
	# crear otro, que es lo que descuadraria la alineacion por indice de la fila.
	if idx < _pantalla._bloques_aliados.size():
		var b: Dictionary = _pantalla._bloques_aliados[idx]
		b["panel"].modulate = Color.WHITE
		b["panel"].add_theme_stylebox_override("panel", _pantalla.figuras._sb_bloque(false))
		b["chips"].visible = true
		b["nombre"].text = c.nombre
		b["hp"].max_value = c.max_hp   # vuelve con otra vida: la barra medía contra el tope de antes
		var col: Control = b.get("columna")
		if col != null and is_instance_valid(col):
			col.visible = true
			col.modulate = Color.WHITE
		# LA FIGURA es la que monto el Combatant de antes, y este es OTRO objeto: mientras estuvo
		# fuera pudo cambiarse el arma o la armadura. Se tira entera y se monta de nuevo, igual que
		# hace _revivir_bloque con el hueco de un cadaver, para que ademas nazca en REPOSO y no
		# herede la pose con la que se fue.
		var fig: ColorRect = b.get("figura")
		if fig != null and is_instance_valid(fig):
			for hijo in fig.get_children():
				fig.remove_child(hijo)
				hijo.queue_free()
			if fig.has_meta("sprite"):
				fig.remove_meta("sprite")
			if fig.has_meta("alto_base"):
				fig.remove_meta("alto_base")
			fig.color = c.color_visual
			_pantalla.figuras._poner_sprite(fig, c)
	_alta_de_aliado(c, agotado, false)
	_pantalla._set_log("%s vuelve a la pelea." % c.nombre)
	return true


# LO COMUN a entrar por primera vez y a volver: la barra, el agotamiento, el marcador de turnos y el
# aviso a los espejos. Estaba solo en anadir_aliado y readmitir_aliado lo necesita igual; separarlo
# evita que las dos ramas se desincronicen, que es como se rompen estas cosas sin dar error.
#
# 'bloque_nuevo' = hay que crear su caja en la fila. Al VOLVER no, que su caja sigue ahi de cuando
# huyo: crear otra descuadraria la alineacion por indice entre _aliados y _bloques_aliados.
func _alta_de_aliado(c: Combatant, agotado: bool, bloque_nuevo: bool = true) -> void:
	_pantalla._gauge[c] = 0.0          # entra con la barra a cero: unirse no regala un turno inmediato
	if agotado:
		_pantalla._lentas[c] = _pantalla.EXHAUSTED_SLOW_ACTIONS
	if bloque_nuevo:
		_anadir_bloque_aliado(c)
	if _pantalla._timeline != null:
		_pantalla._timeline.anadir(c, _pantalla._color_de(c), _pantalla._material_de(c), "")
	_alta_de_combatiente()
	_pantalla._update_hp()


# Un combatiente MAS en la pelea. Sube la revision del roster y se lo manda a los espejos por canal
# FIABLE: la instantanea es solo numeros y ademas va sin garantia, asi que un alta no puede viajar
# en ella (era el bug de "los enemigos que se añaden no los ve el otro jugador").
func _alta_de_combatiente() -> void:
	_pantalla.espejo._rev += 1
	if _pantalla._espejo or not Net.activo:
		return
	Net.peleas.difundir_roster(_pantalla.espejo.roster_para_espejo())


# Dos personajes con el mismo nombre eran indistinguibles en la pelea (el log decia "Dasui ataca" y
# habia dos Dasui). Se numeran del segundo en adelante. Se toca el nombre del COMBATIENTE, que es una
# copia de esta pelea, nunca el del PersonajeData.
func _desambiguar(c: Combatant) -> void:
	if c == null:
		return
	var base: String = c.nombre
	var n: int = 1
	while _hay_aliado_llamado(c.nombre, c):
		n += 1
		c.nombre = "%s (%d)" % [base, n]


# Sirve igual antes de meter a alguien en la lista y con el ya dentro: se ignora a si mismo.
func _hay_aliado_llamado(nombre: String, salvo: Combatant) -> bool:
	for a in _pantalla._aliados:
		if a != salvo and a.nombre == nombre:
			return true
	return false


# --- RETIRADA DE CADAVERES (SOLO la fila de enfrente) ----------------------------------------
# Bloques de enemigos muertos que se estan yendo de la fila. El nodo NO se libera y su entrada en
# _enemies/_bloques NO se toca: solo se OCULTA el envoltorio y se recolocan los anchos.
#
# NO SE PUEDE SACAR DEL ARRAY, por mucho que sea lo natural: los codigos de red SON los indices
# (_cod_combatiente devuelve 100 + i y _de_codigo hace _enemies[cod - 100]). Quitar a un muerto
# desplaza todos los indices de detras y el espejo aplicaria los golpes AL BICHO EQUIVOCADO, sin
# dar un solo error. Ocultando la tarjeta se arregla lo que se ve sin tocar lo que se sincroniza.
#
# Y los NUMEROS no se recalculan: se selecciona a los enemigos por su numero, asi que renumerar a
# mitad de pelea haria que el "4" que tenias apuntado pasara a ser otro bicho. Quedan 1, 2, 4, 5.
var _retirando: Array[Dictionary] = []
const T_RETIRADA := 0.28   # lo que tarda la tarjeta en desvanecerse


# Espera a que la barra TERMINE de bajar y entonces desvanece la tarjeta y recompone la fila.
# Va en _process ANTES del return del espejo: en el espejo tambien se muere gente.
#
# El apagado (apagar_ahora) salta cuando ATERRIZA el ultimo golpe, que es un pelin ANTES de que la
# barra llegue a cero -- la barra viaja sola a VEL_BARRA. Si se retirase ahi, la tarjeta se iria
# con la barra a medias y no se veria el golpe que lo mata, que es justo lo que se queria evitar.
func _avanzar_retiradas(delta: float) -> void:
	if _retirando.is_empty():
		return
	var recomponer: bool = false
	for i in range(_retirando.size() - 1, -1, -1):
		var b: Dictionary = _retirando[i]
		# Se desvanece LA COLUMNA entera (su tarjeta y su sprite): es la que ocupa el hueco en la
		# banda, y es toda su presencia en pantalla lo que tiene que irse.
		var col: Control = b.get("columna")
		# Si el hueco se ha reestrenado mientras se iba (un refuerzo entra en el slot del muerto),
		# _revivir_bloque ya lo ha sacado de la lista. Esto cubre el resto de casos raros.
		if col == null or not is_instance_valid(col) or not col.visible:
			_retirando.remove_at(i)
			continue
		# LO QUE LE QUEDA DE MORIRSE SE DESCUENTA SIEMPRE, y va ANTES de mirar la barra a proposito.
		#
		# Las dos esperas tienen que correr EN PARALELO: la muerte arranca cuando aterriza el golpe
		# letal y la barra sale viajando en ese mismo instante, asi que para cuando la vida llega a
		# cero el bicho ya lleva medio derretido. Puesto DESPUES del 'continue' de la barra, el reloj
		# de la muerte no empezaba a correr hasta que la barra terminaba -- las dos esperas se
		# SUMABAN, y un bicho con mucha vida se quedaba plantado casi un segundo de mas.
		var muerte: float = float(b.get("muerte_queda", 0.0))
		if muerte > 0.0:
			muerte -= delta
			b["muerte_queda"] = muerte
		var bar: ProgressBar = b.get("hp")
		if bar != null and is_instance_valid(bar) and bar.value > 0.01:
			continue   # aun le queda vida que bajar: que se vea
		if muerte > 0.0:
			continue   # y que se le vea morir entero antes de desvanecerse
		var t: float = float(b.get("retirada_t", 0.0)) + delta
		b["retirada_t"] = t
		col.modulate.a = 1.0 - clampf(t / T_RETIRADA, 0.0, 1.0)
		if t < T_RETIRADA:
			continue
		col.visible = false
		col.modulate.a = 1.0   # el alpha se deja limpio por si el hueco se reestrena
		b.erase("retirada_t")
		b.erase("muerte_queda")
		_retirando.remove_at(i)
		recomponer = true
	if recomponer:
		_recomponer_fila_enemigos()


# Reparte el ancho entre las tarjetas que SE VEN. Es lo que hace que al morir uno de cinco la fila
# pase sola al formato de cuatro. Un unico sitio, para que el arranque, los refuerzos y la retirada
# cuenten todos igual: contando bloques ocultos, los vivos se quedaban estrechos sin motivo.
func _recomponer_fila_enemigos() -> void:
	var visibles: Array = []
	for b in _pantalla._bloques:
		var col: Control = b.get("columna")
		if col != null and is_instance_valid(col) and col.visible:
			visibles.append(b)
	_pantalla.montaje._reajustar_anchos(visibles, visibles.size())
	_ordenar_fila_enemigos()
	# La fila ha cambiado: puede haber entrado uno mas grande, o haberse ido el que mandaba.
	_pantalla.figuras._ajustar_zoom_sprites()


# EL JEFE, SIEMPRE EN EL CENTRO. Los invocados entran en el primer hueco libre y se añaden al final,
# asi que el Rey Slime acababa lanzando sus bolas hacia los lados y luego DESPLAZANDOSE el, como si
# hiciera cola con su propio sequito. Aqui se recoloca su tarjeta al medio de las que se ven.
#
# Se mueve el NODO dentro del HBox (move_child), nunca la entrada de _enemies: los codigos de red
# son los indices del array (ver _cod_combatiente), y tocarlos desincroniza al espejo en silencio.
# Los ocultos se empujan al final para que no dejen huecos raros en el reparto.
func _ordenar_fila_enemigos() -> void:
	if _pantalla._bloques_box == null or not is_instance_valid(_pantalla._bloques_box):
		return
	var jefes: Array = []
	var resto: Array = []
	var ocultos: Array = []
	for i in _pantalla._bloques.size():
		# LA COLUMNA, que lleva la tarjeta y el sprite pegados: recolocandola se mueven los dos a
		# la vez y no pueden acabar en sitios distintos.
		var col: Control = _pantalla._bloques[i].get("columna")
		if col == null or not is_instance_valid(col):
			continue
		if not col.visible:
			ocultos.append(col)
		elif i < _pantalla._enemies.size() and _pantalla._enemies[i].centrado_en_fila:
			jefes.append(col)
		else:
			resto.append(col)
	if jefes.is_empty():
		return   # sin jefe no hay nada que recolocar: se respeta el orden del array
	# Los jefes se meten JUSTO EN MEDIO de los demas. Con 2 secuaces queda [s, REY, s]; con 1,
	# [s, REY] -- que es lo mas centrado posible sin inventarse un hueco.
	var orden: Array = resto.duplicate()
	for w in jefes:
		orden.insert(orden.size() / 2, w)
	var idx: int = 0
	for w in orden + ocultos:
		_pantalla._bloques_box.move_child(w, idx)
		idx += 1


# La fila de enemigos TAL COMO SE VE: los vivos y visibles, de izquierda a derecha. Es lo que manda
# para la adyacencia, y no el orden del array: desde que el jefe se recoloca al centro
# (_ordenar_fila_enemigos) los dos ordenes pueden no coincidir, y "el de al lado" tiene que ser el
# que el jugador ve al lado. Si no, volveriamos al problema de los cadaveres pero al reves.
func _fila_visual_enemigos() -> Array[Combatant]:
	var pares: Array = []
	for i in _pantalla._bloques.size():
		if i >= _pantalla._enemies.size() or not _pantalla._enemies[i].is_alive():
			continue
		var col: Control = _pantalla._bloques[i].get("columna")
		if col == null or not is_instance_valid(col) or not col.visible:
			continue
		pares.append([col.get_index(), _pantalla._enemies[i]])
	pares.sort_custom(func(x, y): return int(x[0]) < int(y[0]))
	var out: Array[Combatant] = []
	for p in pares:
		out.append(p[1])
	return out


# Apaga el bloque de un enemigo que ha caido: gris, barra a 0 y sin clic. El nodo NO se libera y su
# slot NO se toca (ver _retirando): solo se oculta la tarjeta cuando ha terminado de morirse.
func _apagar_bloque(e: Combatant) -> void:
	var i: int = _pantalla._enemies.find(e)
	if i < 0 or i >= _pantalla._bloques.size():
		return
	_apagar_diferido(_pantalla._bloques[i], false)


# EL GRIS DEL CADAVER, pero ESPERANDO a que se vea morir. Los muertos se rematan al final de la
# accion (_tras_accion_jugador_varios), o sea ANTES de que la cola de animacion haya reproducido
# un solo golpe: la tarjeta se ponia gris y despues llegaba volando el hechizo que la mataba.
#
# Si a ese bloque aun le quedan golpes por aterrizar, se marca y lo apaga CombatFX en cuanto
# caiga el ultimo (señal apagar_ahora). Si no queda ninguno, se apaga ya.
func _apagar_diferido(b: Dictionary, es_aliado: bool) -> void:
	if _pantalla._fx != null and _pantalla._fx.golpes_pendientes(b):
		b["fx_apagar"] = true
		b["fx_apagar_aliado"] = es_aliado
		return
	_apagar_visual(b, es_aliado)


# El apagado en si. Un solo sitio, porque lo llaman cuatro caminos (enemigo muerto, aliado KO, el
# barrido de caidos del espejo, y el diferido de arriba) y antes estaba copiado en todos.
#
# SE APAGA UNA SOLA VEZ. En el ESPEJO esto se llamaba en CADA instantanea que llegara (ver
# _apagar_caidos, que barre a los que estan a 0 y no sabe a quien ya barrio): la animacion de muerte
# volvia a empezar desde el primer fotograma con cada paquete, o sea el bicho muriendose tres o
# cuatro veces seguidas en bucle, y encima cada pasada reescribia 'muerte_queda' y alargaba la
# retirada. El guard de _retirando que habia solo cubria la lista de retirada, no la animacion.
# El flag va en el BLOQUE (no en el combatiente) porque es estado de pantalla, y _revivir_bloque -que
# es lo unico que reestrena un hueco- lo limpia.
func _apagar_visual(b: Dictionary, es_aliado: bool) -> void:
	var panel: Control = b.get("panel")
	if panel == null or not is_instance_valid(panel):
		return
	if bool(b.get("muerte_pintada", false)):
		return
	b["muerte_pintada"] = true
	# EL SPRITE/MUÑECO SE QUEDA MUERTO, pase lo que pase despues. Sin esta marca, un bicho que caiga
	# mientras atacaba resucita al cerrarse la cola (ver _on_gesto_terminado), y hasta un golpe de
	# area que le entrara ya cadaver le haria sacudir la cabeza. Ver PoseSprite.
	var nodo_muerto: Node = _pantalla.figuras._nodo_pose_de(b)
	if nodo_muerto != null:
		_pantalla.figuras._pose_marcar(nodo_muerto, _pantalla.figuras.PoseSprite.MUERTE)
	# Y AQUI ES DONDE SE MUERE. Este es el momento exacto: _apagar_diferido ya ha esperado a que
	# aterrice el golpe que lo mata (señal apagar_ahora), asi que la muerte empieza justo cuando le
	# entra el ultimo porrazo y no antes.
	var muriendo: bool = _pantalla.figuras._arrancar_muerte(b, nodo_muerto)
	# EL GRIS VA EN LA COLUMNA, no en la tarjeta: asi cae sobre la ficha Y sobre la figura del
	# escenario de una vez. Y no puede ir en la figura misma, que es de CombatFX -- su modulate se
	# reescribe cada frame (ver _aplicar) y se comeria el gris al instante.
	#
	# Y NO SE PONE SI SE LE VE MORIR: el gris existe para decir "este ya no esta", y cuando el bicho
	# se derrite o se desploma delante de ti eso ya esta dicho. Se queda de respaldo para los aliados,
	# para los enemigos que siguen siendo una figura de color y para cualquiera cuyo horneado no
	# traiga la animacion.
	var col: Control = b.get("columna")
	if col != null and is_instance_valid(col) and not muriendo:
		col.modulate = Color(0.4, 0.4, 0.4)
	if not es_aliado:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Y su figura tampoco: a un cadaver no se le apunta por ninguna de las dos vias.
		var hueco: Control = b.get("actor_wrap")
		if hueco != null and is_instance_valid(hueco):
			hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cur: Control = b.get("cursor")
		if cur != null and is_instance_valid(cur):
			cur.visible = false
	panel.add_theme_stylebox_override("panel", _pantalla.figuras._sb_bloque(false))
	b["chips"].visible = false
	# Un cadaver no arde ni centellea. Hay que apagarlo A MANO porque _update_hp se salta los
	# chips de los muertos: sin esto el emisor se quedaba emitiendo encima del muerto para siempre.
	if _pantalla._fx != null:
		_pantalla._fx.pintar_estados(b, [], false)
	# Y ahora que ya se ha visto morir, que se VAYA de la fila (solo los de enfrente; los tuyos se
	# quedan en su sitio a proposito). Ver _avanzar_retiradas.
	if not es_aliado and not _retirando.has(b):
		_retirando.append(b)
		# Un enemigo muerto ya no cuenta para el zoom compartido -- para los de enfrente esto llega
		# solo, mas tarde, via _recomponer_fila_enemigos cuando se retira de verdad. Para un ALIADO,
		# que se queda en su sitio y nunca dispara esa recomposicion, hay que pedirlo aqui: si era el
		# mas grande de la pelea, el resto no puede seguir encogido por un cadaver.
	elif es_aliado:
		_pantalla.figuras._ajustar_zoom_sprites()


# UN ALIADO CAE (KO). No es una derrota: sale del orden de turnos, se le apaga el bloque y la
# pelea sigue con los que queden. Se pierde solo cuando cae el ULTIMO (lo mira quien llama).
# Sus estados y lo que tuviera a medias (Defender, un conjuro recitandose) se van con el: el que
# vuelva a levantarse no reanuda el hechizo por el que iba.
func _caer_aliado(c: Combatant) -> void:
	if c == null:
		return
	_pantalla._gauge.erase(c)
	_pantalla._defendiendo.erase(c)
	_pantalla._casteos.erase(c)
	# COBERTURA: caiga el que cubre o el cubierto, la pareja se deshace entera. Si no, el muerto se
	# queda apuntado en el vivo y la redireccion mandaria golpes a un cadaver -- o los dejaria de
	# mandar al que ya no tiene quien le tape.
	_pantalla.objetivos._romper_cobertura(c)
	c.statuses.clear()
	var i: int = _pantalla._aliados.find(c)
	if i >= 0 and i < _pantalla._bloques_aliados.size():
		_apagar_diferido(_pantalla._bloques_aliados[i], true)   # espera a que se vea el golpe que lo tumba
	_pantalla._set_log("%s cae derrotado. 💀" % c.nombre)
	# El que actuaba era el: el puntero pasa a alguien en pie, o las acciones (y el log de "tu
	# turno") se quedarian colgadas de un KO.
	if _pantalla._player == c:
		var vivos: Array[Combatant] = _pantalla._aliados_vivos()
		if not vivos.is_empty():
			_pantalla._player = vivos[0]
	_pantalla._update_hp()


# INVOCACION (Rey Slime, Parte B): mete un slime VIVO en la pelea en curso.
# El slime nace flojo (t bajo): su papel es ser ESCUDO del Rey (reduccion de daño), no matarte.
# Va marcado como INVOCADO: no cuenta como kill ni da maná al matarlo (ver _slots_invocados).
# Devuelve el slime metido, o null si no cabia. Devuelve EL BICHO y no un bool porque quien invoca
# necesita su tarjeta para pintarle la gota que lo desprende (ver el Brote en _enemy_use_ability).
func _invocar_slime(data: EnemyData) -> Combatant:
	if data == null:
		return null
	var c: Combatant = data.crear_combatant(0.2)
	return c if _meter_enemigo(c, true) >= 0 else null


# REFUERZO QUE LLEGA ANDANDO (hito 5.4): un bicho del mapa alcanza a alguien que ya esta peleando y
# se mete en la pelea. A diferencia de un invocado, este es un enemigo DE VERDAD: cuenta como kill,
# da maná al morir y su cadaver es extraible, asi que NO lleva la marca de invocado.
# Devuelve el indice del slot, o -1 si no cabe (entonces el que llama lo pone en cola).
func anadir_enemigo(data: EnemyData, t: float, hp: float = -1.0, estados: Array = [],
		es_jefe: bool = false, mutante: bool = false, hueco: int = -1) -> int:
	if data == null or _pantalla._state == _pantalla.State.FINISHED:
		return -1   # la pelea ya acabo (o se esta cerrando): que se quede fuera
	# La MUTACION viaja igual que la 't' y la bandera de jefe, y por el motivo de la nota de mas
	# abajo: este es el SEGUNDO camino de entrada al combate. Sin pasarla aqui, un mini-jefe que
	# llega de refuerzo entra con las stats de un bicho corriente.
	var c: Combatant = data.crear_combatant(t, mutante, es_jefe)
	# Un JEFE puede entrar de refuerzo a una pelea ya empezada. Sin esto el roster salia sin bandera
	# y los espejos seguian con la musica de rata (y esta pantalla tampoco cambiaba de pista).
	c.es_jefe = es_jefe
	# Vida arrastrada: si ya venia herido de otra pelea, entra con sus heridas (igual que el arranque).
	if hp >= 0.0:
		c.current_hp = clampf(hp, 1.0, c.max_hp)
	# Y los ESTADOS que traia, tambien igual que en el arranque: el que se une a mitad no puede
	# entrar limpio del veneno que le pusiste hace un minuto.
	StatusEffects.aplicar_a(c, estados)
	# MODO PRUEBA: el refuerzo tambien es muñeco. Este es el SEGUNDO camino de entrada al combate y
	# es el que siempre se queda sin lo que se escribe en el otro: sin esto, el que llegaba tarde
	# entraba con sus stats de verdad y ensuciaba la medida en silencio.
	Game.volver_muneco(c, _pantalla._player)
	return _meter_enemigo(c, false, hueco)


# ¿Se esta cerrando? Lo pregunta Game antes de meter a alguien en la cola: a una pelea que acaba no
# se le encola nadie (se quedaria congelado sin nadie que lo soltara).
func acabada() -> bool:
	return _pantalla._state == _pantalla.State.FINISHED


# "+N esperando" junto a los enemigos: los de la cola de la pelea, que no tienen tarjeta (ver
# Game._cola_combate). Sin esto el jugador no sabria que matar a uno trae a otro.
var _lbl_cola: Label = null

func fijar_cola(n: int) -> void:
	if _lbl_cola == null or not is_instance_valid(_lbl_cola):
		if n <= 0:
			return
		# FUERA de la fila de tarjetas a proposito: esa fila reparte el ancho y reordena sus hijos
		# (_recomponer_fila_enemigos / _ordenar_fila_enemigos) contando que todos son columnas.
		_lbl_cola = Label.new()
		_lbl_cola.add_theme_font_size_override("font_size", 16)
		_lbl_cola.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		_lbl_cola.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_lbl_cola.add_theme_constant_override("outline_size", 4)
		_lbl_cola.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lbl_cola.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_lbl_cola.offset_top = 6.0
		_pantalla.add_child(_lbl_cola)
	_lbl_cola.text = "+%d esperando" % n
	_lbl_cola.tooltip_text = "Enemigos que esperan hueco: entran en cuanto cae uno."
	_lbl_cola.visible = n > 0


# El motor comun de "un enemigo mas en la pelea en curso". Prefiere REUTILIZAR el hueco de un
# cadaver (mantiene el tope y la numeracion estable, sin apilar bloques); si no hay cadaver y queda
# sitio, añade uno al final. Devuelve el slot, o -1 si no cabe.
func _meter_enemigo(c: Combatant, es_invocado: bool, hueco: int = -1) -> int:
	if c == null:
		return -1
	var idx: int = -1
	# Un hueco CONCRETO (el del que acaba de caer, ver Game.meter_de_la_cola), si de verdad esta libre.
	if hueco >= 0 and hueco < _pantalla._enemies.size() and not _pantalla._enemies[hueco].is_alive():
		idx = hueco
	for i in _pantalla._enemies.size():
		if idx >= 0:
			break
		if not _pantalla._enemies[i].is_alive():
			idx = i   # hueco de cadaver: se reutiliza
			break
	if idx < 0 and _pantalla._enemies.size() >= _pantalla.MAX_ENEMIGOS:
		return -1   # ni cadaver ni sitio: no cabe
	if idx >= 0:
		_pantalla._enemies[idx] = c            # reemplaza al cadaver en su slot
		_revivir_bloque(idx, c)
		_pantalla._slots_invocados.erase(idx)  # el slot se reestrena: hereda la marca del anterior si no
	else:
		idx = _pantalla._enemies.size()        # append: slot nuevo al final
		_pantalla._enemies.append(c)
		var b: Dictionary = _pantalla.figuras._crear_bloque(c, idx + 1, idx)
		_pantalla._bloques.append(b)
		_pantalla._bloques_box.add_child(b["columna"])
	# La fila ha cambiado (uno mas, o un hueco reestrenado): repartir el ancho entre los VISIBLES y
	# devolver al jefe al centro. VA EN LOS DOS CAMINOS -- reestrenar un hueco tambien saca una
	# tarjeta de la nada, y por el camino de arriba se quedaba sin recolocar.
	_recomponer_fila_enemigos()
	# Estructuras por-combatiente (mismas que puebla el arranque): ATB, marcador y roster del escudo.
	_pantalla._gauge[c] = 0.0                  # entra con la barra a cero (no regala una accion inmediata)
	if _pantalla._timeline != null:
		_pantalla._timeline.anadir(c, c.color_visual, null, str(idx + 1))
	c.battle_enemies = _pantalla._enemies      # referencia compartida: cuenta para el escudo del Rey
	if es_invocado:
		_pantalla._slots_invocados[idx] = true
	_alta_de_combatiente()   # que los espejos vean al recien llegado (roster nuevo, revision nueva)
	# Rellena YA el bloque recien creado (nombre + barra): _crear_bloque lo deja en blanco y quien lo
	# puebla es _update_hp. Sin esta llamada el refuerzo salia con el recuadro VACIO en la maquina
	# que ejecuta la pelea hasta el siguiente golpe (el espejo si lo veia, porque aplicar_roster
	# refresca). anadir_aliado ya lo hacia; aqui faltaba.
	_pantalla._update_hp()
	var etiqueta: String = "invocacion" if es_invocado else "refuerzo"
	print("[%s] entra %s en el slot %d (vivos: %d)" % [etiqueta, c.nombre, idx + 1, _pantalla._vivos().size()])
	return idx


# Vuelve a ENCENDER el bloque de un slot que reutiliza una invocacion: deshace _apagar_bloque y
# reajusta la barra al maximo del nuevo combatiente (el bloque nacio con el max del cadaver anterior).
# El nombre y la vida los refresca _update_hp solo (lee _enemies[i]).
func _revivir_bloque(i: int, c: Combatant) -> void:
	if i < 0 or i >= _pantalla._bloques.size():
		return
	var b: Dictionary = _pantalla._bloques[i]
	# El hueco se reestrena: al que entra hay que poder verle morir a EL (ver _apagar_visual).
	b["muerte_pintada"] = false
	b["panel"].modulate = Color(1, 1, 1)
	b["panel"].mouse_filter = Control.MOUSE_FILTER_STOP
	b["panel"].add_theme_stylebox_override("panel", _pantalla.figuras._sb_bloque(false))
	# Al que estrena el hueco se le vuelve a poder apuntar TAMBIEN por su figura (ver _apagar_visual).
	var hueco_vivo: Control = b.get("actor_wrap")
	if hueco_vivo != null and is_instance_valid(hueco_vivo):
		hueco_vivo.mouse_filter = Control.MOUSE_FILTER_STOP
	b["chips"].visible = true
	b["hp"].max_value = c.max_hp
	# EL HUECO SE REESTRENA: la tarjeta del cadaver estaba oculta (o desvaneciendose), asi que hay
	# que devolverla a la vida ENTERA. Sin esto el refuerzo entraba invisible -- o peor, se seguia
	# desvaneciendo encima del que acababa de entrar, porque la retirada mira el envoltorio y no
	# sabe que dentro hay otro bicho. Ver _avanzar_retiradas.
	_retirando.erase(b)
	b.erase("retirada_t")
	# Y la cuenta atras de morirse, o el hueco reestrenado nace esperando a un muerto: el refuerzo
	# entraria vivo pero con la columna bloqueada, sin desvanecerse ni terminar de aparecer.
	b.erase("muerte_queda")
	var col: Control = b.get("columna")
	if col != null and is_instance_valid(col):
		col.visible = true
		# modulate ENTERO y no solo el alpha: ahi vive tambien el gris del cadaver (ver
		# _apagar_visual), asi que devolviendo solo la opacidad el refuerzo entraba en gris.
		col.modulate = Color.WHITE
	# EL ASPECTO del que ESTRENA el hueco: la figura la creo el cadaver anterior, asi que sin esto
	# un slime invocado en el hueco de una rata seguiria siendo una rata.
	#
	# Y de paso se lleva por delante el estado del sprite (ver PoseSprite): el viejo se tira ENTERO y
	# el nuevo nace en REPOSO, asi que el refuerzo no puede heredar la MUERTE del que ocupaba el
	# sitio y quedarse plantado sin animarse el resto de la pelea.
	var fig: ColorRect = b.get("figura")
	if fig != null and is_instance_valid(fig):
		# remove_child ADEMAS del queue_free: liberar solo deja al viejo colgando hasta el final
		# del frame, y _poner_sprite habria montado el nuevo encima -- se verian los dos bichos.
		for hijo in fig.get_children():
			fig.remove_child(hijo)
			hijo.queue_free()
		if fig.has_meta("sprite"):
			fig.remove_meta("sprite")
		if fig.has_meta("alto_base"):
			fig.remove_meta("alto_base")
		fig.color = c.color_visual
		_pantalla.figuras._poner_sprite(fig, c)
		# Y su firma de mutante, PUESTA O QUITADA segun el que estrena el hueco: el aura del anterior
		# cuelga del actor y el vaciado de arriba no la toca (ver _marcar_mutante, que es idempotente).
		var act: Control = fig.get_parent() as Control
		if act != null:
			_pantalla.figuras._marcar_mutante(act, fig, c)
	# EL APAGADO PENDIENTE DEL CADAVER ANTERIOR, FUERA. Es lo que dejaba GRIS al refuerzo que entra en
	# el hueco de un muerto: _apagar_diferido no apaga en el acto si quedan golpes por aterrizar, deja
	# b["fx_apagar"] = true y lo consume despues _saldar_barras, que recorre TODAS las tarjetas. Si
	# entre medias el hueco se reestrena, ese flag apaga al que acaba de entrar —vivo— y ademas le
	# pone mouse_filter = IGNORE, asi que tampoco se le podia clicar en todo el combate.
	b.erase("fx_apagar")
	b.erase("fx_apagar_aliado")
	# Y el TINTE de estados del muerto: lo repintan _on_tinte_cambiado y _seleccionar leyendo
	# b.get("tinte"), asi que sin borrarlo el que entra hereda el color de veneno del anterior.
	b.erase("tinte")
	# El hueco se REESTRENA: la barra del que entra tiene que aparecer ya en su sitio, no venir
	# deslizandose desde la vida que tenia el cadaver anterior.
	if _pantalla._fx != null:
		_pantalla._fx.olvidar_barras(b)
