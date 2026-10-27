extends Node2D

# Puerta de viaje entre pueblo y mazmorra
# Auto-detecta la escena actual y viaja a la otra

@export var town_path: String = "res://scenes/levels/town.tscn"
@export var dungeon_path: String = "res://scenes/levels/main.tscn"

var _destination: String = ""

# Cuanto se descuenta de la distancia al jugador (ver player._mas_cercano_en_grupo). En la mazmorra es
# 0; la ESCALERA DE CARACOL del pueblo mide 3x3 y pone aqui su medio lado, para que la F valga desde
# cualquiera de sus cuatro lados (lo pidio el usuario) y no solo desde la boca.
var radio_extra: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	# En la mazmorra esta puerta ES la vuelta al pueblo del piso 1, asi que va a la libreta como
	# tal (Game.capturar_mapa). En el pueblo tambien entra al grupo, pero alli no hay mapa que
	# capturar. En los pisos 2+ se aparta a la quinta puñeta (ver DungeonFloor._colocar_actores):
	# su celda cae fuera del mapa, la libreta la descarta sola y no hace falta comprobarlo aqui.
	add_to_group("salida_pueblo")
	# Su letrero ("← PUEBLO" en la mazmorra) viene de la escena: se sube por encima de los personajes
	# como el resto de letreros del mundo (Game.elevar_letrero).
	var letrero: Label = get_node_or_null("Sprite/Label") as Label
	if letrero != null:
		Game.elevar_letrero(letrero)
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
	# EN LA ARENA la salida es un PORTON (el mismo del pueblo, lo dibuja DungeonFloor._construir_arena en
	# la pared), no una escalera: se vuelve por donde se entro.
	if Game.es_arena():
		viejo.color = Color(0, 0, 0, 0)
		var lb: Label = viejo.get_node_or_null("Label") as Label
		if lb != null:
			lb.visible = false
		radio_extra = 24.0
		return
	# UNA ESCALERA DE CARACOL QUE SUBE, gemela de la que baja desde la plaza (lo pidio el usuario), con
	# el centro del pozo en este nodo. Es la misma que la salida de los pisos de jefe (dungeon_exit.gd).
	EscaleraSprites.montar(self, "caracol")
	# Choca como un pozo de 40 de radio: la F tiene que llegar desde cualquier lado (ver radio_extra).
	radio_extra = EscaleraSprites.C_PRETIL_R
	# El Label cuelga del ColorRect, asi que este se queda (invisible) para no dejarlo huerfano, y se sube
	# por encima de la columna.
	viejo.color = Color(0, 0, 0, 0)
	viejo.position.y = -80.0


func _detectar_destino() -> void:
	var scene: String = get_tree().current_scene.scene_file_path
	if scene.contains("town"):
		_destination = dungeon_path
	else:
		_destination = town_path


# Lo que dice el boton flotante del HUD al tenerlo a mano (ver player.texto_interaccion).
func texto_interaccion() -> String:
	if Game.es_arena() and _destination == town_path:
		return "Volver al pueblo"
	return "Bajar a la mazmorra" if _destination == dungeon_path else "Salir al pueblo"


func interact_with_player() -> void:
	# LA ARENA: se sale sin mapa que guardar ni piso que congelar, y todo lo tuyo vuelve a como estaba
	# al entrar (ver Game.salir_de_arena).
	if Game.es_arena() and _destination == town_path:
		Game.salir_de_arena()
		Net.pisos.viajar_al_pueblo()
		return
	# MULTIJUGADOR (hito 3b): la expedicion es COMPARTIDA y la coordina Net. El primero que
	# entra la abre; el que llega despues se une sin resetear nada al que ya esta dentro; el ultimo
	# que sale la cierra. Los ATAJOS tambien valen aqui (ver Game.pisos_desbloqueados): si hay mas
	# de uno, se elige por donde entras. Quien ejecuta el viaje es Net.pisos.solicitar_entrar(piso),
	# que es el que reparte los dueños de piso.
	if _destination == dungeon_path:
		var menu: Node = get_tree().get_first_node_in_group("floor_menu")
		if Game.pisos_desbloqueados().size() > 1 and menu != null and menu.has_method("abrir"):
			menu.abrir()
			return
		Net.pisos.solicitar_entrar()
	else:
		# Volver a casa con vida: se captura el mapa y se COMETE, lo seas o no host. comprometer_mapa
		# distingue por dentro y en sesion NO escribe en tu save, se lo manda al host para que lo fusione y
		# te devuelva la libreta entera.
		Game.capturar_mapa()
		Game.comprometer_mapa()
		Net.pisos.viajar_al_pueblo()
