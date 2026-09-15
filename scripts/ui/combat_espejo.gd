# ============================================================
#  combat_espejo.gd  (tema de la pantalla de combate: combat.espejo)
#  LA PELEA COMPARTIDA (multi): la pantalla que la EJECUTA manda roster, instantaneas, impactos y la
#  barra de accion; la que la ESPEJA los pinta sin simular nada. Aqui van las dos puntas, el turno de un
#  personaje ajeno (pedirlo, repetirlo y aplicar su accion), el traspaso cuando se va el anfitrion y la
#  unica puerta de salida de las respuestas del espejo. Lo demas, a _pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# Identidad de cada combatiente dentro de ESTA pelea (ver _uid_de). En el anfitrion se asigna sola;
# en el espejo se copia del roster, para poder casar fila con maniqui sin depender del nombre.
var _uid: Dictionary = {}
var _uid_seq: int = 0
# Los ESTADOS de cada maniqui del espejo (Combatant -> [[texto, tooltip], ...]), tal cual los
# calculo el anfitrion. En el espejo no hay motor de estados que consultar: los chips llegan ya
# resueltos en la instantanea (ver _chips_de).
var _chips_espejo: Dictionary = {}
# LO ULTIMO QUE LE PEDI a ese remoto, para poder REENVIARSELO si no contesta. Un turno remoto que
# se pierde por el camino (su _tu_turno no llego porque su pantalla aun no estaba montada, o su
# respuesta se descarto) dejaba la pelea COLGADA PARA SIEMPRE: nadie mas puede actuar porque el ATB
# esta congelado esperandole. Con el reenvio, el turno se recupera solo.
var _peticion_pendiente: Dictionary = {}
var _espera_acum: float = 0.0
# NUMERO DE PETICION. Sube con CADA cosa que se le pide a un remoto (su turno, una frase, el
# disparo) y viaja con ella; el remoto lo devuelve en su respuesta. Es lo que distingue "me
# contesta a lo que le acabo de pedir" de "me llega, tarde, la respuesta a lo de hace dos turnos".
#
# Sin esto se perdian turnos, y el camino era este: el espejo contesta y se pone en ADVANCING; si su
# respuesta tarda mas de REENVIO_TURNO el heartbeat le repite la peticion; como ya no esta en
# WAITING_PLAYER, el guardia de turno_mio no aplicaba y le volvia a pintar la barra de acciones de un
# turno YA contestado -> segunda respuesta. Esa segunda llegaba cuando el anfitrion ya esperaba a
# OTRO jugador y, como no se validaba nada, se aplicaba al turno de ese otro: le robaba el turno. Y
# encima dejaba _esperando_a a 0 con el estado en WAITING_PLAYER, que es justo la combinacion que
# apaga el heartbeat (ver _heartbeat_remoto) y deja la pelea muerta.
var _pet_seq: int = 0
# ESPEJO: el numero de lo que me han pedido y el de lo ultimo que ya conteste.
var _seq_espejo: int = 0
var _seq_contestada: int = 0
# Cada cuanto se le repite la peticion a un remoto que no contesta. Generoso a proposito: un humano
# tarda en decidir, y el reenvio NO le molesta (ver turno_mio, que lo ignora si ya esta eligiendo).
const REENVIO_TURNO := 4.0
# REVISION del roster: sube con cada ALTA de combatiente (un refuerzo enemigo, un aliado que se
# une, una invocacion). Viaja en la instantanea para que un espejo sepa si se ha perdido un alta:
# si la revision no le cuadra, pide el roster entero y se recompone (ver aplicar_roster).
var _rev: int = 0
# ESPEJO: ya he pedido el roster y estoy esperandolo (para no pedirlo en cada instantanea).
var _rev_pedida := false
# Cada cuanto se les manda a los espejos como van las barras de accion (20 Hz, ver _difundir_atb).
const ATB_TICK := 0.05
var _atb_acum := 0.0
# ESPEJO: la barra llega a 20 Hz, pero se pinta a 60. Si _gauge se escribiera de golpe con cada
# paquete (como se hacia antes), la barra iba a ESCALONES —el que entra despues la veia a saltos—.
# Ahora el paquete solo fija el OBJETIVO y _process acerca _gauge a el cada frame, igual que
# remote_player interpola su posicion (mismo lerp exponencial y una SUAVIZADO analoga).
var _gauge_objetivo: Dictionary = {}
const SUAVIZADO_ATB := 14.0


# ARRANQUE EN ESPEJO (hito 5.4-C): monto la MISMA pantalla, pero sin simular. Los combatientes se
# reconstruyen "de escaparate" a partir del roster que manda quien ejecuta la pelea: solo hace
# falta lo que se PINTA (nombre, color y las tres barras). Es un Combatant normal con los campos
# puestos a mano — no necesita stats de verdad porque aqui no se tira ni un dado.
func setup_espejo(roster: Dictionary) -> void:
	_pantalla._espejo = true
	_pantalla._injected = true
	_pantalla._aliados.assign(_combatientes_de_escaparate(roster.get("aliados", [])))
	_pantalla._enemies.assign(_combatientes_de_escaparate(roster.get("enemigos", [])))
	for e in _pantalla._enemies:
		e.battle_enemies = _pantalla._enemies
	_pantalla._player = _pantalla._aliados[0] if not _pantalla._aliados.is_empty() else null
	_rev = int(roster.get("rev", 0))
	_pantalla._dps_on = false


func _combatientes_de_escaparate(datos: Array) -> Array:
	var out: Array = []
	for d in datos:
		out.append(_maniqui_de_fila(d))
	return out


# IDENTIDAD de un combatiente DENTRO de esta pelea. Hacia falta porque el espejo reconciliaba el
# roster comparando el NOMBRE, y los enemigos no se desambiguan: un Slime que relevaba a un Slime
# muerto -- el caso normal -- se tomaba por "el mismo de siempre" y su bloque no se reencendia
# nunca. Se quedaba gris y sin poder seleccionarlo, para siempre.
#
# Va aqui y no en Combatant porque solo tiene sentido mientras dura la pelea. Como el relevo crea un
# Combatant NUEVO, un hueco reestrenado recibe un uid distinto sin tener que contar reestrenos.
func _uid_de(c: Combatant) -> int:
	if not _uid.has(c):
		_uid_seq += 1
		_uid[c] = _uid_seq
	return int(_uid[c])


# UN maniqui a partir de su fila del roster. Suelto porque tambien lo usa aplicar_roster: los
# combatientes que se unen a MITAD de pelea llegan de uno en uno.
func _maniqui_de_fila(d: Dictionary) -> Combatant:
	# Combatant exige stats en el constructor y se calcula la vida solo. Aqui da igual: es un
	# maniqui de escaparate, asi que se crea con lo minimo y se le pisan los valores que SI se
	# pintan. Ningun dado se tira contra el (eso pasa en la maquina que ejecuta la pelea).
	var c := Combatant.new(String(d.get("nombre", "?")), 1, Abilities.new(), 1.0, 0.0, 0.0, 0.0)
	# La identidad viene del anfitrion: es lo que deja reconocer un hueco reestrenado sin fiarse del
	# nombre. El 0 de respaldo no casa con ningun uid real (empiezan en 1), asi que un roster viejo
	# sin este campo hace que todo se trate como nuevo -- que es el lado seguro del error.
	_uid[c] = int(d.get("uid", 0))
	c.level = int(d.get("nivel", 1))
	c.max_hp = float(d.get("max_hp", 1.0))
	c.current_hp = float(d.get("hp", c.max_hp))
	c.max_mp = float(d.get("max_mp", 0.0))
	c.current_mp = float(d.get("mp", 0.0))
	c.max_energy = float(d.get("max_en", 0.0))
	c.current_energy = float(d.get("en", 0.0))
	c.color_visual = d.get("color", Color.WHITE)
	# De donde sale su sprite. Un roster de una version anterior no lo trae, y entonces se queda
	# con la figura de color de siempre en vez de reventar.
	c.sprite_res = String(d.get("spr", ""))
	c.sprite_t = float(d.get("spr_t", 0.5))
	c.es_jefe = bool(d.get("jefe", false))
	c.uid_formacion = String(d.get("uidf", ""))
	# Y si es un MUTANTE, que es lo que decide su aura, su tinte y su tamaño (ver _marcar_mutante).
	# Un roster de una version anterior no lo trae y se queda en false: el bicho se ve normal, que es
	# exactamente lo que pasaba antes de esto.
	c.mutante = bool(d.get("mut", false))
	# LA FICHA DE ESCAPARATE del aliado (aspecto + equipo). No es un PersonajeData de verdad -- no
	# tiene stats ni inventario --, solo lo justo para que JugadorSprites le monte las capas. Se
	# cuelga del maniqui porque Game.pj_de_combatant no lo puede encontrar: en un espejo
	# _active_player_cs esta vacio (los personajes de verdad los lleva quien ejecuta la pelea).
	var pjd: Dictionary = d.get("pj", {})
	if not pjd.is_empty():
		c.pj_escaparate = Game.pj_de_dict(pjd)
	# Su cara, para el marcador de turnos: se monta aqui una vez y se cachea por maniqui.
	var png: PackedByteArray = d.get("imagen", PackedByteArray())
	var metal: float = float(d.get("metal", 0.0))
	# La opacidad del color sobre la imagen viaja en el roster: sin ella se fijaba a 1.0 y el color
	# tapaba la cara. El material solo hace falta si hay imagen o brillo.
	if not png.is_empty() or metal > 0.0:
		_pantalla._mat_espejo[c] = Game.material_aspecto(metal, Game.textura_de_png(png),
			float(d.get("alpha", 1.0)))
	return c


# Lo que hay que mandarle a un espejo para que MONTE la pantalla (al unirse, y otra vez cada vez que
# entra alguien nuevo en la pelea). Va con la REVISION: es lo que permite al espejo saber si se ha
# perdido un alta (ver aplicar_instantanea).
func roster_para_espejo() -> Dictionary:
	return {"aliados": _fila_de_roster(_pantalla._aliados), "enemigos": _fila_de_roster(_pantalla._enemies),
		"rev": _rev}


func _fila_de_roster(lista: Array) -> Array:
	var out: Array = []
	for c in lista:
		# El COLOR y la CARA salen de la ficha cuando la hay (los aliados): son los mismos con los
		# que se les ve en el mapa. Los enemigos no tienen ficha y usan su color_visual.
		var pj: PersonajeData = Game.pj_de_combatant(c)
		out.append({"nombre": c.nombre, "nivel": c.level, "uid": _uid_de(c),
			# SI SE HA IDO POR SU PIE. En el anfitrion el bloque del que huye se esconde, pero el
			# espejo no se enteraba (solo añade por el final) y seguia enseñando su tarjeta como si
			# peleara. Con el reingreso por hueco ya no salen duplicados, pero un huido que se queda
			# fuera tampoco puede seguir ocupando sitio en la fila del compañero.
			"huido": _pantalla._huidos.has(c),
			"color": pj.color if pj != null else c.color_visual,
			"metal": pj.metalico if pj != null else 0.0,
			# La OPACIDAD del color sobre la imagen (color_alpha del shader). Sin ella el marcador
			# de turnos del espejo pintaba el color plano tapando la cara.
			"alpha": pj.color_alpha if pj != null else 1.0,
			"imagen": pj.imagen if pj != null else PackedByteArray(),
			"max_hp": c.max_hp, "hp": c.current_hp,
			"max_mp": c.max_mp, "mp": c.current_mp,
			"max_en": c.max_energy, "en": c.current_energy,
			# DE DONDE SACAR SU SPRITE. Viaja la ruta de su .tres y la 't' de su variante, que son
			# dos datos minusculos y con eso el compañero carga el mismo bicho por su cuenta. Sin
			# esto, en su pantalla la pelea entera serian cuadrados de color.
			"spr": c.sprite_res, "spr_t": c.sprite_t,
			# SI ES UN JEFE: lo unico que necesita el espejo para poner la musica que toca. La deducia
			# de sus propios _active_enemies, que estando de espejo estan vacios (los bichos los lleva
			# la maquina que ejecuta), asi que unirse a la pelea de un jefe sonaba a pelea de rata.
			"jefe": c.es_jefe,
			# SI ES UN MUTANTE. Va por la misma razon que "jefe": el espejo no tiene el nodo del mundo
			# del que sale esta bandera, asi que sin mandarla el que se une a la pelea veia un bicho
			# corriente -- sin aura, sin tinte y del tamaño normal -- pegando como un mini-jefe. El
			# nombre ya le llegaba con el "mutante" puesto, y eso hacia la mentira mas rara todavia.
			"mut": c.mutante,
			# DE QUIEN ES el aliado, para colocarlo en su puesto de la formacion (ver _fila_visual_aliados).
			"uidf": c.uid_formacion,
			# EL EQUIPO Y EL ASPECTO del aliado, para que el espejo pueda montarle el muñeco. Los
			# enemigos viajan con su sprite (spr/spr_t) y por eso SI se veian; los aliados no llevaban
			# nada y salian de cuadrado de color con la cara pegada. Ver Game.pj_de_dict.
			"pj": Game.pj_a_dict(pj) if pj != null else {}})
	return out


# ESPEJO: llega un roster nuevo porque ALGUIEN HA ENTRADO en la pelea (un refuerzo enemigo, una
# invocacion, el compañero de otro humano). No se reconstruye la pantalla: se RECONCILIA fila por
# fila, que es mucho mas barato y ademas conserva la seleccion, el log y los marcadores que ya
# estaban. Dos casos por indice:
#   - no tengo esa fila -> combatiente nuevo (bloque + marcador de turnos);
#   - la tengo con OTRO nombre -> el anfitrion reutilizo el hueco de un cadaver (ver _meter_enemigo):
#     se sustituye el maniqui y se reenciende su bloque.
func aplicar_roster(roster: Dictionary) -> void:
	if not _pantalla._espejo:
		return
	_rev_pedida = false
	_rev = int(roster.get("rev", _rev))
	# Los aliados solo crecen por el final (nunca se reordenan ni se reutilizan huecos: el cruce por
	# indice con las fichas de Game depende de ello), asi que basta con dar de alta los que faltan.
	var mios: Array = roster.get("aliados", [])
	for i in range(_pantalla._aliados.size(), mios.size()):
		var c: Combatant = _maniqui_de_fila(mios[i])
		_pantalla._aliados.append(c)
		_pantalla._gauge[c] = 0.0
		_pantalla.altas._anadir_bloque_aliado(c)
		if _pantalla._timeline != null:
			_pantalla._timeline.anadir(c, _pantalla._color_de(c), _pantalla._material_de(c), "")
	# LOS QUE SE HAN IDO POR SU PIE, fuera de la fila (y los que VUELVEN, de vuelta a ella). Aqui no
	# hay motor de huidas que lo decida: llega resuelto del anfitrion, igual que los chips de estado.
	# El maniqui tambien se cambia si el hueco lo estrena otro (un reingreso trae un Combatant nuevo,
	# con su uid nuevo), que es lo que hace que el nombre vuelva a ser el suyo y no el "(2)" de antes.
	for i in mini(_pantalla._aliados.size(), mios.size()):
		var d: Dictionary = mios[i]
		if int(d.get("uid", 0)) != int(_uid.get(_pantalla._aliados[i], -1)):
			var nuevo: Combatant = _maniqui_de_fila(d)
			_pantalla._gauge.erase(_pantalla._aliados[i])
			_pantalla._huidos.erase(_pantalla._aliados[i])
			_pantalla._aliados[i] = nuevo
			_pantalla._gauge[nuevo] = 0.0
		var fuera: bool = bool(d.get("huido", false))
		if fuera:
			_pantalla._huidos[_pantalla._aliados[i]] = true
		else:
			_pantalla._huidos.erase(_pantalla._aliados[i])
		if i < _pantalla._bloques_aliados.size():
			var col: Control = (_pantalla._bloques_aliados[i] as Dictionary).get("columna")
			if col != null and is_instance_valid(col):
				col.visible = not fuera
	var filas: Array = roster.get("enemigos", [])
	for i in filas.size():
		var d: Dictionary = filas[i]
		# Por UID, no por nombre: los enemigos no se desambiguan, asi que comparando el nombre un
		# Slime que relevaba a un Slime muerto pasaba por "el mismo" y su bloque se quedaba apagado
		# (gris y sin poder clicarlo) para el resto de la pelea.
		if i < _pantalla._enemies.size() and int(d.get("uid", 0)) == int(_uid.get(_pantalla._enemies[i], -1)):
			continue   # el mismo de siempre: sus numeros ya los trae la instantanea
		var c: Combatant = _maniqui_de_fila(d)
		if i < _pantalla._enemies.size():
			# Hueco de cadaver reestrenado: fuera el viejo del marcador, y su bloque se reenciende.
			if _pantalla._timeline != null:
				_pantalla._timeline.quitar(_pantalla._enemies[i])
			_pantalla._gauge.erase(_pantalla._enemies[i])
			_pantalla._enemies[i] = c
			_pantalla.altas._revivir_bloque(i, c)
		else:
			_pantalla._enemies.append(c)
			var b: Dictionary = _pantalla.figuras._crear_bloque(c, i + 1, i)
			_pantalla._bloques.append(b)
			_pantalla._bloques_box.add_child(b["columna"])
		_pantalla._gauge[c] = 0.0
		if _pantalla._timeline != null:
			_pantalla._timeline.anadir(c, c.color_visual, null, str(i + 1))
	# battle_enemies es una referencia COMPARTIDA (la usa el escudo del Rey Slime para contar
	# slimes vivos): al cambiar la lista hay que repartirla otra vez.
	for e in _pantalla._enemies:
		e.battle_enemies = _pantalla._enemies
	# El roster puede haber traido bichos nuevos: si ya no caben a su ancho, se encogen todos.
	_pantalla.altas._recomponer_fila_enemigos()
	_pantalla._update_hp()
	# ...y uno de ellos puede ser un JEFE que entra a mitad. En la maquina que ejecuta la pelea de
	# esto se encarga Game.unir_enemigo_al_combate; el espejo se entera por aqui, que es su UNICA via
	# de altas.
	for e in _pantalla._enemies:
		if e.es_jefe and e.is_alive():
			Musica.cambiar_cima("jefe")
			break


# LA INSTANTANEA: lo que cambia turno a turno. Va del que ejecuta la pelea a los espejos. Solo
# lleva numeros y de quien es el turno; el resto (barras, colores, orden) ya lo tienen montado.
# Solo las ultimas lineas del log viajan al espejo. El log ENTERO crecia sin tope y una pelea larga
# hacia que la instantanea pasara de la MTU (1392): ENet la descartaba y el espejo se quedaba
# congelado sin ver el combate. El espejo solo enseña las lineas recientes de todas formas.
const _LOG_COLA_ESPEJO := 12

func instantanea() -> Dictionary:
	# 'vel' va en CADA instantanea (no solo en el roster) para que si el dueño la cambia a mitad de
	# pelea, al que la espeja le cambie sola. Es un float: sale mas barato que un aviso aparte.
	return {"a": _valores(_pantalla._aliados, true), "e": _valores(_pantalla._enemies),
		"turno": _pantalla._aliados.find(_pantalla._player), "log": _cola_log(), "fin": _pantalla._state == _pantalla.State.FINISHED,
		"rev": _rev, "vel": _pantalla._vel_pelea}


func _cola_log() -> String:
	var lineas: PackedStringArray = _pantalla._log.text.split("\n")
	if lineas.size() <= _LOG_COLA_ESPEJO:
		return _pantalla._log.text
	return "\n".join(lineas.slice(lineas.size() - _LOG_COLA_ESPEJO))


# Lo que cambia de un combatiente entre instantaneas: sus tres barras y sus ESTADOS. Los estados van
# como pares [texto, tooltip] ya resueltos (ver _chips_de): en el espejo no hay motor de estados, y
# sin esto los debuffs de los demas eran invisibles alli.
#
# Y LOS MAXIMOS. Antes solo viajaban en el ROSTER (una vez, al montar la pelea), asi que el espejo se
# quedaba congelado con el maximo del principio: en cuanto alguien lanzaba Guardia de carne -que
# DUPLICA max_hp en vivo- uno veia "130/150" y el otro "130/75", con la barra roja desbordada. Son
# tres numeros mas por combatiente y ahorran una clase entera de desincronizacion.
func _valores(lista: Array, aliados: bool = false) -> Array:
	var out: Array = []
	for c in lista:
		# Los campos 8 y 9 son las CARGAS DE FOCO y los COOLDOWNS. Van aqui y no en el roster porque
		# cambian turno a turno (se ganan y se gastan peleando), igual que la vida. Son las otras dos
		# puertas que mira la barra de habilidades, y sin ellas el espejo pintaba habilitado lo que el
		# anfitrion iba a rechazar -> salia un BASICO. Era el "uso una habilidad y se tira un basico".
		#
		# Los cooldowns van por RUTA y solo los que estan corriendo: casi siempre es un dict vacio, asi
		# que no engorda el paquete en el caso normal.
		# El campo 9, solo de ALIADOS: los numeros de su ficha de detalle (ver CombateDetalle.numeros_aliado).
		# El maniqui del espejo no tiene de donde sacarlos y pintaba "Defensa 0" aunque peleara con la suya.
		out.append([c.current_hp, c.current_mp, c.current_energy, _pantalla.efectos._chips_de(c),
			c.max_hp, c.max_mp, c.max_energy, c.foco_cargas, _cds_activos(c),
			CombateDetalle.numeros_aliado(c) if aliados and not _pantalla._espejo else []])
	return out


# ESPEJO: los numeros de la ficha de detalle de un aliado tal como los calculo quien ejecuta la pelea.
var _numeros_espejo: Dictionary = {}

func numeros_de(c: Combatant) -> Array:
	return _numeros_espejo.get(c, [])


# Los cooldowns que estan CORRIENDO, por ruta. Los de 0 no se mandan: en el caso normal esto es un
# dict vacio y no engorda la instantanea, que sale en cada repintado.
func _cds_activos(c: Combatant) -> Dictionary:
	var out: Dictionary = {}
	for ab in c.ability_cooldowns:
		var turnos: int = int(c.ability_cooldowns[ab])
		if turnos > 0 and ab != null and not String(ab.resource_path).is_empty():
			out[String(ab.resource_path)] = turnos
	return out


# Corre en el ESPEJO: vuelca los numeros recibidos en sus combatientes de escaparate y repinta.
func aplicar_instantanea(snap: Dictionary) -> void:
	if not _pantalla._espejo:
		return
	# ¿Me he perdido un ALTA? (un refuerzo enemigo, un aliado que se unio, una invocacion). La
	# instantanea solo trae numeros, asi que sin esto las filas de mas se descartaban EN SILENCIO
	# -era el bug de "no veo los enemigos que se añaden"-. La revision lo delata y pido el roster
	# entero UNA vez; mientras llega, los numeros que si cuadran se siguen pintando.
	# LA VELOCIDAD LA MANDA EL DUEÑO. Aqui no se elige: se obedece, y por eso el boton va apagado en
	# el espejo. Asi las dos pantallas van al mismo ritmo y nadie ve un turno resuelto mientras el
	# otro lo sigue animando.
	var vel: float = float(snap.get("vel", _pantalla._vel_pelea))
	if not is_equal_approx(vel, _pantalla._vel_pelea):
		_pantalla._aplicar_velocidad(vel)
	var rev: int = int(snap.get("rev", _rev))
	if rev != _rev and not _rev_pedida:
		_rev_pedida = true
		Net.peleas.pedir_roster_pelea()
	_volcar(_pantalla._aliados, snap.get("a", []))
	_volcar(_pantalla._enemies, snap.get("e", []))
	_apagar_caidos()
	var t: int = int(snap.get("turno", -1))
	if t >= 0 and t < _pantalla._aliados.size():
		_pantalla._player = _pantalla._aliados[t]
	if snap.has("log"):
		_pantalla._log.text = String(snap["log"])
	if bool(snap.get("fin", false)):
		_pantalla._state = _pantalla.State.FINISHED
		# Igual que en _end(): visible Y habilitado Y con su texto. Solo poner 'visible' no bastaba
		# si el boton venia deshabilitado de antes: se veia el "Continuar" pero no se podia pulsar.
		_pantalla._continue_button.visible = true
		_pantalla._continue_button.disabled = false
		_pantalla._continue_button.text = "Continuar"
		_pantalla._ocultar_cajas()
	_pantalla._update_hp()


# --- TRASPASO DE LA PELEA (hito 5.4-C) -------------------------------------------------------
#
# La pelea la EJECUTA una maquina. Si esa se va (su jugador huye, o se le corta la conexion) la
# pelea NO se cierra: se TRASPASA a otro que este dentro y sigue donde estaba.
#
# La clave para que esto no sea un monstruo: casi todo el Combatant es DERIVADO (sale de la ficha
# y del equipo, o del EnemyData), asi que el que la recoge lo RECONSTRUYE con el camino de siempre
# —start_combat + unir_aliado_al_combate— y aqui solo viaja lo VOLATIL, lo que no se puede deducir:
# vida, mana, aguante, estados, cargas, cooldowns, imbuicion, barras de ATB y conjuros a medias.

# Lo que lleva un combatiente encima y no se puede reconstruir de su ficha.
func _volatil(c: Combatant) -> Dictionary:
	var estados: Array = []
	for e in c.statuses:
		estados.append([e.id(), e.turns, e.stacks, e.magnitude, e.mult_override, e.fresh])
	var cds: Dictionary = {}
	for ab in c.ability_cooldowns:
		if ab != null and not String(ab.resource_path).is_empty():
			cds[String(ab.resource_path)] = int(c.ability_cooldowns[ab])
	# El FOCO tambien: se gana y se gasta dentro de la pelea, asi que no se puede deducir de la ficha
	# —que es el criterio de esta funcion— y sin el, traspasar la pelea le regalaba al que la recoge
	# las cargas que ya tenia puestas (o se las quitaba). Faltaba desde siempre; se vio tirando del
	# hilo del "uso una habilidad y sale un basico", que era este mismo campo por otra puerta.
	# COBERTURA: los turnos y A QUIEN, como INDICE en _aliados y nunca como referencia -- igual que
	# hace el casteo con su destinatario unas lineas mas abajo. Un Combatant no cruza la red; lo que
	# no se copia campo a campo se pierde SOLO en multi, y en silencio.
	# El re-enlace no se puede hacer aqui: al reconstruir el aliado 0 su protector puede no existir
	# todavia. Lo cierra _reenlazar_coberturas, en una segunda pasada. Ver retomar().
	return {"hp": c.current_hp, "mp": c.current_mp, "en": c.current_energy, "foco": c.foco_cargas,
		"provocar": c.provocar_turnos, "estados": estados, "cd": cds,
		"cubre": [_pantalla._aliados.find(c.protegiendo_a) if c.protegiendo_a != null else -1,
			c.proteger_turnos],
		"carga": [String(c.charging.resource_path) if c.charging != null else "", c.charge_left],
		"imbue": [c.imbue_elemento, c.imbue_pct, c.imbue_usos, c.imbue_cuerpo,
			c.imbue_estado, c.imbue_prob, c.imbue_prob_doble, c.imbue_por_destreza]}


func _aplicar_volatil(c: Combatant, v: Dictionary) -> void:
	if c == null or v.is_empty():
		return
	c.current_hp = float(v.get("hp", c.current_hp))
	c.current_mp = float(v.get("mp", c.current_mp))
	c.current_energy = float(v.get("en", c.current_energy))
	c.foco_cargas = int(v.get("foco", c.foco_cargas))
	c.provocar_turnos = int(v.get("provocar", 0))
	# COBERTURA: aqui solo se apunta el indice en bruto; el puntero lo cierra _reenlazar_coberturas
	# cuando ya estan todos montados. Se guarda EN EL DICT y no en el Combatant para no dejar un
	# campo a medias en el que la redireccion pueda creerse.
	var cub: Array = v.get("cubre", [-1, 0])
	if cub.size() >= 2 and int(cub[1]) > 0 and int(cub[0]) >= 0:
		_pantalla._cobertura_pendiente[c] = int(cub[0])
		c.proteger_turnos = int(cub[1])
	else:
		_pantalla.objetivos._romper_cobertura(c)
	c.statuses.clear()
	for e in v.get("estados", []):
		var def: Dictionary = StatusEffects.def(int(e[0]))
		if def.is_empty():
			continue
		var inst := StatusEffects.Instance.new(def, int(e[1]), int(e[2]))
		inst.magnitude = float(e[3])
		inst.mult_override = float(e[4])
		inst.fresh = bool(e[5])
		c.statuses.append(inst)
	c.ability_cooldowns.clear()
	for ruta in v.get("cd", {}):
		var ab = load(String(ruta))
		if ab != null:
			c.ability_cooldowns[ab] = int(v["cd"][ruta])
	var carga: Array = v.get("carga", ["", 0])
	c.charging = load(String(carga[0])) if String(carga[0]) != "" else null
	c.charge_left = int(carga[1])
	var imb: Array = v.get("imbue", [])
	if imb.size() >= 6:
		c.imbue_elemento = int(imb[0])
		c.imbue_pct = float(imb[1])
		c.imbue_usos = int(imb[2])
		c.imbue_cuerpo = bool(imb[3])
		c.imbue_estado = int(imb[4])
		c.imbue_prob = float(imb[5])
		# Los dos escalones y el escalado por Destreza (imbuicion de ARMA). Si no viajaran, tras un
		# traspaso de anfitrion el veneno de la daga se quedaria en un solo escalon y medido por
		# Magia -- o sea, en nada, porque un picaro no tiene Magia.
		if imb.size() >= 8:
			c.imbue_prob_doble = float(imb[6])
			c.imbue_por_destreza = bool(imb[7])
		# Y la AFINIDAD, que es la mitad de un manto (resistencias, inmunidades, aturdimiento).
		# Sin esto, quien llevara un Manto y sufriera un traspaso de anfitrion perdia todo el lado
		# defensivo aunque el chip siguiera diciendo 🛡: solo le quedaba el bonus de daño.
		if c.imbue_cuerpo and c.imbue_usos > 0:
			c.elemento = c.imbue_elemento
			c.elemento_intensidad = Elementos.INTENSIDAD_IMBUIDO
		else:
			c.elemento = Elementos.Elemento.NINGUNO
			c.elemento_intensidad = Elementos.INTENSIDAD_PURA


# LA FOTO de la pelea para el que la recoge. 'nuevo' es su peer: sus personajes los pone EL de su
# propio equipo (son suyos de verdad), asi que de esos solo viaja lo volatil, no la ficha.
# Los personajes del que SE VA no van: se retira de la pelea, es justo lo que esta haciendo.
func estado_para_traspaso(nuevo: int) -> Dictionary:
	var als: Array = []
	for c in _pantalla._aliados:
		var dueno: int = int(_pantalla._dueno_aliado.get(c, 0))
		if dueno == 0 or _pantalla._huidos.has(c):
			continue   # los mios (me voy) y los que ya habian huido no siguen en la pelea
		var fila: Dictionary = {"dueno": dueno, "mio": dueno == nuevo, "vol": _volatil(c),
			"gauge": float(_pantalla._gauge.get(c, 0.0)), "lentas": int(_pantalla._lentas.get(c, 0)),
			"defendiendo": bool(_pantalla._defendiendo.get(c, false)), "nombre": c.nombre}
		if dueno != nuevo:
			# De los TERCEROS hace falta la ficha entera: el que recoge tiene que montarles un
			# doble, igual que hace hoy quien recibe a alguien que se une.
			var pj: PersonajeData = Game.pj_de_combatant(c)
			if pj != null:
				Game.volcar_desgaste_en_ficha(pj)
				fila["ficha"] = Net.partida.ficha_a_dict(pj)
		if _pantalla._casteos.has(c):
			# El tercer campo es A QUIEN va (indice en _aliados; -1 = a si mismo): un conjuro de
			# los que caen sobre un aliado dura 2-3 turnos y puede pillar el traspaso a medias.
			var dest = _pantalla._casteos[c].get("aliado")
			# El CUARTO es 'pagado' (el conjuro que alguien se trajo ya recitado del mapa): sin el, al
			# cambiar de anfitrion se le volveria a cobrar el maná al soltarlo.
			fila["casteo"] = [String((_pantalla._casteos[c]["spell"] as SpellData).resource_path),
				int(_pantalla._casteos[c]["idx"]), _pantalla._aliados.find(dest) if dest != null else -1,
				bool(_pantalla._casteos[c].get("pagado", false))]
		als.append(fila)
	var ens: Array = []
	for i in _pantalla._enemies.size():
		var e: Combatant = _pantalla._enemies[i]
		var nodo = Game._active_enemies[i] if i < Game._active_enemies.size() else null
		if not is_instance_valid(nodo) or not nodo.has_meta("net_id"):
			continue   # sin net_id no hay forma de que el otro sepa de que bicho hablo
		ens.append({"net_id": int(nodo.get_meta("net_id")), "vivo": e.is_alive(),
			"invocado": _pantalla._slots_invocados.has(i), "vol": _volatil(e),
			"gauge": float(_pantalla._gauge.get(e, 0.0))})
	return {"aliados": als, "enemigos": ens, "log": _pantalla._log.text}


# Corre en EL QUE RECOGE la pelea, con la pantalla ya montada por el camino de siempre: le vuelca
# encima lo volatil de la pelea vieja. 'cs' son los combatientes de esta pantalla en el MISMO orden
# que estado.aliados; 'filas_e' las filas de los enemigos que SI han venido (los vivos), en el
# orden en que se le pasaron a start_combat, o sea el de _enemies.
func retomar(estado: Dictionary, cs: Array, filas_e: Array) -> void:
	var als: Array = estado.get("aliados", [])
	for i in mini(cs.size(), als.size()):
		var c: Combatant = cs[i]
		if c == null:
			continue
		var fila: Dictionary = als[i]
		_aplicar_volatil(c, fila.get("vol", {}))
		_pantalla._gauge[c] = float(fila.get("gauge", 0.0))
		if int(fila.get("lentas", 0)) > 0:
			_pantalla._lentas[c] = int(fila["lentas"])
		if bool(fila.get("defendiendo", false)):
			_pantalla._defendiendo[c] = true
		# Un conjuro A MEDIAS no se pierde por cambiar de maquina: se sigue por la frase que iba.
		if fila.has("casteo"):
			var sp = load(String(fila["casteo"][0]))
			if sp != null:
				var cst: Array = fila["casteo"]
				var idest: int = int(cst[2]) if cst.size() > 2 else -1
				_pantalla._casteos[c] = {"spell": sp, "idx": int(cst[1]),
					"aliado": _pantalla._aliados[idest] if idest >= 0 and idest < _pantalla._aliados.size() else null,
					"pagado": bool(cst[3]) if cst.size() > 3 else false}
	# SEGUNDA PASADA: ya estan todos los aliados montados, asi que ahora los indices de cobertura
	# se pueden convertir en punteros. Antes no: al reconstruir el primero, su protector todavia
	# no existia.
	_pantalla.objetivos._reenlazar_coberturas()
	for i in mini(_pantalla._enemies.size(), filas_e.size()):
		var e: Combatant = _pantalla._enemies[i]
		_aplicar_volatil(e, filas_e[i].get("vol", {}))
		_pantalla._gauge[e] = float(filas_e[i].get("gauge", 0.0))
		if bool(filas_e[i].get("invocado", false)):
			_pantalla._slots_invocados[i] = true   # los invocados no dan kill ni maná: la marca viaja
	_rev += 1
	_pantalla._set_log("Tomas el relevo de la pelea. " + String(estado.get("log", "")).split("\n")[-1])
	_pantalla._update_hp()
	_pantalla._update_timeline()


# --- TURNOS COMPARTIDOS (hito 5.4-C) ---------------------------------------------------------

# En que hueco de la fila esta un aliado (-1 si no esta). El indice es el idioma comun entre las dos
# maquinas: por el se dice de quien es el turno y a quien apunta un objeto.
func indice_de_aliado(c: Combatant) -> int:
	return _pantalla._aliados.find(c)


# Apunta que ese aliado es de otro humano: cuando le toque, se le pedira a el la accion.
func marcar_dueno(c: Combatant, peer: int) -> void:
	if c != null and peer != 0:
		_pantalla._dueno_aliado[c] = peer


# Corre en EL ESPEJO: me toca mover a mi personaje. Se enseña la barra de acciones de siempre.
func turno_mio(idx: int, seq: int = 0) -> void:
	if not _pantalla._espejo or idx < 0 or idx >= _pantalla._aliados.size():
		return
	# YA CONTESTE A ESTA MISMA PETICION. Es el reenvio del heartbeat cruzandose con mi respuesta:
	# el anfitrion todavia no la ha procesado y me repite lo mismo. Volver a pintar la barra de
	# acciones aqui era el origen del turno robado (ver _pet_seq): el jugador elegia por segunda vez
	# y esa segunda respuesta acababa consumiendo el turno de otro. Con el numero se reconoce el eco.
	if seq != 0 and seq == _seq_contestada:
		_pantalla._traza_add("me repiten la #%d, que YA conteste: la ignoro" % seq)
		return
	if seq != 0:
		_seq_espejo = seq
	# REPETICION del anfitrion (ver _heartbeat_remoto): si YA estoy eligiendo para este mismo
	# personaje, no se toca nada — resetear los menus a media eleccion seria peor que el bug. Si en
	# cambio ya habia contestado (o nunca me llego el turno), esto lo recupera.
	if _pantalla._state == _pantalla.State.WAITING_PLAYER and _pantalla._player == _pantalla._aliados[idx]:
		return
	_pantalla._traza_add("ME TOCA (#%d) con %s" % [seq, _pantalla._aliados[idx].nombre])
	_pantalla._player = _pantalla._aliados[idx]
	# El maniqui solo trae lo que se PINTA, asi que no tiene ni habilidades ni hechizos y los
	# submenus salian vacios ("solo deja hacer basicos"). Se los pongo desde MI PROPIA ficha —la de
	# ESTE hueco, que puede ser mi lider o un acompañante mio—: aqui solo sirven para ELEGIR, quien
	# lo resuelve es el anfitrion. La vida, el mana y la energia NO se tocan: manda su instantanea.
	var mio: PersonajeData = Net.peleas.mi_pj_en_pelea(idx)
	var real: Combatant = Game.crear_player_combatant(mio) if mio != null else null
	if real != null:
		_vestir_maniqui(_pantalla._player, real)
	_pantalla._state = _pantalla.State.WAITING_PLAYER
	_pantalla._mostrar_acciones()


# ESPEJO: le pone al maniqui todo lo que la barra de acciones necesita para ELEGIR, copiado del
# combatiente de VERDAD (el que monta Game.crear_player_combatant con mi ficha y mi equipo).
#
# TODO LO QUE LOS MENUS CONSULTEN VA AQUI. El maniqui nace con lo minimo (ver _maniqui_de_fila) y
# cada campo que falte no da error: devuelve su valor por defecto y MIENTE en silencio. Asi se
# perdio el DUAL — sin `ability_hands`, ability_hand_indices devuelve [0] y toda la pantalla se
# calculaba a UNA mano: Rafaga a 48 EN en vez de 70, el tooltip con 2 golpes en vez de 4, y la
# puerta de energia dejando pulsar con 48 (el anfitrion la rechazaba y la pelea se quedaba colgada).
#
# La vida, el mana y la energia NO se tocan: de eso manda la instantanea del anfitrion.
func _vestir_maniqui(m: Combatant, real: Combatant) -> void:
	m.abilities_combate = real.abilities_combate
	m.spells = real.spells
	m.magic_amp = real.magic_amp
	m.mana_reduccion = real.mana_reduccion
	# Las MANOS del loadout (dual): set_hands va ANTES de motion_value porque activa la mano 0 y
	# pisa motion_value/ataque_arma/etc. con los de esa mano (que es la principal: mismo valor).
	m.set_hands(real.hands)
	m.ability_hands = real.ability_hands
	m.motion_value = real.motion_value
	# LAS CARGAS DE FOCO Y LOS COOLDOWNS NO SE COPIAN DE AQUI, y es a proposito.
	#
	# 'real' es un Combatant recien creado con la ficha, o sea que su foco vale 0 y su tabla de
	# cooldowns esta VACIA (crear_player_combatant no los siembra: los pone start_combat /
	# unir_aliado_al_combate despues). Copiarlos de aqui no era medio arreglo, era pintar ceros:
	# el espejo enseñaba TODAS las habilidades listas, pulsabas una que en el anfitrion estaba en
	# cooldown, y alli se rechazaba y salia un BASICO. El mismo agujero que el dual y que el foco,
	# tres veces seguidas y siempre igual: un campo que el maniqui no tiene devuelve su valor por
	# defecto y MIENTE en silencio.
	#
	# Los dos se ganan y se gastan DENTRO de la pelea, asi que cambian turno a turno: viajan en la
	# INSTANTANEA, como la vida (ver _valores, campos 8 y 9).


# LE PIDO ALGO A UN REMOTO (su turno, una frase, el disparo) y me quedo esperando. Se recuerda QUE
# le pedi para poder REPETIRSELO si no contesta: ver _heartbeat_remoto. Un turno remoto perdido
# congelaba la pelea entera para todos.
func _pedir_a_remoto(dueno: int, pet: Dictionary) -> void:
	_pantalla._esperando_a = dueno
	# CADA peticion lleva su numero. Es lo que permite luego distinguir su respuesta de una respuesta
	# rezagada a algo que le pedi antes (ver _pet_seq y aplicar_accion_remota).
	_pet_seq += 1
	pet["seq"] = _pet_seq
	_peticion_pendiente = pet
	_espera_acum = 0.0
	_pantalla._traza_add("PIDO #%d '%s' al peer %d (para %s)" % [
		_pet_seq, String(pet.get("tipo", "?")), dueno,
		_pantalla._player.nombre if _pantalla._player != null else "?"])
	_enviar_peticion()


func _enviar_peticion() -> void:
	if _pantalla._esperando_a == 0 or _peticion_pendiente.is_empty():
		return
	var pet: Dictionary = _peticion_pendiente
	var seq: int = int(pet.get("seq", 0))
	match String(pet.get("tipo", "")):
		"accion":
			Net.peleas.pedir_accion(_pantalla._esperando_a, int(pet.get("idx", 0)), seq)
		"frase":
			Net.peleas.pedir_frase(_pantalla._esperando_a, int(pet.get("idx", 0)), pet.get("opciones", []),
				String(pet.get("nombre", "")), int(pet.get("largo", 1)), seq)
		"disparo":
			Net.peleas.pedir_disparo(_pantalla._esperando_a, String(pet.get("nombre", "")), seq)
		"soltar":
			Net.peleas.pedir_soltar(_pantalla._esperando_a, String(pet.get("nombre", "")), seq)


# Deja de esperar (llego su respuesta, o se fue).
func _fin_de_espera() -> void:
	_pantalla._esperando_a = 0
	_peticion_pendiente = {}
	_espera_acum = 0.0


# HEARTBEAT: mientras espero a un remoto, le repito la peticion cada REENVIO_TURNO. Si su pantalla
# no llego a mostrarle el turno (o su respuesta se perdio), esto lo despierta; y si ya esta
# eligiendo, el reenvio se ignora al otro lado y no le molesta. Sin esto, cualquier mensaje perdido
# dejaba la pelea muerta: el ATB esta congelado esperando a alguien que no va a contestar.
func _heartbeat_remoto(delta: float) -> void:
	if _pantalla._esperando_a == 0 or _pantalla._state != _pantalla.State.WAITING_PLAYER or _peticion_pendiente.is_empty():
		_espera_acum = 0.0
		return
	_espera_acum += delta
	if _espera_acum < REENVIO_TURNO:
		return
	_espera_acum = 0.0
	# ¿Sigue en la pelea? Si se fue, sus personajes salen y la pelea continua (no se espera a un
	# fantasma). Si sigue, se le repite lo que le pedi.
	if not Net.peleas.esta_en_mi_pelea(_pantalla._esperando_a):
		var quien: int = _pantalla._esperando_a
		_fin_de_espera()
		_pantalla.sacar_a(quien)
		return
	print("[combate] repito la peticion a %d (%s #%d): no ha contestado en %.0f s" % [
		_pantalla._esperando_a, String(_peticion_pendiente.get("tipo", "?")),
		int(_peticion_pendiente.get("seq", 0)), REENVIO_TURNO])
	_pantalla._traza_add("REENVIO #%d '%s' al peer %d (sin respuesta en %.0fs)" % [
		int(_peticion_pendiente.get("seq", 0)), String(_peticion_pendiente.get("tipo", "?")),
		_pantalla._esperando_a, REENVIO_TURNO])
	_enviar_peticion()


# Corre en EL ANFITRION: ha llegado la accion que eligio el dueño. Se ejecuta como si la hubiera
# pulsado aqui, reusando las mismas funciones (asi el combate es UNO, sin reglas paralelas).
func aplicar_accion_remota(accion: Dictionary, emisor: int = 0) -> void:
	var tipo: String = String(accion.get("tipo", "?"))
	if _pantalla._espejo or _pantalla._state != _pantalla.State.WAITING_PLAYER or _pantalla._esperando_a == 0:
		# Descartarla EN SILENCIO era lo que dejaba el turno colgado sin dejar rastro. Ahora se dice,
		# y el heartbeat volvera a pedirsela si de verdad seguimos esperando.
		print("[combate] accion remota IGNORADA (%s): espejo=%s estado=%d esperando_a=%d" % [
			tipo, str(_pantalla._espejo), _pantalla._state, _pantalla._esperando_a])
		_pantalla._traza_add("DESCARTO '%s' del peer %d: no estoy esperando (estado=%d, esperando_a=%d)" % [
			tipo, emisor, _pantalla._state, _pantalla._esperando_a])
		return

	# ¿ME CONTESTA A QUIEN LE PREGUNTE? Antes no se miraba, y eso es lo que convertia una respuesta
	# rezagada en un turno robado: llegaba la de un jugador cuando ya se esperaba a otro, se aplicaba
	# al _player de turno (que era del otro) y se consumia su turno sin que el hubiera elegido nada.
	if emisor != 0 and emisor != _pantalla._esperando_a:
		print("[combate] accion remota IGNORADA (%s): la manda el peer %d y yo espero al %d" % [
			tipo, emisor, _pantalla._esperando_a])
		_pantalla._traza_add("DESCARTO '%s': viene del peer %d y espero al %d (respuesta de otro)" % [
			tipo, emisor, _pantalla._esperando_a])
		return

	# ¿ME CONTESTA A LO QUE LE PREGUNTE, Y NO A LO DE ANTES? El numero de peticion lo distingue: una
	# respuesta con un numero viejo es un eco de un turno ya resuelto y hay que tirarla, no aplicarla.
	var seq_pet: int = int(_peticion_pendiente.get("seq", 0))
	var seq_res: int = int(accion.get("seq", 0))
	if seq_res != 0 and seq_pet != 0 and seq_res != seq_pet:
		print("[combate] accion remota IGNORADA (%s): responde a la #%d y la pendiente es la #%d" % [
			tipo, seq_res, seq_pet])
		_pantalla._traza_add("DESCARTO '%s' del peer %d: responde a #%d y pido la #%d (rezagada)" % [
			tipo, emisor, seq_res, seq_pet])
		return

	# ¿Y ME CONTESTA LO QUE LE PREGUNTE? Un "atacar" retrasado cuando lo pendiente es una FRASE se
	# colaba por el `_:` de mas abajo y se resolvia como un ataque, saltandose el recitado.
	var pendiente: String = String(_peticion_pendiente.get("tipo", ""))
	if not _encaja_con_lo_pedido(tipo, pendiente):
		print("[combate] accion remota IGNORADA (%s): lo pendiente era '%s'" % [tipo, pendiente])
		_pantalla._traza_add("DESCARTO '%s' del peer %d: lo pendiente era '%s' (no encaja)" % [
			tipo, emisor, pendiente])
		return

	_pantalla._traza_add("RECIBO #%d '%s' del peer %d -> la aplico a %s" % [
		seq_res, tipo, emisor, _pantalla._player.nombre if _pantalla._player != null else "?"])
	_fin_de_espera()
	var obj: int = int(accion.get("obj", -1))
	if obj >= 0 and obj < _pantalla._enemies.size():
		_pantalla._target_idx = obj
	match String(accion.get("tipo", "atacar")):
		"defender":
			_pantalla._accion_defender()
		"huir":
			_pantalla._accion_huir()
		"habilidad":
			# Se busca en SU loadout (el doble lleva su mismo equipo): asi nadie puede colar una
			# habilidad que su personaje no tiene.
			var ruta: String = String(accion.get("ruta", ""))
			var elegida: AbilityData = null
			for ab in _pantalla._player.abilities_combate:
				if ab != null and String(ab.resource_path) == ruta:
					elegida = ab
					break
			if elegida != null:
				var ia_h: int = int(accion.get("aliado", -1))
				_pantalla._hab_aliado = _pantalla._aliados[ia_h] if ia_h >= 0 and ia_h < _pantalla._aliados.size() else null
				_pantalla.habilidades._usar_habilidad(elegida)
			else:
				_pantalla._accion_atacar()   # ya no la tiene: no se pierde el turno
		"magia":
			# Empieza a recitar. El hechizo se busca en SU loadout (mismo criterio que las
			# habilidades: nadie puede colar una magia que su personaje no lleva).
			var ruta_s: String = String(accion.get("ruta", ""))
			var hechizo: SpellData = null
			for sp in _pantalla._player.spells:
				if sp != null and String(sp.resource_path) == ruta_s:
					hechizo = sp
					break
			if hechizo != null:
				# El destinatario viaja como indice en _aliados (igual que la pocion). -1 = a si mismo.
				var ia_m: int = int(accion.get("aliado", -1))
				var al_m: Combatant = _pantalla._aliados[ia_m] if ia_m >= 0 and ia_m < _pantalla._aliados.size() else null
				_pantalla.magia._elegir_hechizo(hechizo, al_m)
			else:
				_pantalla._accion_atacar()   # ya no lo lleva: no se pierde el turno
		"frase":
			# Ha respondido al examen de una frase. Quien dice si acerto soy YO: la frase correcta
			# nunca sale de aqui, solo vuelve el texto que eligio.
			if _pantalla._cast_spell == null or _pantalla._cast_index >= _pantalla._cast_spell.longitud():
				return
			_pantalla.magia._responder_frase(String(accion.get("texto", "")), _pantalla._cast_spell.frases[_pantalla._cast_index])
		"cancelar":
			# Se ha echado atras ANTES de recitar nada: el conjuro se cae sin coste y le devuelvo el
			# turno entero. Con una frase ya recitada NO se acepta (solo puede ser un eco: el boton
			# no existe a partir de la segunda).
			if _pantalla._cast_spell == null or _pantalla._cast_index > 0:
				return
			_pantalla.magia._limpiar_casteo()
			_pantalla._update_hp()
			_pantalla._pedir_accion_del_turno()
		"disparar":
			if _pantalla._cast_spell == null:
				return
			_pantalla.magia._disparar_hechizo()
		"soltar":
			# Su carga, con SU objetivo (_target_idx ya viene puesto de accion["obj"], arriba).
			if _pantalla._player.charging == null:
				_pantalla._accion_atacar()   # se la interrumpieron entre medias: no se pierde el turno
			else:
				_pantalla.habilidades._soltar_la_carga()
		"objeto":
			var cons = load(String(accion.get("ruta", "")))
			var ia: int = int(accion.get("aliado", -1))
			var al: Combatant = _pantalla._aliados[ia] if ia >= 0 and ia < _pantalla._aliados.size() else _pantalla._player
			if cons != null:
				_pantalla.objetos._usar_objeto(cons, al, false)   # ya la pago el de su bolsa, aqui solo se resuelve
			else:
				_pantalla._accion_atacar()
		_:
			# Un tipo de accion que esta maquina no conoce. Atacar de basico es lo correcto (no se
			# puede colgar la pelea por eso), pero en silencio era otro "se tira un basico solo" sin
			# rastro: si las dos puntas van con versiones distintas, esto es lo unico que lo delata.
			push_warning("[multi] accion remota de tipo desconocido '%s': ataca de basico"
				% String(accion.get("tipo", "")))
			_pantalla._accion_atacar()


# ¿La respuesta que llega es de la clase de lo que se pidio? Un turno ("accion") admite cualquiera de
# las acciones del menu; una FRASE solo admite la frase, y el DISPARO solo el disparo. Mezclarlos era
# lo que dejaba que un "atacar" rezagado se resolviera en mitad de un recitado.
func _encaja_con_lo_pedido(tipo: String, pendiente: String) -> bool:
	match pendiente:
		# La frase admite tambien el "cancelar": desde el examen de la PRIMERA se puede volver atras.
		"frase":   return tipo in ["frase", "cancelar"]
		"disparo": return tipo == "disparar"
		# Soltar una carga no admite nada mas: ese turno no tiene otra accion posible.
		"soltar":  return tipo == "soltar"
		"accion":  return tipo in ["atacar", "defender", "huir", "habilidad", "magia", "objeto"]
		_:         return true   # peticion sin tipo conocido: no se bloquea nada


# El anfitrion ha cerrado la pelea: mi espejo se va con ella.
func cerrar_espejo() -> void:
	if not _pantalla._espejo:
		return
	_pantalla._state = _pantalla.State.FINISHED
	_pantalla.combat_finished.emit(false, [], [], [], [], [], [], [])


# Manda la foto a los espejos. Se llama tras cada cambio que se VE (un golpe, un turno nuevo, el
# final). Es barata -solo numeros- pero no se manda cada frame: solo cuando algo cambia.
func _difundir() -> void:
	if _pantalla._espejo or not Net.activo:
		return
	Net.peleas.difundir_instantanea(instantanea())


# LA BARRA DE ACCION en los espejos. El ATB corre SOLO aqui, asi que alli los marcadores se
# quedaban clavados donde nacieron: el que entraba segundo veia una barra muerta. No puede ir en la
# instantanea (esa sale solo cuando cambia algo, y la barra iria a saltos), asi que va como las
# POSICIONES de los enemigos: un tick propio a ~20 Hz, sin garantia de entrega —si se pierde uno,
# el siguiente llega en 50 ms y nadie lo nota—.
func _difundir_atb(delta: float) -> void:
	if not Net.activo:
		return
	_atb_acum += delta
	if _atb_acum < ATB_TICK:
		return
	_atb_acum = 0.0
	var r: PackedFloat32Array = PackedFloat32Array()
	for c in _pantalla._aliados:
		r.append(float(_pantalla._gauge.get(c, 0.0)) / _pantalla.UMBRAL)
	for e in _pantalla._enemies:
		r.append(float(_pantalla._gauge.get(e, 0.0)) / _pantalla.UMBRAL)
	Net.peleas.difundir_atb(r)


# --- IMPACTOS PARA EL ESPEJO -----------------------------------------------------------------
# El que espeja la pelea no simula nada: sin esto veria las vidas bajar de golpe, sin embestidas
# ni numeros. Se le manda un paquete por ACCION (no por golpe): se van apuntando los impactos
# segun se resuelven y se sueltan todos juntos al cerrar la accion, JUSTO ANTES del _update_hp
# que difunde la instantanea -- asi alli tambien se ve primero el golpe y despues baja la barra.
#
# Formato: 4 enteros por impacto, y nada mas. Es cosmetico, asi que va por el mismo canal SIN
# GARANTIA que el ATB: un paquete perdido no puede competir con la instantanea ni atascar un turno.
# EL MISMO numero que CombatFX.MAX_EVENTOS, y a proposito: un impacto que el anfitrion ni siquiera
# anima tampoco tiene sentido mandarlo. 40 x 4 x 4 B = 640 B, muy por debajo de la MTU de ENet
# (1392). NO se puede trocear en dos paquetes: aplicar_impactos arranca la cola al terminar de
# leer, asi que un segundo paquete montaria una racha nueva encima de la que ya estaba corriendo.
const MAX_IMPACTOS_RED := CombatFX.MAX_EVENTOS
var _impactos_red: PackedInt32Array = PackedInt32Array()
# La tanda del ultimo impacto apuntado para la red, para saber cuando marcar el bit de "abre tanda".
var _ult_tanda_red := -1


# El codigo de un combatiente dentro del roster: los tuyos tal cual y los de enfrente a partir de
# 100. Mismo orden que usa _difundir_atb (aliados primero), que es el que conoce el espejo.
func _cod_combatiente(c: Combatant) -> int:
	if c == null:
		return -1
	var i: int = _pantalla._aliados.find(c)
	if i >= 0:
		return i
	i = _pantalla._enemies.find(c)
	return 100 + i if i >= 0 else -1


# CADA IMPACTO SON CINCO ENTEROS: atacante, victima, daño x10, flags y SEMILLA DE SONIDO. El
# quinto entro al darle varias versiones a cada sonido: la version y el tono se sortean con esa
# semilla, asi que mandandola el golpe suena identico en todas las pantallas en vez de que cada
# maquina se saque el suyo. En los flags no cabia (estan los 31 bits utiles cogidos), y cambiar el
# paso de 4 a 5 es justo lo que obliga a subir Net.PROTOCOLO: una punta vieja leeria el paquete
# corrido y veria una pelea inventada, sin dar ni un error.
#
# El reparto de bits de 'flags', que hay que leer igual en las dos puntas:
#   0      critico
#   1      evadido
#   2      ABRE TANDA (este golpe empieza una tanda nueva; ver CombatFX.tanda)
#   3-5    elemento + 1  (0..4)
#   6-13   estilo        (CombatFX.Estilo; 8 bits = caben 256)
#   14-20  peso x 64     (0..127 -> 0.00..1.98)
#   21     SOLO DIBUJO   (un adorno, no un golpe: ver CombatFX.encolar)
#   22-30  sonido + 1    (indice en Sonido.CLAVES; 0 = ninguno, suena el generico del estilo)
#   31     -             SIN USAR, y que siga asi: es el bit de signo del Int32 y un indice que lo
#                        pisara llegaria al otro lado como un numero negativo.
#
# EL SONIDO VIAJA POR EL MISMO SITIO QUE EL DIBUJO, y tiene que hacerlo: el estilo solo dice la
# FAMILIA (un chillido), no QUIEN grita, asi que sin el indice el compañero oiria el generico de la
# rata cuando el que berrea es el minotauro. Cabe en los bits que sobraban, sin un quinto entero.
#
# El estilo eran 3 bits (8 estilos justos), se ensancho a 4 al añadir la EXPLOSION, a 6 al entrar
# los mordiscos de la familia ROEDOR y a 8 al darle dibujo propio a CADA arma y CADA habilidad del
# jugador, corriendo el peso a la izquierda cada vez. Con 6 no llegaba ni de lejos: 35 estilos de
# bicho + 10 armas + 59 habilidades son 104, y en 64 no caben. Los 256 de ahora dan de sobra.
# Es un PackedInt32Array, asi que sitio sobra: viajan los mismos
# cuatro enteros por impacto. Si se toca una punta y no la otra NO SALTA NINGUN ERROR: el espejo
# simplemente lee otro estilo y otro peso, y ve la pelea con efectos distintos a los tuyos. Las
# mascaras de cada campo tienen que cuadrar aqui y en aplicar_impactos.
func _apuntar_impacto_red(atacante: Combatant, victima: Combatant, dmg: float,
		crit: bool, evadido: bool, elem: int, estilo: int, peso: float,
		solo_dibujo: bool = false, sfx: String = "", semilla: int = 0) -> void:
	if _pantalla._espejo or not Net.activo or _impactos_red.size() >= MAX_IMPACTOS_RED * 5:
		return
	var ca: int = _cod_combatiente(atacante)
	var cv: int = _cod_combatiente(victima)
	if cv < 0:
		return
	# LA TANDA VIAJA. El espejo reconstruye la cola llamando a _fx_golpe en orden, pero no pasa por
	# los _fx_tanda de la resolucion, asi que sin esto veria un molinete como cuatro golpes sueltos
	# mientras el anfitrion lo ve como un barrido. No hace falta mandar el numero: como el orden se
	# respeta, basta con marcar DONDE empieza cada tanda y que el espejo lleve el contador.
	var t_ev: int = _pantalla._fx.ultima_tanda() if _pantalla._fx != null else -1
	var abre: bool = t_ev != _ult_tanda_red
	_ult_tanda_red = t_ev
	var flags: int = (1 if crit else 0) | (2 if evadido else 0) | (4 if abre else 0) \
		| (((elem + 1) & 7) << 3) | ((estilo & 255) << 6) \
		| (clampi(roundi(peso * 64.0), 0, 127) << 14) \
		| (2097152 if solo_dibujo else 0) \
		| (((Sonido.CLAVES.find(sfx) + 1) & 511) << 22)
	_impactos_red.append(ca)
	_impactos_red.append(cv)
	_impactos_red.append(roundi(minf(dmg, 3000.0) * 10.0))   # x10: un decimal, y cabe en el int
	_impactos_red.append(flags)
	_impactos_red.append(semilla)


# Suelta lo apuntado. Se llama al cerrar CADA accion (la del enemigo en _pausa_lectura, la tuya en
# _tras_accion_jugador_varios, y la que remata la pelea en _end). Nunca desde _process: es como
# mucho un paquete por turno.
func _soltar_impactos_red() -> void:
	if _impactos_red.is_empty():
		return
	if not _pantalla._espejo and Net.activo:
		Net.peleas.difundir_impactos(_impactos_red)
	_impactos_red = PackedInt32Array()
	_ult_tanda_red = -1   # la accion se ha ido: la siguiente vuelve a empezar por su tanda 0


# Corre en el ESPEJO: reproduce los golpes que acaba de resolver el anfitrion. Solo pinta -- no
# toca _state ni _pause_left, que aqui no existen (el espejo retorna al principio de _process).
func aplicar_impactos(datos: PackedInt32Array) -> void:
	if not _pantalla._espejo or _pantalla._fx == null:
		return
	var j: int = 0
	var tanda: int = -1
	while j + 4 < datos.size():
		var ca: int = datos[j]
		var cv: int = datos[j + 1]
		var dmg: float = float(datos[j + 2]) / 10.0
		var flags: int = datos[j + 3]
		var semilla: int = datos[j + 4]
		j += 5
		# El bit de "abre tanda" se lee SIEMPRE, aunque la victima ya no exista en esta pantalla:
		# el contador tiene que seguir el mismo compas que el del anfitrion pase lo que pase.
		if (flags & 4) != 0:
			tanda += 1
		var victima: Combatant = _de_codigo(cv)
		if victima == null:
			continue
		_pantalla.efectos._fx_tanda(maxi(0, tanda))
		# Con MASCARA en cada campo: sin ella, el elemento se leia con los bits del estilo y del
		# peso pegados detras y salia un numero absurdo.
		_pantalla.efectos._fx_golpe(_de_codigo(ca), victima, dmg, (flags & 1) != 0, (flags & 2) != 0,
			((flags >> 3) & 7) - 1, (flags >> 6) & 255, float((flags >> 14) & 127) / 64.0,
			(flags & 2097152) != 0, Sonido.clave_de((flags >> 22) & 511),
			# El gesto y la animacion van por su valor de siempre (no viajan: el Combatant del
			# atacante ya los trae). La SEMILLA si viaja, y se pasa TAL CUAL: es lo que hace que
			# el golpe suene con la misma version y el mismo tono que en la pantalla del que pega.
			AbilityData.Gesto.AUTO, &"", semilla)
	_pantalla._fx.arrancar_cola()


func _de_codigo(cod: int) -> Combatant:
	if cod < 0:
		return null
	if cod >= 100:
		var i: int = cod - 100
		return _pantalla._enemies[i] if i < _pantalla._enemies.size() else null
	return _pantalla._aliados[cod] if cod < _pantalla._aliados.size() else null


# Corre en el ESPEJO: los avances que me manda el anfitrion, en el orden del roster (los mios
# primero y detras los de enfrente). _update_timeline ya los pinta desde _gauge en cada frame.
func aplicar_atb(ratios: PackedFloat32Array) -> void:
	if not _pantalla._espejo:
		return
	var n: int = _pantalla._aliados.size()
	for i in mini(n, ratios.size()):
		_fijar_objetivo_atb(_pantalla._aliados[i], float(ratios[i]) * _pantalla.UMBRAL)
	for i in mini(_pantalla._enemies.size(), ratios.size() - n):
		_fijar_objetivo_atb(_pantalla._enemies[i], float(ratios[n + i]) * _pantalla.UMBRAL)


# Guarda el destino de la barra de un combatiente. El primer valor se pone TAL CUAL (que la barra
# aparezca ya donde va, sin subir desde 0 al entrar); a partir de ahi _interpolar_atb_espejo la
# acerca suave. Mismo espiritu que remote_player.ir_a con su primer paquete.
func _fijar_objetivo_atb(c, valor: float) -> void:
	_gauge_objetivo[c] = valor
	if not _pantalla._gauge.has(c):
		_pantalla._gauge[c] = valor


# ESPEJO: acerca cada barra a su objetivo, un lerp exponencial por frame (tapa el hueco entre los
# paquetes de 20 Hz). Corre en _process ANTES de pintar la linea de tiempo.
func _interpolar_atb_espejo(delta: float) -> void:
	if delta <= 0.0:
		return
	var t: float = 1.0 - exp(-SUAVIZADO_ATB * delta)
	for c in _gauge_objetivo:
		_pantalla._gauge[c] = lerpf(float(_pantalla._gauge.get(c, 0.0)), float(_gauge_objetivo[c]), t)


func _volcar(lista: Array, valores: Array) -> void:
	for i in mini(lista.size(), valores.size()):
		var v: Array = valores[i]
		lista[i].current_hp = float(v[0])
		lista[i].current_mp = float(v[1])
		lista[i].current_energy = float(v[2])
		if v.size() > 3:
			_chips_espejo[lista[i]] = v[3]
		# Los MAXIMOS, si el paquete los trae (un compañero con una version anterior no los manda, y
		# entonces se dejan como estaban en vez de ponerlos a cero y borrarle las barras).
		if v.size() > 6:
			lista[i].max_hp = float(v[4])
			lista[i].max_mp = float(v[5])
			lista[i].max_energy = float(v[6])
		# Las cargas de FOCO: es lo que decide si el boton de otra habilidad de Foco sale apagado.
		if v.size() > 7:
			lista[i].foco_cargas = int(v[7])
		# Y los COOLDOWNS, que son la otra puerta. Se reconstruyen enteros en vez de fusionar: lo que
		# no viene en el paquete es que ya no esta corriendo, y dejarlo puesto apagaria un boton que
		# el anfitrion ya considera listo.
		if v.size() > 9 and not (v[9] as Array).is_empty():
			_numeros_espejo[lista[i]] = v[9]
		if v.size() > 8:
			lista[i].ability_cooldowns.clear()
			for ruta in (v[8] as Dictionary):
				var ab = load(String(ruta))
				if ab != null:
					lista[i].ability_cooldowns[ab] = int((v[8] as Dictionary)[ruta])


# ESPEJO: los que han caido en la instantanea se apagan aqui igual que en la pantalla que ejecuta.
# Alli lo hacen _apagar_bloque y _caer_aliado desde el motor; aqui no hay motor, solo numeros, asi
# que se mira quien esta a 0 y se le apaga el bloque y se le quita del marcador de turnos. Sin esto
# el espejo dejaba cadaveres pintados como vivos.
func _apagar_caidos() -> void:
	for i in _pantalla._bloques.size():
		if i >= _pantalla._enemies.size() or _pantalla._enemies[i].is_alive():
			continue
		_pantalla.altas._apagar_bloque(_pantalla._enemies[i])
		if _pantalla._timeline != null:
			_pantalla._timeline.quitar(_pantalla._enemies[i])
	for i in _pantalla._bloques_aliados.size():
		if i >= _pantalla._aliados.size() or _pantalla._aliados[i].is_alive():
			continue
		_pantalla.altas._apagar_diferido(_pantalla._bloques_aliados[i], true)
		if _pantalla._timeline != null:
			_pantalla._timeline.quitar(_pantalla._aliados[i])


# En el ESPEJO las acciones no se resuelven aqui: se le mandan al anfitrion, que es quien lleva la
# pelea. Devuelve true si ya se ha enviado (y por tanto hay que salir sin hacer nada mas).
func _enviar_si_espejo(tipo: String) -> bool:
	if not _pantalla._espejo:
		return false
	_responder_al_anfitrion({"tipo": tipo, "obj": _pantalla._target_idx})
	return true


# LA UNICA PUERTA DE SALIDA de las respuestas del espejo. Todas pasan por aqui para que ninguna se
# olvide de dos cosas: sellar la respuesta con el numero de lo que me pidieron, y APUNTAR que ya
# conteste a ese numero. Lo segundo es lo que hace que un reenvio del anfitrion no me vuelva a poner
# los botones de un turno que ya jugue (ver turno_mio y _pet_seq).
func _responder_al_anfitrion(accion: Dictionary) -> void:
	accion["seq"] = _seq_espejo
	_seq_contestada = _seq_espejo
	_pantalla._ocultar_cajas()
	_pantalla._state = _pantalla.State.ADVANCING
	_pantalla._traza_add("CONTESTO #%d '%s'" % [_seq_espejo, String(accion.get("tipo", "?"))])
	Net.peleas.enviar_accion(accion)
