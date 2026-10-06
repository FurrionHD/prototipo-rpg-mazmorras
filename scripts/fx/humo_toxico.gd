# ============================================================
#  humo_toxico.gd  (class_name HumoToxico)
#  LO QUE LE SALE AL AZAR POR EL CUERPO a los mutantes del slime venenoso (06/10, lo pidio el jefe: "el humo no puede
#  salir todo el rato: saldra aleatorio y en sitios aleatorios"; y el pestilente "burbujas que salen a veces de forma
#  aleatoria en cualquier parte de su cuerpo y luego sale el humillo para arriba").
#    - modo 1 (SLIME DE MIASMA): cada pocos segundos, por un sitio al azar de su cuerpo, una BOCANADA de gas verde que
#      sube, crece y se deshace.
#    - modo 2 (SLIME PESTILENTE): una BURBUJA que se le hincha en la piel, REVIENTA (gotitas) y suelta la bocanada. Mas
#      a menudo, y a veces dos a la vez.
#  Como el Parpadeo: una capa HIJA del sprite (hereda posicion, escala, volteo y tinte), cada enemigo a su aire. Se pinta
#  en pixeles de la hoja (el sprite lo amplia), con los colores de su gel. Muerto, nada.
# ============================================================
extends Node2D
class_name HumoToxico

const NOMBRE := "HumoToxico"
const VIDA_BOCANADA := 1.5
const VIDA_BURBUJA := 0.5      # lo que tarda la burbuja en hincharse y reventar (luego, su bocanada)

var modo: int = 1
var _principal: AnimatedSprite2D = null
var _espera: float = 0.0
var _vivos: Array = []         # {p (relativo al centro del cuerpo, en radios), t, burbuja}
var _col: Color = Color(0.29, 0.78, 0.33)


# Se lo pone (o se lo quita, modo 0) a 'sprite'. 'col' = el color de su gel (el del piso).
static func poner(sprite: AnimatedSprite2D, modo_: int, col: Color = Color(0.29, 0.78, 0.33)) -> void:
	if sprite == null:
		return
	var h: HumoToxico = sprite.get_node_or_null(NOMBRE) as HumoToxico
	if modo_ <= 0:
		if h != null:
			h.queue_free()
		return
	if h == null:
		h = HumoToxico.new()
		h.name = NOMBRE
		sprite.add_child(h)
	h._principal = sprite
	h.modo = modo_
	h._col = col
	h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# El modo que le toca a un enemigo (el 'humo' de su MutacionData; 0 si no es mutante o no lo lleva).
static func modo_de(ed: EnemyData, mutante: bool, mutacion: StringName) -> int:
	if ed == null or not mutante:
		return 0
	var m: MutacionData = ed.mutacion_de(mutacion)
	return m.humo if m != null else 0


func _ready() -> void:
	_espera = randf_range(0.3, 2.5)


func _process(delta: float) -> void:
	if _principal == null or not is_instance_valid(_principal):
		return
	for v in _vivos:
		v["t"] = float(v["t"]) + delta
	_vivos = _vivos.filter(func(v): return float(v["t"]) < VIDA_BOCANADA + (VIDA_BURBUJA if v["burbuja"] else 0.0))
	_espera -= delta
	if _espera <= 0.0:
		if _puede():
			_sale()
			# El pestilente, a veces dos a la vez.
			if modo == 2 and randf() < 0.3:
				_sale()
		_espera = randf_range(1.5, 4.5) if modo == 1 else randf_range(0.8, 2.5)
	queue_redraw()


func _puede() -> bool:
	var a: String = String(_principal.animation)
	return not (a.begins_with("muerte") or a.begins_with("cadaver")) and _principal.visible


# Un sitio al azar de su cuerpo (mas por arriba que por abajo, que es donde se ve; el humo sube).
func _sale() -> void:
	var p := Vector2(randf_range(-0.85, 0.85), randf_range(-0.95, 0.35))
	if p.length() > 0.95:
		p = p.normalized() * 0.95
	_vivos.append({"p": p, "t": 0.0, "burbuja": modo == 2})


# Centro y radios del cuerpo en el sprite (pixeles de la hoja, relativos a su centro). Las medidas son las del modelo
# (tools/sprites_sdf/slime_sdf.py): la bola de 16,5 de radio, con el centro a 9 de altura, y el lienzo de 34 u por
# escala 1,15; con u = alto del lienzo / 1,52.
func _cuerpo() -> Array:
	var tex: Texture2D = _principal.sprite_frames.get_frame_texture(_principal.animation, _principal.frame) \
		if _principal.sprite_frames != null and _principal.sprite_frames.has_animation(_principal.animation) else null
	var alto: float = tex.get_size().y if tex != null else 60.0
	var u: float = alto / 1.52
	var c: Vector2 = _principal.offset + Vector2(0.0, 0.173 * u)
	if not _principal.centered and tex != null:
		c += tex.get_size() * 0.5
	return [c, Vector2(0.48 * u, 0.42 * u), u]


func _draw() -> void:
	if _vivos.is_empty() or _principal == null:
		return
	var cu: Array = _cuerpo()
	var c0: Vector2 = cu[0]
	var rad: Vector2 = cu[1]
	var u: float = cu[2]
	var esc: float = u / 40.0          # (los tamaños, pensados para el miasma: u ~ 40)
	var osc: Color = _col.darkened(0.55)
	for v in _vivos:
		var base: Vector2 = c0 + Vector2((v["p"] as Vector2).x * rad.x, (v["p"] as Vector2).y * rad.y)
		var t: float = float(v["t"])
		if v["burbuja"]:
			if t < VIDA_BURBUJA:
				# LA BURBUJA que se hincha en la piel (con su brillo) y, al final, revienta.
				var k: float = t / VIDA_BURBUJA
				var r: float = (1.0 + 3.0 * k) * esc
				if k < 0.88:
					draw_circle(base.round(), r + 1.0, Color(osc, 0.95))
					draw_circle(base.round(), r, _col.lightened(0.45))
					draw_circle((base + Vector2(-r * 0.35, -r * 0.4)).round(), maxf(r * 0.3, 0.8), Color(1, 1, 0.95, 0.9))
				else:
					for i in 5:
						var d := Vector2.RIGHT.rotated(TAU * float(i) / 5.0 + 0.4)
						draw_circle((base + d * r * 1.6).round(), maxf(0.9 * esc, 0.8), Color(_col.lightened(0.3), 0.9))
				continue
			t -= VIDA_BURBUJA
		_bocanada(base, t / VIDA_BOCANADA, esc, osc)


# UNA BOCANADA: tres o cuatro bolas de gas verde con su borde oscuro y su luz, que suben, crecen y se deshacen.
func _bocanada(base: Vector2, k: float, esc: float, osc: Color) -> void:
	var sube: float = 14.0 * esc * (1.0 - (1.0 - k) * (1.0 - k))
	var tam: float = esc * (0.6 + 1.0 * sin(minf(k, 1.0) * PI * 0.85))
	var alfa: float = 1.0 - clampf((k - 0.55) / 0.45, 0.0, 1.0)
	if alfa <= 0.02 or tam <= 0.05:
		return
	var c: Vector2 = base - Vector2(sin(k * 4.0) * 1.5 * esc, sube)
	var gas: Color = _col.lerp(Color(0.80, 0.95, 0.62), 0.45)
	var bolas: Array = [[Vector2(0, 0), 2.6], [Vector2(2.0, 0.4), 2.0], [Vector2(-2.0, 0.3), 1.9], [Vector2(0.5, -1.6), 1.8]]
	for b in bolas:
		draw_circle((c + (b[0] as Vector2) * tam).round(), float(b[1]) * tam + 1.0, Color(osc, 0.85 * alfa))
	for b in bolas:
		draw_circle((c + (b[0] as Vector2) * tam).round(), float(b[1]) * tam, Color(gas, 0.9 * alfa))
	for b in bolas:
		draw_circle((c + (b[0] as Vector2) * tam + Vector2(-0.6, -0.7) * tam).round(), float(b[1]) * tam * 0.45,
			Color(gas.lightened(0.4), 0.8 * alfa))
