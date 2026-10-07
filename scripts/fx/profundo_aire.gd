# ============================================================
#  profundo_aire.gd  (class_name ProfundoAire)
#  LOS EFECTOS DE LOS MUTANTES DEL SLIME PROFUNDO en el mapa (07/10/2026: el slime de arrecife y el de escarcha). SUYOS,
#  no las magias nuestras (ver la ola o el aliento del jugador): el AGUA del arrecife es agua de mar (azul verdoso con
#  espuma blanca) y lleva sus CORALES; el FRIO de la escarcha es blanco azulado, con cristalitos y copos.
#  Todo relleno y con degradado (sin una sola raya: ver BarridoAire.cometa / brillo / destello).
#  POR EL SUELO (SueloRoto.Tipo.PROFUNDO_*):
#    MAREA      Reventon de marea: donde cae, una OLA en anillo que se abre desde el centro (la cresta de espuma, el agua
#               detras y el suelo mojado que brilla) y gotas que saltan de la cresta.
#    CHORRO     Chorro a presion: un chorro de agua que sale de su frente a la altura de la boca y cruza la linea hasta
#               el final (nucleo claro, agua alrededor, el suelo mojado debajo); al llegar, rompe en salpicaduras.
#    CORAL      Esquirlas de coral: trozos de coral de colores que salen volando en abanico, girando, con su estela, y al
#               caer se parten en motas.
#    ESTALLIDO  Estallido helado: donde cae, la ESCARCHA se extiende por el suelo (borde irregular), salen cristales de
#               hielo hacia arriba y copos; se queda un momento blanco y se funde.
#    ALIENTO    Aliento gelido: bocanadas de vaho blanco azulado que salen de su frente por el cono, crecen y se deshacen,
#               con copos que titilan y el suelo que se queda escarchado.
#    CARAMBANOS Carambanos: en cada circulo de la fila (CombatFormas.BOLAS), uno tras otro: su sombra crece en el suelo,
#               el carambano cae del aire y se rompe en esquirlas con un destello y una mancha de escarcha.
#  Coordenadas de MUNDO; el suelo sin achatar; lo que va en el aire, a su altura por K. Todo sale de la forma y la semilla.
# ============================================================
extends Node2D
class_name ProfundoAire

enum Modo { MAREA, CHORRO, CORAL, ESTALLIDO, ALIENTO, CARAMBANOS }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80

const BLANCO := Color(1.0, 1.0, 1.0)
const AGUA := Color(0.18, 0.55, 0.78)
const AGUA_CLARA := Color(0.5, 0.85, 1.0)
const AGUA_HONDA := Color(0.07, 0.28, 0.48)
const ESPUMA := Color(0.92, 0.98, 1.0)
const HIELO := Color(0.62, 0.84, 1.0)
const HIELO_HONDO := Color(0.32, 0.55, 0.85)
const ESCARCHA := Color(0.88, 0.95, 1.0)
const CORALES := [Color(0.92, 0.42, 0.40), Color(0.86, 0.78, 0.38), Color(0.62, 0.38, 0.78), Color(0.38, 0.85, 0.58),
	Color(0.95, 0.55, 0.80)]

# LA MAREA
const T_OLA := 0.32
const T_MOJADO := 0.55
const GOTAS_OLA := 12
# EL CHORRO
const T_CHORRO := 0.16
const T_CHORRO_VIVE := 0.22
const T_CHORRO_APAGA := 0.18
const ALTO_BOCA := 8.0
# EL CORAL
const T_VUELO := 0.22
const T_ROTO := 0.3
const TROZOS := 9
# EL ESTALLIDO
const T_ESTALLA := 0.2
const T_HELADA := 0.5
const T_FUNDE := 0.35
const PICOS := 9
# EL ALIENTO
const T_SOPLO := 0.32
const T_ALIENTO_VIVE := 0.3
const BOCANADAS := 10
# LOS CARAMBANOS
const T_MARCA := 0.22
const T_ENTRE := 0.12
const T_CAE := 0.2
const T_ROMPE := 0.4
const ALTO_CAIDA := 64.0

var modo: int = Modo.MAREA
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _fase: float = 0.0
var _gotas: Array = []
var _trozos: Array = []
var _borde: PackedFloat32Array = PackedFloat32Array()
var _puntos: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null


static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> ProfundoAire:
	if padre == null or f == null:
		return null
	var e := ProfundoAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


func _montar(padre: Node) -> void:
	z_as_relative = false
	z_index = SueloRoto.Z_SUELO
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(self)
	_suelo = _capa(SueloRoto.Z_SUELO)
	_delante = _capa(Z_ENCIMA)


func _capa(z: int) -> Node2D:
	var c := Node2D.new()
	c.z_as_relative = false
	c.z_index = z
	c.draw.connect(_pintar.bind(c))
	add_child(c)
	return c


# Lo que sale al azar (de la semilla): las gotas, los trozos de coral, el borde de la escarcha, las bocanadas.
func _preparar() -> void:
	_fase = _rng.randf_range(0.0, TAU)
	for i in 16:
		_gotas.append({"a": _rng.randf_range(0.0, TAU), "v": _rng.randf_range(0.7, 1.3), "r": _rng.randf_range(0.8, 1.6),
			"h": _rng.randf_range(0.6, 1.2), "d": _rng.randf_range(0.0, 0.25)})
	for i in TROZOS:
		_trozos.append({"u": _rng.randf_range(-0.5, 0.5), "d": _rng.randf_range(0.65, 1.0), "giro": _rng.randf_range(4.0, 9.0),
			"col": CORALES[i % CORALES.size()], "tam": _rng.randf_range(4.5, 6.5), "sale": _rng.randf_range(0.0, 0.08)})
	for i in 24:
		_borde.append(_rng.randf_range(0.8, 1.08))
	if modo == Modo.ALIENTO:
		for i in BOCANADAS:
			_puntos.append({"u": _rng.randf_range(-0.45, 0.45), "sale": float(i) / float(BOCANADAS) * 0.16,
				"d": _rng.randf_range(0.6, 1.0), "r": _rng.randf_range(0.8, 1.3)})
	if modo == Modo.CARAMBANOS:
		_puntos = forma.centros_bolas()


# CUANDO LE LLEGA a 'p' (en segundos desde que se lanza). El mismo numero manda el dibujo y el golpe.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.MAREA:
			var u: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
			return T_OLA * (1.0 - sqrt(1.0 - u))
		Modo.ESTALLIDO:
			var u2: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
			return T_ESTALLA * (1.0 - sqrt(1.0 - u2))
		Modo.CHORRO:
			return T_CHORRO * clampf((p - f.origen).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0)
		Modo.CORAL:
			return T_VUELO * clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
		Modo.ALIENTO:
			return T_SOPLO * clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
		Modo.CARAMBANOS:
			# El carambano que le cae mas cerca.
			var pts: Array = f.centros_bolas()
			var mejor: int = 0
			for i in pts.size():
				if (pts[i] as Vector2).distance_to(p) < (pts[mejor] as Vector2).distance_to(p):
					mejor = i
			return T_MARCA + T_ENTRE * float(mejor) + T_CAE
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.MAREA: return T_OLA
		Modo.ESTALLIDO: return T_ESTALLA
		Modo.CHORRO: return T_CHORRO
		Modo.CORAL: return T_VUELO
		Modo.ALIENTO: return T_SOPLO
		Modo.CARAMBANOS: return T_MARCA + T_CAE
	return 0.2


func duracion() -> float:
	match modo:
		Modo.MAREA: return T_OLA + T_MOJADO
		Modo.CHORRO: return T_CHORRO + T_CHORRO_VIVE + T_CHORRO_APAGA + 0.3
		Modo.CORAL: return T_VUELO + 0.08 + T_ROTO
		Modo.ESTALLIDO: return T_ESTALLA + T_HELADA + T_FUNDE
		Modo.ALIENTO: return T_SOPLO + 0.16 + T_ALIENTO_VIVE + 0.2
		Modo.CARAMBANOS: return T_MARCA + T_ENTRE * float(maxi(_puntos.size() - 1, 0)) + T_CAE + T_ROMPE + 0.1
	return 1.0


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	_suelo.queue_redraw()
	_delante.queue_redraw()


func _pintar(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.MAREA: _marea(capa)
		Modo.CHORRO: _chorro(capa)
		Modo.CORAL: _coral(capa)
		Modo.ESTALLIDO: _estallido(capa)
		Modo.ALIENTO: _aliento(capa)
		Modo.CARAMBANOS: _carambanos(capa)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
# UNA BANDA EN ANILLO rellena con degradado de dentro a fuera: 'col_in' en r_in, 'col_mid' en r_mid, 'col_out' en r_out.
# Es la cresta de la ola (sin raya: el borde se difumina).
static func _anillo_relleno(ci: CanvasItem, c: Vector2, r_in: float, r_mid: float, r_out: float, col_in: Color,
		col_mid: Color, col_out: Color, n: int = 40) -> void:
	if r_out <= 0.5:
		return
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var p_in0: Vector2 = c + d0 * maxf(r_in, 0.0)
		var p_in1: Vector2 = c + d1 * maxf(r_in, 0.0)
		var p_m0: Vector2 = c + d0 * r_mid
		var p_m1: Vector2 = c + d1 * r_mid
		var p_o0: Vector2 = c + d0 * r_out
		var p_o1: Vector2 = c + d1 * r_out
		ci.draw_primitive(PackedVector2Array([p_in0, p_m0, p_m1]), PackedColorArray([col_in, col_mid, col_mid]),
			PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([p_in0, p_m1, p_in1]), PackedColorArray([col_in, col_mid, col_in]),
			PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([p_m0, p_o0, p_o1]), PackedColorArray([col_mid, col_out, col_out]),
			PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([p_m0, p_o1, p_m1]), PackedColorArray([col_mid, col_out, col_mid]),
			PackedVector2Array())


# UNA BANDA a lo largo de unos puntos, de ancho 'anchos[i]', opaca en el eje y transparente en los bordes.
static func _banda(ci: CanvasItem, pts: Array, anchos: Array, col: Color) -> void:
	if pts.size() < 2:
		return
	var transp := Color(col, 0.0)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d: Vector2 = (b - a)
		if d.length() < 0.01:
			continue
		var n: Vector2 = d.normalized().orthogonal()
		var na: Vector2 = n * float(anchos[i]) * 0.5
		var nb: Vector2 = n * float(anchos[i + 1]) * 0.5
		for lado in [1.0, -1.0]:
			ci.draw_primitive(PackedVector2Array([a, b, b + nb * lado]), PackedColorArray([col, col, transp]),
				PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([a, b + nb * lado, a + na * lado]), PackedColorArray([col, transp, transp]),
				PackedVector2Array())


# UN TROZO de algo duro (coral, hielo): un rombo alargado relleno, claro de un lado y oscuro del otro.
static func _trozo(ci: CanvasItem, c: Vector2, tam: float, giro: float, col: Color) -> void:
	var d := Vector2(cos(giro), sin(giro))
	var n: Vector2 = d.orthogonal() * tam * 0.55
	var a: Vector2 = c + d * tam
	var b: Vector2 = c - d * tam * 0.8
	ci.draw_colored_polygon(PackedVector2Array([a, c + n, b]), col.lightened(0.25))
	ci.draw_colored_polygon(PackedVector2Array([a, b, c - n]), col.darkened(0.25))


# UN CARAMBANO: un huso largo que acaba en punta hacia abajo, blanco arriba y azul hacia la punta.
static func _carambano(ci: CanvasItem, arriba: Vector2, largo: float, ancho: float, alfa: float) -> void:
	var punta: Vector2 = arriba + Vector2(0.0, largo)
	var l := arriba + Vector2(-ancho * 0.5, largo * 0.15)
	var r := arriba + Vector2(ancho * 0.5, largo * 0.15)
	ci.draw_primitive(PackedVector2Array([arriba, l, punta]), PackedColorArray([Color(ESCARCHA, alfa), Color(HIELO, alfa),
		Color(HIELO_HONDO, alfa)]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([arriba, punta, r]), PackedColorArray([Color(BLANCO, alfa), Color(HIELO, alfa),
		Color(ESCARCHA, alfa)]), PackedVector2Array())


# ------------------------------------------------------------
#  LA MAREA (Reventon de marea)
# ------------------------------------------------------------
func _marea(capa: Node2D) -> void:
	var c: Vector2 = forma.centro
	var R: float = forma.radio
	var u: float = clampf(_t / T_OLA, 0.0, 1.0)
	var fr: float = R * (1.0 - (1.0 - u) * (1.0 - u))   # el frente de la ola
	var tras: float = maxf(_t - T_OLA, 0.0)
	var seca: float = clampf(tras / T_MOJADO, 0.0, 1.0)
	if capa == _suelo:
		# EL SUELO MOJADO: agua honda que brilla por dentro, hasta donde ha llegado la ola, y se seca.
		BarridoAire.brillo(capa, c, fr * 1.05, Color(AGUA_HONDA, 0.5 * (1.0 - seca)))
		BarridoAire.brillo(capa, c, fr * 0.7, Color(AGUA, 0.35 * (1.0 - seca)))
		# LA OLA: el agua de detras de la cresta (banda suave) y la CRESTA hecha de borbotones de espuma, cada uno a su
		# altura (no un aro: "un circulo con borde parece una canica").
		if u < 1.0 or tras < 0.22:
			var vive: float = 1.0 - clampf(tras / 0.22, 0.0, 1.0)
			var g: float = 7.0 + 4.0 * (1.0 - u)
			_anillo_relleno(capa, c, fr - g * 3.2, fr - g * 1.2, fr + g * 0.3, Color(AGUA_HONDA, 0.0),
				Color(AGUA, 0.55 * vive), Color(AGUA_CLARA, 0.0))
			var n: int = _borde.size()
			for i in n:
				var a: float = TAU * float(i) / float(n) + _fase
				var bo: float = float(_borde[i])
				var q: Vector2 = c + Vector2(cos(a), sin(a)) * (fr - 2.0 + (bo - 0.94) * 14.0)
				var rb: float = (3.5 + 3.0 * bo) * (0.6 + 0.4 * sin(_t * 18.0 + float(i) * 1.7))
				BarridoAire.brillo(capa, q, rb * 1.6, Color(AGUA_CLARA, 0.5 * vive))
				BarridoAire.brillo(capa, q, rb, Color(ESPUMA, 0.95 * vive))
		return
	# LAS GOTAS que saltan de la cresta: suben, caen y se apagan (cada una con su estela).
	for i in GOTAS_OLA:
		var gd: Dictionary = _gotas[i]
		var t0: float = float(gd["d"]) * T_OLA
		var vida: float = (_t - t0) / 0.42
		if vida <= 0.0 or vida >= 1.0:
			continue
		var a: float = float(gd["a"])
		var rr: float = R * (1.0 - (1.0 - minf((t0 + vida * 0.3) / T_OLA, 1.0)) ** 2) * 0.95
		var base: Vector2 = c + Vector2(cos(a), sin(a)) * rr
		var alto: float = sin(PI * vida) * 16.0 * float(gd["h"])
		var p: Vector2 = base - Vector2(0.0, alto * K)
		var antes: float = maxf(vida - 0.08, 0.0)
		var p_antes: Vector2 = c + Vector2(cos(a), sin(a)) * rr * 0.97 - Vector2(0.0, sin(PI * antes) * 16.0 * float(gd["h"]) * K)
		BarridoAire.cometa(capa, p_antes, p, 3.4 * float(gd["r"]), Color(AGUA_CLARA, 0.9 * (1.0 - vida * 0.6)))
	# Al caer, un golpe de espuma en el centro.
	if _t < 0.2:
		BarridoAire.destello(capa, c - Vector2(0.0, 4.0), lerpf(18.0, 6.0, _t / 0.2), Color(ESPUMA, 1.0 - _t / 0.2), _fase)


# ------------------------------------------------------------
#  EL CHORRO (Chorro a presion)
# ------------------------------------------------------------
func _chorro(capa: Node2D) -> void:
	var o: Vector2 = forma.origen
	var d: Vector2 = forma.dir
	var L: float = forma.largo
	var llega: float = clampf(_t / T_CHORRO, 0.0, 1.0)
	var t_apaga: float = _t - (T_CHORRO + T_CHORRO_VIVE)
	var cola: float = clampf(t_apaga / T_CHORRO_APAGA, 0.0, 1.0) if t_apaga > 0.0 else 0.0
	var s0: float = cola           # donde empieza (al apagarse, la cola se va hacia el final)
	var s1: float = llega
	var ancho: float = maxf(forma.ancho, 8.0)
	if capa == _suelo:
		# EL SUELO MOJADO por debajo del chorro, que se queda un rato y se seca.
		var seca: float = clampf((_t - T_CHORRO) / (T_CHORRO_VIVE + T_CHORRO_APAGA + 0.3), 0.0, 1.0)
		var pts: Array = []
		var an: Array = []
		for k in 9:
			var s: float = float(k) / 8.0 * llega
			pts.append(o + d * L * s)
			an.append(ancho * (0.8 + 0.5 * s))
		_banda(capa, pts, an, Color(AGUA_HONDA, 0.45 * (1.0 - seca)))
		return
	if s1 - s0 < 0.01:
		# Al llegar, rompe al final: espuma y gotas.
		pass
	else:
		var pts2: Array = []
		var an2: Array = []
		var nucleo: Array = []
		for k in 13:
			var s2: float = lerpf(s0, s1, float(k) / 12.0)
			# Sale a la altura de la boca y baja al suelo hacia el final; ondula un poco (es agua, no un rayo).
			var alto: float = ALTO_BOCA * (1.0 - s2 * 0.7)
			var on: float = sin(s2 * 6.0 - _t * 24.0 + _fase) * 0.5
			var p: Vector2 = o + d * L * s2 + d.orthogonal() * on - Vector2(0.0, alto * K)
			pts2.append(p)
			an2.append(ancho * (1.0 + 0.6 * s2))
			nucleo.append(ancho * (0.45 + 0.3 * s2))
		_banda(capa, pts2, an2, Color(AGUA, 0.9))
		_banda(capa, pts2, an2.map(func(x): return x * 0.7), Color(AGUA_CLARA, 0.85))
		_banda(capa, pts2, nucleo, Color(ESPUMA, 0.95))
		# LAS GOTAS que se le escapan a lo largo (el agua va a presion).
		for i in 10:
			var gd2: Dictionary = _gotas[i]
			var sg: float = lerpf(s0, s1, fmod(float(gd2["d"]) * 4.0 + _t * 3.0 * float(gd2["v"]), 1.0))
			var lado: float = 1.0 if i % 2 == 0 else -1.0
			var pg: Vector2 = o + d * L * sg + d.orthogonal() * lado * ancho * (0.55 + 0.4 * float(gd2["h"])) 				- Vector2(0.0, ALTO_BOCA * (1.0 - sg * 0.7) * K)
			BarridoAire.cometa(capa, pg - d * 6.0, pg, 2.6 * float(gd2["r"]), Color(AGUA_CLARA, 0.8))
		BarridoAire.brillo(capa, pts2[0], ancho * 0.6, Color(AGUA_CLARA, 0.6 * (1.0 - cola)))
	# LA SALPICADURA al final, desde que llega hasta un poco despues de apagarse.
	var t_rompe: float = _t - T_CHORRO
	if t_rompe >= 0.0:
		var fin: Vector2 = o + d * L
		var vida_s: float = t_rompe / (T_CHORRO_VIVE + T_CHORRO_APAGA + 0.3)
		BarridoAire.brillo(capa, fin - Vector2(0.0, 2.0), ancho * 1.6, Color(ESPUMA, 0.5 * (1.0 - vida_s)))
		for i in 12:
			var gd: Dictionary = _gotas[i]
			var ciclo: float = fmod(t_rompe * 2.6 * float(gd["v"]) + float(gd["d"]) * 4.0, 1.0)
			if t_apaga > T_CHORRO_APAGA * 0.6 and ciclo < 0.3:
				continue   # (apagandose ya no salen gotas nuevas)
			var a: float = d.angle() + (float(gd["a"]) / TAU - 0.5) * 2.4
			var dd := Vector2(cos(a), sin(a))
			var p2: Vector2 = fin + dd * 18.0 * ciclo - Vector2(0.0, sin(PI * ciclo) * 12.0 * float(gd["h"]) * K)
			var p3: Vector2 = fin + dd * 18.0 * maxf(ciclo - 0.1, 0.0) \
				- Vector2(0.0, sin(PI * maxf(ciclo - 0.1, 0.0)) * 12.0 * float(gd["h"]) * K)
			BarridoAire.cometa(capa, p3, p2, 3.4 * float(gd["r"]), Color(AGUA_CLARA, 0.9 * (1.0 - ciclo)))


# ------------------------------------------------------------
#  EL CORAL (Esquirlas de coral)
# ------------------------------------------------------------
func _coral(capa: Node2D) -> void:
	var o: Vector2 = forma.origen
	var R: float = forma.radio
	var ap: float = deg_to_rad(forma.apertura)
	for tr in _trozos:
		var a: float = forma.dir.angle() + float(tr["u"]) * ap
		var dd := Vector2(cos(a), sin(a))
		var lejos: float = R * float(tr["d"])
		var t0: float = float(tr["sale"])
		var u: float = clampf((_t - t0) / T_VUELO, 0.0, 1.0)
		if _t < t0:
			continue
		var col: Color = tr["col"]
		var cae: Vector2 = o + dd * lejos
		if u < 1.0:
			if capa != _delante:
				continue
			# EN EL AIRE: vuela en arco (sale de la altura de su cuerpo) girando, con su estela.
			var p: Vector2 = o + dd * lejos * u - Vector2(0.0, (6.0 + sin(PI * u) * 10.0) * (1.0 - u * 0.4) * K)
			var u0: float = maxf(u - 0.18, 0.0)
			var p0: Vector2 = o + dd * lejos * u0 - Vector2(0.0, (6.0 + sin(PI * u0) * 10.0) * (1.0 - u0 * 0.4) * K)
			BarridoAire.cometa(capa, p0, p, 4.0, Color(col, 0.6))
			_trozo(capa, p, float(tr["tam"]), _fase + _t * float(tr["giro"]), col)
			continue
		var tras: float = _t - t0 - T_VUELO
		var k: float = clampf(tras / T_ROTO, 0.0, 1.0)
		if k >= 1.0:
			continue
		if capa == _suelo:
			BarridoAire.brillo(capa, cae, 10.0 * (1.0 - k), Color(col, 0.4 * (1.0 - k)))
			continue
		# AL CAER: un destello pequeño y el trozo partido en motas que saltan.
		if k < 0.4:
			BarridoAire.destello(capa, cae - Vector2(0.0, 2.0), 11.0 * (1.0 - k / 0.4), Color(col.lightened(0.4), 1.0 - k / 0.4),
				a)
		for j in 3:
			var gd: Dictionary = _gotas[(j * 5 + int(float(tr["giro"]) * 3.0)) % _gotas.size()]
			var aj: float = float(gd["a"])
			var q: Vector2 = cae + Vector2(cos(aj), sin(aj) * 0.6) * 13.0 * k - Vector2(0.0, sin(PI * k) * 9.0 * K)
			_trozo(capa, q, float(tr["tam"]) * 0.45 * (1.0 - k * 0.5), aj + _t * 6.0, Color(col, 1.0 - k))


# ------------------------------------------------------------
#  EL ESTALLIDO (Estallido helado)
# ------------------------------------------------------------
func _estallido(capa: Node2D) -> void:
	var c: Vector2 = forma.centro
	var R: float = forma.radio
	var u: float = clampf(_t / T_ESTALLA, 0.0, 1.0)
	var fr: float = R * (1.0 - (1.0 - u) * (1.0 - u))
	var tras: float = maxf(_t - T_ESTALLA - T_HELADA, 0.0)
	var funde: float = clampf(tras / T_FUNDE, 0.0, 1.0)
	if capa == _suelo:
		# LA ESCARCHA por el suelo: borde irregular (cristalino), clara por dentro y mas blanca en el borde.
		var n: int = _borde.size()
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in n:
			var a: float = TAU * float(i) / float(n) + _fase
			pts.append(c + Vector2(cos(a), sin(a)) * fr * float(_borde[i]))
			cols.append(Color(ESCARCHA, 0.8 * (1.0 - funde)))
		if fr > 1.0:
			for i in n:
				var j: int = (i + 1) % n
				capa.draw_primitive(PackedVector2Array([c, pts[i], pts[j]]),
					PackedColorArray([Color(ESCARCHA, 0.55 * (1.0 - funde)), cols[i], cols[j]]), PackedVector2Array())
		BarridoAire.brillo(capa, c, fr * 0.6, Color(BLANCO, 0.3 * (1.0 - funde)))
		return
	# EL GOLPE: un destello blanco en el centro.
	if _t < 0.22:
		BarridoAire.destello(capa, c - Vector2(0.0, 5.0), lerpf(22.0, 8.0, _t / 0.22), Color(BLANCO, 1.0 - _t / 0.22), _fase)
	# LOS CRISTALES que brotan del suelo a lo que llega la escarcha (puntas hacia arriba) y se funden al final.
	for i in PICOS:
		var a2: float = TAU * float(i) / float(PICOS) + _fase * 0.7
		var dist: float = R * (0.45 + 0.4 * float(_borde[i * 2 % _borde.size()]) - 0.4)
		if fr < dist:
			continue
		var crece: float = clampf((fr - dist) / (R * 0.25), 0.0, 1.0) * (1.0 - funde)
		if crece <= 0.02:
			continue
		var base: Vector2 = c + Vector2(cos(a2), sin(a2)) * dist
		var alto: float = (12.0 + 8.0 * float(_borde[(i * 3) % _borde.size()])) * crece
		var ladeo: Vector2 = Vector2(cos(a2), sin(a2) * 0.5) * alto * 0.35
		var punta: Vector2 = base + ladeo - Vector2(0.0, alto * K)
		var w: float = 3.8 * crece
		capa.draw_primitive(PackedVector2Array([base + Vector2(-w, 0.0), punta, base + Vector2(w, 0.0)]),
			PackedColorArray([Color(HIELO_HONDO, 0.9), Color(BLANCO, 0.95), Color(HIELO, 0.9)]), PackedVector2Array())
	# LOS COPOS que suben y titilan.
	for i in 10:
		var gd: Dictionary = _gotas[i]
		var vida: float = clampf((_t - float(gd["d"]) * 0.3) / (T_ESTALLA + T_HELADA), 0.0, 1.0)
		if vida <= 0.0 or vida >= 1.0:
			continue
		var a3: float = float(gd["a"])
		var q: Vector2 = c + Vector2(cos(a3), sin(a3)) * R * 0.8 * sqrt(vida) * float(gd["v"]) \
			- Vector2(0.0, 22.0 * vida * float(gd["h"]) * K)
		BarridoAire.destello(capa, q, 3.2 * float(gd["r"]) * (0.7 + 0.3 * sin(_t * 9.0 + a3)), Color(ESCARCHA, 1.0 - vida), a3)


# ------------------------------------------------------------
#  EL ALIENTO (Aliento gelido)
# ------------------------------------------------------------
func _aliento(capa: Node2D) -> void:
	var o: Vector2 = forma.origen
	var R: float = forma.radio
	var ap: float = deg_to_rad(forma.apertura)
	var fin_total: float = T_SOPLO + 0.16 + T_ALIENTO_VIVE + 0.2
	if capa == _suelo:
		# EL SUELO ESCARCHADO por el abanico, hasta donde ha llegado el vaho, que se funde al final.
		var llega: float = clampf(_t / T_SOPLO, 0.0, 1.0)
		var funde: float = clampf((_t - T_SOPLO - T_ALIENTO_VIVE) / 0.35, 0.0, 1.0)
		var a0: float = forma.dir.angle() - ap * 0.5
		var n: int = 12
		for i in n:
			var aa: float = a0 + ap * float(i) / float(n)
			var ab: float = a0 + ap * float(i + 1) / float(n)
			var r: float = R * llega
			var m0: Vector2 = o + Vector2(cos(aa), sin(aa)) * r * 0.65
			var m1: Vector2 = o + Vector2(cos(ab), sin(ab)) * r * 0.65
			var f0: Vector2 = o + Vector2(cos(aa), sin(aa)) * r
			var f1: Vector2 = o + Vector2(cos(ab), sin(ab)) * r
			var lleno := Color(ESCARCHA, 0.34 * (1.0 - funde))
			var nada := Color(ESCARCHA, 0.0)
			capa.draw_primitive(PackedVector2Array([o, m0, m1]), PackedColorArray([nada, lleno, lleno]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([m0, f0, f1]), PackedColorArray([lleno, nada, nada]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([m0, f1, m1]), PackedColorArray([lleno, nada, lleno]), PackedVector2Array())
		return
	# LAS BOCANADAS: salen de su frente (a la altura de la boca), viajan por el cono creciendo y se deshacen.
	for b in _puntos:
		var t0: float = float(b["sale"])
		var vida: float = (_t - t0) / (T_SOPLO + T_ALIENTO_VIVE)
		if vida <= 0.0 or vida >= 1.0:
			continue
		var a: float = forma.dir.angle() + float(b["u"]) * ap
		var avanza: float = minf((_t - t0) / T_SOPLO, 1.0)
		avanza = 1.0 - (1.0 - avanza) * (1.0 - avanza)
		var p: Vector2 = o + Vector2(cos(a), sin(a)) * R * float(b["d"]) * avanza \
			- Vector2(0.0, ALTO_BOCA * (1.0 - avanza * 0.6) * K)
		var rad: float = lerpf(4.0, 14.0, avanza) * float(b["r"])
		var alfa: float = 0.75 * (1.0 - vida * vida)
		BarridoAire.brillo(capa, p, rad, Color(ESCARCHA, alfa))
		BarridoAire.brillo(capa, p, rad * 0.5, Color(BLANCO, alfa * 0.7))
	# LOS COPOS dentro del vaho: titilan y caen despacio.
	for i in 12:
		var gd: Dictionary = _gotas[i]
		var t1: float = float(gd["d"]) * 0.6
		var vida2: float = (_t - t1) / (fin_total - t1)
		if vida2 <= 0.0 or vida2 >= 1.0:
			continue
		var a4: float = forma.dir.angle() + (float(gd["a"]) / TAU - 0.5) * ap
		var q: Vector2 = o + Vector2(cos(a4), sin(a4)) * R * minf(vida2 * 1.6, 1.0) * float(gd["v"]) * 0.85 \
			- Vector2(0.0, (ALTO_BOCA + 6.0 * float(gd["h"]) - 10.0 * vida2) * K)
		BarridoAire.destello(capa, q, 3.0 * float(gd["r"]) * (0.6 + 0.4 * sin(_t * 11.0 + a4)), Color(BLANCO, 1.0 - vida2), a4)


# ------------------------------------------------------------
#  LOS CARAMBANOS
# ------------------------------------------------------------
func _carambanos(capa: Node2D) -> void:
	var r_bola: float = maxf(forma.ancho * 0.5, 6.0)
	for i in _puntos.size():
		var p: Vector2 = _puntos[i]
		var t_cae: float = T_MARCA + T_ENTRE * float(i)
		var u: float = clampf((_t - (t_cae - T_MARCA)) / T_MARCA, 0.0, 1.0)   # la sombra, antes de que caiga
		var tras: float = _t - (t_cae + T_CAE)                                  # desde que toco el suelo
		if capa == _suelo:
			if tras < 0.0:
				# LA SOMBRA del que viene: crece y se oscurece (se ve venir).
				BarridoAire.brillo(capa, p, r_bola * lerpf(0.5, 1.0, u), Color(HIELO_HONDO, 0.45 * u))
			elif tras < T_ROMPE:
				var k: float = tras / T_ROMPE
				# LA ESCARCHA que deja: clara, del tamaño del circulo, y se va.
				BarridoAire.brillo(capa, p, r_bola * (1.0 + 0.4 * k), Color(ESCARCHA, 0.7 * (1.0 - k)))
				BarridoAire.brillo(capa, p, r_bola * 0.5, Color(BLANCO, 0.6 * (1.0 - k)))
			continue
		# EN EL AIRE: el carambano cae (acelerando) con un brillito arriba.
		if tras < 0.0 and _t >= t_cae:
			var v: float = clampf((_t - t_cae) / T_CAE, 0.0, 1.0)
			var alto: float = ALTO_CAIDA * (1.0 - v * v)
			var largo: float = 26.0
			var arriba: Vector2 = p - Vector2(0.0, (alto + largo) * K + largo * (1.0 - K))
			_carambano(capa, arriba, largo, 10.0, 1.0)
			BarridoAire.brillo(capa, arriba + Vector2(0.0, 3.0), 7.0, Color(BLANCO, 0.5))
		elif tras >= 0.0 and tras < T_ROMPE:
			var k2: float = tras / T_ROMPE
			# AL TOCAR: destello y las esquirlas de hielo que saltan hacia fuera (con su gravedad).
			if k2 < 0.45:
				BarridoAire.destello(capa, p - Vector2(0.0, 3.0), lerpf(20.0, 6.0, k2 / 0.45), Color(BLANCO, 1.0 - k2 / 0.45),
					_fase + float(i))
			for j in 6:
				var gd: Dictionary = _gotas[(i * 4 + j) % _gotas.size()]
				var aj: float = float(gd["a"])
				var q: Vector2 = p + Vector2(cos(aj), sin(aj) * 0.6) * 20.0 * k2 * float(gd["v"]) \
					- Vector2(0.0, (sin(PI * k2) * 10.0 * float(gd["h"])) * K)
				_trozo(capa, q, 4.0 * (1.0 - k2 * 0.6), aj + _t * 8.0, Color(HIELO, 1.0 - k2))
