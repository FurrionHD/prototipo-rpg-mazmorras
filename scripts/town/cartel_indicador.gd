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

var _globo: Label = null
var _queda: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	set_process(false)


func texto_interaccion() -> String:
	return "Leer el cartel"


func interact_with_player() -> void:
	if _globo == null:
		_globo = Label.new()
		_globo.add_theme_font_size_override("font_size", 11)
		_globo.add_theme_color_override("font_outline_color", Color.BLACK)
		_globo.add_theme_constant_override("outline_size", 4)
		_globo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		Game.elevar_letrero(_globo)
		add_child(_globo)
	var lineas: PackedStringArray = []
	for d in destinos:
		lineas.append("%s  %s" % [FLECHAS.get(String(d[1]), ""), String(d[0])])
	_globo.text = "\n".join(lineas)
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
