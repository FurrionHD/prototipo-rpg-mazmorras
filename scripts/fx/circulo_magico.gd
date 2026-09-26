# ============================================================
#  circulo_magico.gd
#  EL CIRCULO MAGICO DE QUIEN RECITA (26/09/2026, idea del usuario). Sale a sus pies con la primera frase y
#  CRECE con cada una: 1 el nucleo, 2 el anillo de fuera, 3 tres satelites que giran sobre si mismos y orbitan,
#  4 una corona que flota sobre la cabeza. Cada magia trae SU receta (SellosMagicos): color, figuras y giros.
#  Al disparar se acelera y se cierra en un fogonazo; al fallar la frase se agrieta, parpadea y se rompe; si se
#  corta (muerte, huida) se apaga.
#  Va colgado del cuerpo (le sigue), como AreaCuracion. El suelo SIN achatar; la corona tiene altura -> y a K.
#  NADA DE LINEAS peladas: cada trazo es una banda rellena, nucleo casi blanco y halo difuminado, en mezcla
#  aditiva (brilla). Todo va en un triangle_array por capa: un circulo son miles de triangulos.
# ============================================================
extends Node2D
class_name CirculoMagico

enum Estado { VIVO, DISPARO, FALLO, APAGA }

const K := 0.7071
const T_TRAZA := 0.55        # lo que tarda una pieza en trazarse
const T_PIEZA := 0.07        # y el retraso entre las piezas de una misma capa
const T_ENTRE_CAPAS := 0.25  # si salen varias capas de golpe (un espejo que llega a mitad), una tras otra
const T_DISPARO := 0.6
const T_FALLO := 0.85
const T_APAGA := 0.35
const ANCHO := 0.9           # el nucleo del trazo
const HALO := 2.0            # el difuminado a cada lado
const Z_LUZ := SueloRoto.Z_SUELO + 1
const Z_CORONA := Game.Z_PERSONAJES + 80

var receta: Dictionary = {}
var auto: bool = true         # false = el reloj lo lleva otro (las hojas: avanzar())
var _t: float = 0.0
var _giro: float = 0.0
var _t_etapa: Array = [-1.0, -1.0, -1.0, -1.0]
var _estado: int = Estado.VIVO
var _t_fin: float = 0.0
var _geo: Array = []          # por grupo: [{paths: [...], pozo: r, g, a}]
var _deriva: Array = []       # por grupo: hacia donde sale despedido al romperse
var _fondo: Node2D
var _luz: Node2D
var _corona: Node2D


static func crear(padre: Node, spell: SpellData, en: Vector2 = Vector2.ZERO) -> CirculoMagico:
	if padre == null or spell == null:
		return null
	var c := CirculoMagico.new()
	c.receta = SellosMagicos.receta_de(spell)
	c.position = en
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(c)
	c._preparar()
	return c


# 'dichas' = cuantas frases van ya dichas (1..n): salen las capas que falten.
func a_la_frase(dichas: int) -> void:
	if _estado != Estado.VIVO:
		return
	var nuevas: int = 0
	for e in clampi(dichas, 0, 4):
		if float(_t_etapa[e]) < 0.0:
			_t_etapa[e] = _t + T_ENTRE_CAPAS * float(nuevas)
			nuevas += 1


func frases_dichas() -> int:
	var n: int = 0
	for e in 4:
		if float(_t_etapa[e]) >= 0.0:
			n += 1
	return n


func disparar() -> void:
	_acabar(Estado.DISPARO)


func fallar() -> void:
	# Fallar la PRIMERA frase: el nucleo empieza a trazarse y se rompe a medias (que se vea que algo salio mal).
	if frases_dichas() == 0 and _estado == Estado.VIVO:
		_t_etapa[0] = _t - T_TRAZA * 0.6
	_acabar(Estado.FALLO)


func apagar() -> void:
	_acabar(Estado.APAGA)


func acabando() -> bool:
	return _estado != Estado.VIVO


func _acabar(e: int) -> void:
	if _estado != Estado.VIVO:
		return
	_estado = e
	_t_fin = _t


func _process(delta: float) -> void:
	if auto:
		avanzar(delta)


func avanzar(dt: float) -> void:
	_t += dt
	var mult: float = 1.0
	if _estado == Estado.DISPARO:
		var x: float = clampf((_t - _t_fin) / T_DISPARO, 0.0, 1.0)
		mult = 1.0 + 10.0 * x * x
	_giro += dt * mult
	var dura: float = {Estado.DISPARO: T_DISPARO, Estado.FALLO: T_FALLO, Estado.APAGA: T_APAGA}.get(_estado, INF)
	if _t - _t_fin >= dura and _estado != Estado.VIVO:
		queue_free()
		return
	for n in [_fondo, _luz, _corona]:
		if n != null:
			n.queue_redraw()


# ------------------------------------------------------------
#  LA GEOMETRIA (una vez, en coordenadas de cada grupo)
# ------------------------------------------------------------
func _preparar() -> void:
	_fondo = _capa(SueloRoto.Z_SUELO, false)
	_luz = _capa(Z_LUZ, true)
	if int(receta.get("n", 1)) >= 4:
		_corona = _capa(Z_CORONA, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(receta.get("clave", "")))
	for g in receta.get("grupos", []):
		var piezas: Array = []
		for pz in g["piezas"]:
			piezas.append({"paths": _paths_de(pz), "pozo": float(pz.get("r", 0.0)) if pz["p"] == "pozo" else 0.0,
				"g": float(pz.get("g", 1.0)), "a": float(pz.get("a", 1.0))})
		_geo.append(piezas)
		_deriva.append(Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(6.0, 14.0))


func _capa(z: int, aditiva: bool) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	if aditiva:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	add_child(n)
	n.draw.connect(_pintar.bind(n))
	return n


static func _polar(r: float, a: float) -> Vector2:
	return Vector2(cos(a), sin(a)) * r


static func _circ(c: Vector2, r: float, a0: float, a1: float, segs: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segs + 1:
		out.append(c + _polar(r, lerpf(a0, a1, float(i) / float(segs))))
	return out


# Cada path: {pts, cerrado, suave}.
func _paths_de(pz: Dictionary) -> Array:
	var out: Array = []
	var r: float = float(pz.get("r", 0.0))
	var n: int = int(pz.get("n", 1))
	var rot: float = float(pz.get("rot", 0.0))
	match str(pz["p"]):
		"anillo":
			var segs: int = maxi(20, int(r * 2.2))
			var pts := _circ(Vector2.ZERO, r, 0.0, TAU, segs)
			pts.remove_at(pts.size() - 1)
			out.append({"pts": pts, "cerrado": true, "suave": true})
		"estrella":
			var k: int = maxi(1, int(pz.get("k", 1)))
			var d: int = _mcd(n, k)
			for s in d:
				var pts := PackedVector2Array()
				for i in n / d:
					pts.append(_polar(r, rot + TAU * float(s + i * k) / float(n)))
				out.append({"pts": pts, "cerrado": true, "suave": false})
		"dientes":
			var h: float = float(pz.get("h", 3.0))
			var pts := PackedVector2Array()
			for i in n:
				var a: float = TAU * float(i) / float(n)
				pts.append(_polar(r, a))
				pts.append(_polar(r + h, a + PI / float(n)))
			out.append({"pts": pts, "cerrado": true, "suave": false})
		"petalos":
			var rp: float = r * sin(PI / float(n))
			for i in n:
				var a: float = TAU * float(i) / float(n)
				out.append({"pts": _circ(_polar(r, a), rp, a - PI * 0.5, a + PI * 0.5, 10), "cerrado": false, "suave": true})
		"cuentas":
			var rr: float = float(pz.get("rr", 1.2))
			for i in n:
				var pts := _circ(_polar(r, TAU * float(i) / float(n)), rr, 0.0, TAU, 10)
				pts.remove_at(pts.size() - 1)
				out.append({"pts": pts, "cerrado": true, "suave": true})
		"lunas":
			var rr: float = float(pz.get("rr", 4.0))
			for i in n:
				var a: float = rot + TAU * float(i) / float(n)
				var c: Vector2 = _polar(r, a)
				var abre: float = a if r > 0.0 else rot
				var u: Vector2 = _polar(1.0, abre)
				# El creciente: el arco de fuera por detras, y de vuelta el de un circulo corrido hacia la boca.
				var pts := _circ(c, rr, abre + 0.9, abre + TAU - 0.9, 16)
				var dentro := _circ(c + u * rr * 0.42, rr * 0.8, abre + TAU - 1.25, abre + 1.25, 14)
				pts.append_array(dentro)
				out.append({"pts": pts, "cerrado": true, "suave": true})
		"marcas":
			var r0: float = float(pz.get("r0", 0.0))
			var r1: float = float(pz.get("r1", 0.0))
			for i in n:
				var a: float = TAU * float(i) / float(n)
				out.append({"pts": PackedVector2Array([_polar(r0, a), _polar(r1, a)]), "cerrado": false, "suave": false})
		"friso":
			var r0: float = float(pz.get("r0", 0.0))
			var r1: float = float(pz.get("r1", 0.0))
			var rm: float = (r0 + r1) * 0.5
			var s: float = (r1 - r0) * 0.5
			var estilos: Array = pz.get("estilos", ["punto"])
			for i in n:
				var a: float = TAU * float(i) / float(n)
				var rad: Vector2 = _polar(1.0, a)
				var tg: Vector2 = rad.orthogonal()
				var c: Vector2 = rad * rm
				match str(estilos[i % estilos.size()]):
					"rombo":
						out.append({"pts": PackedVector2Array([c - rad * s * 0.9, c + tg * s * 0.45, c + rad * s * 0.9,
							c - tg * s * 0.45]), "cerrado": true, "suave": false})
					"punto":
						var pts := _circ(c, s * 0.3, 0.0, TAU, 8)
						pts.remove_at(pts.size() - 1)
						out.append({"pts": pts, "cerrado": true, "suave": true})
					"raya":
						out.append({"pts": PackedVector2Array([c - rad * s, c + rad * s]), "cerrado": false, "suave": false})
					_:
						out.append({"pts": PackedVector2Array([c - rad * s * 0.7 - tg * s * 0.5, c + rad * s * 0.8,
							c - rad * s * 0.7 + tg * s * 0.5]), "cerrado": true, "suave": false})
	# Cada path con su largo acumulado (para trazarlo poco a poco).
	for p in out:
		var pts: PackedVector2Array = p["pts"]
		var acum := PackedFloat32Array([0.0])
		var m: int = pts.size() if p["cerrado"] else pts.size() - 1
		for i in m:
			acum.append(acum[acum.size() - 1] + pts[i].distance_to(pts[(i + 1) % pts.size()]))
		p["acum"] = acum
	return out


static func _mcd(a: int, b: int) -> int:
	while b != 0:
		var t: int = a % b
		a = b
		b = t
	return maxi(a, 1)


# ------------------------------------------------------------
#  EL DIBUJO
# ------------------------------------------------------------
func _vida() -> float:
	var x: float = _t - _t_fin
	match _estado:
		Estado.DISPARO:
			return 1.0 - smoothstep(0.75, 1.0, x / T_DISPARO)
		Estado.FALLO:
			var u: float = clampf(x / T_FALLO, 0.0, 1.0)
			var parpadeo: float = 0.35 if _ruido(floor(_t * 22.0), 7.0) < 0.4 else 1.0
			return (1.0 - u) * parpadeo
		Estado.APAGA:
			return 1.0 - clampf(x / T_APAGA, 0.0, 1.0)
	return 1.0


func _escala() -> float:
	if _estado != Estado.DISPARO:
		return 1.0
	var x: float = clampf((_t - _t_fin) / T_DISPARO, 0.0, 1.0)
	if x < 0.4:
		return 1.0 + 0.06 * sin(x / 0.4 * PI)
	var u: float = (x - 0.4) / 0.6
	return lerpf(1.0, 0.08, u * u)


func _brillo() -> float:
	var b: float = 0.88 + 0.12 * sin(_t * 2.6)
	if _estado == Estado.DISPARO:
		b *= 1.0 + 1.4 * clampf((_t - _t_fin) / (T_DISPARO * 0.4), 0.0, 1.0)
	return b


# Lo roto al fallar: la parte de los tramos que ya no se pintan.
func _roto() -> float:
	if _estado != Estado.FALLO:
		return 0.0
	return clampf((_t - _t_fin) / T_FALLO * 1.5, 0.0, 0.85)


# Donde cae un punto del grupo 'gi' en el dibujo (coordenadas de este nodo).
func _xf(gi: int, p: Vector2) -> Vector2:
	var g: Dictionary = receta["grupos"][gi]
	var te: float = float(_t_etapa[int(g["etapa"]) - 1])
	var rot: float = float(g["rot0"]) + float(g["v"]) * _giro
	var q: Vector2 = p.rotated(rot)
	var esc: float = _escala()
	match str(g["clase"]):
		"sat":
			# Salen del anillo hacia su orbita.
			var u: float = clampf((_t - te) / T_TRAZA, 0.0, 1.0)
			var ro: float = lerpf(SellosMagicos.R_ANILLO, SellosMagicos.R_ORBITA, 1.0 - pow(1.0 - u, 3.0))
			var a: float = -PI * 0.5 + TAU * float(g["i"]) / 3.0 + float(g["v_orb"]) * _giro
			q = (q + _polar(ro, a)) * esc
		"corona":
			q = Vector2(q.x, q.y * K) * esc + Vector2(0.0, -SellosMagicos.ALTO_CORONA)
		_:
			q *= esc
	if _estado == Estado.FALLO:
		var x: float = clampf((_t - _t_fin) / T_FALLO, 0.0, 1.0)
		q += (_deriva[gi] as Vector2) * x * x
	return q


func _pintar(capa: Node2D) -> void:
	if receta.is_empty():
		return
	var vida: float = _vida()
	if vida <= 0.0:
		return
	var pv := PackedVector2Array()
	var pc := PackedColorArray()
	var pi := PackedInt32Array()
	var grupos: Array = receta["grupos"]
	var roto: float = _roto()
	var destellos: Array = []
	for gi in grupos.size():
		var g: Dictionary = grupos[gi]
		var en_corona: bool = g["clase"] == "corona"
		if (capa == _corona) != en_corona:
			continue
		var te: float = float(_t_etapa[int(g["etapa"]) - 1])
		if te < 0.0 or _t < te:
			continue
		var tonos: Array = SellosMagicos.tono(int(g["elem"]))
		var halo: Color = tonos[0]
		var nucleo: Color = tonos[1]
		if _estado == Estado.FALLO:
			var x: float = clampf((_t - _t_fin) / T_FALLO, 0.0, 1.0)
			halo = halo.lerp(Color(0.55, 0.2, 0.2), x)
			nucleo = nucleo.lerp(Color(0.7, 0.5, 0.5), x)
		# El fogonazo de cuando sale la capa.
		var edad: float = _t - te
		var boost: float = 1.0 + 1.3 * exp(-edad * 5.0)
		var a_g: float = vida * _brillo() * boost
		if edad < 0.4 and capa != _fondo:
			var donde: Vector2 = _xf(gi, Vector2.ZERO) if g["clase"] in ["sat", "corona"] \
				else _xf(gi, _polar(SellosMagicos.R_NUCLEO if g["etapa"] == 1 else SellosMagicos.R_ANILLO, 0.0))
			destellos.append([donde, 11.0 * (1.0 - edad / 0.4), Color(nucleo, vida), _t * 2.0])
		var piezas: Array = _geo[gi]
		for k in piezas.size():
			var pz: Dictionary = piezas[k]
			var u: float = clampf((edad - T_PIEZA * float(k)) / T_TRAZA, 0.0, 1.0)
			if u <= 0.0:
				continue
			u = 1.0 - pow(1.0 - u, 2.0)
			if capa == _fondo:
				if float(pz["pozo"]) > 0.0:
					_disco(pv, pc, pi, gi, float(pz["pozo"]), Color(0.02, 0.0, 0.04, 0.9 * vida * u), Color(0.02, 0.0, 0.04, 0.0))
				continue
			var a: float = float(pz["a"]) * a_g
			var col_h := Color(halo, clampf(0.55 * a, 0.0, 1.0))
			var col_n := Color(nucleo, clampf(a, 0.0, 1.0))
			var w: float = ANCHO * float(pz["g"])
			var h: float = HALO * (0.6 + 0.4 * float(pz["g"]))
			var pn: int = 0
			for p in pz["paths"]:
				_banda(pv, pc, pi, gi, p, u, w, h, col_h, col_n, roto, gi * 131 + k * 17 + pn)
				pn += 1
		# El suelo teñido bajo el nucleo y bajo el anillo (flojo: es luz sobre el suelo, no una mancha).
		if capa == _fondo and g["clase"] in ["nucleo", "anillo"]:
			var r_f: float = SellosMagicos.R_NUCLEO if g["clase"] == "nucleo" else SellosMagicos.R_ANILLO + 3.0
			var u2: float = clampf(edad / T_TRAZA, 0.0, 1.0)
			_disco(pv, pc, pi, gi, r_f * u2, Color(halo, 0.10 * vida), Color(halo, 0.03 * vida))
	if not pv.is_empty():
		RenderingServer.canvas_item_add_triangle_array(capa.get_canvas_item(), pi, pv, pc)
	for d in destellos:
		BarridoAire.destello(capa, d[0], d[1], d[2], d[3])
	# EL FOGONAZO DEL DISPARO: el circulo se cierra en un destello en el centro.
	if _estado == Estado.DISPARO and capa == _luz:
		var x2: float = clampf((_t - _t_fin) / T_DISPARO, 0.0, 1.0)
		if x2 > 0.45:
			var tono0: Array = SellosMagicos.tono(int(grupos[0]["elem"]))
			var f: float = (x2 - 0.45) / 0.55
			BarridoAire.destello(capa, Vector2(0.0, -2.0), 38.0 * sin(f * PI) + 4.0, Color(tono0[1], 1.0 - f * f), f * 1.5)


# Un disco con el centro de un color y el borde de otro (el suelo teñido, el pozo de la oscuridad).
func _disco(pv: PackedVector2Array, pc: PackedColorArray, pi: PackedInt32Array, gi: int, r: float,
		c_centro: Color, c_borde: Color) -> void:
	if r <= 0.2:
		return
	var n: int = 24
	var base: int = pv.size()
	pv.append(_xf(gi, Vector2.ZERO))
	pc.append(c_centro)
	for i in n:
		pv.append(_xf(gi, _polar(r, TAU * float(i) / float(n))))
		pc.append(c_borde)
	for i in n:
		pi.append_array([base, base + 1 + i, base + 1 + (i + 1) % n])


# UN TRAZO: banda rellena a lo largo del path, trazada hasta la fraccion 'u' de su largo. A lo ancho, de fuera
# a dentro: transparente, halo, nucleo, halo, transparente. 'roto' se come tramos (el circulo que se rompe).
func _banda(pv: PackedVector2Array, pc: PackedColorArray, pi: PackedInt32Array, gi: int, p: Dictionary,
		u: float, w: float, h: float, col_h: Color, col_n: Color, roto: float, semilla: int) -> void:
	var pts: PackedVector2Array = p["pts"]
	var acum: PackedFloat32Array = p["acum"]
	var nseg: int = acum.size() - 1
	if nseg <= 0:
		return
	var hasta: float = acum[nseg] * u
	var cerrado: bool = p["cerrado"]
	var suave: bool = p["suave"]
	var transp := Color(col_h, 0.0)
	var cols: Array = [transp, col_h, col_n, col_h, transp]
	var offs: Array = [-(w * 0.5 + h), -w * 0.5, 0.0, w * 0.5, w * 0.5 + h]
	var np: int = pts.size()
	for i in nseg:
		if acum[i] >= hasta:
			break
		if roto > 0.0 and _ruido(float(semilla * 97 + i), 3.0) < roto:
			continue
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % np]
		var fin: float = clampf((hasta - acum[i]) / maxf(acum[i + 1] - acum[i], 0.0001), 0.0, 1.0)
		b = a.lerp(b, fin)
		var qa: Vector2 = _xf(gi, a)
		var qb: Vector2 = _xf(gi, b)
		var d: Vector2 = qb - qa
		if d.length_squared() < 0.0001:
			continue
		var n_seg: Vector2 = d.normalized().orthogonal()
		var na: Vector2 = n_seg
		var nb: Vector2 = n_seg
		if suave:
			na = _normal_en(gi, pts, i, cerrado, n_seg)
			nb = _normal_en(gi, pts, (i + 1) % np, cerrado, n_seg) if fin >= 1.0 else n_seg
		var base: int = pv.size()
		for j in 5:
			pv.append(qa + na * offs[j])
			pc.append(cols[j])
		for j in 5:
			pv.append(qb + nb * offs[j])
			pc.append(cols[j])
		for j in 4:
			pi.append_array([base + j, base + j + 1, base + 6 + j, base + j, base + 6 + j, base + 5 + j])


# La normal media en un vertice (los anillos sin juntas que se vean).
func _normal_en(gi: int, pts: PackedVector2Array, i: int, cerrado: bool, def: Vector2) -> Vector2:
	var np: int = pts.size()
	if not cerrado and (i == 0 or i == np - 1):
		return def
	var prev: Vector2 = _xf(gi, pts[(i - 1 + np) % np])
	var aqui: Vector2 = _xf(gi, pts[i])
	var sig: Vector2 = _xf(gi, pts[(i + 1) % np])
	var n1: Vector2 = (aqui - prev).normalized().orthogonal()
	var n2: Vector2 = (sig - aqui).normalized().orthogonal()
	var m: Vector2 = n1 + n2
	if m.length_squared() < 0.0001:
		return def
	return m.normalized()


static func _ruido(x: float, k: float) -> float:
	return fmod(absf(sin(x * 12.9898 + k * 78.233) * 43758.5453), 1.0)
