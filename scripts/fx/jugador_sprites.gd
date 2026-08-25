# ============================================================
#  jugador_sprites.gd  (class_name JugadorSprites)
#  EL REGISTRO DEL PERSONAJE: dice QUE CAPAS hay que apilar y en que orden. Nada mas.
#
#  Es el hermano de SpritesEnemigo, y existe por lo mismo: la decision de que se dibuja tiene que
#  estar en UN sitio, porque la necesitan cuatro -- el jugador del mapa, el compañero, el jugador
#  remoto del otro y la figura de combate. Cuatro copias de la misma regla acaban divergiendo, y
#  ahi la consecuencia es que cada pantalla te enseña a la misma persona con otra ropa.
#
#  NO ES EL MISMO REGISTRO QUE EL DE LOS BICHOS, y no se podia reutilizar: aquel despacha UN
#  generador por enemigo (un slime se dibuja entero con SlimeSprites), y aqui son muchos a la vez
#  sobre el mismo cuerpo. Un bicho es un dibujo; un personaje es una pila.
#
#  COMO CRECE (que es lo que hay que saber para las fases que faltan): una pieza de armadura nueva
#  es UNA linea en su tabla. El despacho va por MOLDE, y el molde sale del propio item si lo trae
#  (ArmorData.sprite_molde) o, si no, de su categoria -- exactamente como SpritesEnemigo deja que el
#  nombre gane a la familia. Hoy todo cae por categoria y no hay ni un molde propio; el dia que una
#  armadura concreta quiera su dibujo, no hay que tocar nada mas.
# ============================================================

extends RefCounted
class_name JugadorSprites

# LAS CAPAS, DE ABAJO ARRIBA. El orden de esta lista es el orden de apilado por defecto; la
# profundidad fina (que el escudo se vaya detras del cuerpo al mirar al este) NO se decide aqui sino
# fotograma a fotograma, preguntandole a PoseJugador por donde cae su punto de anclaje.
#
# 'piezas' = de cuantos trozos separados PUEDE constar la capa. No es adorno: es lo que hace que el
# validador de islas del horno sirva para algo. El cuerpo es UNA pieza siempre -- si sale en dos, se
# ha despegado algo --, pero unas botas son DOS y unos guanteletes tambien, y sin declararlo el
# validador daria un aviso por cada fotograma de cada bota del juego y acabaria ignorandose.
enum Ranura { CUERPO, PANTALONES, BOTAS, PECHO, MANOS, CARA, CASCO, MANO_DER, MANO_IZQ }

static var CAPAS := [
	{"ranura": Ranura.CUERPO, "clave": "cuerpo", "gen": CuerpoSprites, "piezas": 1,
		"ancla": PoseJugador.P_CADERA},
]


# Los SpriteFrames de todas las capas que le tocan a este personaje, ya en orden de apilado.
# Devuelve [{clave, frames, ancla, ...}] para que el compositor no tenga que saber de generadores.
#
# HOY SOLO DEVUELVE EL CUERPO: la armadura y las armas entran en las fases siguientes. La firma ya
# recibe el PersonajeData a proposito, para que enchufarlas no obligue a tocar a los que llaman.
static func capas_de(_pj: PersonajeData) -> Array:
	var out: Array = []
	for c in CAPAS:
		var g = c["gen"]
		out.append({"clave": c["clave"], "ranura": c["ranura"], "ancla": c["ancla"],
			"frames": g.frames(1.0)})
	return out


# Que animacion toca. Delega en PoseJugador, que es donde vive la regla: aqui solo se reexporta para
# que quien use este registro no tenga que conocer dos clases.
static func animacion(mirada: Vector2, modo: int, moviendose: bool, golpeando: bool = false) -> String:
	return PoseJugador.animacion(mirada, modo, moviendose, golpeando)


static func cadaver(mirada: Vector2) -> String:
	return PoseJugador.cadaver(mirada)


# La caja de colision del personaje, en unidades de mundo. Se queda en los 32x32 de siempre A
# PROPOSITO: el sprite se dibuja alrededor y es mas alto que ancho, pero cambiar la colision movería
# como estorba el personaje en un pasillo, que es cosa de juego y no de dibujo. Si algun dia se
# toca, que sea por una decision de juego y no de refilon al meter arte.
static func tam_cuerpo() -> Vector2:
	return Vector2(32.0, 32.0)
