extends Node2D

# Puerta de viaje entre pueblo y mazmorra
# Auto-detecta la escena actual y viaja a la otra

@export var town_path: String = "res://scenes/levels/town.tscn"
@export var dungeon_path: String = "res://scenes/levels/main.tscn"

var _destination: String = ""

func _ready() -> void:
	add_to_group("interactable")
	# En la mazmorra esta puerta ES la vuelta al pueblo del piso 1, asi que va a la libreta como
	# tal (Game.capturar_mapa). En el pueblo tambien entra al grupo, pero alli no hay mapa que
	# capturar. En los pisos 2+ se aparta a la quinta puñeta (ver DungeonFloor._colocar_actores):
	# su celda cae fuera del mapa, la libreta la descarta sola y no hace falta comprobarlo aqui.
	add_to_group("salida_pueblo")
	_detectar_destino()


func _detectar_destino() -> void:
	var scene: String = get_tree().current_scene.scene_file_path
	if scene.contains("town"):
		_destination = dungeon_path
	else:
		_destination = town_path


func interact_with_player() -> void:
	# MULTIJUGADOR (hito 3b): la expedicion es COMPARTIDA y la coordina Net. El primero que
	# entra la abre (piso 1); el que llega despues se une al piso activo tal cual (sin resetear
	# nada al que ya esta dentro); el ultimo que sale la cierra. Los atajos por piso quedan
	# para mas adelante en multi.
	if Net.activo:
		if _destination == dungeon_path:
			Net.solicitar_entrar()
		else:
			# Volver a casa con vida: se captura el mapa de la expedicion, pero al PERMANENTE
			# solo lo comete el HOST — la mazmorra es de SU mundo; la libreta del save del
			# cliente no debe llenarse de planos de un mundo ajeno.
			Game.capturar_mapa()
			if Net.es_host:
				Game.comprometer_mapa()
			Net.viajar_al_pueblo()
		return
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
		# Baseline del mapa: lo que cartografies esta expedicion se pierde si mueres.
		Game.iniciar_expedicion_mapa()
	else:
		# Volviendo a CASA CON VIDA: se captura el piso actual y se COMETE al permanente todo lo
		# cartografiado esta expedicion (ver Game). Es el unico momento en que el mapa se consolida.
		Game.capturar_mapa()
		Game.comprometer_mapa()
	print("[Puerta] Viajando a: %s" % _destination)
	get_tree().change_scene_to_file(_destination)
