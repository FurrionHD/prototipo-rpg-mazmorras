# ============================================================
#  dungeon_exit.gd
#  SALIDA AL PUEBLO dentro de la mazmorra. Solo existe en los pisos con BOSS, y solo DESPUES
#  de matarlo: es el premio del boss, y va justo al lado de la bajada.
#
#  El sentido es que un piso de boss deja de ser el fondo de un pozo. Antes, para volver del
#  piso 5 habia que desandar cinco pisos; ahora se sale de un paso... pero solo el que ha
#  matado al que guardaba la puerta.
#
#  No reutiliza door.gd porque ese nodo vive en las escenas (con su ColorRect y su Label
#  puestos a mano) y aqui hay que crearlo por codigo, con su propio aspecto.
# ============================================================

extends Node2D

const TOWN := "res://scenes/levels/town.tscn"


func _ready() -> void:
	add_to_group("interactable")
	_crear_aspecto()


func interact_with_player() -> void:
	# Salir al pueblo TERMINA la expedicion, igual que salir por la boca de la mazmorra: la
	# proxima vez que entres, los pisos estan repoblados. Lo que NO se pierde es el hito del
	# boss (Game.bosses_derrotados), que vive en la partida y no en la memoria de la mazmorra.
	Game.current_floor = 1
	Game.olvidar_mazmorra()
	print("[salida] Vuelves al pueblo desde el piso del boss.")
	get_tree().change_scene_to_file(TOWN)


func _crear_aspecto() -> void:
	var cr := ColorRect.new()
	cr.color = Color(0.9, 0.72, 0.3)
	cr.offset_left = -18.0
	cr.offset_top = -18.0
	cr.offset_right = 18.0
	cr.offset_bottom = 18.0
	add_child(cr)

	var lbl := Label.new()
	lbl.text = "↩ PUEBLO\n[F]"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.offset_left = -40.0
	lbl.offset_top = -40.0
	lbl.offset_right = 40.0
	lbl.offset_bottom = -14.0
	add_child(lbl)
