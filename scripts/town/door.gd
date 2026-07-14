extends Node2D

# Puerta de viaje entre pueblo y mazmorra
# Auto-detecta la escena actual y viaja a la otra

@export var town_path: String = "res://scenes/levels/town.tscn"
@export var dungeon_path: String = "res://scenes/levels/main.tscn"

var _destination: String = ""

func _ready() -> void:
	add_to_group("interactable")
	_detectar_destino()


func _detectar_destino() -> void:
	var scene: String = get_tree().current_scene.scene_file_path
	if scene.contains("town"):
		_destination = dungeon_path
	else:
		_destination = town_path


func interact_with_player() -> void:
	# Entrar a la mazmorra = EXPEDICION NUEVA: siempre se empieza por el piso 1. La
	# profundidad vive en el autoload Game y no se reinicia sola, asi que al volver al
	# pueblo y reentrar te quedabas en el ultimo piso al que habias bajado.
	if _destination == dungeon_path:
		# Si hay ATAJOS abiertos (cada boss derrotado abre el suyo), se elige por donde entras.
		# Con solo el piso 1 desbloqueado no hay nada que preguntar: se entra y punto.
		var menu: Node = get_tree().get_first_node_in_group("floor_menu")
		if Game.pisos_desbloqueados().size() > 1 and menu != null and menu.has_method("abrir"):
			menu.abrir()
			return
		Game.current_floor = 1
		# Y la mazmorra se repuebla: lo que dejaste en los pisos la expedicion anterior ya no
		# esta. Si se recordara entre expediciones, los pisos se vaciarian para siempre.
		Game.olvidar_mazmorra()
	else:
		# Volviendo a CASA: se pone al dia la libreta del mapa con lo explorado (ver Game).
		Game.capturar_mapa()
	print("[Puerta] Viajando a: %s" % _destination)
	get_tree().change_scene_to_file(_destination)
