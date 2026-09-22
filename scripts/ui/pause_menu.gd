# ============================================================
#  pause_menu.gd  (CanvasLayer creada por codigo desde el jugador, como el HUD)
#  Menu de PAUSA (ESC): Reanudar / Ajustes / Multijugador / Guardar / Guardar y salir.
#  Se puede guardar en CUALQUIER sitio, tambien en mitad de la mazmorra: la partida recuerda
#  el piso, tu posicion exacta y los bichos que hubiera (ver Game.exportar_partida).
#
#  NO se abre durante un COMBATE ni durante la EXTRACCION: esas pantallas ya tienen el arbol
#  en pausa y su propio flujo, y guardar a mitad de un combate seria guardar un estado que
#  luego no se puede reconstruir (media pelea, un enemigo a medio matar...).
#  Interfaz placeholder por codigo; el arte va al final.
# ============================================================

extends CanvasLayer

const MENU_PRINCIPAL := "res://scenes/ui/main_menu.tscn"
const AJUSTES := preload("res://scripts/ui/settings_menu.gd")

var _root: Control = null
var _aviso: Label = null
# El menu de siempre y el de ajustes son hermanos y se turnan: se ve uno o se ve el otro, nunca los
# dos. Asi los ajustes no heredan el ancho ni el alto de la lista de botones.
var _menu: Control = null
var _ajustes: Control = null
var _fila_codigo: HBoxContainer = null
var _txt_codigo: Label = null


func _ready() -> void:
	layer = 95   # por encima del HUD, por debajo del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS   # tiene que funcionar con el juego en pausa
	add_to_group("menu_pausa")   # lo busca el boton del engranaje del HUD (ver hud.gd)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_menu = center

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.10, 0.97)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 42
	sb.content_margin_right = 42
	sb.content_margin_top = 32
	sb.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var tit := Label.new()
	tit.text = "PAUSA"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 28)
	tit.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	vb.add_child(tit)

	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 12)
	_aviso.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	vb.add_child(_aviso)

	# ¿ESTOY EN UN MUNDO COMPARTIDO? Se calcula UNA vez y se usa para las dos cosas que dependen de
	# ello (el panel de LAN y el salir sin guardar): con dos copias de la condicion, tarde o temprano
	# una se queda atras de la otra.
	#
	# OJO CON PREGUNTARLO SOLO CON `Mundos.abierto`: esa variable es LOCAL, dice "tengo yo el fichero
	# del mundo abierto en mi disco". El INVITADO no lo tiene (lo tiene el anfitrion), asi que para el
	# vale "" aunque este dentro del mundo de otro. La bandera que sirve en los dos lados es
	# Net.mundo_compartido, la misma que usa _guardar_y_salir.
	var en_mundo_compartido: bool = Mundos.abierto != "" or (Net.activo and Net.mundo_compartido)

	_boton(vb, "Reanudar", _cerrar)
	# AJUSTES va aqui arriba, lejos de los de guardar: entre "Guardar" y "Guardar y salir" era un
	# boton mas donde ya se pulsa deprisa y sin mirar.
	_boton(vb, "Ajustes", _abrir_ajustes)
	# EL PANEL DE LAN es el de hostear/unirse por IP a mano, y dentro de un mundo compartido no pinta
	# nada: ya estas conectado, y la partida esta abierta de base. Solo se ofrece jugando a solas.
	# (El panel y el modo LAN de siempre siguen existiendo: lo que desaparece es la puerta.)
	if not en_mundo_compartido:
		_boton(vb, "Multijugador (LAN)", _abrir_multi)
	_boton(vb, "Guardar", _guardar)
	_boton(vb, "Guardar y salir al menú", _guardar_y_salir)
	# SALIR SIN GUARDAR YA NO ESTA, en ningun modo. En un mundo compartido nunca estuvo (el mundo es
	# de varios: salir sin guardar tiraria tu rato Y dejaria el mundo bloqueado a tu nombre hasta que
	# caducara el cerrojo), y en un jugador se ha quitado porque era el boton de al lado del de salir
	# guardando: un despiste ahi cuesta la sesion entera, y no gana nada que no gane recargar la
	# ranura desde el menu principal.
	var n := Label.new()
	n.text = "Al salir siempre se guarda."
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.custom_minimum_size = Vector2(ANCHO_BOTON, 0)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_size_override("font_size", 11)
	n.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	vb.add_child(n)

	# EL CODIGO DEL MUNDO, en pequeño y con un boton de copiar: para pasarselo a un compañero sin
	# tener que salir al menu de mundos. Solo sale si hay codigo (ver _codigo_mundo).
	_fila_codigo = HBoxContainer.new()
	_fila_codigo.alignment = BoxContainer.ALIGNMENT_CENTER
	_fila_codigo.add_theme_constant_override("separation", 8)
	vb.add_child(_fila_codigo)
	_txt_codigo = Label.new()
	_txt_codigo.add_theme_font_size_override("font_size", 11)
	_txt_codigo.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	_fila_codigo.add_child(_txt_codigo)
	var copiar := Button.new()
	copiar.text = "Copiar"
	copiar.add_theme_font_size_override("font_size", 11)
	copiar.pressed.connect(_copiar_codigo)
	_fila_codigo.add_child(copiar)
	_pintar_codigo()

	# Los ajustes se montan ya, no la primera vez que se abren: asi el panel existe desde el
	# principio y no hay que preguntarse si esta creado cada vez que se pulsa el boton.
	_ajustes = AJUSTES.new()
	_ajustes.visible = false
	_ajustes.cerrado.connect(_cerrar_ajustes)
	_root.add_child(_ajustes)


# 420x56 y no 260 de ancho por lo alto que salga: con el pulgar, un boton de 31 px de alto es una
# loteria. Con los CINCO de un jugador (reanudar, ajustes, LAN, guardar, guardar y salir) son ~420 px
# de alto contando titulo y nota, que entran de sobra en los 720 de referencia; en un mundo
# compartido son cuatro y sobra aire.
const ANCHO_BOTON := 420.0
const ALTO_BOTON := 56.0


func _boton(vb: VBoxContainer, txt: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(ANCHO_BOTON, ALTO_BOTON)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(fn)
	vb.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.is_action_pressed(&"cancelar"):
		return
	# ESC dentro de los AJUSTES vuelve a la pausa, no cierra la pausa entera: si no, para salir de
	# los ajustes habria que reabrir el menu.
	if _root.visible and _ajustes != null and _ajustes.visible:
		_ajustes.cerrar()
		get_viewport().set_input_as_handled()
		return
	if not alternar():
		return
	get_viewport().set_input_as_handled()


# Abre o cierra la pausa, con la guarda dentro. Lo llaman las DOS vias (la tecla ESC de arriba y el
# boton del engranaje del HUD), para que la regla de cuando SE PUEDE pausar viva en un solo sitio y
# no en dos que se separen el dia que cambie.
#
# ESC dentro de OTRO menu lo CIERRA y no abre esto. La primera linea de defensa es que cada menu
# consume la ESC en su _input (que corre antes que el _unhandled_input de arriba), asi que
# normalmente ahi no llega nada; hay_modal() es el cinturon por si algun menu se olvida de
# consumirla. Y con un combate o una extraccion delante no hace nada: ahi no se guarda.
#
# Devuelve si ha hecho algo, que es lo que la tecla necesita para saber si consume el evento.
func alternar() -> bool:
	if not _root.visible and (Game.hay_pantalla_abierta() or Game.hay_modal()):
		return false
	_set_open(not _root.visible)
	return true


func _set_open(abierto: bool) -> void:
	_root.visible = abierto
	Game.fijar_modal(Game.Modal.SISTEMA, self, abierto)
	if abierto:
		_aviso.text = ""
		_pintar_codigo()
	# Cerrando con los ajustes delante (el engranaje del HUD, por ejemplo): se cierran ellos primero
	# -- que es lo que guarda lo tocado -- y la pausa vuelve a empezar por su lista de botones.
	elif _ajustes != null and _ajustes.visible:
		_ajustes.cerrar()


func _cerrar() -> void:
	_set_open(false)


# El codigo (id_nube) del mundo en el que estoy. Mundos.abierto lo tiene quien abre el mundo en su
# disco; con la SALA todos entran como clientes y lo que queda puesto es Mundos.uniendome. Un mundo
# añadido solo por IP no tiene codigo, y a solas tampoco: "" y la fila no sale.
# Se guarda la primera vez que sale: Mundos.entrada tambien inspecciona el fichero del mundo, y no
# hace falta repetirlo cada vez que se abre la pausa (el codigo no cambia en toda la sesion).
var _codigo: String = ""

func _codigo_mundo() -> String:
	if _codigo != "":
		return _codigo
	var clave: String = Mundos.abierto if Mundos.abierto != "" else Mundos.uniendome
	if clave == "":
		return ""
	_codigo = String(Mundos.entrada(clave).get("id_nube", ""))
	return _codigo


func _pintar_codigo() -> void:
	var cod: String = _codigo_mundo()
	_fila_codigo.visible = cod != ""
	_txt_codigo.text = "Código del mundo: %s" % cod


func _copiar_codigo() -> void:
	DisplayServer.clipboard_set(_codigo_mundo())
	_aviso.text = "Código copiado."


func _abrir_ajustes() -> void:
	_menu.visible = false
	_ajustes.abrir()


func _cerrar_ajustes() -> void:
	_menu.visible = true


# Abre el panel de conexion LAN (multiplayer_panel.gd, hermano nuestro colgado del jugador).
# Cerramos la pausa primero: el panel trae su propio modal y su propio ESC.
func _abrir_multi() -> void:
	var panel: Node = get_tree().get_first_node_in_group("multiplayer_panel")
	if panel == null:
		_aviso.text = "No esta el panel de multijugador."
		return
	_set_open(false)
	panel.abrir()


# MULTIJUGADOR (hito 6 preventivo): guarda el HOST, y guarda POR LOS DOS. El invitado esta jugando en
# el mundo del host, asi que su partida no se puede volcar tal cual: Game.exportar_partida_invitado le
# devuelve lo del mundo (baul, mapa, bosses) a como estaba al entrar y le deja en SU pueblo. Solo lo
# dispara el host: dos saves autoritativos a la vez es justo el lio que el hito 6 viene a resolver.
func _guardar() -> void:
	# EL INVITADO TAMBIEN PUEDE. No guarda por su cuenta -- el mundo donde estais jugando es el del
	# host y hay que volcarlo tambien -- asi que se lo PIDE, y el host hace lo mismo que si hubiera
	# pulsado el boton el: se guarda, y de ahi salen los guardados de TODOS los invitados.
	if Net.activo and not Net.es_host:
		Net.partida.pedir_guardar_todos()
		_aviso.text = "Guardando: se lo pides al anfitrión y quedáis todos a salvo."
		return
	# MUNDO COMPARTIDO: se guarda en el mundo, no en una ranura, y ademas se SUBE (sin soltar el
	# cerrojo) para que un cuelgue no se lleve la sesion.
	if Mundos.abierto != "":
		var subido: bool = await Mundos.autoguardar()
		_aviso.text = "Mundo guardado y al día." if subido \
			else "Guardado en tu disco, pero sin subir todavía."
		return
	var ok: bool = Perfil.guardar_actual()
	if ok and Net.activo:
		Net.partida.guardar_todos()
		_aviso.text = "Partida guardada (y tus compañeros, a salvo en su pueblo)."
		return
	_aviso.text = "Partida guardada." if ok else "No se pudo guardar."


func _guardar_y_salir() -> void:
	# El invitado lo pide igual, pero con cerrando=true: el host guarda, cierra, y a cada invitado se
	# le devuelve a su mundo con lo recien guardado (el camino de _guardar_ahora ya estaba escrito).
	if Net.activo and not Net.es_host:
		# INVITADO EN UN MUNDO COMPARTIDO: mi personaje vive en ese mundo, asi que "salir" es dejarlo
		# guardado y volver al menu de multijugador -- no tengo pueblo propio al que ir. Se le pide al
		# anfitrion que guarde y se le da un respiro para que mi estado llegue antes de cortar.
		if Net.mundo_compartido:
			_aviso.text = "Guardando tu personaje en el mundo..."
			# Se ESPERA a que el host diga que ha escrito, con un tope. Antes era un segundo a ciegas, y
			# el host puede tardar hasta _PLAZO_ESTADOS en recoger: con un poco de lag se cortaba antes
			# de que llegase lo ultimo que habias hecho. La espera vive en Ventana porque la necesitan
			# los DOS caminos de salir: este boton y la ✕ de la ventana.
			await Ventana.pedir_guardado_al_anfitrion()
			await get_tree().create_timer(0.2).timeout   # respiro antes de cortar (ver desconectar)
			Game.limpiar_modales()
			Net.desconectar()
			get_tree().change_scene_to_file("res://scenes/ui/multi_menu.tscn")
			return
		Net.partida.pedir_guardar_todos(true)
		_aviso.text = "Guardando y cerrando: se lo pides al anfitrión."
		return
	# MUNDO COMPARTIDO: guardar, subir y SOLTAR EL CERROJO, en ese orden. Si la subida falla el mundo
	# sigue reservado a mi nombre y queda marcado como pendiente: no se sale como si nada.
	# (cerrar_y_subir recoge antes el estado de los invitados y les avisa de que se cierra.)
	if Mundos.abierto != "":
		var r: Dictionary = await Mundos.cerrar_y_subir()
		if not r.get("ok", false):
			_aviso.text = "%s\nSe sale, pero el mundo queda pendiente de subir." % String(r.get("mensaje", ""))
			await get_tree().create_timer(1.5).timeout
		_salir()
		return
	if not Perfil.guardar_actual():
		_aviso.text = "No se pudo guardar (no se sale)."
		return
	# Cerrando la sesion: al invitado se le pide que guarde Y que se vuelva a su mundo con lo guardado
	# (si no, se comeria un "el host ha cerrado" a secas). Se ESPERA a que el aviso salga de verdad:
	# _salir() desconecta, y cortar en el mismo frame tiraria el paquete sin enviarlo.
	if Net.activo:
		await Net.partida.guardar_todos(true)
	_salir()


func _salir() -> void:
	# Despausar ANTES de cambiar de escena: si no, el menu principal nace con el arbol en
	# pausa y no responde a nada. Vaciamos la pila entera: el singleton Game persiste entre
	# escenas y no debe quedar ningun modal residual.
	Game.limpiar_modales()
	# Y si habia sesion de red, se cierra: el menu principal no es sitio para seguir conectado.
	if Net.activo:
		Net.desconectar()
	get_tree().change_scene_to_file(MENU_PRINCIPAL)
