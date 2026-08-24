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


static func _generador(ed: EnemyData):
	if ed == null:
		return null
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
	return g.generar_de(ed, t) if g != null else null


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
	return ancho_pantalla / float(g.ancho_px(ed.escala_visual)) if g != null else 1.0
