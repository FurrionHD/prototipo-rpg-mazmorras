# ============================================================
#  minotauro_aire.gd
#  LOS EFECTOS DEL MINOTAURO en el mapa (02/10/2026, paso 2; propuesta aprobada: ver la memoria minotauro-tactico).
#  Copiados de los que le gustaron (el hacha grande, la acorazada, el coloso, el Grito del mandoble) en su piel de bestia:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.MINO_*):
#    HACHAZO     su basico (el hacha la baja su sprite): la media luna GORDA del hacha cae de arriba sobre quien lo recibe
#                (cabeza gorda y cola fina, como HachaAire._mordisco), se clava en seco con un destello y se apaga de
#                golpe. Inclinada segun de donde viene el golpe, cada uno a su manera. La sangre va aparte (SangreMapa).
#                Si lo ESQUIVA, el filo se clava en el SUELO a su lado: grietas cortas, polvo y piedrecillas.
#    CORNADA     el enganche de la Cornada (lo hacen su sprite y el desliz): un FOGONAZO ROMO a la altura de los cuernos
#                (puntas cortas y gordas, no estrella), polvo que sale de sus pies hacia donde le empuja y piedrecillas.
#                El temblor de la figura y la sangre, CombatTactico.
#    SISMO       a quien le pilla el Pisoton: polvo que le sube de los pies (el temblor, CombatTactico).
#  POR EL SUELO (SueloRoto.Tipo.MINO_*):
#    PISOTON     un solo impacto (efectos-copiar-los-god): el CRATER bajo su pezuña, grietas que corren hasta el borde, DOS
#                anillos de losas que saltan uno tras otro (como el coloso; sus dos tramos) y el polvo del borde.
#    BRAMIDO     el chorro de VAHO que le sale del morro y TRES ANILLOS GRAVES rellenos (filo duro por fuera que se
#                difumina hacia dentro, como la onda del Grito de guerra) pardo-rojizos, ondulados; levantan polvo al pasar.
#  SOBRE EL (CombatTactico._tick_minotauro):
#    ESCARBA     mientras carga la Cornada, agazapado: la pezuña de atras escarba (terrones hacia atras y polvo) y le sale
#                vaho del morro.
#    RABIA       al cruzar el 30% (una vez): el cuerno izquierdo SALE VOLANDO (chispa de hueso y astillas al partirse),
#                cae al suelo y se queda un rato; un fogonazo rojizo en su cuerpo y dos bocanadas de vaho.
#    RABIOSO     mientras le dure: bocanadas de vaho de vez en cuando (los ojos rojos y el rojizo los pone el shader
#                rabia_minotauro sobre su sprite).
#  NADA DE LINEAS (efectos-sin-lineas): bandas rellenas con degradado, cometas, bolas blandas. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name MinotauroAire

enum Modo { HACHAZO, CORNADA, SISMO, ESCARBA, PISOTON, BRAMIDO, RABIA, RABIOSO }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const GRAVEDAD := 320.0

# Los colores. El acero y la sangre, los del hacha grande; el suelo, el de la mazmorra.
const BLANCO := BarridoAire.BLANCO
const ACERO := HachaAire.ACERO
const SANGRE := HachaAire.SANGRE
const SANGRE_VIVA := HachaAire.SANGRE_VIVA
const POLVO := Color(0.6, 0.55, 0.5)
const TIERRA := Color(0.36, 0.3, 0.26)
const TERRON := Color(0.55, 0.47, 0.4)   # lo que escarba: claro, sobre el suelo oscuro se perdia
const VAHO := Color(0.88, 0.86, 0.84)
const PARDO := Color(0.78, 0.5, 0.36)       # el bramido: pardo que tira a rojo
const ROJIZO := Color(1.0, 0.32, 0.18)
const HUESO := Color(0.96, 0.91, 0.79)      # el cuerno (el de su sprite, 244/232/201)
const HUESO_OSCURO := Color(0.72, 0.6, 0.45)
const LOSA_BORDE := Color(0.1, 0.09, 0.1)
const LOSA_CARA := Color(0.3, 0.29, 0.31)
const LOSA_TAPA := Color(0.5, 0.49, 0.5)

const T_BAJA := 0.08          # lo que tarda el hacha en bajar (su vuelo en CombatFX.T_VUELO)
const T_CLAVADO := 0.09       # y lo que se queda clavada entera
const T_APAGA := 0.12         # y lo que tarda en irse: de golpe, como el hacha
const T_HACHAZO := 0.7
const T_CORNADA := 0.6
const T_SISMO := 0.8
const T_PISOTON := 0.25       # lo que tarda el frente del Pisoton en llegar a su borde
const T_BRAMIDO := 0.5        # y el primer anillo del Bramido
const T_RABIA := 1.2
const T_CUERNO_VUELA := 0.62  # lo que vuela el cuerno hasta el suelo
const T_CUERNO_SUELO := 6.0   # y lo que se queda alli
const T_SECA := 0.5
# EL MORRO: a que altura (en fraccion de su caja, desde arriba) y cuanto adelantado (fraccion del ancho) va, de pie y
# agazapado. Medido sobre sus hojas.
const MORRO_ALTO := 0.2
const MORRO_ALTO_AGACHADO := 0.55
const MORRO_DELANTE := 0.32
# El bramido no tiene su caja (va por el suelo): su morro, sobre los pies (medido con la cabeza echada atras).
const ALTO_MORRO_BRAMIDO := 74.0

var modo: int = Modo.HACHAZO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _caja: Rect2 = Rect2()
var _pies: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.DOWN      # hacia donde mira (o hacia donde va el golpe)
var _imp: Vector2 = Vector2.ZERO      # donde entra / donde revienta
var _camino: Array = []               # HACHAZO: por donde baja el filo (bezier de tres puntos)
var _lado: float = 1.0
var _fallo: bool = false
var _piezas: Array = []
var _bocanadas: Array = []            # {t0, p, v, tam}
var _siguiente: float = 0.0           # ESCARBA / RABIOSO: cuando toca la proxima
var _par: bool = false
var _secando: float = -1.0
var _o: Vector2 = Vector2.ZERO
var _radio: float = 60.0
var _anillos: Array = []
var _grietas: Array = []
var _crater := PackedVector2Array()
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = el centro de quien pega, 'caja' y 'pies' = los de quien lo recibe. 'fallo' = lo esquivo (el hachazo se clava
# en el suelo).
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, pies: Vector2, semilla: int, espera: float,
		ritmo: float, fallo: bool = false) -> MinotauroAire:
	if padre == null:
		return null
	var e := MinotauroAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._caja = caja
	e._pies = pies
	e._fallo = fallo
	var c: Vector2 = caja.get_center()
	e._dir = (c - desde).normalized() if c.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	e._t = -maxf(espera, 0.0)
	match m:
		Modo.HACHAZO:
			e._preparar_hachazo()
		Modo.CORNADA:
			# A la altura de los cuernos (bajos: va agachado), del lado de quien embiste.
			e._imp = Vector2(c.x - e._dir.x * caja.size.x * 0.32, caja.position.y + caja.size.y * 0.58)
			for i in 9:
				e._piezas.append(_esquirla(e._rng, Vector2(e._dir.x, e._dir.y * K), 0.75))
			for i in 7:
				e._bocanadas.append({"t0": e._rng.randf_range(0.0, 0.08), "x": e._rng.randf_range(-0.45, 0.45),
					"v": e._dir * e._rng.randf_range(18.0, 34.0) + Vector2(0.0, -e._rng.randf_range(4.0, 10.0)),
					"tam": e._rng.randf_range(4.5, 7.5)})
		Modo.SISMO:
			for i in 7:
				e._bocanadas.append({"t0": e._rng.randf_range(0.0, 0.12), "x": e._rng.randf_range(-0.5, 0.5),
					"v": Vector2(e._rng.randf_range(-8.0, 8.0), -e._rng.randf_range(10.0, 22.0)),
					"tam": e._rng.randf_range(4.0, 6.5)})
	e.z_as_relative = false
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# LO QUE SE QUEDA SOBRE EL (escarbar mientras carga, la rabia mientras le dure): sigue a su cuerpo (seguir) y se va
# (secar). RABIA es de una vez y se va sola.
static func sobre_el(padre: Node, m: int, caja: Rect2, pies: Vector2, dir: Vector2, semilla: int) -> MinotauroAire:
	if padre == null:
		return null
	var e := MinotauroAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e.seguir(caja, pies, dir)
	e.z_as_relative = false
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	if m == Modo.RABIA:
		e._preparar_rabia()
	elif m == Modo.RABIOSO:
		e._siguiente = e._rng.randf_range(0.6, 1.4)
	padre.add_child(e)
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


func seguir(caja: Rect2, pies: Vector2, dir: Vector2) -> void:
	_caja = caja
	_pies = pies
	if dir.length_squared() > 0.0001:
		_dir = dir.normalized()


func secar() -> void:
	if _secando < 0.0:
		_secando = _t


# ------------------------------------------------------------
#  POR EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, bramido: bool, semilla: int, espera: float) -> MinotauroAire:
	if padre == null or f == null:
		return null
	var e := MinotauroAire.new()
	e.modo = Modo.BRAMIDO if bramido else Modo.PISOTON
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._o = f.centro
	e._radio = maxf(f.radio, 8.0)
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.DOWN
	e.z_as_relative = false
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	if bramido:
		e._preparar_bramido()
	else:
		e._preparar_pisoton()
	padre.add_child(e)
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	e._t = -maxf(espera, 0.0) * e._ritmo
	return e


# CUANDO LE LLEGA a 'p' (el frente sale del pie y llega al borde en su tiempo).
static func retraso(f: CombatFormas.Forma, p: Vector2, bramido: bool) -> float:
	if f == null:
		return 0.0
	var u: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
	return _llega_bramido(u) if bramido else u * T_PISOTON


# El primer anillo del Bramido llega a la fraccion 'u' del radio cuando 1 - (1 - prog)^1,6 = u (ver _bramido).
static func _llega_bramido(u: float) -> float:
	return T_BRAMIDO * (1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 1.0 / 1.6))


# ------------------------------------------------------------
#  EL RELOJ Y LAS CAPAS
# ------------------------------------------------------------
func duracion() -> float:
	match modo:
		Modo.HACHAZO: return T_HACHAZO
		Modo.CORNADA: return T_CORNADA
		Modo.SISMO: return T_SISMO
		Modo.PISOTON: return T_PISOTON + 1.1
		Modo.BRAMIDO: return T_BRAMIDO + 0.2 * 2.0 + 0.9
		Modo.RABIA: return _t_vuela + T_CUERNO_SUELO + 0.6
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
	if modo in [Modo.ESCARBA, Modo.RABIOSO] and _secando < 0.0 and _t >= _siguiente:
		_soltar_tanda()
	for n in [_suelo, _delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.HACHAZO: _hachazo(capa)
		Modo.CORNADA: _cornada(capa)
		Modo.SISMO: _sismo(capa)
		Modo.ESCARBA, Modo.RABIOSO: _de_estado(capa)
		Modo.PISOTON: _pisoton(capa)
		Modo.BRAMIDO: _bramido(capa)
		Modo.RABIA: _rabia(capa)


# Lo que queda al irse (los que se quedan se secan poco a poco).
func _queda() -> float:
	return 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
# UNA ESQUIRLA ANGULOSA (poligono de 4-5 lados) que sale hacia 'hacia' y hacia arriba, y cae con peso.
static func _esquirla(rng: RandomNumberGenerator, hacia: Vector2, fuerza: float) -> Dictionary:
	var n_l: int = 4 + rng.randi() % 2
	var forma_e := PackedVector2Array()
	for k in n_l:
		var a: float = TAU * float(k) / float(n_l) + rng.randf_range(-0.35, 0.35)
		forma_e.append(Vector2(cos(a), sin(a)) * rng.randf_range(0.6, 1.1))
	var sal: Vector2 = (hacia * 0.7 + Vector2(rng.randf_range(-1.0, 1.0), 0.0)).normalized()
	return {"v": sal * rng.randf_range(30.0, 60.0) * fuerza + Vector2(0.0, -rng.randf_range(60.0, 110.0) * fuerza),
		"tam": rng.randf_range(1.5, 2.6), "gira": rng.randf_range(-14.0, 14.0), "forma": forma_e,
		"t0": rng.randf_range(0.0, 0.05)}


# Una piedrecilla en vuelo: su forma con borde oscuro y cara de suelo.
func _piedra(ci: CanvasItem, p: Vector2, forma_p: PackedVector2Array, tam: float, giro: float, alfa: float,
		cara: Color = LOSA_CARA) -> void:
	if alfa <= 0.01:
		return
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	for q in forma_p:
		var r: Vector2 = q.rotated(giro)
		fuera.append(p + r * (tam + 0.8))
		dentro.append(p + r * tam)
	Poligono.relleno(ci, fuera, Color(LOSA_BORDE, alfa))
	Poligono.relleno(ci, dentro, Color(cara, alfa))


# Las esquirlas de '_piezas' saltando desde 'desde' (t = desde que saltan), hasta caer a 'suelo_y'.
func _esquirlas(ci: CanvasItem, desde: Vector2, t: float, suelo_y: float, vida: float, cara: Color = LOSA_CARA) -> void:
	for g in _piezas:
		var tg: float = t - float(g["t0"])
		if tg < 0.0 or tg > vida:
			continue
		var v: Vector2 = g["v"]
		var p: Vector2 = desde + v * tg + Vector2(0.0, 0.5 * GRAVEDAD * tg * tg)
		p.y = minf(p.y, suelo_y)
		var alfa: float = 1.0 - clampf((tg - vida * 0.6) / (vida * 0.4), 0.0, 1.0)
		_piedra(ci, p, g["forma"], float(g["tam"]), float(g["gira"]) * tg, alfa)


# Una grieta en el suelo: poligono quebrado que se afila (es suelo, no el efecto: puede ser trazo relleno).
static func _grieta(ci: CanvasItem, o: Vector2, d: Vector2, largo: float, grueso: float, alfa: float, quiebro: float) -> void:
	if largo < 1.0 or alfa <= 0.01:
		return
	var n: Vector2 = d.orthogonal()
	var codo: Vector2 = o + d * largo * 0.5 + n * largo * quiebro
	var fin: Vector2 = o + d * largo
	Poligono.relleno(ci, PackedVector2Array([o + n * grueso, codo + n * grueso * 0.6, fin, codo - n * grueso * 0.6,
		o - n * grueso]), Color(LOSA_BORDE, alfa * 0.9))


# UNA BOCANADA de vaho o de polvo: bola blanda que crece y se apaga.
static func _nube(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	BestiaAire._bola(ci, p, r, col)


# ------------------------------------------------------------
#  EL HACHAZO (su basico)
# ------------------------------------------------------------
func _preparar_hachazo() -> void:
	var c: Vector2 = _caja.get_center()
	var w: float = maxf(_caja.size.x, 10.0)
	var h: float = maxf(_caja.size.y, 14.0)
	# EL LADO por donde baja: del de quien pega (lo lateral es la perpendicular en el suelo achatada; de N/S, al azar),
	# con su inclinacion propia en cada golpe.
	_lado = -signf(_dir.x) if absf(_dir.x) > 0.2 else (1.0 if _rng.randf() < 0.5 else -1.0)
	var incl: float = _rng.randf_range(0.25, 0.55)
	if _fallo:
		# Se clava en el suelo a su lado, del de quien pega.
		_imp = _pies + Vector2(_lado * w * 0.55, _rng.randf_range(-2.0, 3.0)) - _dir * 3.0
		var arriba: Vector2 = _imp + Vector2(_lado * maxf(w, 14.0) * (1.2 + incl), -maxf(h * 1.8, 44.0))
		_camino = [arriba, _imp + Vector2(_lado * maxf(w, 14.0) * (1.05 + incl), -maxf(h * 1.8, 44.0) * 0.25), _imp]
		for i in 7:
			_piezas.append(_esquirla(_rng, Vector2(-_lado, 0.0), 0.55))
		for i in 5:
			_bocanadas.append({"t0": _rng.randf_range(0.0, 0.08), "x": _rng.randf_range(-6.0, 6.0),
				"v": Vector2(_rng.randf_range(-14.0, 14.0), -_rng.randf_range(6.0, 14.0)), "tam": _rng.randf_range(4.0, 6.5)})
		for i in 3:
			_grietas.append({"a": _rng.randf_range(0.0, TAU), "l": _rng.randf_range(8.0, 14.0), "q": _rng.randf_range(-0.2, 0.2)})
		return
	# Entra arriba (hombro/cabeza) y se para a media altura: un hacha se lleva arriba y cae, y se hunde.
	_imp = c + Vector2(_lado * w * _rng.randf_range(0.0, 0.12), h * _rng.randf_range(0.0, 0.12))
	# GRANDE: es el hacha de un gigante. A la medida de la figura (1,25 de su alto) salia una pua fina.
	var alto: float = maxf(h * 2.0, 48.0)
	_camino = [_imp + Vector2(_lado * maxf(w, 14.0) * (1.4 + incl), -alto),
		_imp + Vector2(_lado * maxf(w, 14.0) * (1.25 + incl), -alto * 0.25), _imp]
	for i in 5:
		_piezas.append({"a": _rng.randf_range(-0.9, 0.9), "v": _rng.randf_range(26.0, 44.0), "l": _rng.randf_range(4.0, 8.0)})


func _en_camino(u: float) -> Vector2:
	var a: Vector2 = _camino[0]
	var b: Vector2 = _camino[1]
	var c: Vector2 = _camino[2]
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


# LA MEDIA LUNA DEL HACHA por el camino, de 's_cola' a 's_cabeza' (0..1): el filo blanco y duro por FUERA (el lado de
# '_lado'), acero, el velo rojo oscuro y nada; fina en la cola y gorda hasta la misma cabeza, donde se corta en seco.
func _mordisco(ci: CanvasItem, s_cola: float, s_cabeza: float, grueso: float, alfa: float) -> void:
	if alfa <= 0.0 or s_cabeza - s_cola < 0.01:
		return
	var n: int = 14
	# A tamaño de cuerpo el velo rojo del Hachazo brutal no se ve sobre el suelo oscuro (salia una rayita blanca): aqui
	# manda el acero y el rojo es solo la cola de dentro.
	var fr: Array = [0.0, 0.22, 0.52, 0.8, 1.0]
	var cols: Array = [BLANCO, BLANCO.lerp(ACERO, 0.5), ACERO, SANGRE_VIVA, SANGRE]
	var al: Array = [1.0, 0.95, 0.85, 0.55, 0.0]
	var pts: Array = []
	for i in n + 1:
		pts.append(_en_camino(lerpf(s_cola, s_cabeza, float(i) / float(n))))
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		var tg: Vector2 = (p1 - p0).normalized() if p1.distance_squared_to(p0) > 0.0001 else Vector2.DOWN
		# Hacia DENTRO de la curva (hacia donde se difumina): del lado contrario al de por donde viene.
		var dentro: Vector2 = tg.orthogonal() * (1.0 if _lado > 0.0 else -1.0)
		var g0: float = grueso * (0.12 + 0.88 * pow(s0, 1.4))
		var g1: float = grueso * (0.12 + 0.88 * pow(s1, 1.4))
		var l0: float = alfa * (0.3 + 0.7 * s0)
		var l1: float = alfa * (0.3 + 0.7 * s1)
		for k in fr.size() - 1:
			var p00: Vector2 = p0 + dentro * g0 * float(fr[k])
			var p10: Vector2 = p1 + dentro * g1 * float(fr[k])
			var p01: Vector2 = p0 + dentro * g0 * float(fr[k + 1])
			var p11: Vector2 = p1 + dentro * g1 * float(fr[k + 1])
			var c00 := Color(cols[k], l0 * float(al[k]))
			var c10 := Color(cols[k], l1 * float(al[k]))
			var c01 := Color(cols[k + 1], l0 * float(al[k + 1]))
			var c11 := Color(cols[k + 1], l1 * float(al[k + 1]))
			ci.draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())


func _hachazo(capa: Node2D) -> void:
	# _t va de -T_BAJA (arriba) a 0 (clavada).
	var tb: float = _t + T_BAJA
	if tb < 0.0:
		return
	var s: float = clampf(tb / T_BAJA, 0.0, 1.0)
	# Lento al arrancar y rapidisimo al final (como el Hachazo brutal): s^2.
	var cabeza: float = s * s
	var tc: float = _t
	var apaga: float = clampf((tc - T_CLAVADO) / T_APAGA, 0.0, 1.0) if tc > 0.0 else 0.0
	var recoge: float = clampf(tc / T_CLAVADO, 0.0, 1.0) if tc > 0.0 else 0.0
	var cola: float = maxf(cabeza - 0.85 * (1.0 - 0.6 * recoge), 0.0)
	var grueso: float = clampf(_caja.size.x * 1.6, 18.0, 30.0) * (0.85 if _fallo else 1.0)
	if capa == _delante and apaga < 1.0:
		_mordisco(capa, cola, cabeza, grueso, 0.95 * (1.0 - apaga))
	if tc < 0.0:
		return
	if _fallo:
		# CLAVADA EN EL SUELO: las grietas cortas, el polvo y las piedrecillas.
		var alfa_s: float = 1.0 - clampf((tc - 0.35) / 0.3, 0.0, 1.0)
		if capa == _suelo:
			var k: float = clampf(tc / 0.08, 0.0, 1.0)
			for g in _grietas:
				var a: float = float(g["a"])
				_grieta(capa, _imp, Vector2(cos(a), sin(a) * K), float(g["l"]) * k, 2.2, alfa_s, float(g["q"]))
			for b in _bocanadas:
				var tb2: float = tc - float(b["t0"])
				if tb2 < 0.0 or tb2 > 0.5:
					continue
				var kb: float = tb2 / 0.5
				_nube(capa, _imp + Vector2(float(b["x"]), 0.0) + Vector2(b["v"]) * sqrt(kb) * 1.4,
					float(b["tam"]) * (0.6 + 0.8 * kb), Color(POLVO, 0.5 * (1.0 - kb)))
		elif capa == _delante:
			_esquirlas(capa, _imp, tc, _imp.y + 3.0, 0.45)
		return
	# EL DESTELLO SECO al clavarse (pequeño y corto: muerde, no brilla) y unas chispas de acero que saltan hacia atras.
	if capa == _brillo:
		var pulso: float = exp(-tc / 0.05)
		BarridoAire.destello(capa, _imp, 15.0 * (0.35 + 0.8 * pulso), Color(BLANCO, (1.0 - apaga) * (0.4 + 0.6 * pulso)),
			0.3 * _lado)
		for g in _piezas:
			if tc > 0.18:
				break
			var u: float = tc / 0.18
			var d := Vector2(_lado, -0.6).normalized().rotated(float(g["a"]) * 0.6)
			var p: Vector2 = _imp + d * float(g["v"]) * tc
			BarridoAire.cometa(capa, p - d * float(g["l"]), p, 1.6, Color(BLANCO, 0.85 * (1.0 - u)))


# ------------------------------------------------------------
#  LA CORNADA (el enganche)
# ------------------------------------------------------------
func _cornada(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var suelo_y: float = _pies.y + 2.0
	if capa == _brillo:
		# EL FOGONAZO ROMO: un halo gordo y seis puntas CORTAS y anchas (es un testarazo, no un corte).
		var pulso: float = exp(-_t / 0.07)
		var r: float = clampf(_caja.size.x * 0.6, 10.0, 24.0) * (0.55 + 0.6 * (1.0 - pulso))
		var alfa: float = 1.0 - clampf((_t - 0.06) / 0.18, 0.0, 1.0)
		if alfa > 0.0:
			BarridoAire.brillo(capa, _imp, r * 1.3, Color(1.0, 0.92, 0.8, 0.55 * alfa))
			var giro: float = _dir.angle()
			var transp := Color(BLANCO, 0.0)
			for k in 6:
				var a: float = giro + TAU * float(k) / 6.0 + 0.25
				var d := Vector2(cos(a), sin(a) * 0.8)
				var nn: Vector2 = d.orthogonal() * r * 0.32
				capa.draw_primitive(PackedVector2Array([_imp + nn, _imp + d * r, _imp - nn]),
					PackedColorArray([Color(BLANCO, 0.9 * alfa), transp, Color(BLANCO, 0.9 * alfa)]), PackedVector2Array())
			BarridoAire.brillo(capa, _imp, r * 0.45, Color(1, 1, 1, alfa))
	elif capa == _suelo:
		# El polvo de sus pies, empujado hacia donde le lleva.
		for b in _bocanadas:
			var tb: float = _t - float(b["t0"])
			if tb < 0.0 or tb > 0.55:
				continue
			var kb: float = tb / 0.55
			_nube(capa, _pies + Vector2(float(b["x"]) * _caja.size.x, 0.0) + Vector2(b["v"]) * sqrt(kb),
				float(b["tam"]) * (0.6 + 0.9 * kb), Color(POLVO, 0.5 * (1.0 - kb)))
	elif capa == _delante:
		_esquirlas(capa, _imp, _t, suelo_y, 0.55)


# ------------------------------------------------------------
#  EL SISMO (a quien le pilla el Pisoton): polvo que le sube de los pies
# ------------------------------------------------------------
func _sismo(capa: Node2D) -> void:
	if _t < 0.0 or capa != _suelo:
		return
	for b in _bocanadas:
		var tb: float = _t - float(b["t0"])
		if tb < 0.0 or tb > 0.65:
			continue
		var kb: float = tb / 0.65
		_nube(capa, _pies + Vector2(float(b["x"]) * maxf(_caja.size.x, 10.0), 0.0) + Vector2(b["v"]) * sqrt(kb),
			float(b["tam"]) * (0.6 + 0.8 * kb), Color(POLVO, 0.45 * (1.0 - kb)))


# ------------------------------------------------------------
#  SOBRE EL: escarbar (cargando la Cornada) y la rabia (mientras dure)
# ------------------------------------------------------------
func _morro(agachado: bool) -> Vector2:
	var lat: Vector2 = Vector2(_dir.x, _dir.y * K)
	return Vector2(_caja.get_center().x, _caja.position.y + _caja.size.y * (MORRO_ALTO_AGACHADO if agachado else MORRO_ALTO)) \
		+ lat * _caja.size.x * MORRO_DELANTE


# Una tanda: escarbando, la pezuña de atras echa terrones y polvo hacia atras (y cada dos, vaho); rabioso, dos bocanadas
# cortas de vaho por el morro.
func _soltar_tanda() -> void:
	if modo == Modo.ESCARBA:
		_siguiente = _t + _rng.randf_range(0.42, 0.55)
		var atras: Vector2 = -Vector2(_dir.x, _dir.y * K)
		var lat: Vector2 = Vector2(-_dir.y, _dir.x * K) * _rng.randf_range(-0.25, 0.25) * _caja.size.x
		var pezuna: Vector2 = _pies + atras * _caja.size.x * 0.16 + lat
		# GORDO (en la 1a hoja casi no se veia): terrones grandes y una buena nube.
		for i in 6:
			var q: Dictionary = _esquirla(_rng, atras, 0.6)
			q["t0"] = _t + _rng.randf_range(0.0, 0.06)
			q["desde"] = pezuna
			q["tam"] = float(q["tam"]) * 2.1
			_piezas.append(q)
		for i in 4:
			_bocanadas.append({"t0": _t + _rng.randf_range(0.0, 0.08), "p": pezuna + Vector2(_rng.randf_range(-5.0, 5.0), 0.0),
				"v": atras * _rng.randf_range(16.0, 28.0) + Vector2(0.0, -_rng.randf_range(6.0, 12.0)), "tam": _rng.randf_range(6.0, 9.0),
				"vaho": false})
		# El vaho, una tanda si y otra no.
		_par = not _par
		if _par:
			_echar_vaho(true, 2)
	else:
		_siguiente = _t + _rng.randf_range(1.3, 2.1)
		_echar_vaho(false, 2)
	# Lo viejo fuera.
	var vivos: Array = []
	for b in _bocanadas:
		if _t - float(b["t0"]) < 1.2:
			vivos.append(b)
	_bocanadas = vivos
	var siguen: Array = []
	for q in _piezas:
		if _t - float(q["t0"]) < 0.8:
			siguen.append(q)
	_piezas = siguen


# Dos (o 'n') bocanadas por el morro, hacia delante y arriba, una detras de otra.
func _echar_vaho(agachado: bool, n: int) -> void:
	var m: Vector2 = _morro(agachado)
	var fuera: Vector2 = Vector2(_dir.x, _dir.y * K)
	for i in n:
		_bocanadas.append({"t0": _t + float(i) * 0.16, "p": m, "v": fuera * _rng.randf_range(22.0, 32.0)
			+ Vector2(_rng.randf_range(-3.0, 3.0), -_rng.randf_range(10.0, 16.0)), "tam": _rng.randf_range(5.5, 7.5), "vaho": true})


func _de_estado(capa: Node2D) -> void:
	var queda: float = _queda()
	for b in _bocanadas:
		var tb: float = _t - float(b["t0"])
		var vida: float = 0.9 if bool(b["vaho"]) else 0.55
		if tb < 0.0 or tb > vida:
			continue
		var kb: float = tb / vida
		var p: Vector2 = Vector2(b["p"]) + Vector2(b["v"]) * (1.0 - pow(1.0 - kb, 2.0)) * vida
		if bool(b["vaho"]):
			if capa == _delante:
				_nube(capa, p, float(b["tam"]) * (0.8 + 1.5 * kb), Color(VAHO, 0.7 * (1.0 - kb) * queda))
		elif capa == _suelo:
			_nube(capa, p, float(b["tam"]) * (0.7 + 1.1 * kb), Color(POLVO, 0.75 * (1.0 - kb) * queda))
	if capa != _delante:
		return
	for q in _piezas:
		var tq: float = _t - float(q["t0"])
		if tq < 0.0 or tq > 0.6:
			continue
		var desde: Vector2 = q["desde"]
		var p: Vector2 = desde + Vector2(q["v"]) * tq + Vector2(0.0, 0.5 * GRAVEDAD * tq * tq)
		p.y = minf(p.y, desde.y + 4.0)
		_piedra(capa, p, q["forma"], float(q["tam"]), float(q["gira"]) * tq, (1.0 - clampf((tq - 0.4) / 0.2, 0.0, 1.0)) * queda,
			TERRON)


# ------------------------------------------------------------
#  LA RABIA (una vez): el cuerno sale volando, el fogonazo rojizo y el vaho
# ------------------------------------------------------------
var _cuerno_desde: Vector2 = Vector2.ZERO
var _cuerno_v: Vector2 = Vector2.ZERO
var _cuerno_suelo: float = 0.0
var _cuerno_gira: float = 0.0
var _cuerno_lado: float = 1.0
var _t_vuela: float = T_CUERNO_VUELA

func _preparar_rabia() -> void:
	# EL CUERNO IZQUIERDO (el que se parte en su sprite): arriba en la cabeza, del lado de su izquierda (la perpendicular
	# en el suelo, achatada); de espaldas o de frente sale por un lado igual.
	var izq: Vector2 = _dir.rotated(-PI * 0.5)
	var lat: Vector2 = Vector2(izq.x, izq.y * K)
	if lat.length_squared() < 0.05:
		lat = Vector2(1.0, 0.0)
	lat = lat.normalized()
	_cuerno_lado = 1.0 if lat.x >= 0.0 else -1.0
	_cuerno_desde = Vector2(_caja.get_center().x, _caja.position.y + _caja.size.y * 0.06) + lat * _caja.size.x * 0.22
	# Sale hacia fuera y arriba y cae a un lado de sus pies.
	_cuerno_v = lat * _rng.randf_range(24.0, 32.0) + Vector2(0.0, -_rng.randf_range(85.0, 100.0))
	_cuerno_suelo = _pies.y + _rng.randf_range(4.0, 10.0)
	# Lo que vuela: hasta que la parabola llega al suelo (a sus pies). Con un tiempo fijo se quedaba en el aire.
	var dy: float = _cuerno_suelo - _cuerno_desde.y
	var g2: float = 0.5 * GRAVEDAD
	_t_vuela = (-_cuerno_v.y + sqrt(_cuerno_v.y * _cuerno_v.y + 4.0 * g2 * maxf(dy, 0.0))) / (2.0 * g2)
	_cuerno_gira = _cuerno_lado * TAU * _rng.randf_range(1.6, 2.2) / _t_vuela
	for i in 6:
		var q: Dictionary = _esquirla(_rng, lat, 0.55)
		q["tam"] = float(q["tam"]) * 0.7
		_piezas.append(q)
	_echar_vaho(false, 2)
	for b in _bocanadas:
		b["t0"] = float(b["t0"]) + 0.12


# Donde va el cuerno a los 'tc' segundos (vuela en parabola y se queda en el suelo).
func _cuerno_en(tc: float) -> Vector2:
	var tv: float = minf(tc, _t_vuela)
	var p: Vector2 = _cuerno_desde + _cuerno_v * tv + Vector2(0.0, 0.5 * GRAVEDAD * tv * tv)
	return Vector2(p.x, minf(p.y, _cuerno_suelo))


# EL CUERNO: una media luna de hueso que se afila hacia la punta, con su borde oscuro y el muñon astillado.
func _dibujar_cuerno(ci: CanvasItem, p: Vector2, giro: float, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var largo: float = clampf(_caja.size.x * 0.22, 11.0, 18.0)
	var ancho: float = largo * 0.32
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	var n: int = 7
	# La curva: de la base (ancha) a la punta, doblandose hacia arriba.
	for i in n + 1:
		var u: float = float(i) / float(n)
		var c: Vector2 = Vector2(u * largo - largo * 0.5, -sin(u * PI * 0.5) * largo * 0.45)
		var w: float = ancho * (1.0 - u * 0.92)
		fuera.append(p + (c + Vector2(0.0, w + 0.8)).rotated(giro))
		dentro.append(p + (c + Vector2(0.0, w)).rotated(giro))
	for i in range(n, -1, -1):
		var u: float = float(i) / float(n)
		var c: Vector2 = Vector2(u * largo - largo * 0.5, -sin(u * PI * 0.5) * largo * 0.45)
		var w: float = ancho * (1.0 - u * 0.92)
		fuera.append(p + (c - Vector2(0.0, w + 0.8)).rotated(giro))
		dentro.append(p + (c - Vector2(0.0, w)).rotated(giro))
	Poligono.relleno(ci, fuera, Color(LOSA_BORDE, alfa))
	Poligono.relleno(ci, dentro, Color(HUESO, alfa))
	# La sombra de abajo y el muñon astillado de la base.
	var base: Vector2 = p + Vector2(-largo * 0.5, 0.0).rotated(giro)
	Poligono.relleno(ci, PackedVector2Array([base + Vector2(0.0, -ancho).rotated(giro),
		base + Vector2(ancho * 0.6, -ancho * 0.3).rotated(giro), base + Vector2(ancho * 0.2, 0.1).rotated(giro),
		base + Vector2(ancho * 0.7, ancho * 0.5).rotated(giro), base + Vector2(0.0, ancho).rotated(giro)]),
		Color(HUESO_OSCURO, alfa))


func _rabia(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var tc: float = _t
	var en_suelo: bool = tc >= _t_vuela
	var alfa_c: float = 1.0 - clampf((tc - _t_vuela - T_CUERNO_SUELO) / 0.6, 0.0, 1.0)
	var p_c: Vector2 = _cuerno_en(tc)
	var giro: float = _cuerno_gira * minf(tc, _t_vuela) + (0.0 if _cuerno_lado > 0.0 else PI)
	# El cuerno: volando, por delante de todo; en el suelo, en la capa del suelo (y su sombrita).
	if en_suelo and capa == _suelo:
		_nube(capa, p_c + Vector2(0.0, 2.0), 7.0, Color(0, 0, 0, 0.35 * alfa_c))
		_dibujar_cuerno(capa, p_c, giro, alfa_c)
		# El golpecito de polvo al caer.
		var tp: float = tc - _t_vuela
		if tp < 0.4:
			for i in 4:
				var a: float = TAU * float(i) / 4.0 + 0.4
				_nube(capa, p_c + Vector2(cos(a), sin(a) * K) * (3.0 + 10.0 * tp), 3.5 + 6.0 * tp, Color(POLVO, 0.5 * (1.0 - tp / 0.4)))
	elif not en_suelo and capa == _delante:
		# Su sombra en el suelo no (va en el aire alto); el cuerno girando.
		_dibujar_cuerno(capa, p_c, giro, 1.0)
	if capa == _delante:
		# Las astillas al partirse.
		_esquirlas(capa, _cuerno_desde, tc, _pies.y + 4.0, 0.5, HUESO_OSCURO)
		# El vaho (con un pelo de rojo).
		for b in _bocanadas:
			var tb: float = tc - float(b["t0"])
			if tb < 0.0 or tb > 0.9:
				continue
			var kb: float = tb / 0.9
			var p: Vector2 = Vector2(b["p"]) + Vector2(b["v"]) * (1.0 - pow(1.0 - kb, 2.0)) * 0.9
			_nube(capa, p, float(b["tam"]) * (0.9 + 1.6 * kb), Color(VAHO.lerp(ROJIZO, 0.15), 0.7 * (1.0 - kb)))
	if capa == _brillo:
		# LA CHISPA DE HUESO al partirse.
		var pulso: float = exp(-tc / 0.06)
		if tc < 0.3:
			BarridoAire.destello(capa, _cuerno_desde, 13.0 * (0.4 + 0.8 * pulso), Color(1.0, 0.95, 0.85, 1.0 - tc / 0.3), 0.4)
		# EL FOGONAZO ROJIZO: le sube un resplandor rojo por el cuerpo y se apaga despacio.
		var kr: float = clampf(tc / 0.5, 0.0, 1.0)
		var alfa_r: float = sin(kr * PI) * (1.0 if tc < 0.5 else 0.0)
		if alfa_r > 0.0:
			var c: Vector2 = _caja.get_center()
			BarridoAire.brillo(capa, c, maxf(_caja.size.x, _caja.size.y) * (0.5 + 0.2 * kr), Color(ROJIZO, 0.3 * alfa_r))
			BarridoAire.brillo(capa, Vector2(c.x, _pies.y), _caja.size.x * (0.6 + 0.9 * kr), Color(ROJIZO, 0.25 * alfa_r))


# ------------------------------------------------------------
#  POR EL SUELO: EL PISOTON (crater, grietas, dos anillos de losas y polvo)
# ------------------------------------------------------------
func _preparar_pisoton() -> void:
	# El crater: bajo la pezuña que cae (un poco por delante de sus pies), irregular.
	# Delante de sus pies (con 6 px quedaba tapado bajo su cuerpo).
	var c: Vector2 = _o + Vector2(_dir.x, _dir.y * K) * 20.0
	_imp = c
	var r_c: float = clampf(_radio * 0.19, 9.0, 16.0)
	for i in 11:
		var a: float = TAU * float(i) / 11.0
		_crater.append(c + Vector2(cos(a), sin(a) * K) * r_c * _rng.randf_range(0.78, 1.12))
	# Las losas: DOS anillos (sus dos tramos), cada una con su forma y su tamaño (menguando hacia fuera).
	for anillo in 2:
		var r: float = _radio * (float(anillo) + 0.6) / 2.0
		var n_l: int = 9 + anillo * 6
		var tam: float = lerpf(19.0, 12.0, float(anillo))
		for i in n_l:
			var a2: float = TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / float(n_l)
			var q: Dictionary = _esquirla(_rng, Vector2.ZERO, 0.0)
			# En CIRCULO, como su huella (huellas-suelo-circulos).
			q["p"] = Vector2(cos(a2), sin(a2)) * r * _rng.randf_range(0.92, 1.06)
			q["tam"] = tam * _rng.randf_range(0.8, 1.15)
			q["anillo"] = anillo
			q["alza"] = tam * _rng.randf_range(0.6, 1.0)
			_anillos.append(q)
	# Las grietas: 8 desde el crater hasta casi el borde.
	for i in 8:
		_grietas.append({"a": TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / 8.0, "l": _rng.randf_range(0.7, 0.95),
			"q": _rng.randf_range(-0.14, 0.14)})
	# Piedrecillas que saltan del crater.
	for i in 9:
		_piezas.append(_esquirla(_rng, Vector2.ZERO, 0.75))


# UNA LOSA de suelo levantada: borde, cara y la tapa CLARA de arriba.
func _losa(ci: CanvasItem, p: Vector2, forma_l: PackedVector2Array, tam: float, giro: float, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var fuera := PackedVector2Array()
	var cara := PackedVector2Array()
	var tapa := PackedVector2Array()
	for q in forma_l:
		var r: Vector2 = q.rotated(giro)
		fuera.append(p + Vector2(r.x, r.y * 0.7) * (tam + 1.0) + Vector2(0.0, 1.5))
		cara.append(p + Vector2(r.x, r.y * 0.7) * tam + Vector2(0.0, 1.5))
		tapa.append(p + Vector2(r.x, r.y * 0.7) * tam * 0.85)
	Poligono.relleno(ci, fuera, Color(LOSA_BORDE, alfa))
	Poligono.relleno(ci, cara, Color(LOSA_CARA, alfa))
	Poligono.relleno(ci, tapa, Color(LOSA_TAPA, alfa))


func _pisoton(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var apaga: float = clampf((_t - (T_PISOTON + 0.55)) / 0.4, 0.0, 1.0)
	var alfa: float = 1.0 - apaga
	if capa == _suelo:
		# EL CRATER: el hundido oscuro con su labio, que aparece de golpe.
		var hund := PackedVector2Array()
		for q in _crater:
			hund.append(_imp + (q - _imp) * 0.62)
		Poligono.relleno(capa, _crater, Color(LOSA_CARA, 0.9 * alfa))
		Poligono.relleno(capa, hund, Color(LOSA_BORDE, 0.9 * alfa))
		# LAS GRIETAS corren del crater al borde en lo que tarda el frente.
		var k: float = clampf(_t / T_PISOTON, 0.0, 1.0)
		var r_c: float = clampf(_radio * 0.19, 9.0, 16.0)
		for g in _grietas:
			var a: float = float(g["a"])
			var d := Vector2(cos(a), sin(a))
			_grieta(capa, _imp + Vector2(d.x, d.y * K) * r_c * 0.8, d, (_radio * float(g["l"]) - r_c) * k, 3.4, alfa,
				float(g["q"]))
		# LAS LOSAS (en la capa del suelo, bajo los cuerpos): cada anillo salta cuando le llega el frente.
		for g in _anillos:
			var t_llega: float = (float(g["anillo"]) + 0.6) / 2.0 * T_PISOTON
			var tg: float = _t - t_llega
			if tg < 0.0:
				continue
			var salto: float = clampf(tg / 0.22, 0.0, 1.0)
			var h: float = float(g["alza"]) * sin(salto * PI) + float(g["alza"]) * 0.25 * (1.0 - salto)
			_losa(capa, _o + Vector2(g["p"]) - Vector2(0.0, h * (1.0 - apaga)), g["forma"], float(g["tam"]),
				float(g["gira"]) * 0.03 * salto, alfa)
		# EL POLVO: un golpe gordo en el crater y, al llegar el frente, en el borde.
		if _t < 0.6:
			var kp0: float = _t / 0.6
			for i in 6:
				var a3: float = TAU * float(i) / 6.0 + 0.3
				_nube(capa, _imp + Vector2(cos(a3), sin(a3) * K) * (8.0 + 28.0 * sqrt(kp0)) - Vector2(0.0, 8.0 * kp0),
					13.0 * (0.6 + 0.9 * kp0), Color(POLVO, 0.65 * (1.0 - kp0)))
		if _t > T_PISOTON * 0.8:
			var kp: float = clampf((_t - T_PISOTON * 0.8) / 0.5, 0.0, 1.0)
			for i in 12:
				var a4: float = TAU * float(i) / 12.0
				_nube(capa, _o + Vector2(cos(a4), sin(a4)) * _radio * (0.95 + 0.1 * kp), 11.0 * (0.6 + 0.8 * kp),
					Color(POLVO, 0.5 * (1.0 - kp)))
	elif capa == _delante:
		_esquirlas(capa, _imp, _t, _imp.y + 6.0, 0.6)


# ------------------------------------------------------------
#  POR EL SUELO: EL BRAMIDO (vaho del morro y tres anillos graves)
# ------------------------------------------------------------
func _preparar_bramido() -> void:
	# Las ondulaciones de cada anillo (un bramido no es un circulo de compas): fase y numero de bultos propios.
	for k in 3:
		_anillos.append({"fase": _rng.randf_range(0.0, TAU), "n": 5 + _rng.randi() % 3, "amp": _rng.randf_range(0.03, 0.05)})
	# El polvo que levanta cada anillo al pasar.
	for i in 16:
		_piezas.append({"a": TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / 16.0, "u": _rng.randf_range(0.35, 0.95),
			"tam": _rng.randf_range(5.0, 8.0)})
	# El chorro de vaho: bocanadas que salen del morro, hacia delante y arriba, una detras de otra.
	var m: Vector2 = _o + Vector2(_dir.x, _dir.y * K) * 12.0 - Vector2(0.0, ALTO_MORRO_BRAMIDO)
	var fuera: Vector2 = Vector2(_dir.x, _dir.y * K)
	for i in 9:
		_bocanadas.append({"t0": -0.04 + float(i) * 0.045, "p": m,
			"v": fuera * _rng.randf_range(34.0, 52.0) + Vector2(_rng.randf_range(-8.0, 8.0), -_rng.randf_range(22.0, 34.0)),
			"tam": _rng.randf_range(8.0, 11.0)})


func _bramido(capa: Node2D) -> void:
	if _t < -0.05:
		return
	if capa == _delante:
		# EL VAHO del morro (con un pelo de su pardo).
		for b in _bocanadas:
			var tb: float = _t - float(b["t0"])
			if tb < 0.0 or tb > 0.8:
				continue
			var kb: float = tb / 0.8
			var p: Vector2 = Vector2(b["p"]) + Vector2(b["v"]) * (1.0 - pow(1.0 - kb, 2.0)) * 0.8
			_nube(capa, p, float(b["tam"]) * (0.8 + 1.8 * kb), Color(VAHO.lerp(PARDO, 0.2), 0.75 * (1.0 - kb)))
		# LOS ANILLOS GRAVES: el filo duro y claro por fuera que se difumina hacia dentro, gordos, lentos, uno tras otro
		# (cada uno mas flojo), ondulados.
		for k in 3:
			var tk: float = _t - float(k) * 0.2
			if tk < 0.0:
				continue
			var prog: float = clampf(tk / T_BRAMIDO, 0.0, 1.0)
			var avance: float = 1.0 - pow(1.0 - prog, 1.6)
			var rf: float = _radio * avance
			var fin: float = clampf((tk - T_BRAMIDO) / 0.25, 0.0, 1.0)
			var alfa: float = (0.6 - 0.15 * float(k)) * (1.0 - 0.45 * prog) * (1.0 - fin)
			if alfa <= 0.0 or rf < 5.0:
				continue
			var grueso: float = lerpf(7.0, 20.0, prog)
			var an: Dictionary = _anillos[k]
			var n: int = 40
			for i in n:
				var a0: float = TAU * float(i) / float(n)
				var a1: float = TAU * float(i + 1) / float(n)
				var r0: float = rf * (1.0 + float(an["amp"]) * sin(a0 * float(an["n"]) + float(an["fase"]) + tk * 3.0))
				var r1: float = rf * (1.0 + float(an["amp"]) * sin(a1 * float(an["n"]) + float(an["fase"]) + tk * 3.0))
				var f0: Vector2 = _o + Vector2(cos(a0), sin(a0)) * r0
				var f1: Vector2 = _o + Vector2(cos(a1), sin(a1)) * r1
				var d0: Vector2 = _o + Vector2(cos(a0), sin(a0)) * maxf(r0 - grueso, 0.0)
				var d1: Vector2 = _o + Vector2(cos(a1), sin(a1)) * maxf(r1 - grueso, 0.0)
				var c := Color(PARDO.lerp(Color.WHITE, 0.25), alfa)
				var transp := Color(PARDO, 0.0)
				capa.draw_primitive(PackedVector2Array([f0, f1, d1]), PackedColorArray([c, c, transp]), PackedVector2Array())
				capa.draw_primitive(PackedVector2Array([f0, d1, d0]), PackedColorArray([c, transp, transp]), PackedVector2Array())
	elif capa == _suelo:
		# EL POLVO que levanta el primer anillo al pasar.
		for g in _piezas:
			var t_llega: float = _llega_bramido(float(g["u"]))
			var tg: float = _t - t_llega
			if tg < 0.0 or tg > 0.6:
				continue
			var kg: float = tg / 0.6
			var a: float = float(g["a"])
			var p: Vector2 = _o + Vector2(cos(a), sin(a)) * _radio * float(g["u"]) + Vector2(cos(a), sin(a)) * 8.0 * kg \
				- Vector2(0.0, 5.0 * kg)
			_nube(capa, p, float(g["tam"]) * (0.6 + 0.8 * kg), Color(POLVO, 0.4 * (1.0 - kg)))
