# ============================================================
#  slime_aire.gd
#  LOS EFECTOS DE LOS SLIMES en el mapa (28/09/2026; la lista la aprobo el usuario). Todo del COLOR DEL SLIME
#  que lo lanza, que viaja metido en los bits altos de la semilla (ver semilla_con_color): asi el espejo pinta
#  lo mismo sin mandar nada mas por red.
#  POR EL SUELO (SueloRoto.Tipo.SLIME_*, en el orden de Modo; el golpe le llega a cada uno cuando le alcanza):
#    SPLAT       Reventon: cae del salto y revienta en un CHARCO de gel con una corona de gotas que salen
#                disparadas; el nucleo mas denso.
#    APLASTA     Aplastamiento del Rey: lo mismo en grande, con la onda de choque y las losas del martillo.
#    MAREA       Marea corrosiva: tres anillos de baba que se abren desde el Rey (uno por tramo).
#    COMBUSTION  Combustion: una bola de fuego revienta sobre el slime y la onda de llamas llega al borde.
#    SALPICA     Salpicadura ardiente: se sacude y saltan gotas de lava en anillo; chisporrotean en el suelo.
#    ROCIADA     Rociada corrosiva: un abanico de gotas (cometas) por el cono que dejan manchas.
#    LLAMARADA   Llamarada: el aliento de la Brasa (MagiaAire.ALIENTO) estrechado a su linea.
#    PRESION     Presion del abismo: una ola de GARRAS NEGRAS en media luna (con su pincelada clara rota) que barre su
#                linea y deja tinta salpicada y sombra. El abisal es de OSCURIDAD, no de agua (lo dijo el usuario,
#                28/09), y con el lenguaje de NUESTRA oscuridad (la Voragine): nada de fuego negro.
#    PLACAJE     Placaje: el rastro de baba que deja al embestir y el salpicon al chocar.
#    EMBATE      Doble embate: los dos coletazos, la ida y vuelta del Segar (BarridoAire.SIEGA) en gel.
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.SLIME_*):
#    GOLPE       el basico: salpicon de gel sobre el que recibe, hacia atras de donde viene el golpe.
#    ESCUPE      el Escupitajo (y las gotas del Brote): una bola de baba en parabola con estela de gotas que
#                revienta en el pecho y deja un charquito.
#    TROMBA      Tromba abisal: un EMBUDO de medias lunas negras que gira y se estrecha cae sobre el (cabeza negra con
#                el ojo claro del eclipse) y a sus pies se abre un REMOLINO de brazos negros, una Voragine pequeña.
#    IGNICION    Ignicion: el slime de fuego SE PRENDE: llamas que le suben del cuerpo, calor en el suelo y ascuas.
#    TROZO       Escision: un trozo del Rey sale disparado hacia el, le revienta encima y vuelve.
#  NADA DE LINEAS peladas: gel = silueta llena con borde oscuro, cuerpo y brillo; gotas = cometas. Suelo sin
#  achatar; lo que va por el aire, a su altura por K. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name SlimeAire

# Los del suelo van en el orden de SueloRoto.Tipo.SLIME_*: no reordenar.
enum Modo { SPLAT, APLASTA, MAREA, COMBUSTION, SALPICA, ROCIADA, LLAMARADA, PRESION, PLACAJE, EMBATE,
	GOLPE, ESCUPE, TROMBA, TROZO, IGNICION, PUAS }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80

const T_SPLAT := 0.16            # lo que tarda el charco en abrirse hasta el borde
const T_APLASTA := 0.3           # la onda del Aplastamiento hasta el borde
const T_MAREA := 0.75            # lo que tarda cada anillo de la marea en llegar al borde
const T_ENTRE_OLAS := 0.14
const T_COMBUSTION := 0.26       # la onda de llamas de la Combustion hasta el borde
const T_SALPICA := 0.34          # lo que vuela una gota de lava
const T_ROCIADA := 0.3           # lo que vuela una gota de la rociada hasta el fondo
const T_PLACAJE := 0.2           # = CombatTactico.T_EMBESTIDA_BICHO (el rastro va con el cuerpo)
const T_QUEDA := 0.9             # lo que se queda el charco antes de secarse
const T_SECA := 0.6
const T_COLUMNA := 0.16          # lo que tarda la columna de la tromba en caer
const T_PUAS := 0.2              # lo que tardan las puas de Expandir puas en llegar al borde del circulo
const CRISTAL := Color(0.55, 0.95, 1.0)
const CRISTAL_OSCURO := Color(0.16, 0.42, 0.55)
const ALTO_COLUMNA := 95.0
const ALTO_BOCA := 8.0           # de donde sale el escupitajo (la boca del slime, sobre sus pies)

const FUEGO_OSCURO := Color(0.42, 0.07, 0.03)
const FUEGO_ROJO := Color(0.85, 0.16, 0.04)
const FUEGO_NARANJA := Color(1.0, 0.5, 0.1)
const FUEGO_AMARILLO := Color(1.0, 0.82, 0.3)
const FUEGO_BLANCO := Color(1.0, 0.97, 0.78)
const HUMO := Color(0.13, 0.11, 0.11)
const CHAMUSCADO := Color(0.05, 0.03, 0.02)
# LA OSCURIDAD del abisal: la de la Voragine (MagiaMayor): formas negras RELLENAS en media luna con una pincelada
# clara ROTA en el borde, gotas de tinta, sombra en el suelo y el ojo blanco-azulado del eclipse. Sin llamas.
const T_OSCURO := 0.45           # lo que tarda el frente de la Presion en recorrer su linea
const T_IGNICION := 0.9

var modo: int = Modo.SPLAT
var forma: CombatFormas.Forma = null
var color: Color = Color(0.35, 0.7, 0.95)
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _o: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _r: float = 30.0
var _largo: float = 40.0
var _ancho: float = 16.0
var _gotas: Array = []
var _manchas: Array = []
var _llamas: Array = []
var _desde: Vector2 = Vector2.ZERO   # sobre un cuerpo: de donde viene
var _hasta: Vector2 = Vector2.ZERO   # sobre un cuerpo: su pecho
var _pies: Vector2 = Vector2.ZERO    # sobre un cuerpo: sus pies
var _viaje: float = 0.2              # lo que tarda en llegar lo que viaja (el vuelo del golpe)
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  EL COLOR EN LA SEMILLA
# ------------------------------------------------------------
# 12 bits de color (4 por canal) en los bits 18-29; los 18 de abajo son el azar (impar). Cabe en los 30 bits
# de siempre, asi que viaja por el paquete del suelo (MARCA_SUELO) sin cambiar nada.
static func semilla_con_color(azar: int, col: Color) -> int:
	var rgb: int = (clampi(roundi(col.r * 15.0), 0, 15) << 8) | (clampi(roundi(col.g * 15.0), 0, 15) << 4) \
		| clampi(roundi(col.b * 15.0), 0, 15)
	return (rgb << 18) | (azar & 0x3FFFF) | 1


static func color_de_semilla(semilla: int) -> Color:
	var rgb: int = (semilla >> 18) & 0xFFF
	if rgb == 0:
		return Color(0.35, 0.7, 0.95)
	return Color(float((rgb >> 8) & 15) / 15.0, float((rgb >> 4) & 15) / 15.0, float(rgb & 15) / 15.0)


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> Node2D:
	if padre == null or f == null:
		return null
	var col: Color = color_de_semilla(semilla)
	# LOS PRESTADOS: lo que ya te gusto en las armas y las magias, con el color o el tinte del slime.
	match m:
		Modo.LLAMARADA:
			return MagiaAire.area(padre, _cono_de_linea(f), MagiaAire.Modo.ALIENTO, semilla, espera)
		Modo.EMBATE:
			var b: Node2D = BarridoAire.lanzar(padre, f, BarridoAire.Modo.SIEGA, semilla, espera)
			if b != null:
				b.modulate = col.lightened(0.25)
			return b
		Modo.APLASTA:
			# Las LOSAS del golpe sismico, bajo el charco (el Rey cae con todo su peso).
			var losas := CombatFormas.circulo(f.centro, f.radio * 0.8)
			SueloRoto.lanzar(padre, losas, SueloRoto.Tipo.FRAGMENTOS, semilla, 0.0, espera)
	var e := SlimeAire.new()
	e.modo = m
	e.forma = f
	e.color = col
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._preparar_area()
	return e


# La LLAMARADA es una linea en la ficha (su huella) y el aliento es un cono: el mismo largo, abierto lo justo.
static func _cono_de_linea(f: CombatFormas.Forma) -> CombatFormas.Forma:
	var largo: float = f.largo if f.largo > 0.0 else f.radio
	var abre: float = clampf(rad_to_deg(atan2(maxf(f.ancho, 8.0), largo)) * 2.0, 14.0, 40.0)
	return CombatFormas.cono(f.origen, f.dir, largo, abre)


# CUANDO LE LLEGA a 'p', en segundos desde que se lanza (la misma cuenta que el dibujo).
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	var o: Vector2 = SueloRoto.origen_de(f)
	var u: float = clampf(p.distance_to(o) / maxf(f.radio, 1.0), 0.0, 1.0)
	match m:
		Modo.SPLAT: return u * T_SPLAT
		Modo.APLASTA: return u * T_APLASTA
		Modo.MAREA: return u * T_MAREA
		Modo.COMBUSTION: return u * T_COMBUSTION
		Modo.SALPICA: return u * T_SALPICA
		Modo.ROCIADA: return u * T_ROCIADA
		Modo.PLACAJE:
			return clampf((p - f.origen).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0) * T_PLACAJE
		Modo.LLAMARADA:
			return MagiaAire.retraso(MagiaAire.Modo.ALIENTO, _cono_de_linea(f), p)
		Modo.PRESION:
			return clampf((p - f.origen).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0) * T_OSCURO
		Modo.EMBATE:
			return BarridoAire.retraso_px(BarridoAire.Modo.SIEGA, p.distance_to(o), f.radio)
		Modo.PUAS: return u * T_PUAS
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.SPLAT: return T_SPLAT
		Modo.APLASTA: return T_APLASTA
		Modo.MAREA: return T_MAREA + T_ENTRE_OLAS * 2.0
		Modo.COMBUSTION: return T_COMBUSTION
		Modo.SALPICA: return T_SALPICA
		Modo.ROCIADA: return T_ROCIADA
		Modo.PLACAJE: return T_PLACAJE
		Modo.LLAMARADA: return MagiaAire.t_salir(MagiaAire.Modo.ALIENTO)
		Modo.PRESION: return T_OSCURO
		Modo.EMBATE: return BarridoAire.T_ENTRE * 2.0
		Modo.PUAS: return T_PUAS
	return 0.3


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = de donde viene (el pecho o la boca de quien lo lanza), 'caja' = el cuerpo que lo recibe, 'espera' =
# lo que falta para el golpe (lo que viaja ocupa ese tiempo).
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, col: Color, semilla: int,
		espera: float, ritmo: float) -> SlimeAire:
	if padre == null:
		return null
	var e := SlimeAire.new()
	e.modo = m
	e.color = col
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._viaje = maxf(espera, 0.08)
	e._t = -e._viaje
	e._desde = desde
	e._hasta = caja.get_center()
	e._pies = Vector2(caja.get_center().x, caja.end.y)
	e._ancho = maxf(caja.size.x, 10.0)
	e._largo = maxf(caja.size.y, 16.0)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	var atras: Vector2 = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	var n_gotas: int = 7 if m == Modo.GOLPE else 10
	for i in n_gotas:
		# Salen hacia ATRAS de donde viene el golpe, abiertas en abanico, y caen.
		var a: float = atras.angle() + e._rng.randf_range(-1.1, 1.1)
		e._gotas.append({"v": Vector2(cos(a), sin(a) * K) * e._rng.randf_range(35.0, 70.0),
			"sube": e._rng.randf_range(20.0, 45.0), "tam": e._rng.randf_range(2.4, 3.8), "t0": e._rng.randf_range(0.0, 0.05)})
	for i in 14:
		e._llamas.append({"x": e._rng.randf_range(-0.5, 0.5), "t0": e._rng.randf_range(0.0, 0.55),
			"tam": e._rng.randf_range(0.8, 1.3), "fase": e._rng.randf_range(0.0, 50.0), "vida": e._rng.randf_range(0.35, 0.55),
			"a": e._rng.randf_range(0.0, TAU)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


func duracion() -> float:
	match modo:
		Modo.SPLAT, Modo.APLASTA: return T_APLASTA + T_QUEDA + T_SECA
		Modo.MAREA: return T_MAREA + T_ENTRE_OLAS * 2.0 + T_QUEDA + T_SECA
		Modo.COMBUSTION: return T_COMBUSTION + 1.3
		Modo.SALPICA: return T_SALPICA + T_QUEDA + T_SECA
		Modo.ROCIADA: return T_ROCIADA + T_QUEDA + T_SECA
		Modo.PLACAJE: return T_PLACAJE + T_QUEDA + T_SECA
		Modo.GOLPE: return 0.6
		Modo.ESCUPE: return 0.25 + T_QUEDA * 0.6 + T_SECA
		Modo.TROMBA: return T_COLUMNA + 0.8
		Modo.IGNICION: return T_IGNICION + 0.5
		Modo.PRESION: return T_OSCURO + 1.2
		Modo.TROZO: return 0.75
		Modo.PUAS: return T_PUAS + T_QUEDA + T_SECA
	return 1.0


func _preparar_area() -> void:
	_o = SueloRoto.origen_de(forma)
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_r = maxf(forma.radio, 8.0)
	_largo = maxf(forma.largo if forma.tipo == CombatFormas.Tipo.LINEA else forma.radio, 4.0)
	_ancho = maxf(forma.ancho, 8.0)
	match modo:
		Modo.SPLAT, Modo.APLASTA:
			var n: int = 18 if modo == Modo.SPLAT else 30
			for i in n:
				var a: float = TAU * (float(i) + _rng.randf_range(0.0, 0.8)) / float(n)
				_gotas.append({"a": a, "u": _rng.randf_range(0.55, 1.05), "sube": _rng.randf_range(18.0, 40.0),
					"tam": _rng.randf_range(1.8, 3.2) * (1.4 if modo == Modo.APLASTA else 1.0), "t0": _rng.randf_range(0.0, 0.05)})
			for i in 7:
				_manchas.append({"a": _rng.randf_range(0.0, TAU), "u": _rng.randf_range(0.5, 1.0),
					"r": _rng.randf_range(0.1, 0.18) * _r})
		Modo.MAREA:
			for i in 36:
				_gotas.append({"a": _rng.randf_range(0.0, TAU), "ola": i % 3, "sube": _rng.randf_range(8.0, 18.0),
					"tam": _rng.randf_range(1.5, 2.6), "fase": _rng.randf()})
		Modo.COMBUSTION:
			for i in 22:
				_llamas.append({"a": TAU * float(i) / 22.0 + _rng.randf_range(-0.1, 0.1), "u": _rng.randf_range(0.7, 1.0),
					"tam": _rng.randf_range(0.8, 1.25), "fase": _rng.randf_range(0.0, 50.0), "vida": _rng.randf_range(0.45, 0.7)})
			for i in 18:
				_gotas.append({"a": _rng.randf_range(0.0, TAU), "u": _rng.randf_range(0.2, 1.0), "fase": _rng.randf_range(0.0, TAU),
					"vida": _rng.randf_range(0.8, 1.4), "tam": _rng.randf_range(0.8, 1.5)})
		Modo.SALPICA:
			for i in 16:
				var a: float = TAU * (float(i) + _rng.randf_range(0.0, 0.7)) / 16.0
				_gotas.append({"a": a, "u": _rng.randf_range(0.45, 1.0), "sube": _rng.randf_range(22.0, 40.0),
					"tam": _rng.randf_range(2.0, 3.2), "t0": _rng.randf_range(0.0, 0.06)})
		Modo.ROCIADA:
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			for i in 20:
				_gotas.append({"a": _rng.randf_range(-mitad, mitad) * 0.9, "u": _rng.randf_range(0.35, 1.0),
					"sube": _rng.randf_range(6.0, 16.0), "tam": _rng.randf_range(1.6, 2.8), "t0": _rng.randf_range(0.0, 0.08)})
		Modo.PRESION:
			var n3: int = int(clampf(_largo / 4.0, 12.0, 30.0))
			for i in n3:
				_llamas.append({"u": (float(i) + _rng.randf_range(0.0, 0.8)) / float(n3), "v": _rng.randf_range(-0.45, 0.45),
					"tam": _rng.randf_range(0.8, 1.3), "fase": _rng.randf_range(0.0, 50.0), "vida": _rng.randf_range(0.45, 0.7)})
			for i in 10:
				_manchas.append({"u": _rng.randf_range(0.05, 1.0), "v": _rng.randf_range(-0.3, 0.3), "r": _rng.randf_range(0.3, 0.5) * _ancho})
		Modo.PUAS:
			# (06/10, su diagnostico: "son un poco cutres y salen desde dentro de el, y no tiene las puas dentro sino en sus
			# esquinas") Pocas y GRANDES, con la forma de las suyas (cristal de dos puntas), y salen de su PIEL, no del centro.
			var n4: int = 9
			var giro: float = _rng.randf_range(0.0, TAU)
			for i in n4:
				_llamas.append({"a": giro + TAU * (float(i) + _rng.randf_range(-0.18, 0.18)) / float(n4),
					"u": _rng.randf_range(0.86, 1.0), "l": _rng.randf_range(13.0, 17.0), "t0": _rng.randf_range(0.0, 0.03),
					"w": _rng.randf_range(3.6, 4.6), "gira": _rng.randf_range(-0.25, 0.25)})
		Modo.PLACAJE:
			var n2: int = int(clampf(_largo / 5.0, 5.0, 16.0))
			for i in n2:
				_manchas.append({"u": (float(i) + _rng.randf_range(0.0, 0.6)) / float(n2), "v": _rng.randf_range(-0.25, 0.25),
					"r": _rng.randf_range(0.28, 0.45) * _ancho})
			for i in 9:
				var a2: float = _dir.angle() + _rng.randf_range(-1.3, 1.3)
				_gotas.append({"v": Vector2(cos(a2), sin(a2) * K) * _rng.randf_range(30.0, 60.0),
					"sube": _rng.randf_range(15.0, 30.0), "tam": _rng.randf_range(1.6, 2.6)})
	_suelo = _capa(SueloRoto.Z_SUELO, false)
	_delante = _capa(Z_ENCIMA, false)
	_brillo = _capa(Z_ENCIMA + 1, true)


func _capa(z: int, aditiva: bool) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	if aditiva:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = mat
	add_child(n)
	n.draw.connect(_dibujar_capa.bind(n))
	return n


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	for n in [_suelo, _delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


# ------------------------------------------------------------
#  PIEZAS DE GEL
# ------------------------------------------------------------
static func _alto(h: float) -> Vector2:
	return Vector2(0.0, -h * K)


static func _ruido(x: float, k: float) -> float:
	return fmod(absf(sin(x * 12.9898 + k * 78.233) * 43758.5453), 1.0)


func _oscuro() -> Color:
	return color.darkened(0.55)


func _claro() -> Color:
	return color.lightened(0.5)


# UNA MANCHA DE GEL: silueta llena y blanda (borde oscuro, cuerpo del color, brillo claro arriba a la
# izquierda). 'achata' < 1 la aplasta hacia el suelo; 'sem' cambia sus bultos. Sin una sola raya.
func _gota(ci: CanvasItem, c: Vector2, r: float, alfa: float, achata: float = 1.0, sem: float = 0.0) -> void:
	if r <= 0.4 or alfa <= 0.01:
		return
	var n: int = 14
	var capas: Array = [[1.0, _oscuro()], [0.8, color], [0.34, _claro()]]
	for k in capas.size():
		var esc: float = float(capas[k][0])
		var col: Color = Color(capas[k][1] as Color, alfa)
		var centro: Vector2 = c + (Vector2(-r * 0.25, -r * 0.3 * achata) if k == 2 else Vector2.ZERO)
		var pts := PackedVector2Array()
		for i in n:
			var a: float = TAU * float(i) / float(n)
			var rr: float = r * esc * (0.86 + 0.22 * _ruido(float(i), sem + float(k)))
			pts.append(centro + Vector2(cos(a) * rr, sin(a) * rr * achata))
		_abanico(ci, centro, pts, col)


# Un poligono ESTRELLADO desde 'c' en triangulos sueltos: no hay que triangular (draw_colored_polygon falla con
# las manchas que aun miden un pixel, al empezar a abrirse).
static func _abanico(ci: CanvasItem, c: Vector2, pts: PackedVector2Array, col: Color) -> void:
	var n: int = pts.size()
	if n < 3 or col.a <= 0.0:
		return
	var pv := PackedVector2Array([c])
	var pc := PackedColorArray([col])
	var pi := PackedInt32Array()
	for i in n:
		pv.append(pts[i])
		pc.append(col)
		pi.append_array([0, 1 + i, 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# UN CHARCO en el suelo (sin achatar: es suelo): mancha grande de bordes blandos, mas oscura por fuera.
func _charco(ci: CanvasItem, c: Vector2, r: float, alfa: float, sem: float) -> void:
	if r <= 0.5 or alfa <= 0.01:
		return
	var n: int = 22
	var pv := PackedVector2Array([c])
	var pc := PackedColorArray([Color(color.lightened(0.1), alfa * 0.75)])
	var pi := PackedInt32Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var rr: float = r * (0.78 + 0.34 * _ruido(float(i) * 1.7, sem))
		pv.append(c + Vector2(cos(a), sin(a)) * rr)
		pc.append(Color(_oscuro(), alfa * 0.85))
	for i in n:
		pv.append(c + Vector2(cos(TAU * float(i) / float(n)), sin(TAU * float(i) / float(n))) \
			* r * (0.78 + 0.34 * _ruido(float(i) * 1.7, sem)) * 1.12)
		pc.append(Color(_oscuro(), 0.0))
	for i in n:
		var j: int = (i + 1) % n
		pi.append_array([0, 1 + i, 1 + j])
		pi.append_array([1 + i, 1 + n + i, 1 + j, 1 + j, 1 + n + i, 1 + n + j])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
	# Un brillo humedo encima.
	_gota(ci, c + Vector2(-r * 0.2, -r * 0.15), r * 0.22, alfa * 0.5, 0.6, sem + 3.0)


# Un anillo RELLENO de gel (la ola de la marea): banda que se difumina por dentro y tiene la cresta clara.
func _anillo_gel(ci: CanvasItem, c: Vector2, r: float, grueso: float, alfa: float) -> void:
	if r <= 1.0 or alfa <= 0.01:
		return
	var n: int = 40
	var radios: Array = [maxf(0.0, r - grueso), r - grueso * 0.25, r, r + grueso * 0.2]
	var cols: Array = [Color(color, 0.0), Color(color, alfa * 0.8), Color(_claro(), alfa), Color(_oscuro(), 0.0)]
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var ondula: float = 1.0 + 0.04 * sin(a * 7.0 + _t * 9.0)
		for j in 4:
			pv.append(c + Vector2(cos(a), sin(a)) * float(radios[j]) * ondula)
			pc.append(cols[j])
	for i in n:
		var b0: int = i * 4
		var b1: int = ((i + 1) % n) * 4
		for j in 3:
			pi.append_array([b0 + j, b0 + j + 1, b1 + j, b0 + j + 1, b1 + j + 1, b1 + j])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# UNA BOCANADA DE FUEGO (la de MagiaAire, con su silueta a saltos y sus tres capas).
func _bocanada(ci: CanvasItem, c: Vector2, r: float, k: float, fase: float) -> void:
	var paso: float = floor(_t * 14.0) + fase
	var n: int = 14
	var contorno := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		var rr: float = r * (0.8 + 0.3 * _ruido(float(i) + paso * 3.1, fase))
		if d.y < -0.2:
			rr *= 1.0 + 0.35 * (-d.y) + (0.45 * (-d.y) if (i + int(paso)) % 3 == 0 else 0.0)
		contorno.append(Vector2(d.x * rr, d.y * rr * (1.15 if d.y < 0.0 else 0.8)))
	var vida: float = 1.0 - smoothstep(0.7, 1.0, k)
	var viejo: float = smoothstep(0.35, 0.85, k)
	var capas: Array = [
		[1.0, FUEGO_NARANJA.lerp(FUEGO_OSCURO, viejo), FUEGO_ROJO.lerp(HUMO, viejo), 0.72],
		[0.62, FUEGO_AMARILLO.lerp(FUEGO_ROJO, viejo), FUEGO_NARANJA.lerp(FUEGO_OSCURO, viejo), 0.95],
		[0.32, FUEGO_BLANCO, FUEGO_AMARILLO, 1.0 - smoothstep(0.15, 0.45, k)]]
	for cp in capas:
		var esc: float = float(cp[0])
		var alfa: float = float(cp[3]) * vida
		if alfa <= 0.01:
			continue
		var pv := PackedVector2Array([c])
		var pc := PackedColorArray([Color(cp[1] as Color, alfa)])
		var pi := PackedInt32Array()
		for i in n:
			pv.append(c + contorno[i] * esc)
			pc.append(Color(cp[2] as Color, alfa))
		for i in n:
			pi.append_array([0, 1 + i, 1 + (i + 1) % n])
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# Lo que se va secando: 1 entero, 0 ya no esta. 't_llega' = cuando nacio.
func _seca(t_llega: float) -> float:
	var t: float = _t - t_llega - T_QUEDA
	return 1.0 - clampf(t / T_SECA, 0.0, 1.0)


# Una gota que sale de 'p0' con velocidad 'v' (en el suelo) y altura maxima 'sube', a la edad 'k' (0..1 de su
# vuelo). Devuelve [pos en el suelo, pos en pantalla con su altura].
func _vuelo(p0: Vector2, v: Vector2, sube: float, k: float, dur: float) -> Array:
	var suelo: Vector2 = p0 + v * dur * k
	return [suelo, suelo + _alto(sube * 4.0 * k * (1.0 - k))]


# ------------------------------------------------------------
#  EL DIBUJO
# ------------------------------------------------------------
func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.SPLAT, Modo.APLASTA: _splat(capa)
		Modo.MAREA: _marea(capa)
		Modo.COMBUSTION: _combustion(capa)
		Modo.SALPICA: _salpica(capa)
		Modo.ROCIADA: _rociada(capa)
		Modo.PLACAJE: _placaje(capa)
		Modo.GOLPE: _golpe(capa)
		Modo.ESCUPE: _escupe(capa)
		Modo.TROMBA: _tromba(capa)
		Modo.PRESION: _presion(capa)
		Modo.IGNICION: _ignicion(capa)
		Modo.TROZO: _trozo(capa)
		Modo.PUAS: _puas(capa)


# EXPANDIR PUAS (06/10): las puas de cristal le salen DISPARADAS DE LA PIEL en anillo hasta el borde del circulo, se
# quedan clavadas un momento y se apagan. Cada una es como las de su cuerpo (ver slime_sdf.py, _cristal): un cristal de
# dos puntas, con su cara clara y su cara en sombra, el contorno oscuro y un brillo.
const PIEL_PUAS := 17.0          # de donde salen: la piel del slime (su radio a la altura de las puas)
const ALTO_PUAS := 9.0           # a que altura le salen del cuerpo

func _puas(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var seca: float = _seca(T_PUAS)
	for pu in _llamas:
		var k: float = clampf((_t - float(pu["t0"])) / T_PUAS, 0.0, 1.0)
		if k <= 0.0:
			continue
		var ang: float = float(pu["a"])
		var d := Vector2(cos(ang), sin(ang) * K).normalized()
		var r0: float = PIEL_PUAS
		var r1: float = _r * float(pu["u"])
		var en_suelo: Vector2 = _o + d * lerpf(r0, r1, k)
		if capa == _suelo:
			# SU SOMBRA en el suelo (ancla lo que vuela al plano del mapa), mas nitida al clavarse.
			capa.draw_circle(en_suelo, 2.6, Color(0, 0, 0, (0.15 + 0.15 * k) * seca))
			continue
		if capa != _delante:
			continue
		# Sale a la altura de su cuerpo y BAJA hasta clavarse, inclinandose hacia delante (la punta mas baja).
		var alt: float = ALTO_PUAS * (1.0 - k)
		var punta: Vector2 = en_suelo + _alto(alt)
		var eje: Vector2 = (d + Vector2(0.0, float(pu["gira"]) * 0.2 + 0.35 * k)).normalized()
		_cristal(capa, punta, eje, float(pu["l"]), float(pu["w"]), seca)
		# El rastro de chispas mientras vuela.
		if k < 1.0:
			BarridoAire.cometa(capa, punta - eje * (float(pu["l"]) + 8.0), punta - eje * float(pu["l"]) * 0.6,
				float(pu["w"]) * 0.7, Color(CRISTAL, 0.45 * (1.0 - k)))
	if capa == _brillo:
		# EL DESTELLO al soltarlas: un anillo de chispas EN SU PIEL (no en el centro), que se abre y se apaga.
		var fb: float = 1.0 - clampf(_t / 0.16, 0.0, 1.0)
		if fb > 0.0:
			for pu in _llamas:
				var dd := Vector2(cos(float(pu["a"])), sin(float(pu["a"])) * K).normalized()
				BarridoAire.destello(capa, _o + dd * PIEL_PUAS + _alto(ALTO_PUAS), 5.0 * (1.2 - fb * 0.4),
					Color(CRISTAL, fb * 0.75))


# UN CRISTAL como los del slime: dos puntas (la de delante larga), la mitad de arriba clara y la de abajo en sombra,
# con el contorno oscuro y una raya de brillo.
func _cristal(ci: CanvasItem, punta: Vector2, eje: Vector2, largo: float, ancho: float, alfa: float) -> void:
	var cola: Vector2 = punta - eje * largo
	var medio: Vector2 = punta - eje * largo * 0.62
	var lado: Vector2 = eje.orthogonal() * ancho * 0.5
	var arriba: Vector2 = medio + lado
	var abajo: Vector2 = medio - lado
	if lado.y > 0.0:   # la cara clara siempre la de ARRIBA (la luz viene de arriba)
		var tmp: Vector2 = arriba
		arriba = abajo
		abajo = tmp
	var borde := PackedVector2Array([punta + eje * 1.0, arriba + (arriba - medio).normalized(), cola - eje * 1.0,
		abajo + (abajo - medio).normalized()])
	# (06/10) LA OBSIDIANA, con su slime OSCURO: agujas de cristal negro, la cara clara gris humo; el brillo se queda.
	var claro: Color = CRISTAL
	var oscuro: Color = CRISTAL_OSCURO
	if color.get_luminance() < 0.25:
		claro = Color(0.30, 0.28, 0.36)
		oscuro = Color(0.07, 0.06, 0.10)
	Poligono.relleno(ci, borde, Color(oscuro.darkened(0.35), alfa))
	Poligono.relleno(ci, PackedVector2Array([punta, arriba, cola, medio]), Color(claro.lightened(0.15), alfa))
	Poligono.relleno(ci, PackedVector2Array([punta, medio, cola, abajo]), Color(oscuro.lightened(0.2), alfa))
	ci.draw_line(punta.lerp(arriba, 0.35), medio.lerp(arriba, 0.5).lerp(cola, 0.3), Color(1, 1, 1, 0.85 * alfa), 1.0)


func _splat(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var t_abre: float = T_SPLAT if modo == Modo.SPLAT else T_APLASTA
	var abre: float = 1.0 - pow(1.0 - clampf(_t / t_abre, 0.0, 1.0), 2.0)
	var seca: float = _seca(t_abre)
	if capa == _suelo:
		# EL CHARCO: se abre del centro al borde y se va secando.
		_charco(capa, _o, _r * 0.62 * abre, seca, 1.0)
		for m in _manchas:
			var pm: Vector2 = _o + Vector2(cos(float(m["a"])), sin(float(m["a"]))) * float(m["u"]) * _r * 0.85 * abre
			_charco(capa, pm, float(m["r"]) * abre, seca * 0.9, float(m["a"]))
		# EL APLASTAMIENTO: la onda de choque que corre hasta el borde.
		if modo == Modo.APLASTA:
			MagiaAire._anillo(capa, _o, _r * abre, 10.0, Color(_claro(), 0.55 * (1.0 - clampf(_t / (t_abre + 0.25), 0.0, 1.0))))
		return
	if capa == _delante:
		# LA CORONA DE GOTAS: saltan del borde del charco hacia fuera, suben y caen donde se hacen mancha.
		for g in _gotas:
			var k: float = clampf((_t - float(g["t0"])) / 0.45, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var d := Vector2(cos(float(g["a"])), sin(float(g["a"])))
			var p0: Vector2 = _o + d * _r * 0.45
			var p1: Vector2 = _o + d * _r * float(g["u"])
			var suelo: Vector2 = p0.lerp(p1, k)
			var aire: Vector2 = suelo + _alto(float(g["sube"]) * 4.0 * k * (1.0 - k))
			var antes: Vector2 = p0.lerp(p1, maxf(k - 0.12, 0.0))
			antes += _alto(float(g["sube"]) * 4.0 * maxf(k - 0.12, 0.0) * (1.0 - maxf(k - 0.12, 0.0)))
			BarridoAire.cometa(capa, antes, aire, float(g["tam"]) * 1.6, Color(color, 0.85))
			_gota(capa, aire, float(g["tam"]), 1.0, 1.0, float(g["a"]))
		# El golpe contra el suelo: un bulto de gel que se aplasta en el centro nada mas caer.
		var golpe: float = 1.0 - clampf(_t / 0.18, 0.0, 1.0)
		if golpe > 0.0:
			_gota(capa, _o, _r * 0.4 * (1.2 - golpe * 0.4), golpe, 0.45, 7.0)
		return
	# EL BRILLO del impacto.
	var fb: float = 1.0 - clampf(_t / 0.2, 0.0, 1.0)
	if fb > 0.0:
		BarridoAire.destello(capa, _o + _alto(4.0), _r * 0.5 * (1.0 - fb * 0.5), Color(_claro(), fb * 0.8))


func _marea(capa: Node2D) -> void:
	if _t < 0.0:
		return
	if capa == _suelo:
		# LO MOJADO: la mancha que deja detras la ola mas lejana.
		var hecho: float = clampf(_t / (T_MAREA + T_ENTRE_OLAS * 2.0), 0.0, 1.0)
		var seca: float = _seca(T_MAREA + T_ENTRE_OLAS * 2.0)
		_charco(capa, _o, _r * 0.95 * (1.0 - pow(1.0 - hecho, 2.0)), seca * 0.45, 2.0)
		# LOS TRES ANILLOS: cada ola sale un poco despues que la anterior y se abre hasta el borde.
		for ola in 3:
			var k: float = clampf((_t - T_ENTRE_OLAS * float(ola)) / T_MAREA, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var r: float = _r * (1.0 - pow(1.0 - k, 1.6))
			_anillo_gel(capa, _o, r, 9.0 + 5.0 * (1.0 - k), 0.9 * (1.0 - smoothstep(0.75, 1.0, k)))
		return
	if capa == _delante:
		# LA ESPUMA: gotas que saltan de la cresta de cada ola.
		for g in _gotas:
			var k2: float = clampf((_t - T_ENTRE_OLAS * float(g["ola"])) / T_MAREA, 0.0, 1.0)
			if k2 <= 0.05 or k2 >= 0.95:
				continue
			var r2: float = _r * (1.0 - pow(1.0 - k2, 1.6))
			var bote: float = absf(sin((k2 * 3.0 + float(g["fase"])) * PI))
			var p: Vector2 = _o + Vector2(cos(float(g["a"])), sin(float(g["a"]))) * r2 + _alto(float(g["sube"]) * bote)
			_gota(capa, p, float(g["tam"]), 1.0 - smoothstep(0.7, 0.95, k2), 1.0, float(g["a"]))


func _combustion(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var k: float = clampf(_t / T_COMBUSTION, 0.0, 1.0)
	var frente: float = 1.0 - pow(1.0 - k, 2.0)
	if capa == _suelo:
		# EL SUELO QUEMADO que deja la onda, y las ascuas que se apagan.
		var quema: float = 1.0 - clampf((_t - 0.5) / 0.8, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			pts.append(_o + Vector2(cos(a), sin(a)) * _r * frente * (0.85 + 0.2 * _ruido(float(i), 5.0)))
		_abanico(capa, _o, pts, Color(CHAMUSCADO, 0.55 * quema))
		for g in _gotas:
			var vida: float = clampf((_t - float(g["u"]) * T_COMBUSTION) / float(g["vida"]), 0.0, 1.0)
			if vida <= 0.0 or vida >= 1.0:
				continue
			var pa: Vector2 = _o + Vector2(cos(float(g["a"])), sin(float(g["a"]))) * float(g["u"]) * _r
			var lat: float = 0.5 + 0.5 * sin(_t * 12.0 + float(g["fase"]))
			BarridoAire.brillo(capa, pa, 2.5 * float(g["tam"]), Color(FUEGO_NARANJA.lerp(FUEGO_AMARILLO, lat), 1.0 - vida))
		return
	if capa == _delante:
		# LA BOLA DE FUEGO en el centro, que crece y se hace humo...
		var kb: float = clampf(_t / 0.7, 0.0, 1.0)
		_bocanada(capa, _o + _alto(10.0 * kb), _r * 0.45 * (0.6 + 0.6 * sqrt(kb)), kb, 11.0)
		# ...y el ANILLO DE LLAMAS que corre hasta el borde.
		for l in _llamas:
			var t0: float = float(l["u"]) * T_COMBUSTION
			var kl: float = clampf((_t - t0) / float(l["vida"]), 0.0, 1.0)
			if kl <= 0.0 or kl >= 1.0:
				continue
			var pl: Vector2 = _o + Vector2(cos(float(l["a"])), sin(float(l["a"]))) * _r * float(l["u"]) * frente
			_bocanada(capa, pl, 7.0 * float(l["tam"]), kl, float(l["fase"]))
		return
	var fb: float = 1.0 - clampf(_t / 0.22, 0.0, 1.0)
	if fb > 0.0:
		BarridoAire.destello(capa, _o + _alto(10.0), _r * 0.7, Color(FUEGO_AMARILLO, fb))


func _salpica(capa: Node2D) -> void:
	if _t < 0.0:
		return
	for g in _gotas:
		var d := Vector2(cos(float(g["a"])), sin(float(g["a"])))
		var p1: Vector2 = _o + d * _r * float(g["u"])
		var k: float = clampf((_t - float(g["t0"])) / T_SALPICA, 0.0, 1.0)
		if capa == _suelo:
			# DONDE CAE, un charquito de lava que chisporrotea y se enfria.
			if k >= 1.0:
				var vive: float = _seca(float(g["t0"]) + T_SALPICA)
				var lat: float = 0.5 + 0.5 * sin(_t * 14.0 + float(g["a"]) * 5.0)
				_charco(capa, p1, float(g["tam"]) * 2.2, vive, float(g["a"]))
				BarridoAire.brillo(capa, p1, float(g["tam"]) * 2.4, Color(FUEGO_AMARILLO, 0.6 * vive * lat))
			continue
		if capa == _delante and k > 0.0 and k < 1.0:
			var p0: Vector2 = _o + d * 6.0
			var suelo: Vector2 = p0.lerp(p1, k)
			var aire: Vector2 = suelo + _alto(float(g["sube"]) * 4.0 * k * (1.0 - k))
			var k0: float = maxf(k - 0.15, 0.0)
			var antes: Vector2 = p0.lerp(p1, k0) + _alto(float(g["sube"]) * 4.0 * k0 * (1.0 - k0))
			BarridoAire.cometa(capa, antes, aire, float(g["tam"]) * 1.4, Color(FUEGO_NARANJA, 0.9))
			_gota(capa, aire, float(g["tam"]), 1.0, 1.0, float(g["a"]))
	if capa == _brillo:
		var fb: float = 1.0 - clampf(_t / 0.25, 0.0, 1.0)
		if fb > 0.0:
			BarridoAire.brillo(capa, _o + _alto(6.0), _r * 0.45, Color(FUEGO_AMARILLO, 0.7 * fb))


func _rociada(capa: Node2D) -> void:
	if _t < 0.0:
		return
	for g in _gotas:
		var d: Vector2 = _dir.rotated(float(g["a"]))
		var p1: Vector2 = _o + d * _r * float(g["u"])
		var k: float = clampf((_t - float(g["t0"])) / (T_ROCIADA * float(g["u"])), 0.0, 1.0)
		if capa == _suelo:
			if k >= 1.0:
				_charco(capa, p1, float(g["tam"]) * 2.0, _seca(float(g["t0"]) + T_ROCIADA), float(g["a"]) * 9.0)
			continue
		if capa == _delante and k > 0.0 and k < 1.0:
			var p0: Vector2 = _o + d * 4.0
			var suelo: Vector2 = p0.lerp(p1, k)
			var aire: Vector2 = suelo + _alto(8.0 + float(g["sube"]) * 4.0 * k * (1.0 - k))
			var k0: float = maxf(k - 0.2, 0.0)
			var antes: Vector2 = p0.lerp(p1, k0) + _alto(8.0 + float(g["sube"]) * 4.0 * k0 * (1.0 - k0))
			BarridoAire.cometa(capa, antes, aire, float(g["tam"]) * 1.5, Color(color, 0.85))
			_gota(capa, aire, float(g["tam"]), 1.0, 1.0, float(g["a"]) * 9.0)


func _placaje(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var avance: float = clampf(_t / T_PLACAJE, 0.0, 1.0)
	var lat: Vector2 = _dir.orthogonal()
	if capa == _suelo:
		# EL RASTRO: las manchas salen a medida que el cuerpo pasa por encima.
		for m in _manchas:
			if float(m["u"]) > avance:
				continue
			var pm: Vector2 = _o + _dir * _largo * float(m["u"]) + lat * _ancho * float(m["v"])
			_charco(capa, pm, float(m["r"]), _seca(float(m["u"]) * T_PLACAJE), float(m["u"]) * 13.0)
		return
	if capa == _delante and _t >= T_PLACAJE:
		# EL CHOQUE al final: salpicon hacia delante.
		var k: float = clampf((_t - T_PLACAJE) / 0.4, 0.0, 1.0)
		if k >= 1.0:
			return
		var fin: Vector2 = _o + _dir * _largo
		for g in _gotas:
			var r: Array = _vuelo(fin, g["v"], float(g["sube"]), k, 0.4)
			_gota(capa, r[1], float(g["tam"]) * (1.0 - k * 0.4), 1.0 - smoothstep(0.7, 1.0, k), 1.0, float(g["sube"]))


func _golpe(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var k: float = clampf(_t / 0.45, 0.0, 1.0)
	if capa == _delante:
		# El PEGOTE sobre el cuerpo, que se estira y se escurre.
		var pe: float = 1.0 - clampf(_t / 0.3, 0.0, 1.0)
		if pe > 0.0:
			_gota(capa, _hasta, maxf(_ancho * 0.45, 7.0) * (1.3 - pe * 0.3), pe, 0.8, 4.0)
		for g in _gotas:
			var kg: float = clampf((_t - float(g["t0"])) / 0.45, 0.0, 1.0)
			if kg <= 0.0 or kg >= 1.0:
				continue
			var r: Array = _vuelo(_hasta, g["v"], float(g["sube"]), kg, 0.45)
			var r0: Array = _vuelo(_hasta, g["v"], float(g["sube"]), maxf(kg - 0.15, 0.0), 0.45)
			BarridoAire.cometa(capa, r0[1], r[1], float(g["tam"]) * 1.5, Color(color, 0.8))
			_gota(capa, r[1], float(g["tam"]), 1.0 - smoothstep(0.75, 1.0, kg), 1.0, float(g["sube"]))
	elif capa == _brillo and k < 0.4:
		BarridoAire.destello(capa, _hasta, _ancho * 0.55, Color(_claro(), 0.7 * (1.0 - k / 0.4)))


func _escupe(capa: Node2D) -> void:
	# VIAJA durante la espera (t < 0): la bola va de la boca al pecho en parabola.
	if _t < 0.0:
		if capa != _delante:
			return
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		var alto: float = maxf(18.0, _desde.distance_to(_hasta) * 0.35)
		var p: Vector2 = _desde.lerp(_hasta, u) + _alto(alto * 4.0 * u * (1.0 - u))
		# La ESTELA de trozos: gotitas que se quedan atras y caen.
		for i in 5:
			var ui: float = maxf(u - 0.06 * float(i + 1), 0.0)
			var pi: Vector2 = _desde.lerp(_hasta, ui) + _alto(alto * 4.0 * ui * (1.0 - ui)) + Vector2(0.0, float(i) * 1.5)
			_gota(capa, pi, 3.6 - float(i) * 0.5, 0.9 - float(i) * 0.15, 1.0, float(i))
		_gota(capa, p, 7.0, 1.0, 1.0, 2.0)
		return
	if capa == _suelo:
		_charco(capa, _pies, maxf(_ancho * 0.8, 10.0) * clampf(_t / 0.12, 0.0, 1.0), _seca(0.1) * 0.9, 5.0)
		return
	_golpe(capa)


func _tromba(capa: Node2D) -> void:
	if _t < -T_COLUMNA:
		return
	var cae: float = clampf((_t + T_COLUMNA) / T_COLUMNA, 0.0, 1.0)   # 0 arriba, 1 ya en el suelo
	var sale: float = clampf(_t / 0.55, 0.0, 1.0)                     # despues: el remolino se cierra y se va
	var arriba: Vector2 = _pies + _alto(ALTO_COLUMNA)
	var cabeza: Vector2 = arriba.lerp(_pies + _alto(6.0), cae)
	var r0: float = maxf(_ancho * 0.8, 11.0)
	var giro: float = _t * 9.0
	if capa == _delante:
		# EL EMBUDO: anillos de media luna negra apilados de lo alto a la cabeza, anchos arriba y estrechos abajo, cada
		# uno girando (su pincelada da la vuelta); se deshace de abajo arriba al tocar.
		var n: int = 9
		for k in n:
			var u: float = float(k) / float(n - 1)        # 0 arriba, 1 la cabeza
			if _t >= 0.0 and u > 1.0 - sale * 1.4:
				continue
			var pk: Vector2 = arriba.lerp(cabeza, u)
			var rk: float = r0 * lerpf(1.25, 0.55, u)
			_anillo_negro(capa, pk, rk, 0.34, 2.2 + 1.6 * u, giro * (1.0 + u) + float(k) * 0.9, 1.0 - sale, float(k))
		if _t < 0.0:
			# LA CABEZA: bola negra con el ojo claro.
			MagiaMayor._disco(capa, cabeza, r0 * 0.55, MagiaMayor.NEGRO, Color(MagiaMayor.NEGRO, 0.9))
			MagiaMayor._disco(capa, cabeza, r0 * 0.2, MagiaMayor.ECLIPSE_CLARO, MagiaMayor.ECLIPSE)
		else:
			# LAS GOTAS DE TINTA que salta al reventar.
			for g in _gotas:
				var kg: float = clampf((_t - float(g["t0"])) / 0.45, 0.0, 1.0)
				if kg <= 0.0 or kg >= 1.0:
					continue
				var r: Array = _vuelo(_pies, g["v"], float(g["sube"]), kg, 0.45)
				MagiaMayor._disco(capa, r[1], float(g["tam"]) * (1.0 - kg * 0.5), Color(MagiaMayor.NEGRO, 0.9), Color(MagiaMayor.NEGRO, 0.9))
	elif capa == _suelo:
		# LA SOMBRA que crece bajo el mientras cae, y al tocar EL REMOLINO de brazos negros a sus pies.
		BarridoAire.brillo(capa, _pies, r0 * (0.8 + 0.8 * cae), Color(MagiaMayor.NEGRO, 0.5 * cae * (1.0 - sale)))
		if _t >= 0.0:
			var abre: float = 1.0 - pow(1.0 - clampf(_t / 0.12, 0.0, 1.0), 2.0)
			var vivo: float = abre * (1.0 - sale * sale)
			for k in 5:
				_brazo(capa, _pies, TAU * float(k) / 5.0 - _t * 6.0, r0 * 0.25, r0 * 1.9 * abre, -2.2, r0 * 0.28 * vivo,
					vivo, float(k) * 3.1)
	elif capa == _brillo and _t >= 0.0 and _t < 0.3:
		BarridoAire.destello(capa, _pies + _alto(4.0), r0 * 1.3 * (1.0 - _t / 0.3), Color(MagiaMayor.ECLIPSE_CLARO, 1.0 - _t / 0.3))


func _presion(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var frente: float = clampf(_t / T_OSCURO, 0.0, 1.0)
	var lat: Vector2 = _dir.orthogonal()
	if capa == _suelo:
		# LA SOMBRA por donde ha pasado y la TINTA que salpica.
		var tras: float = 1.0 - smoothstep(0.4, 1.0, (_t - T_OSCURO) / 0.9)
		for k in 6:
			var uk: float = (float(k) + 0.5) / 6.0
			if uk > frente:
				break
			BarridoAire.brillo(capa, _o + _dir * _largo * uk, _ancho * 0.9, Color(MagiaMayor.NEGRO, 0.35 * tras))
		for m in _manchas:
			if float(m["u"]) > frente:
				continue
			var pm: Vector2 = _o + _dir * _largo * float(m["u"]) + lat * _ancho * float(m["v"]) * 1.2
			MagiaMayor._disco(capa, pm, float(m["r"]) * 0.35, Color(MagiaMayor.NEGRO, 0.85 * tras), Color(MagiaMayor.NEGRO, 0.85 * tras))
		return
	if capa == _delante:
		# LAS GARRAS: medias lunas negras que avanzan con el frente, abombadas hacia delante; tres escalonadas en la
		# cresta y las de detras se deshacen.
		for k in 4:
			var uk: float = frente - 0.12 * float(k)
			if uk < 0.0:
				continue
			var vivo: float = (1.0 - 0.25 * float(k)) * (1.0 - smoothstep(0.85, 1.0, _t / (T_OSCURO + 0.3)))
			var c: Vector2 = _o + _dir * _largo * uk + _alto(4.0 + 3.0 * float(k % 2))
			_garra(capa, c, _dir, lat, _ancho * (1.05 + 0.12 * float(k)), _ancho * 0.65, _ancho * 0.32, vivo, float(k) * 2.3 + floor(_t * 10.0))
		return
	if frente < 1.0:
		BarridoAire.brillo(capa, _o + _dir * _largo * frente, _ancho * 0.8, Color(MagiaMayor.ECLIPSE, 0.25))


# UN ANILLO del embudo: la mitad de DELANTE de una elipse (el aro visto a 45 grados), negra y rellena, mas gorda en
# medio y afilada en las puntas, con trozos de pincelada clara que corren con 'giro'.
func _anillo_negro(ci: CanvasItem, c: Vector2, r: float, achata: float, grueso: float, giro: float, alfa: float,
		sem: float) -> void:
	if r <= 0.5 or alfa <= 0.01:
		return
	var n: int = 12
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for k in n + 1:
		var u: float = float(k) / float(n)
		var a: float = PI * u                       # de un lado al otro por DELANTE (y positiva)
		var d := Vector2(cos(a), sin(a) * achata)
		var w: float = grueso * sin(u * PI)
		pv.append(c + d * r + Vector2(0.0, w))
		pv.append(c + d * r - Vector2(0.0, w * 0.5))
		pc.append(Color(MagiaMayor.NEGRO, alfa))
		pc.append(Color(MagiaMayor.NEGRO, alfa))
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
	# La pincelada: dos trozos cortos por la parte de abajo que se desplazan con el giro (asi se ve girar).
	for j in 2:
		var u0: float = fposmod(giro * 0.16 + float(j) * 0.5 + sem * 0.13, 1.0)
		if u0 < 0.1 or u0 > 0.8:
			continue
		var a0: float = PI * u0
		var a1: float = PI * (u0 + 0.16)
		var p0: Vector2 = c + Vector2(cos(a0), sin(a0) * achata) * r + Vector2(0.0, grueso * 0.9)
		var p1: Vector2 = c + Vector2(cos(a1), sin(a1) * achata) * r + Vector2(0.0, grueso * 0.9)
		var t: Vector2 = (p1 - p0).normalized().orthogonal() * grueso * 0.35
		ci.draw_primitive(PackedVector2Array([p0 - t, p1, p0 + t]),
			PackedColorArray([Color(MagiaMayor.PINCEL, alfa), Color(MagiaMayor.PINCEL, 0.0), Color(MagiaMayor.PINCEL, alfa)]),
			PackedVector2Array())


# UNA GARRA de la Presion: media luna negra rellena, atravesada a 'eje' y abombada hacia el, gorda en medio y afilada
# en las puntas, con su pincelada clara ROTA por el filo de delante.
func _garra(ci: CanvasItem, c: Vector2, eje: Vector2, lat: Vector2, ancho: float, bomba: float, grueso: float,
		alfa: float, sem: float) -> void:
	if alfa <= 0.01 or ancho <= 0.5:
		return
	var n: int = 12
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	var filo: Array = []
	for k in n + 1:
		var s2: float = float(k) / float(n) * 2.0 - 1.0     # -1 .. 1 a lo ancho
		var q: Vector2 = c + lat * s2 * ancho + eje * bomba * (1.0 - s2 * s2)
		var w: float = grueso * (1.0 - s2 * s2) * (0.85 + 0.3 * _ruido(float(k), sem))
		pv.append(q + eje * w * 0.5)
		pv.append(q - eje * w)
		pc.append(Color(MagiaMayor.NEGRO, alfa))
		pc.append(Color(MagiaMayor.NEGRO, alfa * 0.8))
		filo.append([q + eje * (w * 0.5 + 1.2), w])
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
	for k in n:
		if _ruido(float(k) * 1.7, sem + 3.0) < 0.4:
			continue
		var p0: Vector2 = filo[k][0]
		var p1: Vector2 = filo[k + 1][0]
		var g: float = 0.4 + 0.9 * float(filo[k][1]) / maxf(grueso, 0.1)
		var t: Vector2 = (p1 - p0).normalized().orthogonal() * g
		ci.draw_primitive(PackedVector2Array([p0 - t, p1, p0 + t]),
			PackedColorArray([Color(MagiaMayor.PINCEL, alfa), Color(MagiaMayor.PINCEL, 0.0), Color(MagiaMayor.PINCEL, alfa)]),
			PackedVector2Array())


# UN BRAZO DEL REMOLINO (el de la Voragine, MagiaMayor._brazo): media luna negra que se enrosca de 'r_out' a 'r_in' en
# el suelo, con su pincelada clara rota por fuera.
func _brazo(ci: CanvasItem, c: Vector2, a0: float, r_in: float, r_out: float, vuelta: float, grueso: float, alfa: float,
		sem: float) -> void:
	if grueso <= 0.3 or alfa <= 0.01:
		return
	var n: int = 12
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	var bordes: Array = []
	for k in n + 1:
		var u: float = float(k) / float(n)
		var ang: float = a0 + vuelta * u
		var rr: float = lerpf(r_out, r_in, u)
		var d := Vector2(cos(ang), sin(ang))
		var w: float = grueso * sin(u * PI) * (0.85 + 0.3 * _ruido(float(k), sem))
		pv.append(c + d * (rr + w))
		pv.append(c + d * maxf(rr - w * 0.4, 0.0))
		pc.append(Color(MagiaMayor.NEGRO, alfa))
		pc.append(Color(MagiaMayor.NEGRO, alfa))
		bordes.append([c + d * (rr + w), d, w, u])
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
	for k in n:
		if _ruido(float(k) * 1.7, sem + 3.0) < 0.35:
			continue
		var e0: Array = bordes[k]
		var e1: Array = bordes[k + 1]
		var g0: float = 0.4 + 1.1 * sin(float(e0[3]) * PI)
		var g1: float = 0.4 + 1.1 * sin(float(e1[3]) * PI)
		var p0: Vector2 = (e0[0] as Vector2) + (e0[1] as Vector2) * 1.3
		var p1: Vector2 = (e1[0] as Vector2) + (e1[1] as Vector2) * 1.3
		var t: Vector2 = (p1 - p0).normalized().orthogonal()
		ci.draw_primitive(PackedVector2Array([p0 - t * g0, p1 - t * g1 * 0.2, p1 + t * g1 * 0.2, p0 + t * g0]),
			PackedColorArray([Color(MagiaMayor.PINCEL, alfa), Color(MagiaMayor.PINCEL, 0.0), Color(MagiaMayor.PINCEL, 0.0),
				Color(MagiaMayor.PINCEL, alfa)]), PackedVector2Array())


func _ignicion(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var k: float = clampf(_t / T_IGNICION, 0.0, 1.0)
	var apaga: float = 1.0 - smoothstep(0.75, 1.0, _t / (T_IGNICION + 0.4))
	var base: Vector2 = Vector2(_hasta.x, _pies.y - _largo * 0.35)   # donde arde: sobre su lomo
	if capa == _suelo:
		# EL CALOR en el suelo: un anillo naranja que se abre bajo el.
		MagiaAire._anillo(capa, _pies, _ancho * (0.5 + 0.5 * k), 5.0, Color(FUEGO_NARANJA, 0.45 * apaga))
		return
	if capa == _delante:
		# LAS LLAMAS le suben del cuerpo: nacen por su lomo y sus costados, suben, crecen y se hacen humo.
		for l in _llamas:
			var kl: float = clampf((_t - float(l["t0"])) / float(l["vida"]), 0.0, 1.0)
			if kl <= 0.0 or kl >= 1.0:
				continue
			var pl: Vector2 = base + Vector2(float(l["x"]) * _ancho, 0.0) + _alto(4.0 + 22.0 * kl)
			_bocanada(capa, pl, 5.5 * float(l["tam"]) * (0.7 + 0.6 * sin(kl * PI)), kl, float(l["fase"]))
		# Y una gran llama sobre el, que late mientras se enciende.
		var lat: float = 0.8 + 0.2 * sin(_t * 18.0)
		_bocanada(capa, base + _alto(8.0), _ancho * 0.45 * lat * sin(clampf(_t / 0.25, 0.0, 1.0) * PI * 0.5) * apaga, 0.1 + 0.6 * k, 3.0)
		return
	# EL BRILLO del cuerpo al rojo.
	BarridoAire.brillo(capa, _hasta, _ancho * 1.1, Color(FUEGO_NARANJA, 0.55 * apaga))
	if _t < 0.2:
		BarridoAire.destello(capa, base, _ancho * 0.8, Color(FUEGO_AMARILLO, 1.0 - _t / 0.2))


func _trozo(capa: Node2D) -> void:
	if capa != _delante and capa != _brillo:
		return
	# IDA durante la espera, y VUELTA despues del golpe.
	var p: Vector2
	var r: float = 7.0
	if _t < 0.0:
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		p = _desde.lerp(_hasta, u) + _alto(22.0 * 4.0 * u * (1.0 - u))
	else:
		if capa == _delante:
			_golpe(capa)
		var v: float = clampf((_t - 0.12) / 0.35, 0.0, 1.0)
		if v <= 0.0 or v >= 1.0:
			return
		p = _hasta.lerp(_desde, v) + _alto(26.0 * 4.0 * v * (1.0 - v))
		r = 5.5
	if capa == _delante:
		_gota(capa, p, r, 1.0, 1.0, 3.0)
