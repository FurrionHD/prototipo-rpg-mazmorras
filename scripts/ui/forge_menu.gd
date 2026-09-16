# ============================================================
#  forge_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de la HERRERIA y de la CARPINTERIA: el mismo armazon, y el taller lo decide `modo`, que se fija
#  ANTES de add_child (ver player.gd).
#
#  HERRERIA (8 pestañas):
#    Fundir, Chapas, Hebillas  - refinar metal (herreria_refinar.gd)
#    Forjar                    - armas, secundarias y armaduras de metal (herreria_forjar.gd)
#    Herramientas              - pico, hoz, hacha, caña, farolillo, cuchillo (herreria_herramientas.gd)
#    Mejorar, Deshacer, Reparar - el mostrador de TODO el equipo (herreria_mejorar/deshacer/reparar.gd)
#  CARPINTERIA (3 pestañas):
#    Tablones, Carbonera       - refinar madera
#    Forjar                    - baston y varita
#
#  REHECHA el 16/09/2026 con la cara del inventario, la ultima de los oficios: pestañas con icono,
#  quien trabaja, rejilla de celdas (la celda es LO QUE SALE) y ficha con pie fijo. El montaje es la
#  BASE de los talleres (taller_menu.gd). Toda la MATH sigue en Game/Forge.
#
#  El oficio es UNO por taller: Herreria (que desde el 16/09 incluye lo que era la Metalurgia) o
#  Carpinteria, y lo pone el artesano que elijas. La armadura de CUERO ya no se forja aqui: se cose en
#  la peleteria (aunque se mejora, se deshace y se repara aqui, como todo el equipo).
# ============================================================

extends "res://scripts/ui/taller_menu.gd"

const HerreriaRefinar = preload("res://scripts/ui/herreria/herreria_refinar.gd")
const HerreriaForjar = preload("res://scripts/ui/herreria/herreria_forjar.gd")
const HerreriaHerramientas = preload("res://scripts/ui/herreria/herreria_herramientas.gd")
const HerreriaMejorar = preload("res://scripts/ui/herreria/herreria_mejorar.gd")
const HerreriaDeshacer = preload("res://scripts/ui/herreria/herreria_deshacer.gd")
const HerreriaReparar = preload("res://scripts/ui/herreria/herreria_reparar.gd")

@export var modo: String = "herrero"   # "herrero" | "carpintero"

# Las pestañas van por ID: cada taller enseña las suyas sin romper el reparto de _pintar.
const TABS_HERRERO := [
	{"id": "fundir", "nombre": "Fundir", "icono": "mineral"},
	{"id": "chapas", "nombre": "Chapas", "icono": "chapa"},
	{"id": "hebillas", "nombre": "Hebillas", "icono": "hebilla"},
	{"id": "forjar", "nombre": "Forjar", "icono": "espada"},
	{"id": "herramientas", "nombre": "Herramientas", "icono": "pico"},
	{"id": "mejorar", "nombre": "Mejorar", "icono": "flecha_arriba"},
	{"id": "deshacer", "nombre": "Deshacer", "icono": "deshacer"},
	{"id": "reparar", "nombre": "Reparar", "icono": "martillo"},
]
const TABS_CARPINTERO := [
	{"id": "tablones", "nombre": "Tablones", "icono": "tablon"},
	{"id": "carbonera", "nombre": "Carbonera", "icono": "carbon"},
	{"id": "forjar", "nombre": "Forjar", "icono": "baston"},
]
# La ficha de forjar lleva los ingredientes en columnas y la tabla de rareza: pide el ancho. En las de
# refinar la rejilla son muchos montones y la ficha, cuatro lineas.
const ANCHO_FICHA_ANCHA := 780.0

var refinar = null
var forjar = null
var herramientas = null
var mejorar = null
var deshacer = null
var reparar = null

# MULTI: lo que MI seleccion tiene apartado. Se junta durante el repintado y se publica UNA sola vez al
# final. Publicar dos veces por repintado (soltar al empezar y volver a pedir) colgaba a los clientes:
# cada respuesta llegaba en otro fotograma, pedia otro repintado y el trafico se doblaba solo.
var _claim_reserva: Dictionary = {}


func _es_carpintero() -> bool:
	return modo == "carpintero"


func _tabs() -> Array:
	return TABS_CARPINTERO if _es_carpintero() else TABS_HERRERO


func _oficio() -> String:
	return "carpinteria" if _es_carpintero() else "herreria"


# El id de la pestaña abierta.
func tab_id() -> String:
	return String(_tabs()[clampi(_tab, 0, _tabs().size() - 1)]["id"])


func nombre_tab() -> String:
	return String(_tabs()[clampi(_tab, 0, _tabs().size() - 1)]["nombre"])


func _ready() -> void:
	add_to_group("carpinteria_menu" if _es_carpintero() else "forge_menu")
	refinar = HerreriaRefinar.new(self)
	forjar = HerreriaForjar.new(self,
		HerreriaForjar.Catalogo.CARPINTERIA if _es_carpintero() else HerreriaForjar.Catalogo.HERRERIA)
	herramientas = HerreriaHerramientas.new(self)
	mejorar = HerreriaMejorar.new(self)
	deshacer = HerreriaDeshacer.new(self)
	reparar = HerreriaReparar.new(self)
	var nombres: Array = []
	var iconos: Array = []
	for tb in _tabs():
		nombres.append(tb["nombre"])
		iconos.append(tb["icono"])
	montar("Carpintería" if _es_carpintero() else "Herrería", nombres, iconos)


func abrir() -> void:
	# MULTI: no se coge el candado al abrir (los dos a la vez); se coge solo el instante de crear, y lo
	# seleccionado se RESERVA para el otro.
	_tab = 0
	forjar.limpiar()
	herramientas.limpiar()
	abrir_taller()


func _al_cerrar() -> void:
	forjar.vaciar_vitrina()
	herramientas.vaciar_vitrina()


func _al_cambiar_pantalla() -> void:
	forjar.limpiar()
	herramientas.limpiar()


# Otra celda = otra pieza = otro coste: lo elegido antes ya no vale.
func _al_elegir_otra() -> void:
	forjar.limpiar()
	herramientas.limpiar()


func reservar(claim: Dictionary) -> void:
	_claim_reserva = claim


func _pintar() -> void:
	_claim_reserva = {}
	var id: String = tab_id()
	_titulo_seccion.text = nombre_tab()
	var ancha: bool = id in ["forjar", "herramientas", "mejorar", "deshacer", "reparar"]
	anchos(ANCHO_REJILLA_MIN, ANCHO_FICHA_ANCHA if ancha else ANCHO_FICHA)
	# QUIEN TRABAJA solo donde hay oficio: mejorar, deshacer y reparar no entrenan nada.
	if id in ["mejorar", "deshacer"]:
		pintar_artesanos("", "", "")
	elif id != "reparar":
		pintar_artesanos(_oficio(), "hacha" if _es_carpintero() else "martillo",
			"Tiene Carpintería" if _es_carpintero() else "Tiene Herrería")
	match id:
		"fundir": refinar.build(HerreriaRefinar.Que.FUNDIR)
		"chapas": refinar.build(HerreriaRefinar.Que.CHAPAS)
		"hebillas": refinar.build(HerreriaRefinar.Que.HEBILLAS)
		"tablones": refinar.build(HerreriaRefinar.Que.TABLONES)
		"carbonera": refinar.build(HerreriaRefinar.Que.CARBON)
		"forjar": forjar.build()
		"herramientas": herramientas.build()
		"mejorar": mejorar.build()
		"deshacer": deshacer.build()
		"reparar": reparar.build()
	# Y AQUI, una sola vez, ya con la pestaña pintada. Va al final a proposito: que una pantalla se corte
	# antes de tiempo no puede dejarme material apartado a espaldas del compañero.
	if Net.activo:
		Net.hogar.reservar(_claim_reserva)
