# ============================================================
#  neblina_fria.gd  (class_name NeblinaFria)
#  LA NEBLINA DEL AURA FRIA del slime de escarcha (07/10, su idea: "una neblina fria permanente alrededor del slime que
#  marque la zona donde afecta"). Siempre puesta, en el mapa y peleando: vaho blanco azulado pegado al SUELO que gira
#  despacio alrededor del slime, con chispitas de escarcha que titilan. EN PIXEL ART (04/11/2026): lo pinta su shader, celda a celda.
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
const _SHADER := preload("res://scripts/fx/neblina_fria.gdshader")
const DIFUMINA := 12.0       # lo que tarda el borde en deshacerse hacia fuera (px de mundo)

static var _cache_pintado := {}

var _principal: AnimatedSprite2D = null


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


func _process(delta: float) -> void:
	if _principal == null or not is_instance_valid(_principal):
		return
	# En MUNDO: donde esta el sprite, sin su escala ni su giro.
	global_transform = Transform2D(0.0, _principal.global_position)
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
		var u: Rect2i = SpriteLienzo.caja_pintada(tex)["caja"]
		if u.size.x > 0 and u.size.y > 0:
			usado = Rect2(usado.position + Vector2(u.position), Vector2(u.size))
		_cache_pintado[clave] = usado
	var origen: Vector2 = _principal.offset - (tex.get_size() * 0.5 if _principal.centered else Vector2.ZERO)
	var esc: Vector2 = _principal.get_global_transform().get_scale().abs()
	return Rect2((usado.position + origen) * esc, usado.size * esc)


func _draw() -> void:
	if _principal == null or not _puede():
		return
	var r: Rect2 = _dibujo()
	if not r.has_area():
		return
	if material == null:
		var m := ShaderMaterial.new()
		m.shader = _SHADER
		m.set_shader_parameter("celda", SpriteLienzo.UNIDADES_POR_CELDA)
		material = m
	var mat: ShaderMaterial = material
	mat.set_shader_parameter("centro", r.get_center())
	mat.set_shader_parameter("media", r.size * 0.5)
	mat.set_shader_parameter("alcance", alcance())
	draw_rect(r.grow(alcance() + DIFUMINA + 6.0), Color.WHITE)
