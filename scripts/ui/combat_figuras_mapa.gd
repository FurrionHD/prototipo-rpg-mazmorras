# ============================================================
#  combat_figuras_mapa.gd  (tema de la pantalla de combate: combat.figuras_mapa)
#  LAS FICHAS, CUANDO SE PELEA EN EL MAPA: cada tarjeta deja de estar en una fila y pasa a flotar
#  SOBRE SU CUERPO, el de verdad, el que anda por la mazmorra.
#
#  LA IDEA, Y POR QUE ASI. La tentacion es montar tarjetas nuevas para el mapa. Seria un error: la
#  tarjeta de combat_figuras no es una caja con un numero, es el sitio del que cuelgan la barra de
#  vida, los chips de estado, el tinte de cadaver, el borde de seleccion, el cursor de objetivo, las
#  embestidas de CombatFX y el clic que elige objetivo. Todo eso ya funciona y esta probado.
#
#  Asi que aqui NO se construye nada: se MUDAN las que ya hizo el montaje de siempre. Se sacan de su
#  banda, se cuelgan de una capa suelta y cada fotograma se les pone la posicion de su cuerpo. El
#  resto de la pantalla (_update_hp, los chips, las altas, los efectos) sigue encontrandose los
#  mismos _bloques de siempre y no se entera de nada.
#
#  Y SE LES QUITA EL HUECO DEL SPRITE, que en la fila reservaba 208 px para dibujar al bicho. Aqui el
#  bicho ya esta dibujado: es el que anda por el mapa. Lo que flota es solo la ficha.
#
#  QUE FLOTA Y QUE NO (decidido mirando como lo hacen los Trails):
#    TUS PERSONAJES     nada. Sus barras se leen ARRIBA, en la fila del grupo del HUD del mapa (ver
#                       player._rehacer_barras), que ya las pinta. Tenerlas en los dos sitios era
#                       pintar lo mismo dos veces, y una de las dos copias tapaba la pelea.
#    LOS ENEMIGOS       una barrita de vida y ya: sin panel, sin nombre, sin cifras. Con siete
#                       combatientes en un corro de dos celdas, una tarjeta entera por cabeza no cabe
#                       ni encogida.
#    EL APUNTADO        ese SI, entero: nombre, numero, HP con cifras y chips a tamaño normal. Es al
#                       unico al que estas mirando cuando eliges, y es donde hace falta el detalle.
# ============================================================
extends RefCounted

const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# Lo que se deja de aire entre la cabeza del cuerpo y la ficha que lo rotula.
const SOBRE_LA_CABEZA := 12.0
# Cuanto se levanta la ficha respecto al origen del cuerpo. Los cuerpos tienen el origen en los PIES
# (la huella de colision va abajo, ver player.tscn), asi que sin esto la ficha saldria por la cintura.
const ALTO_CUERPO := 52.0

# --- EL MODO MINI -------------------------------------------------------------------------------
# LA BARRA MIDE LO QUE MIDE EL BICHO. No un ancho fijo: una rata y el Rey Slime no pueden llevar la
# misma barra, porque lo que dice de un vistazo cual es la de cada uno es estar a su medida. El
# ancho sale de su forma de colision, que enemy._aplicar_colision ya deja a la medida del cuerpo, y
# se pasa a pixeles de PANTALLA con la escala de la transformada de canvas (que es el zoom de la
# camara: un bicho lejano tiene la barra mas corta, como debe ser).
const ANCHO_CUERPO_POR_DEFECTO := 32.0   # los que no declaran forma (todavia son un ColorRect)
# Y un suelo, porque una barra de 12 px no se lee ni se puede pulsar.
const ANCHO_MINI_MIN := 28.0
const ALTO_BARRA_MINI := 5.0
# El hueco de los chips, y a que escala se dibujan dentro. Se escala el ENVOLTORIO en vez de tocar
# StatusChip.crear porque los chips se borran y se rehacen en CADA _update_hp (ver
# combat_efectos._refrescar_chips): lo que se le haga a un chip suelto no dura ni un golpe.
const ALTO_CHIPS_MINI := 14.0
const ESCALA_CHIPS_MINI := 0.7

var _capa: Control = null
var _fichas: Array = []   # [{bloque: Dictionary, cuerpo: Node2D}]


# Muda todas las fichas al mapa. Se llama DESPUES del _setup_ui de siempre: para entonces los
# bloques ya existen, con su numero, su barra y sus chips.
func montar() -> void:
	_capa = Control.new()
	_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# La capa no atrapa nada, pero sus hijos si: el clic que elige objetivo sigue siendo de la
	# tarjeta, como en la fila.
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.clip_contents = false
	_capa.process_mode = Node.PROCESS_MODE_ALWAYS
	_pantalla.add_child(_capa)

	for i in _pantalla._bloques.size():
		_mudar(_pantalla._bloques[i], _cuerpo_enemigo(i))
	# LOS ALIADOS NO SE MUDAN: sus barras salen arriba, no debajo suyo. Sus columnas se quedan donde
	# las dejo el montaje, dentro de una banda con visible=false, asi que siguen existiendo enteras:
	# _update_hp, _refrescar_chips y las altas a media pelea se las encuentran igual que siempre y no
	# se enteran de que nadie las mira.
	seguir()


# Recoloca cada ficha sobre su cuerpo. Se llama cada fotograma desde la pantalla: los cuerpos se
# mueven (en su turno, o porque el mundo sigue vivo en multi) y la camara tambien puede.
func seguir() -> void:
	# El TAMAÑO antes que el SITIO: la ficha se coloca centrada sobre el cuerpo usando su ancho y su
	# alto, asi que si va a cambiar de tamaño tiene que hacerlo antes de que se le calcule el sitio.
	refrescar_mini()
	for f in _fichas:
		var col: Control = f["bloque"].get("columna")
		if not is_instance_valid(col):
			continue
		var cuerpo: Node2D = f["cuerpo"]
		if not is_instance_valid(cuerpo):
			# Un cuerpo que ya no esta (murio y se lo llevaron): la ficha se queda donde estaba en vez
			# de saltar a la esquina. Ya se apagara sola por el camino de siempre.
			continue
		# De MUNDO a PANTALLA. La pelea vive en un CanvasLayer, al que la camara de la mazmorra no le
		# afecta; el cuerpo si esta bajo la camara. Esta transformada es la que cruza los dos mundos.
		var p: Vector2 = cuerpo.get_global_transform_with_canvas().origin
		# EL TAMAÑO SE LE IMPONE, no se le pregunta. Un Control suelto se queda con el 'size' que
		# tenia en su fila -- y ahi la columna reservaba 208 px para el sprite del bicho. Aunque ese
		# hueco se oculte al mudarla, el size viejo no se encoge solo: la ficha se coloca restando su
		# alto, asi que salia flotando doscientos pixeles por encima de la cabeza del bicho, sin nada
		# debajo que la explicara.
		var tam: Vector2 = col.get_combined_minimum_size()
		if not col.size.is_equal_approx(tam):
			col.size = tam
		col.position = Vector2(p.x - tam.x * 0.5, p.y - ALTO_CUERPO - SOBRE_LA_CABEZA - tam.y)

		# El cristal del clic, sobre el cuerpo. Mismo origen en los PIES que la ficha (ver
		# ALTO_CUERPO), asi que se sube su alto entero para quedar tapandolo.
		var zona: Control = f.get("zona")
		if is_instance_valid(zona):
			var ancho: float = _ancho_cuerpo_px(cuerpo)
			var alto: float = maxf(ALTO_CUERPO * cuerpo.get_global_transform_with_canvas() \
				.get_scale().y, ancho)
			zona.size = Vector2(ancho, alto)
			zona.position = Vector2(p.x - ancho * 0.5, p.y - alto)


# Saca una ficha de su banda y la cuelga de la capa suelta, sin su hueco de sprite.
func _mudar(bloque: Dictionary, cuerpo: Node2D) -> void:
	var col: Control = bloque.get("columna")
	if not is_instance_valid(col):
		return
	var padre: Node = col.get_parent()
	if padre != null:
		padre.remove_child(col)
	# Un Container le reescribiria la position en cada re-layout, y aqui la position es nuestra: la
	# capa es un Control pelado a proposito (el mismo motivo por el que la tarjeta va dentro de un
	# 'wrap', ver combat_figuras._crear_bloque).
	_capa.add_child(col)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# FUERA EL HUECO DEL SPRITE: aqui el cuerpo lo pone el mapa.
	var hueco: Control = bloque.get("actor_wrap")
	if is_instance_valid(hueco):
		hueco.visible = false
		hueco.custom_minimum_size = Vector2.ZERO

	var ficha: Dictionary = {"bloque": bloque, "cuerpo": cuerpo}
	# AL BICHO SE LE PULSA ENCIMA. En la fila eso lo hacia el hueco del sprite, que aqui no existe:
	# el bicho lo pinta el mapa, y el mapa no es un Control, asi que no recibe clics de interfaz. Se
	# le pone delante un cristal del tamaño de su cuerpo, invisible y sin nada dentro, que se coloca
	# sobre el en seguir(). El clic lo atiende el MISMO sitio que el de la tarjeta, asi que pulsar el
	# bicho y pulsar su barra son literalmente lo mismo.
	if int(bloque.get("idx", -1)) >= 0:
		var zona := Control.new()
		zona.mouse_filter = Control.MOUSE_FILTER_STOP
		zona.gui_input.connect(_pantalla.figuras._on_bloque_gui_input.bind(int(bloque["idx"])))
		_capa.add_child(zona)
		# POR DEBAJO de las fichas: donde se solapen el cristal de un bicho y la barra de otro, manda
		# la barra, que es la que estas viendo.
		_capa.move_child(zona, 0)
		ficha["zona"] = zona

	_fichas.append(ficha)


# --- MINI O ENTERA -----------------------------------------------------------------------------

# Pone cada ficha en su tamaño: entera la del apuntado, mini todas las demas.
#
# SE LLAMA CADA FOTOGRAMA, desde seguir(), y no desde _seleccionar. No es por vago: al apuntado se
# deja de apuntar de mas maneras que pulsandole encima -- se muere y _objetivo() cae al siguiente
# vivo SIN mover _target_idx (ver combat._objetivo), entran refuerzos, llega una instantanea de la
# red... Enganchandolo al clic, la ficha entera se quedaba abierta sobre el cadaver.
#
# Mirar cada fotograma es gratis porque _poner_mini no toca nada si la ficha ya esta como toca: lo
# que cuesta es el re-layout que dispara escribir un custom_minimum_size, y eso solo pasa cuando de
# verdad cambia algo.
func refrescar_mini() -> void:
	var objetivo: int = _pantalla._target_idx
	for f in _fichas:
		var bloque: Dictionary = f["bloque"]
		var idx: int = int(bloque.get("idx", -1))
		# VIVO, ademas de apuntado: mismo criterio que usa el recuadro de seleccion (ver
		# _on_tinte_cambiado). A un cadaver no se le apunta, asi que tampoco luce ficha entera.
		var entera: bool = idx >= 0 and idx == objetivo \
			and idx < _pantalla._enemies.size() and _pantalla._enemies[idx].is_alive()
		_poner_mini(f, not entera)


# Lo que mide el cuerpo de un bicho EN PANTALLA. De su forma de colision, que enemy._aplicar_colision
# deja a la medida de cada uno, por la escala de la transformada de canvas (el zoom de la camara).
func _ancho_cuerpo_px(cuerpo: Node2D) -> float:
	if not is_instance_valid(cuerpo):
		return ANCHO_MINI_MIN
	var ancho: float = ANCHO_CUERPO_POR_DEFECTO
	var col := cuerpo.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		ancho = (col.shape as RectangleShape2D).size.x
	return maxf(ancho * cuerpo.get_global_transform_with_canvas().get_scale().x, ANCHO_MINI_MIN)


# Encoge una ficha a barrita, o la devuelve a su tamaño de siempre. Si ya esta como se le pide, no
# toca nada: escribir un custom_minimum_size dispara un re-layout de la ficha entera, y esto se
# llama en cada fotograma.
#
# NO se toca el recuadro del panel: sin tinte y sin seleccion, _sb_bloque ya lo deja transparente del
# todo (fondo y borde a alpha 0), asi que en mini no se ve solo. Y dejandolo en paz, el borde blanco
# del apuntado y el tinte de los estados siguen mandando ellos, sin pelearse con esto.
func _poner_mini(ficha: Dictionary, mini: bool) -> void:
	# EL ANCHO se mira aunque no cambie el modo: el bicho puede crecer (un mutante que se hincha) y
	# la camara puede moverse. Se compara con lo aplicado y solo se escribe si de verdad cambia,
	# porque escribir un custom_minimum_size dispara el re-layout de la ficha entera.
	var ancho: float = _ancho_cuerpo_px(ficha["cuerpo"]) if mini \
		else _pantalla.montaje._ancho_bloque(_pantalla._enemies.size())
	var mismo_modo: bool = ficha.get("mini") == mini
	if mismo_modo and absf(float(ficha.get("ancho", -1.0)) - ancho) < 1.0:
		return
	ficha["mini"] = mini
	ficha["ancho"] = ancho
	var bloque: Dictionary = ficha["bloque"]
	var wrap: Control = bloque.get("wrap")
	if not is_instance_valid(wrap):
		return
	wrap.custom_minimum_size.x = ancho
	if mismo_modo:
		return   # solo cambiaba el ancho: lo demas ya esta como toca

	var margen: MarginContainer = bloque.get("margen")
	if is_instance_valid(margen):
		var m: int = 0 if mini else 6
		for lado in ["left", "right", "top", "bottom"]:
			margen.add_theme_constant_override("margin_" + lado, m)

	# El nombre y el numero, fuera: es lo que mas ancho pide y lo que mas tapa.
	var fila: Control = bloque.get("fila_nombre")
	if is_instance_valid(fila):
		fila.visible = not mini

	var hp: Control = bloque.get("hp")
	if is_instance_valid(hp):
		hp.custom_minimum_size.y = ALTO_BARRA_MINI if mini else _pantalla.figuras.ALTO_BARRA_HP
	# Las cifras dentro de la barra no caben en 5 px de alto, y ademas son ruido: lo que dice la
	# barrita es "cuanto le queda", no "cuanto exactamente".
	var hp_lbl: Control = bloque.get("hp_lbl")
	if is_instance_valid(hp_lbl):
		hp_lbl.visible = not mini

	var chips_wrap: Control = bloque.get("chips_wrap")
	if is_instance_valid(chips_wrap):
		chips_wrap.custom_minimum_size.y = ALTO_CHIPS_MINI if mini else _pantalla.figuras.ALTO_CHIPS
		var e: float = ESCALA_CHIPS_MINI if mini else 1.0
		chips_wrap.scale = Vector2(e, e)


# --- DE COMBATIENTE A CUERPO DEL MAPA ----------------------------------------------------------
# El orden es el mismo por construccion: Game._abrir_pelea crea un Combatant por nodo y en el mismo
# orden (_active_enemies), y un aliado por ficha (_active_player_pjs). Aqui se aprovecha ese pacto en
# vez de inventar un mapa nuevo que habria que mantener sincronizado.

func _cuerpo_enemigo(i: int) -> Node2D:
	var nodos: Array = Game._active_enemies
	return nodos[i] as Node2D if i >= 0 and i < nodos.size() else null


func _cuerpo_aliado(i: int) -> Node2D:
	var pjs: Array = Game._active_player_pjs
	if i < 0 or i >= pjs.size():
		return null
	return Game.cuerpo_de(pjs[i] as PersonajeData)
