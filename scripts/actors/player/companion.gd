# ============================================================
#  companion.gd
#  EL CUERPO de un companero de equipo en el mapa.
#
#  Antes los companeros eran ColorRects sueltos que el rastro teletransportaba (ver
#  party_trail.gd). Servia para verlos, pero para el mundo NO EXISTIAN: atravesaban la roca y
#  ningun bicho podia ir a por ellos. Ahora son CharacterBody2D de verdad, asi que:
#    - chocan con las paredes (no se cuelan por la piedra al doblar una esquina),
#    - estan en el grupo "aliado", que es la lista de objetivos que mira el enemigo.
#
#  Lo que NO cambia es COMO se mueven: no tienen IA ni pathfinding, siguen el rastro que deja el
#  que va en cabeza (party_trail les dice a que punto ir en cada frame). El cuerpo solo aporta la
#  colision: el camino ya es pisable por construccion, porque lo pisaste tu antes.
#
#  COLISION: capa 4 ("aliados"), mascara 1 (solo la roca). Mismo criterio que enemy.gd: si los
#  cuerpos chocaran entre si, dos que se solapan se des-penetran a empujones y acaban saliendo
#  disparados a traves de una pared. El grupo se atraviesa entre si Y te atraviesa a ti: eso no es
#  una concesion, es lo que evita que os bloqueeis unos a otros en un pasillo.
#
#  OJO con el jugador: esta en la capa 1, LA MISMA QUE LA ROCA (ver enemy.gd, que se topa con lo
#  mismo al tirar sus rayos de vision). Asi que la mascara "solo roca" te incluye a ti de propina,
#  y hay que excluirte a mano con una excepcion de colision, o el que va detras se pasa el rato
#  empujando al que llevas delante.
# ============================================================

extends CharacterBody2D

const LADO := 32.0    # el ColorRect de respaldo, para cuando no hay dibujo
# Tope de velocidad al perseguir su punto del rastro. Normalmente va exactamente al ritmo del
# lider (el punto se mueve con el), asi que esto solo actua cuando se ha quedado atras: tras
# engancharse en una esquina, o al cambiar de lider. Por encima de la velocidad MAXIMA del lider
# para que recupere el hueco, pero acotado: sin tope, un salto del rastro lo dispararia de golpe.
# Se mueve con la velocidad MAXIMA del lider, ~15% por encima. Con walk_speed 100 y el bonus de
# Agilidad en +30% (Game.AGILIDAD_VEL_MAX), el lider tope corre a ~230 (170 x 1.30 x 1.04 de
# armadura ligera), asi que 265. Antes eran 380 porque el lider llegaba a ~330.
const VEL_MAX := 265.0
# A partir de cuanto se le da por encallado y se le teletransporta a su sitio (ver seguir()). Tres
# cuerpos de margen: mas que cualquier rodeo honesto por una esquina, menos que "se ha perdido".
const RESCATE := 96.0

# A quien pinta este cuerpo. Lo lee el enemigo (para el nombre en el log) y el rastro para saber
# si tiene que repintarlo.
var pj: PersonajeData = null

var _cuerpo: ColorRect = null
# Rastro de SU imbuicion (null = no lleva ninguna). Ver _pintar_imbue.
var _fx_imbue: CPUParticles2D = null
# Su cuerpo dibujado (ver muneco_jugador.gd) y hacia donde mira. El rastro no le dice a donde
# mirar, solo a donde ir, asi que la mirada se deduce de por donde se esta moviendo.
var _muneco: MunecoJugador = null
var _facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4   # capa "aliados"
	collision_mask = 1    # solo el mundo (paredes)
	# Z ABSOLUTO, y a la altura del jugador y de los bichos. Es la unica forma de que se vean: el
	# z_index normal es RELATIVO al del padre, y el sequito cuelga de un nodo que ya iba a -1, asi
	# que un -1 suyo los mandaba a -2... justo por DEBAJO del suelo de la mazmorra, que se pinta a
	# -1 (ver dungeon_floor). En el pueblo no hay suelo pintado y por eso alli si se veian.
	z_as_relative = false
	z_index = 0
	add_to_group("aliado")

	# El cuerpo del jugador comparte capa con la roca: se le excluye para poder atravesarlo.
	# (ver caja_cuerpo() al final: es lo que hace que a un compañero le peguen igual que a ti)
	var lider: Node = get_tree().get_first_node_in_group("player")
	if lider is CollisionObject2D:
		add_collision_exception_with(lider)

	_cuerpo = ColorRect.new()
	_cuerpo.offset_left = -LADO * 0.5
	_cuerpo.offset_top = -LADO * 0.5
	_cuerpo.offset_right = LADO * 0.5
	_cuerpo.offset_bottom = LADO * 0.5
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cuerpo)

	# LA HUELLA DE LOS PIES, la misma que la del jugador (ver PoseJugador.HUELLA): baja y pegada al
	# suelo, para que a 45 grados solo los pies choquen con el muro. Sale de alli y no de un numero
	# propio porque si los tres cuerpos no coinciden, el mismo pasillo se pasa o no segun quien lo
	# intente -- y el sequito va justo detras de ti, por el sitio que acabas de pasar tu.
	var col := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = PoseJugador.HUELLA
	col.shape = forma
	col.position = Vector2(0.0, PoseJugador.HUELLA_Y)
	add_child(col)

	if pj != null:
		pintar(pj)


# El aspecto de su dueño: su color, su brillo y su imagen (el mismo shader que el lider, ver
# Game.material_de). Es lo que te permite distinguirlos de un vistazo.
func pintar(nuevo: PersonajeData) -> void:
	pj = nuevo
	if _cuerpo == null or pj == null:
		return
	if _muneco == null:
		_muneco = MunecoJugador.new()
		add_child(_muneco)
	_muneco.montar(pj)
	if _muneco.hay_dibujo():
		# SU color y SU metal, no los del lider: distinguirlos de un vistazo es justo para lo que
		# esta el aspecto, y en un grupo de cuatro es la unica forma de saber a quien estas mirando.
		_muneco.tenir(pj.color, pj.metalico)
		# Y SU cara, por lo mismo: en una fila de cuatro, la imagen es lo que dice quien es quien.
		_muneco.poner_cara(pj.textura())
		_cuerpo.visible = false
	else:
		_cuerpo.visible = true
		_cuerpo.color = pj.color
		_cuerpo.material = Game.material_de(pj)
	refrescar_imbue()


# Cada companero lleva SU rastro, leido de SU ficha: los buffs se le echan a quien tu quieras, asi
# que el de atras puede ir imbuido en fuego y tu en nada. Mismo criterio que el lider, porque los
# dos preguntan a la ficha (PersonajeData.imbue_elemento).
#
# PUBLICA a proposito: pintar() solo se llama cuando el cuerpo cambia de dueño (ver
# party_trail.refrescar), y la imbuicion cambia con la MISMA gente en la fila.
func refrescar_imbue() -> void:
	if pj == null:
		return
	var elem: int = pj.imbue_elemento()
	if not Elementos.tiene_color(elem):
		if _fx_imbue != null:
			_fx_imbue.queue_free()
			_fx_imbue = null
		return
	if _fx_imbue == null:
		# El ALTO del cuerpo dibujado y no el del ColorRect (ver la misma nota en remote_player.gd):
		# el rastro sube por el personaje entero, y con 32 se quedaba a media altura.
		_fx_imbue = Particulas.ascendentes(self, Elementos.color(elem), 1.0,
			PoseJugador.ALTO_MUNDO)
	else:
		Particulas.repintar(_fx_imbue, Elementos.color(elem))


# Avanza hacia el punto del rastro que le toca. La velocidad es "lo que falta / delta": asi
# aterriza EXACTAMENTE en su punto y la fila no se deforma, y la unica cosa que puede impedirlo
# es una pared (que es justo para lo que esta el cuerpo).
func seguir(destino: Vector2, delta: float) -> void:
	# Los companeros se ATRAVIESAN entre si (y al lider): el grupo entero es intangible por dentro, a
	# proposito, para no bloquearse en un pasillo. Si al pararte el rastro se colapsa y se solapan un
	# rato, no pasa nada: son un grupo, no tres cuerpos que tienen que hacer sitio. Por eso aqui NO
	# hay separacion: cada uno va a su punto del rastro y punto.
	var falta: Vector2 = destino - global_position
	# RESCATE: si se ha quedado MUY atras, se le planta en su punto y a seguir. Pasa cuando un
	# cuerpo se enrieda en una esquina o acaba dentro de la roca (un teletransporte raro, un
	# combate que lo dejo descolocado). El punto del rastro es pisable por definicion -lo acabas
	# de pisar tu-, asi que el rescate nunca lo mete en una pared. Sin esto, un companero
	# encallado se quedaba atras PARA SIEMPRE: el destino se aleja y el no puede alcanzarlo.
	if falta.length() > RESCATE:
		plantar(destino)
		return
	if delta <= 0.0 or falta.length() < 0.5:
		velocity = Vector2.ZERO
		_animar(false)
		return
	velocity = (falta / delta).limit_length(VEL_MAX)
	move_and_slide()
	if velocity.length() > 2.0:
		_facing = velocity.normalized()
	_animar(velocity.length() > 2.0)


# VA AL PASO DEL LIDER, y por eso le pregunta a el en que modo va en vez de deducirlo de su propia
# velocidad. El grupo entero anda, corre o se agazapa a la vez (es lo que ya hacia el calculo de
# velocidad de player.gd), asi que un compañero corriendo detras de un lider agachado seria mentira
# -- y encima delataria el sigilo, que es medio juego.
func _animar(moviendose: bool) -> void:
	if _muneco == null or not _muneco.hay_dibujo():
		return
	var lider: Node = get_tree().get_first_node_in_group("player")
	var modo: int = int(lider.get("movement_mode")) if lider != null else 1
	_muneco.animar(PoseJugador.animacion(_facing, modo, moviendose))


# Colocacion DURA (cambio de piso, cambio de lider): aqui no se anda, se aparece.
func plantar(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO


# La caja con la que se PELEA, relativa a su nodo. La pregunta Cuerpos.caja_de por has_method, asi
# que basta con tenerla para que le peguen igual que al lider.
#
# SIN ESTO, A UN COMPAÑERO LE PEGABAN DESDE MAS CERCA QUE A TI y no habria dado ningun error: el
# bicho se queda con el cuerpo base de 32x32 para todo el que no sepa contestar, asi que el mismo
# ataque conectaba contigo y no con el de al lado. Ver la nota de los dos cuerpos en pose_jugador.gd.
func caja_cuerpo() -> Rect2:
	return PoseJugador.CAJA_CUERPO
