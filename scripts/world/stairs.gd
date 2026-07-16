# ============================================================
#  stairs.gd
#  ESCALERA entre pisos. Interactuable con F (grupo "interactable"), como la puerta.
#   - BAJAR: en la sala mas lejana a la entrada, asi que descender obliga a cruzar la
#     mazmorra entera.
#   - SUBIR: en la sala de entrada, y solo a partir del piso 2. En el piso 1 ese sitio lo
#     ocupa la puerta al pueblo: el pueblo esta en la BOCA de la mazmorra, no en cada piso.
#  Aspecto placeholder por codigo; el arte va al final.
# ============================================================

extends Node2D

var sube: bool = false   # false = baja un piso; true = sube uno


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("escalera")   # para que la libreta (Game.capturar_mapa) las cartografie
	_crear_aspecto()


func interact_with_player() -> void:
	if sube:
		Game.subir_piso()
	else:
		Game.bajar_piso()


func _crear_aspecto() -> void:
	var cr := ColorRect.new()
	cr.color = Color(0.55, 0.8, 0.35) if sube else Color(0.1, 0.7, 0.85)
	cr.offset_left = -18.0
	cr.offset_top = -18.0
	cr.offset_right = 18.0
	cr.offset_bottom = 18.0
	add_child(cr)

	var lbl := Label.new()
	lbl.text = "↑ SUBIR\n[F]" if sube else "↓ BAJAR\n[F]"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.offset_left = -34.0
	lbl.offset_top = -40.0
	lbl.offset_right = 34.0
	lbl.offset_bottom = -14.0
	add_child(lbl)
