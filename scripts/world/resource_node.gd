# ============================================================
#  resource_node.gd
#  Lo que se RECOLECTA en el mapa: una VETA (pegada a la pared de una sala), una PLANTA
#  (en un pasillo) o una ENREDADERA de la que sacar MADERA (trepando la pared del pasillo).
#  Se interactua con F, abre su minijuego y suelta el material.
#
#  NO tiene colision a proposito: no quiero que una planta te tape un pasillo de 3 celdas
#  ni que una veta te empuje contra la pared. Estorbar no es interesante; decidir si te
#  paras a picar con bichos deambulando, si.
#
#  Grupo propio "recolectable" (y no "interactable"): en player._try_interact los
#  interactuables van ANTES que los cadaveres, asi que una veta en el grupo equivocado
#  volveria inextraible al bicho que muriese encima de ella.
#
#  Una vez agotado se desvanece, y su CELDA se apunta en la memoria del piso: al volver,
#  la veta picada no reaparece entera (ver dungeon_floor).
#  Aspecto placeholder por codigo; el arte va al final.
# ============================================================

extends Node2D

# MADERA va la ULTIMA: dungeon_floor pasa el tipo como numero (0 veta, 1 planta, 2 madera).
enum Tipo { VETA, PLANTA, MADERA }

var tipo: int = Tipo.VETA
# OJO con el nombre: NO puede llamarse 'material'. Esto es un Node2D, y CanvasItem ya tiene
# una propiedad 'material' (la del shader): declararla aqui la pisa y Godot ni compila.
var material_data: MaterialData = null
var celda: Vector2i = Vector2i.ZERO
var agotado: bool = false
# Nace con un fundido de entrada en vez de aparecer de golpe. Lo pone DungeonFloor cuando el nodo
# viene del RESPAWN en vivo (puede brotar delante de tus narices); al generar el piso, no.
var brotando: bool = false

var _rect: ColorRect = null
var _lbl: Label = null


func _ready() -> void:
	add_to_group("recolectable")
	_crear_aspecto()
	# Espejo de agotar(): el que vuelve por respawn entra con el mismo fundido con el que se fue.
	if brotando:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.45)


func es_veta() -> bool:
	return tipo == Tipo.VETA

func es_madera() -> bool:
	return tipo == Tipo.MADERA


# Lo llama el jugador al pulsar F (ver player._try_interact).
func interactuar() -> void:
	if agotado or material_data == null:
		return
	if es_veta():
		Game.start_mineria(self)
	elif es_madera():
		Game.start_talado(self)
	else:
		Game.start_herboristeria(self)


# Ya lo has sacado: se desvanece. Quien avisa a la memoria del piso es Game (que sabe
# en que piso estamos), no el nodo.
func agotar() -> void:
	agotado = true
	remove_from_group("recolectable")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)


func _crear_aspecto() -> void:
	var color: Color = material_data.color if material_data != null else Color(0.7, 0.7, 0.7)

	_rect = ColorRect.new()
	if es_veta():
		# La veta es un bulto en la roca: ancha y baja.
		_rect.size = Vector2(26, 18)
		_rect.position = Vector2(-13, -9)
	elif es_madera():
		# La enredadera TREPA por el muro: muy alta y muy estrecha. Se distingue de la planta
		# de un vistazo, que es lo unico que le pido a un placeholder.
		_rect.size = Vector2(10, 34)
		_rect.position = Vector2(-5, -26)
	else:
		# La planta es un manojo: estrecha y alta.
		_rect.size = Vector2(14, 22)
		_rect.position = Vector2(-7, -14)
	_rect.color = color
	add_child(_rect)

	_lbl = Label.new()
	_lbl.text = "[F]"
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 10)
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl.add_theme_constant_override("outline_size", 3)
	_lbl.offset_left = -20.0
	_lbl.offset_top = -32.0
	_lbl.offset_right = 20.0
	_lbl.offset_bottom = -16.0
	add_child(_lbl)
