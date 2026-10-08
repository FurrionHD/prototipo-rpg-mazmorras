# ============================================================
#  cargando.gd  (AUTOLOAD: se llama "Cargando")
#  UNA CAPA DE "CARGANDO..." por encima de todo, para los ratos en los que el juego se queda
#  parado haciendo algo pesado (migrar las partidas a la BD, montar una partida, cargar el pueblo
#  o la mazmorra). No acelera nada: que se VEA que esta trabajando en vez de parecer colgado.
#
#  El truco es el orden: mostrar(), ESPERAR a que se pinte (dos fotogramas) y DESPUES el trabajo
#  pesado. Si se hace todo en el mismo fotograma, la capa no llega a verse nunca.
#    await Cargando.mostrar("Actualizando tus partidas...")
#    <trabajo pesado>
#    Cargando.ocultar()
#  Para cambiar de escena: await Cargando.cambiar_escena(arbol, ruta, texto) (se quita sola cuando
#  la escena nueva ya esta puesta). Interfaz placeholder por codigo, como el resto.
# ============================================================
extends CanvasLayer

var _fondo: ColorRect
var _texto: Label


func _ready() -> void:
	layer = 120   # por encima de menus y modales
	process_mode = Node.PROCESS_MODE_ALWAYS   # los menus pausan el arbol
	_fondo = ColorRect.new()
	_fondo.color = Color(0.04, 0.04, 0.06, 0.92)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP   # que no se pulse nada debajo mientras tanto
	add_child(_fondo)
	_texto = Label.new()
	_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size", 26)
	_texto.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_fondo.add_child(_texto)
	visible = false


## Enseña la capa y espera a que se haya pintado: lo que venga despues del await ya se ve tapado.
func mostrar(texto: String = "Cargando...") -> void:
	_texto.text = texto
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame


## Cambia el texto de la capa ya puesta (lo que va pasando mientras tanto).
func poner_texto(texto: String) -> void:
	_texto.text = texto


func ocultar() -> void:
	visible = false


func visible_ahora() -> bool:
	return visible


## Cambia de escena con la capa puesta y la quita cuando la escena nueva ya esta en el arbol. Si la escena nueva es la
## MAZMORRA, no la quita: la quita el piso cuando esta montado y va fluido (ver cubrir_piso / piso_montado).
func cambiar_escena(arbol: SceneTree, ruta: String, texto: String = "Cargando...") -> void:
	await mostrar(texto)
	arbol.change_scene_to_file(ruta)
	if arbol.has_signal(&"scene_changed"):
		await arbol.scene_changed
	await arbol.process_frame
	if not _reteniendo:
		ocultar()


# ============================================================
#  AL ENTRAR A UN PISO (08/10, playtest: "la primera vez que me metia en el piso 6 daba un lagazo; que haya una pantalla
#  de carga que cargue primero el piso entero y luego ya me deje moverme").
#  cubrir_piso() la pone y PARA el juego (pila de modales de Game, como un menu: nadie te pega mientras carga) en
#  cuanto se sabe que se va a un piso; piso_montado() la llama el piso al acabar de construirse y la quita cuando los
#  fotogramas van fluidos (FOTOGRAMAS_FLUIDOS seguidos por debajo de FOTOGRAMA_FLUIDO), con un TOPE por si nunca.
#  Sin ventana (pruebas, trabajadores de pelea) no hace nada: alli no hay nadie a quien taparle nada y las pruebas
#  cuentan fotogramas desde que nace el piso.
# ============================================================
const _TOKEN_PISO := "cargando_piso"
const FOTOGRAMAS_FLUIDOS := 10
const FOTOGRAMA_FLUIDO := 1.0 / 30.0
const TOPE_MS := 12000
var _reteniendo: bool = false
var _cubierto: bool = false
## Para probarla sin ventana (tools/prueba_carga_piso).
var forzar_sin_ventana: bool = false


func _sin_pantalla() -> bool:
	return not forzar_sin_ventana and (DisplayServer.get_name() == "headless" or Net.soy_trabajador)


## La pone y para el juego. En solitario conviene esperarla (await) ANTES del trabajo pesado, para que se llegue a ver.
func cubrir_piso(texto: String = "Cargando...") -> void:
	if _sin_pantalla():
		return
	_texto.text = texto
	visible = true
	if not _cubierto:
		_cubierto = true
		Game.entrar_modal(Game.Modal.SISTEMA, _TOKEN_PISO)
		_vigilar_cubierto()
	await get_tree().process_frame
	await get_tree().process_frame


# EL SEGURO: si se cubrio para ir a un piso y el piso no llega a avisar (no habia partida y se fue al menu, la escena
# fallo...), pasado el tope se quita sola y suelta el juego. Sin esto se quedaria parado tras la capa para siempre.
func _vigilar_cubierto() -> void:
	await get_tree().create_timer(float(TOPE_MS) / 1000.0, true).timeout
	if _cubierto and not _reteniendo:
		push_warning("[carga] el piso no aviso de que estaba montado: quito la pantalla")
		Game.salir_modal(_TOKEN_PISO)
		_cubierto = false
		ocultar()


## El piso ya esta construido: se queda puesta hasta que vaya fluido y luego suelta el juego.
func piso_montado() -> void:
	if _sin_pantalla():
		return
	if _reteniendo:
		return
	_reteniendo = true
	visible = true
	# (Otra vez por si cambiar de escena vacio la pila de modales, ver Game.limpiar_modales.)
	Game.salir_modal(_TOKEN_PISO)
	Game.entrar_modal(Game.Modal.SISTEMA, _TOKEN_PISO)
	_cubierto = true
	var t0: int = Time.get_ticks_msec()
	var buenos: int = 0
	while buenos < FOTOGRAMAS_FLUIDOS and Time.get_ticks_msec() - t0 < TOPE_MS:
		await get_tree().process_frame
		buenos = buenos + 1 if get_process_delta_time() < FOTOGRAMA_FLUIDO else 0
	print("[carga] piso listo en %d ms" % (Time.get_ticks_msec() - t0))
	Game.salir_modal(_TOKEN_PISO)
	_cubierto = false
	_reteniendo = false
	ocultar()


func reteniendo() -> bool:
	return _reteniendo or _cubierto
