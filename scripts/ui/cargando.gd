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


## Cambia de escena con la capa puesta y la quita cuando la escena nueva ya esta en el arbol.
func cambiar_escena(arbol: SceneTree, ruta: String, texto: String = "Cargando...") -> void:
	await mostrar(texto)
	arbol.change_scene_to_file(ruta)
	if arbol.has_signal(&"scene_changed"):
		await arbol.scene_changed
	await arbol.process_frame
	ocultar()
