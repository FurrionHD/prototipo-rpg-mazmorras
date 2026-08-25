# ============================================================
#  sprites_enemigo.gd  (class_name SpritesEnemigo)
#  EL REGISTRO: decide QUE generador de sprites le toca a cada enemigo. Nada mas.
#
#  Existe porque esa decision estaba escrita DOS VECES -- en enemy.gd (el juego) y en
#  dev_enemigos_animaciones.gd (el visor) -- y dos copias de la misma regla acaban divergiendo:
#  el visor te enseña una cosa y la mazmorra otra, que es justo lo que no puede pasar en la
#  herramienta con la que se juzga el arte. Ahora los dos preguntan aqui.
#
#  Añadir un enemigo dibujado por codigo = UNA LINEA en GENERADORES. Ni un 'if' en enemy.gd.
#
#  El CONTRATO que cumple un generador (por duck typing, cuatro estaticas):
#     generar_de(ed: EnemyData, t: float) -> SpriteFrames
#     escala_base() -> float      cuanto hay que escalar su textura para medir lo que debe medir
#     ancho_px(escala) -> int     ancho de su textura (el visor lo necesita para su zoom)
#     dimensiona_por_escala() -> bool
#         true  = el generador YA dibuja al bicho grande con mas celdas (lo correcto: el pixel mide
#                 siempre igual). Nadie debe volver a estirar el sprite.
#         false = genera siempre del mismo tamaño y hay que estirarlo con escala_visual, con lo que
#                 al bicho grande le salen los pixeles gordos. Hoy no lo hace ninguno: lo unico que
#                 vuelve por ahi es el arte de verdad, que si viene a un tamaño fijo.
#
#  OJO con las capas: este archivo conoce a los generadores y ellos conocen a SpriteLienzo, pero
#  SpriteLienzo no conoce a nadie. Meter este registro dentro del motor haria un ciclo.
# ============================================================

extends RefCounted
class_name SpritesEnemigo

# Que familia se dibuja con que generador. La familia ya existia como etiqueta de juego (la usan
# las pasivas slayer) y describe exactamente lo que hace falta saber aqui: un ROEDOR se ve como una
# rata. Los 6 .tres con es_slime son justo los 6 de familia SLIME, asi que despachar por familia es
# fiel a lo que habia antes -- y es_slime sigue existiendo para lo suyo (rastro de baba, sequito
# del Rey), que no es cosa del dibujo.
# (static var y no const: una referencia a otra clase no es una expresion constante en GDScript.)
static var GENERADORES := {
	EnemyData.Familia.SLIME: SlimeSprites,
	EnemyData.Familia.ROEDOR: RataSprites,
}

# Y los que NO se pueden despachar por familia, POR NOMBRE (EnemyData.sprite_gen).
#
# Despachar por familia funcionaba con dos generadores y deja de funcionar con cuatro: la familia es
# una etiqueta de JUEGO (la usan las pasivas slayer), no de dibujo, y hay familias que juntan bichos
# que no se parecen en nada. BESTIA son el Jabali y el Acechador de las simas; NINGUNA son el Trent
# y la Aberracion de la sima. Registrando BESTIA -> JabaliSprites, el Acechador saldria con forma de
# jabali.
#
# El nombre gana a la familia, asi que un bicho puede salirse del dibujo de los suyos sin tocar nada
# mas. Y NO se toco el enum Familia para meter una PLANTA: eso es un cambio de juego (las slayer),
# no de dibujo.
static var GENERADORES_POR_NOMBRE := {
	&"jabali": JabaliSprites,
	&"trent": TrentSprites,
}


static func _generador(ed: EnemyData):
	if ed == null:
		return null
	if ed.sprite_gen != &"":
		return GENERADORES_POR_NOMBRE.get(ed.sprite_gen, null)
	return GENERADORES.get(ed.familia, null)


# Los frames que le tocan a este enemigo, o null si no le toca ninguno (se queda con el ColorRect
# de siempre). EL ARTE DE VERDAD SIEMPRE GANA: el dia que un .tres traiga su sprite_frames dibujado
# a mano, sustituye al generado sin tocar una linea de codigo.
static func frames_de(ed: EnemyData, t: float) -> SpriteFrames:
	if ed == null:
		return null
	if ed.sprite_frames != null:
		return ed.sprite_frames
	var g = _generador(ed)
	if g == null:
		return null
	# EL HORNEADO MANDA. Si esta variante ya esta en disco (ver hornear_sprites.bat), se carga y listo:
	# son milisegundos, contra los ~0,3-1,2 s que cuesta dibujarla. Y si NO esta -- porque acabas de
	# tocar un generador y aun no has horneado --, se genera al vuelo como siempre. Esa caida es
	# deliberada: sin ella, cada retoque de un sprite obligaria a hornear antes de poder probarlo.
	var clave: String = g.clave_de(ed, t)
	if not _horneado.has(clave):
		_horneado[clave] = SpriteLienzo.cargar_horneado(clave)
	if _horneado[clave] != null:
		return _horneado[clave]
	return g.generar_de(ed, t)


# Lo ya leido de disco, por clave. null = se miro y no estaba (no se vuelve a mirar en cada bicho).
static var _horneado: Dictionary = {}


# La CLAVE de la variante que le toca a este enemigo con esta 't'. La usa el horno para saber que
# nombre poner al fichero, y el juego para saber cual buscar: tienen que salir del MISMO sitio.
static func clave_de(ed: EnemyData, t: float) -> String:
	var g = _generador(ed)
	return String(g.clave_de(ed, t)) if g != null else ""


# Cuanto hay que escalar el nodo. Las texturas generadas van a 1 celda = 1 pixel y las amplia el
# nodo (con filtro NEAREST), asi que sin esto saldrian con el tamaño de su rejilla. El arte de
# verdad se da por hecho que viene ya a su tamaño (1.0).
static func escala_de(ed: EnemyData) -> float:
	if ed == null or ed.sprite_frames != null:
		return 1.0
	var g = _generador(ed)
	return g.escala_base() if g != null else 1.0


# ¿Hay que estirar el sprite con escala_visual, o el generador ya lo dibujo del tamaño que toca?
# El arte de verdad viene siempre a un tamaño fijo, asi que ese SI hay que estirarlo.
static func hay_que_estirar(ed: EnemyData) -> bool:
	if ed == null:
		return false
	if ed.sprite_frames != null:
		return true
	var g = _generador(ed)
	return not g.dimensiona_por_escala() if g != null else false


# ============================================================
#  QUE ANIMACION TOCA
# ============================================================
# Vive aqui, y no en enemy.gd, por el mismo motivo que el registro de generadores: la regla la
# necesitan DOS sitios -- el bicho que se simula (enemy.gd) y su espejo en la maquina del otro
# jugador (remote_enemy.gd) --, y dos copias de la misma regla divergen. Si divergen, cada jugador
# ve al mismo bicho haciendo cosas distintas, que en un juego donde el sigilo es medio juego no es
# un detalle estetico.

# Una direccion de pantalla (+Y abajo) a uno de los 8 sectores: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW,
# que es el orden en que TODOS los generadores nombran sus animaciones.
static func dir8(dir: Vector2) -> int:
	var ang: float = dir.angle()   # 0 = derecha (E), crece en sentido horario (Y abajo)
	var sector: int = int(round((PI / 2.0 - ang) / (PI / 4.0)))
	return ((sector % 8) + 8) % 8


# El nombre de la animacion que toca, a partir de hacia donde mira y que esta haciendo.
static func animacion(mirada: Vector2, embistiendo: bool, moviendose: bool) -> String:
	return "%s_%d" % ["embestida" if embistiendo else ("walk" if moviendose else "idle"),
		dir8(mirada)]


# Y LA POSE DE CADAVER, hermana de la de arriba. Vive aqui, y no en enemy.gd, porque la necesitan
# DOS sitios -- el bicho de esta partida y el que refleja el compañero en multijugador (remote_enemy)
# --, y dos copias de la misma regla acaban divergiendo: en una pantalla el muerto se queda mirando
# adonde estaba y en la otra al sur.
#
# UN fotograma por direccion, al reves que la animacion de morir (ocho fotogramas, una direccion):
# en el mapa no se ve morir a nadie -- se entra a la sala y el bicho ya esta tirado --, pero pudo
# caer mirando a cualquier lado.
static func cadaver(mirada: Vector2) -> String:
	return "cadaver_%d" % dir8(mirada)


# ============================================================
#  PRECALENTAR: generar los sprites ANTES de que nazca el bicho
# ============================================================
# Generar los 192 frames de un enemigo cuesta lo suyo (medido: 0,17 s un slime, 0,77 s el jabali,
# 1,17 s el Rey Slime), y hasta ahora se pagaba EN EL _ready DEL BICHO -- o sea, en mitad de la
# partida, la primera vez que a una pared le daba por parir uno de ese tipo. Y no una vez por tipo:
# el color sale de color_visual(t) con 't' aleatorio por bicho, asi que tras cuantizar quedan 3-4
# variantes y cada una es su propia generacion. Un BROTE de cinco podia comerse mas de un segundo
# de golpe, justo cuando estas jugando.
#
# Con el cache caliente, en cambio, un nacimiento cuesta CERO (medido: 50 seguidos, 0 ms). Asi que
# el arreglo no es generar mas rapido, es generar ANTES: aqui, mientras se monta el piso.
#
# El cache es ESTATICO y va por (color cuantizado, escala, variante), asi que esto solo se paga la
# PRIMERA vez que aparece cada tipo en toda la sesion; volver a bajar al mismo piso es gratis.

# Cuantas 't' se prueban por enemigo. No hace falta afinar: 't' solo entra por color_visual, que es
# monotona, y tras cuantizar deja 3-4 escalones. Con 24 muestras se cubren todos de sobra, y las que
# repiten clave salen gratis (el cache acierta).
const _MUESTRAS_T := 24


# Deja listos los sprites de estos EnemyData. Devuelve los milisegundos que ha costado, para poder
# medirlo desde fuera sin instrumentar esto.
static func precalentar(datas: Array) -> int:
	var t0: int = Time.get_ticks_msec()
	var vistos := {}
	for d in datas:
		var ed: EnemyData = d as EnemyData
		if ed == null or vistos.has(ed):
			continue
		vistos[ed] = true
		if _generador(ed) == null:
			continue      # sigue siendo un ColorRect: no hay nada que generar
		for i in _MUESTRAS_T:
			frames_de(ed, float(i) / float(_MUESTRAS_T - 1))
	return Time.get_ticks_msec() - t0


# El CUERPO de este enemigo en planta (ancho, largo) en unidades de mundo, o Vector2.ZERO si no se
# sabe -- que es el caso de los ~15 que siguen siendo un ColorRect y el del arte de verdad, que no
# declara su geometria. Quien pregunte tiene que tratar el ZERO como "usa la caja de siempre".
#
# Existe porque la colision era 32x32 PARA TODOS, escalada con escala_visual, y eso solo le queda
# bien a un bicho macizo y redondo como el slime. La rata es estrecha y larga: media 8,7 unidades de
# ancho vista de frente dentro de una caja de 27, o sea que chocaba con las paredes por un cuerpo
# que no tiene. Ahora cada uno choca por lo que ocupa de verdad.
static func tam_cuerpo(ed: EnemyData) -> Vector2:
	if ed == null or ed.sprite_frames != null:
		return Vector2.ZERO
	var g = _generador(ed)
	return g.tam_cuerpo(ed.escala_visual) if g != null else Vector2.ZERO


# Zoom para que el bicho ocupe 'ancho_pantalla' en el visor. Va por generador Y por escala, porque
# cada rejilla es distinta: la rata es mas ancha que el slime, y un rey se dibuja con mas celdas que
# uno normal. Con una constante, unos se verian enormes y otros diminutos.
static func zoom_visor(ed: EnemyData, ancho_pantalla: float) -> float:
	if ed == null or ed.sprite_frames != null:
		return 1.0
	var g = _generador(ed)
	if g == null:
		return 1.0
	# LO QUE MIDE EL BICHO, no lo que mide su lienzo. No es lo mismo ni de lejos: el lienzo lleva
	# ademas todo el aire que necesitan sus animaciones mas amplias, y en el trent -- que hay que
	# poder dibujar TUMBADO, o sea de largo en horizontal -- ese aire es tres cuartas partes del
	# ancho. Midiendo el lienzo, el visor lo enseñaba como una miniatura en mitad de la pantalla,
	# justo la herramienta con la que se juzga si el dibujo esta bien.
	#
	# El ancho real sale del recorte del frame de reposo, que es lo que hace tambien el combate para
	# repartir el zoom entre los bichos de la fila (ver combat._poner_sprite).
	var frames: SpriteFrames = frames_de(ed, 1.0)
	if frames != null and frames.has_animation(&"idle_0"):
		var tex: Texture2D = frames.get_frame_texture(&"idle_0", 0)
		var img: Image = tex.get_image() if tex != null else null
		if img != null and img.get_width() > 0:
			return ancho_pantalla / float(img.get_width())
	return ancho_pantalla / float(g.ancho_px(ed.escala_visual))
