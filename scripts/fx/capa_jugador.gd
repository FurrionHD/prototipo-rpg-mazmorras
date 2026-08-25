# ============================================================
#  capa_jugador.gd  (class_name CapaJugador)
#  LA FABRICA DE CAPAS: convierte "esta funcion sabe donde van mis elipses" en un SpriteFrames
#  completo, con sus 8 direcciones, sus 8 animaciones y su atlas.
#
#  Es lo que hace que escribir una pieza de armadura nueva sea escribir UNA funcion. El cuerpo, un
#  peto, un casco y una espada tienen exactamente el mismo trabajo alrededor -- recorrer las
#  animaciones, pedirle el esqueleto a PoseJugador, pintar, contornear, cachear, empaquetar --, y
#  ese trabajo esta aqui una sola vez.
#
#  Y hay un motivo mas fuerte que ahorrar teclas: LA COHERENCIA ENTRE CAPAS DEJA DE SER ALGO QUE
#  HAYA QUE VIGILAR. Como todas las capas se montan por aqui, todas salen con las mismas
#  animaciones, el mismo numero de fotogramas y el mismo lienzo, porque los tres salen de
#  PoseJugador.ANIMS y PoseJugador.lienzo. Si cada generador montara lo suyo, bastaria con que uno
#  se dejara 'sigilo' para que el personaje se quedara en calzoncillos al agacharse -- sin error,
#  sin aviso, y solo visible agachandose.
#
#  EL CONTRATO DE UN PINTOR (lo unico que escribe quien añade una capa):
#      func(esq: Dictionary, piezas: Array) -> void
#  Recibe el esqueleto de ESTE fotograma (ver PoseJugador.esqueleto) y va metiendo piezas con
#  PoseJugador.poner / PoseJugador.cadena. No decide colores (eso es la paleta), ni direcciones, ni
#  fotogramas: solo donde caen sus elipses cuando el cuerpo esta ASI.
#
#  CAPAS, Y NO COMBINACIONES: ver la cabecera de pose_jugador.gd. Aqui lo que importa es la
#  consecuencia practica -- una capa se hornea SOLA, sin saber que llevara debajo ni encima.
# ============================================================

extends RefCounted
class_name CapaJugador

# Las capas del jugador tienen carpeta propia. Son ~35 (un cuerpo, veinte de armadura, catorce de
# mano) y mezcladas con los bichos no habria forma de ver de un vistazo cuanto ocupa cada cosa.
const CARPETA := "res://assets/sprites/player/"

# El tono 0 siempre es el vacio (contrato de SpriteLienzo), y el 1 y el 2 se reservan para la sombra
# de suelo y el borde. A partir del 3, cada capa pone lo suyo.
#
# ESTAN FIJOS PARA TODAS LAS CAPAS a proposito: 'contornear' necesita saber que dos tonos cuentan
# como hueco, y si cada capa los pusiera en un indice distinto habria que pasarselos por parametro
# a todo. Ademas asi una capa puede mirar el tono de otra sin traducir.
const T_VACIO := 0
const T_SOMBRA_SUELO := 1
const T_BORDE := 2
const T_PRIMER_LIBRE := 3

# La geometria cacheada por (capa, animacion, fotograma, direccion, escala). NO por color: ese es el
# truco que ya usan los bichos y que aqui vale doble, porque el color del jugador ni siquiera entra
# en el dibujo -- se hornea en gris y se tiñe en el juego (ver 'generar').
static var _cache_plantillas: Dictionary = {}
# Los SpriteFrames ya montados, por clave de capa.
static var _cache: Dictionary = {}
# Lo leido de disco. Un null cacheado significa "ya se miro y no estaba", para no volver a mirar.
static var _horneado: Dictionary = {}


# ============================================================
#  LA CAPA ENTERA
# ============================================================
# 'clave' identifica la capa en el cache y en el disco ("cuerpo", "peto_placas", "arma_mandoble"...).
# 'colores' son los colores de cada tono EN EL ORDEN DEL ENUM de la capa (contrato de
# SpriteLienzo.paleta), empezando por los tres fijos de arriba.
#
# POR QUE SE HORNEA EN GRIS Y SE TIÑE DESPUES, que es LO UNICO que se aparta del camino de los
# bichos: un bicho tiene tres o cuatro colores en toda su vida, asi que hornear una variante por
# color sale barato. Una pieza de armadura, no -- cambia con el material, con el tier y con la
# rareza, y son ocho rarezas por vete a saber cuantos materiales. Un peto de hierro epico y otro
# comun son EL MISMO DIBUJO con otro tinte, asi que se hornea uno y lo tiñe metal.gdshader, que ya
# esta escrito y ya sabe hacer tinte y brillo metalico. Sin esto la cuenta de atlas se dispara y con
# esto se queda en ~35.
static func generar(clave: String, pintor: Callable, colores: Array, esc: float = 1.0) -> SpriteFrames:
	var e: float = snappedf(esc, 0.05)     # se cuantiza o el cache no acierta
	var ck: String = "%s_%.2f" % [clave, e]
	if _cache.has(ck):
		return _cache[ck]
	var lz: Vector2i = PoseJugador.lienzo(e)
	var anims: Array = []
	for a in PoseJugador.ANIMS:
		var nombre: String = a["n"]
		var dirs: int = int(a["dirs"])
		var marcos: int = int(a["marcos"])
		for dir in dirs:
			var plantillas: Array = []
			for i in marcos:
				var pk: String = "%s_%s_%d_%d_%.2f" % [clave, nombre, i, dir, e]
				var plant: PackedByteArray = _cache_plantillas.get(pk, PackedByteArray())
				if plant.is_empty():
					plant = plantilla(pintor, nombre, i, dir, e)
					_cache_plantillas[pk] = plant
				plantillas.append(plant)
			anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": bool(a["loop"]),
				"fps": float(a["fps"]), "plantillas": plantillas})
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(colores), lz.x, lz.y)
	_cache[ck] = sf
	return sf


# La plantilla de UN fotograma: que tono le toca a cada celda.
static func plantilla(pintor: Callable, anim: String, marco: int, dir: int,
		esc: float) -> PackedByteArray:
	var lz: Vector2i = PoseJugador.lienzo(esc)
	var plant := PackedByteArray()
	plant.resize(lz.x * lz.y)
	var esq: Dictionary = PoseJugador.esqueleto(anim, marco, dir, esc)
	var piezas: Array = []
	pintor.call(esq, piezas)
	if piezas.is_empty():
		return plant     # una capa puede no dibujar nada en esta direccion (la cara de espaldas)

	# EL ORDEN DE LA LISTA ES LA PROFUNDIDAD: no hay z-buffer, las ultimas tapan a las primeras. Por
	# eso el pintor mete primero lo que va detras (la pierna del fondo) y al final lo que va delante.
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			float(p["ang"]), p["solo_sobre"], float(p["persp"]))

	# CONTORNO AL FINAL, sobre la silueta ya fusionada, nunca pieza a pieza: si no, cada elipse
	# traeria su propio circulito marcado por dentro y el brazo dejaria de leerse como parte del
	# cuerpo. La sombra del suelo cuenta como hueco -- es una mancha translucida, no eres tu.
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		T_BORDE, T_VACIO, T_SOMBRA_SUELO)
	return plant


# ============================================================
#  DISCO
# ============================================================
# Misma cadena de prioridad que los bichos: si la capa esta horneada se carga (milisegundos) y si no
# se dibuja al vuelo. Esa caida es deliberada: sin ella, cada retoque de un peto obligaria a hornear
# antes de poder verlo.
static func frames(clave: String, pintor: Callable, colores: Array, esc: float = 1.0) -> SpriteFrames:
	var e: float = snappedf(esc, 0.05)
	var ck: String = "%s_%.2f" % [clave, e]
	if not _horneado.has(ck):
		_horneado[ck] = SpriteLienzo.cargar_horneado(ck, CARPETA)
	if _horneado[ck] != null:
		return _horneado[ck]
	return generar(clave, pintor, colores, e)


static func hornear(sf: SpriteFrames, clave: String, esc: float = 1.0) -> int:
	return SpriteLienzo.hornear(sf, "%s_%.2f" % [clave, snappedf(esc, 0.05)], CARPETA)


# ============================================================
#  LA PALETA EN GRIS
# ============================================================
# Los cinco escalones que usa casi cualquier capa. Se hornean asi y el tinte los lleva a su color en
# el juego, asi que el gris NO es un color de relleno provisional: es el dibujo definitivo.
#
# El valor medio va en 0.62 y no en 0.5 porque metal.gdshader mezcla hacia el tinte
# (mix(textura, color, alpha)) y ademas le suma un bisel: partiendo de un gris medio de verdad, todo
# salia apagado. Con la escala un poco alta, el tinte queda con el brillo que se espera.
static func grises(borde := 0.20, sombra := 0.42, base := 0.62, luz := 0.80, brillo := 0.94) -> Array:
	return [
		Color(0, 0, 0, 0),                      # T_VACIO
		Color(0, 0, 0, 0.20),                   # T_SOMBRA_SUELO
		Color(borde, borde, borde),             # T_BORDE
		Color(sombra, sombra, sombra),
		Color(base, base, base),
		Color(luz, luz, luz),
		Color(brillo, brillo, brillo),
	]


# La sombra de contacto, que la lleva TODA capa que toque el suelo. Se pone a altura cero: acompaña
# al personaje por el suelo pero no sube con el cuando bota, y esa separacion es lo que se lee como
# un salto. Sin ella el personaje flota, y canta al lado de un bicho que no flota.
#
# No lleva escorzo a mano: con altura cero, la proyeccion de PoseJugador.poner ya la deja aplastada
# en cos(45), que es exactamente lo que le toca a una mancha tumbada en el suelo.
static func sombra_suelo(piezas: Array, esq: Dictionary, rx: float = 5.6, ry: float = 3.4) -> void:
	PoseJugador.poner(piezas, esq, Vector3.ZERO, Vector3(rx, ry, 0.0), T_SOMBRA_SUELO,
		{"en_suelo": true, "gira": false})
