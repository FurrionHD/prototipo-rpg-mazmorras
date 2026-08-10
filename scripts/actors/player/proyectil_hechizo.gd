# ============================================================
#  proyectil_hechizo.gd
#  El conjuro que sale disparado cuando terminas de recitar en el mapa (ver casteo_mapa.gd). Va del
#  que lo lanza al bicho y, al llegar, avisa por su señal: quien la escucha es el que abre el
#  combate (player._impacto_conjuro).
#
#  CADA ELEMENTO TIENE SU FORMA. Al principio esto era un cuadrado del color del elemento girando, y
#  el resultado es que todo parecia la misma bola de fuego pintada de otro color. Se dibuja a mano
#  (_draw) porque son cuatro formas simples y asi no hace falta ni un PNG ni un shader:
#
#    FUEGO -> nucleo claro + halo que late + lengüetas de llama que ondean.
#    AGUA  -> una GOTA estirada en la direccion de vuelo, con su brillo.
#    RAYO  -> ni bola ni nada redondo: un ZIGZAG que chisporrotea y se redibuja solo.
#    (sin elemento) -> rombo arcano girando dentro de un anillo fino.
#
#  Y EL TAMAÑO SALE DE LA POTENCIA del hechizo: una Descarga es una chispa y una Tormenta es una
#  bola que se ve venir. Es informacion, no adorno: por el tamaño sabes lo que le va a caer encima.
#
#  PERSIGUE AL NODO, no a un punto: entre que sale y llega, el bicho se ha movido. Y si el bicho
#  desaparece por el camino (lo mata un DoT, lo recicla el piso), el conjuro se disipa sin avisar a
#  nadie -- el maná ya se gasto al soltarlo, igual que en combate.
# ============================================================

extends Node2D

signal impacto(objetivo: Node)

# Lo que tarda en recorrer la distancia. Va por VELOCIDAD y no por tiempo fijo: a bocajarro tiene
# que sentirse instantaneo y desde lejos tiene que verse volar.
const VELOCIDAD := 520.0
# Si el objetivo huye mas rapido de lo que vuela el conjuro, esto evita que lo persiga eternamente.
const VIDA_MAX := 3.0

# RADIO segun la potencia del hechizo. Los extremos de hoy son Descarga (6 de daño mostrado) y
# Tormenta (46): por debajo y por encima se queda clavado en los topes, asi que un hechizo futuro
# mas bestia no reventara la pantalla.
const DANO_MIN := 6.0
const DANO_MAX := 46.0
const RADIO_MIN := 9.0
const RADIO_MAX := 26.0

var _objetivo: Node = null
var _color: Color = Color.WHITE
var _elemento: int = Elementos.Elemento.NINGUNO
var _radio: float = RADIO_MIN
var _vida: float = 0.0
var _dir: Vector2 = Vector2.RIGHT   # hacia donde vuela (la gota y el rayo se orientan con ella)
var _t: float = 0.0                 # reloj propio para las animaciones
var _semilla: float = 0.0           # para que dos conjuros a la vez no ondeen identicos
var _zigzag: PackedVector2Array = PackedVector2Array()
var _prox_zigzag: float = 0.0


# 'spell' se usa solo para el ASPECTO (elemento y tamaño): lo que hace el hechizo se resuelve dentro
# del combate, aqui no se pega a nadie.
func setup(objetivo: Node, color: Color, spell: SpellData = null) -> void:
	_objetivo = objetivo
	_color = color
	if spell != null:
		_elemento = spell.elemento
		var dano: float = spell.dano_mostrado()
		var t: float = clampf((dano - DANO_MIN) / maxf(1.0, DANO_MAX - DANO_MIN), 0.0, 1.0)
		_radio = lerpf(RADIO_MIN, RADIO_MAX, t)


func _ready() -> void:
	z_as_relative = false
	z_index = 5   # por encima de los cuerpos: el conjuro pasa POR DELANTE
	_semilla = randf() * 10.0
	# La estela: las mismas particulas que llevan los bichos elementales, con el color del hechizo.
	# local_coords = false, asi que se quedan por donde ha pasado y dibujan el rastro solas.
	Particulas.ascendentes(self, _color, 1.0, _radio * 2.0)


func _process(delta: float) -> void:
	_t += delta
	_vida += delta
	if not is_instance_valid(_objetivo) or _vida > VIDA_MAX:
		queue_free()   # se ha quedado sin a quien ir: se disipa y no avisa a nadie
		return
	var destino: Vector2 = (_objetivo as Node2D).global_position
	var paso: float = VELOCIDAD * delta
	var hacia: Vector2 = destino - global_position
	if hacia.length() > 0.01:
		_dir = hacia.normalized()
	queue_redraw()   # las cuatro formas estan animadas: se repinta cada frame
	if hacia.length() <= paso:
		global_position = destino
		var obj := _objetivo
		_objetivo = null   # que un segundo frame no vuelva a emitir
		_reventar(destino)
		impacto.emit(obj)
		queue_free()
		return
	global_position += _dir * paso


# El DESTELLO del impacto. Se queda colgando del mundo (no de este nodo, que se libera ya) y se
# apaga solo. Reusa los destellos de siempre (Particulas), con el color del elemento.
func _reventar(donde: Vector2) -> void:
	var mundo: Node = get_parent()
	if mundo == null:
		return
	var chispa := Node2D.new()
	chispa.global_position = donde
	chispa.z_as_relative = false
	chispa.z_index = 6
	mundo.add_child(chispa)
	Particulas.destellos(chispa, _color, Vector2(_radio * 3.0, _radio * 3.0), 1.0, 2.0)
	# Se va solo: un temporizador de usar y tirar, que es mas barato que un Tween para esto.
	var t := Timer.new()
	t.wait_time = 1.2
	t.one_shot = true
	t.timeout.connect(chispa.queue_free)
	chispa.add_child(t)
	t.start()


# ------------------------------------------------------------
#  DIBUJO: una forma por elemento
# ------------------------------------------------------------
func _draw() -> void:
	match _elemento:
		Elementos.Elemento.FUEGO: _dibujar_fuego()
		Elementos.Elemento.AGUA: _dibujar_agua()
		Elementos.Elemento.RAYO: _dibujar_rayo()
		_: _dibujar_arcano()


# Bola de fuego: un nucleo casi blanco (lo mas caliente), el halo del color del elemento latiendo, y
# lengüetas de llama que ondean hacia ATRAS, como si el aire se las peinara al volar.
func _dibujar_fuego() -> void:
	var pulso: float = 1.0 + 0.12 * sin(_t * 14.0 + _semilla)
	var r: float = _radio * pulso
	var atras: Vector2 = -_dir
	var puntas := PackedVector2Array()
	var n := 9
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var dirp := Vector2(cos(a), sin(a))
		# Las que apuntan hacia atras se estiran (la llama va detras); las de delante se comprimen.
		var estira: float = 1.0 + 0.85 * maxf(0.0, dirp.dot(atras))
		var ondeo: float = 1.0 + 0.22 * sin(_t * 18.0 + float(i) * 1.7 + _semilla)
		puntas.append(dirp * r * estira * ondeo)
	draw_colored_polygon(puntas, Color(_color.r, _color.g, _color.b, 0.55))
	draw_circle(Vector2.ZERO, r * 0.62, _color)
	draw_circle(Vector2.ZERO, r * 0.34, Color(1.0, 0.95, 0.75))


# Gota: alargada en la direccion de vuelo, con la punta POR DELANTE (parte el aire) y la cola
# detras. El brillo va descentrado, arriba a la izquierda del cuerpo, como en cualquier gota.
func _dibujar_agua() -> void:
	var lado: Vector2 = Vector2(-_dir.y, _dir.x)
	var r: float = _radio * (1.0 + 0.06 * sin(_t * 9.0 + _semilla))
	var pts := PackedVector2Array([
		_dir * r * 1.75,                       # la punta, delante
		lado * r * 0.72 + _dir * r * 0.15,
		-_dir * r * 1.15 + lado * r * 0.30,    # la cola, ancha y corta
		-_dir * r * 1.30,
		-_dir * r * 1.15 - lado * r * 0.30,
		-lado * r * 0.72 + _dir * r * 0.15,
	])
	draw_colored_polygon(pts, _color)
	# Reflejo: el mismo color aclarado, no blanco puro, para no perder el azul.
	var claro := Color(minf(1.0, _color.r + 0.45), minf(1.0, _color.g + 0.35),
		minf(1.0, _color.b + 0.25), 0.85)
	draw_circle(_dir * r * 0.25 + lado * r * 0.22, r * 0.26, claro)


# Rayo: NADA redondo. Un zigzag corto que se rehace varias veces por segundo (chisporroteo) con un
# resplandor detras. Se orienta con la direccion de vuelo, asi que parece que va abriendo camino.
const ZIGZAG_CADA := 0.05

func _dibujar_rayo() -> void:
	if _t >= _prox_zigzag:
		_prox_zigzag = _t + ZIGZAG_CADA
		_zigzag = _nuevo_zigzag()
	if _zigzag.size() < 2:
		return
	# Resplandor: la misma linea, mas gorda y translucida, por debajo.
	draw_polyline(_zigzag, Color(_color.r, _color.g, _color.b, 0.30), _radio * 0.75, true)
	draw_polyline(_zigzag, _color, _radio * 0.34, true)
	draw_polyline(_zigzag, Color(1, 1, 1, 0.9), _radio * 0.13, true)


func _nuevo_zigzag() -> PackedVector2Array:
	var lado: Vector2 = Vector2(-_dir.y, _dir.x)
	var largo: float = _radio * 2.6
	var pts := PackedVector2Array()
	var n := 5
	for i in n:
		var t: float = float(i) / float(n - 1)          # 0..1 de la cola a la punta
		var desvio: float = 0.0 if i == 0 or i == n - 1 else randf_range(-0.55, 0.55)
		pts.append(_dir * lerpf(-largo * 0.5, largo * 0.5, t) + lado * desvio * _radio)
	return pts


# Sin elemento: un rombo girando dentro de un anillo fino. Se lee como "magia" sin tirar de ningun
# color elemental, que es justo lo que es.
func _dibujar_arcano() -> void:
	var g: float = _t * 3.2 + _semilla
	var r: float = _radio * (1.0 + 0.08 * sin(_t * 7.0))
	var eje := Vector2(cos(g), sin(g))
	var lado := Vector2(-eje.y, eje.x)
	draw_colored_polygon(PackedVector2Array([
		eje * r, lado * r * 0.55, -eje * r, -lado * r * 0.55,
	]), _color)
	draw_arc(Vector2.ZERO, r * 1.25, 0.0, TAU, 24, Color(_color.r, _color.g, _color.b, 0.5), 2.0, true)
