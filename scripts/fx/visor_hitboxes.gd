# ============================================================
#  visor_hitboxes.gd  --  DIBUJA LAS CAJAS por encima del mapa. Se enciende desde el panel de debug.
#
#  POR QUE NO VALE EL VISOR DE COLISIONES DE GODOT, que ya existe y es gratis: porque enseña los
#  NODOS de colision, y en este juego la caja con la que te pegan NO ES UN NODO. En todo el proyecto
#  no hay un solo Area2D -- el contacto se resuelve con un rectangulo calculado desde el centro (ver
#  Enemy.hueco_hasta) --, asi que el visor del motor enseñaria exactamente la mitad del problema, y
#  ademas la mitad que casi nunca es la que falla.
#
#  LAS DOS CAJAS SON DISTINTAS Y ESO ES EL PUNTO (ver la nota de los dos cuerpos en pose_jugador.gd):
#
#    * LA HUELLA (cian) es la fisica: con eso se choca contra los muros. Va baja y pegada a los pies
#      a proposito, para que a 45 grados la cabeza y el tronco pasen por delante de lo que hay
#      detras. Si te quedas enganchado en un pasillo, el problema esta aqui.
#    * EL BULTO (rosa) es el cuerpo entero: con eso te pegan y pegas. Si un bicho conecta antes o
#      despues de lo que se ve, el problema esta aqui.
#
#  Y ADEMAS EL HUECO EN NUMEROS. La pregunta de verdad no es "¿donde estan las cajas?" sino "¿por
#  que me ha dado si estaba lejos?", y eso lo contesta el numero que decide de verdad: el hueco entre
#  los dos bultos, que es 0 cuando se tocan. Dibujarlo al lado de cada bicho ahorra tener que
#  deducirlo mirando dos rectangulos.
#
#  Vive colgado del jugador pero con top_level, o sea en coordenadas de MUNDO: colgado de verdad,
#  todo lo que dibujara saldria girado y desplazado con el.
# ============================================================

extends Node2D

# Hasta donde se mira, en px alrededor del jugador. Los muros son cientos de rectangulos fusionados
# (ver DungeonGenerator.muros_fusionados) y dibujarlos todos en un piso entero cuesta mas que el
# juego. Con esto se ve la sala en la que estas, que es donde estas mirando.
const RADIO := 520.0

const C_HUELLA := Color(0.25, 0.85, 1.00, 0.95)     # la caja fisica de un actor
const C_MURO := Color(0.55, 0.55, 0.62, 0.55)       # la caja fisica de la roca
const C_BULTO := Color(1.00, 0.35, 0.75, 0.95)      # el cuerpo con el que se pega
const C_ATAQUE := Color(1.00, 0.85, 0.25, 0.75)     # el cono del espadazo
const C_INTERACT := Color(0.45, 1.00, 0.45, 0.55)   # el alcance de la F
const C_TOCANDO := Color(1.00, 0.30, 0.25, 1.00)    # el hueco cuando ya es <= 0

# El cuerpo base que supone el enemigo para todo el que no sepa decir cuanto ocupa (ver
# Enemy.hueco_hasta). Se repite aqui a proposito: este visor tiene que enseñar lo que el juego
# SUPONE, no lo que deberia suponer, o dejaria de servir para cazar justo ese fallo.
const MEDIO_BASE := 16.0

# Los cuerpos estaticos (la roca) encontrados en esta escena, cacheados.
#
# SE BUSCAN POR TIPO Y NO POR NOMBRE NI POR GRUPO, y eso importa: la mazmorra mete todos sus muros
# en un unico StaticBody2D llamado "Muros" (ver DungeonFloor), pero el pueblo usa wall.tscn sueltos,
# el estanque se monta el suyo (fishing_spot.gd)... y ninguno comparte grupo. Buscando "Muros" se
# veria la roca de la mazmorra y NADA en el pueblo, que es justo donde uno se queda mirando por que
# no puede pasar por un hueco.
var _estaticos: Array[CollisionObject2D] = []
var _escena_vista: Node = null
# Cuando se rebusco por ultima vez. Sin esto, una escena que de verdad no tiene roca (la arena de
# pruebas vacia) haria un barrido del arbol entero en CADA fotograma, para siempre y para nada.
var _buscado_en: float = -99.0
const REBUSCA_CADA := 2.0


func _ready() -> void:
	top_level = true          # coordenadas de mundo, no las del jugador
	z_as_relative = false
	z_index = 4000            # por encima del personaje y de los bichos, por debajo del HUD
	set_process(true)


func _process(_delta: float) -> void:
	visible = Game.dev_hitboxes
	if visible:
		queue_redraw()        # las cajas se mueven con todo el mundo: hay que repintar cada frame


func _draw() -> void:
	if not Game.dev_hitboxes:
		return
	var jugador: Node2D = get_tree().get_first_node_in_group("player")
	var centro: Vector2 = jugador.global_position if jugador != null else global_position

	# 1. LA ROCA, lo primero (va debajo de todo lo demas). Es lo que contesta "¿por que no paso por
	#    aqui?", que sin esto solo se puede averiguar a base de empujar.
	_refrescar_estaticos()
	for s in _estaticos:
		if is_instance_valid(s):
			_cajas_de(s, centro, C_MURO, 1.0)

	# 2. LOS ALCANCES DEL JUGADOR. Van antes que los cuerpos para que no los tapen.
	if jugador != null:
		_alcances(jugador)

	# 3. CADA ACTOR: su huella (la fisica) y su bulto (con el que pelea).
	for grupo in ["player", "aliado", "enemy"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if not (n is Node2D) or not is_instance_valid(n):
				continue
			var a: Node2D = n
			if a.global_position.distance_to(centro) > RADIO:
				continue
			_cajas_de(a, centro, C_HUELLA, 2.0)
			_bulto_de(a)

	# 4. Y EL HUECO en numeros hasta cada bicho. Es el que decide de verdad si te alcanzan.
	if jugador != null:
		_huecos(jugador, centro)


# La lista de cuerpos estaticos de la escena, recorrida UNA VEZ y guardada.
#
# La roca no se mueve, asi que recorrer el arbol entero en cada _draw seria pagar un barrido de
# cientos de nodos sesenta veces por segundo para obtener siempre lo mismo. Se rehace cuando cambia
# la escena (bajar un piso, entrar al pueblo) y cuando alguien ha añadido cuerpos despues -- el piso
# se genera DESPUES de que exista el jugador, asi que el primer barrido puede pillarlo vacio.
func _refrescar_estaticos() -> void:
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		return
	var vivos: int = 0
	for s in _estaticos:
		if is_instance_valid(s):
			vivos += 1
	if raiz == _escena_vista and vivos > 0:
		return
	# Vacia todavia: se reintenta, pero de tarde en tarde. El piso se genera DESPUES de que exista
	# el jugador, asi que el primer barrido llega a un mapa sin roca y hay que volver.
	var ahora: float = float(Time.get_ticks_msec()) / 1000.0
	if raiz == _escena_vista and ahora - _buscado_en < REBUSCA_CADA:
		return
	_buscado_en = ahora
	_escena_vista = raiz
	_estaticos.clear()
	_buscar_estaticos(raiz)


func _buscar_estaticos(n: Node) -> void:
	var s := n as StaticBody2D
	if s != null:
		_estaticos.append(s)
	for h in n.get_children():
		_buscar_estaticos(h)


# ============================================================
#  LA HUELLA: las formas de colision de VERDAD
# ============================================================
# Se leen del arbol y no de una constante a proposito: lo que hay que poder ver es lo que el motor
# esta usando, no lo que el codigo cree que puso. Un CollisionShape2D desplazado o girado (el
# enemigo gira el suyo cuando es mas largo que ancho, ver Enemy._aplicar_colision) sale en su sitio
# porque se dibuja con SU transform, no con el del cuerpo.
func _cajas_de(raiz: Node, centro: Vector2, color: Color, grosor: float) -> void:
	for hijo in raiz.get_children():
		var cs := hijo as CollisionShape2D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var t: Transform2D = cs.global_transform
		if t.origin.distance_to(centro) > RADIO:
			continue
		var rect := cs.shape as RectangleShape2D
		if rect != null:
			var h: Vector2 = rect.size * 0.5
			var esquinas := PackedVector2Array([
				t * Vector2(-h.x, -h.y), t * Vector2(h.x, -h.y),
				t * Vector2(h.x, h.y), t * Vector2(-h.x, h.y),
				t * Vector2(-h.x, -h.y)])
			draw_polyline(esquinas, color, grosor)
			continue
		var circ := cs.shape as CircleShape2D
		if circ != null:
			draw_arc(t.origin, circ.radius, 0.0, TAU, 24, color, grosor)


# ============================================================
#  EL BULTO: el rectangulo que NO existe como nodo
# ============================================================
# Se pregunta igual que lo pregunta el enemigo -- por has_method("medio_cuerpo") --, y quien no sepa
# contestar se dibuja con el cuerpo base de 32x32. Eso NO es un atajo: es exactamente el fallo que
# este visor tiene que poder enseñar. Si un aliado nuevo se olvida de ese metodo, aqui se le vera el
# bulto mas pequeño que a los demas, que es la pinta que tiene "a este le pegan desde mas cerca".
func _bulto_de(a: Node2D) -> void:
	var medio := Vector2(MEDIO_BASE, MEDIO_BASE)
	if a.has_method("medio_cuerpo"):
		medio = a.medio_cuerpo()
	# Lo que sobresale un elite por encima del cuerpo base (ver Enemy.radio_extra).
	if "radio_extra" in a:
		var extra: float = float(a.radio_extra)
		medio += Vector2(extra, extra)
	var p: Vector2 = a.global_position
	draw_rect(Rect2(p - medio, medio * 2.0), C_BULTO, false, 2.0)
	# El CENTRO, que es de donde se miden todas las distancias del juego. Verlo importa: el nodo
	# esta a la altura de los pies, no en mitad del dibujo, y esa diferencia es la que hace que un
	# golpe "de arriba" conecte antes de lo que parece.
	draw_line(p - Vector2(4, 0), p + Vector2(4, 0), C_BULTO, 1.0)
	draw_line(p - Vector2(0, 4), p + Vector2(0, 4), C_BULTO, 1.0)


# ============================================================
#  LOS ALCANCES DEL JUGADOR
# ============================================================
# El cono del espadazo (attack_range + attack_half_angle_deg) y el circulo de la F. Los dos se miden
# de CENTRO A CENTRO, asi que se dibujan tal cual: la conversion a "hueco entre cuerpos" la hace el
# filtro, y verlos sin convertir es lo que deja comparar el dibujo con el numero del .gd.
func _alcances(j: Node2D) -> void:
	var p: Vector2 = j.global_position
	if "interact_range" in j:
		draw_arc(p, float(j.interact_range), 0.0, TAU, 32, C_INTERACT, 1.5)
	if not ("attack_range" in j and "attack_half_angle_deg" in j):
		return
	var r: float = float(j.attack_range)
	var media: float = deg_to_rad(float(j.attack_half_angle_deg))
	var mira: Vector2 = j._facing if "_facing" in j else Vector2.DOWN
	var a0: float = mira.angle() - media
	draw_arc(p, r, a0, a0 + media * 2.0, 32, C_ATAQUE, 2.0)
	draw_line(p, p + Vector2.RIGHT.rotated(a0) * r, C_ATAQUE, 1.5)
	draw_line(p, p + Vector2.RIGHT.rotated(a0 + media * 2.0) * r, C_ATAQUE, 1.5)


# ============================================================
#  EL HUECO, EN NUMEROS
# ============================================================
# Lo pinta AL LADO DE CADA BICHO y no en una esquina: con tres slimes encima, un numero suelto no
# dice de cual es. Se pide al propio bicho (Enemy.hueco_hasta) en vez de recalcularlo aqui, que es
# lo unico que garantiza que el numero que se lee sea el que decide.
func _huecos(j: Node2D, centro: Vector2) -> void:
	var fuente: Font = ThemeDB.fallback_font
	if fuente == null:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		var b: Node2D = e
		if b.global_position.distance_to(centro) > RADIO or not b.has_method("hueco_hasta"):
			continue
		var h: float = b.hueco_hasta(j)
		if h == INF:
			continue
		# En rojo cuando ya se tocan (hueco <= 0): es el instante en el que el golpe conecta, y
		# tenerlo marcado ahorra ir leyendo decimales.
		var col: Color = C_TOCANDO if h <= 0.0 else C_BULTO
		draw_string(fuente, b.global_position + Vector2(-14, -26),
			"%.0f" % h, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
