# ============================================================
#  magia_mayor.gd
#  LOS EFECTOS DE LAS MAGIAS DE 3 FRASES en el mapa (26/09/2026, los eligio el usuario). Van aparte de MagiaAire
#  (que ya pasa de las 1900 lineas) pero con sus mismas piezas (MagiaAire._anillo, BarridoAire.brillo...).
#  POR EL SUELO (SueloRoto.Tipo.MAGIA_SOL.., en el orden de Modo: no reordenar, viajan por red):
#    SOL       Estallido solar: una CHISPA sale de tu mano con estela de destellos y se para en el sitio; ahi NACE un
#              sol pequeño con su corona de rayos girando, crece, se aprieta un instante y REVIENTA en una onda de luz
#              que llena el circulo del centro hacia fuera; el resplandor que deja se apaga desde el centro.
#    VORAGINE  Voragine de sombra (sus referencias: remolino negro en media luna con pinceladas rotas y un ojo rojo de
#              anillos; "ojos de muerte" negros con iris rojo): un ORBE negro sale de tu mano con estela de humo y se
#              HUNDE en el sitio; se abre un REMOLINO de mechones negros de tinta (26/09, su referencia: llamas oscuras
#              con puntas y vetas grises de pincel girando hacia dentro) con un OJO DE ECLIPSE dorado en medio (pupila
#              negra, aro claro, halo y destello en cruz). En cada tiron los mechones se enroscan y se cierran de golpe,
#              el ojo se enciende y el humo y los trozos caen dentro. Al final se cierra en un punto.
#              (Los ojos de muerte se probaron aqui y no; _ojo_muerte queda para una magia futura.)
#  Criterio (el suyo): siluetas llenas de 3-4 tonos con halo, efecto previo que lo dispare, nada de rayas peladas.
#  Coordenadas de MUNDO; el suelo SIN achatar; lo que va en el aire, a su altura por K. Todo sale de una semilla.
# ============================================================
extends Node2D
class_name MagiaMayor

enum Modo { SOL, VORAGINE, SHOCK, TORMENTA, LUZ }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ALTO_MANO := 12.0

# EL SOL
const T_CARGA_SOL := 0.14        # la chispa se concentra en tu mano
const V_CHISPA := 340.0          # y vuela a esta velocidad hasta el sitio
const T_CRECE := 0.42            # el sol nace y crece
const T_APRIETA := 0.12          # se aprieta antes de reventar
const T_ONDA_SOL := 0.3          # lo que tarda la onda en llegar al borde
const T_RESPLANDOR := 0.75       # y lo que dura el resplandor que deja
const ALTO_SOL := 22.0
const SOL_BLANCO := Color(1.0, 0.99, 0.9)
const SOL_AMARILLO := Color(1.0, 0.86, 0.32)
const SOL_NARANJA := Color(1.0, 0.6, 0.14)
const SOL_ROJIZO := Color(0.88, 0.32, 0.07)

# LA VORAGINE
const V_ORBE_SOMBRA := 300.0
const T_HUNDE := 0.14            # el orbe se mete en el suelo
const T_ABRE_POZO := 0.3         # el pozo se abre hasta su tamaño
const T_PULSO := 0.22            # entre tiron y tiron (los tres golpes)
const TIRONES := 3
const T_CIERRA := 0.35           # y lo que tarda en cerrarse en un punto
const NEGRO := Color(0.03, 0.02, 0.04)
# (26/09: "en vez de rojo usa blanco") negro y blanco, como su dibujo.
const SOMBRA_CLARA := Color(0.95, 0.94, 0.97)
const SOMBRA_GRIS := Color(0.26, 0.24, 0.3)
const BLANCO_OJO := Color(0.96, 0.95, 0.98)
# El remolino de tinta y el ojo de eclipse (su referencia; el eclipse en BLANCO FRIO, 26/09: el dorado se leia como luz).
const TINTA := Color(0.05, 0.04, 0.03)
const TINTA_MEDIA := Color(0.2, 0.17, 0.13)
const TINTA_CLARA := Color(0.58, 0.54, 0.47)
const ECLIPSE := Color(0.55, 0.62, 0.72)
const ECLIPSE_CLARO := Color(0.95, 0.97, 1.0)
const ALTO_OJO_ECLIPSE := 8.0
const PINCEL := Color(0.8, 0.78, 0.84)
const VIOLETA_HONDO := Color(0.24, 0.07, 0.3)

var modo: int = Modo.SOL
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _semilla: int = 1
var _c: Vector2 = Vector2.ZERO       # el centro del circulo (en el suelo)
var _o: Vector2 = Vector2.ZERO       # de donde sale (tus pies)
var _r: float = 30.0
var _motas: Array = []
var _trozos: Array = []
var _rayos: Array = []
var _gotas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> MagiaMayor:
	if padre == null or f == null:
		return null
	var e := MagiaMayor.new()
	e.modo = m
	e.forma = f
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._preparar()
	return e


# DE DONDE SALE lo que se lanza a un circulo: tus pies, 'ancho' px hacia atras por su 'dir' (ver
# CombatTactico.forma_hechizo, que lo guarda ahi porque por red solo viaja el centro).
static func origen(f: CombatFormas.Forma) -> Vector2:
	var d: Vector2 = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	return f.centro - d * f.ancho


# Lo que tarda la chispa (o lo que se lance) en llegar al centro, carga incluida.
static func t_llega(f: CombatFormas.Forma) -> float:
	return T_CARGA_SOL + maxf(f.ancho - 6.0, 0.0) / V_CHISPA


# CUANDO LE LLEGA a 'p', en segundos desde que se lanza.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.SOL:
			var u: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
			# La onda avanza como 1 - (1 - k)^2: llega a 'u' en k = 1 - sqrt(1 - u).
			return t_llega(f) + T_CRECE + T_APRIETA + T_ONDA_SOL * (1.0 - sqrt(1.0 - u))
		Modo.VORAGINE:
			# El primer tiron, con el pozo ya abierto (los otros dos van detras, al paso de los golpes).
			return t_llega_orbe(f) + T_HUNDE + T_ABRE_POZO
	return 0.0


static func t_llega_orbe(f: CombatFormas.Forma) -> float:
	return T_CARGA_SOL + maxf(f.ancho - 6.0, 0.0) / V_ORBE_SOMBRA


static func t_salir(m: int) -> float:
	match m:
		Modo.SOL: return T_CARGA_SOL + T_CRECE + T_APRIETA + T_ONDA_SOL
		Modo.VORAGINE: return T_CARGA_SOL + T_HUNDE + T_ABRE_POZO
	return 0.3


func duracion() -> float:
	match modo:
		Modo.SOL: return t_llega(forma) + T_CRECE + T_APRIETA + T_ONDA_SOL + T_RESPLANDOR + 0.3
		Modo.VORAGINE: return _t_cierra() + T_CIERRA + 0.3
	return 1.0


# Desde que se lanza hasta que el pozo empieza a cerrarse: se queda abierto un rato tras el ultimo tiron.
func _t_cierra() -> float:
	return t_llega_orbe(forma) + T_HUNDE + T_ABRE_POZO + T_PULSO * float(TIRONES) + 0.35


func _preparar() -> void:
	_c = forma.centro
	_o = origen(forma)
	_r = maxf(forma.radio, 8.0)
	match modo:
		Modo.SOL:
			# Motas de luz que se meten en tu mano (la carga) y las que el sol se traga al apretarse.
			for i in 10:
				_motas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(12.0, 22.0),
					"t0": _rng.randf_range(0.0, 0.05), "tam": _rng.randf_range(1.2, 2.0)})
			# Los TROZOS de luz que salen despedidos al reventar (siluetas de destello, no puntos).
			for i in 22:
				var a: float = _rng.randf_range(0.0, TAU)
				_trozos.append({"d": Vector2(cos(a), sin(a)), "v": _rng.randf_range(0.7, 1.15),
					"sube": _rng.randf_range(10.0, 40.0), "tam": _rng.randf_range(3.0, 6.0), "giro": _rng.randf_range(0.0, TAU)})
			# Los RAYOS ANCHOS del estallido: cuñas rellenas que salen del centro.
			for i in 8:
				_rayos.append({"a": TAU * float(i) / 8.0 + _rng.randf_range(-0.12, 0.12),
					"largo": _rng.randf_range(0.8, 1.05), "ancho": _rng.randf_range(0.2, 0.28)})
		Modo.VORAGINE:
			for i in 10:
				_motas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(12.0, 22.0),
					"t0": _rng.randf_range(0.0, 0.05), "tam": _rng.randf_range(1.4, 2.4)})
			# Los OJOS DE MUERTE alrededor del area: donde, cuanto miden, su giro y cuando se abren.
			# Los MECHONES del remolino: de fuera hacia dentro, cada uno una llama de tinta que se enrosca.
			for i in 42:
				var d0: float = _rng.randf_range(0.25, 1.0)
				_rayos.append({"a": _rng.randf_range(0.0, TAU), "d": d0, "vuelta": _rng.randf_range(0.9, 1.7),
					"cae": _rng.randf_range(0.18, 0.42), "ancho": _rng.randf_range(0.08, 0.14) * (0.6 + 0.6 * d0),
					"sem": _rng.randf_range(0.0, 50.0), "claro": _rng.randf() < 0.45, "t0": _rng.randf_range(0.0, 0.18) * (1.0 - d0)})
			# Gotas de tinta sueltas alrededor.
			for i in 14:
				_gotas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(0.9, 1.2), "t0": _rng.randf_range(0.0, 0.3),
					"tam": _rng.randf_range(0.8, 1.8)})
			# El HUMO y los TROZOS de suelo que el pozo arrastra hacia dentro.
			for i in 26:
				_trozos.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(0.5, 1.1), "tam": _rng.randf_range(2.0, 4.5),
					"t0": _rng.randf_range(0.0, T_PULSO * float(TIRONES) + 0.2), "piedra": _rng.randf() < 0.4,
					"giro": _rng.randf_range(0.0, TAU)})
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


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.SOL: _sol(capa)
		Modo.VORAGINE: _voragine(capa)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
static func _alto(h: float) -> Vector2:
	return Vector2(0.0, -h * K)


# UNA ESTRELLA RELLENA de 'n' puntas (la corona del sol): radio de dentro 'r_in', puntas hasta 'r_out' (las pares
# mas largas), color del centro al borde. 'achata' la aplasta en vertical (en el aire, 1; en el suelo, 1).
static func _estrella(ci: CanvasItem, c: Vector2, r_in: float, r_out: float, n: int, giro: float, col_c: Color,
		col_b: Color, alterna: float = 0.6) -> void:
	if r_out <= 0.3 or col_c.a <= 0.0:
		return
	var pv := PackedVector2Array([c])
	var pc := PackedColorArray([col_c])
	var pi := PackedInt32Array()
	var m: int = n * 2
	for i in m:
		var a: float = giro + TAU * float(i) / float(m)
		var rr: float = r_in
		if i % 2 == 0:
			rr = r_out if (i >> 1) & 1 == 0 else lerpf(r_in, r_out, alterna)
		pv.append(c + Vector2(cos(a), sin(a)) * rr)
		pc.append(col_b)
	for i in m:
		pi.append_array([0, 1 + i, 1 + (i + 1) % m])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# UN DISCO relleno de un color con el borde de otro (sin rayas: el borde es un degradado).
static func _disco(ci: CanvasItem, c: Vector2, r: float, col_c: Color, col_b: Color, achata: float = 1.0) -> void:
	if r <= 0.3:
		return
	var pv := PackedVector2Array([c])
	var pc := PackedColorArray([col_c])
	var pi := PackedInt32Array()
	var n: int = 24
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pv.append(c + Vector2(cos(a), sin(a) * achata) * r)
		pc.append(col_b)
	for i in n:
		pi.append_array([0, 1 + i, 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# UNA CUÑA de luz rellena desde 'c' hacia 'a' radianes (un petalo ancho), que se apaga en la punta.
static func _cuna(ci: CanvasItem, c: Vector2, a: float, r0: float, r1: float, abre: float, col: Color, achata: float = 1.0) -> void:
	if r1 <= r0 or col.a <= 0.0:
		return
	var d := Vector2(cos(a), sin(a) * achata)
	var n := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5) * achata)
	# Un PETALO: nace en r0, es mas ancho a un tercio del largo y se afila hasta la punta.
	var medio: float = lerpf(r0, r1, 0.35)
	var w: float = r1 * tan(abre) * 0.5 + 1.5
	var p0: Vector2 = c + d * r0
	var pm: Vector2 = c + d * medio
	var punta: Vector2 = c + d * r1
	ci.draw_primitive(PackedVector2Array([p0, pm + n * w, pm - n * w]), PackedColorArray([col, col, col]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([pm + n * w, punta, pm - n * w]),
		PackedColorArray([col, Color(col, 0.0), col]), PackedVector2Array())


# ------------------------------------------------------------
#  EL SOL (Estallido solar)
# ------------------------------------------------------------
const LENGUAS_SOL := 11

# UNA LENGUA DE LLAMA que sale del borde del sol y se curva al girar (tono plano, sin degradado: silueta de las de sus
# referencias). Nace en el angulo 'a' a 'r0' del centro, mide 'largo', se tuerce 'curva' radianes y afila hasta la punta.
static func _lengua_sol(ci: CanvasItem, c: Vector2, a: float, r0: float, largo: float, curva: float, ancho: float,
		col: Color) -> void:
	if largo <= 0.5 or col.a <= 0.0:
		return
	var n: int = 7
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for k in n + 1:
		var u: float = float(k) / float(n)
		var ang: float = a + curva * u * u
		var d := Vector2(cos(ang), sin(ang))
		var eje: Vector2 = c + d * (r0 + largo * u)
		var w: float = ancho * pow(1.0 - u, 0.75) * (0.75 + 0.5 * sin(minf(u * 2.2, 1.0) * PI * 0.5))
		var t := Vector2(-d.y, d.x)
		pv.append(eje + t * w)
		pv.append(eje - t * w)
		pc.append(col)
		pc.append(col)
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# EL CUERPO DEL SOL (26/09, "mejoralo, sobre todo el sol"): corona de LENGUAS de llama curvas que giran, en capas de
# tonos planos (rojiza fuera, naranja, amarilla), un aro naranja, el disco amarillo con MANCHAS (huecos de negativo),
# un anillo claro que gira en espiral por dentro, el nucleo blanco y GOTITAS de llama sueltas que orbitan. 'corona'
# (1 -> 0) recoge las lenguas al apretarse y 'blanco' (0 -> 1) lo quema todo a blanco.
func _cuerpo_sol(ci: CanvasItem, sol: Vector2, rr: float, corona: float, blanco: float) -> void:
	var paso: float = floor(_t * 14.0)                     # las llamas cambian a saltos, como el fuego de pixel
	var giro: float = _t * 2.2
	var capas: Array = [
		[SOL_ROJIZO, 1.0, 0.55, 0.0],
		[SOL_NARANJA, 0.72, 0.42, 0.33],
		[SOL_AMARILLO, 0.45, 0.3, 0.66]]
	for cp in capas:
		var col: Color = (cp[0] as Color).lerp(SOL_BLANCO, blanco * 0.8)
		for i in LENGUAS_SOL:
			var a: float = giro + TAU * (float(i) + float(cp[3])) / float(LENGUAS_SOL)
			var salto: float = MagiaAire._ruido(float(i) + paso * 1.7, float(cp[3]) * 9.0 + float(_semilla % 31))
			var largo: float = rr * (0.7 + 0.9 * salto) * float(cp[1]) * corona
			_lengua_sol(ci, sol, a, rr * 0.8, largo, 0.85, rr * float(cp[2]), col)
	# GOTITAS de llama sueltas que orbitan y se escapan de las puntas.
	for i in 7:
		var ag: float = -giro * 0.7 + TAU * float(i) / 7.0
		var dg: float = rr * (1.75 + 0.35 * sin(_t * 5.0 + float(i) * 2.0)) * (0.4 + 0.6 * corona)
		var pg: Vector2 = sol + Vector2(cos(ag), sin(ag)) * dg
		_lengua_sol(ci, pg + Vector2(cos(ag - 1.2), sin(ag - 1.2)) * rr * 0.12, ag + PI * 0.5 + PI, 0.0, rr * 0.35, 0.6,
			rr * 0.1, Color(SOL_NARANJA.lerp(SOL_BLANCO, blanco), 0.95 * corona))
	# EL DISCO: aro naranja, disco amarillo, manchas, espiral y nucleo.
	_disco(ci, sol, rr * 1.04, SOL_NARANJA.lerp(SOL_BLANCO, blanco), SOL_NARANJA.lerp(SOL_BLANCO, blanco))
	_disco(ci, sol, rr * 0.9, SOL_AMARILLO.lerp(SOL_BLANCO, blanco), SOL_AMARILLO.lerp(SOL_BLANCO, blanco))
	if blanco < 0.9:
		for i in 4:
			var am: float = giro * 0.6 + TAU * float(i) / 4.0 + 0.4 * MagiaAire._ruido(float(i), 5.0)
			var pm: Vector2 = sol + Vector2(cos(am), sin(am)) * rr * (0.55 + 0.15 * MagiaAire._ruido(float(i), 7.0))
			_disco(ci, pm, rr * (0.1 + 0.05 * MagiaAire._ruido(float(i), 3.0)), Color(SOL_NARANJA, 1.0 - blanco),
				Color(SOL_NARANJA, 1.0 - blanco), 0.8)
	# El anillo claro en espiral: tres arcos rellenos que giran por dentro.
	for i in 3:
		var a0: float = -giro * 1.4 + TAU * float(i) / 3.0
		for k in 5:
			var u0: float = float(k) / 5.0
			var u1: float = float(k + 1) / 5.0
			var q0 := Vector2(cos(a0 + u0 * 1.4), sin(a0 + u0 * 1.4)) * rr * lerpf(0.42, 0.72, u0)
			var q1 := Vector2(cos(a0 + u1 * 1.4), sin(a0 + u1 * 1.4)) * rr * lerpf(0.42, 0.72, u1)
			var w0: float = rr * 0.09 * (1.0 - u0 * 0.7)
			var w1: float = rr * 0.09 * (1.0 - u1 * 0.7)
			var n0: Vector2 = q0.normalized() * w0
			var n1: Vector2 = q1.normalized() * w1
			ci.draw_primitive(PackedVector2Array([sol + q0 - n0, sol + q0 + n0, sol + q1 + n1]),
				PackedColorArray([SOL_BLANCO, SOL_BLANCO, SOL_BLANCO]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([sol + q0 - n0, sol + q1 + n1, sol + q1 - n1]),
				PackedColorArray([SOL_BLANCO, SOL_BLANCO, SOL_BLANCO]), PackedVector2Array())
	_disco(ci, sol + Vector2(-rr * 0.08, -rr * 0.1), rr * (0.38 + 0.3 * blanco), SOL_BLANCO, SOL_BLANCO)


func _pos_chispa(u: float) -> Vector2:
	# De tu mano al sitio del sol, en un arco suave hacia arriba.
	var a: Vector2 = _o + _alto(ALTO_MANO)
	var b: Vector2 = _c + _alto(ALTO_SOL)
	return a.lerp(b, u) + _alto(12.0 * sin(u * PI))


func _sol(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var tl: float = t_llega(forma)
	var t_nace: float = _t - tl                              # desde que la chispa llega al sitio
	var t_rev: float = t_nace - T_CRECE - T_APRIETA          # desde que revienta
	var sol: Vector2 = _c + _alto(ALTO_SOL)
	var r_sol: float = clampf(_r * 0.22, 12.0, 26.0)
	var giro: float = _t * 1.6
	# 1) LA CARGA en tu mano y 2) EL VUELO de la chispa.
	if t_nace < 0.0:
		if capa != _brillo:
			return
		var mano: Vector2 = _o + _alto(ALTO_MANO)
		if _t < T_CARGA_SOL:
			var kc: float = _t / T_CARGA_SOL
			for m in _motas:
				var km: float = clampf((_t - float(m["t0"])) / (T_CARGA_SOL - float(m["t0"])), 0.0, 1.0)
				var desde: Vector2 = mano + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * float(m["d"])
				BarridoAire.cometa(capa, desde.lerp(mano, maxf(0.0, km * km - 0.2)), desde.lerp(mano, km * km),
					float(m["tam"]) * 1.4, Color(SOL_AMARILLO, 0.85))
			BarridoAire.brillo(capa, mano, 5.0 + 9.0 * kc, Color(SOL_NARANJA, 0.5 * kc))
			BarridoAire.destello(capa, mano, 5.0 + 7.0 * kc, Color(SOL_BLANCO, kc), _t * 6.0)
			return
		var u: float = clampf((_t - T_CARGA_SOL) / maxf(tl - T_CARGA_SOL, 0.01), 0.0, 1.0)
		var p: Vector2 = _pos_chispa(u)
		# La ESTELA: cometas doradas que se afinan y destellos pequeños que se quedan atras parpadeando.
		for k in 6:
			var ua: float = clampf(u - 0.045 * float(k + 1), 0.0, 1.0)
			var ub: float = clampf(u - 0.045 * float(k), 0.0, 1.0)
			BarridoAire.cometa(capa, _pos_chispa(ua), _pos_chispa(ub), 6.0 - 0.8 * float(k),
				Color(SOL_NARANJA.lerp(SOL_AMARILLO, 1.0 - float(k) / 6.0), 0.75 * (1.0 - float(k) / 6.0)))
		for k2 in 5:
			var ut: float = u - 0.08 * float(k2 + 1)
			if ut < 0.0:
				break
			var q: Vector2 = _pos_chispa(ut) + Vector2(sin(float(k2) * 2.1 + _t * 9.0) * 3.0, 6.0 * float(k2 + 1) * 0.08)
			BarridoAire.destello(capa, q, 5.0 - 0.6 * float(k2), Color(SOL_AMARILLO, 0.8 - 0.14 * float(k2)), float(k2) + _t * 5.0)
		BarridoAire.brillo(capa, p, 13.0, Color(SOL_NARANJA, 0.5))
		BarridoAire.brillo(capa, p, 5.0, Color(SOL_BLANCO, 1.0))
		BarridoAire.destello(capa, p, 11.0, Color(SOL_BLANCO, 0.85), _t * 8.0)
		return
	# 3) EL SOL que nace, crece y se aprieta.
	if t_rev < 0.0:
		var kn: float = clampf(t_nace / T_CRECE, 0.0, 1.0)
		var crece: float = 1.0 - pow(1.0 - kn, 3.0)
		var aprieta: float = clampf((t_nace - T_CRECE) / T_APRIETA, 0.0, 1.0)
		var rr: float = r_sol * (0.25 + 0.75 * crece) * (1.0 - 0.3 * aprieta * aprieta)
		var corona: float = (1.0 - 0.6 * aprieta)
		# El latido: un pelo mas grande y mas chico, cada vez mas rapido.
		rr *= 1.0 + 0.05 * sin(t_nace * (18.0 + 30.0 * kn))
		if capa == _suelo:
			# La LUZ en el suelo bajo el sol, que crece con el; y su sombra calida justo debajo.
			BarridoAire.brillo(capa, _c, _r * (0.25 + 0.5 * crece), Color(SOL_NARANJA, 0.22 + 0.2 * aprieta))
			BarridoAire.brillo(capa, _c, rr * 1.2, Color(SOL_AMARILLO, 0.35 + 0.3 * aprieta))
			return
		if capa == _delante:
			_cuerpo_sol(capa, sol, rr, corona, aprieta)
			return
		if capa == _brillo:
			BarridoAire.brillo(capa, sol, rr * 3.2, Color(SOL_NARANJA, 0.35 + 0.25 * aprieta))
			BarridoAire.brillo(capa, sol, rr * 1.6, Color(SOL_AMARILLO, 0.35 + 0.4 * aprieta))
			# Motas que se traga al apretarse.
			if aprieta > 0.0:
				for m in _motas:
					var da: float = float(m["d"]) * 1.8 * (1.0 - aprieta)
					var pm: Vector2 = sol + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * (rr + da)
					BarridoAire.brillo(capa, pm, float(m["tam"]) * 1.5, Color(SOL_BLANCO, aprieta))
			return
		return
	# 4) EL ESTALLIDO: la onda que llena el circulo, los rayos anchos, los trozos y el resplandor que se apaga desde el
	#    centro.
	var ko: float = clampf(t_rev / T_ONDA_SOL, 0.0, 1.0)
	var frente: float = _r * (1.0 - pow(1.0 - ko, 2.0))
	var t_apaga: float = t_rev - T_ONDA_SOL
	var ka: float = clampf(t_apaga / T_RESPLANDOR, 0.0, 1.0)
	if capa == _suelo:
		# El SUELO ENCENDIDO: un disco dorado hasta el frente; al acabar la onda se vacia desde el centro (el hueco crece
		# hasta el borde) y lo que queda se enfria a naranja.
		var hueco: float = _r * (1.0 - pow(1.0 - ka, 2.0))
		if ka <= 0.0:
			BarridoAire.brillo(capa, _c, frente * 1.05, Color(SOL_AMARILLO, 0.5))
			_disco(capa, _c, frente, Color(SOL_BLANCO, 0.35), Color(SOL_NARANJA, 0.3))
		elif ka < 1.0:
			MagiaAire._anillo(capa, _c, lerpf(hueco, _r, 0.5), maxf((_r - hueco) * 0.6, 2.0),
				Color(SOL_NARANJA.lerp(SOL_ROJIZO, ka), 0.5 * (1.0 - ka)))
		# El frente de la onda por el suelo: anillo grueso y dorado con el borde blanco.
		if ko < 1.0:
			MagiaAire._anillo(capa, _c, frente, 9.0, Color(SOL_AMARILLO, 0.9 * (1.0 - ko * 0.4)))
			MagiaAire._anillo(capa, _c, frente, 3.5, Color(SOL_BLANCO, 1.0 - ko * 0.5))
		return
	if capa == _delante:
		# Los RAYOS ANCHOS que salen del centro por el suelo (cuñas rellenas de dos tonos), hasta mas alla del frente.
		if ko < 1.0 or ka < 0.4:
			var alfa_r: float = (1.0 - ko * 0.3) * (1.0 - clampf(ka / 0.4, 0.0, 1.0))
			for ry in _rayos:
				var largo_r: float = minf(frente * 1.15, _r * float(ry["largo"]) * 1.15)
				var a_r: float = float(ry["a"]) + giro * 0.2
				_cuna(capa, _c, a_r, 6.0, largo_r, float(ry["ancho"]), Color(SOL_NARANJA, 0.7 * alfa_r))
				_cuna(capa, _c, a_r, 5.0, largo_r * 0.85, float(ry["ancho"]) * 0.65, Color(SOL_AMARILLO, 0.85 * alfa_r))
				_cuna(capa, _c, a_r, 4.0, largo_r * 0.6, float(ry["ancho"]) * 0.35, Color(SOL_BLANCO, 0.95 * alfa_r))
		# Los TROZOS DE LUZ que saltan del centro y caen: estrellitas rellenas que giran.
		if t_rev < 0.7:
			var kt: float = t_rev / 0.7
			for tz in _trozos:
				var d: float = _r * float(tz["v"]) * (1.0 - pow(1.0 - minf(1.0, kt * 1.4), 2.0))
				var h: float = float(tz["sube"]) * sin(minf(1.0, kt * 1.2) * PI) + ALTO_SOL * (1.0 - minf(1.0, kt * 2.0))
				var pt: Vector2 = _c + (tz["d"] as Vector2) * d + _alto(h)
				var tam: float = float(tz["tam"]) * (1.0 - kt * 0.7)
				_estrella(capa, pt, tam * 0.3, tam, 4, float(tz["giro"]) + t_rev * 7.0, Color(SOL_BLANCO, 1.0 - kt),
					Color(SOL_AMARILLO, 0.8 * (1.0 - kt)), 0.45)
		return
	if capa == _brillo:
		# EL FOGONAZO en el sitio del sol, el destello grande y la onda de luz en el aire (un velo que se abre).
		if t_rev < 0.18:
			var kf: float = t_rev / 0.18
			BarridoAire.brillo(capa, sol, r_sol * 5.0 * (1.0 - kf * 0.5), Color(SOL_BLANCO, 0.75 * (1.0 - kf)))
		if t_rev < 0.45:
			var kd: float = t_rev / 0.45
			BarridoAire.destello(capa, sol, r_sol * 3.4 * (1.0 - kd * 0.5), Color(SOL_BLANCO, 1.0 - kd), 0.3 + kd * 0.4)
		if ko < 1.0:
			BarridoAire.brillo(capa, _c + _alto(6.0), frente * 1.1, Color(SOL_NARANJA, 0.22 * (1.0 - ko)))


# ------------------------------------------------------------
#  LA VORAGINE (Voragine de sombra)
# ------------------------------------------------------------
# Lo apretado que esta el remolino a los 'tp' segundos desde que se abre el pozo: un golpe seco en cada tiron que se
# suelta despacio (0 suelto, 1 en el pico).
static func _aprieton(tp: float) -> float:
	var v: float = 0.0
	for k in TIRONES:
		var dt: float = tp - T_ABRE_POZO - T_PULSO * float(k)
		if dt >= 0.0 and dt < T_PULSO * 1.4:
			v = maxf(v, exp(-dt * 14.0) * minf(1.0, dt * 40.0))
	return v


# UN BRAZO DEL REMOLINO: media luna negra que se enrosca de 'r_out' a 'r_in' (en el SUELO, sin achatar), mas gorda
# por el medio, con su PINCELADA clara rota por el borde de fuera (las pinceladas blancas de su referencia).
func _brazo(ci: CanvasItem, c: Vector2, a0: float, r_in: float, r_out: float, vuelta: float, grueso: float, alfa: float,
		sem: float) -> void:
	var n: int = 14
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	var bordes: Array = []
	for k in n + 1:
		var u: float = float(k) / float(n)
		var ang: float = a0 + vuelta * u
		var rr: float = lerpf(r_out, r_in, u)
		var d := Vector2(cos(ang), sin(ang))
		var w: float = grueso * sin(u * PI) * (0.85 + 0.3 * MagiaAire._ruido(float(k), sem))
		pv.append(c + d * (rr + w))
		pv.append(c + d * maxf(rr - w * 0.4, 0.0))
		pc.append(Color(NEGRO, alfa))
		pc.append(Color(NEGRO, alfa))
		bordes.append([c + d * (rr + w), d, w, u])
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
	# La pincelada: trozos cortos y afilados por fuera del brazo, con huecos (no una raya seguida).
	for k in n:
		if MagiaAire._ruido(float(k) * 1.7, sem + 3.0) < 0.35:
			continue
		var e0: Array = bordes[k]
		var e1: Array = bordes[k + 1]
		var off0: Vector2 = (e0[1] as Vector2) * (1.5 + float(e0[2]) * 0.25)
		var off1: Vector2 = (e1[1] as Vector2) * (1.5 + float(e1[2]) * 0.25)
		var g0: float = 0.4 + 1.3 * sin(float(e0[3]) * PI)
		var g1: float = 0.4 + 1.3 * sin(float(e1[3]) * PI)
		var p0: Vector2 = (e0[0] as Vector2) + off0
		var p1: Vector2 = (e1[0] as Vector2) + off1
		var t: Vector2 = (p1 - p0).normalized().orthogonal()
		ci.draw_primitive(PackedVector2Array([p0 - t * g0, p1 - t * g1 * 0.2, p1 + t * g1 * 0.2, p0 + t * g0]),
			PackedColorArray([Color(PINCEL, alfa), Color(PINCEL, 0.0), Color(PINCEL, 0.0), Color(PINCEL, alfa)]),
			PackedVector2Array())


# ANILLOS ROJOS ROTOS alrededor de 'c' (el ojo del centro del pozo, su referencia): arcos rellenos con huecos que giran.
static func _anillos_rotos(ci: CanvasItem, c: Vector2, r: float, giro: float, alfa: float) -> void:
	if r <= 0.5:
		return
	_disco(ci, c, r * 1.1, Color(NEGRO, alfa), Color(NEGRO, alfa))
	var radios: Array = [0.95, 0.72, 0.5]
	for j in radios.size():
		var rr: float = r * float(radios[j])
		var trozos: int = 5 + j * 2
		for k in trozos:
			var a0: float = giro * (1.0 if j % 2 == 0 else -1.3) + TAU * float(k) / float(trozos)
			var a1: float = a0 + TAU / float(trozos) * 0.62
			var m: int = 4
			for q in m:
				var b0: float = lerpf(a0, a1, float(q) / float(m))
				var b1: float = lerpf(a0, a1, float(q + 1) / float(m))
				var w: float = r * 0.09
				var d0 := Vector2(cos(b0), sin(b0))
				var d1 := Vector2(cos(b1), sin(b1))
				var cr := Color(SOMBRA_CLARA, alfa)
				ci.draw_primitive(PackedVector2Array([c + d0 * (rr - w), c + d0 * (rr + w), c + d1 * (rr + w), c + d1 * (rr - w)]),
					PackedColorArray([cr, cr, cr, cr]), PackedVector2Array())
	_disco(ci, c, r * 0.24, Color(SOMBRA_CLARA, alfa), Color(SOMBRA_CLARA, alfa))
	_disco(ci, c, r * 0.12, Color(NEGRO, alfa), Color(NEGRO, alfa))


# UN OJO DE MUERTE (su referencia): almendra negra de borde de pincel con una punta larga a un lado y un gancho al otro,
# dentro un iris ROJO con anillos negros que se aplastan contra los parpados. 'abre' 0 cerrado .. 1 abierto; 'mira'
# mueve la pupila (-1..1 a lo largo). 'cola' pone la punta a un lado u otro.
# CURVADO (su dibujo, 26/09: "los ojos en los bordes tienen que quedar con la curvatura"): con 'arco_r' > 0 el ojo se
# dobla sobre el circulo de centro 'arco_c' y radio 'arco_r'; 'giro' es entonces su angulo en ese circulo y 'c' no
# se usa (a lo largo = por el borde; hacia fuera = y negativa, el parpado de arriba mira hacia fuera).
var _arco_c: Vector2 = Vector2.ZERO
var _arco_r: float = 0.0
var _arco_a: float = 0.0
const ARCO_INCLINA := 0.32

func _ojo_p(c: Vector2, eje: Vector2, nor: Vector2, q: Vector2) -> Vector2:
	if _arco_r <= 0.0:
		return c + eje * q.x + nor * q.y
	var a: float = _arco_a + q.x / _arco_r
	# Inclinado: la punta (x > 0) se abre hacia fuera, como las hojas de un molinillo.
	return _arco_c + Vector2(cos(a), sin(a)) * (_arco_r - q.y + q.x * ARCO_INCLINA)


func _ojo_muerte(ci: CanvasItem, c: Vector2, largo: float, giro: float, abre: float, mira: float, cola: float,
		sem: float, alfa: float) -> void:
	if abre <= 0.02 or alfa <= 0.0:
		return
	var alto: float = largo * 0.2 * abre
	var eje := Vector2(cos(giro), sin(giro))
	var nor := Vector2(-eje.y, eje.x)
	_arco_a = giro
	var n: int = 12
	var arriba: Array = []
	var abajo: Array = []
	for k in n + 1:
		var u: float = float(k) / float(n)
		var x: float = (u - 0.5) * largo
		var cur: float = pow(sin(u * PI), 0.7)
		var diente: float = 0.8 + 0.4 * MagiaAire._ruido(float(k), sem)
		arriba.append(Vector2(x, -alto * cur * diente - 1.2))
		abajo.append(Vector2(x, alto * 0.8 * cur * (0.85 + 0.3 * MagiaAire._ruido(float(k), sem + 1.0)) + 1.2))
	# Punta larga del lado de la cola y gancho del otro.
	var punta := Vector2(cola * largo * 0.9, -alto * 0.6 - largo * 0.12)
	var gancho := Vector2(-cola * largo * 0.56, alto * 0.25)
	var pts: Array = []
	for q in arriba:
		pts.append(q)
	for i in range(abajo.size() - 1, -1, -1):
		pts.append(abajo[i])
	var poly := PackedVector2Array()
	for i in pts.size():
		var q: Vector2 = pts[i]
		poly.append(_ojo_p(c, eje, nor, q))
		if i == n:
			poly.append(_ojo_p(c, eje, nor, punta if cola > 0.0 else gancho))
		elif i == pts.size() - 1:
			poly.append(_ojo_p(c, eje, nor, gancho if cola > 0.0 else punta))
	if Geometry2D.triangulate_polygon(poly).size() > 0:
		ci.draw_colored_polygon(poly, Color(NEGRO, alfa))
	# (26/09, su referencia del ojo: "intenta que sean asi" y "en vez de rojo usa blanco") dentro, una MEDIA LUNA
	# blanca que sigue el parpado de arriba; el IRIS de anillos blancos rotos hacia la punta; y por fuera PINCELADAS
	# blancas rotas.
	if alto > 1.2:
		var luna := PackedVector2Array()
		var n_l: int = 10
		for k in n_l + 1:
			var u: float = lerpf(0.12, 0.72, float(k) / float(n_l))
			var x: float = (u - 0.5) * largo
			var cur: float = pow(sin(u * PI), 0.7)
			var g: float = alto * 0.22 * sin(float(k) / float(n_l) * PI)
			luna.append(_ojo_p(c, eje, nor, Vector2(x, -alto * cur * 0.42 - g)))
		for k in range(n_l, -1, -1):
			var u2: float = lerpf(0.12, 0.72, float(k) / float(n_l))
			var x2: float = (u2 - 0.5) * largo
			var cur2: float = pow(sin(u2 * PI), 0.7)
			var g2: float = alto * 0.22 * sin(float(k) / float(n_l) * PI)
			luna.append(_ojo_p(c, eje, nor, Vector2(x2, -alto * cur2 * 0.42 + g2)))
		if Geometry2D.triangulate_polygon(luna).size() > 0:
			ci.draw_colored_polygon(luna, Color(BLANCO_OJO, alfa))
		# El iris: anillos blancos rotos que giran, hacia la punta del ojo.
		var iris: Vector2 = _ojo_p(c, eje, nor, Vector2(largo * (0.16 + 0.05 * mira), alto * 0.18))
		_anillos_rotos(ci, iris, alto * 0.72, _t * 3.0 + sem, alfa)
		# Las pinceladas blancas por fuera del parpado de arriba (el borde de fuera del ojo), con huecos.
		for k in n:
			if MagiaAire._ruido(float(k) * 1.3, sem + 5.0) < 0.4:
				continue
			var e0: Vector2 = arriba[k]
			var e1: Vector2 = arriba[k + 1]
			var w0: float = 0.5 + 1.2 * sin(float(k) / float(n) * PI)
			var p0: Vector2 = _ojo_p(c, eje, nor, e0 + Vector2(0.0, -2.2))
			var p1: Vector2 = _ojo_p(c, eje, nor, e1 + Vector2(0.0, -2.2 - w0 * 0.5))
			var t: Vector2 = (p1 - p0).normalized().orthogonal()
			ci.draw_primitive(PackedVector2Array([p0 - t * w0, p1, p0 + t * w0]),
				PackedColorArray([Color(BLANCO_OJO, alfa), Color(BLANCO_OJO, 0.0), Color(BLANCO_OJO, alfa)]),
				PackedVector2Array())


# UN MECHON DE TINTA: una llama oscura que se enrosca alrededor de 'c' (en el SUELO, sin achatar) de 'r0' a 'r1' en
# 'vuelta' radianes; gorda a un tercio, con la cola afilada hacia fuera y la cabeza redonda hacia dentro, y un par
# de PUNTAS que le salen por fuera (las llamas con pinchos de su referencia).
func _mechon(ci: CanvasItem, c: Vector2, a0: float, r0: float, r1: float, vuelta: float, ancho: float, col: Color,
		sem: float, puntas: bool) -> void:
	if ancho <= 0.3 or col.a <= 0.0:
		return
	var n: int = 12
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for k in n + 1:
		var u: float = float(k) / float(n)
		var ang: float = a0 + vuelta * u
		var rr: float = lerpf(r0, r1, u)
		var d := Vector2(cos(ang), sin(ang))
		# De dentro (u = 0, redondeada) a fuera (u = 1, afilada).
		var w: float = ancho * pow(sin(minf(u * 1.5, 1.0) * PI * 0.5), 0.6) * pow(1.0 - u, 0.9)
		w = maxf(w, ancho * 0.25 * (1.0 - u))
		pv.append(c + d * (rr + w))
		pv.append(c + d * maxf(rr - w, 0.0))
		pc.append(col)
		pc.append(col)
	for k in n:
		var b: int = k * 2
		pi.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
	if not puntas:
		return
	for j in 2:
		var u2: float = 0.35 + 0.3 * float(j) + 0.1 * MagiaAire._ruido(sem, float(j))
		var ang2: float = a0 + vuelta * u2
		var rr2: float = lerpf(r0, r1, u2)
		var d2 := Vector2(cos(ang2), sin(ang2))
		var t2 := Vector2(-d2.y, d2.x) * signf(vuelta)
		var w2: float = ancho * 0.55
		var base: Vector2 = c + d2 * (rr2 + w2 * 0.6)
		var punta: Vector2 = base + (d2 * 0.9 + t2 * 0.8).normalized() * ancho * (1.6 + MagiaAire._ruido(sem, 4.0 + float(j)))
		ci.draw_primitive(PackedVector2Array([base - t2 * w2, punta, base + t2 * w2]), PackedColorArray([col, col, col]),
			PackedVector2Array())


func _voragine(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var tl: float = t_llega_orbe(forma)
	var t_hunde: float = _t - tl
	var tp: float = t_hunde - T_HUNDE                         # desde que se abre el pozo
	var abre: float = 1.0 - pow(1.0 - clampf(tp / T_ABRE_POZO, 0.0, 1.0), 3.0)
	var cierra: float = clampf((_t - _t_cierra()) / T_CIERRA, 0.0, 1.0)
	var vivo: float = abre * (1.0 - cierra * cierra)
	var ap: float = _aprieton(tp)
	# El giro acelera en cada tiron (se enrosca de golpe) y el pozo se encoge un poco.
	var giro: float = -_t * 2.4 - ap * 0.9 - float(clampi(int((tp - T_ABRE_POZO) / T_PULSO) + 1, 0, TIRONES)) * 0.9
	var r_pozo: float = _r * 0.34 * vivo * (1.0 - 0.18 * ap)
	# 1) CARGA y ORBE hasta el sitio.
	if t_hunde < 0.0:
		if capa != _brillo and capa != _delante:
			return
		var mano: Vector2 = _o + _alto(ALTO_MANO)
		if _t < T_CARGA_SOL:
			if capa != _delante:
				return
			var kc: float = _t / T_CARGA_SOL
			for m in _motas:
				var km: float = clampf((_t - float(m["t0"])) / (T_CARGA_SOL - float(m["t0"])), 0.0, 1.0)
				var desde: Vector2 = mano + Vector2(cos(float(m["a"])), sin(float(m["a"])) * K) * float(m["d"])
				BarridoAire.cometa(capa, desde.lerp(mano, maxf(0.0, km * km - 0.2)), desde.lerp(mano, km * km),
					float(m["tam"]) * 1.4, Color(NEGRO, 0.85))
			_disco(capa, mano, 2.0 + 4.0 * kc, NEGRO, Color(SOMBRA_GRIS, 0.9))
			return
		var u: float = clampf((_t - T_CARGA_SOL) / maxf(tl - T_CARGA_SOL, 0.01), 0.0, 1.0)
		var a: Vector2 = mano
		var b: Vector2 = _c + _alto(8.0)
		var p: Vector2 = a.lerp(b, u) + _alto(10.0 * sin(u * PI))
		if capa == _delante:
			# La ESTELA de humo negro: bocanadas que se quedan atras y se deshacen.
			for k in 7:
				var uk: float = u - 0.06 * float(k + 1)
				if uk < 0.0:
					break
				var pk: Vector2 = a.lerp(b, uk) + _alto(10.0 * sin(uk * PI) + 3.0 * float(k)) \
					+ Vector2(sin(float(k) * 2.3 + _t * 8.0) * 2.5, 0.0)
				_disco(capa, pk, 5.5 - 0.5 * float(k), Color(NEGRO, 0.75 - 0.09 * float(k)), Color(VIOLETA_HONDO, 0.0))
			_disco(capa, p, 7.0, TINTA, Color(TINTA, 0.9))
			_disco(capa, p, 3.2, ECLIPSE_CLARO, ECLIPSE)
			_disco(capa, p, 1.6, TINTA, TINTA)
			return
		BarridoAire.brillo(capa, p, 13.0, Color(ECLIPSE, 0.4))
		return
	# 2) EL POZO.
	if capa == _suelo:
		# La SOMBRA que se extiende por todo el circulo (mas negra hacia el centro).
		BarridoAire.brillo(capa, _c, _r * (0.5 + 0.6 * vivo), Color(NEGRO, 0.55 * vivo))
		BarridoAire.brillo(capa, _c, _r * 0.7 * vivo, Color(VIOLETA_HONDO, 0.35 * vivo))
		if tp < 0.0:
			# El orbe se hunde: un charco negro que se abre bajo el.
			var kh: float = clampf(t_hunde / T_HUNDE, 0.0, 1.0)
			_disco(capa, _c, 5.0 + 8.0 * kh, NEGRO, Color(NEGRO, 0.6))
			return
		# EL REMOLINO DE TINTA: una masa negra en medio, y los mechones por capas (el halo marron, la tinta negra y
		# las vetas grises encima), enroscandose hacia dentro; en cada tiron se cierran hacia el centro.
		var cierre: float = 1.0 - 0.22 * ap
		BarridoAire.brillo(capa, _c, _r * 0.85 * vivo, Color(TINTA, 0.9 * vivo))
		_disco(capa, _c, _r * 0.42 * vivo * cierre, TINTA, Color(TINTA, 0.95 * vivo))
		for pasada in 3:
			for mc in _rayos:
				var km: float = clampf((tp - float(mc["t0"])) / 0.25, 0.0, 1.0)
				if km <= 0.0:
					continue
				var crece: float = (1.0 - pow(1.0 - km, 2.0)) * vivo
				var r_fuera: float = _r * float(mc["d"]) * cierre
				var r_dentro: float = maxf(r_fuera - _r * float(mc["cae"]), _r * 0.08)
				var a_m: float = float(mc["a"]) + giro * (1.3 - 0.6 * float(mc["d"]))
				var w_m: float = _r * float(mc["ancho"]) * crece
				match pasada:
					0:
						_mechon(capa, _c, a_m, r_dentro * crece, r_fuera * crece, -float(mc["vuelta"]), w_m * 1.5,
							Color(TINTA_MEDIA, 0.75 * vivo), float(mc["sem"]), false)
					1:
						_mechon(capa, _c, a_m, r_dentro * crece, r_fuera * crece, -float(mc["vuelta"]), w_m,
							Color(TINTA, vivo), float(mc["sem"]), true)
					2:
						if bool(mc["claro"]):
							_mechon(capa, _c, a_m - 0.1, r_dentro * crece * 1.05, r_fuera * crece * 0.92,
								-float(mc["vuelta"]) * 0.8, w_m * 0.32, Color(TINTA_CLARA, 0.8 * vivo), float(mc["sem"]), false)
		# Las gotas de tinta que salpican alrededor.
		for gt in _gotas:
			var kg: float = clampf((tp - float(gt["t0"])) / 0.3, 0.0, 1.0)
			if kg <= 0.0:
				continue
			var pg: Vector2 = _c + Vector2(cos(float(gt["a"]) + giro * 0.3), sin(float(gt["a"]) + giro * 0.3)) * _r * float(gt["d"]) * vivo
			_disco(capa, pg, float(gt["tam"]) * vivo, Color(TINTA, 0.9), Color(TINTA, 0.9))
		return
	if capa == _delante:
		if tp < 0.0:
			return
		# EL OJO DE ECLIPSE, flotando un pelo sobre el centro (encima de quien este ahi): halo de oro, aro claro y la
		# pupila negra.
		var r_ojo: float = _r * 0.11 * vivo * (1.0 + 0.25 * ap)
		var ojo: Vector2 = _c + _alto(ALTO_OJO_ECLIPSE)
		_disco(capa, ojo, r_ojo * 1.6, Color(ECLIPSE, 0.9 * vivo), Color(ECLIPSE, 0.0))
		_disco(capa, ojo, r_ojo, Color(ECLIPSE_CLARO, vivo), Color(ECLIPSE, vivo))
		_disco(capa, ojo, r_ojo * 0.52, Color(TINTA, vivo), Color(TINTA, vivo))
		# El HUMO y los TROZOS que el pozo se traga: salen del borde y van en espiral al centro.
		for tz in _trozos:
			var tk: float = (tp - float(tz["t0"])) / 0.55
			if tk < 0.0 or tk >= 1.0 or vivo <= 0.0:
				continue
			var d: float = _r * float(tz["d"]) * (1.0 - tk * tk)
			var ang: float = float(tz["a"]) - tk * 2.2
			var pz: Vector2 = _c + Vector2(cos(ang), sin(ang)) * d + _alto(3.0 * (1.0 - tk))
			var tam: float = float(tz["tam"]) * (1.0 - tk * 0.6)
			if bool(tz["piedra"]):
				_estrella(capa, pz, tam * 0.5, tam, 3, float(tz["giro"]) + tk * 6.0, Color(0.2, 0.16, 0.18, vivo),
					Color(0.12, 0.09, 0.1, vivo), 0.8)
			else:
				_disco(capa, pz, tam * 1.2, Color(NEGRO, 0.7 * vivo * sin(tk * PI)), Color(VIOLETA_HONDO, 0.0))
		return
	if capa == _brillo:
		if tp < 0.0:
			var kh2: float = clampf(t_hunde / T_HUNDE, 0.0, 1.0)
			BarridoAire.brillo(capa, _c, 18.0 * kh2, Color(SOMBRA_CLARA, 0.5 * kh2))
			return
		# El resplandor rojo del ojo, que late con los tirones, y el destello rojo al cerrarse.
		# El HALO DORADO del eclipse y su destello en cruz, que se encienden en cada tiron.
		# (sin nucleo blanco: la pupila negra tiene que seguir viendose)
		var r_o: float = _r * 0.11 * vivo
		var ojo_b: Vector2 = _c + _alto(ALTO_OJO_ECLIPSE)
		MagiaAire._anillo(capa, ojo_b, r_o * 1.25, r_o * (0.9 + 0.6 * ap), Color(ECLIPSE, (0.3 + 0.35 * ap) * vivo))
		for k in 4:
			var a_c: float = PI * 0.5 * float(k)
			_cuna(capa, ojo_b, a_c, r_o * 1.05, r_o * (3.2 + 2.0 * ap), 0.05, Color(ECLIPSE_CLARO, (0.75 + 0.25 * ap) * vivo))
		if cierra > 0.0 and cierra < 1.0:
			BarridoAire.destello(capa, ojo_b, 24.0 * (1.0 - cierra), Color(ECLIPSE_CLARO, 1.0 - cierra), 0.0)
