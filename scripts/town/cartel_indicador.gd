# ============================================================
#  cartel_indicador.gd  (los postes con flechas de los cruces, ver PuebloPlano.CARTELES)
#  F encima: sale un globo sobre el poste con hacia donde queda cada sitio importante. Se va solo a los
#  pocos segundos o en cuanto te alejas. Lo pidio el usuario al crecer el pueblo: con la arena en el
#  barrio norte ya no se ve desde la plaza a donde hay que ir.
# ============================================================
extends Node2D

const DURACION := 6.0
# Mas lejos que esto (px) y el globo se cierra: ya no estas leyendo el cartel.
const LEJOS := 90.0
const FLECHAS := {"n": "↑", "s": "↓", "e": "→", "o": "←"}

# [texto, lado] (ver PuebloPlano.CARTELES). Lo rellena town.gd antes de meterlo en el arbol.
var destinos: Array = []

# POR ENCIMA DE LAS CASAS. El globo sale a la altura de los tejados, y un tejado va a
# PiezaPueblo.Z_ENCIMA (3700): con la z de los letreros del mundo (Game.Z_LETRERO = 1) el tejado le
# comia el principio de cada linea y se leia "de pruebas" en vez de "Arena de pruebas" (playtest del
# 23/09). No se usa Game.elevar_letrero a proposito: esa es para los NOMBRES del mundo, que el usuario
# quiere por debajo de los personajes. Esto es un cartel que estas leyendo, y se lee entero.
# Por debajo de los numeros de combate (4000) y de los retratos (4096).
const Z_GLOBO := PiezaPueblo.Z_ENCIMA + 5

var _globo: PanelContainer = null
var _texto: Label = null
var _queda: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	set_process(false)


func texto_interaccion() -> String:
	return "Leer el cartel"


func interact_with_player() -> void:
	if _globo == null:
		# CON FONDO, no solo contorno: sobre la piedra clara de la plaza el texto pelado se perdia.
		_globo = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.10, 0.92)
		sb.border_color = Color(0.87, 0.57, 0.26, 0.7)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		_globo.add_theme_stylebox_override("panel", sb)
		_globo.z_as_relative = false
		_globo.z_index = Z_GLOBO
		_globo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texto = Label.new()
		_texto.add_theme_font_size_override("font_size", 11)
		_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_globo.add_child(_texto)
		add_child(_globo)
	var lineas: PackedStringArray = []
	for d in destinos:
		lineas.append("%s  %s" % [FLECHAS.get(String(d[1]), ""), String(d[0])])
	_texto.text = "\n".join(lineas)
	# Del PanelContainer, que es quien manda el tamaño: el Label de dentro aun mide lo de la vez
	# anterior y el globo saldria descentrado.
	_globo.reset_size()
	# Centrado encima del poste, que mide unos 60 px de alto.
	_globo.position = Vector2(-_globo.size.x * 0.5, -64.0 - _globo.size.y)
	_globo.visible = true
	_queda = DURACION
	set_process(true)


func _process(delta: float) -> void:
	_queda -= delta
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var lejos: bool = jugador != null and jugador.global_position.distance_to(global_position) > LEJOS
	if _queda <= 0.0 or lejos:
		_globo.visible = false
		set_process(false)
