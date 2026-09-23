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
# Lo que mide la ficha de un enemigo al que no estas apuntando. Son numeros de la referencia: una
# barra que se lee de un vistazo y no tapa al bicho que tiene debajo.
const ANCHO_MINI := 48.0
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
	refrescar_mini()


# Recoloca cada ficha sobre su cuerpo. Se llama cada fotograma desde la pantalla: los cuerpos se
# mueven (en su turno, o porque el mundo sigue vivo en multi) y la camara tambien puede.
func seguir() -> void:
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
		var tam: Vector2 = col.size
		if tam.x <= 0.0:
			tam = col.get_combined_minimum_size()
		col.position = Vector2(p.x - tam.x * 0.5, p.y - ALTO_CUERPO - SOBRE_LA_CABEZA - tam.y)


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

	_fichas.append({"bloque": bloque, "cuerpo": cuerpo})


# --- MINI O ENTERA -----------------------------------------------------------------------------

# Pone cada ficha en su tamaño: entera la del apuntado, mini todas las demas. Se llama al montar y
# cada vez que cambias de objetivo (ver combat_figuras._seleccionar).
func refrescar_mini() -> void:
	var objetivo: int = _pantalla._target_idx
	for f in _fichas:
		var bloque: Dictionary = f["bloque"]
		_poner_mini(bloque, int(bloque.get("idx", -1)) != objetivo)


# Encoge una ficha a barrita, o la devuelve a su tamaño de siempre.
#
# NO se toca el recuadro del panel: sin tinte y sin seleccion, _sb_bloque ya lo deja transparente del
# todo (fondo y borde a alpha 0), asi que en mini no se ve solo. Y dejandolo en paz, el borde blanco
# del apuntado y el tinte de los estados siguen mandando ellos, sin pelearse con esto.
func _poner_mini(bloque: Dictionary, mini: bool) -> void:
	var wrap: Control = bloque.get("wrap")
	if not is_instance_valid(wrap):
		return

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

	# El ancho, el ultimo: es el que dispara el re-layout que recoloca todo lo de arriba.
	wrap.custom_minimum_size.x = ANCHO_MINI if mini else _pantalla.montaje._ancho_bloque(
		_pantalla._enemies.size())


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
