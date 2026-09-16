# ============================================================
#  humo_chimenea.gd  (class_name HumoChimenea)
#  EL HUMO QUE SUBE de una chimenea del pueblo. Lo pidio el usuario al ver las tres bocanadas pintadas
#  en la casa: "humo de verdad que suba, en vez de esto asi todo quieto".
#
#  Son particulas de CPU (hay pocas chimeneas y pocas bocanadas): cada una nace en la boca, sube
#  frenando, se deja llevar un poco por el aire hacia el este, crece y se desvanece. La textura es un
#  circulo de pixel-art con dos tonos (sin degradado suave) y filtro nearest, para que no desentone
#  con el resto del dibujo.
#
#  Va por ENCIMA del tejado (su z es el de la parte alta de las casas + 1): el humo sale por arriba.
# ============================================================
extends CPUParticles2D
class_name HumoChimenea

static var _tex: ImageTexture = null


static func crear(fragua: bool) -> HumoChimenea:
	var h := HumoChimenea.new()
	h.name = "Humo"
	h.texture = _bocanada()
	h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.z_as_relative = false
	h.z_index = PiezaPueblo.Z_ENCIMA + 1
	h.amount = 9 if fragua else 7
	h.lifetime = 3.2
	h.preprocess = 3.2              # que al entrar al pueblo ya este echando humo, no empezando
	h.randomness = 0.3
	h.local_coords = false
	h.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	h.emission_sphere_radius = 2.0
	h.direction = Vector2(0, -1)
	h.spread = 14.0
	h.initial_velocity_min = 11.0
	h.initial_velocity_max = 16.0
	h.gravity = Vector2(3.5, 2.0)   # frena al subir y se va de lado con el aire
	h.damping_min = 1.0
	h.damping_max = 2.0
	h.angle_min = 0.0
	h.angle_max = 360.0
	var escala := Curve.new()
	escala.add_point(Vector2(0.0, 0.35))
	escala.add_point(Vector2(0.5, 0.8))
	escala.add_point(Vector2(1.0, 1.25))
	h.scale_amount_curve = escala
	var base: Color = Color(0.36, 0.34, 0.35) if fragua else Color(0.86, 0.86, 0.88)
	var rampa := Gradient.new()
	rampa.set_color(0, Color(base, 0.0))
	rampa.set_offset(0, 0.0)
	rampa.set_color(1, Color(base.lightened(0.15), 0.0))
	rampa.set_offset(1, 1.0)
	rampa.add_point(0.12, Color(base, 0.85))
	rampa.add_point(0.6, Color(base.lightened(0.08), 0.55))
	h.color_ramp = rampa
	return h


# Una bocanada de 12x12 en dos tonos: cuerpo y un brillo arriba a la izquierda.
static func _bocanada() -> ImageTexture:
	if _tex != null:
		return _tex
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var dx: float = float(x) + 0.5 - 6.0
			var dy: float = float(y) + 0.5 - 6.0
			var r: float = sqrt(dx * dx + dy * dy)
			if r > 5.6:
				continue
			var c := Color(0.82, 0.82, 0.84, 1.0)
			if dx + dy < -3.0 and r < 4.2:
				c = Color(1, 1, 1, 1)
			elif dx + dy > 4.0:
				c = Color(0.68, 0.68, 0.70, 1.0)
			img.set_pixel(x, y, c)
	_tex = ImageTexture.create_from_image(img)
	return _tex
