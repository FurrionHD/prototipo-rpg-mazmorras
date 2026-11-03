# ============================================================
#  trent_aire.gd  (class_name TrentAire)
#  LOS EFECTOS DE LOS MUTANTES DEL TRENT en el mapa (02/11/2026: el Tocon ambarino y el Espantajo; ver la memoria
#  trent-mutante). Los del Espantajo van en el lenguaje de la oscuridad del juego (formas negras rellenas, borde violeta
#  claro, luz blanco-violeta); los del Tocon ambarino, en ambar (cuerpo dorado, filo oscuro, brillo claro).
#  LO QUE ELIGIO EL JEFE: el GEISER B (nube) y el CHUPAR A (hilos); las otras versiones se quedan para la hoja de
#  versiones (tools/ver_efectos_trent). Y ademas (paso 5, 03/11):
#    RESINA     (se queda) el pegote de ambar alrededor de los pies de un Resinado, como un cepo; al soltarle se
#               agrieta y cae a trozos.
#    ESTALLIDO  se le rompe la costra al Tocon: los grumos de ambar revientan hacia fuera (como el capullo de su
#               evolucion) y caen alrededor.
#    HUMO       (se queda) la Savia negra: humo violeta que sube del cuerpo, mas denso cuantas mas cargas.
#    CARGA      (se queda) el Geiser cargando: la grieta de la espalda brilla y late.
#    SECO       (se queda) cuanto mas seco mas pega: grietas violeta que laten por el cuerpo, mas cuantos mas tramos.
#    GOTERON    la Resina y la Savia negra: el pegote vuela en parabola desde su boca y revienta al caer.
#  Las versiones del Espantajo:
#    GEISER  sale por la grieta de su espalda y cae sobre un circulo:
#            A  CHORRO y GOTAS gordas que caen con salpicadura
#            B  el chorro forma una NUBE negra encima del area que LLUEVE
#            C  el chorro se abre en BRAZOS de tinta que caen como latigos sobre el area
#    CHUPAR  le saca vida a un enraizado y se la lleva a sus pies:
#            A  HILOS violeta que reptan por el suelo y BOLITAS de luz que suben por ellos
#            B  un REMOLINO sobre la victima y MOTAS que vuelan en espiral hasta el
#            C  una RAIZ negra que asoma entre los dos y LATE: pulsos de luz que viajan hasta el
#  A LA ESCALA DEL ESPANTAJO (casi 1,5 veces el trent): a la del jabali el chorro y los hilos eran rayas finas.
#  NADA DE LINEAS (efectos-sin-lineas): todo relleno. NADA se queda en el suelo: las manchas se apagan. Coordenadas de
#  MUNDO.
# ============================================================
extends Node2D
class_name TrentAire

enum Modo { GEISER, CHUPAR, RESINA, ESTALLIDO, HUMO, CARGA, SECO, GOTERON }

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80

const NEGRO := Color(0.05, 0.03, 0.07)
const SAVIA := Color(0.12, 0.07, 0.16)
const BORDE := Color(0.55, 0.42, 0.78)       # el filo claro de la savia (la pincelada)
const VIOLETA := Color(0.62, 0.40, 0.95)
const LUZ := Color(0.92, 0.86, 1.0)
const AMBAR := Color(0.95, 0.62, 0.15)
const AMBAR_OSCURO := Color(0.45, 0.22, 0.04)
const AMBAR_CLARO := Color(1.0, 0.9, 0.55)

const T_SALE := 0.28        # el chorro sale cuando se arquea (su 'geiser': 8 a 10, el arqueo en el 0,35)
const T_GEISER := 1.7
const T_CHUPAR := 1.3
const T_SECA := 0.7         # lo que tarda en irse lo que se queda (la resina cae a trozos, el humo se apaga)
const T_ESTALLIDO := 1.1
const T_GOTERON := 0.4      # lo que vuela el pegote hasta caer (= retraso del golpe)
const ALTO_GRIETA := 125.0  # la grieta de la espalda del Espantajo sobre el fondo de su dibujo (bajo la copa)
# Y SOBRE EL SITIO DE SU NODO (pies_de: el centro de su lienzo, 90 px por encima del fondo del dibujo; medido el 03/11
# con CombatTactico.rect_dibujo): de donde salen el chorro del Geiser y los goterones en el juego (la huella solo sabe eso).
const GRIETA_NODO := 35.0
const BOCA_TOCON := 25.0
const BOCA_ESPANTAJO := 85.0

var modo: int = Modo.GEISER
var version: int = 0
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _o: Vector2 = Vector2.ZERO        # de donde sale (la grieta de la espalda / la victima)
var _c: Vector2 = Vector2.ZERO        # el centro del area (geiser) / sus pies (chupar)
var _r: float = 45.0
var _piezas: Array = []
var nivel: int = 1                    # HUMO: las cargas; SECO: los tramos
var ambar: bool = true                # GOTERON: resina (true) o savia negra
var _secando: float = -1.0            # lo que se queda: desde cuando se esta yendo (-1 = sigue)
var _caja: Rect2 = Rect2()            # lo que se queda: el cuerpo al que va pegado
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  CREARLOS
# ------------------------------------------------------------
# GEISER: de 'grieta' (su espalda) al circulo de centro 'centro' y radio 'r'. 'version' 0, 1, 2 = A, B, C.
static func geiser(padre: Node, grieta: Vector2, centro: Vector2, r: float, version_: int, semilla: int) -> TrentAire:
	var e := _nuevo(Modo.GEISER, version_, semilla)
	e._o = grieta
	e._c = centro
	e._r = maxf(r, 10.0)
	e._preparar()
	e._montar(padre)
	return e


# CHUPAR: de 'victima' (sus pies) a 'pies' (los del Espantajo). 'version' 0, 1, 2 = A, B, C.
static func chupar(padre: Node, victima: Vector2, pies: Vector2, version_: int, semilla: int) -> TrentAire:
	var e := _nuevo(Modo.CHUPAR, version_, semilla)
	e._o = victima
	e._c = pies
	e._preparar()
	e._montar(padre)
	return e


# EN EL JUEGO, por la huella (SueloRoto.Tipo.TRENT_*): el GEISER (siempre la nube, la B) y el GOTERON de la Resina
# ('m' = RESINA) o de la Savia negra ('m' = HUMO, la savia). De donde sale lo da el 'ancho' del circulo (lo lejos que
# esta quien lo lanza: CombatTactico.desde_quien_lanza). 'espera' = hasta el golpe de su animacion (el arqueo del
# geiser, el escupitajo): ahi empieza a subir el chorro o a volar el pegote.
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> TrentAire:
	if padre == null or f == null:
		return null
	var dir: Vector2 = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	var pies: Vector2 = f.centro - dir * f.ancho if f.ancho > 1.0 else f.centro
	var e: TrentAire
	if m == Modo.GEISER:
		e = _nuevo(Modo.GEISER, 1, semilla)
		e._o = pies + Vector2(-signf(dir.x) * 10.0, -GRIETA_NODO)
		e._t = T_SALE - espera * e._ritmo
	else:
		e = _nuevo(Modo.GOTERON, 0, semilla)
		e.ambar = m == Modo.RESINA
		e._o = pies + Vector2(dir.x * 14.0, -(BOCA_TOCON if e.ambar else BOCA_ESPANTAJO))
		e._t = -espera * e._ritmo
	e._c = f.centro
	e._r = maxf(f.radio, 10.0)
	e._preparar()
	e._montar(padre)
	return e


# Cuando le llega el golpe (segundos desde el golpe de su animacion): el pegote, al caer; la lluvia del geiser, cuando
# las gotas de la nube empiezan a tocar el suelo.
static func retraso(m: int) -> float:
	return 0.75 if m == Modo.GEISER else T_GOTERON


# LO QUE SE QUEDA PEGADO A ALGUIEN (RESINA, HUMO, CARGA, SECO): va sobre 'caja' (su cuerpo; los pies, abajo en el
# medio), la sigue con seguir() y se va con secar(). 'nivel_' = las cargas del humo o los tramos de lo seco.
static func pegado(padre: Node, m: int, caja: Rect2, nivel_: int, semilla: int) -> TrentAire:
	if padre == null:
		return null
	var e := _nuevo(m, 0, semilla)
	e.nivel = maxi(nivel_, 1)
	e._caja = caja
	e._preparar()
	e._montar(padre)
	return e


# EL ESTALLIDO de la costra, en el cuerpo 'caja' del Tocon.
static func estallido(padre: Node, caja: Rect2, semilla: int) -> TrentAire:
	if padre == null:
		return null
	var e := _nuevo(Modo.ESTALLIDO, 0, semilla)
	e._caja = caja
	e._preparar()
	e._montar(padre)
	return e


func seguir(caja: Rect2) -> void:
	_caja = caja


func poner_nivel(n: int) -> void:
	nivel = maxi(n, 1)


func secar() -> void:
	if _secando < 0.0:
		_secando = maxf(_t, 0.0)


static func _nuevo(m: int, v: int, semilla: int) -> TrentAire:
	var e := TrentAire.new()
	e.modo = m
	e.version = clampi(v, 0, 2)
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	return e


func _montar(padre: Node) -> void:
	z_as_relative = false
	z_index = SueloRoto.Z_SUELO
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(self)
	_suelo = _capa(SueloRoto.Z_SUELO, false)
	_delante = _capa(Z_ENCIMA, false)
	_brillo = _capa(Z_ENCIMA + 1, true)


func _capa(z: int, aditiva: bool) -> Node2D:
	var c := Node2D.new()
	c.z_as_relative = false
	c.z_index = z
	if aditiva:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		c.material = mat
	c.draw.connect(_pintar.bind(c))
	add_child(c)
	return c


# Un punto al azar dentro del circulo del area (en el suelo: achatado como todo lo del suelo).
func _en_area() -> Vector2:
	var a: float = _rng.randf() * TAU
	var d: float = sqrt(_rng.randf()) * _r
	return _c + Vector2(cos(a), sin(a) * 0.6) * d


func _preparar() -> void:
	match modo:
		Modo.GEISER:
			var n: int = [14, 26, 5][version]
			for i in n:
				var t0: float
				match version:
					0: t0 = 0.62 + 0.4 * float(i) / float(n) + _rng.randf_range(-0.04, 0.04)
					1: t0 = 0.78 + 0.5 * float(i) / float(n) + _rng.randf_range(-0.05, 0.05)
					_: t0 = 0.62 + 0.07 * float(i)
				_piezas.append({"en": _en_area(), "t0": t0, "tam": _rng.randf_range(0.8, 1.25),
					"fase": _rng.randf_range(0.0, TAU), "lado": -1.0 if i % 2 else 1.0})
		Modo.CHUPAR:
			var n2: int = [3, 10, 5][version]
			for i in n2:
				_piezas.append({"t0": _rng.randf_range(0.0, 0.25) + 0.12 * float(i) * (1.0 if version != 0 else 0.0),
					"fase": _rng.randf_range(0.0, TAU), "curva": _rng.randf_range(-1.0, 1.0), "k": i})
		Modo.RESINA:
			# Los trozos en que se parte al soltarle: cada uno un pedazo del cepo (su angulo alrededor de los pies),
			# con su forma y hacia donde salta.
			for i in 9:
				_piezas.append({"a": TAU * (float(i) + _rng.randf_range(0.0, 0.6)) / 9.0, "tam": _rng.randf_range(0.8, 1.2),
					"v": _rng.randf_range(10.0, 20.0), "sube": _rng.randf_range(6.0, 14.0),
					"giro": _rng.randf_range(-6.0, 6.0), "lob": _lobulos(5)})
		Modo.ESTALLIDO:
			# Los grumos: salen de lo alto del cuerpo (el domo de ambar) en abanico, suben y caen alrededor.
			for i in 14:
				var a2: float = -PI * 0.5 + _rng.randf_range(-1.35, 1.35)
				_piezas.append({"x": _rng.randf_range(-0.35, 0.35), "y": _rng.randf_range(0.1, 0.4),
					"vx": cos(a2) * _rng.randf_range(22.0, 48.0), "sube": _rng.randf_range(14.0, 30.0),
					"tam": _rng.randf_range(2.2, 4.6), "giro": _rng.randf_range(-8.0, 8.0), "lob": _lobulos(6),
					"suelo": _rng.randf_range(-4.0, 6.0)})
		Modo.HUMO:
			for i in 12:
				_piezas.append({"x": _rng.randf_range(-0.4, 0.4), "y": _rng.randf_range(0.35, 0.8),
					"per": _rng.randf_range(1.1, 1.7), "fase": _rng.randf(), "r": _rng.randf_range(4.0, 7.0),
					"deriva": _rng.randf_range(-6.0, 6.0), "k": i})
		Modo.SECO:
			# Las grietas del cuerpo: su quiebro (en fracciones de su caja, desde lo alto en medio) y su fase.
			for i in 6:
				var pts := PackedVector2Array()
				var q := Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.2, 0.75))
				var ang: float = _rng.randf_range(0.0, TAU)
				pts.append(q)
				for k in 4:
					ang += _rng.randf_range(-0.9, 0.9)
					q += Vector2(cos(ang), sin(ang)) * _rng.randf_range(0.04, 0.07)
					pts.append(q)
				_piezas.append({"pts": pts, "fase": _rng.randf_range(0.0, 0.5), "k": i})
		Modo.GOTERON:
			for i in 10:
				_piezas.append({"a": TAU * (float(i) + _rng.randf_range(0.0, 0.7)) / 10.0,
					"v": _rng.randf_range(0.45, 1.0) * maxf(_r, 14.0), "sube": _rng.randf_range(8.0, 18.0),
					"tam": _rng.randf_range(1.4, 2.6)})


# Un borde irregular (los trozos de ambar): n radios entre 0,7 y 1.
func _lobulos(n: int) -> PackedFloat32Array:
	var l := PackedFloat32Array()
	for i in n:
		l.append(_rng.randf_range(0.7, 1.0))
	return l


func duracion() -> float:
	match modo:
		Modo.GEISER: return T_GEISER
		Modo.CHUPAR: return T_CHUPAR
		Modo.ESTALLIDO: return T_ESTALLIDO
		Modo.GOTERON: return T_GOTERON + 0.6
	# lo que se queda, hasta que se seca
	return INF if _secando < 0.0 else _secando + T_SECA


func _process(delta: float) -> void:
	avanzar_a(_t + delta * _ritmo)
	if _t >= duracion():
		queue_free()


func avanzar_a(t: float) -> void:
	_t = t
	if _suelo != null:
		_suelo.queue_redraw()
		_delante.queue_redraw()
		_brillo.queue_redraw()


func _pintar(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.GEISER: _geiser(capa)
		Modo.CHUPAR: _chupar(capa)
		Modo.RESINA: _resina(capa)
		Modo.ESTALLIDO: _estallido(capa)
		Modo.HUMO: _humo(capa)
		Modo.CARGA: _carga(capa)
		Modo.SECO: _seco(capa)
		Modo.GOTERON: _goteron(capa)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
# UNA CINTA rellena por 'pts' con un ancho por punto (los hilos, la raiz, los brazos, el chorro).
static func _cinta(ci: CanvasItem, pts: PackedVector2Array, anchos: PackedFloat32Array, col: Color) -> void:
	if pts.size() < 2 or col.a <= 0.01:
		return
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in pts.size():
		var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)])
		if d.length_squared() < 0.0001:
			d = Vector2.RIGHT
		var n: Vector2 = d.normalized().orthogonal() * anchos[i] * 0.5
		izq.append(pts[i] + n)
		der.append(pts[i] - n)
	der.reverse()
	izq.append_array(der)
	Poligono.relleno(ci, izq, col)


# UNA GOTA que cae: lagrima con la punta hacia arriba, negra, con el filo claro a un lado.
static func _gota(ci: CanvasItem, c: Vector2, tam: float, estira: float, alfa: float) -> void:
	if alfa <= 0.01 or tam <= 0.2:
		return
	var pts := PackedVector2Array()
	for k in 12:
		var a: float = TAU * float(k) / 12.0
		var y: float = sin(a)
		var x: float = cos(a) * (1.0 - maxf(-y, 0.0) * 0.75)
		pts.append(c + Vector2(x * tam, y * tam * (1.0 if y > 0.0 else estira)))
	Poligono.relleno(ci, pts, Color(SAVIA, alfa))
	ci.draw_circle(c + Vector2(-tam * 0.35, tam * 0.1), tam * 0.35, Color(BORDE, 0.8 * alfa))


# LA SALPICADURA al tocar el suelo: una corona de gotitas que saltan y una mancha violeta que se apaga.
func _salpica(capa: Node2D, p: Vector2, u: float, tam: float) -> void:
	if u < 0.0 or u > 1.0:
		return
	if capa == _suelo:
		MagiaMayor._disco(capa, p, (4.0 + 6.0 * u) * tam, Color(SAVIA, 0.55 * (1.0 - u)), Color(VIOLETA, 0.0), 0.5)
	elif capa == _delante:
		for j in 5:
			var a: float = PI + PI * (float(j) + 0.5) / 5.0
			var q: Vector2 = p + Vector2(cos(a) * 9.0 * u * tam, -10.0 * tam * sin(PI * u) + sin(a) * 2.0)
			capa.draw_circle(q, 1.1 * tam * (1.0 - u * 0.5), Color(SAVIA, 1.0 - u))
	elif capa == _brillo:
		capa.draw_circle(p, 5.0 * tam * (1.0 - u), Color(VIOLETA, 0.35 * (1.0 - u)))


# ------------------------------------------------------------
#  EL GEISER
# ------------------------------------------------------------
const ALTO_CHORRO := 170.0

# EL CHORRO: sale de la grieta y sube (0..1 = 'sube'); despues la cola se despega y sube detras ('suelta' 0..1).
func _chorro(capa: Node2D, sube: float, suelta: float, ancho: float) -> Vector2:
	var arriba: Vector2 = _o + Vector2(0.0, -ALTO_CHORRO * sube)
	if sube <= 0.0 or suelta >= 1.0:
		return arriba
	var cola: Vector2 = _o.lerp(arriba, suelta)
	var pts := PackedVector2Array()
	var an := PackedFloat32Array()
	for i in 9:
		var u: float = float(i) / 8.0
		var p: Vector2 = cola.lerp(arriba, u) + Vector2(sin(u * 7.0 + _t * 20.0) * 1.6, 0.0)
		pts.append(p)
		an.append(ancho * (0.7 + 0.5 * u))
	if capa == _delante:
		_cinta(capa, pts, an, Color(SAVIA, 1.0))
		# el filo claro (la pincelada) a un lado
		var filo := PackedVector2Array()
		for p in pts:
			filo.append(p + Vector2(-ancho * 0.28, 0.0))
		var anf := PackedFloat32Array()
		for a in an:
			anf.append(a * 0.22)
		_cinta(capa, filo, anf, Color(BORDE, 0.85))
		capa.draw_circle(arriba, ancho * 0.75, Color(SAVIA, 1.0))
	elif capa == _brillo:
		MagiaMayor._disco(capa, _o, ancho * 1.1 * (1.0 - suelta), Color(VIOLETA, 0.45 * (1.0 - suelta)), Color(VIOLETA, 0.0))
	return arriba


func _geiser(capa: Node2D) -> void:
	var sube: float = clampf((_t - T_SALE) / 0.25, 0.0, 1.0)
	var suelta: float = clampf((_t - T_SALE - 0.22) / 0.25, 0.0, 1.0)
	# LA SOMBRA del area: se oscurece mientras sube (avisa de donde va a caer) y se apaga al final.
	if capa == _suelo:
		var aviso: float = clampf((_t - T_SALE) / 0.4, 0.0, 1.0) * (1.0 - clampf((_t - 1.35) / 0.3, 0.0, 1.0))
		MagiaMayor._disco(capa, _c, _r, Color(NEGRO, 0.22 * aviso), Color(NEGRO, 0.05 * aviso), 0.6)
	match version:
		0: _geiser_gotas(capa, sube, suelta)
		1: _geiser_nube(capa, sube, suelta)
		_: _geiser_brazos(capa, sube, suelta)


# A: el chorro sube y se va; las GOTAS gordas caen sobre el area con su salpicadura.
func _geiser_gotas(capa: Node2D, sube: float, suelta: float) -> void:
	_chorro(capa, sube, suelta, 14.0)
	for p in _piezas:
		var u: float = (_t - float(p["t0"])) / 0.28
		var tam: float = float(p["tam"])
		var en: Vector2 = p["en"]
		if u >= 0.0 and u < 1.0 and capa == _delante:
			_gota(capa, en + Vector2(0.0, -190.0 * (1.0 - u * u)), 6.0 * tam, 1.4 + u, 1.0)
		elif u >= 1.0:
			_salpica(capa, en, (_t - float(p["t0"]) - 0.28) / 0.35, 1.8 * tam)


# B: el chorro sube y en lo alto forma una NUBE de savia sobre el area que llueve y se deshace.
func _geiser_nube(capa: Node2D, sube: float, suelta: float) -> void:
	var arriba: Vector2 = _chorro(capa, sube, suelta, 12.0)
	var cielo: Vector2 = _c + Vector2(0.0, -ALTO_CHORRO * 0.85)
	var forma: float = clampf((_t - T_SALE - 0.2) / 0.3, 0.0, 1.0)
	var deshace: float = clampf((_t - 1.3) / 0.35, 0.0, 1.0)
	if forma > 0.0 and deshace < 1.0 and capa != _suelo:
		var centro: Vector2 = arriba.lerp(cielo, forma)
		for j in 7:
			var a: float = TAU * float(j) / 7.0 + 0.3
			var q: Vector2 = centro + Vector2(cos(a) * _r * 0.6, sin(a) * 6.0) * forma
			var rr: float = (16.0 + 4.0 * sin(float(j) * 2.1 + _t * 3.0)) * forma * (1.0 - deshace * 0.6)
			if capa == _delante:
				MagiaMayor._disco(capa, q, rr, Color(SAVIA, 1.0 - deshace), Color(NEGRO, 0.9 * (1.0 - deshace)))
				capa.draw_circle(q + Vector2(-rr * 0.3, -rr * 0.35), rr * 0.35, Color(BORDE, 0.5 * (1.0 - deshace)))
			else:
				capa.draw_circle(q + Vector2(0, rr * 0.5), rr * 0.6, Color(VIOLETA, 0.12 * (1.0 - deshace)))
	for p in _piezas:
		var u: float = (_t - float(p["t0"])) / 0.22
		var en: Vector2 = p["en"]
		var desde: Vector2 = Vector2(en.x, cielo.y + 8.0)
		if u >= 0.0 and u < 1.0 and capa == _delante:
			_gota(capa, desde.lerp(en, u * u), 3.2 * float(p["tam"]), 2.4, 1.0)
		elif u >= 1.0:
			_salpica(capa, en, (_t - float(p["t0"]) - 0.22) / 0.3, 1.2 * float(p["tam"]))


# C: el chorro se abre arriba en BRAZOS de tinta que se curvan y caen como latigos, cada uno sobre un punto del area.
func _geiser_brazos(capa: Node2D, sube: float, suelta: float) -> void:
	var arriba: Vector2 = _chorro(capa, sube, 0.0 if _t < 1.2 else clampf((_t - 1.2) / 0.3, 0.0, 1.0), 16.0)
	for p in _piezas:
		var t0: float = float(p["t0"])
		var u: float = clampf((_t - t0) / 0.25, 0.0, 1.0)
		var vuelve: float = clampf((_t - t0 - 0.45) / 0.3, 0.0, 1.0)
		var en: Vector2 = p["en"]
		if _t < t0 - 0.1:
			continue
		if capa == _delante and vuelve < 1.0:
			# el brazo: de lo alto del chorro, arqueado hacia fuera, hasta el punto; crece a lo largo y se recoge
			var ctrl: Vector2 = arriba.lerp(en, 0.5) + Vector2(float(p["lado"]) * 50.0, -70.0)
			var hasta: float = u * (1.0 - vuelve)
			var pts := PackedVector2Array()
			var an := PackedFloat32Array()
			for i in 12:
				var s: float = float(i) / 11.0 * hasta
				var q: Vector2 = arriba.lerp(ctrl, s).lerp(ctrl.lerp(en, s), s)
				pts.append(q)
				an.append(lerpf(13.0, 4.0, s) * (1.0 - vuelve * 0.5))
			_cinta(capa, pts, an, Color(SAVIA, 1.0))
		if u >= 1.0:
			_salpica(capa, en, (_t - t0 - 0.25) / 0.4, 2.4)


# ------------------------------------------------------------
#  CHUPAR
# ------------------------------------------------------------
func _chupar(capa: Node2D) -> void:
	match version:
		0: _chupar_hilos(capa)
		1: _chupar_espiral(capa)
		_: _chupar_raiz(capa)


# El camino por el suelo de la victima a sus pies, ondulado ('curva' de -1 a 1 lo tuerce a un lado).
func _camino(u: float, curva: float, onda: float) -> Vector2:
	var d: Vector2 = _c - _o
	var n: Vector2 = d.orthogonal().normalized() * Vector2(1.0, 0.6)
	return _o.lerp(_c, u) + n * (sin(PI * u) * curva * 22.0 + sin(u * 9.0 + onda) * 3.0)


# A: HILOS violeta que reptan de la victima a sus pies y BOLITAS de luz que suben por ellos.
func _chupar_hilos(capa: Node2D) -> void:
	var crece: float = clampf(_t / 0.35, 0.0, 1.0)
	var apaga: float = clampf((_t - 1.0) / 0.3, 0.0, 1.0)
	for p in _piezas:
		var curva: float = float(p["curva"])
		var fase: float = float(p["fase"])
		if capa == _suelo:
			var pts := PackedVector2Array()
			var an := PackedFloat32Array()
			for i in 16:
				var u: float = float(i) / 15.0 * crece
				pts.append(_camino(u, curva, fase + _t * 4.0))
				an.append(3.6)
			_cinta(capa, pts, an, Color(SAVIA, 0.9 * (1.0 - apaga)))
		elif capa == _brillo:
			var pts2 := PackedVector2Array()
			var an2 := PackedFloat32Array()
			for i in 16:
				var u2: float = float(i) / 15.0 * crece
				pts2.append(_camino(u2, curva, fase + _t * 4.0))
				an2.append(1.6)
			_cinta(capa, pts2, an2, Color(VIOLETA, 0.6 * (1.0 - apaga)))
			for j in 2:
				var ub: float = (_t - 0.3 - float(j) * 0.25 - float(p["k"]) * 0.08) / 0.5
				if ub < 0.0 or ub > 1.0:
					continue
				var q: Vector2 = _camino(ub, curva, fase + _t * 4.0)
				capa.draw_circle(q, 4.5, Color(VIOLETA, 0.5))
				capa.draw_circle(q, 2.2, Color(LUZ, 0.9))
	if capa == _brillo:
		var llega: float = clampf((_t - 0.75) / 0.4, 0.0, 1.0) * (1.0 - apaga)
		capa.draw_circle(_c, 16.0 * llega, Color(VIOLETA, 0.3 * llega))


# B: un REMOLINO oscuro sobre la victima (cuñas que giran y se cierran) y MOTAS que salen en espiral y vuelan a el.
func _chupar_espiral(capa: Node2D) -> void:
	var abre: float = clampf(_t / 0.25, 0.0, 1.0) * (1.0 - clampf((_t - 1.0) / 0.3, 0.0, 1.0))
	var sobre: Vector2 = _o + Vector2(0.0, -20.0)
	if capa == _delante and abre > 0.0:
		for j in 5:
			var a: float = TAU * float(j) / 5.0 + _t * 7.0
			MagiaMayor._cuna(capa, sobre, a, 3.0, 22.0 * abre, 0.6, Color(SAVIA, 0.85 * abre), 0.6)
	for p in _piezas:
		var u: float = (_t - float(p["t0"])) / 0.7
		if u < 0.0 or u > 1.0:
			continue
		var giro: float = float(p["fase"]) + u * 9.0
		var rr: float = 18.0 * (1.0 - u)
		var hacia: Vector2 = sobre.lerp(_c + Vector2(0.0, -90.0), u * u)
		var q: Vector2 = hacia + Vector2(cos(giro), sin(giro) * 0.5) * rr - Vector2(0.0, 18.0 * sin(PI * u))
		if capa == _brillo:
			capa.draw_circle(q, 4.0, Color(VIOLETA, 0.45 * (1.0 - u * 0.4)))
			capa.draw_circle(q, 2.0, Color(LUZ, 0.9))


# C: una RAIZ negra que asoma del suelo entre los dos (ondulada, gorda, con el filo violeta) y LATE: bultos de luz que
# viajan por ella hasta sus pies. En la victima, tres garfios de raiz que la agarran.
func _chupar_raiz(capa: Node2D) -> void:
	var asoma: float = clampf(_t / 0.3, 0.0, 1.0)
	var hunde: float = clampf((_t - 1.0) / 0.3, 0.0, 1.0)
	var grosor: float = 8.0 * asoma * (1.0 - hunde)
	var pts := PackedVector2Array()
	var an := PackedFloat32Array()
	for i in 20:
		var u: float = float(i) / 19.0
		pts.append(_camino(u, 0.6, 1.0) - Vector2(0.0, 2.0 * sin(PI * u) * asoma))
		var late: float = 0.0
		for p in _piezas:
			var ul: float = (_t - 0.25 - float(p["k"]) * 0.14) / 0.45
			late += 4.5 * exp(-pow((u - ul) / 0.06, 2.0))
		an.append(grosor * (0.8 + 0.3 * sin(u * 11.0)) + late * (1.0 - hunde))
	if capa == _delante:
		_cinta(capa, pts, an, Color(SAVIA, 1.0))
		var filo := PackedVector2Array()
		var anf := PackedFloat32Array()
		for i in pts.size():
			filo.append(pts[i] + Vector2(0.0, -an[i] * 0.3))
			anf.append(an[i] * 0.25)
		_cinta(capa, filo, anf, Color(BORDE, 0.8))
		for j in 3:
			var a: float = -PI * 0.5 + (float(j) - 1.0) * 0.9
			var b: Vector2 = _o + Vector2(cos(a) * 3.0, 2.0)
			var garfio := PackedVector2Array([b, b + Vector2(cos(a) * 12.0, sin(a) * 15.0) * asoma * (1.0 - hunde),
				b + Vector2(cos(a) * 15.0 + 3.0, sin(a) * 10.0) * asoma * (1.0 - hunde)])
			var ang := PackedFloat32Array([4.0 * (1.0 - hunde), 2.4, 0.6])
			_cinta(capa, garfio, ang, Color(SAVIA, 1.0))
	elif capa == _brillo:
		for p in _piezas:
			var ul2: float = (_t - 0.25 - float(p["k"]) * 0.14) / 0.45
			if ul2 < 0.0 or ul2 > 1.0:
				continue
			var q: Vector2 = _camino(ul2, 0.6, 1.0) - Vector2(0.0, 2.0 * sin(PI * ul2))
			capa.draw_circle(q, 5.5, Color(VIOLETA, 0.5))
			capa.draw_circle(q, 2.6, Color(LUZ, 0.9))
			if ul2 > 0.9:
				capa.draw_circle(_c, 9.0 * (ul2 - 0.9) * 10.0, Color(VIOLETA, 0.25))


# ------------------------------------------------------------
#  EL AMBAR Y LO QUE SE QUEDA
# ------------------------------------------------------------
# Lo que le queda a lo que se queda: 1 mientras sigue, de 1 a 0 al secarse.
func _queda() -> float:
	return 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)


func _pies() -> Vector2:
	return Vector2(_caja.get_center().x, _caja.end.y)


# UN TROZO DE AMBAR: borde irregular ('lob'), filo oscuro, cuerpo dorado y su brillo.
static func _trozo(ci: CanvasItem, c: Vector2, tam: float, giro: float, lob: PackedFloat32Array, alfa: float) -> void:
	if alfa <= 0.01 or tam <= 0.3:
		return
	var n: int = lob.size()
	var borde := PackedVector2Array()
	var cuerpo := PackedVector2Array()
	for i in n:
		var a: float = giro + TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a) * 0.85) * tam * lob[i]
		borde.append(c + d * 1.25)
		cuerpo.append(c + d)
	Poligono.relleno(ci, borde, Color(AMBAR_OSCURO, alfa))
	Poligono.relleno(ci, cuerpo, Color(AMBAR, alfa))
	ci.draw_circle(c + Vector2(-tam * 0.3, -tam * 0.3), tam * 0.3, Color(AMBAR_CLARO, 0.9 * alfa))


# EL CEPO DE RESINA: un cerro de ambar alrededor de los pies (apoyado en el suelo), dos lenguas que trepan por las
# piernas, burbujas atrapadas y su brillo. Al soltarle tiembla, se agrieta y salta a trozos que caen y se apagan.
func _resina(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var pies: Vector2 = _pies()
	var ancho: float = clampf(_caja.size.x * 0.42, 9.0, 34.0)
	var alto: float = clampf(_caja.size.y * 0.16, 5.0, 18.0)
	var sale: float = clampf(_t / 0.22, 0.0, 1.0)
	sale = sale * (1.0 + 0.12 * sin(PI * sale))
	var seca: float = -1.0 if _secando < 0.0 else clampf((_t - _secando) / T_SECA, 0.0, 1.0)
	if capa == _suelo:
		var a_s: float = 0.55 * (1.0 if seca < 0.0 else 1.0 - seca)
		MagiaMayor._disco(capa, pies, ancho * 1.25 * sale, Color(AMBAR_OSCURO, a_s), Color(AMBAR_OSCURO, 0.0), 0.45)
		return
	if seca < 0.15:
		var tiembla := Vector2(sin(_t * 90.0) * (1.6 if seca >= 0.0 else 0.0), 0.0)
		var o: Vector2 = pies + tiembla
		if capa == _brillo:
			MagiaMayor._disco(capa, o + Vector2(-ancho * 0.3, -alto * 0.6) * sale, ancho * 0.35 * sale,
				Color(AMBAR_CLARO, 0.35), Color(AMBAR_CLARO, 0.0), 0.6)
			return
		var monte := PackedVector2Array()
		var filo := PackedVector2Array()
		for i in 17:
			var u: float = float(i) / 16.0
			var x: float = lerpf(-1.0, 1.0, u)
			var h: float = alto * sale * (1.0 - x * x * 0.85) * (1.0 + 0.12 * sin(u * 13.0 + 1.7))
			monte.append(o + Vector2(x * ancho * sale, 2.0 - h))
			filo.append(o + Vector2(x * ancho * sale * 1.08, 2.0 - h * 1.12 - 0.8))
		monte.append(o + Vector2(ancho * sale * 0.92, 4.0))
		monte.append(o + Vector2(-ancho * sale * 0.92, 4.0))
		filo.append(o + Vector2(ancho * sale * 1.0, 5.0))
		filo.append(o + Vector2(-ancho * sale * 1.0, 5.0))
		Poligono.relleno(capa, filo, Color(AMBAR_OSCURO, 0.95))
		Poligono.relleno(capa, monte, Color(AMBAR, 0.82))
		# LAS LENGUAS que trepan por las piernas
		for s in [-1.0, 1.0]:
			var base: Vector2 = o + Vector2(s * ancho * 0.35, -alto * 0.6) * sale
			var punta: Vector2 = base + Vector2(s * 1.5, -alto * 0.9 * sale - 1.5 * sin(_t * 2.0 + s))
			_cinta(capa, PackedVector2Array([base, base.lerp(punta, 0.5), punta]),
				PackedFloat32Array([ancho * 0.28, ancho * 0.18, 1.0]), Color(AMBAR, 0.85))
		# burbujas atrapadas
		for j in 3:
			var b: Vector2 = o + Vector2((float(j) - 1.0) * ancho * 0.45, -alto * (0.3 + 0.15 * float(j % 2))) * sale
			capa.draw_circle(b, 1.3, Color(AMBAR_CLARO, 0.75))
		# LAS GRIETAS al soltarse: tiras oscuras que corren del centro
		if seca >= 0.0:
			var k: float = seca / 0.15
			for j in 4:
				var a: float = -PI * 0.5 + (float(j) - 1.5) * 0.7
				var c: Vector2 = o + Vector2(0.0, -alto * 0.45)
				var fin: Vector2 = c + Vector2(cos(a) * ancho * 0.9, sin(a) * alto * 0.7 + alto * 0.4) * k
				_cinta(capa, PackedVector2Array([c, c.lerp(fin, 0.5) + Vector2(1.5, 0.0), fin]),
					PackedFloat32Array([1.8, 1.2, 0.4]), Color(AMBAR_OSCURO, 0.95))
		return
	# A TROZOS
	if capa != _delante:
		return
	var kt: float = (seca - 0.15) / 0.85
	for p in _piezas:
		var a2: float = float(p["a"])
		var desde: Vector2 = pies + Vector2(cos(a2) * ancho * 0.6, -alto * 0.4 + sin(a2) * alto * 0.3)
		var q: Vector2 = desde + Vector2(cos(a2) * float(p["v"]) * kt,
			-float(p["sube"]) * 4.0 * kt * (1.0 - kt) + alto * 0.4 * kt)
		_trozo(capa, q, 3.0 * float(p["tam"]), float(p["giro"]) * kt, p["lob"], 1.0 - kt * kt)


# EL ESTALLIDO DE LA COSTRA: un fogonazo dorado en lo alto del cuerpo y los grumos que salen disparados hacia arriba y
# afuera, caen alrededor de sus pies, botan un pelin y se apagan (con su manchita en el suelo).
const T_CAER_GRUMO := 0.55

func _estallido(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var pies: Vector2 = _pies()
	var domo := Vector2(_caja.get_center().x, _caja.position.y + _caja.size.y * 0.3)
	if capa == _brillo:
		var f: float = clampf(1.0 - _t / 0.3, 0.0, 1.0)
		MagiaMayor._disco(capa, domo, _caja.size.x * 0.55 * (0.6 + 0.6 * (1.0 - f)), Color(AMBAR_CLARO, 0.7 * f),
			Color(AMBAR, 0.0))
		return
	var alfa: float = 1.0 - clampf((_t - 0.8) / 0.3, 0.0, 1.0)
	for p in _piezas:
		var desde: Vector2 = domo + Vector2(float(p["x"]) * _caja.size.x, (float(p["y"]) - 0.1) * _caja.size.y * 0.5)
		var u: float = clampf(_t / T_CAER_GRUMO, 0.0, 1.0)
		var x: float = float(p["vx"]) * u
		var abajo: float = pies.y + float(p["suelo"]) - desde.y
		var y: float = -float(p["sube"]) * 4.0 * u * (1.0 - u) + abajo * u * u
		if _t > T_CAER_GRUMO:
			var kb: float = clampf((_t - T_CAER_GRUMO) / 0.2, 0.0, 1.0)
			y -= 3.0 * sin(PI * kb)
			x += float(p["vx"]) * 0.12 * kb
		var q: Vector2 = desde + Vector2(x, y)
		if capa == _delante:
			_trozo(capa, q, float(p["tam"]), float(p["giro"]) * u, p["lob"], alfa)
		elif capa == _suelo and _t > T_CAER_GRUMO:
			MagiaMayor._disco(capa, Vector2(q.x, pies.y + float(p["suelo"])), float(p["tam"]) * 1.4,
				Color(AMBAR_OSCURO, 0.35 * alfa), Color(AMBAR_OSCURO, 0.0), 0.5)


# EL HUMO VIOLETA de la Savia negra: bocanadas que salen de su cuerpo y suben deshaciendose. Cuantas mas cargas, mas
# bocanadas a la vez y mas espesas (con 1, dos hilillos; con 5, una columna).
func _humo(capa: Node2D) -> void:
	if _t < 0.0 or capa == _suelo:
		return
	var queda: float = _queda()
	var n: int = mini(2 + nivel * 2, _piezas.size())
	var dens: float = lerpf(0.45, 0.85, clampf(float(nivel - 1) / 4.0, 0.0, 1.0))
	for i in n:
		var p: Dictionary = _piezas[i]
		var u: float = fposmod(_t / float(p["per"]) + float(p["fase"]), 1.0)
		var base := Vector2(_caja.get_center().x + float(p["x"]) * _caja.size.x,
			_caja.position.y + float(p["y"]) * _caja.size.y)
		var q: Vector2 = base + Vector2(float(p["deriva"]) * u + sin(u * 5.0 + float(p["k"])) * 2.0,
			-u * (_caja.size.y * 0.55 + 10.0))
		# (a la medida del cuerpo: en el Espantajo, bocanadas gordas; en una rata, hilillos)
		var r: float = float(p["r"]) * (0.6 + 1.1 * u) * clampf(_caja.size.x / 30.0, 0.8, 2.5)
		var a: float = dens * sin(PI * minf(u * 1.4, 1.0)) * (1.0 - u * 0.5) * queda
		if capa == _delante:
			BestiaAire._bola(capa, q, r, Color(SAVIA.lerp(VIOLETA, 0.55), a * 0.85))
		else:
			BestiaAire._bola(capa, q, r * 0.6, Color(VIOLETA, a * 0.35))


# LA GRIETA QUE BRILLA mientras carga el Geiser: en su espalda, un brillo violeta que late cada vez mas deprisa y
# gotitas negras que se escapan hacia arriba.
func _carga(capa: Node2D) -> void:
	if _t < 0.0 or capa == _suelo:
		return
	var queda: float = _queda()
	var g: Vector2 = _pies() + Vector2(0.0, -minf(ALTO_GRIETA, _caja.size.y * 0.7))
	var late: float = 0.5 + 0.5 * sin(_t * (6.0 + minf(_t, 2.0) * 3.0))
	if capa == _brillo:
		MagiaMayor._disco(capa, g, (12.0 + 6.0 * late) * queda, Color(VIOLETA, (0.35 + 0.35 * late) * queda),
			Color(VIOLETA, 0.0), 0.8)
		capa.draw_circle(g, 2.5 + 1.5 * late, Color(LUZ, 0.8 * queda))
	else:
		for j in 3:
			var u: float = fposmod(_t * 1.3 + float(j) / 3.0, 1.0)
			_gota(capa, g + Vector2((float(j) - 1.0) * 4.0, -u * 22.0), 1.8 * (1.0 - u * 0.5), 1.4, (1.0 - u) * queda)


# MAS SECO MAS PEGA: grietas violeta por el cuerpo que laten como un corazon; dos mas por cada tramo.
func _seco(capa: Node2D) -> void:
	if _t < 0.0 or capa != _brillo:
		return
	var queda: float = _queda()
	var n: int = mini(nivel * 2, _piezas.size())
	var latido: float = pow(maxf(sin(_t * TAU * (0.8 + 0.25 * float(nivel))), 0.0), 3.0)
	var base := Vector2(_caja.get_center().x, _caja.position.y)
	for i in n:
		var p: Dictionary = _piezas[i]
		var pts := PackedVector2Array()
		var an := PackedFloat32Array()
		var an2 := PackedFloat32Array()
		for q in p["pts"]:
			pts.append(base + (q as Vector2) * _caja.size)
			an.append(2.2)
			an2.append(0.9)
		an[an.size() - 1] = 0.6
		an2[an2.size() - 1] = 0.3
		var a: float = (0.35 + 0.65 * latido) * queda
		_cinta(capa, pts, an, Color(VIOLETA, a))
		_cinta(capa, pts, an2, Color(LUZ, a * 0.8))


# EL GOTERON (la Resina y la Savia negra): de su boca en parabola hasta el centro, con su reguero de gotitas detras; al
# caer revienta en corona. La resina en ambar; la savia en negro con su destello violeta.
func _goteron(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var cuerpo: Color = AMBAR if ambar else SAVIA
	var filo: Color = AMBAR_OSCURO if ambar else NEGRO
	var claro: Color = AMBAR_CLARO if ambar else BORDE
	var lejos: float = _o.distance_to(_c)
	if _t < T_GOTERON:
		if capa != _delante:
			return
		var k: float = _t / T_GOTERON
		for j in 4:
			var kj: float = maxf(k - float(j) * 0.07, 0.0)
			var q: Vector2 = _o.lerp(_c, kj) - Vector2(0.0, (lejos * 0.35 + 18.0) * sin(PI * kj))
			var tam: float = 5.0 if j == 0 else 2.6 - float(j) * 0.5
			capa.draw_circle(q, tam + 1.0, Color(filo, 1.0 - float(j) * 0.2))
			capa.draw_circle(q, tam, Color(cuerpo, 1.0 - float(j) * 0.2))
			if j == 0:
				capa.draw_circle(q + Vector2(-1.5, -1.5), 1.6, claro)
		return
	var kv: float = clampf((_t - T_GOTERON) / 0.5, 0.0, 1.0)
	if capa == _suelo:
		MagiaMayor._disco(capa, _c, _r * 0.8 * (0.5 + 0.5 * kv), Color(cuerpo, 0.5 * (1.0 - kv)), Color(cuerpo, 0.0), 0.5)
	elif capa == _delante:
		for p in _piezas:
			var d := Vector2(cos(float(p["a"])), sin(float(p["a"])) * 0.6)
			var q2: Vector2 = _c + d * float(p["v"]) * kv - Vector2(0.0, float(p["sube"]) * 4.0 * kv * (1.0 - kv))
			capa.draw_circle(q2, float(p["tam"]) + 0.6, Color(filo, 1.0 - kv * kv))
			capa.draw_circle(q2, float(p["tam"]), Color(cuerpo, 1.0 - kv * kv))
	elif capa == _brillo and not ambar:
		capa.draw_circle(_c, 10.0 * (1.0 - kv), Color(VIOLETA, 0.4 * (1.0 - kv)))
