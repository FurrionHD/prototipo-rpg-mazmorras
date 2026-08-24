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
	_vestir()


# El ColorRect marron de la escena pasa a ser la puerta dibujada, PERO solo en la mazmorra: ahi
# esta puerta es la SALIDA al pueblo. En el pueblo la misma escena usa este script para la puerta
# de ENTRADA a la mazmorra, que pide otro dibujo (y el pase visual del pueblo va aparte).
func _vestir() -> void:
	if _destination != town_path:
		return
	var viejo: ColorRect = get_node_or_null("Sprite") as ColorRect
	if viejo == null:
		return
	var t: Vector2i = PropSprites.tam("puerta_pueblo")
	var s := Sprite2D.new()
	s.texture = PropSprites.textura("puerta_pueblo")
	# POR NODO, que el proyecto no lo pone globalmente (misma nota que en enemy.gd).
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	# Se apoya donde se apoyaba el rectangulo viejo: mismo pie, mismo centro. Asi no se mueve
	# respecto a la celda ni respecto al Label, que sigue colgando del padre.
	s.position = Vector2(-float(t.x) * 0.5, viejo.offset_bottom - float(t.y))
	add_child(s)
	# El Label cuelga del ColorRect, asi que este se queda (invisible) para no dejarlo huerfano.
	viejo.color = Color(0, 0, 0, 0)


func _detectar_destino() -> void:
	var scene: String = get_tree().current_scene.scene_file_path
	if scene.contains("town"):
		_destination = dungeon_path
	else:
		_destination = town_path


func interact_with_player() -> void:
	# MULTIJUGADOR (hito 3b): la expedicion es COMPARTIDA y la coordina Net. El primero que
	# entra la abre; el que llega despues se une sin resetear nada al que ya esta dentro; el ultimo
	# que sale la cierra. Los ATAJOS tambien valen aqui: el menu es el mismo que en solitario y la
	# lista ya incluye los del mundo del host (ver Game.pisos_desbloqueados). Lo que cambia es quien
	# ejecuta el viaje: Net.solicitar_entrar(piso), que es el que reparte los dueños de piso.
	if Net.activo:
		if _destination == dungeon_path:
			var menu_net: Node = get_tree().get_first_node_in_group("floor_menu")
			if Game.pisos_desbloqueados().size() > 1 and menu_net != null and menu_net.has_method("abrir"):
				menu_net.abrir()
				return
			Net.solicitar_entrar()
		else:
			# Volver a casa con vida: se captura el mapa y se COMETE, lo seas o no host. El gate
			# "solo el host" que habia aqui sobraba: comprometer_mapa ya distingue por dentro y en
			# sesion NO escribe en tu save, se lo manda al host para que lo fusione y te devuelva la
			# libreta entera. Con el gate, el invitado no subia nunca lo suyo NI recibia lo del host,
			# asi que su mapa solo cambiaba al reconectar.
			Game.capturar_mapa()
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
		# NO se llama a Game.olvidar_mazmorra(): la mazmorra SIGUE ABIERTA entre bajadas. Volver al
		# pueblo a vender y bajar otra vez te encuentra los pisos como los dejaste, y —lo que se
		# pedia— lo que se te cayo al suelo en el piso 4 sigue ahi esperandote.
		# Lo que SI la cierra: morir (Game.morir_jugador), salir por la puerta del jefe
		# (dungeon_exit) y cerrar el juego (al cargar solo vuelve el piso que estabas pisando, ver
		# Game.cargar). Los jefes ya no dependen de esto para volver: reaparecen por tiempo
		# (Game.BOSS_RESPAWN).
		# Baseline del mapa: lo que cartografies esta expedicion se pierde si mueres.
		Game.iniciar_expedicion_mapa()
	else:
		# Volviendo a CASA CON VIDA: se captura el piso actual y se COMETE al permanente todo lo
		# cartografiado esta expedicion (ver Game). Es el unico momento en que el mapa se consolida.
		Game.capturar_mapa()
		Game.comprometer_mapa()
		# Y se cierra la BAJADA (no la mazmorra): el piso que dejas se congela tal cual —es lo que te
		# vas a encontrar al bajar otra vez— y se apaga el alboroto. Ver Game.cerrar_bajada.
		Game.cerrar_bajada()
	print("[Puerta] Viajando a: %s" % _destination)
	get_tree().change_scene_to_file(_destination)
