# ============================================================
#  magia_aire.gd
#  LOS EFECTOS DE LAS MAGIAS en el mapa (26/09/2026, las comunes de 1 frase; los eligio el usuario):
#  POR EL SUELO (SueloRoto: la ficha del hechizo dice cual en SpellData.suelo_mapa; MAGIA_* en el orden de Modo):
#    ALIENTO   Brasa: un aliento de dragon. BOCANADAS de fuego que salen de la mano y se abren por el cono, crecen,
#              suben en puntas y se hacen humo (blancas por dentro, rojas por fuera), humo oscuro detras y el suelo
#              ennegrecido con ascuas que se apagan.
#    LLUVIA    Rocio: una nube baja sobre la franja y una lluvia fuerte que la recorre desde ti; cada gota salpica
#              al caer y deja charcos que luego se secan.
#    ORBE      Pulso menor: una bolita violeta con estela que va recta; en el primero revienta en un anillo
#              relleno y un destello. ORBE_FALLA: no habia nadie, se apaga al final del recorrido.
#    BOLA      Descarga: una bola electrica chisporroteando hasta el primero; revienta en un fogonazo y de ella
#              salen los ARCOS de la cadena. BOLA_FALLA: se deshace en chispas.
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa):
#    ARCO      el salto de una cadena: un rayo quebrado RELLENO de pecho a pecho que chisporrotea.
#  NADA DE LINEAS peladas (bandas rellenas con halo, cometas y destellos de BarridoAire). Coordenadas de MUNDO;
#  el suelo SIN achatar; lo que va en el aire, a su altura por K. Todo sale de una semilla.
# ============================================================
extends Node2D
class_name MagiaAire

# Los del suelo van en el orden de SueloRoto.Tipo.MAGIA_*: no reordenar.
enum Modo { ALIENTO, LLUVIA, ORBE, BOLA, ORBE_FALLA, BOLA_FALLA, ARCO }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ALTO_MANO := 12.0          # a que altura sale lo que lanzas (la mano)
const ALTO_PECHO := 13.0

# EL ALIENTO
const T_ALIENTO := 0.34          # lo que tarda el frente de llama en llegar al fondo del cono
const T_SOSTIENE := 0.22         # lo que se queda entero
const T_RECOGE := 0.3            # y lo que tarda la cola en alcanzar al frente (se va hacia delante)
const BOCANADAS := 30
const T_EMITE := 0.5             # lo que dura el soplo (salen bocanadas todo ese rato)
const T_VIAJE_BOCANADA := 0.34   # lo que tarda una bocanada en llegar a su sitio (la primera, al fondo: T_ALIENTO)
const FUEGO_OSCURO := Color(0.42, 0.07, 0.03)
const FUEGO_BLANCO := Color(1.0, 0.97, 0.78)
const FUEGO_AMARILLO := Color(1.0, 0.82, 0.3)
const FUEGO_NARANJA := Color(1.0, 0.5, 0.1)
const FUEGO_ROJO := Color(0.85, 0.16, 0.04)
const HUMO := Color(0.13, 0.11, 0.11)
const CHAMUSCADO := Color(0.05, 0.03, 0.02)

# LA LLUVIA
const T_FRENTE := 0.32           # lo que tarda la lluvia en recorrer la franja desde ti
const T_LLUEVE := 1.0            # lo que llueve en total
const T_CAIDA := 0.16            # lo que tarda una gota en caer
const ALTO_NUBE := 46.0
const GOTAS := 170
const AGUA := Color(0.55, 0.78, 1.0)
const AGUA_CLARA := Color(0.88, 0.95, 1.0)
const CHARCO := Color(0.22, 0.42, 0.78)
const NUBE := Color(0.2, 0.24, 0.34)
const NUBE_LUZ := Color(0.46, 0.53, 0.66)

# EL ORBE Y LA BOLA
const V_ORBE := 380.0
const V_BOLA := 300.0
const T_REVIENTA := 0.3
const ARCANO := Color(0.66, 0.46, 1.0)
const ARCANO_CLARO := Color(0.92, 0.86, 1.0)
const RAYO := Color(1.0, 0.9, 0.25)
const RAYO_CLARO := Color(1.0, 1.0, 0.86)

# EL ARCO
const T_ARCO := 0.28
const T_REJITTER := 0.045

var modo: int = Modo.ORBE
var forma: CombatFormas.Forma = null
var color: Color = RAYO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _semilla: int = 1
var _o: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _lat: Vector2 = Vector2.DOWN
var _r: float = 30.0
var _largo: float = 60.0
var _ancho: float = 30.0
var _humos: Array = []
var _bocanadas: Array = []
var _manchas: Array = []
var _ascuas: Array = []
var _chispas: Array = []
var _gotas: Array = []
var _charcos: Array = []
var _nubes: Array = []
var _motas: Array = []
# El arco.
var _desde: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> MagiaAire:
	if padre == null or f == null:
		return null
	var e := MagiaAire.new()
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
	e._preparar_area()
	return e


# CUANDO LE LLEGA a 'p', en segundos desde que se lanza.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	var o: Vector2 = SueloRoto.origen_de(f)
	match m:
		Modo.ALIENTO:
			return clampf(p.distance_to(o) / maxf(f.radio, 1.0), 0.0, 1.0) * T_ALIENTO
		Modo.LLUVIA:
			var a: float = clampf((p - o).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0)
			return a * T_FRENTE + T_CAIDA
		Modo.ORBE, Modo.ORBE_FALLA:
			return maxf(0.0, (p - o).dot(f.dir)) / V_ORBE
		Modo.BOLA, Modo.BOLA_FALLA:
			return maxf(0.0, (p - o).dot(f.dir)) / V_BOLA
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.ALIENTO: return T_ALIENTO
		Modo.LLUVIA: return T_FRENTE + T_CAIDA
	return 0.3


func duracion() -> float:
	match modo:
		Modo.ALIENTO: return T_ALIENTO + T_SOSTIENE + T_RECOGE + 1.3
		Modo.LLUVIA: return T_LLUEVE + 1.8
		Modo.ORBE, Modo.ORBE_FALLA: return _largo / V_ORBE + T_REVIENTA + 0.5
		Modo.BOLA, Modo.BOLA_FALLA: return _largo / V_BOLA + T_REVIENTA + 0.7
		Modo.ARCO: return T_ARCO + 0.05
	return 1.0


func _preparar_area() -> void:
	_o = SueloRoto.origen_de(forma)
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_lat = _dir.orthogonal()
	_r = maxf(forma.radio, 8.0)
	_largo = maxf(forma.largo if forma.tipo == CombatFormas.Tipo.LINEA else forma.radio, 4.0)
	_ancho = maxf(forma.ancho, 8.0)
	match modo:
		Modo.ALIENTO:
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			for i in BOCANADAS:
				var lado: float = -1.0 if _rng.randf() < 0.5 else 1.0
				_bocanadas.append({"t0": T_EMITE * float(i) / float(BOCANADAS) + _rng.randf_range(0.0, 0.03),
					"a": lado * pow(_rng.randf(), 1.3) * mitad * 0.8, "u": _rng.randf_range(0.82, 1.02),
					"vida": _rng.randf_range(0.45, 0.6), "tam": _rng.randf_range(0.8, 1.2), "fase": _rng.randf_range(0.0, 50.0)})
			# La primera sale derecha y llega al fondo: marca el frente (lo que dice retraso).
			_bocanadas[0]["t0"] = 0.0
			_bocanadas[0]["a"] = 0.0
			_bocanadas[0]["u"] = 1.0
			for i in 16:
				var u: float = _rng.randf_range(0.15, 1.0)
				_humos.append({"u": u, "a": _rng.randf_range(-mitad, mitad) * 0.8, "t0": u * T_ALIENTO + _rng.randf_range(0.05, 0.3),
					"r": _rng.randf_range(4.0, 8.0), "sube": _rng.randf_range(12.0, 24.0), "vida": _rng.randf_range(0.7, 1.1)})
			for i in 12:
				var u2: float = _rng.randf_range(0.2, 0.95)
				_manchas.append({"u": u2, "a": _rng.randf_range(-mitad, mitad) * 0.85, "r": _rng.randf_range(5.0, 10.0)})
			for i in 26:
				var u3: float = _rng.randf_range(0.15, 1.0)
				_ascuas.append({"u": u3, "a": _rng.randf_range(-mitad, mitad) * 0.9, "tam": _rng.randf_range(0.8, 1.6),
					"fase": _rng.randf_range(0.0, TAU), "vida": _rng.randf_range(0.9, 1.5)})
			for i in 12:
				var u4: float = _rng.randf_range(0.3, 1.0)
				_chispas.append({"u": u4, "a": _rng.randf_range(-mitad, mitad) * 0.8, "t0": u4 * T_ALIENTO + _rng.randf_range(0.0, 0.3),
					"v": Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-55.0, -30.0))})
		Modo.LLUVIA:
			for i in GOTAS:
				var u: float = _rng.randf()
				var llega: float = u * T_FRENTE
				_gotas.append({"u": u, "v": _rng.randf_range(-0.5, 0.5), "t0": llega + _rng.randf_range(0.0, maxf(0.05, T_LLUEVE - llega - T_CAIDA)),
					"largo": _rng.randf_range(11.0, 17.0)})
			var n_ch: int = int(clampf(_largo / 18.0, 5.0, 12.0))
			for i in n_ch:
				var u2: float = (float(i) + _rng.randf_range(0.1, 0.9)) / float(n_ch)
				_charcos.append({"u": u2, "v": _rng.randf_range(-0.32, 0.32), "r": _rng.randf_range(5.0, 10.0),
					"ex": _rng.randf_range(0.7, 1.3), "giro": _rng.randf_range(0.0, PI)})
			var n_nu: int = int(clampf(_largo / 14.0, 6.0, 14.0))
			for i in n_nu:
				_nubes.append({"u": (float(i) + 0.5) / float(n_nu), "v": _rng.randf_range(-0.25, 0.25),
					"r": _rng.randf_range(0.34, 0.5) * _ancho, "fase": _rng.randf_range(0.0, TAU)})
		Modo.ORBE, Modo.ORBE_FALLA, Modo.BOLA, Modo.BOLA_FALLA:
			for i in 7:
				var a: float = _rng.randf_range(0.0, TAU)
				_motas.append({"d": Vector2(cos(a), sin(a) * K), "v": _rng.randf_range(20.0, 45.0), "tam": _rng.randf_range(1.0, 1.8)})
	_suelo = _capa(SueloRoto.Z_SUELO, false)
	_delante = _capa(Z_ENCIMA, false)
	_brillo = _capa(Z_ENCIMA + 1, true)


# ------------------------------------------------------------
#  SOBRE UN CUERPO: el arco de una cadena, de pecho a pecho
# ------------------------------------------------------------
static func arco(padre: Node, desde: Vector2, hasta: Vector2, col: Color, semilla: int, espera: float,
		ritmo: float) -> MagiaAire:
	if padre == null:
		return null
	var e := MagiaAire.new()
	e.modo = Modo.ARCO
	e.color = col
	e._semilla = semilla
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._desde = desde
	e._hasta = hasta
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


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
#  PIEZAS
# ------------------------------------------------------------
static func _alto(h: float) -> Vector2:
	return Vector2(0.0, -h * K)


static func _ruido(x: float, k: float) -> float:
	return fmod(absf(sin(x * 12.9898 + k * 78.233) * 43758.5453), 1.0)


# UNA LENGUA: banda rellena a lo largo de 'pts', con su ancho y sus dos colores en cada punto (borde y nucleo). A lo
# ancho: transparente, borde, nucleo, borde, transparente. Va en un solo triangle_array.
static func _lengua(ci: CanvasItem, pts: PackedVector2Array, anchos: PackedFloat32Array, bordes: PackedColorArray,
		nucleos: PackedColorArray) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	for i in n:
		var d: Vector2 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		var nor: Vector2 = d.normalized().orthogonal() if d.length_squared() > 0.0001 else Vector2.UP
		var w: float = anchos[i]
		var cb: Color = bordes[i]
		var offs: Array = [-w, -w * 0.45, 0.0, w * 0.45, w]
		var cols: Array = [Color(cb, 0.0), cb, nucleos[i], cb, Color(cb, 0.0)]
		for j in 5:
			pv.append(pts[i] + nor * offs[j])
			pc.append(cols[j])
	for i in n - 1:
		var b: int = i * 5
		for j in 4:
			pi.append_array([b + j, b + j + 1, b + 5 + j, b + j + 1, b + 6 + j, b + 5 + j])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# UNA BOCANADA DE FUEGO en 'c' de radio 'r' y edad 'k' (0 nace, 1 se apaga). Silueta irregular que cambia a saltos
# (como el fuego de pixel-art: pocas formas, no un borron) y se estira hacia ARRIBA en puntas; tres capas de dentro
# a fuera: blanca, amarilla/naranja y roja. Al envejecer se oscurece hasta hacerse humo.
func _bocanada(ci: CanvasItem, c: Vector2, r: float, k: float, fase: float) -> void:
	var paso: float = floor(_t * 14.0) + fase
	var n: int = 14
	var contorno := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		var rr: float = r * (0.8 + 0.3 * _ruido(float(i) + paso * 3.1, fase))
		if d.y < -0.2:
			# Arriba: la llama sube, y una de cada tres es una punta.
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
		var pv := PackedVector2Array([c + Vector2(0.0, r * 0.12 * (1.0 - esc))])
		var pc := PackedColorArray([Color(cp[1] as Color, alfa)])
		var pi := PackedInt32Array()
		for i in n:
			pv.append(c + contorno[i] * esc + Vector2(0.0, r * 0.12 * (1.0 - esc)))
			pc.append(Color(cp[2] as Color, alfa))
		for i in n:
			pi.append_array([0, 1 + i, 1 + (i + 1) % n])
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# Un anillo RELLENO que se difumina hacia dentro y hacia fuera (la onda de un impacto). En el suelo: sin achatar.
static func _anillo(ci: CanvasItem, c: Vector2, r: float, grueso: float, col: Color, achata: float = 1.0) -> void:
	if r <= 0.3 or col.a <= 0.0:
		return
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	var n: int = 28
	var radios: Array = [maxf(0.0, r - grueso), r, r + grueso * 0.6]
	var cols: Array = [Color(col, 0.0), col, Color(col, 0.0)]
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a) * achata)
		for j in 3:
			pv.append(c + d * radios[j])
			pc.append(cols[j])
	for i in n:
		var b0: int = i * 3
		var b1: int = ((i + 1) % n) * 3
		for j in 2:
			pi.append_array([b0 + j, b0 + j + 1, b1 + j, b0 + j + 1, b1 + j + 1, b1 + j])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


# Un rayo QUEBRADO relleno de 'a' a 'b' (halo ancho del color y nucleo blanco fino). 'sem' cambia el quiebro.
static func _quebrado(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, claro: Color, sem: float, tramos: int,
		desvio: float, grueso: float, alfa: float) -> void:
	var pts := PackedVector2Array()
	var d: Vector2 = b - a
	var nor: Vector2 = d.normalized().orthogonal() if d.length_squared() > 0.01 else Vector2.UP
	for i in tramos + 1:
		var u: float = float(i) / float(tramos)
		var j: float = 0.0 if i == 0 or i == tramos else (_ruido(sem + float(i), 3.1) - 0.5) * 2.0 * desvio
		pts.append(a + d * u + nor * j)
	var anchos := PackedFloat32Array()
	var bordes := PackedColorArray()
	var nucleos := PackedColorArray()
	for i in pts.size():
		var u2: float = float(i) / float(tramos)
		var afila: float = 0.55 + 0.45 * sin(u2 * PI)
		anchos.append(grueso * afila)
		bordes.append(Color(col, 0.55 * alfa))
		nucleos.append(Color(claro, alfa))
	_lengua(ci, pts, anchos, bordes, nucleos)


# ------------------------------------------------------------
#  EL DIBUJO
# ------------------------------------------------------------
func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.ALIENTO: _aliento(capa)
		Modo.LLUVIA: _lluvia(capa)
		Modo.ORBE, Modo.ORBE_FALLA: _orbe(capa)
		Modo.BOLA, Modo.BOLA_FALLA: _bola(capa)
		Modo.ARCO: _arco(capa)


# Un punto del cono en el suelo: a la fraccion 'u' del radio y 'a' radianes del eje.
func _en_cono(u: float, a: float) -> Vector2:
	return _o + _dir.rotated(a) * _r * u


func _aliento(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	var frente: float = 1.0 - pow(1.0 - clampf(_t / T_ALIENTO, 0.0, 1.0), 2.0)
	var t_fin: float = T_ALIENTO + T_SOSTIENE
	var cola: float = clampf((_t - t_fin) / T_RECOGE, 0.0, 1.0)
	cola = cola * cola
	var vivo: bool = cola < 1.0
	if capa == _suelo:
		# EL SUELO ENNEGRECIDO: manchas por donde ya ha pasado el frente, que se apagan despacio.
		var apaga: float = 1.0 - clampf((_t - t_fin - 0.4) / 1.2, 0.0, 1.0)
		for m in _manchas:
			var u: float = float(m["u"])
			if u > frente:
				continue
			var p: Vector2 = _en_cono(u, float(m["a"]))
			BarridoAire.brillo(capa, p, float(m["r"]), Color(CHAMUSCADO, 0.42 * apaga))
		# Y las ASCUAS: puntitos que laten y se apagan.
		for a2 in _ascuas:
			var u2: float = float(a2["u"])
			var t_a: float = _t - u2 * T_ALIENTO
			if t_a < 0.0:
				continue
			var vida: float = 1.0 - clampf((t_a - 0.3) / float(a2["vida"]), 0.0, 1.0)
			if vida <= 0.0:
				continue
			var late: float = 0.6 + 0.4 * sin(_t * 11.0 + float(a2["fase"]))
			var p2: Vector2 = _en_cono(u2, float(a2["a"]))
			BarridoAire.brillo(capa, p2, float(a2["tam"]) * 2.4, Color(FUEGO_NARANJA, 0.55 * vida * late))
			BarridoAire.brillo(capa, p2, float(a2["tam"]), Color(FUEGO_AMARILLO, vida * late))
		return
	if capa == _delante:
		# EL HUMO, detras del fuego: bocanadas oscuras que suben y se abren.
		for h in _humos:
			var th: float = _t - float(h["t0"])
			if th < 0.0:
				continue
			var k: float = th / float(h["vida"])
			if k >= 1.0:
				continue
			var p: Vector2 = _en_cono(float(h["u"]), float(h["a"])) + _alto(ALTO_MANO + float(h["sube"]) * k)
			BarridoAire.brillo(capa, p, float(h["r"]) * (1.3 + 1.5 * k), Color(HUMO, 0.62 * sin(k * PI)))
		if not vivo:
			return
		# LAS BOCANADAS DE FUEGO (26/09: las lenguas "parecen lineas hacia delante"): bolas de llama irregulares
		# que salen de la mano, crecen y se frenan al avanzar, con puntas que suben; al envejecer se oscurecen y
		# se hacen humo. Primero las viejas (las de lejos): las nuevas, junto a la mano, van encima.
		for b in _bocanadas:
			var tb: float = _t - float(b["t0"])
			if tb < 0.0:
				continue
			var k: float = tb / float(b["vida"])
			if k >= 1.0:
				continue
			var viaje: float = 1.0 - pow(1.0 - clampf(tb / T_VIAJE_BOCANADA, 0.0, 1.0), 2.0)
			var u: float = float(b["u"]) * viaje
			var c: Vector2 = _en_cono(u, float(b["a"])) + _alto(ALTO_MANO * (1.0 - 0.35 * u) + 10.0 * k * k)
			var r: float = (2.0 + u * _r * tan(mitad) * 0.36) * float(b["tam"]) * (0.7 + 0.5 * minf(1.0, tb / 0.12))
			_bocanada(capa, c, r, k, float(b["fase"]))
		return
	if capa == _brillo:
		if vivo:
			# El resplandor del fuego, suave, a lo largo del eje.
			for j in 5:
				var u: float = (float(j) + 0.5) / 5.0 * frente
				if u < cola * frente:
					continue
				BarridoAire.brillo(capa, _en_cono(u, 0.0) + _alto(ALTO_MANO * 0.8), _r * 0.28, Color(FUEGO_NARANJA, 0.22))
			BarridoAire.brillo(capa, _o + _alto(ALTO_MANO), 7.0, Color(FUEGO_AMARILLO, 0.5 * (1.0 - cola)))
		# CHISPAS que saltan hacia arriba.
		for c in _chispas:
			var tc: float = _t - float(c["t0"])
			if tc < 0.0 or tc > 0.55:
				continue
			var p0: Vector2 = _en_cono(float(c["u"]), float(c["a"])) + _alto(ALTO_MANO)
			var v: Vector2 = c["v"]
			var p1: Vector2 = p0 + v * tc + Vector2(0.0, 60.0 * tc * tc)
			var p_ant: Vector2 = p0 + v * maxf(0.0, tc - 0.06)
			BarridoAire.cometa(capa, p_ant, p1, 1.3, Color(FUEGO_AMARILLO, 1.0 - tc / 0.55))


func _lluvia(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var sale: float = clampf(_t / 0.2, 0.0, 1.0)
	var fin: float = 1.0 - clampf((_t - T_LLUEVE) / 0.5, 0.0, 1.0)
	if capa == _suelo:
		# EL SUELO MOJADO: una sombra fria por donde ha pasado la lluvia, y los charcos que crecen y se secan.
		var frente: float = clampf(_t / T_FRENTE, 0.0, 1.0)
		var seca: float = 1.0 - clampf((_t - T_LLUEVE) / 1.6, 0.0, 1.0)
		for ch in _charcos:
			var u: float = float(ch["u"])
			if u > frente:
				continue
			var crece: float = clampf((_t - u * T_FRENTE) / 0.6, 0.0, 1.0)
			var c: Vector2 = _o + _dir * _largo * u + _lat * _ancho * float(ch["v"])
			var r: float = float(ch["r"]) * (0.4 + 0.6 * crece)
			BarridoAire.brillo(capa, c, r * 1.35, Color(CHARCO, 0.5 * seca))
			_anillo(capa, c, r * 0.9, 1.4, Color(AGUA, 0.35 * seca))
			BarridoAire.brillo(capa, c + Vector2(-r * 0.3, -r * 0.25), r * 0.4, Color(AGUA_CLARA, 0.4 * seca))
		# Las SALPICADURAS de cada gota al llegar al suelo: un anillito que se abre.
		for g in _gotas:
			var tg: float = _t - float(g["t0"]) - T_CAIDA
			if tg < 0.0 or tg > 0.22:
				continue
			var p: Vector2 = _o + _dir * _largo * float(g["u"]) + _lat * _ancho * float(g["v"])
			_anillo(capa, p, 1.5 + 5.0 * (tg / 0.22), 1.5, Color(AGUA_CLARA, 0.85 * (1.0 - tg / 0.22)))
			# y dos gotitas que saltan
			for sj in 2:
				var ds: float = -1.0 if sj == 0 else 1.0
				var ps: Vector2 = p + _lat * ds * 4.0 * (tg / 0.22) + _alto(10.0 * sin(tg / 0.22 * PI))
				BarridoAire.brillo(capa, ps, 1.1, Color(AGUA_CLARA, 0.8 * (1.0 - tg / 0.22)))
		return
	if capa == _delante:
		# LA NUBE, baja, sobre la franja: bultos oscuros y blandos que se forman desde ti y se deshacen al final.
		for nu in _nubes:
			var u: float = float(nu["u"])
			var llega: float = clampf((_t - u * T_FRENTE * 0.8) / 0.25, 0.0, 1.0)
			if llega <= 0.0:
				continue
			var c: Vector2 = _o + _dir * _largo * u + _lat * _ancho * float(nu["v"]) + _alto(ALTO_NUBE) \
				+ Vector2(sin(_t * 1.3 + float(nu["fase"])) * 1.5, 0.0)
			var r: float = float(nu["r"]) * (0.7 + 0.3 * llega)
			BarridoAire.brillo(capa, c, r * 1.1, Color(NUBE, 0.8 * llega * fin))
			BarridoAire.brillo(capa, c + Vector2(r * 0.15, -r * 0.35), r * 0.62, Color(NUBE_LUZ, 0.55 * llega * fin))
		# LAS GOTAS cayendo: cometas finas de la nube al suelo.
		for g in _gotas:
			var tg: float = _t - float(g["t0"])
			if tg < 0.0 or tg > T_CAIDA:
				continue
			var p: Vector2 = _o + _dir * _largo * float(g["u"]) + _lat * _ancho * float(g["v"])
			var h: float = ALTO_NUBE * (1.0 - tg / T_CAIDA)
			var cabeza: Vector2 = p + _alto(h)
			BarridoAire.cometa(capa, cabeza + Vector2(0.0, -float(g["largo"])), cabeza, 1.7, Color(AGUA_CLARA, 0.95 * sale))
		return
	if capa == _brillo:
		# Un velo de agua fresca sobre la franja mientras llueve.
		var n: int = int(clampf(_largo / 22.0, 3.0, 9.0))
		for j in n:
			var u: float = (float(j) + 0.5) / float(n)
			if u > clampf(_t / T_FRENTE, 0.0, 1.0):
				continue
			BarridoAire.brillo(capa, _o + _dir * _largo * u + _alto(ALTO_NUBE * 0.4), _ancho * 0.55, Color(AGUA, 0.07 * fin))


# Donde va el proyectil a los 't' segundos (en el aire, a la altura de la mano).
func _pos_proyectil(t: float, v: float) -> Vector2:
	var d: float = clampf(t * v, 0.0, _largo)
	return _o + _dir * (6.0 + d) + _alto(ALTO_MANO)


func _orbe(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var t_llega: float = _largo / V_ORBE
	var falla: bool = modo == Modo.ORBE_FALLA
	if _t < t_llega:
		if capa == _brillo:
			var p: Vector2 = _pos_proyectil(_t, V_ORBE)
			# La ESTELA: tres cometas que se difuminan, un pelo separadas, y motas que se quedan atras.
			for j in 3:
				var off: Vector2 = _lat * (float(j) - 1.0) * 1.6
				BarridoAire.cometa(capa, p - _dir * (38.0 - 9.0 * absf(float(j) - 1.0)) + off * 1.6, p + off, 5.0 - 1.5 * absf(float(j) - 1.0),
					Color(ARCANO, 0.6))
			BarridoAire.brillo(capa, p, 14.0, Color(ARCANO, 0.5))
			BarridoAire.brillo(capa, p, 5.5, Color(ARCANO_CLARO, 1.0))
			BarridoAire.destello(capa, p, 10.0, Color(ARCANO_CLARO, 0.65), _t * 8.0)
			for k in 4:
				var tk: float = _t - float(k) * 0.05
				if tk < 0.0:
					continue
				var pk: Vector2 = _pos_proyectil(tk, V_ORBE) + _lat * sin(float(k) * 2.3 + _t * 20.0) * 3.0
				BarridoAire.brillo(capa, pk, 1.6, Color(ARCANO_CLARO, 0.5 - 0.1 * float(k)))
		return
	var tr: float = _t - t_llega
	var fin: Vector2 = _pos_proyectil(t_llega, V_ORBE)
	var k2: float = clampf(tr / T_REVIENTA, 0.0, 1.0)
	if falla:
		# NO HABIA NADIE: el orbe se encoge y se apaga en una bocanada.
		if capa == _brillo and k2 < 1.0:
			BarridoAire.brillo(capa, fin, 8.0 * (1.0 - k2), Color(ARCANO, 0.4 * (1.0 - k2)))
			BarridoAire.brillo(capa, fin, 3.5 * (1.0 - k2), Color(ARCANO_CLARO, 1.0 - k2))
		return
	if capa == _brillo:
		# EL CHOQUE: anillo relleno que se abre, destello en estrella y motas que salen y caen.
		if tr < 0.1:
			BarridoAire.brillo(capa, fin, 22.0 * (1.0 - tr / 0.1), Color(ARCANO_CLARO, 0.5 * (1.0 - tr / 0.1)))
		_anillo(capa, fin, 4.0 + 22.0 * (1.0 - pow(1.0 - k2, 2.0)), 4.5, Color(ARCANO, 0.85 * (1.0 - k2)), K)
		BarridoAire.destello(capa, fin, 22.0 * (1.0 - k2 * 0.6), Color(ARCANO_CLARO, 1.0 - k2), 0.4)
		for m in _motas:
			var tm: float = tr
			if tm > 0.45:
				continue
			var pm: Vector2 = fin + (m["d"] as Vector2) * float(m["v"]) * tm + Vector2(0.0, 40.0 * tm * tm)
			BarridoAire.brillo(capa, pm, float(m["tam"]), Color(ARCANO_CLARO, 1.0 - tm / 0.45))
	elif capa == _suelo:
		var suelo_p: Vector2 = fin - _alto(ALTO_MANO)
		BarridoAire.brillo(capa, suelo_p, 10.0, Color(ARCANO, 0.25 * (1.0 - clampf(tr / 0.6, 0.0, 1.0))))


func _bola(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var t_llega: float = _largo / V_BOLA
	var falla: bool = modo == Modo.BOLA_FALLA
	var chispa: float = floor(_t / T_REJITTER)
	if _t < t_llega:
		if capa == _brillo:
			var p: Vector2 = _pos_proyectil(_t, V_BOLA)
			BarridoAire.cometa(capa, p - _dir * 26.0, p, 5.0, Color(RAYO, 0.4))
			BarridoAire.brillo(capa, p, 16.0, Color(RAYO, 0.45 + 0.2 * _ruido(chispa, 1.0)))
			BarridoAire.brillo(capa, p, 6.0, Color(RAYO_CLARO, 1.0))
			# El chisporroteo: rayitos quebrados que salen de la bola y cambian cada poco.
			for j in 6:
				var a: float = TAU * _ruido(chispa + float(j) * 7.0, 2.0)
				var q: Vector2 = p + Vector2(cos(a), sin(a) * K) * (10.0 + 8.0 * _ruido(chispa, float(j)))
				_quebrado(capa, p, q, RAYO, RAYO_CLARO, chispa * 13.0 + float(j), 3, 2.8, 2.2, 0.95)
		return
	var tr: float = _t - t_llega
	var fin: Vector2 = _pos_proyectil(t_llega, V_BOLA)
	var k2: float = clampf(tr / T_REVIENTA, 0.0, 1.0)
	if falla:
		if capa == _brillo and k2 < 1.0:
			BarridoAire.brillo(capa, fin, 9.0 * (1.0 - k2), Color(RAYO, 0.35 * (1.0 - k2)))
			for j in 3:
				var a2: float = TAU * _ruido(chispa + float(j) * 5.0, 4.0)
				_quebrado(capa, fin, fin + Vector2(cos(a2), sin(a2) * K) * 8.0 * (1.0 - k2), RAYO, RAYO_CLARO,
					chispa * 11.0 + float(j), 3, 2.0, 1.4, 1.0 - k2)
		return
	if capa == _brillo:
		# EL REVENTON: fogonazo, onda y chispas quebradas hacia fuera.
		if tr < 0.12:
			BarridoAire.brillo(capa, fin, 26.0 * (1.0 - tr / 0.12), Color(RAYO_CLARO, 0.55 * (1.0 - tr / 0.12)))
		_anillo(capa, fin, 4.0 + 16.0 * (1.0 - pow(1.0 - k2, 2.0)), 3.0, Color(RAYO, 0.75 * (1.0 - k2)), K)
		BarridoAire.destello(capa, fin, 20.0 * (1.0 - k2 * 0.5), Color(RAYO_CLARO, 1.0 - k2), 0.3)
		if tr < 0.22:
			for j in 6:
				var a3: float = TAU * float(j) / 6.0 + _ruido(float(_semilla), float(j)) * 0.8
				var largo_c: float = 10.0 + 8.0 * _ruido(float(j), 9.0)
				_quebrado(capa, fin, fin + Vector2(cos(a3), sin(a3) * K) * largo_c * (0.5 + tr / 0.22 * 0.5), RAYO, RAYO_CLARO,
					chispa * 17.0 + float(j), 4, 2.6, 1.8, 1.0 - tr / 0.22)
	elif capa == _suelo:
		var suelo_p: Vector2 = fin - _alto(ALTO_MANO)
		var apaga: float = 1.0 - clampf(tr / 0.9, 0.0, 1.0)
		BarridoAire.brillo(capa, suelo_p, 11.0, Color(CHAMUSCADO, 0.4 * apaga))
		BarridoAire.brillo(capa, suelo_p, 6.0, Color(RAYO, 0.3 * apaga * apaga))


func _arco(capa: Node2D) -> void:
	# El salto aparece un pelo antes del impacto y chisporrotea un rato: cambia de quiebro cada T_REJITTER.
	if _t < -0.04 or capa != _brillo:
		return
	var k: float = clampf((_t + 0.04) / T_ARCO, 0.0, 1.0)
	var alfa: float = (1.0 - k) * (0.7 + 0.3 * _ruido(floor(_t / T_REJITTER), 5.0))
	var claro: Color = color.lerp(Color.WHITE, 0.75)
	var sem: float = floor(_t / T_REJITTER) * 29.0 + float(_semilla % 97)
	var largo: float = _desde.distance_to(_hasta)
	var tramos: int = clampi(int(largo / 9.0), 4, 12)
	_quebrado(capa, _desde, _hasta, color, claro, sem, tramos, clampf(largo * 0.09, 2.5, 7.0), 3.4, alfa)
	# Una rama suelta que sale del medio.
	var medio: Vector2 = _desde.lerp(_hasta, 0.45 + 0.2 * _ruido(sem, 1.0))
	var rama: Vector2 = medio + (_hasta - _desde).normalized().rotated(0.9 * (1.0 if _ruido(sem, 2.0) < 0.5 else -1.0)) * 9.0
	_quebrado(capa, medio, rama, color, claro, sem + 5.0, 3, 2.0, 1.8, alfa * 0.7)
	if _t >= 0.0:
		var k2: float = clampf(_t / 0.18, 0.0, 1.0)
		BarridoAire.destello(capa, _hasta, 11.0 * (1.0 - k2 * 0.5), Color(claro, 1.0 - k2), sem)
