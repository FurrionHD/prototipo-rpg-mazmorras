# ============================================================
#  rata_aire.gd  (class_name RataAire)
#  LOS EFECTOS DE LOS MUTANTES DE LA RATA en el mapa (30/10/2026: la Rata sombria, la Rata drusa y la Rata de cuarzo
#  ahumado; ver la memoria rata-mutante). Las mandibulas de sus mordiscos son las de la rata (BestiaAire, ya aprobadas):
#  aqui va lo que les pone encima cada mutante. SUYOS, con su lenguaje:
#    - LA SOMBRA de la sombria, como la oscuridad del juego (la Voragine): medias lunas negras RELLENAS con la pincelada
#      clara rota en el borde, que se deshacen; nada de fuego negro.
#    - EL CRISTAL de la drusa: esquirlas cian (las de los cristales que se ha comido) con el blanco del reflejo; el de la
#      de cuarzo ahumado, el mismo cristal en AHUMADO (azul oscuro). Lo decide el color de quien ataca (oscuro =
#      ahumado), que viaja en la semilla (SlimeAire.semilla_con_color) o en su color_visual.
#  POR EL SUELO (SueloRoto.Tipo.RATA_*, en el orden de Modo):
#    ESTELA_SOMBRA     el salto del Frenesi en la sombra: jirones de sombra por donde ha pasado y una mancha que se abre
#                      donde cae.
#    ANILLO_ESQUIRLAS  el Frenesi de esquirlas: al caer le revientan los cristales en un anillo que barre el circulo.
#    SURCO_CRISTAL     la Embestida de cristal: esquirlas que se quedan clavadas por donde pasa, brillan y se apagan.
#    DESTELLO          el Destello de la de cuarzo ahumado: un fogonazo en abanico desde los cristales de su pecho, blanco
#                      azulado en el centro y humo azul oscuro hacia el borde, con esquirlas de luz.
#    TRAICION          el Mordisco a traicion: se deshace en un remolino de sombra donde estaba y reaparece de otro detras
#                      de su presa.
#  SOBRE EL CUERPO (CombatFX.Estilo.RATA_*: la mandibula la pone BestiaAire y esto va encima):
#    JIRONES           jirones de sombra que salen del bocado y se deshacen.
#    ESQUIRLAS         esquirlas de cristal que saltan del bocado, con un destello.
#    CORTE             el corte de cristal a quien atraviesa la Embestida: una media luna de cristal y sus esquirlas.
#    VELO              el que se come el Destello: un velo oscuro sobre los ojos, con motas de luz (la Ceguera).
#  NADA DE LINEAS (efectos-sin-lineas). Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name RataAire

# Los del suelo, en el orden de SueloRoto.Tipo.RATA_*: no reordenar.
enum Modo { ESTELA_SOMBRA, ANILLO_ESQUIRLAS, SURCO_CRISTAL, DESTELLO, TRAICION,
	JIRONES, ESQUIRLAS, CORTE, VELO }

const K := 0.7071
const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80

const NEGRO := Color(0.05, 0.04, 0.08)
const SOMBRA := Color(0.16, 0.13, 0.22)
const PINCEL := Color(0.8, 0.78, 0.84)          # la pincelada clara rota del borde (MagiaMayor.PINCEL)
const OJO := Color(0.95, 0.80, 0.20)            # sus ojos amarillos
const BLANCO := Color(1.0, 1.0, 1.0)
const CRISTAL := Color(0.45, 0.88, 1.0)
const CRISTAL_CLARO := Color(0.80, 1.0, 1.0)
const CRISTAL_HONDO := Color(0.22, 0.55, 0.72)
const AHUMADO := Color(0.30, 0.50, 0.68)
const AHUMADO_CLARO := Color(0.62, 0.80, 0.95)
const AHUMADO_HONDO := Color(0.12, 0.20, 0.32)
const LUZ := Color(0.85, 0.93, 1.0)             # el centro del Destello
const HUMO := Color(0.10, 0.15, 0.26)           # su borde

const T_SALTO := 0.22          # lo que tarda en caer (CombatTactico.T_SALTO_BICHO)
const T_SOMBRA := 0.55         # lo que tardan los jirones en deshacerse
const T_ANILLO := 0.26         # lo que tarda el anillo de esquirlas en llegar al borde
const T_PASA := 0.2            # lo que tarda la Embestida en recorrer su linea (BestiaAire.T_ESTELA)
const T_CLAVADAS := 0.9        # lo que se quedan brillando las esquirlas del surco
const T_FOGONAZO := 0.16       # lo que tarda el Destello en llegar al borde de su abanico
const T_HUMO := 0.6            # lo que tarda su humo en irse
const T_REMOLINO := 0.32       # lo que dura cada remolino de la Traicion
const T_VELO := 0.85           # lo que se queda el velo sobre los ojos
const T_GOLPE := 0.4           # los de sobre el cuerpo

var modo: int = Modo.JIRONES
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _fase: float = 0.0
var _ahumado: bool = false
var _o: Vector2 = Vector2.ZERO        # de donde sale (el que salta, el que embiste, el pecho del Destello)
var _c: Vector2 = Vector2.ZERO        # donde cae / donde muerde
var _dir: Vector2 = Vector2.RIGHT
var _r: float = 25.0
var _largo: float = 40.0
var _caja: Rect2 = Rect2()
var _piezas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  CREARLOS
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> RataAire:
	if padre == null or f == null:
		return null
	var e := RataAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ahumado = es_ahumado(SlimeAire.color_de_semilla(semilla))
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._r = maxf(f.radio, 8.0)
	if f.tipo == CombatFormas.Tipo.CIRCULO:
		e._c = f.centro
		# DE DONDE SALTA: lo lejos que esta quien lo lanza va en el 'ancho' del circulo (CombatTactico.desde_quien_lanza).
		e._o = f.centro - e._dir * f.ancho if f.ancho > 1.0 else f.centro
	else:
		e._o = SueloRoto.origen_de(f)
		e._largo = maxf(f.largo if f.tipo == CombatFormas.Tipo.LINEA else f.radio, 8.0)
		e._c = e._o + e._dir * e._largo
	e._preparar()
	e._montar(padre)
	return e


# 'desde' = de donde viene (quien muerde), 'caja' = el cuerpo que lo recibe, 'color' = el de quien ataca (oscuro =
# cristal ahumado).
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, color: Color, semilla: int, espera: float,
		ritmo: float) -> RataAire:
	if padre == null:
		return null
	var e := RataAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ahumado = es_ahumado(color)
	e._ritmo = maxf(ritmo, 0.05)
	e._caja = caja
	e._c = caja.get_center() + Vector2(e._rng.randf_range(-0.12, 0.12) * caja.size.x, e._rng.randf_range(-0.15, 0.05) * caja.size.y)
	e._o = desde
	e._dir = (e._c - desde).normalized() if e._c.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	e._r = maxf(caja.size.x, 10.0)
	e._t = -maxf(espera, 0.0) * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


# ¿Ese color es el de la de cuarzo ahumado? (oscuro: su cristal es ahumado; el de la drusa, cian).
static func es_ahumado(col: Color) -> bool:
	return col.get_luminance() < 0.25


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


func _preparar() -> void:
	_fase = _rng.randf_range(0.0, TAU)
	match modo:
		Modo.ESTELA_SOMBRA:
			# Jirones por donde ha pasado (u de 0 = donde despega a 1 = donde cae) y la mancha de la caida.
			for i in 7:
				_piezas.append({"u": (float(i) + _rng.randf_range(0.1, 0.9)) / 7.0, "lado": _rng.randf_range(-1.0, 1.0),
					"tam": _rng.randf_range(0.8, 1.3), "giro": _rng.randf_range(-1.0, 1.0)})
		Modo.ANILLO_ESQUIRLAS:
			for i in 14:
				_piezas.append({"a": TAU * (float(i) + _rng.randf_range(0.0, 0.7)) / 14.0, "d": _rng.randf_range(0.75, 1.05),
					"tam": _rng.randf_range(4.0, 6.5), "giro": _rng.randf_range(6.0, 12.0), "sube": _rng.randf_range(6.0, 14.0)})
		Modo.SURCO_CRISTAL:
			var n: int = int(clampf(_largo / 6.0, 7.0, 16.0))
			for i in n:
				_piezas.append({"u": (float(i) + _rng.randf_range(0.0, 0.8)) / float(n), "v": _rng.randf_range(-0.55, 0.55),
					"tam": _rng.randf_range(3.2, 5.5), "inclina": _rng.randf_range(-0.5, 0.5), "brilla": _rng.randf_range(0.0, 1.0)})
		Modo.DESTELLO:
			for i in 12:
				_piezas.append({"u": _rng.randf_range(-0.5, 0.5), "d": _rng.randf_range(0.35, 1.05), "tam": _rng.randf_range(0.7, 1.4),
					"sube": _rng.randf_range(4.0, 12.0), "luz": i < 5})
		Modo.TRAICION:
			for i in 5:
				_piezas.append({"a": TAU * float(i) / 5.0 + _rng.randf_range(-0.3, 0.3), "tam": _rng.randf_range(0.8, 1.2)})
		Modo.JIRONES:
			for i in 3:
				_piezas.append({"a": _dir.angle() + PI + _rng.randf_range(-1.1, 1.1), "tam": _rng.randf_range(0.8, 1.2),
					"t0": float(i) * 0.04})
		Modo.ESQUIRLAS, Modo.CORTE:
			for i in 7:
				_piezas.append({"a": _dir.angle() + _rng.randf_range(-0.9, 0.9), "v": _rng.randf_range(16.0, 30.0),
					"sube": _rng.randf_range(8.0, 16.0), "tam": _rng.randf_range(2.6, 4.2), "giro": _rng.randf_range(6.0, 12.0)})
		Modo.VELO:
			for i in 6:
				_piezas.append({"x": _rng.randf_range(-0.45, 0.45), "y": _rng.randf_range(-0.4, 0.4), "f": _rng.randf_range(0.0, TAU)})


# CUANDO LE LLEGA a 'p' (en segundos desde que se lanza). El mismo numero manda el dibujo y el golpe.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.ESTELA_SOMBRA, Modo.TRAICION:
			return T_SALTO
		Modo.ANILLO_ESQUIRLAS:
			return T_SALTO + clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0) * T_ANILLO
		Modo.SURCO_CRISTAL:
			return clampf((p - f.origen).dot(f.dir.normalized()) / maxf(f.largo, 1.0), 0.0, 1.0) * SueloRoto.t_embestida(f)
		Modo.DESTELLO:
			return clampf(p.distance_to(SueloRoto.origen_de(f)) / maxf(f.radio, 1.0), 0.0, 1.0) * T_FOGONAZO
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.ESTELA_SOMBRA, Modo.TRAICION: return T_SALTO
		Modo.ANILLO_ESQUIRLAS: return T_SALTO + T_ANILLO
		Modo.SURCO_CRISTAL: return T_PASA   # (la de verdad, la de su linea: SueloRoto.t_embestida)
		Modo.DESTELLO: return T_FOGONAZO
	return 0.2


func duracion() -> float:
	match modo:
		Modo.ESTELA_SOMBRA: return T_SALTO + T_SOMBRA
		Modo.ANILLO_ESQUIRLAS: return T_SALTO + T_ANILLO + 0.35
		Modo.SURCO_CRISTAL: return _pasa() + T_CLAVADAS
		Modo.DESTELLO: return T_FOGONAZO + T_HUMO
		Modo.TRAICION: return T_SALTO + T_REMOLINO
		Modo.VELO: return T_VELO
	return T_GOLPE


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	_suelo.queue_redraw()
	_delante.queue_redraw()
	_brillo.queue_redraw()


func _pintar(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.ESTELA_SOMBRA: _estela_sombra(capa)
		Modo.ANILLO_ESQUIRLAS: _anillo(capa)
		Modo.SURCO_CRISTAL: _surco(capa)
		Modo.DESTELLO: _destello(capa)
		Modo.TRAICION: _traicion(capa)
		Modo.JIRONES: _jirones(capa)
		Modo.ESQUIRLAS: _esquirlas(capa)
		Modo.CORTE: _corte(capa)
		Modo.VELO: _velo(capa)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
# UN JIRON DE SOMBRA: una media luna negra rellena (densa en el filo, que se difumina hacia dentro) con la pincelada
# clara rota por fuera. 'a' = hacia donde se abre.
static func _jiron(ci: CanvasItem, c: Vector2, a: float, r: float, grueso: float, alfa: float) -> void:
	if alfa <= 0.01 or r <= 0.5:
		return
	BestiaAire._media_luna(ci, c, a - 1.2, a + 1.2, r, grueso, NEGRO, SOMBRA, alfa * 0.95, false)
	# LA PINCELADA CLARA del borde es la que lo separa del suelo oscuro de la mazmorra (sin ella, negro sobre negro no se
	# ve: hojas del 30/10): gruesa y viva, rota en dos trazos.
	BestiaAire._media_luna(ci, c, a - 0.8, a + 0.1, r + grueso * 0.15, grueso * 0.38, PINCEL, SOMBRA, alfa * 0.95, false)
	BestiaAire._media_luna(ci, c, a + 0.35, a + 0.9, r + grueso * 0.1, grueso * 0.26, PINCEL, SOMBRA, alfa * 0.7, false)


# UNA ESQUIRLA de cristal (cian o ahumada): un rombo alargado, la cara de la luz clara y la otra honda.
func _esquirla(ci: CanvasItem, c: Vector2, tam: float, giro: float, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var claro: Color = AHUMADO_CLARO if _ahumado else CRISTAL_CLARO
	var medio: Color = AHUMADO if _ahumado else CRISTAL
	var hondo: Color = AHUMADO_HONDO if _ahumado else CRISTAL_HONDO
	var d := Vector2(cos(giro), sin(giro))
	var n: Vector2 = d.orthogonal() * tam * 0.38
	var a: Vector2 = c + d * tam
	var b: Vector2 = c - d * tam * 0.7
	ci.draw_primitive(PackedVector2Array([a, c + n, b]), PackedColorArray([Color(BLANCO, alfa), Color(claro, alfa),
		Color(medio, alfa)]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([a, b, c - n]), PackedColorArray([Color(medio, alfa), Color(hondo, alfa),
		Color(hondo, alfa)]), PackedVector2Array())


# Lo que tarda la Embestida en recorrer su linea: lo de todas las embestidas (SueloRoto.t_embestida).
func _pasa() -> float:
	return SueloRoto.t_embestida(forma) if forma != null else T_PASA


func _col_cristal() -> Color:
	return AHUMADO if _ahumado else CRISTAL


# ------------------------------------------------------------
#  EL FRENESI EN LA SOMBRA (el salto)
# ------------------------------------------------------------
func _estela_sombra(capa: Node2D) -> void:
	var largo: float = _o.distance_to(_c)
	# LOS JIRONES por donde pasa: cada uno nace cuando el cuerpo pasa por ahi y se deshace.
	if largo > 4.0 and capa == _delante:
		for jp in _piezas:
			var u: float = float(jp["u"])
			var nace: float = u * T_SALTO
			var k: float = clampf((_t - nace) / T_SOMBRA, 0.0, 1.0)
			if _t < nace or k >= 1.0:
				continue
			var p: Vector2 = _o.lerp(_c, u) + _dir.orthogonal() * float(jp["lado"]) * 5.0 \
				- Vector2(0.0, sin(PI * u) * 14.0 * K + 6.0 * k)
			var tam: float = 10.0 * float(jp["tam"]) * (1.0 + 0.6 * k)
			_jiron(capa, p, _dir.angle() + PI + float(jp["giro"]), tam, tam * 0.7, (1.0 - k) * (1.0 - k))
	# DONDE CAE: una mancha de sombra que se abre en el suelo y se va, y un ultimo jiron que sube.
	var kc: float = clampf((_t - T_SALTO) / T_SOMBRA, 0.0, 1.0)
	if _t < T_SALTO or kc >= 1.0:
		return
	if capa == _suelo:
		BarridoAire.brillo(capa, _c, _r * (0.6 + 0.6 * kc), Color(NEGRO, 0.55 * (1.0 - kc)))
	elif capa == _delante:
		for i in 4:
			var a: float = _fase + TAU * float(i) / 4.0
			var q: Vector2 = _c + Vector2(cos(a), sin(a) * 0.6) * _r * (0.3 + 0.5 * kc) - Vector2(0.0, 4.0 * kc)
			_jiron(capa, q, a, 6.0 * (1.0 + kc), 4.5, (1.0 - kc) * 0.8)


# ------------------------------------------------------------
#  EL FRENESI DE ESQUIRLAS (el anillo al caer)
# ------------------------------------------------------------
func _anillo(capa: Node2D) -> void:
	var k: float = clampf((_t - T_SALTO) / T_ANILLO, 0.0, 1.0)
	if _t < T_SALTO:
		return
	var apaga: float = clampf((_t - T_SALTO - T_ANILLO) / 0.35, 0.0, 1.0)
	if capa == _suelo:
		# El brillo del suelo que barre el circulo con el frente.
		BarridoAire.brillo(capa, _c, _r * (0.3 + 0.8 * k), Color(_col_cristal(), 0.3 * (1.0 - apaga)))
		return
	if capa == _brillo:
		if k < 0.35:
			BarridoAire.destello(capa, _c - Vector2(0.0, 4.0), 16.0 * (1.0 - k / 0.35), Color(BLANCO, 0.9 * (1.0 - k / 0.35)), _fase)
		return
	for pz in _piezas:
		var a: float = float(pz["a"])
		var d := Vector2(cos(a), sin(a))
		var lejos: float = _r * float(pz["d"]) * k
		var alto: float = sin(PI * k) * float(pz["sube"]) * K
		var q: Vector2 = _c + Vector2(d.x, d.y) * lejos - Vector2(0.0, alto + 3.0)
		_esquirla(capa, q, float(pz["tam"]) * (1.0 - 0.4 * apaga), a + _t * float(pz["giro"]), 1.0 - apaga)


# ------------------------------------------------------------
#  LA EMBESTIDA DE CRISTAL (el surco de esquirlas clavadas)
# ------------------------------------------------------------
func _surco(capa: Node2D) -> void:
	var n_lado: Vector2 = _dir.orthogonal()
	var ancho: float = maxf(forma.ancho, 10.0) if forma != null else 14.0
	for pz in _piezas:
		var u: float = float(pz["u"])
		var nace: float = u * _pasa()
		if _t < nace:
			continue
		var vida: float = clampf((_t - nace) / (T_CLAVADAS + _pasa() - nace), 0.0, 1.0)
		var alfa: float = 1.0 - vida * vida
		var p: Vector2 = _o + _dir * _largo * u + n_lado * float(pz["v"]) * ancho
		if capa == _suelo:
			BarridoAire.brillo(capa, p, 6.0, Color(_col_cristal(), 0.3 * alfa))
			continue
		if capa == _brillo:
			# El brillo que le recorre a ratos.
			var ciclo: float = fposmod(_t * 1.6 + float(pz["brilla"]), 1.0)
			if ciclo < 0.15:
				BarridoAire.destello(capa, p - Vector2(0.0, 4.0), 5.0 * (1.0 - ciclo / 0.15), Color(BLANCO, 0.8 * alfa), _fase)
			continue
		# CLAVADA de punta, con un respingo al clavarse.
		var tras: float = _t - nace
		var vibra: float = sin(tras * 40.0) * 0.15 * maxf(0.0, 1.0 - tras / 0.2)
		_esquirla(capa, p - Vector2(0.0, float(pz["tam"]) * 0.6 * K), float(pz["tam"]), -PI * 0.5 + float(pz["inclina"]) + vibra, alfa)


# ------------------------------------------------------------
#  EL DESTELLO (el fogonazo en abanico de la de cuarzo ahumado)
# ------------------------------------------------------------
func _destello(capa: Node2D) -> void:
	var o: Vector2 = _o
	var R: float = _r
	var ap: float = deg_to_rad(maxf(forma.apertura, 20.0)) if forma != null else 1.2
	var a0: float = _dir.angle()
	var k: float = clampf(_t / T_FOGONAZO, 0.0, 1.0)
	var humo: float = clampf((_t - T_FOGONAZO) / T_HUMO, 0.0, 1.0)
	if capa == _suelo:
		BarridoAire.brillo(capa, o + _dir * R * 0.5, R * 0.7, Color(HUMO, 0.4 * (1.0 - humo)))
		return
	# EL ABANICO: relleno, luz blanco-azulada cerca de ella que se oscurece hacia el borde en humo; el frente es el que
	# avanza. Se apaga del centro hacia fuera.
	var frente: float = R * k
	var n: int = 14
	var alfa: float = 1.0 - humo
	if alfa > 0.01 and capa == (_brillo if humo < 0.25 else _delante):
		for i in n:
			var s0: float = float(i) / float(n)
			var s1: float = float(i + 1) / float(n)
			var d0 := Vector2(cos(a0 + (s0 - 0.5) * ap), sin(a0 + (s0 - 0.5) * ap))
			var d1 := Vector2(cos(a0 + (s1 - 0.5) * ap), sin(a0 + (s1 - 0.5) * ap))
			var borde_a: float = sin(PI * (s0 + s1) * 0.5)   # mas fuerte en medio del abanico
			var cerca: Color = Color(LUZ, 0.75 * alfa * borde_a)
			var lejos: Color = Color(HUMO, 0.0)
			var medio: Color = Color(LUZ.lerp(HUMO, 0.6), 0.55 * alfa * borde_a)
			capa.draw_primitive(PackedVector2Array([o, o + d0 * frente * 0.55, o + d1 * frente * 0.55]),
				PackedColorArray([cerca, medio, medio]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([o + d0 * frente * 0.55, o + d0 * frente, o + d1 * frente]),
				PackedColorArray([medio, lejos, lejos]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([o + d0 * frente * 0.55, o + d1 * frente, o + d1 * frente * 0.55]),
				PackedColorArray([medio, lejos, medio]), PackedVector2Array())
	if capa == _brillo and k < 1.0:
		BarridoAire.destello(capa, o - Vector2(0.0, 3.0), 14.0 * (1.0 - k * 0.6), Color(BLANCO, 1.0 - k * 0.5), _fase)
	# EL HUMO que se queda y LAS ESQUIRLAS DE LUZ que vuelan con el frente.
	if capa == _delante:
		for pz in _piezas:
			var a: float = a0 + float(pz["u"]) * ap
			var dd := Vector2(cos(a), sin(a))
			var p: Vector2 = o + dd * R * float(pz["d"]) * minf(k / maxf(float(pz["d"]), 0.01), 1.0)
			if bool(pz["luz"]):
				if humo < 0.5:
					BarridoAire.destello(capa, p - Vector2(0.0, 3.0 + 6.0 * humo), 3.5 * float(pz["tam"]) * (1.0 - humo * 2.0),
						Color(AHUMADO_CLARO, 1.0 - humo * 2.0), a)
			elif humo > 0.0:
				BestiaAire._bola(capa, p - Vector2(0.0, float(pz["sube"]) * humo * K), 7.0 * float(pz["tam"]) * (1.0 + humo),
					Color(HUMO, 0.5 * (1.0 - humo)))


# ------------------------------------------------------------
#  EL MORDISCO A TRAICION (los dos remolinos de sombra)
# ------------------------------------------------------------
func _traicion(capa: Node2D) -> void:
	if capa == _brillo:
		return
	for donde in 2:
		# Donde aparece: a la ESPALDA de su presa (un poco mas alla de ella, en la direccion del salto).
		var c: Vector2 = _o if donde == 0 else _c + _dir * 14.0
		var t0: float = 0.0 if donde == 0 else T_SALTO * 0.6
		var k: float = clampf((_t - t0) / T_REMOLINO, 0.0, 1.0)
		if _t < t0 or k >= 1.0:
			continue
		if capa == _suelo:
			BarridoAire.brillo(capa, c, 16.0 * (1.0 - k * 0.5), Color(NEGRO, 0.5 * (1.0 - k)))
			continue
		# DONDE SE VA, el remolino se CIERRA (los jirones giran hacia dentro); DONDE APARECE, se ABRE.
		var cierra: float = k if donde == 0 else 1.0 - k
		for pz in _piezas:
			var a: float = float(pz["a"]) + _t * (9.0 if donde == 0 else -9.0)
			var rr: float = lerpf(22.0, 5.0, cierra) * float(pz["tam"])
			var q: Vector2 = c + Vector2(cos(a), sin(a) * 0.55) * rr - Vector2(0.0, 7.0)
			_jiron(capa, q, a + PI * 0.5, 11.0 * float(pz["tam"]), 8.0, sin(PI * k) * 0.95)
		if k < 0.5:
			BarridoAire.destello(capa, c - Vector2(-3.0, 9.0), 2.2, Color(OJO, (1.0 - k * 2.0) * (1.0 if donde == 1 else 0.0)), 0.0)


# ------------------------------------------------------------
#  SOBRE EL CUERPO
# ------------------------------------------------------------
func _jirones(capa: Node2D) -> void:
	if capa != _delante:
		return
	for pz in _piezas:
		var k: float = clampf((_t - float(pz["t0"])) / (T_GOLPE - float(pz["t0"])), 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var a: float = float(pz["a"])
		var p: Vector2 = _c + Vector2(cos(a), sin(a) * 0.7) * (4.0 + 10.0 * k) - Vector2(0.0, 5.0 * k)
		var tam: float = _r * 0.45 * float(pz["tam"]) * (1.0 + 0.7 * k)
		_jiron(capa, p, a, tam, tam * 0.75, (1.0 - k) * (1.0 - k))


func _esquirlas(capa: Node2D) -> void:
	var k: float = clampf(_t / T_GOLPE, 0.0, 1.0)
	if capa == _brillo:
		if k < 0.3:
			BarridoAire.destello(capa, _c, 11.0 * (1.0 - k / 0.3), Color(_col_cristal().lightened(0.4), 1.0 - k / 0.3), _fase)
		return
	if capa != _delante:
		return
	for pz in _piezas:
		var a: float = float(pz["a"])
		var d := Vector2(cos(a), sin(a))
		var q: Vector2 = _c + d * float(pz["v"]) * k - Vector2(0.0, (sin(PI * k) * float(pz["sube"])) * K)
		_esquirla(capa, q, float(pz["tam"]) * (1.0 - 0.4 * k), a + _t * float(pz["giro"]), 1.0 - k * k)


func _corte(capa: Node2D) -> void:
	var k: float = clampf(_t / T_GOLPE, 0.0, 1.0)
	var claro: Color = AHUMADO_CLARO if _ahumado else CRISTAL_CLARO
	if capa == _delante and k < 0.7:
		# LA MEDIA LUNA DE CRISTAL que le cruza de lado a lado, perpendicular a por donde pasa (dura delante, difuminada
		# detras).
		var a: float = _dir.angle()
		BestiaAire._media_luna(capa, _c - _dir * _r * 0.35, a - 0.9, a + 0.9, _r * 0.55, _r * 0.3, claro, _col_cristal(),
			1.0 - k / 0.7, true)
	_esquirlas(capa)


func _velo(capa: Node2D) -> void:
	if capa != _delante:
		return
	var entra: float = clampf(_t / 0.15, 0.0, 1.0)
	var sale: float = clampf((_t - T_VELO * 0.6) / (T_VELO * 0.4), 0.0, 1.0)
	var alfa: float = entra * (1.0 - sale)
	if alfa <= 0.01:
		return
	# A LA ALTURA DE LOS OJOS: una banda de sombra que le tapa la cara, con su pincelada y motas de luz que se apagan.
	var ojos := Vector2(_caja.get_center().x, _caja.position.y + _caja.size.y * 0.3)
	var w: float = maxf(_caja.size.x, 12.0) * 0.75
	for i in 3:
		var x: float = (float(i) - 1.0) * w * 0.45
		BestiaAire._bola(capa, ojos + Vector2(x, sin(_t * 6.0 + float(i)) * 1.2), w * 0.42, Color(NEGRO, 0.75 * alfa))
	BestiaAire._media_luna(capa, ojos + Vector2(0.0, w * 0.35), -PI * 0.5 - 1.0, -PI * 0.5 + 1.0, w * 0.55, w * 0.25, PINCEL,
		NEGRO, 0.4 * alfa, true)
	for pz in _piezas:
		var q: Vector2 = ojos + Vector2(float(pz["x"]) * w * 1.4, float(pz["y"]) * w * 0.6)
		var luce: float = 0.5 + 0.5 * sin(_t * 8.0 + float(pz["f"]))
		BarridoAire.destello(capa, q, 2.0, Color(AHUMADO_CLARO, alfa * luce), float(pz["f"]))
