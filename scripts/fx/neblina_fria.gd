# ============================================================
#  neblina_fria.gd  (class_name NeblinaFria)
#  LA NEBLINA DEL AURA FRIA del slime de escarcha (07/10, su idea: "una neblina fria permanente alrededor del slime que
#  marque la zona donde afecta"). Siempre puesta, en el mapa y peleando: vaho blanco azulado pegado al SUELO que gira
#  despacio alrededor del slime, con chispitas de escarcha que titilan. Sin una raya ([[efectos-sin-lineas]]): todo
#  relleno y con degradado.
#  LA ZONA ES LA DE VERDAD: el aura le cala a quien acaba su turno con los PIES a menos de HUECO_CUERPO_A_CUERPO (30)
#  del dibujo del slime, descontando lo que pisa (combat._aura_fria -> turno_mapa.hueco_entre). O sea, el dibujo
#  ensanchado por 30 + lo que pisa un personaje (PoseJugador.CAJA_CUERPO x CombatTactico.PISA): un rectangulo con las
#  esquinas redondas. El borde de la neblina (donde se espesa y luego se deshace) cae justo ahi.
#  Como HumoToxico: una capa HIJA del sprite (nace y muere con el, sigue su visibilidad y su tinte), pero se pinta en
#  coordenadas de MUNDO (deshace la escala del sprite) y en la capa del suelo (bajo los cuerpos de todos).
# ============================================================
extends Node2D
class_name NeblinaFria

const NOMBRE := "NeblinaFria"
const PUNTOS_ESQUINA := 9
const DIFUMINA := 12.0       # lo que tarda el borde en deshacerse hacia fuera (px de mundo)
const VAHOS := 18
const CHISPAS := 7
const VIDA_CHISPA := 1.4
const VAHO := Color(0.80, 0.90, 1.0)
const ESCARCHA := Color(0.90, 0.96, 1.0)

static var _cache_pintado := {}

var _principal: AnimatedSprite2D = null
var _t: float = 0.0
var _vahos: Array = []       # {u (sitio en el borde, 0..1), v (velocidad), r, fase, hondo (0..1 hacia dentro)}
var _chispas: Array = []     # {u, hondo, t, r}


# Se la pone (o se la quita, 'lleva' false) a 'sprite'.
static func poner(sprite: AnimatedSprite2D, lleva_: bool) -> void:
	if sprite == null:
		return
	var n: NeblinaFria = sprite.get_node_or_null(NOMBRE) as NeblinaFria
	if not lleva_:
		if n != null:
			n.queue_free()
		return
	if n == null:
		n = NeblinaFria.new()
		n.name = NOMBRE
		sprite.add_child(n)
	n._principal = sprite


# ¿La lleva este enemigo? Los mutantes con aura fria en su MutacionData (hoy, el slime de escarcha).
static func lleva(ed: EnemyData, mutante: bool, mutacion: StringName) -> bool:
	if ed == null or not mutante:
		return false
	var m: MutacionData = ed.mutacion_de(mutacion)
	return m != null and m.aura_fria


# Hasta donde llega el aura desde el borde del dibujo: el hueco cuerpo a cuerpo de la pelea (combat.gd,
# HUECO_CUERPO_A_CUERPO) mas lo que pisa un personaje (CombatTactico.radio_pisa: su caja x PISA).
static func alcance() -> float:
	return 30.0 + PoseJugador.CAJA_CUERPO.size.x * 0.33


func _ready() -> void:
	z_as_relative = false
	z_index = SueloRoto.Z_SUELO
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id())
	_t = rng.randf_range(0.0, 20.0)
	for i in VAHOS:
		_vahos.append({"u": (float(i) + rng.randf_range(-0.3, 0.3)) / float(VAHOS), "v": rng.randf_range(0.012, 0.022),
			"r": rng.randf_range(9.0, 15.0), "fase": rng.randf_range(0.0, TAU), "hondo": rng.randf_range(0.0, 0.35)})
	for i in CHISPAS:
		_chispas.append({"u": rng.randf(), "hondo": rng.randf_range(0.05, 0.9), "t": rng.randf_range(0.0, VIDA_CHISPA),
			"r": rng.randf_range(2.4, 3.6)})


func _process(delta: float) -> void:
	if _principal == null or not is_instance_valid(_principal):
		return
	# En MUNDO: donde esta el sprite, sin su escala ni su giro.
	global_transform = Transform2D(0.0, _principal.global_position)
	_t += delta
	for ch in _chispas:
		ch["t"] = float(ch["t"]) + delta
		if float(ch["t"]) >= VIDA_CHISPA:
			ch["t"] = 0.0
			ch["u"] = randf()
			ch["hondo"] = randf_range(0.05, 0.9)
	queue_redraw()


func _puede() -> bool:
	var a: String = String(_principal.animation)
	return not (a.begins_with("muerte") or a.begins_with("cadaver")) and _principal.is_visible_in_tree()


# EL DIBUJO DEL SLIME en mundo, relativo a su sprite: lo pintado de su 'idle' (no del fotograma que se ve, que la
# neblina no baile con cada bote). Lo mismo que mide la pelea (CombatTactico.rect_dibujo), cacheado por textura.
func _dibujo() -> Rect2:
	var sf: SpriteFrames = _principal.sprite_frames
	if sf == null:
		return Rect2()
	var anim: StringName = &"idle_0" if sf.has_animation(&"idle_0") else _principal.animation
	if not sf.has_animation(anim):
		return Rect2()
	var tex: Texture2D = sf.get_frame_texture(anim, 0)
	if tex == null:
		return Rect2()
	var clave: int = tex.get_instance_id()
	var usado: Rect2
	if _cache_pintado.has(clave):
		usado = _cache_pintado[clave]
	else:
		# (como CombatTactico._pintado_local: los fotogramas son recortes de un atlas con su margen)
		usado = Rect2(Vector2.ZERO, tex.get_size())
		if tex is AtlasTexture:
			usado = Rect2((tex as AtlasTexture).margin.position, (tex as AtlasTexture).region.size)
		var img: Image = tex.get_image()
		if img != null:
			var u: Rect2i = img.get_used_rect()
			if u.size.x > 0 and u.size.y > 0:
				usado = Rect2(usado.position + Vector2(u.position), Vector2(u.size))
		_cache_pintado[clave] = usado
	var origen: Vector2 = _principal.offset - (tex.get_size() * 0.5 if _principal.centered else Vector2.ZERO)
	var esc: Vector2 = _principal.get_global_transform().get_scale().abs()
	return Rect2((usado.position + origen) * esc, usado.size * esc)


# EL BORDE DE LA ZONA: el dibujo ensanchado por el alcance (las esquinas, cuartos de circulo; los lados, rectos).
func _borde(r: Rect2, d: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var esquinas: Array = [r.end, Vector2(r.position.x, r.end.y), r.position, Vector2(r.end.x, r.position.y)]
	for k in 4:
		for i in PUNTOS_ESQUINA:
			var a: float = PI * 0.5 * (float(k) + float(i) / float(PUNTOS_ESQUINA - 1))
			pts.append((esquinas[k] as Vector2) + Vector2(cos(a), sin(a)) * d)
	return pts


# Un sitio del borde, de 0 a 1 vuelta (interpolado entre sus puntos).
static func _en_borde(pts: PackedVector2Array, u: float) -> Vector2:
	var n: int = pts.size()
	var f: float = fposmod(u, 1.0) * float(n)
	var i: int = int(f) % n
	return pts[i].lerp(pts[(i + 1) % n], f - floorf(f))


func _draw() -> void:
	if _principal == null or not _puede():
		return
	var r: Rect2 = _dibujo()
	if not r.has_area():
		return
	var c: Vector2 = r.get_center()
	var pts: PackedVector2Array = _borde(r, alcance())
	var n: int = pts.size()
	# EL VELO: casi nada junto al cuerpo, se espesa hacia el borde de la zona y se deshace justo despues. El borde
	# respira (cada punto a su ritmo) para que no sea una forma dura.
	var dentro := PackedVector2Array()
	var borde := PackedVector2Array()
	var fuera := PackedVector2Array()
	var alfas := PackedFloat32Array()
	for i in n:
		var p: Vector2 = pts[i]
		var hacia: Vector2 = (p - c).normalized()
		var ola: float = sin(_t * 0.7 + float(i) * 1.3) * 2.0
		borde.append(p + hacia * ola)
		dentro.append(c + (p - c) * 0.7)
		fuera.append(p + hacia * (DIFUMINA + ola))
		alfas.append(0.85 + 0.15 * sin(_t * 0.9 + float(i) * 0.7))
	var transp := Color(VAHO, 0.0)
	for i in n:
		var j: int = (i + 1) % n
		var cin_i := Color(VAHO, 0.10 * alfas[i])
		var cin_j := Color(VAHO, 0.10 * alfas[j])
		var cb_i := Color(VAHO, 0.26 * alfas[i])
		var cb_j := Color(VAHO, 0.26 * alfas[j])
		draw_primitive(PackedVector2Array([c, dentro[i], dentro[j]]), PackedColorArray([Color(VAHO, 0.05), cin_i, cin_j]),
			PackedVector2Array())
		draw_primitive(PackedVector2Array([dentro[i], borde[i], borde[j]]), PackedColorArray([cin_i, cb_i, cb_j]),
			PackedVector2Array())
		draw_primitive(PackedVector2Array([dentro[i], borde[j], dentro[j]]), PackedColorArray([cin_i, cb_j, cin_j]),
			PackedVector2Array())
		draw_primitive(PackedVector2Array([borde[i], fuera[i], fuera[j]]), PackedColorArray([cb_i, transp, transp]),
			PackedVector2Array())
		draw_primitive(PackedVector2Array([borde[i], fuera[j], borde[j]]), PackedColorArray([cb_i, transp, cb_j]),
			PackedVector2Array())
	# EL VAHO: bocanadas suaves que dan la vuelta despacio por dentro del borde, cada una respirando a su aire.
	for vh in _vahos:
		var p2: Vector2 = _en_borde(borde, float(vh["u"]) + _t * float(vh["v"]))
		var q: Vector2 = p2.lerp(c, 0.08 + float(vh["hondo"]) * 0.3)
		var resp: float = 0.5 + 0.5 * sin(_t * 0.8 + float(vh["fase"]))
		BarridoAire.brillo(self, q, float(vh["r"]) * (0.85 + 0.3 * resp), Color(VAHO, 0.12 + 0.12 * resp))
	# LAS CHISPITAS de escarcha: nacen en un sitio de la zona, suben un pelo, titilan y se apagan.
	for ch in _chispas:
		var k: float = float(ch["t"]) / VIDA_CHISPA
		var p3: Vector2 = _en_borde(borde, float(ch["u"])).lerp(c, float(ch["hondo"]) * 0.75) - Vector2(0.0, 6.0 * k)
		var brilla: float = sin(PI * k)
		BarridoAire.destello(self, p3, float(ch["r"]) * (0.6 + 0.4 * brilla), Color(ESCARCHA, 0.9 * brilla), float(ch["u"]) * TAU)
