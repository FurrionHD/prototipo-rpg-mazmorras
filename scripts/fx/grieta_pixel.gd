# ============================================================
#  grieta_pixel.gd  (class_name GrietaPixel)
#  EL LATIDO DE LAS GRIETAS VIOLETA DEL ESPANTAJO, EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art): lo que ya trae su sprite no se
#  vuelve a dibujar; se le ENCIENDEN sus propios pixeles violeta, fotograma a fotograma (un shader sobre su dibujo de ahora). CARGA = el Geiser
#  cargando (late cada vez mas deprisa); SECO = cuanto mas seco, mas le laten y mas se extienden (nivel = los tramos).
#  Va de hijo del sprite: le sigue, se esconde y se tine con el.
# ============================================================
extends Node2D
class_name GrietaPixel

const NOMBRE := "GrietaPixel"
const _CODIGO := """shader_type canvas_item;
uniform vec4 luz : source_color;
uniform vec4 medio : source_color;
uniform float late = 1.0;
uniform int extiende = 0;
bool violeta(vec2 uv) {
	vec4 t = texture(TEXTURE, uv);
	return t.a > 0.5 && t.b > 0.47 && (t.b - t.g) > 0.157 && t.r > t.g;
}
void fragment() {
	bool v = violeta(UV);
	if (!v && extiende > 0 && texture(TEXTURE, UV).a > 0.5) {
		vec2 p = TEXTURE_PIXEL_SIZE;
		v = violeta(UV + vec2(0.0, p.y)) || violeta(UV - vec2(0.0, p.y));
		if (extiende > 1) {
			v = v || violeta(UV + vec2(p.x, 0.0)) || violeta(UV - vec2(p.x, 0.0));
		}
	}
	COLOR = v ? (late > 0.5 ? luz : medio) : vec4(0.0);
}
"""
const LUZ := Color8(190, 160, 250)
const MEDIO := Color8(84, 56, 138)

static var _shader: Shader = null
static var _shader_reflejo: Shader = null

# EL REFLEJO (el Caparazon del escarabajo): una franja diagonal clara que le cruza lo claro de su dibujo, de punta a punta.
const _CODIGO_REFLEJO := """shader_type canvas_item;
uniform vec4 luz : source_color;
uniform vec4 medio : source_color;
uniform float pasa = 0.0;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	vec2 tam = 1.0 / TEXTURE_PIXEL_SIZE;
	float d = abs((p.x + p.y * 0.6) - pasa * (tam.x + tam.y * 0.6));
	bool claro = t.a > 0.5 && (t.r + t.g + t.b) > 0.35;
	COLOR = (claro && d < 3.0) ? luz : ((claro && d < 5.0) ? medio : vec4(0.0));
}
"""
var _reflejo: float = -1.0
var _t_reflejo: float = 0.4

var nivel: int = 1
var carga: bool = false
var _spr: AnimatedSprite2D = null
var _t: float = 0.0
var _mat: ShaderMaterial = null


static func poner(spr: AnimatedSprite2D, es_carga: bool, nivel_: int) -> GrietaPixel:
	if spr == null:
		return null
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _CODIGO
	var g := GrietaPixel.new()
	g.name = NOMBRE
	g._spr = spr
	g.carga = es_carga
	g.nivel = maxi(nivel_, 1)
	g._mat = ShaderMaterial.new()
	g._mat.shader = _shader
	g._mat.set_shader_parameter("luz", LUZ)
	g._mat.set_shader_parameter("medio", MEDIO)
	g.material = g._mat
	g.z_index = 1
	g.process_mode = Node.PROCESS_MODE_ALWAYS
	spr.add_child(g)
	return g


# (lo de los demas pegados: TacticoTrent les habla igual a todos)
func seguir(_caja: Rect2) -> void:
	pass


func poner_nivel(n: int) -> void:
	nivel = maxi(n, 1)


func secar() -> void:
	queue_free()


static func reflejo(spr: AnimatedSprite2D, espera: float, dur: float = 0.4) -> GrietaPixel:
	if spr == null:
		return null
	if _shader_reflejo == null:
		_shader_reflejo = Shader.new()
		_shader_reflejo.code = _CODIGO_REFLEJO
	var g := GrietaPixel.new()
	g._spr = spr
	g._reflejo = -maxf(espera, 0.0)
	g._t_reflejo = maxf(dur, 0.05)
	g._mat = ShaderMaterial.new()
	g._mat.shader = _shader_reflejo
	g._mat.set_shader_parameter("luz", Color8(220, 226, 236))
	g._mat.set_shader_parameter("medio", Color8(150, 156, 170))
	g.material = g._mat
	g.z_index = 1
	g.process_mode = Node.PROCESS_MODE_ALWAYS
	spr.add_child(g)
	return g


func _process(delta: float) -> void:
	if not is_instance_valid(_spr):
		queue_free()
		return
	if _reflejo > -INF and _mat.shader == _shader_reflejo:
		_reflejo += delta
		if _reflejo >= _t_reflejo:
			queue_free()
			return
		visible = _reflejo >= 0.0
		_mat.set_shader_parameter("pasa", clampf(_reflejo / _t_reflejo, 0.0, 1.0))
		queue_redraw()
		return
	_t += delta
	# Late: la carga, cada vez mas deprisa; lo seco, mas deprisa cuantos mas tramos.
	var periodo: float = (0.5 - minf(_t, 2.0) * 0.15) if carga else maxf(0.6 - 0.12 * float(nivel), 0.2)
	var encendido: bool = fmod(_t, periodo) < periodo * 0.5
	_mat.set_shader_parameter("late", 1.0 if encendido else 0.0)
	_mat.set_shader_parameter("extiende", 0 if carga else clampi(nivel - 1, 0, 2))
	visible = encendido or carga or nivel > 1
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_spr) or _spr.sprite_frames == null or not _spr.sprite_frames.has_animation(_spr.animation):
		return
	var tex: Texture2D = _spr.sprite_frames.get_frame_texture(_spr.animation, _spr.frame)
	if tex == null:
		return
	var tam: Vector2 = tex.get_size()
	var pos: Vector2 = (-tam * 0.5 if _spr.centered else Vector2.ZERO) + _spr.offset
	if _spr.flip_h:
		draw_texture_rect(tex, Rect2(Vector2(-pos.x, pos.y), Vector2(-tam.x, tam.y)), false)
	else:
		draw_texture(tex, pos)
