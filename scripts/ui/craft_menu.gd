# ============================================================
#  craft_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de RECETAS con los materiales del baul del Hogar. Sirve a DOS talleres, y el que sea lo
#  decide `modo` (ver MODOS abajo), que se le pone al instanciarlo desde player.gd:
#    POCIONES -> la BOTICARIA (boticaria.gd). Tiers Menores/Medianas x tipo Vida/Maná/Antídotos, con
#                mejoras que consumen la poción del escalon anterior. Oficio: MEZCLA.
#    COCINA   -> el COCINERO (cocinero.gd). Tiers T1/T2, sin sub-tipo y sin mejoras. Oficio: COCINA.
#  Van en el mismo archivo porque comparten TODO lo que cuesta: los contadores de calidad por
#  ingrediente, las reservas de multijugador y el calculo de cuantas piezas salen. Lo unico
#  distinto entre los dos son las pestañas, los textos y de donde salen las recetas.
#
#  Lo abre su NPC del pueblo (-> abrir()). No hay tecla propia: se entra por el NPC.
#
#  REHECHO el 16/09/2026 con la cara del inventario, igual que la peleteria: rejilla de celdas a la
#  izquierda (cada celda es LO QUE SALE: la poción o el plato), ficha ancha a la derecha y los botones
#  en un pie fijo debajo de ella. Arriba, las pestañas son los TIERS; encima de la rejilla, en las
#  pociones, el filtro Todo / Vida / Maná / Antídotos.
#
#  El montaje es de la BASE de los talleres (taller_menu.gd); la pantalla de recetas vive en
#  scripts/ui/taller/taller_recetas.gd. Toda la MATH sigue en Game.
# ============================================================

extends "res://scripts/ui/taller_menu.gd"

const TallerRecetas = preload("res://scripts/ui/taller/taller_recetas.gd")

# Que oficio es este menu. Se le pone ANTES de meterlo al arbol (player.gd), porque _ready() ya lo
# usa para elegir su grupo y su titulo.
enum Modo { POCIONES, COCINA }
var modo: int = Modo.POCIONES

func es_cocina() -> bool: return modo == Modo.COCINA

# El OFICIO de este taller: el id de su desarrollo, que es tambien la clave de su artesano.
func oficio() -> String: return "cocina" if es_cocina() else "mezcla"

# La PIEZA que sale de una receta, en singular y plural, para no escribir "poción" en un menu que
# esta haciendo un kebab.
func pieza_txt(n: int = 1) -> String:
	if es_cocina():
		return "plato" if n == 1 else "platos"
	return "poción" if n == 1 else "pociones"

# Las pestañas de arriba son los TIERS, con icono y sin texto (el nombre se lee arriba a la izquierda).
func tabs() -> Array:
	return ["De la cueva", "De lo hondo"] if es_cocina() else ["Menores", "Medianas"]
const TAB_ICONOS := ["tier_1", "tier_2"]

# EL REPARTO DEL ANCHO, que cambia con el taller. Una columna de ingrediente con sus contadores mide
# unos 280 px, y eso manda:
#   - POCIONES: la rejilla son diez recetas y con cuatro columnas cada fila es una cadena (base, +1,
#     +2, +3). La ficha lleva los ingredientes en DOS columnas (ver taller_recetas.COLUMNAS_ING): las
#     pociones llevan dos, y el antidoto que lleva tres pone el tercero debajo.
#   - COCINA: un plato lleva hasta SEIS ingredientes y van en TRES columnas. Con la rejilla a 420 la
#     tercera se salia por el canto de la pantalla, y con la rejilla a 300 el cuarto retrato de QUIEN
#     TRABAJA quedaba cortado (vistos los dos en captura): 330 es lo que piden cuatro retratos.
const ANCHO_FICHA_POCIONES := 780.0
const ANCHO_FICHA_COCINA := 875.0
const ANCHO_REJILLA_COCINA := 330.0

var recetas = null   # TallerRecetas

# La pestaña: 1 menores / de la cueva, 2 medianas / de lo hondo. Es _tab + 1.
var tier: int:
	get: return _tab + 1
	set(v): _tab = v - 1


func _ready() -> void:
	add_to_group("cocina_menu" if es_cocina() else "craft_menu")
	recetas = TallerRecetas.new(self)
	montar("Cocina" if es_cocina() else "Boticaria", tabs(), TAB_ICONOS,
		ANCHO_REJILLA_COCINA if es_cocina() else ANCHO_REJILLA_MIN,
		ANCHO_FICHA_COCINA if es_cocina() else ANCHO_FICHA_POCIONES)


func abrir() -> void:
	# MULTI: no se coge el candado al abrir (los dos a la vez); se coge solo al fabricar, y lo
	# seleccionado se RESERVA para el otro. Ver forge_menu.
	_tab = 0
	recetas.abrir()
	abrir_taller()


func _al_cambiar_pantalla() -> void:
	recetas.cambio_de_receta()


func _al_elegir_otra() -> void:
	recetas.cambio_de_receta()


func _pintar() -> void:
	# Las MEDIANAS solo salen cuando has conseguido algun material para hacerlas; la cocina enseña sus
	# dos tiers desde el primer dia (verlo es la mitad de la gracia: te dice a que sabe seguir bajando).
	var hay_t2: bool = es_cocina() or Game.medianas_desbloqueadas()
	if tier >= 2 and not hay_t2:
		tier = 1
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		b.button_pressed = (i + 1 == tier)
		# Con UNA sola pestaña no hay nada que elegir: fuera la barra entera.
		b.visible = hay_t2
	_titulo_seccion.text = tabs()[tier - 1]
	pintar_artesanos(oficio(), "cuenco" if es_cocina() else "pocion",
		"Tiene Cocina" if es_cocina() else "Tiene Mezcla")
	recetas.build()
