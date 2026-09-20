# ============================================================
#  ventana.gd  (autoload "Ventana")
#  LA VENTANA: como se ve y como se cierra. Dos cosas que parecen distintas y son la misma: las dos
#  las decide el sistema operativo por encima del juego, y hasta hoy el juego no se enteraba.
#
#  1. EL CIERRE. Con auto_accept_quit (el valor de fabrica) la ✕ y el alt+F4 cierran el proceso sin
#     pasar por ninguna linea de codigo: en un mundo compartido eso se llevaba hasta un minuto de
#     juego (el autoguardado va cada SEG_AUTOGUARDADO) y en un jugador, todo lo hecho desde el
#     ultimo guardado a mano. Ahora el aviso llega aqui, se guarda con un cartel delante y se cierra.
#  2. EL MODO DE PANTALLA: ventana, ventana sin bordes o pantalla completa. Es un ajuste de MAQUINA,
#     no de partida, asi que vive en user://ajustes.cfg junto a los volumenes (ver sonido.gd).
#
#  PROCESS_MODE_ALWAYS porque los menus de este juego pausan el arbol: sin eso, cerrar desde el menu
#  de pausa se quedaria esperando un frame que no llega (ver menus-pausan-el-juego).
# ============================================================

extends Node

# El mismo fichero que Sonido, y por el mismo motivo: son ajustes de esta maquina, no de la partida,
# asi que no pintan nada en el save. Los dos cargan-modifican-guardan para no pisarse la seccion.
const RUTA_AJUSTES := "user://ajustes.cfg"
const SECCION := "pantalla"

enum Modo {VENTANA, SIN_BORDES, COMPLETA}

# COMO SE LLAMAN PARA EL JUGADOR, en el orden en que salen en Ajustes.
const MODOS := [
	{"id": Modo.VENTANA, "nombre": "Ventana"},
	{"id": Modo.SIN_BORDES, "nombre": "Ventana sin bordes"},
	{"id": Modo.COMPLETA, "nombre": "Pantalla completa"},
]

# Lo que se espera como mucho a que termine el guardado al cerrar. Un alt+F4 que no cierra es peor
# que un alt+F4 que pierde algo: si esto se agota, se cierra igual. Da de sobra para lo que tarda
# (el mundo compartido recoge estados ~1,5 s y sube el fichero; la ranura de un jugador, menos).
const TOPE_CIERRE := 8.0

var modo: int = Modo.VENTANA
# SINCRONIZACION VERTICAL. Encendida corta el desgarro de la imagen al moverse; apagada deja correr
# los fotogramas (portatil con la grafica justa, o para ver de verdad si algo va lento). Es lo otro
# que se ajusta de la imagen, asi que vive aqui con el modo.
var vsync: bool = true

var _cerrando: bool = false
var _cartel: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar_ajustes()
	aplicar(modo)
	aplicar_vsync(vsync)


# ============================================================
#  EL MODO DE PANTALLA
# ============================================================

func aplicar(m: int) -> void:
	modo = clampi(m, 0, MODOS.size() - 1)
	# SIEMPRE se sale de pantalla completa primero. Poner el borde (o quitarlo) con la ventana en
	# completa no hace nada en Windows y te deja el ajuste a medias: se ve completa y cree que es
	# ventana. Volviendo a WINDOWED antes, los tres modos salen del mismo sitio.
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	match modo:
		Modo.COMPLETA:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Modo.SIN_BORDES:
			# No es pantalla completa de verdad: es una ventana sin marco que TAPA LA PANTALLA ENTERA.
			# Asi alt+tab no parpadea y se puede dejar algo encima, pero se ve como una completa.
			#
			# Por screen_get_position/size y NO por screen_get_usable_rect: "usable" es el escritorio
			# MENOS la barra de tareas, asi que la ventana se quedaba corta por abajo y la barra de
			# Windows seguia ahi encima del juego. Sin bordes tiene que taparla.
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var pantalla: int = DisplayServer.window_get_current_screen()
			DisplayServer.window_set_position(DisplayServer.screen_get_position(pantalla))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(pantalla))
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	_guardar_ajustes()


func aplicar_vsync(activo: bool) -> void:
	vsync = activo
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_guardar_ajustes()


func nombre_modo(m: int) -> String:
	return String((MODOS[clampi(m, 0, MODOS.size() - 1)] as Dictionary)["nombre"])


# F11 alterna completa/ventana sin pasar por los ajustes, que es como se espera que funcione en
# cualquier juego. Va por _input y no por _unhandled_input a proposito: con un menu delante (y los
# menus de aqui se comen la entrada) el atajo tiene que seguir respondiendo.
func _input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo \
			and (e as InputEventKey).keycode == KEY_F11:
		aplicar(Modo.VENTANA if modo == Modo.COMPLETA else Modo.COMPLETA)
		get_viewport().set_input_as_handled()


func _cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(RUTA_AJUSTES)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[ventana] no se pudo leer %s (error %d): modo por defecto" % [RUTA_AJUSTES, err])
	modo = clampi(int(cfg.get_value(SECCION, "modo", Modo.VENTANA)), 0, MODOS.size() - 1)
	vsync = bool(cfg.get_value(SECCION, "vsync", true))


func _guardar_ajustes() -> void:
	# LEER ANTES DE ESCRIBIR: en este fichero tambien estan los volumenes. Guardando un ConfigFile
	# recien hecho se los llevaria por delante (y ellos a este) en cuanto los dos toquen el fichero.
	var cfg := ConfigFile.new()
	cfg.load(RUTA_AJUSTES)
	cfg.set_value(SECCION, "modo", modo)
	cfg.set_value(SECCION, "vsync", vsync)
	var err: int = cfg.save(RUTA_AJUSTES)
	if err != OK:
		push_warning("[ventana] no se pudo guardar %s (error %d)" % [RUTA_AJUSTES, err])


# ============================================================
#  EL CIERRE DE LA VENTANA
# ============================================================

func _notification(what: int) -> void:
	# La ✕, el alt+F4 y el boton de atras de Android (el mismo camino: cerrar es cerrar).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_cerrar()


func _cerrar() -> void:
	# La segunda ✕ no vale de nada: ya se esta guardando. Sin esto, dar dos veces lanzaba dos
	# guardados a la vez sobre el mismo fichero.
	if _cerrando:
		return
	_cerrando = true
	# En un menu no hay nada que guardar: el arbol vivo (el jugador, la mazmorra) es justo lo que
	# exportar_partida necesita, y en el menu principal no existe. Se cierra y ya.
	if not Mundos.en_partida():
		get_tree().quit()
		return
	_mostrar_cartel("Guardando la partida…\nNo cierres todavía.")
	# Con TOPE: el guardado espera a la red (los estados de los invitados, la subida a la nube) y
	# una conexion caida no puede dejar la ventana colgada sin cerrarse.
	var listo: Array = [false]   # Array y no bool: la lambda captura por valor
	_guardar_y_marcar(listo)
	var esperado: float = 0.0
	while not listo[0] and esperado < TOPE_CIERRE:
		await get_tree().create_timer(0.1).timeout
		esperado += 0.1
	if not listo[0]:
		push_warning("[ventana] el guardado al cerrar no termino en %.0f s: se cierra igual" % TOPE_CIERRE)
	if Net.activo:
		Net.desconectar()
	get_tree().quit()


func _guardar_y_marcar(listo: Array) -> void:
	await guardar_al_cerrar()
	listo[0] = true


# EL GUARDADO DE CERRAR. Es el reparto de siempre (ver pause_menu._guardar_y_salir, el hermano que
# ademas decide a que menu se vuelve): quien guarda depende de si juegas solo, de invitado, de host
# o dentro de un mundo compartido.
func guardar_al_cerrar() -> void:
	# UN TRABAJADOR DE PISO no tiene partida (ver Game.guardar_mi_partida).
	if Net.soy_trabajador:
		return
	if Net.activo and not Net.es_host:
		# INVITADO: mi personaje vive en el save del anfitrion, asi que no hay nada que escribir
		# aqui. Se le pide a el y se espera a que diga que lo ha escrito.
		await pedir_guardado_al_anfitrion()
		return
	# MUNDO COMPARTIDO: guardar, subir y soltar el cerrojo. Si la subida falla el mundo queda
	# pendiente, que es mejor que soltarlo a medias.
	if Mundos.abierto != "":
		var r: Dictionary = await Mundos.cerrar_y_subir()
		if not bool(r.get("ok", false)):
			push_warning("[ventana] al cerrar: %s" % String(r.get("mensaje", "")))
		return
	Perfil.guardar_actual()
	# HOST de una sala normal: guarda tambien por sus invitados, y se ESPERA a que el aviso salga
	# de verdad (desconectar en el mismo frame tiraria el paquete sin enviarlo).
	if Net.activo:
		await Net.partida.guardar_todos(true)


# EL INVITADO LE PIDE AL ANFITRION QUE GUARDE, y espera a que conteste (con tope). Vive aqui y no en
# el menu de pausa porque lo necesitan los dos caminos de salir: el boton y la ✕.
# 'cerrando' = ademas de guardar, el host cierra la sesion y devuelve a cada uno a su mundo.
# Devuelve si llego la respuesta a tiempo.
func pedir_guardado_al_anfitrion(cerrando: bool = false, tope: float = 5.0) -> bool:
	var llego: Array = [false]   # Array y no bool: la lambda captura por valor
	var al_llegar := func(_ok: bool) -> void: llego[0] = true
	Net.guardado_respondido.connect(al_llegar)
	Net.partida.pedir_guardar_todos(cerrando)
	var esperado: float = 0.0
	while not llego[0] and esperado < tope:
		await get_tree().create_timer(0.1).timeout
		esperado += 0.1
	if Net.guardado_respondido.is_connected(al_llegar):
		Net.guardado_respondido.disconnect(al_llegar)
	return llego[0]


# El cartel de "espera, que estoy guardando". Por codigo y encima de todo (capa 4096, como los
# retratos: ver retratos-pisan-los-modales), que esto tiene que verse aunque haya un modal abierto.
func _mostrar_cartel(texto: String) -> void:
	if _cartel != null:
		return
	_cartel = CanvasLayer.new()
	_cartel.layer = 4096
	_cartel.process_mode = Node.PROCESS_MODE_ALWAYS

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.0, 0.0, 0.0, 0.8)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_cartel.add_child(fondo)

	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	_cartel.add_child(l)

	get_tree().get_root().add_child(_cartel)
