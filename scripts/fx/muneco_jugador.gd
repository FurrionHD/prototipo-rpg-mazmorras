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
const SHADER_CARA: Shader = preload("res://shaders/cara_jugador.gdshader")

# QUE PARTE DE LA CABEZA OCUPA TU IMAGEN, en fraccion de su diametro. Por debajo de 1 a proposito:
# el anillo de piel que queda alrededor es lo que hace que la cara se lea DENTRO de la cabeza y no
# encima de ella. A 1.0 la cara tapa la cabeza entera y desde arriba el personaje pierde la
# coronilla, que es lo unico que se le ve al andar por el mapa.
const CARA_DE_LA_CABEZA := 0.80

# EN QUE DIRECCIONES SE TE VE LA CARA. El indice es el de SpriteLienzo.dir8 (0=S 1=SE 2=E 3=NE 4=N
# 5=NW 6=W 7=SW) y el valor es CUANTO SE ADELANTA la imagen sobre la cabeza, en fraccion de su radio.
#
# De espaldas (NE, N, NW) NO SE DIBUJA: es la nuca. Eso podria salir de PoseJugador.profundidad como
# sale el orden de las demas capas, y no sale de ahi por un motivo -- la cabeza esta practicamente en
# el eje del cuerpo (x = 0), asi que su profundidad es casi cero en las ocho direcciones y el signo
# lo decidiria el redondeo. Un cero mal redondeado aqui significa que se te ve la cara por detras.
#
# EL NUMERO NO LLEVA SIGNO Y NO LE HACE FALTA: es un desplazamiento HACIA DELANTE en el sistema del
# cuerpo (+Y), y de convertir "delante" en "a la derecha o a la izquierda de la pantalla" ya se
# encarga el giro de la direccion, igual que con cualquier otra pieza. Escribirlo con signo era
# apuntar dos veces la misma informacion, y la segunda no se usaba.
#
# De frente va a cero y de perfil se adelanta media cabeza: centrada, la cara de perfil se leeria
# como alguien mirando a camara con el cuerpo de lado -- la postura del muñeco de escaparate.
const CARA_DIRS := {0: 0.0, 1: 0.30, 2: 0.52, 6: 0.52, 7: 0.30}

var _capas: Array = []          # [{clave, ranura, ancla, tinte, nodo: AnimatedSprite2D}]
# La cara: un Sprite2D con tu PNG, o null si este personaje no tiene imagen.
var _cara: Sprite2D = null
# El esqueleto de cada (animacion, fotograma) ya montado. 'esqueleto' construye un diccionario
# entero con los catorce puntos, y recolocar la cara se hace en _process: sin cache seria montarlo
# ocho veces por segundo y por personaje del grupo.
var _esq_cache: Dictionary = {}
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
		s.material = _material(bool(c.get("tinte", true)))
		add_child(s)
		_capas.append({"clave": c["clave"], "ranura": c["ranura"], "ancla": c["ancla"],
			"tinte": bool(c.get("tinte", true)), "nodo": s})
	if _anim != "":
		_aplicar_anim(_anim, true)


# ============================================================
#  LA CARA
# ============================================================
# Tu imagen, pegada a la cabeza. 'null' la quita (un personaje puede no tener imagen: un compañero
# recien reclutado, o el otro humano antes de que llegue su PNG por red).
#
# ES LA UNICA CAPA QUE NO SE HORNEA, y por eso no esta en JugadorSprites.CAPAS: el dibujo lo pones
# tu, asi que no hay atlas que precocinar. A cambio hay que recolocarla a mano en cada fotograma
# (ver '_recolocar_cara'), que es lo que las capas horneadas se ahorran por venir ya dibujadas en su
# sitio.
func poner_cara(tex: Texture2D) -> void:
	if tex == null:
		if _cara != null:
			_cara.queue_free()
			_cara = null
		return
	if _cara == null:
		_cara = Sprite2D.new()
		_cara.centered = true
		# Tu PNG es de 128x128 y la cabeza mide ~16 px: se reduce muchisimo, y sin NEAREST el
		# escalado lo interpola. Es la misma nota que llevan las capas horneadas, por el mismo
		# motivo, solo que aqui se encoge en vez de ampliarse.
		_cara.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_cara.z_as_relative = true
		var m := ShaderMaterial.new()
		m.shader = SHADER_CARA
		_cara.material = m
		add_child(_cara)
	_cara.texture = tex
	if _anim != "":
		_ordenar()
		_recolocar_cara(_marco_actual())


# Deja la cara donde caiga la cabeza en ESTE fotograma, con el tamaño que tenga ahi.
#
# La cuenta no se hace aqui: se le pide a PoseJugador.proyectar, que es la misma que usan todas las
# capas para colocar sus elipses. Copiarla aqui seria garantizar que el dia que se toque la camara la
# cara se quede medio pixel por delante de la cabeza en unas direcciones y no en otras.
func _recolocar_cara(i: int) -> void:
	if _cara == null or _cara.texture == null or _anim == "":
		return
	var d: int = _dir_de(_anim)
	if not CARA_DIRS.has(d):
		_cara.visible = false
		return
	_cara.visible = true
	var esq: Dictionary = _esqueleto_de(_base_de(_anim), i, d)
	var r: float = PoseJugador.CABEZA_R
	# El punto de la cara va adelantado (ver CARA_DIRS) EN EL SISTEMA DEL CUERPO, o sea sobre el eje
	# "hacia donde mira" (+Y). Adelantarlo en PANTALLA se saldria de la cabeza en las diagonales,
	# porque la cabeza no se proyecta igual de ancha en todas.
	var centro: Vector3 = esq["puntos"][PoseJugador.P_CABEZA] \
		+ Vector3(0.0, float(CARA_DIRS[d]) * r, 0.0)
	# LOS MISMOS SEMIEJES CON LOS QUE SE DIBUJA LA CABEZA (ver CuerpoSprites.pintar), no una esfera.
	# Con una esfera la cuenta salia mas grande que la cabeza de verdad -- que va achatada de fondo y
	# de alto -- y la cara asomaba por la coronilla: se veia un disco de color por encima del pelo.
	var pr: Dictionary = PoseJugador.proyectar(esq, centro, Vector3(r, r * 0.90, r * 0.96))
	var pos: Vector2 = pr["pos"]
	var radio: Vector2 = pr["radio"]
	# De celdas a pixeles: el nodo del sprite esta escalado por escala_sprite y desplazado por
	# offset_sprite, exactamente igual que las capas horneadas, y la cara tiene que vivir en el
	# mismo sitio.
	var esc: float = PoseJugador.escala_sprite()
	var off: Vector2 = PoseJugador.offset_sprite(1.0)
	_cara.position = (pos + off) * esc
	# El sprite se escala IGUAL EN LOS DOS EJES (tu imagen no se achata: una cara aplastada se lee
	# como una cara mal dibujada, no como una cabeza vista desde arriba) y se toma el MENOR de los
	# dos radios, que es el que garantiza que el circulo cabe dentro del ovalo de la cabeza. Con el
	# mayor, la cara se sale por el lado corto.
	var lado: float = maxf(1.0, float(maxi(_cara.texture.get_width(), _cara.texture.get_height())))
	var cabe: float = minf(radio.x, radio.y)
	_cara.scale = Vector2.ONE * (cabe * 2.0 * CARA_DE_LA_CABEZA * esc / lado)


# El esqueleto de un fotograma, cacheado. La clave lleva la direccion porque los puntos salen sin
# girar pero el dict trae el angulo dentro.
func _esqueleto_de(base: String, i: int, d: int) -> Dictionary:
	var k: String = "%s_%d_%d" % [base, i, d]
	if not _esq_cache.has(k):
		_esq_cache[k] = PoseJugador.esqueleto(base, i, d, 1.0)
	return _esq_cache[k]


func _marco_actual() -> int:
	if _fijo >= 0:
		return _fijo
	var i: int = int(_reloj * _fps)
	if _loop:
		return i % maxi(1, _marcos)
	return mini(i, maxi(0, _marcos - 1))


func _firma_actual() -> String:
	var f: String = ""
	for c in _capas:
		f += String(c["clave"]) + "|"
	return f


# EL 'base' DEL SHADER NO ES DECORATIVO: es el gris del horneado que tiene que salir EXACTAMENTE del
# color pedido, y el shader divide por el (ver capa_jugador.gdshader). Va en 0,62 para las capas que
# se tiñen, porque estan dibujadas en grises apretados alrededor de ese valor.
#
# UNA CAPA QUE NO SE TIÑE NECESITA base = 1.0, y esto es una trampa que cuesta un rato encontrar: sin
# tinte el 'modulate' es blanco, asi que la cuenta se queda en textura / 0,62 -- o sea que el dibujo
# se ACLARA un 60% y se quema. La piel salia casi blanca y parecia que los colores estaban mal
# elegidos, cuando lo que pasaba es que se estaban dividiendo por un numero que ya no aplicaba. Con
# base = 1.0 la textura pasa tal cual, que es lo unico que se le pide a una capa ya coloreada.
func _material(tinte: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("base", 0.62 if tinte else 1.0)
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
#
# LAS CAPAS CON "tinte": false SE SALTAN, y hoy eso es el cuerpo entero: la piel va en su color y no
# en el tuyo (ver JugadorSprites.CAPAS). Se les deja el modulate en BLANCO explicitamente en vez de
# no tocarlas -- si se hubieran teñido antes de que alguien cambiara el flag, no tocarlas dejaria el
# color viejo pegado.
func tenir(color: Color, metal: float = 0.0) -> void:
	for c in _capas:
		var s: AnimatedSprite2D = c["nodo"]
		var pinta: bool = bool(c.get("tinte", true))
		s.modulate = Color(color.r, color.g, color.b, 1.0) if pinta else Color.WHITE
		var m: ShaderMaterial = s.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("metal", metal if pinta else 0.0)


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
	# La cara va enganchada al MISMO contador que las capas, y no a un reloj suyo. Es el punto 1 de
	# la cabecera de este archivo: dos relojes se separan, y aqui separarse significa que tu cara va
	# un fotograma por detras de tu cabeza y flota al andar.
	_recolocar_cara(i)


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
	# La cara va por encima de TODO el cuerpo y no entra en el reparto por profundidad. No es un
	# atajo: la cabeza esta casi en el eje del personaje, asi que su profundidad es casi cero y el
	# orden lo decidiria el redondeo -- se te veria la cara por detras de tu propia cabeza en unas
	# direcciones y no en otras. Quien decide si se te ve la cara es CARA_DIRS, que mira la
	# direccion y no el redondeo (ver '_recolocar_cara'); una vez decidido que se ve, se ve entera.
	# 2048 y no un numero enorme: Godot solo acepta z_index entre -4096 y 4096, y pasarse no lo
	# recorta -- lo rechaza con un error y deja el z_index ANTERIOR, o sea que la cara acaba
	# ordenandose por donde estuviera. Las capas del cuerpo se reparten en unos pocos cientos
	# (profundidad x 4 x 16), asi que esto queda muy por encima de todas con sitio de sobra.
	if _cara != null:
		_cara.z_index = 2048


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
