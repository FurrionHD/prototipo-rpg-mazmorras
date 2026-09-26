# ============================================================
#  magia_mayor.gd
#  LOS EFECTOS DE LAS MAGIAS DE 3 FRASES en el mapa (26/09/2026, los eligio el usuario). Van aparte de MagiaAire
#  (que ya pasa de las 1900 lineas) pero con sus mismas piezas (MagiaAire._anillo, BarridoAire.brillo...).
#  POR EL SUELO (SueloRoto.Tipo.MAGIA_SOL.., en el orden de Modo: no reordenar, viajan por red):
#    SOL       Estallido solar: una CHISPA sale de tu mano con estela de destellos y se para en el sitio; ahi NACE un
#              sol pequeño con su corona de rayos girando, crece, se aprieta un instante y REVIENTA en una onda de luz
#              que llena el circulo del centro hacia fuera; el resplandor que deja se apaga desde el centro.
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
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.SOL: return T_CARGA_SOL + T_CRECE + T_APRIETA + T_ONDA_SOL
	return 0.3


func duracion() -> float:
	match modo:
		Modo.SOL: return t_llega(forma) + T_CRECE + T_APRIETA + T_ONDA_SOL + T_RESPLANDOR + 0.3
	return 1.0


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
			# LA CORONA: dos estrellas de rayos que giran en sentidos contrarios (roja por fuera, naranja dentro) y el
			# disco en tres tonos. Al apretarse los rayos se recogen y todo se vuelve blanco.
			_estrella(capa, sol, rr * 0.95, rr * (1.9 * corona + 0.9), 8, giro, Color(SOL_NARANJA, 0.95),
				Color(SOL_ROJIZO, 0.85))
			_estrella(capa, sol, rr * 0.9, rr * (1.5 * corona + 0.8), 8, -giro * 1.3 + 0.2, Color(SOL_AMARILLO, 1.0),
				Color(SOL_NARANJA, 0.95), 0.5)
			_disco(capa, sol, rr, SOL_BLANCO.lerp(SOL_AMARILLO, 0.35 * (1.0 - aprieta)), SOL_AMARILLO.lerp(SOL_BLANCO, aprieta))
			_disco(capa, sol + Vector2(-rr * 0.18, -rr * 0.2), rr * 0.55, SOL_BLANCO, Color(SOL_BLANCO, 0.0))
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
