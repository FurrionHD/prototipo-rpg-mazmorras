# ============================================================
#  muneco_jugador.gd  (class_name MunecoJugador)
#  EL CUERPO VISIBLE del personaje: apila las capas, las mantiene en el mismo fotograma y las
#  ordena en profundidad. Es lo que sustituye al ColorRect de 32x32 de toda la vida.
#
#  Lo usan los CUATRO sitios donde hay un personaje -- el que llevas (player.gd), los compañeros
#  (companion.gd), el otro humano en multijugador (remote_player.gd) y la figura de la pantalla de
#  combate --, y ese es medio motivo de que exista: cuatro copias de "monta el sprite, ponle el
#  color, elige la animacion" acaban divergiendo, y aqui divergir significa que cada pantalla te
#  enseña a la misma persona con otra ropa.
#
#  TRES COSAS QUE HACE Y QUE NO SON OBVIAS:
#
#  1. LLEVA EL RELOJ EL, Y NO CADA CAPA. Lo natural seria llamar a play() en los nueve
#     AnimatedSprite2D y dejar que cada uno corra; el problema es que cada uno arranca su reloj
#     cuando le toca y con el tiempo se separan -- el peto va un fotograma por detras del cuerpo y
#     la coraza flota medio pixel por encima del torso. Aqui hay UN contador y se escribe 'frame' en
#     todos a la vez, asi que no se pueden desincronizar aunque se quiera. De propina, la pantalla
#     de combate puede clavar una pose concreta cuando la necesita.
#
#  2. LA PROFUNDIDAD SE CALCULA, NO SE TABULA. Cada capa cuelga de un punto del cuerpo (el casco de
#     la cabeza, el escudo de la mano izquierda); se le pregunta a PoseJugador donde cae ese punto
#     en ESTE fotograma y se ordena por ahi. De eso salen solos, sin un solo caso especial, los dos
#     comportamientos que se pidieron: mirando al sur se te ve el icono de la cara y mirando al
#     norte lo tapa la nuca del casco; mirando al este el escudo se va detras del cuerpo.
#
#  3. EL COLOR ENTRA MULTIPLICANDO. Las capas se hornean en gris y se tiñen aqui (ver
#     capa_jugador.gdshader). Por eso el mismo peto vale para cualquier material y cualquier rareza.
# ============================================================

extends Node2D
class_name MunecoJugador

const SHADER: Shader = preload("res://shaders/capa_jugador.gdshader")

# La capa de la CARA es la unica que no es un atlas horneado: es tu PNG de 128x128, el mismo de
# siempre, pegado a la cabeza. Entra en la fase siguiente; el hueco esta reservado aqui para que
# quien lea esto sepa por que el compositor habla de "capas" y no de "sprites".

var _capas: Array = []          # [{clave, ranura, ancla, nodo: AnimatedSprite2D}]
var _anim: String = ""
var _reloj: float = 0.0
var _fps: float = 1.0
var _loop: bool = false
var _marcos: int = 1
# La pose CLAVADA: cuando se pide un fotograma concreto (la pantalla de combate lo hace), el reloj
# deja de correr hasta que alguien vuelva a pedir una animacion.
var _fijo: int = -1


func _ready() -> void:
	# Z ABSOLUTO. El muñeco cuelga de un cuerpo que puede estar a cualquier z (el sequito va a -1),
	# y las capas se ordenan entre si con z_index: si fueran relativas, el orden interno del muñeco
	# se sumaria al del padre y dos personajes a distinta altura se apilarian mal entre ellos.
	z_as_relative = false
	set_process(true)


# ============================================================
#  MONTAR
# ============================================================
# Deja el muñeco con las capas que le tocan a este personaje. Se puede llamar las veces que haga
# falta (al cambiar de arma, al equiparse un peto): reaprovecha los nodos que siguen valiendo.
func montar(pj: PersonajeData) -> void:
	var quiere: Array = JugadorSprites.capas_de(pj)
	# Reconstruir solo si ha cambiado la LISTA. Un cambio de color o de tinte no toca los nodos.
	var firma: String = ""
	for c in quiere:
		firma += String(c["clave"]) + "|"
	if firma == _firma_actual():
		return
	for c in _capas:
		c["nodo"].queue_free()
	_capas.clear()
	for c in quiere:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = c["frames"]
		s.centered = false
		s.offset = PoseJugador.offset_sprite(1.0)
		s.scale = Vector2.ONE * PoseJugador.escala_sprite()
		# El sprite se dibuja a 1 celda = 1 pixel y este nodo lo AMPLIA. Sin NEAREST el escalado lo
		# interpola y el pixel-art sale borroso -- la misma nota que lleva enemy.gd.
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_as_relative = true
		s.material = _material()
		add_child(s)
		_capas.append({"clave": c["clave"], "ranura": c["ranura"], "ancla": c["ancla"], "nodo": s})
	if _anim != "":
		_aplicar_anim(_anim, true)


func _firma_actual() -> String:
	var f: String = ""
	for c in _capas:
		f += String(c["clave"]) + "|"
	return f


func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	return m


# ============================================================
#  TEÑIR
# ============================================================
# El color del personaje (el que eligio al crear la partida) y su acabado metalico. Multiplica: las
# capas van en gris con su sombreado, y esto las lleva a su color sin aplanarlas.
#
# El METAL es por capa y no del personaje: la piel no brilla y unas placas si. Hoy solo esta el
# cuerpo, asi que todo va mate; cuando entren las armaduras, cada una traera el suyo segun su
# categoria (cuero 0, placas casi 1).
func tenir(color: Color, metal: float = 0.0) -> void:
	for c in _capas:
		var s: AnimatedSprite2D = c["nodo"]
		s.modulate = Color(color.r, color.g, color.b, 1.0)
		var m: ShaderMaterial = s.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("metal", metal)


# ============================================================
#  ANIMAR
# ============================================================
# 'nombre' viene ya con su direccion ("walk_3"), como lo devuelve PoseJugador.animacion.
func animar(nombre: String) -> void:
	if nombre == _anim and _fijo < 0:
		return
	_aplicar_anim(nombre, true)


# Clava un fotograma concreto y para el reloj. Lo usa la pantalla de combate, que decide ella cuando
# avanza un gesto en vez de dejarlo correr.
func fijar(nombre: String, marco: int) -> void:
	if nombre != _anim:
		_aplicar_anim(nombre, false)
	_fijo = clampi(marco, 0, maxi(0, _marcos - 1))
	_escribir(_fijo)


func _aplicar_anim(nombre: String, reinicia: bool) -> void:
	_anim = nombre
	_fijo = -1
	if reinicia:
		_reloj = 0.0
	# Los datos de ritmo salen de la PRIMERA capa que tenga esta animacion. Todas tienen las mismas
	# (se montan de PoseJugador.ANIMS), asi que da igual cual: si alguna no la tuviera, seria un
	# fallo de esa capa y lo canta el validador del horno, no hay que taparlo aqui.
	_fps = 1.0
	_loop = false
	_marcos = 1
	for c in _capas:
		var sf: SpriteFrames = c["nodo"].sprite_frames
		var n: String = _que_anim(sf, nombre)
		if n == "":
			continue
		_fps = maxf(0.001, sf.get_animation_speed(n))
		_loop = sf.get_animation_loop(n)
		_marcos = maxi(1, sf.get_frame_count(n))
		break
	for c in _capas:
		var sf2: SpriteFrames = c["nodo"].sprite_frames
		var n2: String = _que_anim(sf2, nombre)
		if n2 != "":
			c["nodo"].animation = n2
			c["nodo"].visible = true
		else:
			c["nodo"].visible = false
	_ordenar()
	_escribir(0)


# La animacion que de verdad existe en esta capa. 'encaje' y 'muerte' solo se dibujan en UNA
# direccion (en combate al personaje se le ve siempre de frente), asi que si se piden desde otra se
# cae a la _0 -- misma degradacion que ya hace el visor de bichos y que el juego.
func _que_anim(sf: SpriteFrames, nombre: String) -> String:
	if sf == null:
		return ""
	if sf.has_animation(nombre):
		return nombre
	var base: String = nombre.rsplit("_", true, 1)[0]
	return base + "_0" if sf.has_animation(base + "_0") else ""


func _process(delta: float) -> void:
	if _capas.is_empty() or _anim == "" or _fijo >= 0:
		return
	_reloj += delta
	var i: int = int(_reloj * _fps)
	if _loop:
		i = i % _marcos
	elif i >= _marcos:
		i = _marcos - 1     # las que no repiten se quedan en el ultimo fotograma
	_escribir(i)


func _escribir(i: int) -> void:
	for c in _capas:
		var s: AnimatedSprite2D = c["nodo"]
		if s.visible and i < s.sprite_frames.get_frame_count(s.animation):
			s.frame = i


# ============================================================
#  LA PROFUNDIDAD
# ============================================================
# Ordena las capas segun donde caiga su punto de anclaje una vez girado por la direccion. Lo que
# queda detras del cuerpo se dibuja detras, y lo que queda delante, delante.
#
# Se recalcula al CAMBIAR DE ANIMACION y no fotograma a fotograma, y eso es a proposito: dentro de
# una animacion la direccion no cambia, que es lo unico que decide de verdad este orden. Los brazos
# se mueven, si, pero un escudo no se pasa al otro lado del cuerpo a mitad de un paso -- y hacerlo
# por fotograma haria PARPADEAR el orden en las poses en las que el anclaje cruza el eje.
func _ordenar() -> void:
	if _capas.is_empty() or _anim == "":
		return
	var d: int = _dir_de(_anim)
	var esq: Dictionary = PoseJugador.esqueleto(_base_de(_anim), 0, d, 1.0)
	for i in _capas.size():
		var c: Dictionary = _capas[i]
		var prof: float = PoseJugador.profundidad(esq, c["ancla"])
		# El orden de la lista (JugadorSprites.CAPAS) sigue mandando entre capas que estan a la
		# misma profundidad: el peto va SIEMPRE por encima del torso, este donde este. La
		# profundidad solo desempata delante/detras del cuerpo, que es lo que cambia al girar.
		c["nodo"].z_index = int(round(prof * 4.0)) * 16 + i


func _base_de(nombre: String) -> String:
	return nombre.rsplit("_", true, 1)[0]


func _dir_de(nombre: String) -> int:
	var p: PackedStringArray = nombre.rsplit("_", true, 1)
	return int(p[1]) if p.size() > 1 else 0


# ============================================================
#  RESPALDO
# ============================================================
# ¿Se ha podido montar? Si las capas no estan horneadas y algo falla al dibujarlas, quien llame a
# esto se queda con su ColorRect de siempre en vez de con un personaje invisible. Es la misma red
# que tiene enemy.gd cuando un bicho no tiene generador.
func hay_dibujo() -> bool:
	return not _capas.is_empty() and _capas[0]["nodo"].sprite_frames != null
