# ============================================================
#  combat_montaje_mapa.gd  (tema de la pantalla de combate: combat.montaje, en modo TACTICO)
#  EL MONTAJE CUANDO SE PELEA EN EL MAPA. HEREDA del montaje de siempre y solo cambia lo que era de
#  la fila de tarjetas; todo lo demas -- la barra de acciones, el registro, la linea de tiempo, el
#  boton de velocidad, la capa de numeros -- se reutiliza TAL CUAL, porque no tiene nada que ver con
#  donde esten colocados los combatientes: son HUD pegado a los bordes de la pantalla.
#
#  Hereda, y no es un tema hermano, justamente por eso: lo que cambia son tres funciones de trece.
#  Copiarlas todas seria garantizar que el dia que alguien arregle el registro lo arregle en un solo
#  sitio de los dos.
#
#  LAS TRES QUE CAMBIAN:
#    _anadir_fondo   no se pinta nada: debajo esta la mazmorra, y la gracia es verla.
#    _montar_columna no hay bandas de tarjetas. Si hay registro y capa de numeros.
#    _setup_ui       se montan los bloques igual que siempre (con su numero, su vida y sus chips) y
#                    despues se MUDAN encima de su cuerpo del mapa (ver combat_figuras_mapa).
# ============================================================
extends "res://scripts/ui/combat_montaje.gd"


# El mundo se ve: no hay fondo que pintar. Es la diferencia mas visible de las tres y la mas corta.
func _anadir_fondo() -> void:
	pass


# Sin bandas de tarjetas: cada ficha va a flotar sobre su cuerpo. Lo que si hace falta es el
# registro (se lee igual) y la capa donde vuelan los numeros de daño.
func _montar_columna() -> void:
	_col = _pantalla.get_node("VBox")
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.visible = false

	# LAS BANDAS SE CREAN IGUAL, aunque queden vacias. No es desperdicio: _crear_bloque pregunta el
	# ancho de su fila y las altas a media pelea meten y sacan columnas de ellas. Dejandolas existir,
	# el codigo de siempre sigue funcionando y las columnas simplemente se mudan despues.
	_pantalla._bloques_box = _crear_fila_bloques(true)
	_aliados_box = _crear_fila_bloques(false)
	# ...pero no se ven: lo que se ve son las fichas ya mudadas sobre los cuerpos.
	_pantalla._bloques_box.visible = false
	_aliados_box.visible = false

	_montar_log()

	_capa_numeros = Control.new()
	_capa_numeros.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa_numeros.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_numeros.clip_contents = false
	_capa_numeros.process_mode = Node.PROCESS_MODE_ALWAYS
	_capa_numeros.z_index = 4000
	_pantalla.add_child(_capa_numeros)
	if _pantalla._fx != null:
		_pantalla._fx.capa_numeros = _capa_numeros


# Los bloques se crean por el camino de siempre y luego se mudan al mapa.
func _setup_ui() -> void:
	super._setup_ui()
	_pantalla.figuras_mapa.montar()


# EL ANCHO DE LAS FICHAS NO SE REPARTE AQUI. En la fila, las tarjetas se encogen a partes iguales
# cuando entran refuerzos y dejan de caber; flotando sobre el mapa no compiten por un hueco comun, y
# el ancho lo decide el modo mini (ver combat_figuras_mapa._poner_mini). Sin esto, el primer bicho
# que entrara a media pelea le devolveria sus 216 px a todas las barritas.
func _reajustar_anchos(_bloques: Array, _n: int) -> void:
	pass
