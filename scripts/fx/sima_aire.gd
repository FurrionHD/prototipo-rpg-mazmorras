# ============================================================
#  sima_aire.gd
#  LOS EFECTOS DE LAS SIMAS en el mapa (30/09/2026): miconido, chupasimas, chillon y polilla, uno a uno y con su
#  visto bueno (ver la memoria simas-tactico). Aparte de InsectoAire y BestiaAire; usa sus piezas estaticas. Empieza
#  por el MICONIDO:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.SIMA_*):
#    PORRAZO     el basico: el sombrero le cae encima (lo hace su sprite, 'embestida'); aqui el golpe blando: un
#                aplaston redondo sobre la cabeza y una bocanada de esporas pardas que sale a los lados.
#    TOS         a cada uno que pilla la Bocanada: una nubecilla parda en la cara que se abre y motas que suben.
#    LATIGO      el Latigazo de micelio: NO ES UNA RAYA DESDE SUS PIES (lo pidio el usuario, 30/09: "que el latigo
#                parezca un brazo suyo"). Sale de la MANO del brazo que su sprite levanta EN ALTO ('micelio') y se
#                pinta COMO SU SPRITE: una cadena de cuentas con el borde oscuro, el relleno de su brazo y un brillo,
#                del grosor de su brazo y afilandose; ondea como un latigo, se enrosca en la pierna y se recoge.
#  SE QUEDA:
#    NUBE        la Bocanada (AbilityData.charco_estilo 2): la nube parda flotando a la altura de la cara los turnos
#                del miconido, cada vez mas rala y mas pequeña (como el charco de savia: CombatTactico._charco_visible).
#    ATADO       el Enraizado del micelio: cordones de su carne enroscados en las piernas mientras dure (el de las
#                raices del trent es BestiaAire.atado; CombatTactico._tick_raices elige).
#  NADA DE LINEAS (efectos-sin-lineas): cuentas, bolas blandas y cometas. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name SimaAire

enum Modo { PORRAZO, TOS, LATIGO, NUBE, ATADO }

const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ESPORA := Color(0.5, 0.4, 0.24)
const ESPORA_CLARA := Color(0.74, 0.64, 0.42)
const T_PORRAZO := 0.45
const T_TOS := 0.7
const T_LATIGO_VA := 0.2          # lo que tarda en llegar desde la mano (CombatFX.T_VUELO del SIMA_LATIGO)
const T_LATIGO_SUELTA := 0.35     # lo que se queda enroscado tras el golpe y se recoge
const T_NUBE_SALE := 0.33         # la nube sale en el reventon del sombrero ('esporas')
const T_SECA := 0.5

var modo: int = Modo.PORRAZO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _hasta: Vector2 = Vector2.ZERO
var _mano: Vector2 = Vector2.ZERO
var _eje: Vector2 = Vector2.RIGHT
var _ancho: float = 14.0
var _largo: float = 26.0
var _o: Vector2 = Vector2.ZERO
var _r: float = 40.0
var _viaje: float = 0.2
var queda: float = 1.0                # NUBE: lo que le queda (1 = recien soltada)
var _secando: float = -1.0            # NUBE, ATADO: desde cuando se esta yendo
var _piezas: Array = []
# Los tonos del bicho (MiconidoSprites._colores): el latigo y el atado van con SU carne.
var _borde: Color = Color(0.12, 0.1, 0.07)
var _carne: Color = Color(0.55, 0.5, 0.42)
var _brillo_c: Color = Color(0.78, 0.74, 0.64)
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = el cuerpo de quien lo lanza (su caja, para sacar su mano y su tamaño), 'caja' = el que lo recibe,
# 'espera' = lo que falta para el golpe, 'color' = el de la ficha del bicho (su color_visual).
# 'pies_a' = los pies de quien lo lanza (CombatTactico.pies_de): la mano del latigo se cuenta desde ahi.
static func sobre_cuerpo(padre: Node, m: int, desde: Rect2, caja: Rect2, pies_v: Vector2, color: Color, semilla: int,
		espera: float, ritmo: float, pies_a: Vector2 = Vector2.INF) -> SimaAire:
	if padre == null:
		return null
	var e := SimaAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._ancho = maxf(caja.size.x, 8.0)
	e._largo = maxf(caja.size.y, 10.0)
	e._tonos(color)
	var yo: Vector2 = pies_a if pies_a != Vector2.INF else (Vector2(desde.get_center().x, desde.end.y) if desde.has_area()
		else caja.get_center() - Vector2(40, 0))
	var eje: Vector2 = (pies_v - yo).normalized() if pies_v.distance_squared_to(yo) > 1.0 else Vector2.RIGHT
	e._eje = eje
	match m:
		Modo.PORRAZO:
			e._t = -maxf(espera, 0.0)
			e._hasta = Vector2(caja.get_center().x, caja.position.y + caja.size.y * 0.2)
			for i in 10:
				var lado: float = -1.0 if i % 2 == 0 else 1.0
				e._piezas.append({"d": Vector2(lado, 0.0).rotated(lado * e._rng.randf_range(-0.9, 0.2)),
					"v": e._rng.randf_range(12.0, 24.0), "tam": e._rng.randf_range(0.32, 0.5), "t0": e._rng.randf_range(0.0, 0.05)})
		Modo.TOS:
			e._t = -maxf(espera, 0.0)
			e._hasta = Vector2(caja.get_center().x, caja.position.y + caja.size.y * 0.28)
			for i in 7:
				e._piezas.append({"p": Vector2(e._rng.randf_range(-0.5, 0.5), e._rng.randf_range(-0.3, 0.3)),
					"tam": e._rng.randf_range(0.28, 0.45), "t0": e._rng.randf_range(0.0, 0.08)})
		Modo.LATIGO:
			e._viaje = clampf(espera, 0.08, T_LATIGO_VA)
			e._t = -e._viaje
			# LA MANO: la de SU brazo en alto ('micelio'), sacada del propio sprite (MiconidoSprites.mano_del_latigo)
			# y escalada con el ancho de su dibujo, que es el del ala del sombrero.
			var px: float = desde.size.x / (2.0 * MiconidoSprites.ALA_R.x) if desde.has_area() else 2.0
			e._mano = yo + MiconidoSprites.mano_del_latigo(eje) * px
			# Donde se enrosca: la espinilla.
			e._hasta = pies_v - Vector2(0.0, caja.size.y * 0.2)
			e._r = maxf(desde.size.x * 0.07, 2.6)   # el grosor del brazo en la raiz
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# LA NUBE QUE SE QUEDA (la Bocanada). No se va sola: la seca CombatTactico. 'espera' = lo que falta para que salga.
static func nube(padre: Node, f, semilla: int, espera: float) -> SimaAire:
	if padre == null or f == null:
		return null
	var e := SimaAire.new()
	e.modo = Modo.NUBE
	e._rng.seed = hash(semilla)
	e._t = -maxf(espera, 0.0)
	e._o = f.centro
	e._r = maxf(f.radio, 8.0)
	# LAS BOCANADAS que la forman, repartidas por el circulo (mas en el centro), cada una con su deriva.
	# QUE LLENE SU CIRCULO: con 16 bocanadas pequeñas y hasta 0,78 del radio solo le rodeaba a el, y lo que importa es
	# que se vea hasta donde no hay que meterse.
	for i in 24:
		var a: float = e._rng.randf_range(0.0, TAU)
		var d: float = sqrt(e._rng.randf()) * 0.88
		e._piezas.append({"p": Vector2(cos(a), sin(a)) * d, "tam": e._rng.randf_range(0.3, 0.44),
			"fase": e._rng.randf_range(0.0, TAU), "vel": e._rng.randf_range(0.5, 1.1), "vida": e._rng.randf()})
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	return e


# LOS CORDONES QUE ATAN (Enraizado del micelio), con los tonos del miconido. Sigue al atado con seguir().
static func atado(padre: Node, caja: Rect2, pies: Vector2, color: Color, semilla: int) -> SimaAire:
	if padre == null:
		return null
	var e := SimaAire.new()
	e.modo = Modo.ATADO
	e._rng.seed = hash(semilla)
	e._tonos(color)
	for i in 3:
		# A LAS ESPINILLAS: mas abajo quedaban a ras de los pies, como un monton en el suelo.
		e._piezas.append({"h": 0.16 + 0.12 * float(i) + e._rng.randf_range(-0.02, 0.02),
			"inc": e._rng.randf_range(-0.25, 0.25), "fase": e._rng.randf_range(0.0, TAU)})
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e.seguir(caja, pies)
	e._delante = e._capa(Z_ENCIMA, false)
	return e


func seguir(caja: Rect2, pies: Vector2) -> void:
	_hasta = pies
	_ancho = maxf(caja.size.x, 8.0)
	_largo = maxf(caja.size.y, 10.0)


func secar() -> void:
	if _secando < 0.0:
		_secando = maxf(_t, 0.0)


func _tonos(color: Color) -> void:
	var cs: Array = MiconidoSprites._colores(color)
	_borde = cs[MiconidoSprites.Tono.BORDE]
	_carne = cs[MiconidoSprites.Tono.BRAZO]
	_brillo_c = cs[MiconidoSprites.Tono.CUERPO_T]


func duracion() -> float:
	match modo:
		Modo.PORRAZO: return T_PORRAZO
		Modo.TOS: return T_TOS
		Modo.LATIGO: return T_LATIGO_SUELTA + 0.25
		Modo.NUBE, Modo.ATADO: return INF if _secando < 0.0 else _secando + T_SECA
	return 1.0


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
	for n in [_delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.PORRAZO: _porrazo(capa)
		Modo.TOS: _tos(capa)
		Modo.LATIGO: _latigo(capa)
		Modo.NUBE: _nube(capa)
		Modo.ATADO: _atado(capa)


# ------------------------------------------------------------
#  EL MICONIDO
# ------------------------------------------------------------
# EL PORRAZO: el sombrero le ha caido encima. Un aplaston ancho y redondo sobre la cabeza (media luna simetrica
# boca abajo, del ocre del sombrero) y la bocanada de esporas que sale despedida a los lados.
func _porrazo(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var c: Vector2 = _hasta
	if capa == _brillo:
		if _t < 0.1:
			BarridoAire.destello(capa, c, _ancho * 0.45, Color(1.0, 0.92, 0.75, 0.7 * (1.0 - _t / 0.1)), 0.3)
		return
	if capa != _delante:
		return
	var k: float = clampf(_t / 0.14, 0.0, 1.0)
	# GORDO: con medio ancho de figura salia una rayita.
	var r: float = _ancho * lerpf(0.75, 1.05, k)
	# UNA CUPULA que baja sobre la cabeza (la del sombrero), no una sonrisa debajo: arco por ARRIBA, bajando con 'k'.
	BestiaAire._media_luna(capa, c + Vector2(0.0, r * 0.35 + _ancho * 0.25 * k), -PI * 0.5 - 1.1, -PI * 0.5 + 1.1, r, _ancho * 0.75,
		ESPORA_CLARA, ESPORA, 1.0 - k * k, true)
	_motas(capa, c, 0.4)


# Bocanadas pardas que salen de 'c' por su 'd', se hinchan y se apagan.
func _motas(capa: Node2D, c: Vector2, dura: float) -> void:
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > dura:
			continue
		var k: float = tg / dura
		var q: Vector2 = c + (g["d"] as Vector2) * float(g["v"]) * sqrt(k) - Vector2(0.0, 4.0 * k)
		var rr: float = _ancho * float(g["tam"]) * (0.6 + 0.8 * k)
		BestiaAire._bola(capa, q, rr, Color(ESPORA, 0.75 * (1.0 - k)))
		BestiaAire._bola(capa, q - Vector2(0.5, 0.8), rr * 0.55, Color(ESPORA_CLARA, 0.6 * (1.0 - k)))


# LA TOS: una nubecilla parda en la cara del que pilla la Bocanada, que se abre y se va, con motas que suben.
func _tos(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0:
			continue
		var k: float = clampf(tg / (T_TOS - 0.1), 0.0, 1.0)
		var p: Vector2 = _hasta + (g["p"] as Vector2) * _ancho * (1.0 + 0.8 * k) - Vector2(0.0, 5.0 * k)
		var rr: float = _ancho * float(g["tam"]) * (0.7 + 0.7 * k)
		BestiaAire._bola(capa, p, rr, Color(ESPORA, 0.5 * (1.0 - k)))
		BestiaAire._bola(capa, p - Vector2(0.6, 1.0), rr * 0.5, Color(ESPORA_CLARA, 0.4 * (1.0 - k)))
		capa.draw_circle(p + Vector2(rr * 0.4, -rr * 0.6 - 3.0 * k), 0.8, Color(ESPORA_CLARA, 0.8 * (1.0 - k)))


# UN CORDON DE SU CARNE, a lo largo de 'puntos', pintado como su sprite: primero todas las cuentas en BORDE un poco
# mas gordas (el contorno), luego el relleno de su brazo y encima un brillo arriba. Las cuentas van pegadas (una cada
# medio radio) y en pixeles enteros: asi se lee como pixel art y no como una raya suave.
func _cordon(capa: Node2D, puntos: PackedVector2Array, r0: float, r1: float, alfa: float) -> void:
	if puntos.size() < 2 or alfa <= 0.01:
		return
	var cuentas: Array = []
	var total: float = 0.0
	for i in puntos.size() - 1:
		total += puntos[i].distance_to(puntos[i + 1])
	var hecho: float = 0.0
	for i in puntos.size() - 1:
		var a: Vector2 = puntos[i]
		var b: Vector2 = puntos[i + 1]
		var tramo: float = a.distance_to(b)
		var s: float = 0.0
		while s < tramo:
			var f: float = (hecho + s) / maxf(total, 0.001)
			var r: float = lerpf(r0, r1, f)
			cuentas.append([a.lerp(b, s / maxf(tramo, 0.001)).round(), r])
			s += maxf(r * 0.5, 0.6)
		hecho += tramo
	cuentas.append([puntos[puntos.size() - 1].round(), r1])
	for q in cuentas:
		capa.draw_circle(q[0], float(q[1]) + 1.0, Color(_borde, alfa))
	for q in cuentas:
		capa.draw_circle(q[0], float(q[1]), Color(_carne, alfa))
	for q in cuentas:
		capa.draw_circle((q[0] as Vector2) + Vector2(-0.3, -0.45) * float(q[1]), float(q[1]) * 0.45, Color(_brillo_c, alfa))


# EL LATIGAZO: el cordon sale de la mano (que su sprite ya tiene lanzada al frente), dibuja un arco por encima, ondea
# como un latigo (una onda que corre hacia la punta y se apaga al llegar) y la punta llega a la espinilla EN el golpe;
# ahi da dos vueltas a la pierna (la de delante encima) y el resto del cordon se tensa; luego se recoge a la mano.
func _latigo(capa: Node2D) -> void:
	var va: float     # lo que ha salido (1 = entero hasta la pierna)
	var alfa: float = 1.0
	var tenso: float = 0.0
	if _t < 0.0:
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		va = 1.0 - (1.0 - u) * (1.0 - u)
	else:
		va = 1.0
		tenso = clampf(_t / 0.08, 0.0, 1.0)
		if _t > T_LATIGO_SUELTA:
			va = 1.0 - clampf((_t - T_LATIGO_SUELTA) / 0.22, 0.0, 1.0)
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.1:
			BarridoAire.destello(capa, _hasta, _ancho * 0.5, Color(1.0, 0.95, 0.85, 0.75 * (1.0 - _t / 0.1)), 0.4)
		return
	if capa != _delante or va <= 0.01:
		return
	var a: Vector2 = _mano
	var b: Vector2 = _hasta
	var d: Vector2 = b - a
	var n: Vector2 = d.orthogonal().normalized()
	if n.y > 0.0:
		n = -n   # el arco, por ARRIBA
	var largo: float = d.length()
	var arco: float = largo * 0.22 * (1.0 - 0.7 * tenso)
	var pts := PackedVector2Array()
	var tramos: int = 24
	for i in tramos + 1:
		var f: float = float(i) / float(tramos) * va
		# LA ONDA DEL LATIGO: corre hacia la punta mientras sale y se apaga al tensarse.
		var onda: float = sin(f * 9.0 - _t * 40.0) * largo * 0.06 * f * (1.0 - tenso) * (1.0 - f * 0.5)
		pts.append(a + d * f + n * (arco * sin(PI * f) + onda))
	var r0: float = _r
	var r1: float = maxf(_r * 0.55, 1.2)
	_cordon(capa, pts, r0, lerpf(r0, r1, va), alfa)
	# LAS VUELTAS a la pierna, al llegar: dos anillos de cuentas alrededor de la espinilla, a lo ancho de la figura.
	if _t >= -0.02 and va >= 0.99:
		var cierra: float = clampf((_t + 0.02) / 0.08, 0.0, 1.0)
		for k in 2:
			var cy: float = b.y - float(k) * r1 * 2.6
			var anillo := PackedVector2Array()
			for j in 11:
				var ang: float = lerpf(PI * 1.05, PI * (1.05 - 1.1 * cierra), float(j) / 10.0)
				anillo.append(Vector2(b.x + cos(ang) * _ancho * 0.42, cy - sin(ang) * r1 * 1.6))
			_cordon(capa, anillo, r1, r1, alfa)


# LA NUBE QUE SE QUEDA: bocanadas pardas blandas a la altura de la cara (subidas del circulo del suelo), cada una
# derivando a su ritmo, con motas claras que suben. Sale abriendose desde el centro; cada turno mas rala (se apagan
# las de mas vida) y mas pequeña; al secarse se deshace. Y en el suelo, una sombra parda que marca por donde llega.
func _nube(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var sale: float = clampf(_t / 0.35, 0.0, 1.0)
	sale = 1.0 - (1.0 - sale) * (1.0 - sale)
	var va: float = 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)
	# El mismo radio con el que la pelea mira quien esta dentro (BestiaAire.radio_charco).
	var r: float = _r * lerpf(0.6, 1.0, queda) * lerpf(0.3, 1.0, sale)
	var alto: float = 12.0
	BestiaAire._bola(capa, _o, r * 1.05, Color(ESPORA.darkened(0.3), 0.3 * va * sale))
	for g in _piezas:
		if float(g["vida"]) > queda + 0.15:
			continue   # las que ya se fueron
		var fase: float = float(g["fase"]) + _t * float(g["vel"])
		var p: Vector2 = _o + (g["p"] as Vector2) * r + Vector2(sin(fase) * 3.0, cos(fase * 0.7) * 1.5 - alto)
		var rr: float = r * float(g["tam"]) * (0.9 + 0.15 * sin(fase * 1.3))
		BestiaAire._bola(capa, p, rr, Color(ESPORA, 0.5 * va * sale))
		BestiaAire._bola(capa, p - Vector2(1.0, 1.5), rr * 0.55, Color(ESPORA_CLARA, 0.4 * va * sale))
		# La mota que sube de cada una, en bucle.
		var m: float = fmod(_t * 0.5 * float(g["vel"]) + float(g["vida"]), 1.0)
		capa.draw_circle(p + Vector2(sin(fase * 2.0) * 2.0, -8.0 * m), 0.9, Color(ESPORA_CLARA, 0.7 * va * sale * (1.0 - m)))


# EL ATADO DEL MICELIO: dos o tres anillos de cordon de su carne alrededor de las piernas, un poco ladeados, que
# suben al atar y se sueltan al acabar el Enraizado. Solo la mitad de delante: la de detras la tapa la pierna.
func _atado(capa: Node2D) -> void:
	if capa != _delante:
		return
	var sube: float = clampf(_t / 0.2, 0.0, 1.0)
	var va: float = 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)
	var alfa: float = sube * va
	if alfa <= 0.01:
		return
	var r: float = maxf(_ancho * 0.1, 1.4)
	for g in _piezas:
		var cy: float = _hasta.y - _largo * float(g["h"]) * sube
		var inc: float = float(g["inc"]) + 0.05 * sin(_t * 2.0 + float(g["fase"]))
		var anillo := PackedVector2Array()
		for j in 11:
			var ang: float = PI * float(j) / 10.0
			anillo.append(Vector2(_hasta.x + cos(ang) * _ancho * 0.5, cy + sin(ang) * r * 1.4 + cos(ang) * inc * _ancho * 0.5))
		_cordon(capa, anillo, r, r, alfa)
