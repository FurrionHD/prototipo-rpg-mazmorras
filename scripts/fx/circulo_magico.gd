# ============================================================
#  circulo_magico.gd
#  EL CIRCULO MAGICO DE QUIEN RECITA (26/09/2026, idea del usuario). Sale a sus pies con la primera frase y
#  CRECE con cada una: 1 el nucleo, 2 el anillo de fuera, 3 tres satelites que giran sobre si mismos y orbitan,
#  4 una corona que flota sobre la cabeza. Cada magia trae SU receta (SellosMagicos): color, figuras y giros.
#  Al disparar se acelera y se cierra en un fogonazo; al fallar la frase se agrieta, parpadea y se rompe; si se
#  corta (muerte, huida) se apaga.
#  Va colgado del cuerpo (le sigue), como AreaCuracion. El suelo SIN achatar; la corona tiene altura -> y a K.
#  EN PIXEL ART (04/11/2026): cada trazo es una linea de celdas casi blanca con su filo de color y el cuerpo
#  oscuro a trama, en la rejilla de los sprites (ver _hoja y circulo_pixel.gdshader). Nada de alfa a medias.
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
const Z_LUZ := SueloRoto.Z_SUELO + 1
const Z_CORONA := Game.Z_PERSONAJES + 2590   # por encima de TODOS los cuerpos (su tope ronda +2560), bajo los nombres (+2600)

var receta: Dictionary = {}
var auto: bool = true         # false = el reloj lo lleva otro (las hojas: avanzar())
var _t: float = 0.0
var _giro: float = 0.0
var _t_etapa: Array = [-1.0, -1.0, -1.0, -1.0]
var _estado: int = Estado.VIVO
var _t_fin: float = 0.0
var _geo: Array = []          # por grupo: [{paths: [...], pozo: r, g, a}]
var _deriva: Array = []       # por grupo: hacia donde sale despedido al romperse
var _suelo: Dictionary = {}    # las hojas de pixeles (ver _hoja)
var _corona: Dictionary = {}

const CELDA: float = SpriteLienzo.UNIDADES_POR_CELDA
const SHADER := preload("res://scripts/fx/circulo_pixel.gdshader")
const LADO_SUELO := Vector2i(112, 112)   # celdas: la orbita, los satelites y el fogonazo caben
const LADO_CORONA := Vector2i(44, 36)


# FUERA DE COMBATE (casteo_mapa, y lo mismo en las pantallas de los demas por Net.jugadores.anunciar_circulo):
# el circulo de 'cuerpo' pasa a 'dichas' frases o acaba como diga 'fin'. En la pelea lo lleva CombatTactico.
enum Fin { SIGUE, DISPARO, FALLO, APAGA }

static func en_cuerpo(cuerpo: Node2D, spell: SpellData, dichas: int, fin: int) -> void:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return
	var circ: CirculoMagico = null
	for h in cuerpo.get_children():
		if h is CirculoMagico and not (h as CirculoMagico).acabando() and h.has_meta(&"mapa"):
			circ = h
	if circ != null and spell != null and str(circ.receta.get("clave", "")) != SellosMagicos.clave_de(spell):
		circ.apagar()
		circ = null
	if circ == null and spell != null and (fin == Fin.FALLO or (fin == Fin.SIGUE and dichas > 0)):
		circ = crear(cuerpo, spell, Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
		circ.set_meta(&"mapa", true)
	if circ == null:
		return
	match fin:
		Fin.SIGUE: circ.a_la_frase(dichas)
		Fin.DISPARO: circ.disparar()
		Fin.FALLO: circ.fallar()
		_: circ.apagar()


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
	for h in [_suelo, _corona]:
		if not h.is_empty():
			_colocar(h)


# ------------------------------------------------------------
#  LA GEOMETRIA (una vez, en coordenadas de cada grupo)
# ------------------------------------------------------------
func _preparar() -> void:
	_suelo = _hoja(LADO_SUELO, Z_LUZ, 0.0)
	if int(receta.get("n", 1)) >= 4:
		_corona = _hoja(LADO_CORONA, Z_CORONA, -SellosMagicos.ALTO_CORONA)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(receta.get("clave", "")))
	for g in receta.get("grupos", []):
		var piezas: Array = []
		for pz in g["piezas"]:
			piezas.append({"paths": _paths_de(pz), "pozo": float(pz.get("r", 0.0)) if pz["p"] == "pozo" else 0.0,
				"g": float(pz.get("g", 1.0)), "a": float(pz.get("a", 1.0))})
		_geo.append(piezas)
		_deriva.append(Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(6.0, 14.0))


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
#  EL DIBUJO, EN PIXEL ART (04/11/2026): la geometria se traza como MASCARA en un lienzo de 1 celda = 1 pixel
#  (la rejilla de los sprites) y circulo_pixel.gdshader le pone la paleta cerrada del elemento, el filo y el
#  cuerpo oscuro a trama. Se recalcula cada fotograma: al girar salta celda a celda, como un sprite.
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


# La paleta cerrada de cada elemento: [nucleo casi blanco, claro, medio (el halo), oscuro].
static func paleta_pixel() -> PackedColorArray:
	var out := PackedColorArray()
	for e in 6:
		var tonos: Array = SellosMagicos.tono(e)
		var halo: Color = tonos[0]
		var nucleo: Color = tonos[1]
		out.append(nucleo)
		out.append(halo.lerp(nucleo, 0.4))
		out.append(halo)
		out.append(halo.darkened(0.55))
	return out


# Una hoja de pixeles: el lienzo (SubViewport) donde se traza la mascara y el sprite que la pone en el mundo.
func _hoja(lado: Vector2i, z: int, alto: float) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = lado
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var lienzo := Node2D.new()
	vp.add_child(lienzo)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("pal", paleta_pixel())
	var spr := Sprite2D.new()
	spr.texture = vp.get_texture()
	spr.centered = false
	spr.top_level = true
	spr.scale = Vector2(CELDA, CELDA)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_as_relative = false
	spr.z_index = z
	spr.material = mat
	add_child(spr)
	var h := {"vp": vp, "lienzo": lienzo, "spr": spr, "mat": mat, "alto": alto,
		"mitad": Vector2(lado / 2), "off": Vector2(lado / 2), "corona": alto != 0.0}
	lienzo.draw.connect(_pintar.bind(h))
	return h


# El centro cae en una celda del mundo (no tiembla con la camara); lo que sobra va dentro del lienzo.
func _colocar(h: Dictionary) -> void:
	var centro: Vector2 = global_position + Vector2(0.0, float(h["alto"]))
	var c: Vector2 = (centro / CELDA).floor()
	var mitad: Vector2 = h["mitad"]
	(h["spr"] as Sprite2D).global_position = (c - mitad) * CELDA
	h["off"] = centro / CELDA - c + mitad
	var mat: ShaderMaterial = h["mat"]
	mat.set_shader_parameter("celda0", c - mitad)
	var fallo: float = clampf((_t - _t_fin) / T_FALLO, 0.0, 1.0) if _estado == Estado.FALLO else 0.0
	mat.set_shader_parameter("fallo", fallo)
	(h["lienzo"] as Node2D).queue_redraw()


func _en_celdas(h: Dictionary, p_mundo: Vector2) -> Vector2:
	return (p_mundo - Vector2(0.0, float(h["alto"]))) / CELDA + (h["off"] as Vector2)


static func _mascara(clase: float, elem: int, inten: float) -> Color:
	return Color(clase, float(elem) / 8.0, clampf(inten * 0.5, 0.0, 1.0), 1.0)


func _pintar(h: Dictionary) -> void:
	if receta.is_empty():
		return
	var ci: Node2D = h["lienzo"]
	var vida: float = _vida()
	if vida <= 0.0:
		return
	var es_corona: bool = h["corona"]
	var grupos: Array = receta["grupos"]
	var roto: float = _roto()
	var tintes: Array = []      # [centro, radio, color] en celdas
	var pozos: Array = []
	var trazos: Array = []      # [puntos, color, grueso]
	var destellos: Array = []   # [centro, radio, color]
	for gi in grupos.size():
		var g: Dictionary = grupos[gi]
		if es_corona != (g["clase"] == "corona"):
			continue
		var te: float = float(_t_etapa[int(g["etapa"]) - 1])
		if te < 0.0 or _t < te:
			continue
		var el: int = int(g["elem"])
		var edad: float = _t - te
		var boost: float = 1.0 + 1.3 * exp(-edad * 5.0)
		var a_g: float = vida * _brillo() * boost
		# El fogonazo de cuando sale la capa: una estrella maciza.
		if edad < 0.4:
			var donde: Vector2 = _xf(gi, Vector2.ZERO) if g["clase"] in ["sat", "corona"] \
				else _xf(gi, _polar(SellosMagicos.R_NUCLEO if g["etapa"] == 1 else SellosMagicos.R_ANILLO, 0.0))
			destellos.append([_en_celdas(h, donde), 9.0 * (1.0 - edad / 0.4), _mascara(1.0, el, 2.0 * vida)])
		var piezas: Array = _geo[gi]
		for k in piezas.size():
			var pz: Dictionary = piezas[k]
			var u: float = clampf((edad - T_PIEZA * float(k)) / T_TRAZA, 0.0, 1.0)
			if u <= 0.0:
				continue
			u = 1.0 - pow(1.0 - u, 2.0)
			if float(pz["pozo"]) > 0.0:
				pozos.append([_en_celdas(h, _xf(gi, Vector2.ZERO)), float(pz["pozo"]) * _escala() / CELDA,
					_mascara(0.3, el, 2.0 * vida * u)])
				continue
			# Fuerte = nucleo casi blanco con filo; fino = tono claro; tenue (la orbita) = tono medio. Lo tenue NO va a
			# trama (saldria en motas sueltas): la trama es solo para lo que se apaga.
			var fuerte: bool = float(pz["g"]) >= 0.75 and float(pz["a"]) >= 0.6
			var clase: float = 1.0 if fuerte else (0.6 if float(pz["a"]) >= 0.6 else 0.5)
			var col: Color = _mascara(clase, el, a_g)
			var gr: float = 2.0 if float(pz["g"]) >= 1.1 else -1.0
			var pn: int = 0
			for p in pz["paths"]:
				for tramo in _tramos(h, gi, p, u, roto, gi * 131 + k * 17 + pn):
					trazos.append([tramo, col, gr])
				pn += 1
		# (La luz teñida en el suelo de la version dibujada no va: a trama salia como manchas de barro.)
	# EL FOGONAZO DEL DISPARO: el circulo se cierra en una estrella en el centro.
	if _estado == Estado.DISPARO and not es_corona:
		var x2: float = clampf((_t - _t_fin) / T_DISPARO, 0.0, 1.0)
		if x2 > 0.45:
			var f: float = (x2 - 0.45) / 0.55
			destellos.append([_en_celdas(h, Vector2(0.0, -2.0)), (34.0 * sin(f * PI) + 4.0) / CELDA,
				_mascara(1.0, int(grupos[0]["elem"]), 2.0 * (1.0 - f * f))])
	# Por orden: la luz del suelo, los pozos, los trazos y los destellos encima.
	for d in tintes:
		if float(d[1]) > 0.3:
			ci.draw_circle(d[0], d[1], d[2], true, -1.0, false)
	for d in pozos:
		if float(d[1]) > 0.3:
			ci.draw_circle(d[0], d[1], d[2], true, -1.0, false)
	for d in trazos:
		ci.draw_polyline(d[0], d[1], d[2], false)
	for d in destellos:
		_estrella(ci, d[0], d[1], d[2])


# Los tramos de un path trazado hasta la fraccion 'u' de su largo, ya en celdas; 'roto' se come trozos.
func _tramos(h: Dictionary, gi: int, p: Dictionary, u: float, roto: float, semilla: int) -> Array:
	var pts: PackedVector2Array = p["pts"]
	var acum: PackedFloat32Array = p["acum"]
	var nseg: int = acum.size() - 1
	var out: Array = []
	if nseg <= 0:
		return out
	var hasta: float = acum[nseg] * u
	var np: int = pts.size()
	var cur := PackedVector2Array()
	for i in nseg:
		if acum[i] >= hasta:
			break
		if roto > 0.0 and _ruido(float(semilla * 97 + i), 3.0) < roto:
			if cur.size() >= 2:
				out.append(cur)
			cur = PackedVector2Array()
			continue
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % np]
		var fin: float = clampf((hasta - acum[i]) / maxf(acum[i + 1] - acum[i], 0.0001), 0.0, 1.0)
		if cur.is_empty():
			cur.append(_en_celdas(h, _xf(gi, a)))
		cur.append(_en_celdas(h, _xf(gi, a.lerp(b, fin))))
	if cur.size() >= 2:
		out.append(cur)
	return out


# Un destello = estrella MACIZA de cuatro puntas (la receta de los efectos en pixel), en celdas.
func _estrella(ci: Node2D, c: Vector2, r: float, col: Color) -> void:
	if r < 1.0 or col.b <= 0.0:
		return
	var pts := PackedVector2Array()
	for k in 8:
		var ang: float = PI * 0.25 * float(k)
		pts.append(c + Vector2(cos(ang), sin(ang)) * (r if k % 2 == 0 else maxf(1.2, r * 0.24)))
	ci.draw_colored_polygon(pts, col)


static func _ruido(x: float, k: float) -> float:
	return fmod(absf(sin(x * 12.9898 + k * 78.233) * 43758.5453), 1.0)
