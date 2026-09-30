# ============================================================
#  constructo_aire.gd
#  LOS EFECTOS DE LOS CONSTRUCTOS en el mapa (30/09/2026, paso 2, uno a uno y con su visto bueno; ver la memoria
#  constructos-tactico). Empieza por el GOLEM DE ARCILLA:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.CONSTRUCTO_*):
#    APLASTON    el puñetazo (el gesto lo hace su sprite, 'embestida'), copiado del porrazo de la maza (MazaAire, "god"):
#                el puño CAE DE ARRIBA ABAJO sobre quien lo recibe (la estela de arcilla que baja), el fogonazo romo
#                del impacto, una onda que APLASTA contra el suelo y PIEDRECILLAS angulosas que saltan alto y caen
#                ("pega duro y es grande"). En la Machaca, mas gordo ('peso'). La 1a version (media luna de lado y
#                terrones redondos) se leia como un corte horizontal y "circulos guarros" (30/09).
#    PEGOTES     si el golpe le deja LENTO: manchas de barro en los pies un momento (CombatTactico._on_impacto).
#  SOBRE EL GOLEM (CombatTactico._tick_barro, mirando su estado; tambien en el espejo):
#    COCERSE     el fuego lo cuece (o se Endurece): un resplandor de brasa que le sube de los pies a la cabeza y vaho.
#    VAPOR       el agua le cae estando cocido: una nube de vapor al apagarse.
#    DURO        mientras esta cocido/endurecido: algun hilo de vaho de vez en cuando (el tono terracota lo pone el
#                shader tinte_constructo sobre su sprite: el modulate lo reescribe el aviso del golpe cada fotograma).
#    BLANDO      mientras esta mojado: gotas de barro que le caen y un charquito bajo los pies (y el tono de barro
#                mojado en el shader).
#  NADA DE LINEAS (efectos-sin-lineas): medias lunas llenas, bolas con borde, cometas gordas. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name ConstructoAire

enum Modo { APLASTON, PEGOTES, COCERSE, VAPOR, DURO, BLANDO }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ARCILLA := Color(0.6, 0.45, 0.3)
const T_APLASTON := 0.55
const T_PEGOTES := 0.9
const T_COCERSE := 0.8
const T_VAPOR := 0.9
const T_SECA := 0.5
const BRASA := Color(1.0, 0.55, 0.18)
const VAHO := Color(0.86, 0.84, 0.82)
const POLVO := Color(0.66, 0.57, 0.46)

var modo: int = Modo.APLASTON
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _hasta: Vector2 = Vector2.ZERO
var _pies: Vector2 = Vector2.ZERO
var _eje: Vector2 = Vector2.RIGHT
var _ancho: float = 14.0
var _largo: float = 26.0
var _peso: float = 1.0
var _incl: float = 0.0
var _imp: Vector2 = Vector2.ZERO     # APLASTON: donde entra el puño
var _swing: Array = []               # APLASTON: por donde baja (bezier de tres puntos)
const GRAVEDAD := 320.0
var _piezas: Array = []
var _secando: float = -1.0
var _borde: Color = Color(0.2, 0.14, 0.09)
var _barro: Color = ARCILLA
var _claro: Color = Color(0.8, 0.66, 0.48)
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = el centro de quien pega, 'caja' = el que lo recibe, 'color' = el de su ficha (su arcilla), 'peso' = 1 el
# puñetazo, mas en la Machaca.
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, pies: Vector2, color: Color, semilla: int,
		espera: float, ritmo: float, peso: float = 1.0) -> ConstructoAire:
	if padre == null:
		return null
	var e := ConstructoAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._ancho = maxf(caja.size.x, 8.0)
	e._largo = maxf(caja.size.y, 10.0)
	e._pies = pies
	e._peso = peso
	e._tonos(color)
	e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.12, 0.12) * caja.size.x,
		e._rng.randf_range(-0.15, 0.05) * caja.size.y)
	e._eje = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	e._incl = e._rng.randf_range(-0.25, 0.25)
	e._t = -maxf(espera, 0.0)
	match m:
		Modo.APLASTON:
			# EL IMPACTO: arriba en su cuerpo (cabeza y hombros), del lado de quien pega. El puño viene de ARRIBA, un poco
			# de su lado (cada golpe con su inclinacion).
			e._imp = caja.get_center() - e._eje * caja.size.x * 0.15 + Vector2(e._rng.randf_range(-0.1, 0.1) * caja.size.x,
				-caja.size.y * e._rng.randf_range(0.18, 0.3))
			var lado: float = 1.0 if e._rng.randf() < 0.5 else -1.0
			var alto: float = caja.size.y * (1.1 + 0.3 * peso)
			e._swing = [e._imp + Vector2(-e._eje.x * 8.0 + lado * 7.0, -alto), e._imp + Vector2(-e._eje.x * 4.0 + lado * 3.0, -alto * 0.45),
				e._imp]
			# LAS PIEDRECILLAS: poligonos de 4-5 lados (no bolas), que salen hacia arriba y hacia donde empuja el golpe, alto,
			# girando, y caen con peso.
			for i in int(round(11.0 * peso)):
				var sal: Vector2 = (Vector2(e._eje.x, e._eje.y * K) * 0.6 + Vector2(e._rng.randf_range(-1.0, 1.0), 0.0)).normalized()
				var n_l: int = 4 + e._rng.randi() % 2
				var forma := PackedVector2Array()
				for k in n_l:
					var a: float = TAU * float(k) / float(n_l) + e._rng.randf_range(-0.35, 0.35)
					forma.append(Vector2(cos(a), sin(a)) * e._rng.randf_range(0.65, 1.1))
				e._piezas.append({"v": sal * e._rng.randf_range(30.0, 70.0) * sqrt(peso)
					+ Vector2(0.0, -e._rng.randf_range(70.0, 130.0) * sqrt(peso)),
					"tam": e._rng.randf_range(1.6, 3.0) * sqrt(peso), "gira": e._rng.randf_range(-14.0, 14.0),
					"forma": forma, "t0": e._rng.randf_range(0.0, 0.04)})
		Modo.PEGOTES:
			for i in 4:
				var mancha := PackedVector2Array()
				for k in 9:
					var a2: float = TAU * float(k) / 9.0
					mancha.append(Vector2(cos(a2), sin(a2) * 0.6) * e._rng.randf_range(0.6, 1.15))
				e._piezas.append({"x": e._rng.randf_range(-0.4, 0.4), "y": e._rng.randf_range(-0.1, 0.02),
					"tam": e._rng.randf_range(2.2, 3.4), "forma": mancha})
		Modo.COCERSE, Modo.VAPOR:
			for i in (7 if m == Modo.COCERSE else 11):
				e._piezas.append({"x": e._rng.randf_range(-0.4, 0.4), "t0": e._rng.randf_range(0.0, 0.35),
					"sube": e._rng.randf_range(18.0, 34.0), "tam": e._rng.randf_range(0.8, 1.3)})
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	padre.add_child(e)
	return e


# LO QUE SE QUEDA mientras dure su estado (DURO o BLANDO): sigue a su cuerpo (seguir) y se va (secar).
static func estado(padre: Node, m: int, caja: Rect2, pies: Vector2, color: Color, semilla: int) -> ConstructoAire:
	var e: ConstructoAire = sobre_cuerpo(padre, m, caja.get_center(), caja, pies, color, semilla, 0.0, 1.0)
	if e != null:
		e._hasta = caja.get_center()
	return e


func seguir(caja: Rect2, pies: Vector2) -> void:
	_ancho = maxf(caja.size.x, 8.0)
	_largo = maxf(caja.size.y, 10.0)
	_hasta = caja.get_center()
	_pies = pies


func secar() -> void:
	if _secando < 0.0:
		_secando = _t


func _tonos(color: Color) -> void:
	_barro = color.lerp(ARCILLA, 0.4)
	_borde = _barro.darkened(0.65)
	_claro = _barro.lightened(0.35)


func duracion() -> float:
	match modo:
		Modo.APLASTON: return T_APLASTON
		Modo.PEGOTES: return T_PEGOTES
		Modo.COCERSE: return T_COCERSE
		Modo.VAPOR: return T_VAPOR
	return INF   # los que se quedan: hasta que se secan


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
	if _t >= duracion() or (_secando >= 0.0 and _t - _secando >= T_SECA):
		queue_free()
		return
	for n in [_suelo, _delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.APLASTON: _aplaston(capa)
		Modo.PEGOTES: _pegotes(capa)
		Modo.COCERSE: _cocerse(capa)
		Modo.VAPOR: _vapor(capa)
		Modo.DURO: _duro(capa)
		Modo.BLANDO: _blando(capa)


# Lo que queda al irse (los que se quedan se secan poco a poco).
func _queda() -> float:
	return 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)


# UN TERRON: bola de arcilla con su borde oscuro, su relleno y un brillo arriba a la izquierda (como su sprite).
func _terron(ci: CanvasItem, p: Vector2, r: float, alfa: float) -> void:
	if r <= 0.4 or alfa <= 0.01:
		return
	ci.draw_circle(p, r + 0.8, Color(_borde, alfa))
	ci.draw_circle(p, r, Color(_barro, alfa))
	ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(_claro, alfa))


# ------------------------------------------------------------
#  EL APLASTON (el puñetazo y la Machaca)
# ------------------------------------------------------------
const T_BAJA := 0.12

func _en_swing(u: float) -> Vector2:
	var p0: Vector2 = _swing[0]
	var p1: Vector2 = _swing[1]
	var p2: Vector2 = _swing[2]
	return p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)


# LA ESTELA DEL PUÑO que baja (la de la maza, MazaAire._estela, en arcilla): banda rellena GORDA en la cabeza y afilada
# y transparente hacia la cola.
func _estela_puno(ci: CanvasItem, s_cola: float, s_cabeza: float, grueso: float, alfa: float) -> void:
	if alfa <= 0.0 or s_cabeza - s_cola < 0.01:
		return
	var n: int = 10
	var tr := Color(_barro, 0.0)
	for i in n:
		var u0: float = float(i) / float(n)
		var u1: float = float(i + 1) / float(n)
		var p0: Vector2 = _en_swing(lerpf(s_cola, s_cabeza, u0))
		var p1: Vector2 = _en_swing(lerpf(s_cola, s_cabeza, u1))
		var d: Vector2 = (p1 - p0).normalized().orthogonal() if p1.distance_squared_to(p0) > 0.0001 else Vector2.RIGHT
		var w0: float = grueso * pow(u0, 1.3)
		var w1: float = grueso * pow(u1, 1.3)
		var c0 := Color(_claro, alfa * u0)
		var c1 := Color(_claro, alfa * u1)
		var h0 := Color(_barro, alfa * 0.6 * u0)
		var h1 := Color(_barro, alfa * 0.6 * u1)
		for lado in [1.0, -1.0]:
			ci.draw_primitive(PackedVector2Array([p0, p1, p1 + d * w1 * 0.45 * lado]), PackedColorArray([c0, c1, h1]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0, p1 + d * w1 * 0.45 * lado, p0 + d * w0 * 0.45 * lado]),
				PackedColorArray([c0, h1, h0]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.45 * lado, p1 + d * w1 * 0.45 * lado, p1 + d * w1 * lado]),
				PackedColorArray([h0, h1, tr]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.45 * lado, p1 + d * w1 * lado, p0 + d * w0 * lado]),
				PackedColorArray([h0, tr, tr]), PackedVector2Array())


# UNA PIEDRECILLA: poligono con su borde oscuro, su cara y una arista clara (como la piedra de su sprite).
func _piedra(ci: CanvasItem, p: Vector2, forma: PackedVector2Array, tam: float, giro: float, alfa: float) -> void:
	if alfa <= 0.01 or tam <= 0.3:
		return
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	for q in forma:
		var r: Vector2 = q.rotated(giro)
		fuera.append(p + r * (tam + 0.8))
		dentro.append(p + r * tam)
	ci.draw_colored_polygon(fuera, Color(_borde, alfa))
	ci.draw_colored_polygon(dentro, Color(_barro, alfa))
	ci.draw_colored_polygon(PackedVector2Array([dentro[0], dentro[1], p]), Color(_claro, alfa))


func _aplaston(capa: Node2D) -> void:
	var escala: float = 0.85 + 0.35 * _peso
	var grueso: float = maxf(_ancho * 0.9, 12.0) * escala
	if capa == _delante:
		# 1) EL PUÑO QUE BAJA: la estela de arriba abajo que acaba en el golpe y se apaga enseguida.
		var sw: float = clampf((_t + T_BAJA) / T_BAJA, 0.0, 1.0)
		if sw > 0.0 and _t < 0.1:
			_estela_puno(capa, maxf(0.0, sw - 0.75), sw * sw * (3.0 - 2.0 * sw), grueso, 0.95 * (1.0 - clampf(_t / 0.1, 0.0, 1.0)))
		if _t < 0.0:
			return
		# 3) LA ONDA que aplasta: media luna rellena hacia ABAJO (contra el suelo) que se abre y se apaga.
		var ko: float = clampf(_t / 0.2, 0.0, 1.0)
		if ko < 1.0:
			var ang: float = PI * 0.5 + _incl * 0.5
			BestiaAire._media_luna(capa, _imp, ang - 1.35, ang + 1.35, (5.0 + 16.0 * ko) * escala, lerpf(11.0, 6.0, ko) * escala,
				_claro, _barro, 0.85 * (1.0 - ko), true)
		# 4) LAS PIEDRECILLAS: saltan alto, giran y caen; al llegar a los pies se paran y se apagan.
		for g in _piezas:
			var tg: float = _t - float(g["t0"])
			if tg < 0.0 or tg > 0.7:
				continue
			var v: Vector2 = g["v"]
			var p: Vector2 = _imp + v * tg + Vector2(0.0, 0.5 * GRAVEDAD * tg * tg)
			var suelo_y: float = _pies.y + 2.0 + float(g["tam"])
			var alfa: float = 1.0
			if p.y > suelo_y and v.y + GRAVEDAD * tg > 0.0:
				p.y = suelo_y
				alfa = 1.0 - clampf((tg - 0.45) / 0.25, 0.0, 1.0)
			_piedra(capa, p, g["forma"], float(g["tam"]), float(g["gira"]) * minf(tg, 0.45), alfa)
		return
	if capa == _brillo:
		if _t < 0.0:
			return
		# 2) EL FOGONAZO ROMO del impacto: destello corto y un brillo calido.
		var pulso: float = exp(-_t / 0.06)
		BarridoAire.destello(capa, _imp, (9.0 + 10.0 * pulso) * escala, Color(1.0, 0.95, 0.85, pulso), _incl + 0.4)
		BarridoAire.brillo(capa, _imp, grueso * 0.8, Color(1.0, 0.85, 0.65, 0.5 * (1.0 - clampf(_t / 0.2, 0.0, 1.0))))
		return
	if capa == _suelo and _t >= 0.0:
		# 5) EL POLVO que levanta a sus pies (el golpe le hunde contra el suelo), hacia los lados.
		var kp: float = clampf(_t / 0.45, 0.0, 1.0)
		for i in 4:
			var lado: float = -1.0 if i % 2 == 0 else 1.0
			var q: Vector2 = _pies + Vector2(lado * _ancho * (0.35 + 0.6 * kp) * (1.0 + 0.3 * float(i / 2)), -4.0 * kp)
			BestiaAire._bola(capa, q, _ancho * (0.28 + 0.3 * kp) * escala, Color(POLVO, 0.4 * (1.0 - kp)))


# ------------------------------------------------------------
#  LOS PEGOTES (le ha dejado lento)
# ------------------------------------------------------------
func _pegotes(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var sale: float = clampf(_t / 0.1, 0.0, 1.0)
	var alfa: float = 1.0 - smoothstep(0.6, 1.0, _t / T_PEGOTES)
	for g in _piezas:
		var p: Vector2 = _pies + Vector2(float(g["x"]) * _ancho, float(g["y"]) * _largo + 1.5 * _t)
		# MANCHAS de barro pegadas (con su borde), no bolas; resbalan un poco mientras se van.
		var tam: float = float(g["tam"]) * sale
		var fuera := PackedVector2Array()
		var dentro := PackedVector2Array()
		for q in (g["forma"] as PackedVector2Array):
			fuera.append(p + q * (tam + 0.8))
			dentro.append(p + q * tam)
		capa.draw_colored_polygon(fuera, Color(_borde, alfa))
		capa.draw_colored_polygon(dentro, Color(_barro.darkened(0.2), alfa))


# ------------------------------------------------------------
#  COCERSE (el fuego, o el Endurecerse)
# ------------------------------------------------------------
# Un resplandor de brasa que le sube de los pies a la cabeza (una banda llena y blanda) y el vaho caliente que sube.
func _cocerse(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var u: float = clampf(_t / (T_COCERSE * 0.6), 0.0, 1.0)
	if capa == _brillo:
		var alto: float = lerpf(_largo * 0.45, -_largo * 0.5, u)
		var c: Vector2 = _hasta + Vector2(0.0, alto)
		var a: float = sin(u * PI) * (1.0 - _t / T_COCERSE)
		BestiaAire._bola(capa, c, _ancho * 0.75, Color(BRASA, 0.7 * a))
		BarridoAire.brillo(capa, _hasta, _ancho * 0.9, Color(BRASA, 0.3 * a))
		return
	if capa == _delante:
		_vaho(capa, 0.55)


func _vaho(capa: Node2D, fuerza: float) -> void:
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > 0.55:
			continue
		var k: float = tg / 0.55
		var p: Vector2 = Vector2(_hasta.x + float(g["x"]) * _ancho, _hasta.y - _largo * 0.35) \
			- Vector2(0.0, float(g["sube"]) * k)
		BestiaAire._bola(capa, p, _ancho * 0.22 * float(g["tam"]) * (0.6 + 0.9 * k), Color(VAHO, fuerza * (1.0 - k)))


# EL VAPOR (agua sobre la arcilla cocida): una nube blanca gorda que sube y se abre.
func _vapor(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	for g in _piezas:
		var tg: float = _t - float(g["t0"]) * 0.6
		if tg < 0.0 or tg > 0.7:
			continue
		var k: float = tg / 0.7
		var p: Vector2 = Vector2(_hasta.x + float(g["x"]) * _ancho * (1.0 + k), _hasta.y - _largo * 0.1) \
			- Vector2(0.0, float(g["sube"]) * 1.3 * k)
		BestiaAire._bola(capa, p, _ancho * 0.35 * float(g["tam"]) * (0.6 + 1.0 * k), Color(Color.WHITE, 0.6 * (1.0 - k * k)))


# ------------------------------------------------------------
#  LOS QUE SE QUEDAN
# ------------------------------------------------------------
# DURO: cada poco, un hilo de vaho que le sale de los hombros (la arcilla aun caliente).
func _duro(capa: Node2D) -> void:
	if capa != _delante:
		return
	var ciclo: float = 1.3
	var q: float = _queda()
	for i in 2:
		var tc: float = fmod(_t + float(i) * ciclo * 0.5, ciclo)
		if tc > 0.8:
			continue
		var k: float = tc / 0.8
		var lado: float = -1.0 if i == 0 else 1.0
		var p: Vector2 = Vector2(_hasta.x + lado * _ancho * 0.28, _hasta.y - _largo * 0.3) - Vector2(-lado * 2.0, 14.0 * k)
		BestiaAire._bola(capa, p, _ancho * 0.12 * (0.7 + 0.8 * k), Color(VAHO, 0.4 * (1.0 - k) * q))


# BLANDO: gotas de barro que le caen de los costados al suelo, y el charquito bajo los pies (un circulo en el suelo,
# no una elipse: huellas-suelo-circulos) que crece un poco al llegar cada gota.
func _blando(capa: Node2D) -> void:
	var q: float = _queda()
	var aparece: float = clampf(_t / 0.3, 0.0, 1.0)
	if capa == _suelo:
		var r: float = _ancho * (0.42 + 0.03 * sin(_t * 3.0)) * aparece
		# Oscuro (sobre el suelo de la mazmorra, un barro claro se leia como un resplandor) y con un brillo de agua.
		BestiaAire._bola(capa, _pies, r * 1.2, Color(_borde, 0.85 * q))
		BestiaAire._bola(capa, _pies, r * 0.9, Color(_barro.darkened(0.55), 0.9 * q))
		BestiaAire._bola(capa, _pies + Vector2(-r * 0.3, -r * 0.15), r * 0.25, Color(_claro, 0.35 * q))
		return
	if capa != _delante:
		return
	var ciclo: float = 0.9
	for i in 3:
		var tc: float = fmod(_t + float(i) * 0.31, ciclo)
		var k: float = tc / 0.45
		if k > 1.0:
			continue
		var lado: float = [-0.24, 0.26, -0.06][i]   # de SU cuerpo (mas afuera colgaban en el aire)
		var x: float = _hasta.x + lado * _ancho
		var y0: float = _hasta.y - _largo * [0.05, 0.15, 0.3][i]
		var p: Vector2 = Vector2(x, lerpf(y0, _pies.y - 1.0, k * k))
		_terron(capa, p, 2.6, q * (1.0 - smoothstep(0.85, 1.0, k)))
