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
#     Con el, lo demas de la pestaña Graficos (17/11): vsync, limite de FPS, mostrar FPS y brillo.
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
# 20 y no 8 desde que la nube es de verdad (21/09/2026): subir un mundo de 4 MB a Cloudflare son unos
# segundos con buena conexion y bastantes mas con una subida lenta, y si se corta la nube se queda
# con el autoguardado anterior (y al reabrir, la copia de la nube manda sobre la del disco).
const TOPE_CIERRE := 20.0

var modo: int = Modo.VENTANA
# SINCRONIZACION VERTICAL. Encendida corta el desgarro de la imagen al moverse; apagada deja correr
# los fotogramas (portatil con la grafica justa, o para ver de verdad si algo va lento). Es lo otro
# que se ajusta de la imagen, asi que vive aqui con el modo.
var vsync: bool = true
# LIMITE DE FPS (17/11): 0 = sin limite (con vsync ya va a lo que da la pantalla).
const LIMITES_FPS := [
	{"id": 0, "nombre": "Sin límite"},
	{"id": 30, "nombre": "30"},
	{"id": 60, "nombre": "60"},
	{"id": 120, "nombre": "120"},
	{"id": 144, "nombre": "144"},
]
var limite_fps: int = 0
# LA RESOLUCION DE LA VENTANA (17/11). Solo cuenta en modo Ventana: sin bordes y completa usan la del monitor. Todo esta
# montado sobre 1280x720 y el motor lo escala (stretch canvas_items + expand), asi que cualquier tamaño se ve entero.
# (0, 0) = nunca la ha elegido: no se toca la ventana (lo de siempre).
const RESOLUCIONES := [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160),
]
var resolucion: Vector2i = Vector2i.ZERO
# EL CONTADOR DE FPS (el de F3): lo enciende el interruptor de Ajustes o la tecla, y se recuerda al cerrar.
var mostrar_fps: bool = false
# BRILLO (17/11): 0,5 a 1,5; 1 = como esta pintado. Es una capa por encima de TODO que multiplica la imagen, y solo
# existe si el brillo no es 1: por defecto no cuesta nada.
const BRILLO_MIN := 0.5
const BRILLO_MAX := 1.5
var brillo: float = 1.0
var _capa_brillo: CanvasLayer = null
var _mat_brillo: ShaderMaterial = null

var _cerrando: bool = false
var _cartel: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# SIN VENTANA (la sala, las pruebas) no hay pantalla que ajustar, y aplicar() ESCRIBE
	# ajustes.cfg: con varios de estos arrancando a la vez que el juego, se pisaban el fichero.
	if DisplayServer.get_name() == "headless":
		return
	_cargar_ajustes()
	aplicar(modo)
	aplicar_vsync(vsync)
	aplicar_limite_fps(limite_fps)
	fijar_brillo(brillo)


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
			_poner_resolucion()
	_guardar_ajustes()


# Las que CABEN en el monitor donde esta la ventana (una de 2560 en una pantalla de 1920 se saldria por los lados).
func resoluciones_que_caben() -> Array:
	var tope: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var out: Array = []
	for r in RESOLUCIONES:
		if (r as Vector2i).x <= tope.x and (r as Vector2i).y <= tope.y:
			out.append(r)
	if out.is_empty():
		out.append(RESOLUCIONES[0])
	return out


func aplicar_resolucion(r: Vector2i) -> void:
	resolucion = r
	if modo == Modo.VENTANA:
		_poner_resolucion()
	_guardar_ajustes()


# La pone y CENTRA la ventana en su monitor. Sin elegir (0, 0) no se toca nada.
func _poner_resolucion() -> void:
	if resolucion.x <= 0 or resolucion.y <= 0 or DisplayServer.get_name() == "headless":
		return
	var pantalla: int = DisplayServer.window_get_current_screen()
	DisplayServer.window_set_size(resolucion)
	var hueco: Vector2i = DisplayServer.screen_get_size(pantalla)
	DisplayServer.window_set_position(DisplayServer.screen_get_position(pantalla) + (hueco - resolucion) / 2)


func aplicar_vsync(activo: bool) -> void:
	vsync = activo
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_guardar_ajustes()


func aplicar_limite_fps(f: int) -> void:
	limite_fps = maxi(f, 0)
	Engine.max_fps = limite_fps
	_guardar_ajustes()


# Lo enciende o lo apaga en el contador (fps_overlay, en el grupo "contador_fps") y se guarda.
func aplicar_mostrar_fps(on: bool) -> void:
	mostrar_fps = on
	get_tree().call_group("contador_fps", "encender", on)
	_guardar_ajustes()


# Mientras se arrastra el mando: se ve YA y NO se guarda (como los volumenes). guardar_ajustes() al soltar.
func fijar_brillo(b: float) -> void:
	brillo = clampf(b, BRILLO_MIN, BRILLO_MAX)
	if is_equal_approx(brillo, 1.0):
		if _capa_brillo != null:
			_capa_brillo.visible = false
		return
	if _capa_brillo == null:
		_montar_capa_brillo()
	_capa_brillo.visible = true
	_mat_brillo.set_shader_parameter("brillo", brillo)


func guardar_ajustes() -> void:
	_guardar_ajustes()


# La capa del brillo: encima de TODO (por encima de los carteles de 4096), sin coger el raton, y lee la pantalla ya
# pintada y la multiplica. filter_nearest: que el pixel art no se emborrone.
func _montar_capa_brillo() -> void:
	_capa_brillo = CanvasLayer.new()
	_capa_brillo.layer = 4100
	_capa_brillo.process_mode = Node.PROCESS_MODE_ALWAYS
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform float brillo = 1.0;
void fragment() {
	COLOR = vec4(texture(pantalla, SCREEN_UV).rgb * brillo, 1.0);
}"""
	_mat_brillo = ShaderMaterial.new()
	_mat_brillo.shader = sh
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = _mat_brillo
	_capa_brillo.add_child(r)
	add_child(_capa_brillo)


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
	limite_fps = maxi(int(cfg.get_value(SECCION, "limite_fps", 0)), 0)
	var res = cfg.get_value(SECCION, "resolucion", Vector2i.ZERO)
	resolucion = res if res is Vector2i else Vector2i.ZERO
	mostrar_fps = bool(cfg.get_value(SECCION, "mostrar_fps", false))
	brillo = clampf(float(cfg.get_value(SECCION, "brillo", 1.0)), BRILLO_MIN, BRILLO_MAX)


func _guardar_ajustes() -> void:
	# LEER ANTES DE ESCRIBIR: en este fichero tambien estan los volumenes. Guardando un ConfigFile
	# recien hecho se los llevaria por delante (y ellos a este) en cuanto los dos toquen el fichero.
	var cfg := ConfigFile.new()
	cfg.load(RUTA_AJUSTES)
	cfg.set_value(SECCION, "modo", modo)
	cfg.set_value(SECCION, "vsync", vsync)
	cfg.set_value(SECCION, "limite_fps", limite_fps)
	cfg.set_value(SECCION, "resolucion", resolucion)
	cfg.set_value(SECCION, "mostrar_fps", mostrar_fps)
	cfg.set_value(SECCION, "brillo", brillo)
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


# EL GUARDADO DE CERRAR (ver pause_menu._guardar_y_salir, el hermano que ademas decide a que menu se vuelve). Mi
# personaje vive en el mundo de la sala (etapa 4: el jugador nunca es el anfitrion), asi que no hay nada que escribir
# aqui: se le pide a ella y se espera a que diga que lo ha escrito.
func guardar_al_cerrar() -> void:
	await pedir_guardado_al_anfitrion()


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
