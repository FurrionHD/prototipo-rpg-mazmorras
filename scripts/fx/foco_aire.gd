# (10/11 TARDE: ahora es un CIRCULO alrededor suyo y solo se pintan HACES: ver _pintar_haces. Lo del cono sigue para
# una ficha en cono.)
# EL DESTELLO DEL MICONIDO COMO FOCO (10/11/2026, el jefe: "el destello visualmente no alcanza a los objetivos que
# supuestamente deberia golpear"). Su golpe es un CONO EN EL SUELO (la ficha: 60 de largo, 90 grados, desde delante de
# sus pies y hacia su objetivo); el dibujo de antes era un abanico en el aire, desde la campana y en 8 direcciones.
# Ahora (eligio "foco: campana + suelo"):
#   - un fogonazo en su campana,
#   - un HAZ translucido de la campana al cono,
#   - y en el suelo EL CONO EXACTO DEL GOLPE (mismo origen, largo, abertura y direccion: la Forma de la pelea), que se
#     abre desde sus pies; a cada uno el golpe le llega cuando la luz le alcanza (retraso).
# En pixel (celdas de SpriteLienzo.UNIDADES_POR_CELDA) y sin rejilla: alfa en 4 escalones (memoria transparencia-de-verdad).
# Va por SueloRoto (Tipo.MICONIDO_FOCO): sale igual en todas las pantallas.
extends Node2D

const TACTICO := preload("res://scripts/ui/combat_tactico.gd")

const T_ABRE := 0.22      # lo que tarda la luz en llegar al borde del cono
const T_DURA := 0.38      # lo que se queda encendido entero
const T_APAGA := 0.36     # y lo que tarda en irse (en 4 escalones)
const T_FOGONAZO := 0.16  # la estrella de su campana
# (los de la lamina: miconido_efectos_pixel.LUZ)
const LUZ := [Color8(16, 74, 82), Color8(40, 160, 162), Color8(120, 232, 214), Color8(232, 255, 250)]

var _f: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _desde: Vector2 = Vector2.ZERO   # el nucleo de su campana (de donde baja el haz)
var _suelo: Sprite2D = null
var _haz: Sprite2D = null
var _clave: String = ""


static func lanzar(padre: Node, f: CombatFormas.Forma, espera: float) -> Node2D:
	if padre == null or f == null:
		return null
	var n = load("res://scripts/fx/foco_aire.gd").new()
	n._f = f
	n._ritmo = maxf(BarridoAire.ritmo, 0.05)
	n._t = -maxf(espera, 0.0) * n._ritmo
	n._desde = _campana_cerca(padre, SueloRoto.origen_de(f))
	n.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(n)
	n._montar()
	return n


static func retraso(f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	return clampf(p.distance_to(SueloRoto.origen_de(f)) / maxf(f.radio, 1.0), 0.0, 1.0) * T_ABRE


# EL NUCLEO DE LA CAMPANA de quien lo lanza: el cuerpo con Destello (grupo enemy, o hijo de la arena) mas cercano al origen del cono (en todas las
# pantallas esta ahi: no hace falta mandar nada). Donde lo pone la lamina (miconido_efectos_pixel.campana_de): la
# Campana al 19 % de su dibujo, el Florecido (la campana sobre el yelmo) al 13,5 %.
static func _campana_cerca(padre: Node, o: Vector2) -> Vector2:
	var mejor: Node2D = null
	var d_mejor: float = INF
	var candidatos: Array = padre.get_children()
	if padre.is_inside_tree():
		candidatos.append_array(padre.get_tree().get_nodes_in_group(&"enemy"))
	for hijo in candidatos:
		if not (hijo is Node2D):
			continue
		var spr = _sprite_de(hijo)
		if spr == null:
			continue
		var sf: SpriteFrames = (spr as AnimatedSprite2D).sprite_frames
		if not (sf.has_animation(&"destello_1") or sf.has_animation(&"destello_0")):
			continue
		var d: float = (hijo as Node2D).global_position.distance_squared_to(o)
		if d < d_mejor:
			d_mejor = d
			mejor = hijo
	if mejor == null:
		return o + Vector2(0.0, -60.0)
	var r: Rect2 = TACTICO.rect_dibujo(mejor)
	if not r.has_area():
		return o + Vector2(0.0, -60.0)
	var florecido: bool = _sprite_de(mejor).sprite_frames.has_animation(&"estocada_1")
	return Vector2(r.get_center().x, r.position.y + r.size.y * (0.135 if florecido else 0.19))


static func _sprite_de(n: Node) -> AnimatedSprite2D:
	for hijo in n.get_children():
		if hijo is AnimatedSprite2D and (hijo as AnimatedSprite2D).sprite_frames != null:
			return hijo
	return null


func _montar() -> void:
	_suelo = _capa(SueloRoto.Z_SUELO)
	_haz = _capa(Game.Z_ENCIMA_PERSONAJES + 80)
	_pintar()


func _capa(z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	s.z_as_relative = false
	s.scale = Vector2.ONE * SpriteLienzo.UNIDADES_POR_CELDA
	s.visible = false
	add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= T_ABRE + T_DURA + T_APAGA:
		queue_free()
		return
	_pintar()


# Cuanto se ha abierto (0..1, en 6 pasos: salta celda a celda como un sprite) y cuanto queda (4 escalones de alfa).
func _estado() -> Vector2i:
	if _t < 0.0:
		return Vector2i(-1, 0)
	var abre: int = clampi(int(ceil(_t / T_ABRE * 6.0)), 1, 6)
	var queda: int = 4
	if _t > T_ABRE + T_DURA:
		queda = clampi(4 - int(floor((_t - T_ABRE - T_DURA) / T_APAGA * 4.0)), 1, 4)
	return Vector2i(abre, queda)


func _pintar() -> void:
	var e: Vector2i = _estado()
	var clave: String = "%d_%d_%d_%d" % [e.x, e.y, int(_t < T_FOGONAZO and _t >= 0.0), _tic()]
	if clave == _clave:
		return
	_clave = clave
	if e.x < 0:
		_suelo.visible = false
		_haz.visible = false
		return
	if _f.tipo == CombatFormas.Tipo.CIRCULO:
		_suelo.visible = false
		_pintar_haces(e)
		return
	var celda: float = SpriteLienzo.UNIDADES_POR_CELDA
	var o: Vector2 = SueloRoto.origen_de(_f)
	var dir: Vector2 = _f.dir.normalized() if _f.dir.length_squared() > 0.0001 else Vector2.DOWN
	var mitad: float = deg_to_rad(_f.apertura * 0.5)
	var radio: float = _f.radio
	var llega: float = radio * float(e.x) / 6.0
	var q: float = float(e.y) / 4.0
	# --- EL SUELO: el cono del golpe ---
	var caja := Rect2(o, Vector2.ZERO)
	for k in 9:
		caja = caja.expand(o + dir.rotated(-mitad + mitad * 2.0 * float(k) / 8.0) * radio)
	caja = caja.grow(celda * 2.0)
	var w: int = int(ceil(caja.size.x / celda))
	var h: int = int(ceil(caja.size.y / celda))
	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	for cy in h:
		for cx in w:
			var p: Vector2 = caja.position + (Vector2(cx, cy) + Vector2(0.5, 0.5)) * celda
			var v: Vector2 = p - o
			var d: float = v.length()
			if d > llega:
				continue
			var ang: float = absf(v.angle_to(dir)) if d > 0.5 else 0.0
			if ang > mitad:
				continue
			var u: float = d / maxf(radio, 1.0)
			var borde: bool = d > llega - celda * 1.5 or ang > mitad - celda * 1.2 / maxf(d, 1.0)
			var rayo: bool = sin(v.angle() * 23.0) > 0.3
			var col: Color
			var a: float
			# (el borde, apenas: "que los bordes en el suelo sean menos marcados")
			if borde:
				col = LUZ[1]
				a = 0.5 if u < 0.6 else 0.25
			elif rayo and u < 0.8:
				col = LUZ[2] if u < 0.4 else LUZ[1]
				a = 0.5
			else:
				col = LUZ[1] if u < 0.5 else LUZ[0]
				a = 0.5 if u < 0.5 else 0.25
			if u < 0.1:
				col = LUZ[2]
				a = 0.5
			col.a = _escalon(a * q)
			if col.a > 0.0:
				img.set_pixel(cx, cy, col)
	_suelo.texture = ImageTexture.create_from_image(img)
	_suelo.global_position = caja.position
	_suelo.visible = true
	# --- EL HAZ: de su campana al cono (lo que llega de la luz), translucido, y el fogonazo en la campana ---
	var a_izq: Vector2 = o + dir.rotated(-mitad) * llega
	var a_der: Vector2 = o + dir.rotated(mitad) * llega
	var tri := PackedVector2Array([_desde, a_izq, a_der])
	var caja_h := Rect2(_desde, Vector2.ZERO).expand(a_izq).expand(a_der).expand(o).grow(celda * 10.0)
	var wh: int = int(ceil(caja_h.size.x / celda))
	var hh: int = int(ceil(caja_h.size.y / celda))
	var imh := Image.create(maxi(wh, 1), maxi(hh, 1), false, Image.FORMAT_RGBA8)
	var fogonazo: bool = _t < T_FOGONAZO
	for cy in hh:
		for cx in wh:
			var p2: Vector2 = caja_h.position + (Vector2(cx, cy) + Vector2(0.5, 0.5)) * celda
			var rel: Vector2 = p2 - _desde
			var col2 := Color(0, 0, 0, 0)
			if Geometry2D.is_point_in_polygon(p2, tri):
				var rayo2: bool = sin(rel.angle() * 31.0) > 0.55
				col2 = LUZ[2] if rayo2 else LUZ[1]
				col2.a = _escalon((0.5 if rayo2 else 0.25) * q * (1.0 if rel.length() > celda * 3.0 else 2.0))
			# el fogonazo: una estrella de cuatro puntas en la campana
			if fogonazo:
				var ax: float = absf(rel.x) / celda
				var ay: float = absf(rel.y) / celda
				if (ax < 0.6 and ay < 9.0) or (ay < 0.6 and ax < 12.0):
					col2 = LUZ[3]
					col2.a = 1.0
				elif ax + ay < 3.0:
					col2 = LUZ[2]
					col2.a = 1.0
			if col2.a > 0.0:
				imh.set_pixel(cx, cy, col2)
	_haz.texture = ImageTexture.create_from_image(imh)
	_haz.global_position = caja_h.position
	_haz.visible = true


# EL DESTELLO EN CIRCULO (10/11, su idea: "brilla toda su campana, que pegue en area alrededor suyo; quitamos la marca y
# que solo se vean los haces de luz"). HACES de la campana hacia el suelo que cubren el circulo del golpe (la ficha,
# alrededor de sus pies) con una rendija entre uno y otro; el fogonazo en la campana. Nada en el suelo.
# "mucho mejor pero seguro que podemos hacer que los haces de luz esten mucho mas guapos": VERSIONES para la lamina
# (tools/ver_destello_versiones): 0 = el de antes (plano); 1 = NUCLEO (centro casi blanco, medio cian, borde tenue;
# anchos y largos alternos); 2 = 1 + MOTAS que bajan por los haces y parpadean; 3 = 1 + ABANICO VIVO (se abren
# escalonados y giran un poco); 4 = todo y un HALO en la campana.
const HACES := 12
const HAZ_LLENA := 0.8
const T_CELDA := 0.06   # cada cuanto se repinta lo que se mueve (salta como un sprite)
static var VERSION_DEF: int = 4
var version: int = VERSION_DEF


# Lo que necesita repintar la version que se mueve.
func _tic() -> int:
	return int(_t / T_CELDA) if version >= 2 and _f != null and _f.tipo == CombatFormas.Tipo.CIRCULO else 0


func _pintar_haces(e: Vector2i) -> void:
	var celda: float = SpriteLienzo.UNIDADES_POR_CELDA
	var o: Vector2 = _f.centro
	var q: float = float(e.y) / 4.0
	var nucleo: bool = version >= 1
	var motas: bool = version == 2 or version == 4
	var vivo: bool = version >= 3
	var giro: float = (0.10 * _t) if vivo else 0.0
	var haces: Array = []   # {d (eje), largo, media (medio ancho al final), claro}
	for k in HACES:
		var fino: bool = nucleo and k % 2 == 1
		var abre: float = float(e.x) / 6.0
		if vivo:
			# escalonados: cada uno sale un poco despues, en orden alrededor
			var orden: int = (k * 5) % HACES
			abre = clampf((_t - float(orden) * 0.012) / T_ABRE, 0.0, 1.0)
			abre = ceil(abre * 6.0) / 6.0
		if abre <= 0.0:
			continue
		var ang: float = TAU * (float(k) + 0.5) / float(HACES) + giro
		var dir_s: Vector2 = Vector2.RIGHT.rotated(ang)
		var radio_k: float = _f.radio * (0.94 if fino else 1.0)
		var punta: Vector2 = o + dir_s * radio_k * abre
		var eje: Vector2 = punta - _desde
		var largo: float = maxf(eje.length(), 1.0)
		var media: float = (TAU * radio_k * abre / float(HACES)) * HAZ_LLENA * 0.5 * (0.55 if fino else 1.0)
		haces.append({"d": eje / largo, "largo": largo, "media": media, "claro": not fino if nucleo else k % 2 == 0, "k": k})
	var caja := Rect2(_desde, Vector2.ZERO).expand(o + Vector2(_f.radio, _f.radio) * 1.1).expand(o - Vector2(_f.radio, _f.radio) * 1.1)
	caja = caja.grow(celda * 12.0)
	var w: int = int(ceil(caja.size.x / celda))
	var h: int = int(ceil(caja.size.y / celda))
	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	var fogonazo: bool = _t < T_FOGONAZO
	for cy in h:
		for cx in w:
			var p: Vector2 = caja.position + (Vector2(cx, cy) + Vector2(0.5, 0.5)) * celda
			var rel: Vector2 = p - _desde
			var col := Color(0, 0, 0, 0)
			for hz in haces:
				var d: Vector2 = hz["d"]
				var a_lo: float = rel.dot(d)
				var largo: float = hz["largo"]
				if a_lo <= 0.0 or a_lo > largo:
					continue
				var u: float = a_lo / largo
				var mitad: float = maxf(float(hz["media"]) * u, celda * 0.5)
				var s_l: float = absf(rel.cross(d)) / mitad
				if s_l > 1.0:
					continue
				var c2: Color
				var a: float
				if nucleo:
					if s_l < 0.22 and hz["claro"]:
						c2 = LUZ[3]
						a = 0.75
					elif s_l < 0.55:
						c2 = LUZ[2]
						a = 0.5
					else:
						c2 = LUZ[1]
						a = 0.25 if u > 0.3 else 0.5
					a *= 1.0 - 0.55 * u * u
				else:
					var claro: bool = hz["claro"]
					c2 = LUZ[2] if claro and u < 0.6 else LUZ[1]
					a = (0.5 if claro else 0.25) * (1.0 - 0.5 * u)
				if rel.length() < celda * 3.0:
					a *= 2.0
				c2.a = _escalon(a * q)
				if c2.a > col.a:
					col = c2
			# EL HALO de la campana (4): tres aros de luz que no son lineas, son manchas en escalones
			if version == 4:
				var dh: float = rel.length() / celda
				var ah: float = 0.0
				var ch: Color = LUZ[1]
				if dh < 5.0:
					ah = 0.5
					ch = LUZ[2]
				elif dh < 9.0:
					ah = 0.25
					ch = LUZ[2]
				elif dh < 13.0:
					ah = 0.25
				ch.a = _escalon(ah * q)
				if ch.a > col.a:
					col = ch
			if fogonazo:
				var ax: float = absf(rel.x) / celda
				var ay: float = absf(rel.y) / celda
				if (ax < 0.6 and ay < 9.0) or (ay < 0.6 and ax < 12.0):
					col = LUZ[3]
					col.a = 1.0
				elif ax + ay < 3.0:
					col = LUZ[2]
					col.a = 1.0
			if col.a > 0.0:
				img.set_pixel(cx, cy, col)
	# LAS MOTAS (2 y 4): tres por haz, bajan por dentro y parpadean; una celda, luz entera
	if motas and e.y >= 2:
		for hz in haces:
			for m in 3:
				var sem: float = float(int(hz["k"]) * 7 + m * 13)
				var u_m: float = fposmod(sem * 0.137 + _t * 0.9, 1.0)
				if sin(_t * 23.0 + sem) < -0.2:
					continue
				var lat: float = (fposmod(sem * 0.311, 1.0) - 0.5) * 0.9
				var d_m: Vector2 = hz["d"]
				var pm: Vector2 = _desde + d_m * float(hz["largo"]) * u_m + d_m.orthogonal() * float(hz["media"]) * u_m * lat
				var cm: Vector2i = Vector2i(((pm - caja.position) / celda).floor())
				if cm.x >= 0 and cm.y >= 0 and cm.x < w and cm.y < h:
					var cmc: Color = LUZ[3]
					cmc.a = 1.0 if e.y >= 3 else 0.5
					img.set_pixelv(cm, cmc)
	_haz.texture = ImageTexture.create_from_image(img)
	_haz.global_position = caja.position
	_haz.visible = true


# Alfa en 4 escalones (25/50/75/100 %): nada a medias, nada de trama.
static func _escalon(a: float) -> float:
	if a < 0.125:
		return 0.0
	return clampf(roundf(a * 4.0) / 4.0, 0.25, 1.0)
