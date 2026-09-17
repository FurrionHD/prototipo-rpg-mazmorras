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
	add_to_group("salida_pueblo")   # para que la libreta (Game.capturar_mapa) la cartografie
	_crear_aspecto()


# Lo que dice el boton flotante del HUD al tenerlo a mano (ver player.texto_interaccion).
func texto_interaccion() -> String:
	return "Volver al pueblo"


func interact_with_player() -> void:
	# Salir por aqui es lo MISMO que salir por la boca de la mazmorra (ver door.gd): la mazmorra NO se
	# olvida, los pisos siguen como los dejaste y lo que se te cayo por el suelo sigue ahi. Antes esto
	# llamaba a Game.olvidar_mazmorra() y era la puerta la que hacia respawnear al jefe; ahora el jefe
	# vuelve por reloj (Game.BOSS_RESPAWN) y esta puerta solo es un atajo a casa.
	# La libreta del mapa se consolida ANTES de tocar current_floor: captura el piso del boss en el
	# que estas (no el 1 al que vas a saltar) y COMETE al permanente lo cartografiado esta bajada.
	Game.capturar_mapa()
	# MULTIJUGADOR: salir YO no termina la expedicion si queda gente dentro; se avisa al host
	# y el decide (el ultimo en salir la cierra). El viaje lo hace Net. Se comete el mapa seas o no
	# host: comprometer_mapa ya distingue por dentro y en sesion no escribe en tu save (ver door.gd).
	if Net.activo:
		Game.comprometer_mapa()
		Net.pisos.viajar_al_pueblo()
		return
	Game.comprometer_mapa()
	Game.cerrar_bajada()   # el piso del jefe queda como lo dejas, y el alboroto se apaga (ver Game)
	Game.current_floor = 1
	print("[salida] Vuelves al pueblo desde el piso del boss.")
	get_tree().change_scene_to_file(TOWN)


# La F desde cualquier lado de la caracol (ver player._mas_cercano_en_grupo), como la de la plaza.
var radio_extra: float = EscaleraSprites.C_PRETIL_R


func _crear_aspecto() -> void:
	# La misma que la salida del piso 1 (door.gd): las dos llevan al pueblo, asi que se leen igual. Una
	# ESCALERA DE CARACOL QUE SUBE, gemela de la que baja desde la plaza (lo pidio el usuario).
	EscaleraSprites.montar(self, "caracol")

	var lbl := Label.new()
	lbl.text = "↩ PUEBLO"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Por encima de la columna, que asoma ~60 px sobre el centro del pozo.
	lbl.offset_left = -40.0
	lbl.offset_top = -92.0
	lbl.offset_right = 40.0
	lbl.offset_bottom = -66.0
	Game.elevar_letrero(lbl)
	add_child(lbl)
