# ============================================================
#  transicion.gd
#  QUE ESTILO le toca a cada celda en un piso DE CORTE (donde cambia el tramo).
#
#  Al bajar del 6 al 7 el sitio cambia de mazmorra de piedra a cueva. Cambiarlo de golpe al cruzar
#  la escalera se lee como un corte de escena: entras y ya estas en otro sitio, sin haber ido a
#  ninguna parte. Asi que la ENTRADA sigue siendo el estilo del piso de arriba durante unas celdas
#  y a partir de ahi se transforma: la cueva empieza al fondo y tu la ves venir.
#
#  DATOS PUROS, como Decorado: ni un nodo, todo derivado de la semilla del piso. Eso es lo que hace
#  que se pueda mirar con una herramienta headless y, sobre todo, que el anfitrion y el invitado
#  vean EXACTAMENTE la misma frontera sin que viaje un solo byte por la red.
# ============================================================

extends RefCounted
class_name Transicion

# Celdas de estilo viejo alrededor de la entrada. Cinco es lo que pidio el usuario, y en pantalla
# es aproximadamente lo que se ve de una vez con el farolillo: cuando la frontera te queda a la
# espalda, ya estas dentro.
const RADIO := 5.0

# Cuanto se deforma el borde, en celdas (para arriba y para abajo). Sin esto la frontera es una
# circunferencia de compas y se lee como un foco de luz, no como un cambio de terreno.
const IRREGULAR := 2.6

# Tamaño de los lobulos del borde. 3 = entrantes y salientes de unas tres celdas: mas pequeño se
# lee como ruido sucio y mas grande vuelve a parecer un circulo.
const MANCHA_ESCALA := 3

var activa: bool = false      # false = el piso entero es de un solo tramo
var ancla := Vector2i.ZERO    # centro de la burbuja de estilo viejo
var _sem: int = 0


# 'gen' hace falta para saber donde esta la entrada. Se usa el centro de la PRIMERA SALA y no donde
# aparece el jugador de verdad, y esa diferencia importa: puedes entrar por el fondo (subiendo), por
# la puerta del jefe (el atajo) o donde guardaste la partida. Si el terreno dependiera de eso, el
# mismo piso tendria un aspecto distinto segun como entraste, y dos jugadores del mismo mundo
# verian mapas diferentes. salas[0] es donde apareces al BAJAR -- el caso que importa -- y ademas
# sale de la semilla.
func preparar(piso: int, gen: DungeonGenerator, semilla: int) -> void:
	activa = TerrenoSprites.hay_corte(piso) and gen != null and not gen.salas.is_empty()
	_sem = semilla
	if activa:
		ancla = gen.salas[0].get_center()


# ¿Esta celda es ya del tramo NUEVO? En un piso normal, todas.
func es_nuevo(c: Vector2i) -> bool:
	if not activa:
		return true
	var d2: float = Vector2(c - ancla).length_squared()
	# Los dos atajos se llevan la inmensa mayoria de las celdas del piso sin tocar el ruido: solo
	# el anillo de la frontera (unas ciento y pico celdas) llega a preguntarselo.
	if d2 > (RADIO + IRREGULAR) * (RADIO + IRREGULAR):
		return true
	if d2 < (RADIO - IRREGULAR) * (RADIO - IRREGULAR):
		return false
	var r: float = RADIO + (Decorado.mancha(c, _sem + 4801, MANCHA_ESCALA) - 0.5) * 2.0 * IRREGULAR
	return sqrt(d2) > r


# El id de fuente del TileSet para esta celda: 0 = tramo viejo, 1 = nuevo (ver
# TerrenoSprites.tramos_de, que los devuelve en ese mismo orden). En un piso sin corte, siempre 0.
func fuente(c: Vector2i) -> int:
	if not activa:
		return 0
	return 1 if es_nuevo(c) else 0
