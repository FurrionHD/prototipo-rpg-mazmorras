# ============================================================
#  tannery_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de la PELETERIA. Tres pestañas:
#    1) CURTIR   - cuero crudo -> CUERO CURTIDO (lo unico que admite la forja).
#    2) CORREAS  - cuero curtido -> CORREAS (los tirantes de la mochila).
#    3) MOCHILAS - hebillas (del herrero) + correas + cuero curtido -> MOCHILA.
#
#  Curtir y hacer correas son REFINADOS: NO se mezclan calidades (N piezas de la MISMA calidad
#  dan una de esa calidad); solo la Peleteria puede regalarte un escalon. Coser la mochila, en
#  cambio, SI mezcla: la calidad media tira su RAREZA, que es lo unico que la diferencia (no
#  lleva mejoras). El TIER lo ponen las hebillas.
#
#  REHECHO el 16/09/2026 con la cara del inventario (referencia Honkai Star Rail), detras de la
#  tienda. La queja: era una sola columna de "etiqueta: valor" con medio monitor vacio al lado, y
#  los materiales habia que LEERLOS uno a uno en botones de texto. Ahora: rejilla de celdas a la
#  izquierda (el color dice la calidad y la banda cuantas hay, igual que en el baul), ficha a la
#  derecha y los botones en un pie fijo debajo de ella.
#
#  El montaje, la rejilla, quien trabaja y las piezas comunes de la ficha son de la BASE de los
#  talleres (taller_menu.gd). Cada pestaña vive en scripts/ui/peleteria/. Toda la MATH sigue en
#  Game/Forge, sin tocar.
# ============================================================

extends "res://scripts/ui/taller_menu.gd"

const PeleteriaRefinar = preload("res://scripts/ui/peleteria/peleteria_refinar.gd")
const PeleteriaMochilas = preload("res://scripts/ui/peleteria/peleteria_mochilas.gd")

const TABS := ["Curtir", "Correas", "Mochilas"]
# Los iconos, en el mismo orden. Van con icono y SIN texto, como el inventario y la tienda: el
# nombre de la seccion se lee arriba a la izquierda, bajo "Peleteria".
const TAB_ICONOS := ["cuero", "correa", "mochila"]
const TAB_CURTIR := 0
const TAB_CORREAS := 1
const TAB_MOCHILAS := 2

# MOCHILAS pide mucho mas: en su ficha caben los tres ingredientes con una fila por calidad y la
# tabla de rarezas. Con 360 la ficha salia con scroll y cortada a media linea mientras a la izquierda
# sobraban setecientos pixeles en blanco -- alli solo hay DOS celdas, una por metal. Aqui la rejilla
# se queda con lo justo y todo lo demas es para la ficha, que es donde esta el trabajo.
const ANCHO_FICHA_MOCHILA := 870.0
# Y con ella la rejilla se encoge, pero SIGUE siendo la que se estira: asi el sobrante se lo come
# ella y no queda un palmo muerto a la derecha de la ficha. 330 y no 300: con 300 el cuarto retrato
# de QUIEN TRABAJA salia cortado (visto en captura, igual que en la cocina).
const ANCHO_REJILLA_MOCHILA := 330.0

var refinar = null    # PeleteriaRefinar (vale para Curtir y para Correas)
var mochilas = null   # PeleteriaMochilas


func _ready() -> void:
	add_to_group("tannery_menu")
	refinar = PeleteriaRefinar.new(self)
	mochilas = PeleteriaMochilas.new(self)
	montar("Peletería", TABS, TAB_ICONOS)


func abrir() -> void:
	# MULTI: ya no se coge el candado al abrir (los dos a la vez). Se coge solo al crear, y lo
	# seleccionado en Mochilas se RESERVA para el otro. Ver forge_menu.
	_tab = TAB_CURTIR
	mochilas.limpiar()
	abrir_taller()


func _al_cerrar() -> void:
	# Las copias de escaparate dejan meta en Game.item_meta: sin esto se quedan colgando para siempre
	# (la misma limpieza que hace la tienda al cerrar).
	mochilas.vaciar_vitrina()


func _pintar() -> void:
	_titulo_seccion.text = TABS[_tab]
	# EL REPARTO DEL ANCHO, que cambia con la pestaña (ver ANCHO_FICHA_MOCHILA): en Mochilas la
	# rejilla son dos celdas y el trabajo esta todo en la ficha, asi que se le da la vuelta al
	# reparto de las otras dos.
	if _tab == TAB_MOCHILAS:
		anchos(ANCHO_REJILLA_MOCHILA, ANCHO_FICHA_MOCHILA)
	else:
		anchos(ANCHO_REJILLA_MIN, ANCHO_FICHA)
	# Solo MOCHILAS reserva (seleccion persistente); curtir y correas son instantaneas.
	if Net.activo and _tab != TAB_MOCHILAS:
		Net.hogar.reservar({})

	# QUIEN TIENE EL OFICIO se marca EN SU RETRATO, con el pellejo en la esquina. Estaba escrito en la
	# ficha ("Fulano no la tiene") y el usuario lo corto: eso hay que leerlo, y encima solo hablaba
	# del que estuviera elegido. En el retrato se ve de un vistazo a quien conviene mandar.
	pintar_artesanos("peleteria", "cuero", "Tiene Peletería")
	match _tab:
		TAB_MOCHILAS: mochilas.build()
		_: refinar.build(_tab == TAB_CORREAS)
